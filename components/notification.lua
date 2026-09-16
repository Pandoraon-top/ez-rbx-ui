-- Deps injected via Init(R). Sonner-style toasts: slide in from the anchored edge, stack
-- bottom-right (newest in front), older ones peek behind (scaled + faded); hover the stack to
-- expand into a full list. Each toast is a CanvasGroup so it fades -- and exits -- as one piece.
local Notification = {}
local Create, DefaultTheme, Maid, Overlay, Animate, Icons, Safe, Effects, Recipes
local RunService = game:GetService("RunService")
local container
local stackShadow  -- ONE shadow under the front toast (sibling of the toasts, ZIndex 0)
local order = {}   -- array of entries (oldest first, newest last)
local seq = 0
local expanded = false
local stepConn
local pinnedScale  -- Notification.setScale(n); nil = follow the process-wide Overlay.scale()

-- Pre-measure fallbacks: AbsoluteSize / AbsoluteContentSize are nil headless and on the first
-- frame, so the stack still lays out (and the hover hit-area still exists) before any measure.
local FALLBACK_H = 60
-- Icon badge square. No Sizes token holds 20 today (icon 16 / iconSm 14 / iconButton 26), so the
-- one number the badge needs lives here rather than being faked out of an unrelated token.
local BADGE = 20

function Notification.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Animate = R.Animate; Icons = R.Icons
  Safe = R.Safe; Effects = R.Effects; Recipes = R.Recipes
  container = nil
  stackShadow = nil
  -- Init is re-entrant (the test harness re-runs it per loadLib): drop the previous Heartbeat
  -- countdown so a fresh container never runs two tickers over the same `order`.
  if stepConn then stepConn:Disconnect() end
  stepConn = nil
  expanded = false
  pinnedScale = nil
end

local enabled = true
function Notification.setEnabled(b) enabled = b ~= false end

local TYPE_COLOR = { info = "info", success = "success", warning = "warning", error = "destructive", loading = "info" }
local TYPE_ICON = { info = "info", success = "circle-check", warning = "triangle-alert", error = "circle-alert", loading = "loader" }

local position = "bottom-right"
local POS = {
  ["top-left"]      = { ax = 0,   ay = 0 },
  ["top-center"]    = { ax = 0.5, ay = 0 },
  ["top-right"]     = { ax = 1,   ay = 0 },
  ["bottom-left"]   = { ax = 0,   ay = 1 },
  ["bottom-center"] = { ax = 0.5, ay = 1 },
  ["bottom-right"]  = { ax = 1,   ay = 1 },
}

