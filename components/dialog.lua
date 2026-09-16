-- Deps injected via Init(R). Dialog.open(opts) builds a modal alert dialog in the overlay.
-- Mirrors shadcn AlertDialog: modal, non-dismissible by backdrop click (no X button) -- the user
-- picks a footer button, presses Escape/B (close) or Return/A (the primary button). Optional
-- header icon (inline / badge), a device-aware footer, and open/close motion are layered on below.
local Dialog = {}
local Create, DefaultTheme, Maid, Overlay, Button, Acrylic, Animate, Icons, Device, Effects, Theme
local UserInputService = game:GetService("UserInputService")
local KC = Enum.KeyCode
-- Open dialogs, innermost last. Only the top one answers the keyboard. Kept here (not just as an
-- Overlay depth) so a torn-down harness generation can never answer a key aimed at a live dialog.
local stack = {}
-- The input object a dialog has already acted on. Every open dialog listens to the same signal and
-- they all run in ONE dispatch, so without this an Escape that closes the inner dialog would still
-- be seen by the outer one (now the top of the stack) and close it in the same frame.
local handledInput = nil

function Dialog.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Button = R.Button; Acrylic = R.Acrylic
  Animate = R.Animate; Icons = R.Icons; Device = R.Device; Effects = R.Effects; Theme = R.Theme
  for i = #stack, 1, -1 do stack[i] = nil end
  handledInput = nil
end

local MARGIN = 24     -- min gap between the card and the edge of its container when clamping width
local CLOSE_SCALE = 0.92  -- close zoom; no Motion token holds it (enterScale 0.94 / exitScale 0.96)
local BADGE_TINT = 0.15   -- surface mixed this far toward the icon colour; no theme token yet

-- Card 1501, content 1502, badge glyph 1503 -- all relative to the shared modal layer.
local function zOf(n) return Overlay.Z.modal + n end
local function mix(theme, a, b, t) return (theme.mix or Theme.mix)(a, b, t) end
local function modeVal(theme, tok) return (theme.modeVal or Theme.modeVal)(theme, tok) end
-- A destructive dialog must read before the button row does: the badge carries a little of the
-- icon's colour instead of the neutral surface.
local function badgeColor(theme, icon) return mix(theme, theme.Colors.surface, icon, BADGE_TINT) end

-- Card width: opts.Width (default 320), clamped to the container width minus margins when known.
local function resolveWidth(opts)
  local want = opts.Width or 320
  local avail
  if opts.Window and opts.Window.Main then
    local s = opts.Window.Main.AbsoluteSize; avail = s and s.X
  else
    local vp = Overlay.viewport(); avail = vp and vp.X
  end
  if avail and avail > 0 then
    local max = avail - MARGIN * 2
    if max > 0 and want > max then want = max end
  end
  return want
end

-- Card surface opts shared by decorate (build) and reskin (SetMode/SetAccent): opaque, with the
-- floating hairline alpha rather than the acrylic default so the card reads as a solid sheet.
local function cardSkin(theme) return { solid = true, strokeAlpha = theme.Stroke.floating } end

-- Header title: one TextLabel in every header shape, differing only in alignment + geometry.
local function titleLabel(parent, theme, opts, xAlign, props)
  local lbl = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Title or "Dialog",
    TextColor3 = theme.Colors.foreground, TextXAlignment = xAlign, ZIndex = zOf(2), Parent = parent })
  for k, v in pairs(props) do lbl[k] = v end
  return Create.text(lbl, theme, "title")
end

-- Header: one of three shapes -- badge (icon square above a centred title), inline (small icon left
-- of the title), or a plain left-aligned title. Returns whether the header is centred so the
-- message can match its alignment, plus the coloured parts the reskin closure repaints.
local function buildHeader(card, theme, opts)
  -- IconColor is a caller override; without one the tint follows theme.Colors.foreground live
  local function iconColor() return opts.IconColor or theme.Colors.foreground end
  local parts = { iconColor = iconColor }
  if opts.Icon and opts.IconBadge then
    local header = Create("Frame", { Name = "Header", BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = zOf(2), Parent = card })
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, theme.Spacing.gap),
      HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = header })
    parts.badge = Create("Frame", { Name = "IconBadge", BackgroundColor3 = badgeColor(theme, iconColor()),
      Size = UDim2.new(0, 40, 0, 40), LayoutOrder = 1, ZIndex = zOf(2), Parent = header, Create.corner(theme.Radius.md) })
    parts.icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 20, 0, 20), ZIndex = zOf(3), Parent = parts.badge })
    Icons.apply(parts.icon, opts.Icon, iconColor())
    parts.title = titleLabel(header, theme, opts, Enum.TextXAlignment.Center,
      { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2 })
    return true, parts
  elseif opts.Icon then
    local gap = theme.Spacing.icon
    local header = Create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22),
      LayoutOrder = 1, ZIndex = zOf(2), Parent = card })
    parts.icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
      Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), ZIndex = zOf(2), Parent = header })
    Icons.apply(parts.icon, opts.Icon, iconColor())
    parts.title = titleLabel(header, theme, opts, Enum.TextXAlignment.Left,
      { Position = UDim2.new(0, 16 + gap, 0, 0), Size = UDim2.new(1, -(16 + gap), 1, 0) })
    return false, parts
  else
    parts.title = titleLabel(card, theme, opts, Enum.TextXAlignment.Left,
      { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 })
    return false, parts
  end
