-- Deps injected via Init(R). Sonner-style toasts: slide in from the right, stack
-- bottom-right (newest in front), older ones peek behind (scaled + faded); hover the
-- stack to expand into a full list. Each toast is a CanvasGroup so it can fade.
local Notification = {}
local Create, DefaultTheme, Maid, Overlay, Animate, Icons, Safe
local RunService = game:GetService("RunService")
local container
local order = {}   -- array of entries (oldest first, newest last)
local seq = 0
local expanded = false
local stepConn

function Notification.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Animate = R.Animate; Icons = R.Icons
  Safe = R.Safe
  container = nil
  -- Init is re-entrant (the test harness re-runs it per loadLib): drop the previous Heartbeat
  -- countdown so a fresh container never runs two tickers over the same `order`.
  if stepConn then stepConn:Disconnect() end
  stepConn = nil
  expanded = false
end

local enabled = true
function Notification.setEnabled(b) enabled = b ~= false end

local TYPE_COLOR = { info = "info", success = "success", warning = "warning", error = "destructive", loading = "info" }
local TYPE_ICON = { info = "info", success = "circle-check", warning = "triangle-alert", error = "circle-alert", loading = "loader" }
local GAP, PEEK = 8, 10

local position = "bottom-right"
local POS = {
  ["top-left"]      = { ax = 0,   ay = 0 },
  ["top-center"]    = { ax = 0.5, ay = 0 },
  ["top-right"]     = { ax = 1,   ay = 0 },
  ["bottom-left"]   = { ax = 0,   ay = 1 },
  ["bottom-center"] = { ax = 0.5, ay = 1 },
  ["bottom-right"]  = { ax = 1,   ay = 1 },
}
local function containerPosition(cfg)
  local cx = (cfg.ax == 0 and UDim.new(0, 16)) or (cfg.ax == 1 and UDim.new(1, -16)) or UDim.new(0.5, 0)
  local cy = (cfg.ay == 0) and UDim.new(0, 16) or UDim.new(1, -16)
  return UDim2.new(cx.Scale, cx.Offset, cy.Scale, cy.Offset)
end

local function ensureContainer()
  if container and container.Parent ~= nil then return container end
  local cfg = POS[position] or POS["bottom-right"]
  container = Create("Frame", {
    -- Height starts at 0 and is grown by relayout to wrap the actual toast stack. The container
    -- IS the MouseEnter/Leave hover hit-area, so it must NOT span the full screen height -- a tall
    -- strip would falsely trigger hover/expand whenever the pointer sits in that column (most
    -- visible at top-center/bottom-center, where the column runs down the middle of the screen).
    Name = "ToastContainer", BackgroundTransparency = 1, ZIndex = 1800,
    AnchorPoint = Vector2.new(cfg.ax, cfg.ay), Position = containerPosition(cfg), Size = UDim2.new(0, 300, 0, 0),
  })
  container.MouseEnter:Connect(function()
    expanded = true
    for _, e in ipairs(order) do e.paused = true end
    Notification.relayout()
  end)
  container.MouseLeave:Connect(function()
    expanded = false
    for _, e in ipairs(order) do e.paused = false end
    Notification.relayout()
  end)
  Overlay.mount(container)
  if not stepConn then
    stepConn = RunService.Heartbeat:Connect(function(dt)
      for i = #order, 1, -1 do
        local e = order[i]
        if e.frame and e.total and not e.paused then
          e.remaining = e.remaining - dt
          -- Heartbeat handlers lack the GUI capability on strict executors, so a raw write throws.
          -- pcall (not Safe.mutate) because this is a per-frame cosmetic write -- skip it cleanly when
          -- there's no capability rather than deferring 60 writes/sec. The countdown + dismiss below
          -- run on plain Lua state / Safe.mutate, so the toast still expires correctly.
          if e.bar then pcall(function() e.bar.Size = UDim2.new(math.max(0, e.remaining / e.total), 0, 0, 3) end) end
          if e.remaining <= 0 then Notification.dismiss(e.id) end
        end
      end
    end)
  end
  return container
end

