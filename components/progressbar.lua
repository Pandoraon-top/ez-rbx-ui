-- Deps injected via Init(R).
--
-- API: { Frame, Get() -> number, Set(p), SetIndeterminate(b), Destroy() }
-- `SetIndeterminate(true)` (or opts.Indeterminate) is for work whose length is unknown: a short
-- fill sweeps across the track until the first real Set(number) cancels it.
local ProgressBar = {}
local Create, DefaultTheme, Animate, Safe
function ProgressBar.Init(R) Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Safe = R.Safe end

-- Indeterminate sweep: width of the travelling fill (scale), the static width it rests at under
-- reduced motion, and the period of one pass. The period matches Effect.skeleton.period so both
-- "we are waiting" idioms breathe at the same rate. theme.Effect.indeterminate wins when present.
local IND = { width = 0.3, rest = 0.5, period = 1.1 }

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
  local trackStroke = Create.stroke(theme.Colors.border, 1, theme.Stroke.track)
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
  -- ---- indeterminate sweep (3.3) --------------------------------------------------------------
  -- `indet` is the state, `sweep` the loop handle (nil under reduced motion, where the block is a
  -- static partial fill and no tween is created at all).
  local ind = theme.Effect and theme.Effect.indeterminate or IND
  local sweepW, sweepRest = ind.width or IND.width, ind.rest or IND.rest
  local sweepPeriod = ind.period or IND.period
  local indet, sweep = false, nil
  -- Only the sweep's own geometry is undone here; Size/Visible are left to the caller so Set()
  -- can tween straight from wherever the sweep stopped to the real value.
  local function stopSweep()
    if not indet then return end
    indet = false
    if sweep then sweep.Cancel(); sweep = nil end
    -- The clip is scoped to the sweep: ClipsDescendants clips to the track RECTANGLE and ignores
    -- the UICorner (the same reason the plan rejected a clipped flat leading edge), so leaving it
    -- on would square off the rounded fill the moment it reached either end of the pill.
    track.ClipsDescendants = false
    fill.Position = UDim2.new(0, 0, 0, 0)
  end

  local function Set(p)
    local prev = value
    value = clamp01(p)                              -- state first: concurrency_test reads it synchronously
    local done = value >= 1 and prev < 1
    Safe.mutate(function()
      stopSweep()                                   -- a real value always wins over the sweep
      fill.Visible = value > 0
      Animate.to(fill, durationFor(value - prev), { Size = UDim2.new(value, 0, 1, 0) },
        Animate.EASING.smooth, Animate.DIR.Out)
      -- reaching 1 from below flashes the fill: lifted synchronously, faded back over `base`.
      -- A reversing pulse would be prettier but rests wherever the engine stops it; this always
      -- ends opaque, including under reduced motion where the fade applies instantly.
      if done then
        fill.BackgroundTransparency = theme.Opacity.flash
        Animate.to(fill, "base", { BackgroundTransparency = 0 })
      end
    end)
  end
  -- Additive: the bar keeps its last value underneath, so turning the sweep off restores it.
  local function SetIndeterminate(b)
    local on = b and true or false
    Safe.mutate(function()
      if not on then
        stopSweep()
        fill.Visible = value > 0
        Animate.to(fill, "base", { Size = UDim2.new(value, 0, 1, 0) },
          Animate.EASING.smooth, Animate.DIR.Out)
        return
      end
      if indet then return end                      -- idempotent: never stack two loops on one fill
      indet = true
      fill.Visible = true
      fill.BackgroundTransparency = 0               -- a completion flash must not linger under the sweep
      if not Animate.isEnabled() then
        -- Reduced motion: rest as a static partial fill (no clip, no tween) rather than animating.
        fill.Position = UDim2.new(0, 0, 0, 0)
        fill.Size = UDim2.new(sweepRest, 0, 1, 0)
        return
      end
      track.ClipsDescendants = true                 -- the sweep enters/leaves outside the rail
      fill.Size = UDim2.new(sweepW, 0, 1, 0)
      fill.Position = UDim2.new(-sweepW, 0, 0, 0)
      sweep = Animate.loop(fill, sweepPeriod, { Position = UDim2.new(1, 0, 0, 0) }, Animate.EASING.smooth)
    end)
  end
  if opts.Indeterminate then SetIndeterminate(true) end

  return {
    Frame = root,
    Get = function() return value end,
    Set = Set,
    SetIndeterminate = SetIndeterminate,
    Destroy = function() stopSweep(); if unreg then unreg() end; root:Destroy() end,
  }
end
return ProgressBar
