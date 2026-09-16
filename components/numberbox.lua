-- Deps injected via Init(R).
local RunService = game:GetService("RunService")
local NumberBox = {}
local Create, DefaultTheme, Maid, Icons, Flag, Numfmt, Safe, Animate, Recipes

function NumberBox.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Icons = R.Icons; Flag = R.Flag; Numfmt = R.Numfmt; Safe = R.Safe
  Animate = R.Animate; Recipes = R.Recipes
end

function NumberBox.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local minV, maxV, step = opts.Min, opts.Max, opts.Step or 1
  local value = opts.Default or 0
  local hasLabel = opts.Text ~= nil and opts.Text ~= ""
  local hasDesc = opts.Description ~= nil and opts.Description ~= ""
  local rowH = (not hasLabel) and 30 or (hasDesc and 56 or 46)
  -- SetEnabled blocks USER input only (steppers, wheel, typing): SetValue/Flag.bind restores keep
  -- updating value and visuals while disabled (plan 2.8 contract a).
  local enabled = true
  local hovering = false               -- pointer really over the Box (wheel gate)

  local function clamp(n)
    n = tonumber(n) or value
    if minV then n = math.max(minV, n) end
    if maxV then n = math.min(maxV, n) end
    return n
  end

  local root = Create("Frame", { Name = "NumberBoxRow", BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
    Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
    Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }) })
  if hasLabel then
    Create.text(Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Text,
      TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
      Position = UDim2.new(0, 0, 0, hasDesc and 6 or 0),
      Size = UDim2.new(0.5, -8, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = root }), theme, "label")
    if hasDesc then
      Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
        TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(0.5, -8, 0, 26), Parent = root }), theme, "muted")
    end
  end
  local box = Create("Frame", { Name = "Box", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0,
    Position = hasLabel and UDim2.new(0.5, 4, 0.5, -15) or UDim2.new(0, 0, 0, 0),
    Size = hasLabel and UDim2.new(0.5, -4, 0, 30) or UDim2.new(1, 0, 0, 30),
    Parent = root, Create.corner(theme.Radius.input) })
  -- the Box's only UIStroke: the focus recipe owns its Thickness, strokeColor() its Color
  local boxStroke = Create.stroke(theme.Colors.border, 1); boxStroke.Parent = box
  -- +/- are structural glyphs: they rest at Icon.structural (muted), never the accent (1.4)
  local function structural() return theme.Colors[theme.Icon.structural] end
  local function stepBtn(name, icon, x)
    local b = Create("ImageButton", { Name = name, AutoButtonColor = false, BackgroundColor3 = theme.Colors.surface,
      Size = UDim2.new(0, 26, 1, -6), Position = x, Parent = box, Create.corner(theme.Radius.sm) })
    local img = Create("ImageLabel", { BackgroundTransparency = 1, ImageTransparency = 0, Size = UDim2.new(0, 14, 0, 14),
      Position = UDim2.new(0.5, -7, 0.5, -7), Parent = b })
    Icons.apply(img, icon, structural())
    -- The wash sits at ZIndex 0 INSIDE the button: above the button's own fill, below the glyph
    -- (Sibling behaviour), so the +/- answer a pointer without a second surface in the Box.
    local hover = Recipes.hover(b, { theme = theme, host = b, corner = theme.Radius.sm, kind = "wash" })
    maid:Give(hover.disconnect)
    -- Press squashes the GLYPH, never the button: the shared recipe's Motion.pressScale keeps the
    -- +/- feeling like every other control, and the button keeps the 26px hit area it draws.
    maid:Give(Recipes.press(b, img, { theme = theme }).disconnect)
    return b, img, hover
  end
  local minus, minusImg, minusHover = stepBtn("Minus", "minus", UDim2.new(0, 3, 0.5, -12))
  local plus, plusImg, plusHover = stepBtn("Plus", "plus", UDim2.new(1, -29, 0.5, -12))
  local input = Create.text(Create("TextBox", { Name = "Input", BackgroundTransparency = 1, Text = tostring(value),
    TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false,
    Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -64, 1, 0), Parent = box }), theme, "body")

  local atMin, atMax = false, false
  -- A glyph at its bound reads as disabled: it fades to Opacity.disabled over Motion.fast instead
  -- of swapping colour. The last state is remembered per glyph so a themer re-derive or a
  -- SetValue that never crosses a bound spends no tween on an unchanged goal.
  local dimmed = { [minusImg] = false, [plusImg] = false }
  -- A disabled control dims every glyph, so the whole-control dim outranks the per-bound one; the
  -- bound state is still recorded, which is exactly the rest Recipes.disabled restores on enable.
  local function glyphAlpha(img) return (dimmed[img] or not enabled) and theme.Opacity.disabled or 0 end
  local function dim(img, off)
    if dimmed[img] == off then return end
    dimmed[img] = off
    Animate.to(img, "fast", { ImageTransparency = glyphAlpha(img) })
  end
  local function updateBounds()
    atMin = minV ~= nil and value <= minV
    atMax = maxV ~= nil and value >= maxV
    Safe.mutate(function()
      dim(minusImg, atMin); minus.Active = not atMin
      dim(plusImg, atMax); plus.Active = not atMax
    end)
  end

  local function fmt(n)
    return Numfmt.format(n, { Format = opts.Format, Decimals = opts.Decimals, Prefix = opts.Prefix, Suffix = opts.Suffix })
  end
  local focused = false
  -- single source of the Box stroke colour, read by the focus recipe and the themer closure alike
  local function strokeColor(f) return f and theme.Colors.ring or theme.Colors.border end
  local function render() Safe.mutate(function() input.Text = focused and tostring(value) or fmt(value) end) end
  local function apply(n) value = clamp(n); render(); updateBounds() end
  local commit = Flag.bind(opts, clamp(opts.Default or 0), apply)
  local function set(n) commit(clamp(n)); if opts.Callback then opts.Callback(value) end end

  -- A press refused at Min/Max bumps the Box Motion.bumpPx toward the side the user pushed and
  -- returns to the EXACT starting Position table (no drift). Motion off = no bump at all, and a
  -- bump already in flight is never restarted (its rest would be the displaced offset).
  local bumping = false
  local function bump(dir)
    if bumping or dir == nil or not Animate.isEnabled() then return end
    local rest = box.Position
    bumping = true
    Animate.chain({
      { box, "press", { Position = UDim2.new(rest.X.Scale, rest.X.Offset + dir * theme.Motion.bumpPx,
        rest.Y.Scale, rest.Y.Offset) }, Animate.EASING.snap, Animate.DIR.Out },
      { box, "press", { Position = rest }, Animate.EASING.snap, Animate.DIR.Out },
    }, function() bumping = false end)
  end

  -- SetEnabled: surface dim + input guards. SetLocked (the host's scrim) is a separate flag and
  -- neither of them clears the other; Recipes.disabled keeps each part's rest so a glyph that was
  -- dimmed at a bound comes back dimmed.
  local function setEnabled(b)
    b = b and true or false
    if enabled == b then return end
    enabled = b
    Safe.mutate(function()
      input.TextEditable = b
      Recipes.disabled({
        { box, "BackgroundTransparency", 0 },
        { minusImg, "ImageTransparency", dimmed[minusImg] and theme.Opacity.disabled or 0 },
        { plusImg, "ImageTransparency", dimmed[plusImg] and theme.Opacity.disabled or 0 },
      }, not b, theme)
    end)
  end

  local function holdRepeat(btn, stepFn, atBoundFn, dir)
    local conn, held
    local function stop()
      held = false
      if conn then conn:Disconnect(); conn = nil end
    end
    maid:Give(btn.MouseButton1Down:Connect(function()
      if not enabled then return end
      if atBoundFn() then bump(dir); return end
      held = true
      stepFn()                                  -- immediate first step
      local elapsed, since = 0, 0
      conn = RunService.Heartbeat:Connect(function(dt)
        if not held then return end
        elapsed = elapsed + dt
        if elapsed < 0.35 then return end       -- initial hold delay
        since = since + dt
        local interval = math.max(0.03, 0.12 - (elapsed - 0.35) * 0.06)  -- accelerate
        if since >= interval then
          since = 0
          if atBoundFn() then stop(); return end
          stepFn()
        end
      end)
    end))
    maid:Give(btn.MouseButton1Up:Connect(stop))
    maid:Give(btn.MouseLeave:Connect(stop))
    maid:Give(stop)
  end
  holdRepeat(minus, function() set(value - step) end, function() return atMin end, -1)
  holdRepeat(plus, function() set(value + step) end, function() return atMax end, 1)
  maid:Give(input.Focused:Connect(function() focused = true; input.Text = tostring(value) end))
  maid:Give(input.FocusLost:Connect(function()
    focused = false
    local parsed = Numfmt.parse(input.Text, { Prefix = opts.Prefix, Suffix = opts.Suffix })
    if parsed ~= nil then set(parsed) else render() end
  end))
  maid:Give(Recipes.focus(boxStroke, input, strokeColor, { theme = theme }).disconnect)
  -- Wheel gate: InputChanged fires for anything that moves over the Box (and a wheel event that
  -- is not consumed here keeps scrolling the panel behind it), so the value only follows the
  -- wheel while the pointer is really over the Box or the field holds focus.
  maid:Give(box.MouseEnter:Connect(function() hovering = true end))
  maid:Give(box.MouseLeave:Connect(function() hovering = false end))
  maid:Give(box.InputChanged:Connect(function(io)
    if io.UserInputType == Enum.UserInputType.MouseWheel and enabled and (hovering or focused) then
      local dir = (io.Position.Z >= 0) and 1 or -1
      set(value + step * dir)
    end
  end))
  maid:Give(root)
  if opts.Disabled then setEnabled(false) end

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    root.BackgroundColor3 = theme.Colors.surface
    box.BackgroundColor3 = theme.Colors.background
    boxStroke.Color = strokeColor(focused)
    input.TextColor3 = theme.Colors.foreground
    local ti = root:FindFirstChild("Title"); if ti then ti.TextColor3 = theme.Colors.foreground end
    local de = root:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
    minus.BackgroundColor3 = theme.Colors.surface; plus.BackgroundColor3 = theme.Colors.surface
    Icons.apply(minusImg, "minus", structural()); Icons.apply(plusImg, "plus", structural())
    minusHover.reskin(); plusHover.reskin()   -- the wash owns a colour token too
    updateBounds()
  end)) end

  return {
    Frame = root,
    GetValue = function() return value end,
    SetValue = function(n) set(n) end,
    SetMin = function(n) minV = n; set(value) end,
    SetMax = function(n) maxV = n; set(value) end,
    SetEnabled = function(b) setEnabled(b) end,
    Destroy = function() maid:DoCleanup() end,
  }
end

return NumberBox
