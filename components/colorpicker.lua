-- Deps injected via Init(R). Swatch row + an overlay HSV picker (SV square + hue slider,
-- click/drag). Value persists as an {r,g,b} array (JSON-safe).
local ColorPicker = {}
local Create, DefaultTheme, Maid, Overlay, Flag, Animate, Safe, Recipes, Effects, Acrylic
local UserInputService = game:GetService("UserInputService")
function ColorPicker.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Flag = R.Flag
  Animate = R.Animate; Safe = R.Safe; Recipes = R.Recipes; Effects = R.Effects; Acrylic = R.Acrylic
end

-- Popover box in logical px (the UIScale below turns it into on-screen px): SV square 110 + gap
-- + the 16px hue slider, inside the host padding.
local POP_W, POP_H = 180, 152

local function frostAlpha(theme) return theme.Acrylic.popoverFrost end

-- Popover open/close motion. Animate.popIn/popOut rest a popover's UIScale at 1, which is right
-- until the window forwards a UI scale (2.22): a scaled popover must rest at Overlay.scale(), so
-- the scaled case runs the same curves and the same Motion tokens against `scale` instead.
local function popOpen(frame, theme, edge, scale)
  if scale == 1 then return Animate.popIn(frame, edge) end
  local us = frame:FindFirstChildOfClass("UIScale")
  if not us then return nil end
  if not Animate.isEnabled() then us.Scale = scale; return nil end
  local target = frame.Position
  us.Scale = scale * theme.Motion.exitScale
  local dy = (edge == "up") and theme.Motion.popSlide or -theme.Motion.popSlide
  frame.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + dy)
  Animate.to(frame, "fast", { Position = target }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
  return Animate.springTo(us, "base", { Scale = scale })
end

local function popShut(frame, theme, scale, onDone)
  if scale == 1 then return Animate.popOut(frame, onDone) end
  local us = frame:FindFirstChildOfClass("UIScale")
  if not us then if onDone then onDone() end; return nil end
  return Animate.toThen(us, "exit", { Scale = scale * theme.Motion.exitScale }, onDone,
    Animate.EASING.exit, Animate.DIR.In)
end

-- Color3 channels are .R/.G/.B (0-1 floats) in real Roblox.
local function toArr(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end
local function toColor(v)
  if type(v) == "table" and v[1] then return Color3.fromRGB(v[1], v[2], v[3]) end
  return v
end
local function rgbToHsv(c)
  local r, g, b = c.R, c.G, c.B
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d = mx - mn
  local hh = 0
  if d > 0 then
    if mx == r then hh = ((g - b) / d) % 6
    elseif mx == g then hh = (b - r) / d + 2
    else hh = (r - g) / d + 4 end
    hh = hh / 6
  end
  return hh, (mx == 0) and 0 or d / mx, mx
end
local function clamp01(n) if n < 0 then return 0 elseif n > 1 then return 1 end return n end

function ColorPicker.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local pad = theme.Spacing.gap -- popover UIPadding; padInset pulls the frost layers back over it
  local color = opts.Default or Color3.fromRGB(255, 255, 255)
  local hsvH, hsvS, hsvV = rgbToHsv(color)
  local popover
  local shadow    -- overlay sibling under the open popover; nil while Effect.shadowId is ''
  local popScale = 1 -- UI scale the popover was built with (Close folds back to IT, not to 1)
  local openMaid  -- per-OPEN connections: the popover is rebuilt on every Open, and the
                  -- UserInputService drag listeners used to pile up on the component maid
  local stopDrag  -- ends an in-flight SV/Hue drag from outside (SetDisabled, 2.8b)
  local posConn -- closes the popover when the control scrolls
  local onChanged = opts.Callback

  local hasDesc = opts.Description ~= nil and opts.Description ~= ""
  local btn = Create("TextButton", { Name = "ColorPicker", AutoButtonColor = false, Text = "",
    BackgroundColor3 = theme.Colors.surface, Size = UDim2.new(1, 0, 0, hasDesc and 50 or 34), LayoutOrder = opts.LayoutOrder or 0,
    Parent = opts.Parent, Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }) })
  -- TextTransparency is written explicitly: it is the rest value the disabled recipe returns to.
  local label = Create("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = opts.Text or "Color",
    TextColor3 = theme.Colors.foreground, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    Position = UDim2.new(0, 0, 0, hasDesc and 8 or 0), Size = UDim2.new(1, -40, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn })
  Create.text(label, theme, "label")
  if hasDesc then
    Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
      TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
      TextYAlignment = Enum.TextYAlignment.Top,
      Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -40, 0, 18), Parent = btn }), theme, "muted")
  end
  local swatch = Create("Frame", { Name = "Swatch", BackgroundColor3 = color, BackgroundTransparency = 0, BorderSizePixel = 0,
    Size = UDim2.new(0, 28, 0, 18), Position = UDim2.new(1, -28, 0.5, -9), Parent = btn, Create.corner(theme.Radius.sm) })
  Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = swatch })

  -- Parts the disabled state dims to Opacity.disabled, each with the value it rests at while
  -- enabled (2.8d: Recipes.disabled restores exactly that rest, so re-enabling is lossless).
  local DIM = { { swatch, "BackgroundTransparency", 0 }, { label, "TextTransparency", 0 } }
  local disabled = false
  -- `animated` = the state change (tweened through the recipe); instant = a themer replay, which
  -- must not tween inside a re-skin.
  local function paintDisabled(animated)
    if animated then
      Recipes.disabled(DIM, disabled, theme)
    else
      local a = disabled and theme.Opacity.disabled or 0
      for _, p in ipairs(DIM) do p[1][p[2]] = a end
    end
  end

  local function apply(v) color = toColor(v); Safe.mutate(function() swatch.BackgroundColor3 = color end) end
  local commit = Flag.bind(opts, toArr(color), apply)

  local api = { Frame = btn }
  function api.GetColor() return color end
  function api.SetColor(c) commit(toArr(c)); if onChanged then onChanged(color) end end

  function api.Open()
    if disabled or popover then return end
    local om = Maid.new()
    openMaid = om
    -- The window's UI scale reaches overlay children through Overlay.scale() (2.22): the UIScale
    -- goes on the popover root, and the placement maths gets the ON-SCREEN size so the flip and
    -- the clamp stay right. placePopover also gives the dropdown's flip/clamp to this popover,
    -- which used to sit blindly 36px below the control.
    local scale = Overlay.scale()
    popScale = scale
    local x, y, openUp = Overlay.placePopover(btn.AbsolutePosition, btn.AbsoluteSize, POP_W * scale, POP_H * scale)
    popover = Create("Frame", { Name = "ColorPopover", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0,
      Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, POP_W, 0, POP_H),
      ZIndex = Overlay.Z.popover, Create.corner(theme.Radius.md), Create.padding({ all = pad }),
      Create("UIScale", { Scale = scale }) })
    Create.stroke(theme.Colors.border, 1, theme.Stroke.floating).Parent = popover -- floating surface: opaque hairline (1.5)
    -- Frost: the same material as the dropdown. padInset = the host UIPadding, so the noise/sheen
    -- layers grow back over it and still reach the rounded edge instead of stopping 8px short.
    Acrylic.decorate(popover, theme, { transparency = frostAlpha(theme), edge = true,
      radius = theme.Radius.md, padInset = pad, strokeAlpha = theme.Stroke.floating })
    -- Depth: a SIBLING in the overlay root under the popover layer (a child would render above
    -- the popover's own fill). posConn closes the popover as soon as the control scrolls, so one
    -- Effects.place before mounting is enough — the layer never has to follow.
    local overlayRoot = Overlay.peek()
    shadow = overlayRoot and Effects.shadow(overlayRoot, theme,
      { name = "ColorPopoverShadow", level = "popover", zIndex = Overlay.Z.catcher }) or nil
    Effects.place(shadow, x, y, POP_W * scale, POP_H * scale, "popover", theme)

    -- SV square: hue-colored base + white(sat) overlay + black(value) overlay
    local sv = Create("ImageButton", { Name = "SV", AutoButtonColor = false,
      BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1), ZIndex = 1002, Size = UDim2.new(1, 0, 0, 110),
      Parent = popover, Create.corner(theme.Radius.sm), ClipsDescendants = true })
    local satOverlay = Create("Frame", { Name = "Sat", BackgroundColor3 = Color3.fromRGB(255, 255, 255),
      Size = UDim2.new(1, 0, 1, 0), ZIndex = 1003, Parent = sv,
      Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
    local valOverlay = Create("Frame", { Name = "Val", BackgroundColor3 = Color3.fromRGB(0, 0, 0),
      Size = UDim2.new(1, 0, 1, 0), ZIndex = 1004, Parent = sv,
      Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }) })
    local svDot = Create("Frame", { Name = "Dot", BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 1005,
      Size = UDim2.new(0, 8, 0, 8), AnchorPoint = Vector2.new(0.5, 0.5), Parent = sv, Create.corner(4) })
    -- Ring on both markers: a white dot vanishes over a pale corner of the SV square / the yellow
    -- band of the hue strip, so each one carries a hairline in the shell colour (2.11).
    local svRing = Create.stroke(theme.Colors.background, 1, theme.Acrylic.strokeAlpha); svRing.Parent = svDot

    -- hue slider with rainbow gradient
    local hue = Create("ImageButton", { Name = "Hue", AutoButtonColor = false, ZIndex = 1002,
      BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, 0, 0, 16),
      Position = UDim2.new(0, 0, 0, 120), Parent = popover, Create.corner(theme.Radius.sm) })
    Create("UIGradient", { Parent = hue, Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
      ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
      ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    }) })
    local hueDot = Create("Frame", { Name = "HueDot", BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 1003,
      Size = UDim2.new(0, 4, 1, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(hsvH, 0, 0.5, 0), Parent = hue, Create.corner(2) })
    local hueRing = Create.stroke(theme.Colors.background, 1, theme.Acrylic.strokeAlpha); hueRing.Parent = hueDot

    local function refreshUI()
      sv.BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1)
      svDot.Position = UDim2.new(hsvS, 0, 1 - hsvV, 0)
      hueDot.Position = UDim2.new(hsvH, 0, 0.5, 0)
      api.SetColor(Color3.fromHSV(hsvH, hsvS, hsvV))
    end
    refreshUI()

    local dragTarget
    stopDrag = function() dragTarget = nil end
    local function updateFromSV(px, py)
      local p, sz = sv.AbsolutePosition, sv.AbsoluteSize
      hsvS = clamp01(((px - (p and p.X or 0)) / ((sz and sz.X) or 1)))
      hsvV = 1 - clamp01(((py - (p and p.Y or 0)) / ((sz and sz.Y) or 1)))
      refreshUI()
    end
    local function updateFromHue(px)
      local p, sz = hue.AbsolutePosition, hue.AbsoluteSize
      hsvH = clamp01(((px - (p and p.X or 0)) / ((sz and sz.X) or 1)))
      refreshUI()
    end
    -- Every listener below goes to the PER-OPEN maid: the popover is rebuilt on each Open, so
    -- giving them to the component maid leaked one InputChanged/InputEnded pair per open.
    om:Give(sv.InputBegan:Connect(function(input)
      if disabled then return end
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragTarget = "sv"; updateFromSV(input.Position.X, input.Position.Y)
      end
    end))
    om:Give(hue.InputBegan:Connect(function(input)
      if disabled then return end
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragTarget = "hue"; updateFromHue(input.Position.X)
      end
    end))
    om:Give(UserInputService.InputChanged:Connect(function(input)
      if not dragTarget or disabled then return end
      if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragTarget == "sv" then updateFromSV(input.Position.X, input.Position.Y) else updateFromHue(input.Position.X) end
      end
    end))
    om:Give(UserInputService.InputEnded:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragTarget = nil end
    end))
    om:Give(function() stopDrag = nil end)

    -- close on scroll: the screen-space popover would otherwise detach or float
    -- outside the window once the control leaves the content viewport.
    posConn = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() Safe.mutate(api.Close) end)
    Overlay.mount(popover)
    Overlay.trackPopover(api.Close)
    -- 2.11: while it is open the popover holds a themer registration of its OWN. The control's
    -- closure below only knows the swatch row, so a SetMode/SetAccent landing mid-open would
    -- otherwise leave the popover (fill, hairline, rim, frost stack, shadow alpha, marker rings)
    -- wearing the palette it was born with. Instant writes -- a re-skin replays state, it is not
    -- a transition. Owned by the per-open maid, which api.Close drains synchronously before the
    -- fold starts, so nothing can paint a frame that is being destroyed.
    local popFrame, popShadow = popover, shadow
    local unreg = opts.AccentReg and opts.AccentReg(function()
      Acrylic.reskin(popFrame, theme, { transparency = frostAlpha(theme), edge = true,
        radius = theme.Radius.md, padInset = pad, strokeAlpha = theme.Stroke.floating })
      Effects.reskin(popShadow, theme, "shadow")   -- nil-tolerant: Effect.shadowId is '' by default
      svRing.Color = theme.Colors.background
      hueRing.Color = theme.Colors.background
    end)
    if unreg then om:Give(unreg) end
    -- Grows out of the swatch row; the final Position is the computed one, so layout code
    -- reading popover.Position right after Open still sees it.
    popOpen(popover, theme, openUp and "up" or "down", scale)
  end

  -- Synchronous for the CALLER: the reference is dropped, the per-open connections are cut and
  -- the popover untracked before any motion starts, so a catcher click, a scroll or a second
  -- Close sees no popover while the DETACHED frame is still folding away.
  function api.Close()
    local pv, sh, om = popover, shadow, openMaid
    popover, shadow, openMaid = nil, nil, nil
    if posConn then posConn:Disconnect(); posConn = nil end
    if om then om:DoCleanup() end
    Overlay.untrackPopover(api.Close)
    if not pv then return end
    popShut(pv, theme, popScale, function() pv:Destroy(); if sh then sh:Destroy() end end)
  end
  function api.Destroy() api.Close(); maid:DoCleanup() end

  -- Disabled dims the swatch + label and blocks Open; an in-flight drag is ended rather than
  -- frozen mid-gesture, and the last value is kept (2.8b).
  local function setDisabled(b)
    disabled = b and true or false
    Safe.mutate(function()
      if disabled and stopDrag then stopDrag() end
      paintDisabled(true)
    end)
  end
  function api.SetDisabled(b) setDisabled(b) end

  maid:Give(btn.MouseButton1Click:Connect(function()
    if disabled then return end
    if popover then api.Close() else api.Open() end
  end))
  maid:Give(btn)
  maid:Give(function() api.Close() end)
  if opts.Disabled then setDisabled(true) end

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    btn.BackgroundColor3 = theme.Colors.surface
    local lab = btn:FindFirstChild("Label"); if lab then lab.TextColor3 = theme.Colors.foreground end
    local de = btn:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
    local st = swatch:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
    paintDisabled()
  end)) end

  return api
end

return ColorPicker