-- position/scale/fade each toast based on its index from the bottom (newest = 0)
function Notification.relayout()
  local n = #order
  local cfg = POS[position] or POS["bottom-right"]
  local vdir = (cfg.ay == 0) and 1 or -1
  local y = 0
  for idx = n, 1, -1 do
    local e = order[idx]
    if not e.frame then
      -- GUI deferred to a later Heartbeat; skip until built (it relayouts itself when ready)
    else
      local i = n - idx -- 0 = newest (bottom-front)
      local scale, transp, visible, yoff
      if expanded then
        visible, scale, transp, yoff = true, 1, 0, y
        -- Use the toast's intrinsic content height (UIListLayout content + its all=10 padding),
        -- which is scale-independent -- so expanded gaps stay uniform even while the per-toast
        -- collapse scale is still animating to 1. Reading AbsoluteSize mid-animation gave the
        -- scaled (smaller) height and made the gaps jitter/overlap on hover.
        local lay = e.frame:FindFirstChildOfClass("UIListLayout")
        local acs = lay and lay.AbsoluteContentSize
        local h = (acs and acs.Y and acs.Y > 0 and acs.Y + 20) or (e.frame.AbsoluteSize and e.frame.AbsoluteSize.Y) or 60
        y = y + h + GAP
      else
        visible = i < 3
        scale = 1 - i * 0.05
        transp = i * 0.18
        yoff = i * PEEK
      end
      e.frame.Visible = visible
      e.frame.AnchorPoint = Vector2.new(cfg.ax, cfg.ay)
      Animate.to(e.frame, "base", { Position = UDim2.new(cfg.ax, 0, cfg.ay, vdir * yoff), GroupTransparency = transp }, Animate.EASING.smooth)
      Animate.to(e.scale, "base", { Scale = scale }, Animate.EASING.smooth)
    end
  end
  -- Size the container (the hover hit-area) to wrap the visible stack so MouseEnter only fires over
  -- the toasts, never the empty column above/below them. Set directly (not animated) so the hit-area
  -- never lags the pointer. Anchored at the edge, so growing height extends toward screen centre.
  if container then
    local h = 0
    if n > 0 then
      if expanded then
        h = math.max(0, y - GAP)            -- y accumulated a trailing GAP per toast
      else
        local front = order[n]              -- newest = front of the collapsed stack
        local fh = front and front.frame and front.frame.AbsoluteSize and front.frame.AbsoluteSize.Y or 0
        if fh <= 0 then fh = 60 end         -- fallback before first engine measure (and headless tests)
        h = fh + math.min(n - 1, 2) * PEEK  -- front toast + the (up to 2) peeking behind it
      end
    end
    container.Size = UDim2.new(0, 300, 0, h)
  end
end

local function indexOf(id) for i, e in ipairs(order) do if e.id == id then return i end end end

-- Semantic accent for a toast type, read from the LIVE palette so a reskin picks up the mode's
-- colour (the four type tokens are mode-invariant today, but a theme override may change them).
local function accentFor(theme, ty) return theme.Colors[TYPE_COLOR[ty]] or theme.Colors.info end

local function startCountdown(entry, total, accent, theme)
  local bar = Create("Frame", { Name = "Progress", BackgroundColor3 = accent, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 3), LayoutOrder = 99, Parent = entry.frame, Create.corner(2) })
  entry.total = total; entry.remaining = total; entry.paused = false; entry.bar = bar
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

