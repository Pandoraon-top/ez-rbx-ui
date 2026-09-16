-- Deps injected via Init(R). Dialog.open(opts) builds a modal alert dialog in the overlay.
-- Mirrors shadcn AlertDialog: modal, non-dismissible (no backdrop-click dismissal, no X button) --
-- the user picks a footer button. Optional header icon (inline / badge), a device-aware footer, and
-- open/close motion are layered on by the builders below.
local Dialog = {}
local Create, DefaultTheme, Maid, Overlay, Button, Acrylic, Animate, Icons, Device
function Dialog.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Button = R.Button; Acrylic = R.Acrylic
  Animate = R.Animate; Icons = R.Icons; Device = R.Device
end

local MARGIN = 24 -- min gap between the card and the edge of its container when clamping width

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
    TextColor3 = theme.Colors.foreground, TextXAlignment = xAlign, ZIndex = 1502, Parent = parent })
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
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 1502, Parent = card })
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, theme.Spacing.gap),
      HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = header })
    parts.badge = Create("Frame", { Name = "IconBadge", BackgroundColor3 = theme.Colors.surface,
      Size = UDim2.new(0, 40, 0, 40), LayoutOrder = 1, ZIndex = 1502, Parent = header, Create.corner(theme.Radius.md) })
    parts.icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 20, 0, 20), ZIndex = 1503, Parent = parts.badge })
    Icons.apply(parts.icon, opts.Icon, iconColor())
    parts.title = titleLabel(header, theme, opts, Enum.TextXAlignment.Center,
      { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2 })
    return true, parts
  elseif opts.Icon then
    local gap = theme.Spacing.icon
    local header = Create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22),
      LayoutOrder = 1, ZIndex = 1502, Parent = card })
    parts.icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
      Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), ZIndex = 1502, Parent = header })
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
local function buildFooter(card, theme, buttons, touch, handle, maid, accentReg)
  local n = #buttons
  local row = Create("Frame", { Name = "Buttons", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, touch and 0 or 34),
    AutomaticSize = touch and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
    LayoutOrder = 3, ZIndex = 1502, Parent = card })
  Create("UIListLayout", {
    FillDirection = touch and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
    HorizontalAlignment = touch and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, theme.Spacing.gap), Parent = row })
  for i, b in ipairs(buttons) do
    local order = touch and (n - i + 1) or i
    local btn = Button.new({ Parent = row, LayoutOrder = order, Theme = theme, Text = b.Text or "OK",
      Variant = b.Variant, Icon = b.Icon, AutoWidth = not touch, AccentReg = accentReg,
      Callback = function() if b.Callback then b.Callback() end; handle.Close() end })
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

  local dim = Create("TextButton", { Name = "Dialog", AutoButtonColor = false, Text = "",
    BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0), ZIndex = 1500, Modal = opts.Modal ~= false })
  local card = Create("Frame", { Name = "Card", Size = UDim2.new(0, width, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), ZIndex = 1501, Parent = dim,
    Create.corner(theme.Radius.lg), Create.padding({ all = theme.Spacing.pad }),
    Create.listLayout({ Padding = theme.Spacing.gap }) })
  Acrylic.decorate(card, theme, cardSkin(theme))

  local centered, parts = buildHeader(card, theme, opts)
  local message
  if opts.Message then
    message = Create("TextLabel", { Name = "Message", BackgroundTransparency = 1, Text = opts.Message,
      TextColor3 = theme.Colors.mutedForeground,
      TextXAlignment = centered and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left, TextWrapped = true,
      TextYAlignment = Enum.TextYAlignment.Top,
      Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 1502, Parent = card })
    Create.text(message, theme, "body")
  end

  -- Live re-skin (SetMode/SetAccent) while the dialog is open: card fill + stroke through the
  -- acrylic painter, then every text/icon part from the live palette. Released with the maid on Close.
  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    Acrylic.reskin(card, theme, cardSkin(theme))
    parts.title.TextColor3 = theme.Colors.foreground
    if message then message.TextColor3 = theme.Colors.mutedForeground end
    if parts.badge then parts.badge.BackgroundColor3 = theme.Colors.surface end
    if parts.icon then Icons.apply(parts.icon, opts.Icon, parts.iconColor()) end
  end)) end

  local closing = false
  function handle.Close()
    if closing then return end
    closing = true
    dim.Modal = false
    dim.Active = false
    local us = card:FindFirstChildOfClass("UIScale")
    if us then Animate.to(us, "fast", { Scale = 0.92 }) end
    Animate.toThen(dim, "fast", { BackgroundTransparency = 1 }, function() maid:DoCleanup(); dim:Destroy() end)
  end
  buildFooter(card, theme, buttons, touch, handle, maid, opts.AccentReg)

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
  Animate.to(dim, "base", { BackgroundTransparency = (opts.Modal == false) and 1 or 0.5 }) -- fade the scrim in
  Animate.pop(card, "base") -- pop the card in
  return handle
end

return Dialog
