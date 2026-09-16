-- Deps injected via Init(R).
local Button = {}
local Create, DefaultTheme, Animate, Maid, Icons, Safe, Recipes, Device

function Button.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Icons = R.Icons; Safe = R.Safe
  Recipes = R.Recipes; Device = R.Device
end

local function palette(theme, variant)
  if variant == "destructive" then return theme.Colors.destructive, theme.Colors.primaryForeground, nil end
  if variant == "secondary" then return theme.Colors.surface, theme.Colors.foreground, nil end
  if variant == "outline" then return theme.Colors.card, theme.Colors.foreground, theme.Colors.border end
  if variant == "ghost" then return theme.Colors.surface, theme.Colors.foreground, nil end
  return theme.Colors.primary, theme.Colors.primaryForeground, nil -- default
end

-- Pointer hover survives a click, but a touch tap fires Enter/Down/Up with no Leave, so a release
-- under touch has to fall back to rest or the hover fill sticks (same rule as core/recipes.lua).
local function pointerHover() return Device.SupportsHover() and Device.GetInput() ~= "Touch" end

function Button.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local variant = opts.Variant or "default"
  local maid = Maid.new()
  local bg, fg, stroke = palette(theme, variant)
  local transparent = (variant == "ghost")
  local auto = opts.AutoWidth and true or false

  -- btn: fixed-size hit area, laid out by UIListLayout. It never scales, so the press
  -- animation can't change its AbsoluteSize and siblings never reflow. AutoWidth swaps the
  -- fixed full width for content-based sizing (a min-width constraint keeps small labels tappable).
  local btn = Create("TextButton", {
    Name = "Button", AutoButtonColor = false, Text = "",
    BackgroundTransparency = 1,
    Size = auto and UDim2.new(0, 0, 0, 34) or UDim2.new(1, 0, 0, 34),
    AutomaticSize = auto and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
    LayoutOrder = opts.LayoutOrder or 0,
    Parent = opts.Parent,
  })
  if auto then Create("UISizeConstraint", { MinSize = Vector2.new(72, 0), Parent = btn }) end
  -- surface: the visible button. Centred (AnchorPoint 0.5) so the press UIScale shrinks
  -- toward the middle; Active=false so clicks fall through to btn.
  local surface = Create("Frame", {
    Name = "Surface", BackgroundColor3 = bg, BackgroundTransparency = transparent and 1 or 0,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = auto and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 1, 0),
    AutomaticSize = auto and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
    Active = false, Parent = btn,
    Create.corner(theme.Radius.md),
  })
  local scale = Create("UIScale", { Scale = 1, Parent = surface })
  -- kept as a local: a themer closure or a hover tween must never re-find it by class (the
  -- Surface is one of the frames tests look up with FindFirstChildOfClass).
  local line = stroke and Create("UIStroke", { Color = stroke, Thickness = 1, Parent = surface }) or nil

  local hovering = false
  local bgNormal = transparent and 1 or 0
  -- ghost rests fully transparent; on hover/press it reveals a clearly-visible muted 'surface'
  -- wash (its palette bg is surface, not card -- card matched the panel behind it and looked
  -- dead). Kept lighter than 'secondary' (a full opaque surface fill) so it still reads as ghost.
  local bgHover = transparent and theme.Opacity.ghostHover or theme.Opacity.hoverFill
  local bgPressed = transparent and theme.Opacity.ghostPress or theme.Opacity.pressFill

  local hasIcon = opts.Icon ~= nil
  local label, iconImg
  if auto then
    -- content-width: pad the surface and lay [icon?][label] out horizontally, centred.
    Create.padding({ left = 14, right = 14 }).Parent = surface
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
      HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, theme.Spacing.icon), Parent = surface })
    if hasIcon then
      iconImg = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
        Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), LayoutOrder = 1, Parent = surface })
      Icons.apply(iconImg, opts.Icon, fg)
    end
    label = Create.text(Create("TextLabel", { Name = "Label", BackgroundTransparency = 1,
      Text = opts.Text or "Button", TextColor3 = fg,
      AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
      LayoutOrder = 2, Parent = surface }), theme, "label")
  else
    if hasIcon then
      iconImg = Create("ImageLabel", {
        Name = "Icon", BackgroundTransparency = 1,
        Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), Position = UDim2.new(0.5, -44, 0.5, -theme.Sizes.icon / 2),
        Parent = surface,
      })
      Icons.apply(iconImg, opts.Icon, fg)
    end
    label = Create.text(Create("TextLabel", {
      Name = "Label", BackgroundTransparency = 1,
      Text = opts.Text or "Button", TextColor3 = fg, Size = UDim2.new(1, 0, 1, 0),
      Position = UDim2.new(0, hasIcon and 12 or 0, 0, 0),
      Parent = surface,
    }), theme, "label")
  end

  -- ---- state ----------------------------------------------------------------
  local enabled, loading, pressed = true, false, false
  local function blocked() return (not enabled) or loading end
  -- outline is the only variant whose border carries a state: it lifts to the ring colour on
  -- hover so the button answers the pointer without a fill.
  local function lineColor() return (variant == "outline" and hovering) and theme.Colors.ring or stroke end
  local function paintSurface(alpha) Animate.to(surface, "hover", { BackgroundTransparency = alpha }) end

  local function enter()
    if blocked() then return end
    hovering = true
    paintSurface(bgHover)
    if line and variant == "outline" then Animate.to(line, "hover", { Color = lineColor() }) end
  end
  local function leave()
    hovering = false
    if blocked() then return end
    paintSurface(bgNormal)
    -- a mouse-out while held springs back with the same release curve as a real click
    if pressed then pressed = false; Animate.springTo(scale, "release", { Scale = 1 }) end
    if line and variant == "outline" then Animate.to(line, "hover", { Color = lineColor() }) end
  end
  maid:Give(btn.MouseEnter:Connect(enter))
  maid:Give(btn.MouseLeave:Connect(leave))
  maid:Give(btn.MouseButton1Down:Connect(function()
    if blocked() then return end
    pressed = true
    Animate.to(scale, "press", { Scale = theme.Motion.pressScale })
    Animate.to(surface, "press", { BackgroundTransparency = bgPressed })
  end))
  maid:Give(btn.MouseButton1Up:Connect(function()
    if blocked() then return end
    pressed = false
    Animate.springTo(scale, "release", { Scale = 1 })
    -- touch has no Leave to undo the wash, so a release there goes straight back to rest
    if not pointerHover() then hovering = false end
    paintSurface(hovering and bgHover or bgNormal)
    if line and variant == "outline" then Animate.to(line, "hover", { Color = lineColor() }) end
  end))
  maid:Give(btn.MouseButton1Click:Connect(function()
    if blocked() then return end
    if opts.Action == "ResetConfig" and opts.Window and opts.Window.ResetConfiguration then opts.Window:ResetConfiguration() end
    if opts.Callback then opts.Callback() end
  end))
  maid:Give(btn)

  local function dimParts()
    local parts = { { label, "TextTransparency", 0 } }
    if not transparent then parts[#parts + 1] = { surface, "BackgroundTransparency", bgNormal } end
    if line then parts[#parts + 1] = { line, "Transparency", theme.Stroke.control } end
    if iconImg then parts[#parts + 1] = { iconImg, "ImageTransparency", 0 } end
    return parts
  end
  local function setEnabled(en)
    -- plain Lua state stays outside Safe.mutate: only the GUI writes need a capability context
    enabled = en ~= false
    btn.Active = enabled
    if enabled then hovering = false; pressed = false end
    Safe.mutate(function()
      if enabled then scale.Scale = 1 end
      Recipes.disabled(dimParts(), not enabled, theme)
    end)
  end

  -- ---- loading --------------------------------------------------------------
  local spinner, spin
  local function stopSpin() if spin then spin.Cancel(); spin = nil end end
  local function mkSpinner()
    if spinner then return spinner end
    -- AutoWidth lays the Surface out horizontally, so the spinner takes the label's LayoutOrder
    -- and the label hides while loading; otherwise it just sits where the leading icon would.
    local props = { Name = "Spinner", BackgroundTransparency = 1, Visible = false,
      Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), LayoutOrder = 2, Parent = surface }
    -- fixed-width buttons have no layout, so the glyph is centred by hand
    if not auto then props.Position = UDim2.new(0.5, -theme.Sizes.icon / 2, 0.5, -theme.Sizes.icon / 2) end
    spinner = Create("ImageLabel", props)
    Icons.apply(spinner, "loader", fg)
    return spinner
  end
  local function setLoading(b)
    loading = b and true or false
    if loading then pressed = false; hovering = false end
    Safe.mutate(function()
      local s = mkSpinner()
      stopSpin()
      s.Visible = loading
      if loading then
        scale.Scale = 1
        paintSurface(bgNormal)
        Animate.toThen(label, "fast", { TextTransparency = 1 }, function()
          if auto and loading then label.Visible = false end
        end)
        spin = Animate.spin(s)
      else
        label.Visible = true
        Animate.to(label, "fast", { TextTransparency = 0 })
      end
    end)
  end
  maid:Give(stopSpin)

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    local nbg, nfg, nstroke = palette(theme, variant)
    bg, fg, stroke = nbg, nfg, nstroke
    if not transparent then surface.BackgroundColor3 = nbg end
    label.TextColor3 = nfg
    if iconImg then Icons.apply(iconImg, opts.Icon, nfg) end
    if spinner then Icons.apply(spinner, "loader", nfg) end
    if line then line.Color = lineColor() end -- keeps a hovered outline on the ring colour
  end)) end

  if opts.Disabled then setEnabled(false) end
  if opts.Loading then setLoading(true) end

  return {
    Frame = btn,
    SetText = function(s) Safe.mutate(function() label.Text = s end) end,
    -- Blocks USER input only (the Callback is guarded); SetText and a themer reskin still apply.
    SetEnabled = setEnabled,
    SetLoading = setLoading,
    Destroy = function() maid:DoCleanup() end,
  }
end

return Button
