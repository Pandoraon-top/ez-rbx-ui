-- Deps injected via Init(R).
local Slider = {}
local Create, DefaultTheme, Animate, Maid, Flag, Safe, Effects, Recipes, Device
local UserInputService = game:GetService("UserInputService")
function Slider.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Flag = R.Flag; Safe = R.Safe
  Effects = R.Effects; Recipes = R.Recipes; Device = R.Device
end

-- Rail geometry pinned by theme_test/slider_test: a 6px track 16px above the padded row bottom,
-- with a 12px handle centred on it. The Hit strip and the halo derive from these.
local TRACK_H, TRACK_Y, HANDLE = 6, -16, 12

function Slider.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local minV = opts.Min or 0
  local maxV = opts.Max or 100
  local step = opts.Step or 1
  local value = minV
  local onChanged

  local function snap(n)
    n = tonumber(n) or value
    if step and step > 0 then n = math.floor((n - minV) / step + 0.5) * step + minV end
    if n < minV then n = minV elseif n > maxV then n = maxV end
    return n
  end

  local hasDesc = opts.Description ~= nil and opts.Description ~= ""
  -- symmetric vertical padding so the title/track/handle aren't flush against the row edges;
  -- grow the row height by 2*padY so the inner layout (title at top, track anchored to the
  -- inner bottom) keeps its relative geometry and simply gains breathing room top and bottom.
  local padY = theme.Spacing.inputY
  local root = Create("Frame", { Name = "SliderRow", BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
    Size = UDim2.new(1, 0, 0, (opts.Text and (hasDesc and 62 or 46) or 28) + padY * 2), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
    Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX, top = padY, bottom = padY }) })
  local valueLabel, titleLabel, descLabel
  if opts.Text then
    -- Title is the row label (14, Medium) like every other row; the 16px slot and the track
    -- offset are pinned geometry (theme_test), so only the type role changes.
    titleLabel = Create.text(Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Text,
      TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
      Size = UDim2.new(1, -40, 0, 16), Parent = root }), theme, "label")
    valueLabel = Create.text(Create("TextLabel", { Name = "Value", BackgroundTransparency = 1, Text = "0",
      TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Right,
      Size = UDim2.new(0, 40, 0, 16), Position = UDim2.new(1, -40, 0, 0), Parent = root }), theme, "muted")
    if hasDesc then
      descLabel = Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
        TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, -40, 0, 18), Parent = root }), theme, "muted")
    end
  end
  -- The empty part of the rail is the window background (one step below the row) plus a stroke,
  -- so an untouched slider still reads as a groove rather than a gap.
  local track = Create("Frame", { Name = "Track", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, TRACK_H), Position = UDim2.new(0, 0, 1, TRACK_Y), Parent = root, Create.corner(TRACK_H / 2) })
  local trackStroke = Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = track })
  local fill = Create("Frame", { Name = "Fill", BackgroundColor3 = theme.Colors.primary, BorderSizePixel = 0,
    Size = UDim2.new(0, 0, 1, 0), Parent = track, Create.corner(TRACK_H / 2) })
  -- AnchorPoint (0.5, 0.5): the handle sits ON the value point, so the grow UIScale expands about
  -- its centre instead of dragging the glyph down-right from a top-left origin.
  local handle = Create("Frame", { Name = "Handle", BackgroundColor3 = theme.Colors.foreground, BorderSizePixel = 0, ZIndex = 2,
    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, HANDLE, 0, HANDLE),
    Position = UDim2.new(0, 0, 0.5, 0), Parent = track, Create.corner(HANDLE / 2) })
  local handleScale = Create("UIScale", { Scale = 1, Parent = handle })
  -- Halo: a glow parented to the TRACK at ZIndex 0 (Track has no ClipsDescendants), so it shares
  -- the handle's coordinate space and follows it with a plain Position write -- no Absolute* math.
  -- nil while Effect.shadowId is '' and on phones under controlGlow 'auto'.
  local halo = Effects.glow(track, theme, theme.Colors.primary, "control", 0, "Halo")
  Effects.mirror(halo, handle, "control", theme)
  -- Finger-sized grab strip over the 6px rail: transparent, ZIndex above the track so pointer
  -- input lands here rather than on the rail. Deliberately NOT 'Active' -- the rail it replaces
  -- never sank input either, and an Active frame inside the content ScrollingFrame would swallow
  -- the scroll the row sits in (same rule as the Recipes hover wash).
  local hitH = theme.Sizes.sliderHit
  local hit = Create("Frame", { Name = "Hit", BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 3,
    Size = UDim2.new(1, 0, 0, hitH), Position = UDim2.new(0, 0, 1, TRACK_Y + TRACK_H / 2 - hitH / 2), Parent = root })

  local dragging = false
  local built = false
  -- Handle and halo are both centre-anchored on the value point, so one goal serves both.
  local function valuePos(scale) return UDim2.new(scale, 0, 0.5, 0) end

  local function apply(v)
    value = snap(v)
    local scale = (maxV > minV) and (value - minV) / (maxV - minV) or 0
    local direct = dragging or not built
    Safe.mutate(function()
      if valueLabel then valueLabel.Text = tostring(value) end
      if direct then
        -- an active drag writes straight through so the rail never lags the finger
        fill.Size = UDim2.new(scale, 0, 1, 0)
        handle.Position = valuePos(scale)
        if halo then halo.Position = valuePos(scale) end
        return
      end
      -- programmatic SetValue (config restore, api call) flows instead of jumping
      local E, D = Animate.EASING.smooth, Animate.DIR.Out
      Animate.to(fill, "base", { Size = UDim2.new(scale, 0, 1, 0) }, E, D)
      Animate.to(handle, "base", { Position = valuePos(scale) }, E, D)
      if halo then Animate.to(halo, "base", { Position = valuePos(scale) }, E, D) end
    end)
  end
  local commit = Flag.bind(opts, snap(opts.Default or minV), apply)
  built = true

  local api = { Frame = root }
  function api.GetValue() return value end
  function api.SetValue(v) commit(snap(v)); if opts.Callback then opts.Callback(value) end; if onChanged then onChanged(value) end end
  function api.OnChanged(fn) onChanged = fn end
  function api.Destroy() maid:DoCleanup() end

  -- ---- handle feedback ------------------------------------------------------
  local hovering = false
  local function handleGrow()
    local s = dragging and theme.Motion.handleGrow or (hovering and theme.Motion.handleHover or 1)
    Animate.springTo(handleScale, "release", { Scale = s })
    if halo then Animate.to(halo, "base", { ImageTransparency = dragging and theme.fx(theme).glow or 1 }) end
  end

  local enabled = true
  local function setEnabled(b)
    local was = enabled
    enabled = b ~= false
    Safe.mutate(function()
      local parts = { { fill, "BackgroundTransparency", 0 }, { handle, "BackgroundTransparency", 0 } }
      if valueLabel then parts[#parts + 1] = { valueLabel, "TextTransparency", 0 } end
      Recipes.disabled(parts, not enabled, theme)
    end)
    -- a drag already under way is forced to finish (value kept) rather than left hanging
    if was and not enabled and dragging then dragging = false; handleGrow() end
  end

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    root.BackgroundColor3 = theme.Colors.surface
    track.BackgroundColor3 = theme.Colors.background
    trackStroke.Color = theme.Colors.border
    fill.BackgroundColor3 = theme.Colors.primary
    handle.BackgroundColor3 = theme.Colors.foreground
    Effects.reskin(halo, theme, "glow", theme.Colors.primary)
    if titleLabel then titleLabel.TextColor3 = theme.Colors.foreground end
    if descLabel then descLabel.TextColor3 = theme.Colors.mutedForeground end
    if valueLabel then valueLabel.TextColor3 = theme.Colors.mutedForeground end
  end)) end

  local function fromX(px)
    local ap, sz = track.AbsolutePosition, track.AbsoluteSize
    local x0 = ap and ap.X or 0
    local w = (sz and sz.X) or 1
    local t = (px - x0) / (w > 0 and w or 1)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    api.SetValue(minV + t * (maxV - minV))
  end
  maid:Give(hit.InputBegan:Connect(function(input)
    if not enabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = true; handleGrow(); fromX(input.Position.X)
    end
  end))
  maid:Give(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
      fromX(input.Position.X)
    end
  end))
  maid:Give(UserInputService.InputEnded:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = false; handleGrow()
    end
  end))
  if Device.SupportsHover() then
    maid:Give(hit.MouseEnter:Connect(function() hovering = true; if enabled then handleGrow() end end))
    maid:Give(hit.MouseLeave:Connect(function() hovering = false; handleGrow() end))
  end

  -- Blocks USER input only: SetValue / a config restore still updates state and visuals.
  function api.SetEnabled(b) setEnabled(b) end
  if opts.Disabled then setEnabled(false) end
  maid:Give(root)
  return api
end
return Slider