-- Live re-skin (SetMode/SetAccent): every coloured part re-reads theme.Colors. Parts that
-- applyUpdate creates or replaces later (Message, Progress) are read off the entry at call time.
local function reskin(entry)
  local theme = entry.theme
  local accent = accentFor(theme, entry.type)
  entry.accent = accent
  entry.frame.BackgroundColor3 = theme.Colors.card
  if entry.stroke then entry.stroke.Color = theme.Colors.border end
  entry.titleLabel.TextColor3 = theme.Colors.foreground
  if entry.msgLabel then entry.msgLabel.TextColor3 = theme.Colors.mutedForeground end
  if entry.closeBtn then Icons.apply(entry.closeBtn, "x", theme.Colors.primary) end
  if entry.actionBtn then
    entry.actionBtn.BackgroundColor3 = theme.Colors.surface
    entry.actionBtn.TextColor3 = theme.Colors.foreground
  end
  if entry.bar then entry.bar.BackgroundColor3 = accent end
  -- Icons.apply only rewrites ImageColor3 when the glyph is unchanged, so a spinning loader is
  -- retinted without touching its Rotation.
  if entry.icon then Icons.apply(entry.icon, TYPE_ICON[entry.type] or "info", accent) end
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
  local entry = { id = id, onDismiss = opts.OnDismiss }
  order[#order + 1] = entry           -- reserve FIFO slot synchronously
  Safe.mutate(function()
    local ty = opts.Type or "info"
    local accent = accentFor(theme, ty)
    ensureContainer()
    local pcfg = POS[position] or POS["bottom-right"]
    local sx = (pcfg.ax == 1 and UDim.new(1, 320)) or (pcfg.ax == 0 and UDim.new(0, -320)) or UDim.new(0.5, 0)
    -- center toasts slide in vertically from the nearest edge: top-center from above (-60), bottom-center from below (+60)
    local sy = (pcfg.ax == 0.5) and UDim.new(pcfg.ay, ((pcfg.ay == 0) and -1 or 1) * 60) or UDim.new(pcfg.ay, 0)
    local toast = Create("CanvasGroup", {
      Name = "Toast", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0, GroupTransparency = 1,
      AnchorPoint = Vector2.new(pcfg.ax, pcfg.ay), Position = UDim2.new(sx.Scale, sx.Offset, sy.Scale, sy.Offset),
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = container,
      Create.corner(theme.Radius.md), Create.padding({ all = 10 }),
      Create.listLayout({ Padding = 4 }),
    })
    -- floating surface: opaque hairline (Stroke.floating), same border token as every other stroke
    local stroke = Create.stroke(theme.Colors.border, 1, theme.Stroke.floating)
    stroke.Parent = toast
    local scale = Instance.new("UIScale"); scale.Parent = toast
    toast:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
      -- property-changed handler -> engine thread without GUI capability on strict executors; relayout
      -- reads AbsoluteContentSize/AbsoluteSize raw, so marshal it through Safe.mutate. Always relayout
      -- (not only when expanded): the collapsed container height tracks the front toast's measured
      -- height, so the hover hit-area must update once the engine measures the toast.
      Safe.mutate(Notification.relayout)
    end)
    local titleRow = Create("Frame", { Name = "TitleRow", BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = toast })
    local tIcon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
      Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 0, 0.5, -8), Parent = titleRow })
    Icons.apply(tIcon, TYPE_ICON[ty] or "info", accent)
    local titleLabel = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Title or "",
      TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
      TextTruncate = Enum.TextTruncate.AtEnd,
      Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 24, 0, 0), Parent = titleRow })
    Create.text(titleLabel, theme, "label")
    local closeBtn = Create("ImageButton", { Name = "Close", AutoButtonColor = false, BackgroundTransparency = 1,
      Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -14, 0, 0), Parent = titleRow })
    Icons.apply(closeBtn, "x", theme.Colors.primary)
    closeBtn.MouseButton1Click:Connect(function() Notification.dismiss(id) end)
    local msgLabel
    if opts.Message then
      msgLabel = createMsgLabel(opts.Message, theme, toast)
    end
    local aBtn
    if opts.Action then
      local act = opts.Action
      aBtn = Create("TextButton", { Name = "Action", AutoButtonColor = false,
        BackgroundColor3 = theme.Colors.surface, Text = act.Text or act.Label or "Action",
        TextColor3 = theme.Colors.foreground,
        Size = UDim2.new(0, 96, 0, 24), LayoutOrder = 3, Parent = toast, Create.corner(theme.Radius.sm) })
      Create.text(aBtn, theme, "muted")
      aBtn.MouseButton1Click:Connect(function() if act.Callback then pcall(act.Callback) end; Notification.dismiss(id) end)
    end
    entry.frame = toast; entry.scale = scale; entry.stroke = stroke
    entry.icon = tIcon; entry.titleLabel = titleLabel; entry.closeBtn = closeBtn; entry.actionBtn = aBtn
    entry.theme = theme
    entry.type = ty; entry.accent = accent
    entry.msgLabel = msgLabel
    if entry.type == "loading" then entry.spin = Animate.spin(tIcon) end
    if entry.type ~= "loading" and (opts.Duration or 4000) > 0 then
      startCountdown(entry, (opts.Duration or 4000) / 1000, accent, theme)
    end
    -- A live toast follows SetMode/SetAccent through the window's themer; released in dismiss.
    -- Registered after the build so the closure never sees a half-built toast.
    if opts.AccentReg then entry.unreg = opts.AccentReg(function() reskin(entry) end) end
    Animate.pop(toast, "base")
    Notification.relayout()
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
  entry.type = newType; entry.accent = accent
  -- Cancel BEFORE re-applying the glyph: Cancel rests Rotation at 0 so the new (static) icon
  -- never lands mid-spin. A morph back to 'loading' restarts the spin.
  stopSpin(entry)
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
  end
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

function Notification.dismiss(id)
  local i = indexOf(id)
  if not i then return end
  local entry = table.remove(order, i)
  if entry.onDismiss then pcall(entry.onDismiss) end
  -- Same Safe queue as the build, so a dismiss issued before a deferred build still runs after it
  -- (FIFO) and releases the themer registration + spin the build created.
  Safe.mutate(function()
    stopSpin(entry)
    if entry.unreg then entry.unreg(); entry.unreg = nil end
    if entry.frame then entry.frame:Destroy() end
    Notification.relayout()
  end)
end

function Notification.clearAll()
  for i = #order, 1, -1 do Notification.dismiss(order[i].id) end
end

function Notification.count() return #order end

function Notification.setPosition(p)
  local key = tostring(p):lower():gsub("%s+", "-")
  if not POS[key] then return position end
  position = key
  if container and container.Parent ~= nil then
    Safe.mutate(function()
      local cfg = POS[position]
      container.AnchorPoint = Vector2.new(cfg.ax, cfg.ay)
      container.Position = containerPosition(cfg)
      Notification.relayout()
    end)
  end
  return position
end

return Notification
