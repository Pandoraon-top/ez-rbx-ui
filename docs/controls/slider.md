# Slider

A horizontal drag control for selecting a numeric value within a fixed range. The current value is displayed in a small readout to the right of the label. Values snap to the nearest `Step` increment as you drag. Sliders support an optional description line, a flag for persistence, and an `OnChanged` listener for live readouts.

## Basic usage

```lua
local s = tab:AddSlider({
  Text    = "Speed",
  Min     = 0,
  Max     = 100,
  Default = 50,
})
print(s.GetValue())
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | — | Row label. Shown above the track with the current value to the right. |
| `Min` | `number` | `0` | Minimum value (left end of the track). |
| `Max` | `number` | `100` | Maximum value (right end of the track). |
| `Default` | `number` | `Min` | Initial value, snapped to the nearest `Step`. |
| `Step` | `number` | `1` | Snap increment. Values are rounded to the nearest multiple of `Step` relative to `Min`. |
| `Description` | `string` | — | Muted secondary line rendered below the label. |
| `Disabled` | `boolean` | `false` | Builds the slider dimmed and non-draggable. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Flag` | `string` | — | Config key used to persist the value across sessions. |
| `Callback` | `function(number)` | — | Called with the new value after each drag or `SetValue` call. |

## API

| Method | Returns | Notes |
|---|---|---|
| `GetValue()` | `number` | Returns the current snapped value. |
| `SetValue(n)` | `nil` | Sets the value (snapped and clamped), fires `Callback` and `OnChanged`. |
| `OnChanged(fn)` | `nil` | Registers a listener called with the new value on every change. Use this for live readouts. |
| `SetEnabled(b)` | `nil` | Dims the fill, the handle and the value readout, and blocks the grab, when `false`. The rail and the label keep their normal strength. `SetValue` still applies, and a drag that was already under way is finished with its last value — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Destroy()` | `nil` | Removes the slider from the UI. |

## Grabbing it

The visible rail is 6 px tall, which is nothing to hit with a thumb, so the grab is taken by an
invisible strip four times its height (`Sizes.sliderHit`) centred over it and spanning the row.
Pressing anywhere on that strip — mouse or touch — jumps the value to that point and starts the
drag, and the value keeps following the pointer until it is released, including while the pointer
is outside the row. The 6 px rail no longer starts a drag on its own, and the strip is deliberately
not `Active`, so pressing it never swallows the scroll of the panel the row sits in.

The handle answers before it is grabbed: it grows to `Motion.handleHover` while the pointer is over
the strip, to `Motion.handleGrow` while a drag is under way, and springs back when the drag ends —
to the hover size if the pointer is still over the strip, otherwise to its resting size. An accent
halo fades in behind it for the length of the drag and fades out on release. The halo is part of the
shared depth system, so it is absent when `Effect.shadowId` is empty and, under the default
`controlGlow = "auto"`, on phones — see [Depth layers](/guide/theming#depth-layers). A device with
no pointer never connects the hover growth at all ([capability probes](/guide/device#capability-probes)),
so there the handle grows only while it is actually being dragged.

The empty part of the rail is painted in the window `background` colour under a hairline stroke, so
an untouched slider reads as a groove rather than a gap in the row.

## A drag versus `SetValue`

The two paths are deliberately different:

- **A drag writes straight through.** The fill, the handle and the halo are moved with no tween at
  all, so the rail never lags behind the finger.
- **`SetValue` eases.** A programmatic change flows to the new value over `Motion.base` instead of
  jumping, so a value driven from script reads as a change rather than a cut.
- **The opening pose is written, not animated.** `Default`, and the saved value a
  [`Flag`](/guide/config-and-flags) restores while the control is being built, are painted straight
  through like a drag — a window opens with its sliders already in position instead of sweeping
  them there. A restore that arrives *later*, once the row exists — `Window:UseConfigProfile(name)`
  or `Window:ResetConfiguration()` — eases like any other programmatic change.

Neither path delays the value itself: `GetValue` is up to date immediately, and `Callback` /
`OnChanged` fire on every pointer move during a drag — including moves that land on the same snapped
value — not only when the drag ends. Keep the work inside those listeners cheap, or debounce it
yourself. With animation disabled (reduced motion) `SetValue` lands instantly too.

## Examples

```lua
-- Live readout via OnChanged
local readout = tab:AddLabel("Speed: 16")
local s = tab:AddSlider({ Text = "Speed", Min = 16, Max = 200, Default = 16 })
s.OnChanged(function(v)
  readout.SetText("Speed: " .. tostring(v))
end)

-- With a description
tab:AddSlider({
  Text        = "With description",
  Description = "Drag to adjust.",
  Min         = 0,
  Max         = 100,
  Default     = 30,
})

-- Flag-bound — value persists across sessions
tab:AddSlider({
  Text    = "Saved volume",
  Flag    = "ex_slider",
  Min     = 0,
  Max     = 100,
  Default = 50,
})

-- Disabled while something else is in charge of the value
local music = tab:AddSlider({ Text = "Music", Min = 0, Max = 100, Default = 80 })
tab:AddToggle({
  Text = "Auto volume",
  Callback = function(on)
    music.SetEnabled(not on)   -- dimmed, but the script can still drive it
    if on then music.SetValue(50) end
  end,
})

-- Programmatic update
local vol = tab:AddSlider({ Text = "Volume", Min = 0, Max = 100, Default = 80 })
vol.SetValue(50)
print(vol.GetValue()) -- 50
```