end

-- Footer: non-touch -> right-aligned, content-width buttons (Action rightmost). Touch -> full-width
-- buttons stacked vertically and reversed, so the primary Action sits on top (shadcn flex-col-reverse).
-- Buttons own their themer registration (AccentReg) and release it through the dialog maid.
local function buildFooter(card, theme, buttons, touch, fire, maid, accentReg)
  local n = #buttons
  local row = Create("Frame", { Name = "Buttons", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, touch and 0 or 34),
    AutomaticSize = touch and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
    LayoutOrder = 4, ZIndex = zOf(2), Parent = card })
  Create("UIListLayout", {
    FillDirection = touch and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
    HorizontalAlignment = touch and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, theme.Spacing.gap), Parent = row })
  for i, b in ipairs(buttons) do
    local order = touch and (n - i + 1) or i
    local btn = Button.new({ Parent = row, LayoutOrder = order, Theme = theme, Text = b.Text or "OK",
      Variant = b.Variant, Icon = b.Icon, AutoWidth = not touch, AccentReg = accentReg,
      Callback = function() fire(b) end })
    maid:Give(btn)
  end
end

function Dialog.open(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local buttons = opts.Buttons or { { Text = "OK" } }
  local handle = {}
  local touch = Device and Device.IsTouch() or false
  local width = resolveWidth(opts)
  local modal = opts.Modal ~= false
  -- A dialog takes the screen: a dropdown left open underneath would float over the scrim.
  Overlay.closeAll()
  -- Stacked dialogs: only the FIRST paints a scrim (0.5 over 0.5 would read as 0.75) and only the
  -- innermost answers the keyboard.
  local depth = Overlay.pushDialog()
  local function scrimAlpha() return modeVal(theme, theme.Opacity.dialogScrim) end
  local scrimGoal = (modal and depth == 1) and scrimAlpha() or 1

  local dim = Create("TextButton", { Name = "Dialog", AutoButtonColor = false, Text = "",
    BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0), ZIndex = Overlay.Z.modal, Modal = modal })
  -- CanvasGroup so the whole card (fill, stroke, text, buttons) fades as ONE piece instead of a
  -- dozen independently tweened transparencies.
  local card = Create("CanvasGroup", { Name = "Card", Size = UDim2.new(0, width, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), ZIndex = zOf(1), Parent = dim,
    Create.corner(theme.Radius.lg), Create.padding({ all = theme.Spacing.pad }),
    Create.listLayout({ Padding = theme.Spacing.gap }) })
  -- ONE UIScale carries both jobs: the UI scale (2.22 -- standalone only, a window-scoped dialog
  -- already lives inside Main and must not scale twice) and the enter/exit zoom on top of it.
  local base = opts.Window and 1 or Overlay.scale()
  local us = Create("UIScale", { Scale = base * theme.Motion.enterScale, Parent = card })
  Acrylic.decorate(card, theme, cardSkin(theme))
  local stroke = card:FindFirstChildOfClass("UIStroke")
  Effects.rim(stroke, theme)
  -- Shadow is a SIBLING of the card at the modal layer (card is +1), so it never covers it. The
  -- card is AutomaticSize, so its geometry is tracked through the Absolute* signals.
  local shadow = Effects.shadow(dim, theme, { name = "DialogShadow", level = "dialog", zIndex = Overlay.Z.modal })
  if shadow then shadow.ImageTransparency = 1 end

  local centered, parts = buildHeader(card, theme, opts)
  local message
  if opts.Message then
    message = Create("TextLabel", { Name = "Message", BackgroundTransparency = 1, Text = opts.Message,
      TextColor3 = theme.Colors.mutedForeground,
      TextXAlignment = centered and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left, TextWrapped = true,
      TextYAlignment = Enum.TextYAlignment.Top,
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = zOf(2), Parent = card })
    Create.text(message, theme, "body")
  end

  -- Hairline between the body and the footer (pointer UIs only: the touch footer is a full-width
  -- stack where a rule reads as clutter). A row of the card's UIListLayout, hence LayoutOrder 3.
  local rule
  if not touch then
    rule = Create("Frame", { Name = "FooterRule", BackgroundColor3 = theme.Colors.border,
      BackgroundTransparency = theme.Stroke.divider, BorderSizePixel = 0,
      Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 3, ZIndex = zOf(2), Parent = card })
  end

  local closing = false
  -- Live re-skin (SetMode/SetAccent) while the dialog is open: card fill + stroke through the
  -- acrylic painter, then every text/icon part from the live palette. Released with the maid on Close.
  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    Acrylic.reskin(card, theme, cardSkin(theme))
    Effects.rim(stroke, theme)                 -- per-mode edge alphas
    Effects.reskin(shadow, theme, "shadow")    -- nil-tolerant
    if modal and depth == 1 and not closing then dim.BackgroundTransparency = scrimAlpha() end
    if rule then rule.BackgroundColor3 = theme.Colors.border end
    parts.title.TextColor3 = theme.Colors.foreground
    if message then message.TextColor3 = theme.Colors.mutedForeground end
    if parts.badge then parts.badge.BackgroundColor3 = badgeColor(theme, parts.iconColor()) end
    if parts.icon then Icons.apply(parts.icon, opts.Icon, parts.iconColor()) end
  end)) end

  local function popSelf()
    for i = #stack, 1, -1 do if stack[i] == handle then table.remove(stack, i); break end end
  end

  function handle.Close()
    if closing then return end
    closing = true
    popSelf()
    Overlay.popDialog()
    dim.Modal = false
    dim.Active = false
    -- Fold out: shrink + fade + drop, scrim last so the card is gone before the room lights up.
    Animate.to(us, "exit", { Scale = base * CLOSE_SCALE }, Animate.EASING.exit, Animate.DIR.In)
    Animate.to(card, "exit", { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, theme.Motion.dialogDrop) },
      Animate.EASING.exit, Animate.DIR.In)
    if shadow then Animate.to(shadow, "exit", { ImageTransparency = 1 }, Animate.EASING.exit, Animate.DIR.In) end
    Animate.toThen(dim, "exit", { BackgroundTransparency = 1 }, function() maid:DoCleanup(); dim:Destroy() end,
      Animate.EASING.exit, Animate.DIR.In)
  end

  -- A footer button (and Return/A) runs its callback and then closes.
  local function fire(b)
    if b and b.Callback then b.Callback() end
    handle.Close()
  end
  buildFooter(card, theme, buttons, touch, fire, maid, opts.AccentReg)

  maid:Give(dim)
  -- Scope the backdrop to the owning window when one is given (its api exposes .Main), so the
  -- scrim covers only the window frame (rounded to match it). Standalone dialogs fall back to the
  -- global screen overlay, shared with dropdowns/colorpickers that want the full screen.
  local winFrame = opts.Window and opts.Window.Main
  if winFrame then
    Create.corner(theme.Radius.window).Parent = dim
    dim.Parent = winFrame
  else
    Overlay.mount(dim)
  end
  if shadow then Effects.follow(shadow, card, "dialog", theme, maid) end

  -- Escape / gamepad B closes; Return / gamepad A fires the LAST (primary) button. gameProcessed
  -- input (chat, a focused TextBox) is ignored, and only the innermost dialog reacts.
  stack[#stack + 1] = handle
  maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or closing then return end
    if handledInput ~= nil and handledInput == input then return end
    -- Torn down by its owner rather than by Close() (a window Close destroys the whole Main
    -- subtree): release the slot -- without this the dead dialog would sit on top of the stack and
    -- swallow every later Escape. Roblox-safe liveness check: a destroyed Instance has Parent nil.
    if dim.Parent == nil then handle.Close(); return end
    -- The stack alone answers "am I the innermost LIVE dialog". `depth` is captured once at open
    -- and never moves, while Overlay.dialogDepth() falls every time ANY dialog closes -- so
    -- comparing them would deafen a nested dialog forever as soon as its opener closed first
    -- (a footer button whose callback opens a confirm: fire() runs the callback, THEN closes).
    if stack[#stack] ~= handle then return end
    local k = input and input.KeyCode
    if k == nil then return end
    if k == KC.Escape or k == KC.ButtonB then
      handledInput = input; handle.Close()
    elseif k == KC.Return or k == KC.ButtonA then
      handledInput = input; fire(buttons[#buttons])
    end
  end))

  -- Unfold: fade + zoom from Motion.enterScale + a rise of Motion.dialogRise (shadcn fade-zoom-95).
  card.Position = UDim2.new(0.5, 0, 0.5, theme.Motion.dialogRise)
  Animate.to(dim, "base", { BackgroundTransparency = scrimGoal })
  Animate.to(card, "base", { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) }, Animate.EASING.smooth)
  Animate.springTo(us, "enter", { Scale = base })
  if shadow then Animate.to(shadow, "base", { ImageTransparency = (theme.fx or Theme.fx)(theme).shadow }) end
  return handle
end

return Dialog
