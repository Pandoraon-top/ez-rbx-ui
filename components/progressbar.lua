-- Deps injected via Init(R).
local ProgressBar = {}
local Create, DefaultTheme, Animate, Safe
function ProgressBar.Init(R) Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Safe = R.Safe end

-- Tokens core/theme.lua does not carry yet (reported as deviations); the theme wins as soon as
-- Stroke.track / Opacity.flash exist. Same escape hatch core/animate.lua uses for FALLBACK.
local FALLBACK = { trackStroke = 0.5, flash = 0.35 }

local function clamp01(n) n = tonumber(n) or 0; if n < 0 then return 0 elseif n > 1 then return 1 end return n end

function ProgressBar.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local value = clamp01(opts.Default or 0)
  local root = Create("Frame", { Name = "ProgressBar", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 8), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent })
  local track = Create("Frame", { Name = "Track", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0), Parent = root, Create.corner(4) })
  -- Hairline like the slider rail: an empty track still reads as a groove, not a gap.
  local trackStroke = Create.stroke(theme.Colors.border, 1, theme.Stroke.track or FALLBACK.trackStroke)
  trackStroke.Parent = track
  local fill = Create("Frame", { Name = "Fill", BackgroundColor3 = opts.Color or theme.Colors.primary, BorderSizePixel = 0,
    Size = UDim2.new(value, 0, 1, 0), Visible = value > 0, Parent = track, Create.corner(4) })
  -- Anti-blob: a 1% fill would otherwise render as a sliver thinner than its own corner radius.
  -- The floor is a constraint rather than a Size clamp so the Size tween still runs to the true
  -- value; a TRUE zero stays empty because Visible (written synchronously) gates it.
  Create("UISizeConstraint", { MinSize = Vector2.new(theme.Sizes.progress, 0), Parent = fill })
  local unreg
  if opts.AccentReg then
    unreg = opts.AccentReg(function()
      track.BackgroundColor3 = theme.Colors.surface
      trackStroke.Color = theme.Colors.border
      if not opts.Color then fill.BackgroundColor3 = theme.Colors.primary end
    end)
  end
  -- Distance-aware duration: a nudge lands in `base`, a full sweep takes `slow`.
  local function durationFor(delta)
    return theme.Motion.base + math.abs(delta) * (theme.Motion.slow - theme.Motion.base)
  end
  local function Set(p)
    local prev = value
    value = clamp01(p)                              -- state first: concurrency_test reads it synchronously
    local done = value >= 1 and prev < 1
    Safe.mutate(function()
      fill.Visible = value > 0
      Animate.to(fill, durationFor(value - prev), { Size = UDim2.new(value, 0, 1, 0) },
        Animate.EASING.smooth, Animate.DIR.Out)
      -- reaching 1 from below flashes the fill: lifted synchronously, faded back over `base`.
      -- A reversing pulse would be prettier but rests wherever the engine stops it; this always
      -- ends opaque, including under reduced motion where the fade applies instantly.
      if done then
        fill.BackgroundTransparency = theme.Opacity.flash or FALLBACK.flash
        Animate.to(fill, "base", { BackgroundTransparency = 0 })
      end
    end)
  end
  return {
    Frame = root,
    Get = function() return value end,
    Set = Set,
    Destroy = function() if unreg then unreg() end; root:Destroy() end,
  }
end
return ProgressBar
