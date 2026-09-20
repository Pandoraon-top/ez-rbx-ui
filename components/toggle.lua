-- Deps injected via Init(R).
local Toggle = {}
local Create, DefaultTheme, Animate, Maid, Flag, Safe, Effects, Recipes

function Toggle.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Flag = R.Flag; Safe = R.Safe
  Effects = R.Effects; Recipes = R.Recipes
end


-- shadcn switch proportions, pinned by toggle_test. Every knob offset is derived from them so the
-- ON position, the press stretch and the rim never need a second literal.
local TRACK_W, TRACK_H = 44, 24

function Toggle.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local value = false
  local onChanged

  local hasDesc = opts.Description ~= nil and opts.Description ~= ""
  local rowH = hasDesc and 50 or 34
  local padY = hasDesc and 8 or 0

  local btn = Create("TextButton", {
    Name = "Toggle", AutoButtonColor = false, Text = "",
    BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
    Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = opts.LayoutOrder or 0,
    Parent = opts.Parent,
    Create.corner(theme.Radius.md),
    Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX, top = padY, bottom = padY }),
  })
  local label = Create.text(Create("TextLabel", {
    Name = "Label", BackgroundTransparency = 1, Text = opts.Text or "Toggle",
    TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    Size = UDim2.new(1, -54, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn,
  }), theme, "label")
  local desc
  if hasDesc then
    desc = Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
      TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
      TextYAlignment = Enum.TextYAlignment.Top,
      Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, -54, 0, 18), Parent = btn }), theme, "muted")
  end
  -- ZIndex 2 so the track sits above the accent glow (1) and the hover wash (0), all siblings
  -- under btn; a child glow would render over the knob instead of behind the pill.
  local track = Create("Frame", {
    Name = "Track", BackgroundColor3 = theme.Colors.switchTrackOff, BorderSizePixel = 0, ZIndex = 2,
    Size = UDim2.new(0, TRACK_W, 0, TRACK_H), Position = UDim2.new(1, -TRACK_W, 0.5, -TRACK_H / 2),
    Parent = btn, Create.corner(TRACK_H / 2),
  })
  local trackStroke = Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = track })

  local knobSize = theme.Sizes.knob
  local knobPad = (TRACK_H - knobSize) / 2
  local knobY = -knobSize / 2
  local offX, onX = knobPad, TRACK_W - knobSize - knobPad
  local stretchW = knobSize * theme.Motion.knobStretch
  local knob = Create("Frame", {
    Name = "Knob", BackgroundColor3 = theme.Colors.foreground, BorderSizePixel = 0, ZIndex = 3,
    Size = UDim2.new(0, knobSize, 0, knobSize), Position = UDim2.new(0, offX, 0.5, knobY),
    Parent = track, Create.corner(knobSize / 2),
  })
  -- Rim: a white knob on a white ON track (Adaptive light) would otherwise dissolve into it.
  local knobStroke = Create.stroke(theme.Colors.background, 1, theme.Stroke.knob)
  knobStroke.Parent = knob
  -- Accent glow BEHIND the track, sibling under btn. nil while Effect.shadowId is '' (and on
  -- phones under controlGlow 'auto'), so every use is guarded.
  local glow = Effects.glow(btn, theme, theme.Colors.primary, "control", 1, "TrackGlow")
  Effects.mirror(glow, track, "control", theme)

  local function knobRest() return UDim2.new(0, value and onX or offX, 0.5, knobY) end

  -- `built` makes the first apply (Flag.bind's initial paint) a plain write: the rest pose costs
  -- no tween at build time, every later change animates.
  local built = false
  local function apply(v)
    value = v and true or false
    local instant = not built
    Safe.mutate(function()
      local trackC = value and theme.Colors.primary or theme.Colors.switchTrackOff
      local knobC = value and theme.Colors.primaryForeground or theme.Colors.foreground
      -- ON dissolves the grey stroke so the accent pill reads as one clean shape
      local strokeA = value and 1 or theme.Stroke.control
      local glowA = value and theme.fx(theme).glow or 1
      if instant then
        knob.Position = knobRest(); knob.Size = UDim2.new(0, knobSize, 0, knobSize)
        knob.BackgroundColor3 = knobC; track.BackgroundColor3 = trackC
        trackStroke.Transparency = strokeA
        if glow then glow.ImageTransparency = glowA end
        return
      end
      -- Geometry springs (Back/Out overshoots ~1px past the stop); the knob COLOUR is a separate
      -- Quart tween because Back/Out on a Color3 overshoots past the target and flashes.
      Animate.springTo(knob, "release", { Position = knobRest(), Size = UDim2.new(0, knobSize, 0, knobSize) })
      Animate.to(knob, "base", { BackgroundColor3 = knobC })
      Animate.to(track, "base", { BackgroundColor3 = trackC })
      Animate.to(trackStroke, "fast", { Transparency = strokeA })
      if glow then Animate.to(glow, "base", { ImageTransparency = glowA }) end
    end)
  end

  local commit = Flag.bind(opts, opts.Default == true, apply)
  built = true

  -- ---- state ----------------------------------------------------------------
  local hover = Recipes.hover(btn, { theme = theme, corner = theme.Radius.md,
    inset = { x = theme.Spacing.inputX, y = padY } })
  maid:Give(hover.disconnect)

  local enabled = true
  local function setEnabled(b)
    enabled = b ~= false
    Safe.mutate(function()
      local parts = { { track, "BackgroundTransparency", 0 }, { knob, "BackgroundTransparency", 0 },
        { label, "TextTransparency", 0 } }
      if desc then parts[#parts + 1] = { desc, "TextTransparency", 0 } end
      Recipes.disabled(parts, not enabled, theme)
    end)
  end

  -- Press leans the knob toward where the tap will send it: it stretches to knob*knobStretch with
  -- the TRAILING edge pinned, then springs back to the rest pose on release or mouse-out.
  local pressed = false
  local function pressKnob()
    pressed = true
    Animate.to(knob, "press", {
      Size = UDim2.new(0, stretchW, 0, knobSize),
      Position = UDim2.new(0, value and (TRACK_W - knobPad - stretchW) or knobPad, 0.5, knobY),
    })
  end
  local function releaseKnob()
    if not pressed then return end
    pressed = false
    Animate.springTo(knob, "release", { Size = UDim2.new(0, knobSize, 0, knobSize), Position = knobRest() })
  end

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    btn.BackgroundColor3 = theme.Colors.surface
    label.TextColor3 = theme.Colors.foreground
    if desc then desc.TextColor3 = theme.Colors.mutedForeground end
    trackStroke.Color = theme.Colors.border
    knobStroke.Color = theme.Colors.background
    Effects.reskin(glow, theme, "glow", theme.Colors.primary)
    hover.reskin()
    apply(value)
  end)) end

  local api = { Frame = btn }
  function api.Get() return value end
  function api.Set(v)
    commit(v and true or false)
    if opts.Callback then opts.Callback(value) end
    if onChanged then onChanged(value) end
  end
  function api.OnChanged(fn) onChanged = fn end
  -- Blocks USER input only: Set / a config restore still updates state and visuals while disabled.
  function api.SetEnabled(b) setEnabled(b) end
  function api.Destroy() maid:DoCleanup() end

  maid:Give(btn.MouseButton1Down:Connect(function() if enabled then pressKnob() end end))
  maid:Give(btn.MouseButton1Up:Connect(releaseKnob))
  maid:Give(btn.MouseLeave:Connect(releaseKnob))
  maid:Give(btn.MouseButton1Click:Connect(function() if enabled then api.Set(not value) end end))
  maid:Give(btn)
  if opts.Disabled then setEnabled(false) end
  return api
end

return Toggle