-- The container is process-wide, so there is no single owning window: layout tokens are read
-- from the theme of the toast currently in front, and from the module defaults when empty.
local function frontTheme()
  local e = order[#order]
  return (e and e.theme) or DefaultTheme
end
-- theme.mix rides on Theme.new instances and on the module itself; a bare table theme falls back.
local function mix(theme, a, b, t) return (theme.mix or DefaultTheme.mix)(a, b, t) end
-- Border tinted toward the type colour: an error toast reads as an error before its icon does.
local function edgeColor(theme, accent) return mix(theme, theme.Colors.border, accent, theme.Toast.typeTint) end

local function containerPosition(cfg, TK)
  local cx = (cfg.ax == 0 and UDim.new(0, TK.inset)) or (cfg.ax == 1 and UDim.new(1, -TK.inset)) or UDim.new(0.5, 0)
  local cy = (cfg.ay == 0) and UDim.new(0, TK.inset) or UDim.new(1, -TK.inset)
  return UDim2.new(cx.Scale, cx.Offset, cy.Scale, cy.Offset)
end

-- Window:SetUIScale forwards through Notification.setScale; when nothing pinned a value we follow
-- the process-wide Overlay scale, so a window that only reached Overlay.setScale still scales.
local function currentScale()
  if pinnedScale then return pinnedScale end
  local s = Overlay.scale and Overlay.scale()
  return (type(s) == "number" and s > 0) and s or 1
end

-- ---- countdown ticker ---------------------------------------------------------------------
-- One Heartbeat handler for the whole stack, connected lazily by show() and dropped the moment
-- the stack empties. Before this it ran forever -- even after Overlay.reset() tore the container
-- down -- and a re-Init left the stale one ticking over the same `order`.
local function stopTicker()
  if stepConn then stepConn:Disconnect(); stepConn = nil end
end

local function tick(dt)
  for i = #order, 1, -1 do
    local e = order[i]
    if e.frame and e.total and not e.paused then
      e.remaining = e.remaining - dt
      -- Heartbeat handlers lack the GUI capability on strict executors, so a raw write throws.
      -- pcall (not Safe.mutate) because this is a per-frame cosmetic write -- skip it cleanly when
      -- there's no capability rather than deferring 60 writes/sec. The countdown + dismiss below
      -- run on plain Lua state / Safe.mutate, so the toast still expires correctly.
      if e.bar then
        local bh = ((e.theme or DefaultTheme).Toast).barHeight
        pcall(function() e.bar.Size = UDim2.new(math.max(0, e.remaining / e.total), 0, 0, bh) end)
      end
      if e.remaining <= 0 then Notification.dismiss(e.id) end
    end
  end
  if #order == 0 then stopTicker() end
end

local function ensureTicker()
  if not stepConn then stepConn = RunService.Heartbeat:Connect(tick) end
end

-- ---- container ------------------------------------------------------------------------------
local function ensureContainer(theme)
  if container and container.Parent ~= nil then return container end
  local TK = theme.Toast
  stackShadow = nil                    -- belonged to the previous container
  local cfg = POS[position] or POS["bottom-right"]
  container = Create("Frame", {
    -- Height starts at 0 and is grown by relayout to wrap the actual toast stack. The container
    -- IS the MouseEnter/Leave hover hit-area, so it must NOT span the full screen height -- a tall
    -- strip would falsely trigger hover/expand whenever the pointer sits in that column (most
    -- visible at top-center/bottom-center, where the column runs down the middle of the screen).
    Name = "ToastContainer", BackgroundTransparency = 1, ZIndex = Overlay.Z.toast,
    AnchorPoint = Vector2.new(cfg.ax, cfg.ay), Position = containerPosition(cfg, TK),
    Size = UDim2.new(0, TK.width, 0, 0),
  })
  -- UI scale lives HERE, never on the overlay root (the click catcher's (1,0,1,0) would stop
  -- covering the screen). Toast.width stays logical px; this multiplies the whole stack.
  Create("UIScale", { Name = "ContainerScale", Scale = currentScale(), Parent = container })
  container.MouseEnter:Connect(function()
    expanded = true
    for _, e in ipairs(order) do e.paused = true end
    Notification.relayout("expand")   -- the one pass that fans the rows out on a stagger
  end)
  container.MouseLeave:Connect(function()
    expanded = false
    for _, e in ipairs(order) do e.paused = false end
    Notification.relayout()
  end)
  Overlay.mount(container)
  return container
end

-- One 9-slice layer for the whole stack rather than one per toast. nil while Effect.shadowId is
-- '' (the default), so every use below is nil-tolerant.
local function ensureStackShadow(theme)
  if stackShadow and stackShadow.Parent ~= nil then return stackShadow end
  stackShadow = Effects.shadow(container, theme, { name = "StackShadow", level = "toast", zIndex = 0 })
  if stackShadow then stackShadow.Visible = false end
  return stackShadow
end

-- Park the shadow under the FRONT toast. Toasts render at the default ZIndex 1, so the layer sits
-- at 0; it is a sibling (a child would render above the toast's own fill). Absolute* is nil
-- headless and before the first engine measure, so the layer simply stays hidden until measured.
local function syncStackShadow(theme)
  if not stackShadow then return end
  local e = order[#order]
  local f = e and e.frame
  local ap, as = f and f.AbsolutePosition, f and f.AbsoluteSize
  local cp = container and container.AbsolutePosition
  if not (ap and as and cp and (as.Y or 0) > 0) then stackShadow.Visible = false; return end
  stackShadow.Visible = true
  -- Absolute* are SCREEN pixels, but the shadow lives inside the container's own UIScale, whose
  -- children are laid out in logical pixels. Feeding screen px straight in mis-sized and
  -- mis-placed the layer by exactly the UI scale, so divide it back out first.
  local s = currentScale()
  Effects.place(stackShadow, (ap.X - cp.X) / s, (ap.Y - cp.Y) / s, as.X / s, as.Y / s, "toast", theme)
  Effects.reskin(stackShadow, theme, "shadow")   -- per-mode alpha; nil-tolerant, cheap, idempotent
end

-- Intrinsic (scale-independent) height of a toast: UIListLayout content + its own vertical
-- padding. Reading AbsoluteSize mid-animation gives the SCALED height and makes the expanded
-- gaps jitter, so the measured value is only a fallback.
local function toastHeight(e)
  local lay = e.frame:FindFirstChildOfClass("UIListLayout")
  local acs = lay and lay.AbsoluteContentSize
  local pad = 0
  if e.padding then pad = e.padding.PaddingTop.Offset + e.padding.PaddingBottom.Offset end
  if acs and acs.Y and acs.Y > 0 then return acs.Y + pad end
  return (e.frame.AbsoluteSize and e.frame.AbsoluteSize.Y) or FALLBACK_H
end

-- position/scale/fade each toast based on its index from the front (newest = 0).
-- `reason` is 'expand' for the hover fan-out -- the ONLY pass allowed to carry the stagger delay --
-- and nil / 'measure' for everything else. The engine fires AbsoluteSize on every frame of the
-- entrance (AbsoluteSize includes the UIScale), so a measurement-driven pass that re-armed the
-- stagger would stall the back rows instead of fanning them out; one that re-issued the steady
-- tweens would cancel the entrance's Back/Out overshoot from a partial value. Hence both the
-- reason gate and the per-entry `laid` cache: a MEASUREMENT that changes nothing writes no tween.
function Notification.relayout(reason)
  local theme = frontTheme()
  local TK, M = theme.Toast, theme.Motion
  local n = #order
  local cfg = POS[position] or POS["bottom-right"]
  local vdir = (cfg.ay == 0) and 1 or -1
  local y = 0
  for idx = n, 1, -1 do
    local e = order[idx]
    if not e.frame then
      -- GUI deferred to a later Heartbeat; skip until built (it relayouts itself when ready)
    else
      local i = n - idx -- 0 = newest (front)
      local scale, transp, visible, yoff
      if expanded then
        visible, scale, transp, yoff = true, 1, 0, y
        y = y + toastHeight(e) + TK.gap
      else
        visible = i < TK.maxVisible
        scale = 1 - i * TK.peekScale
        transp = i * TK.peekFade
        yoff = i * TK.peek
      end
      e.frame.Visible = visible
      e.frame.AnchorPoint = Vector2.new(cfg.ax, cfg.ay)
      local target = UDim2.new(cfg.ax, 0, cfg.ay, vdir * yoff)
      -- The layout this entry was last given. A measurement re-runs relayout with identical
      -- numbers, and re-tweening then would both cost 2n tween objects per measured frame and
      -- replace the in-flight entrance with a steady tween from its partial value. Only a
      -- measurement is allowed to skip: every other caller asked for a fresh pass.
      local last = e.laid
      local moved = not last or last.yoff ~= yoff or last.scale ~= scale or last.transp ~= transp
        or last.ax ~= cfg.ax or last.ay ~= cfg.ay
      e.laid = { yoff = yoff, scale = scale, transp = transp, ax = cfg.ax, ay = cfg.ay }
      if e.entering then
        -- The entrance OWNS position + scale for exactly one pass. A steady tween fired in the
        -- same frame used to fight the pop for the UIScale and flatten the Back/Out overshoot,
        -- which is why the entrance never actually overshot.
        e.entering = false
        Animate.springTo(e.frame, "enter", { Position = target })
        Animate.to(e.frame, "base", { GroupTransparency = transp }, Animate.EASING.enter)
        Animate.springTo(e.scale, "enter", { Scale = scale })
      elseif moved or reason ~= "measure" then
        -- Expanding the stack fans the rows open: each one further back waits an extra
        -- Motion.stagger, capped at Toast.staggerCap so a tall stack still opens promptly. Only
        -- the expand pass itself: a reflow that happens to land while expanded (a measurement, an
        -- update that regrew a toast) must move at delay 0 or it re-arms the whole fan.
        local d = (expanded and reason == "expand") and math.min(i, TK.staggerCap) * M.stagger or 0
        Animate.to(e.frame, "base", { Position = target, GroupTransparency = transp }, Animate.EASING.smooth, nil, d)
        Animate.to(e.scale, "base", { Scale = scale }, Animate.EASING.smooth, nil, d)
      end
    end
  end
  -- Size the container (the hover hit-area) to wrap the visible stack so MouseEnter only fires over
  -- the toasts, never the empty column above/below them. Set directly (not animated) so the hit-area
  -- never lags the pointer. Anchored at the edge, so growing height extends toward screen centre.
  if container then
    local h = 0
    if n > 0 then
      if expanded then
        h = math.max(0, y - TK.gap)         -- y accumulated a trailing gap per toast
      else
        local front = order[n]              -- newest = front of the collapsed stack
        local fh = front and front.frame and front.frame.AbsoluteSize and front.frame.AbsoluteSize.Y or 0
        if fh <= 0 then fh = FALLBACK_H end -- fallback before first engine measure (and headless tests)
        h = fh + math.min(n - 1, TK.maxVisible - 1) * TK.peek
      end
    end
    container.Size = UDim2.new(0, TK.width, 0, h)
  end
  syncStackShadow(theme)
end

local function indexOf(id) for i, e in ipairs(order) do if e.id == id then return i end end end

-- Semantic accent for a toast type, read from the LIVE palette so a reskin picks up the mode's
-- colour (the four type tokens are mode-invariant today, but a theme override may change them).
local function accentFor(theme, ty) return theme.Colors[TYPE_COLOR[ty]] or theme.Colors.info end

-- The bar hugs the bottom edge, so a toast WITH a countdown drops its bottom padding to
-- Toast.progressInset and gets it back when the bar goes away (morph to a persistent type).
local function setProgressPad(entry, hasBar)
  if not entry.padding then return end
  local TK = (entry.theme or DefaultTheme).Toast
  entry.padding.PaddingBottom = UDim.new(0, hasBar and TK.progressInset or TK.padY)
end

local function startCountdown(entry, total, accent, theme)
  -- 'Progress' is a DIRECT child of the toast: no track wrapper (a parent would shadow the
  -- lookup) and no sibling track (the toast has a UIListLayout, so it would become a second row).
  local bar = Create("Frame", { Name = "Progress", BackgroundColor3 = accent, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, theme.Toast.barHeight), LayoutOrder = 99, Parent = entry.frame,
    Create.corner(theme.Radius.xs) })
  entry.total = total; entry.remaining = total; entry.paused = false; entry.bar = bar
  setProgressPad(entry, true)
end

local function createMsgLabel(text, theme, parent)
  local lbl = Create("TextLabel", { Name = "Message", BackgroundTransparency = 1, Text = text,
    TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = parent })
  return Create.text(lbl, theme, "muted")
end

-- Stop the loader spin (if any); Animate.spin's Cancel rests the glyph at Rotation 0.
local function stopSpin(entry)
  if entry.spin then entry.spin.Cancel(); entry.spin = nil end
end

-- Type motion: success lands with a pop on its glyph, an error shakes its head. The pop scales a
-- UIScale UNDER the glyph (never the glyph itself, whose Rotation belongs to the spinner), and
-- the shake rotates the whole card by Motion.shake.amp degrees and ends exactly at 0.
local function typeFeedback(entry)
  local theme = entry.theme
  if entry.type == "success" then
    if entry.icon then Animate.pop(entry.icon, "enter") end
  elseif entry.type == "error" and entry.frame and Animate.isEnabled() then
    local sh = theme.Motion.shake
    Animate.chain({
      { entry.frame, sh.step, { Rotation = -sh.amp }, Enum.EasingStyle.Sine },
      { entry.frame, sh.step, { Rotation = sh.amp }, Enum.EasingStyle.Sine },
      { entry.frame, sh.step, { Rotation = 0 }, Enum.EasingStyle.Sine },
    })
  end
end

-- Live re-skin (SetMode/SetAccent): every coloured part re-reads theme.Colors. Parts that
-- applyUpdate creates or replaces later (Message, Progress) are read off the entry at call time.
local function reskin(entry)
  local theme = entry.theme
  local accent = accentFor(theme, entry.type)
  entry.accent = accent
  entry.frame.BackgroundColor3 = theme.Colors.card
  if entry.stroke then entry.stroke.Color = edgeColor(theme, accent) end
  if entry.badge then entry.badge.BackgroundColor3 = accent end
  entry.titleLabel.TextColor3 = theme.Colors.foreground
  if entry.msgLabel then entry.msgLabel.TextColor3 = theme.Colors.mutedForeground end
  -- the icon-button recipe owns the Close glyph tint (it must keep a hovered glyph lifted)
  if entry.closeHandle then entry.closeHandle.reskin() end
  if entry.actionHover then entry.actionHover.reskin() end
  if entry.actionBtn then
    entry.actionBtn.BackgroundColor3 = theme.Colors.surface
    entry.actionBtn.TextColor3 = theme.Colors.foreground
  end
  if entry.bar then entry.bar.BackgroundColor3 = accent end
  -- Icons.apply only rewrites ImageColor3 when the glyph is unchanged, so a spinning loader is
  -- retinted without touching its Rotation.
  if entry.icon then Icons.apply(entry.icon, TYPE_ICON[entry.type] or "info", accent) end
end

-- Everything the build attached (themer registration, recipe handlers, property signals) is
-- released exactly once, on dismiss.
local function releaseEntry(entry)
  if entry.unreg then entry.unreg(); entry.unreg = nil end
  local rel = entry.releases
  if not rel then return end
  for i = #rel, 1, -1 do local fn = rel[i]; rel[i] = nil; pcall(fn) end
end

local function msgText(v, arg)
  if type(v) == "function" then local ok, r = pcall(v, arg); return ok and r or nil end
  if type(v) == "string" then return v end
  return nil
end

local applyUpdate  -- forward declaration; applyUpdate is assigned after Notification.loading, show's pendingUpdate hook closes over it

function Notification.show(opts)
  if not enabled then return nil end
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  seq = seq + 1
  local id = seq
  local entry = { id = id, onDismiss = opts.OnDismiss, releases = {} }
  order[#order + 1] = entry           -- reserve FIFO slot synchronously
  Safe.mutate(function()
    local TK = theme.Toast
    local ty = opts.Type or "info"
    local accent = accentFor(theme, ty)
    ensureContainer(theme)
    ensureStackShadow(theme)
    ensureTicker()
    local pcfg = POS[position] or POS["bottom-right"]
    -- Enter from outside the anchored edge; relayout's entering branch springs it home.
    local sx = (pcfg.ax == 1 and UDim.new(1, TK.slide)) or (pcfg.ax == 0 and UDim.new(0, -TK.slide)) or UDim.new(0.5, 0)
    -- center toasts slide in vertically from the nearest edge: top-center from above, bottom-center from below
    local sy = (pcfg.ax == 0.5) and UDim.new(pcfg.ay, ((pcfg.ay == 0) and -1 or 1) * TK.slide) or UDim.new(pcfg.ay, 0)
    local hasBar = (ty ~= "loading") and ((opts.Duration or 4000) > 0)
    local padding = Create.padding({ left = TK.padX, right = TK.padX, top = TK.padY,
      bottom = hasBar and TK.progressInset or TK.padY })
    local toast = Create("CanvasGroup", {
      Name = "Toast", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0, GroupTransparency = 1,
      AnchorPoint = Vector2.new(pcfg.ax, pcfg.ay), Position = UDim2.new(sx.Scale, sx.Offset, sy.Scale, sy.Offset),
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = container,
      Create.corner(theme.Radius.md), padding,
      Create.listLayout({ Padding = 4 }),
    })
    -- floating surface: opaque hairline (Stroke.floating) tinted Toast.typeTint toward the type
    local stroke = Create.stroke(edgeColor(theme, accent), 1, theme.Stroke.floating)
    stroke.Parent = toast
    -- Entrance state: off-edge, fully faded, shrunk. relayout (entering branch) animates all three.
    local scale = Create("UIScale", { Scale = theme.Motion.enterScale, Parent = toast })
    entry.entering = true
    local sizeConn = toast:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
      -- property-changed handler -> engine thread without GUI capability on strict executors; relayout
      -- reads AbsoluteContentSize/AbsoluteSize raw, so marshal it through Safe.mutate. Always relayout
      -- (not only when expanded): the collapsed container height tracks the front toast's measured
      -- height, so the hover hit-area must update once the engine measures the toast. 'measure'
      -- keeps it cheap and harmless -- the engine fires this on every frame of the entrance, so the
      -- pass must not re-arm the stagger nor re-tween a row that has not actually moved.
      Safe.mutate(function() Notification.relayout("measure") end)
    end)
    entry.releases[#entry.releases + 1] = function() sizeConn:Disconnect() end
    local titleRow = Create("Frame", { Name = "TitleRow", BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = toast })
    -- Badge behind the glyph. TitleRow has no layout, so a decorative child is safe here (the
    -- toast itself has a UIListLayout and could not take one). ZIndex 0 = under its sibling Icon.
    local badge = Create("Frame", { Name = "IconBadge", BackgroundColor3 = accent,
      BackgroundTransparency = TK.badgeAlpha, BorderSizePixel = 0, ZIndex = 0, Active = false,
      Size = UDim2.new(0, BADGE, 0, BADGE), Position = UDim2.new(0, -2, 0.5, -BADGE / 2),
      Parent = titleRow, Create.corner(theme.Radius.sm) })
    local tIcon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
      Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon),
      Position = UDim2.new(0, 0, 0.5, -theme.Sizes.icon / 2), Parent = titleRow })
    Icons.apply(tIcon, TYPE_ICON[ty] or "info", accent)
    local titleX = BADGE + theme.Spacing.icon   -- clears the badge, not just the 16px glyph
    local titleLabel = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Title or "",
      TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
      TextTruncate = Enum.TextTruncate.AtEnd,
      Size = UDim2.new(1, -(titleX + theme.Sizes.icon), 1, 0), Position = UDim2.new(0, titleX, 0, 0), Parent = titleRow })
    Create.text(titleLabel, theme, "label")
    local closeBtn = Create("ImageButton", { Name = "Close", AutoButtonColor = false, BackgroundTransparency = 1,
      Size = UDim2.new(0, theme.Sizes.iconSm, 0, theme.Sizes.iconSm),
      Position = UDim2.new(1, -theme.Sizes.iconSm, 0, 0), Parent = titleRow })
    -- Comfortable hit target + hover wash + glyph lift; the glyph itself stays 14px. 'primary'
    -- rest keeps the close affordance as bright as the rest of the chrome.
    local closeHandle = Recipes.iconButton(closeBtn, { theme = theme, icon = "x", rest = "primary",
      hover = "foreground", parent = titleRow, onClick = function() Notification.dismiss(id) end })
    entry.releases[#entry.releases + 1] = closeHandle.disconnect
    local msgLabel
    if opts.Message then
      msgLabel = createMsgLabel(opts.Message, theme, toast)
    end
    local aBtn, actionHover
    if opts.Action then
      local act = opts.Action
      aBtn = Create("TextButton", { Name = "Action", AutoButtonColor = false,
        BackgroundColor3 = theme.Colors.surface, Text = act.Text or act.Label or "Action",
        TextColor3 = theme.Colors.foreground,
        Size = UDim2.new(0, 96, 0, 24), LayoutOrder = 3, Parent = toast, Create.corner(theme.Radius.sm) })
      Create.text(aBtn, theme, "muted")
      -- wash only: a UIScale on the Action would reflow the toast's UIListLayout rows
      actionHover = Recipes.hover(aBtn, { theme = theme, corner = theme.Radius.sm, kind = "wash" })
      entry.releases[#entry.releases + 1] = actionHover.disconnect
      aBtn.MouseButton1Click:Connect(function() if act.Callback then pcall(act.Callback) end; Notification.dismiss(id) end)
    end
    entry.frame = toast; entry.scale = scale; entry.stroke = stroke; entry.padding = padding
    entry.icon = tIcon; entry.badge = badge; entry.titleLabel = titleLabel
    entry.closeBtn = closeBtn; entry.closeHandle = closeHandle
    entry.actionBtn = aBtn; entry.actionHover = actionHover
    entry.theme = theme
    entry.type = ty; entry.accent = accent
    entry.msgLabel = msgLabel
    if entry.type == "loading" then entry.spin = Animate.spin(tIcon) end
    if hasBar then startCountdown(entry, (opts.Duration or 4000) / 1000, accent, theme) end
    -- A live toast follows SetMode/SetAccent through the window's themer; released in dismiss.
    -- Registered after the build so the closure never sees a half-built toast.
    if opts.AccentReg then entry.unreg = opts.AccentReg(function() reskin(entry) end) end
    Notification.relayout()
    typeFeedback(entry)
    if entry.pendingUpdate then applyUpdate(entry, entry.pendingUpdate); entry.pendingUpdate = nil end
  end)
  return id
end

function Notification.loading(opts)
  opts = opts or {}
  opts.Type = "loading"; opts.Duration = 0
  return Notification.show(opts)
end

applyUpdate = function(entry, opts)
  local theme = entry.theme
  local newType = opts.Type or entry.type
  local accent = accentFor(theme, newType)
  local morphed = newType ~= entry.type
  entry.type = newType; entry.accent = accent
  -- Cancel BEFORE re-applying the glyph: Cancel rests Rotation at 0 so the new (static) icon
  -- never lands mid-spin. A morph back to 'loading' restarts the spin.
  stopSpin(entry)
  if entry.stroke then entry.stroke.Color = edgeColor(theme, accent) end
  if entry.badge then entry.badge.BackgroundColor3 = accent end
  if entry.icon then
    Icons.apply(entry.icon, TYPE_ICON[newType] or "info", accent)
    if newType == "loading" then entry.spin = Animate.spin(entry.icon) end
  end
  if opts.Title ~= nil and entry.titleLabel then entry.titleLabel.Text = opts.Title end
  if opts.Message ~= nil then
    if entry.msgLabel then
      entry.msgLabel.Text = opts.Message
    else
      entry.msgLabel = createMsgLabel(opts.Message, theme, entry.frame)
    end
  end
  if opts.Duration and opts.Duration > 0 then
    if entry.bar then entry.bar:Destroy(); entry.bar = nil end
    startCountdown(entry, opts.Duration / 1000, accent, theme)
  elseif opts.Duration == 0 then
    if entry.bar then entry.bar:Destroy(); entry.bar = nil end
    entry.total = nil; entry.remaining = nil; entry.bar = nil
    setProgressPad(entry, false)
  end
  if morphed then typeFeedback(entry) end
  Notification.relayout()
end

function Notification.update(id, opts)
  local i = indexOf(id); if not i then return end
  local entry = order[i]
  opts = opts or {}
  Safe.mutate(function()
    if not entry.frame then entry.pendingUpdate = opts; return end
    applyUpdate(entry, opts)
  end)
end

function Notification.promise(runner, opts)
  opts = opts or {}
  -- Register the runner Heartbeat:Once BEFORE calling loading() so that, when capability is absent,
  -- this handler is snapshotted first and fires before Safe's flush handler. The runner's
  -- Notification.update call then lands in the same Safe queue as the loading build, so the flush
  -- drains both in FIFO order: build frame first, then applyUpdate -- no extra Heartbeat needed.
  -- `pendingId` is set synchronously (before any Heartbeat fires) so the closure sees the real id.
  local pendingId
  RunService.Heartbeat:Once(function()
    local ok, res = pcall(runner)
    local dur = opts.Duration or 4000
    if ok then
      Notification.update(pendingId, { Type = "success", Title = msgText(opts.Success, res) or "Success", Duration = dur })
    else
      Notification.update(pendingId, { Type = "error", Title = msgText(opts.Error, res) or "Error", Duration = dur })
    end
    if opts.Finally then pcall(opts.Finally) end
  end)
  local id = Notification.loading({
    Title = msgText(opts.Loading) or "Loading…", Message = opts.Message, Theme = opts.Theme, AccentReg = opts.AccentReg })
  pendingId = id
  return id
end

-- Outward exit vector: away from the anchored edge (right stack slides right, a centred stack
-- slides back out through the edge it came from).
local function exitOffset(cfg, TK)
  if cfg.ax == 1 then return TK.exitSlide, 0 end
  if cfg.ax == 0 then return -TK.exitSlide, 0 end
  return 0, (cfg.ay == 0) and -TK.exitSlide or TK.exitSlide
end

function Notification.dismiss(id)
  local i = indexOf(id)
  if not i then return end
  -- Removed from the order FIRST: count() drops in the same tick, and the relayout below never
  -- touches a frame that is on its way out.
  local entry = table.remove(order, i)
  if #order == 0 then stopTicker() end
  if entry.onDismiss then pcall(entry.onDismiss) end
  -- Same Safe queue as the build, so a dismiss issued before a deferred build still runs after it
  -- (FIFO) and releases the themer registration + spin the build created.
  Safe.mutate(function()
    stopSpin(entry)
    releaseEntry(entry)
    local frame = entry.frame
    if not frame then Notification.relayout(); return end
    local TK = (entry.theme or DefaultTheme).Toast
    local cfg = POS[position] or POS["bottom-right"]
    local dx, dy = exitOffset(cfg, TK)
    local p = frame.Position
    local goal = { GroupTransparency = 1 }
    if p then goal.Position = UDim2.new(p.X.Scale, p.X.Offset + dx, p.Y.Scale, p.Y.Offset + dy) end
    -- A real exit (fade + slide out + shrink) instead of vanishing mid-frame; two tweens, and the
    -- destroy hangs off the fade so the frame is gone the moment the fold-out finishes.
    if entry.scale then
      Animate.to(entry.scale, "exit", { Scale = TK.exitScale }, Animate.EASING.exit, Animate.DIR.In)
    end
    Animate.toThen(frame, "exit", goal, function()
      frame:Destroy()
      Notification.relayout()
    end, Animate.EASING.exit, Animate.DIR.In)
  end)
end

function Notification.clearAll()
  for i = #order, 1, -1 do Notification.dismiss(order[i].id) end
  -- Window:Close() calls this next to Overlay.reset(), so drop the pin with the stack: it belongs
  -- to the window that set it, and a later window's toasts would otherwise inherit its UI scale.
  -- currentScale() then follows Overlay.scale() again, which the next SetUIScale writes first.
  pinnedScale = nil
end

function Notification.count() return #order end

-- UI scale forwarding (Window:SetUIScale). The UIScale lives on the toast container, NEVER on the
-- overlay root -- the click catcher's (1,0,1,0) size would stop covering the screen.
function Notification.setScale(n)
  if type(n) ~= "number" or n ~= n or n <= 0 then return currentScale() end
  pinnedScale = n
  if container and container.Parent ~= nil then
    Safe.mutate(function()
      local us = container:FindFirstChild("ContainerScale")
      if us then us.Scale = n end
    end)
  end
  return n
end

function Notification.setPosition(p)
  local key = tostring(p):lower():gsub("%s+", "-")
  if not POS[key] then return position end
  position = key
  if container and container.Parent ~= nil then
    Safe.mutate(function()
      local cfg = POS[position]
      container.AnchorPoint = Vector2.new(cfg.ax, cfg.ay)
      container.Position = containerPosition(cfg, frontTheme().Toast)
      Notification.relayout()
    end)
  end
  return position
end

return Notification
