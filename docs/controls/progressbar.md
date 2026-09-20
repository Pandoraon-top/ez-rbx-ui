# ProgressBar

An animated horizontal fill bar that represents a progress value between 0 and 1. The fill animates smoothly when updated via `Set`. For work whose length is not known in advance it can instead run an indeterminate sweep.

## Basic usage

```lua
local pb = tab:AddProgressBar({ Default = 0.4 })
pb.Set(1)   -- fill to 100%
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Default` | `number` | `0` | Initial fill value, clamped to `0..1`. |
| `Color` | `Color3` | theme primary | Override the fill color. When omitted the fill tracks the accent color automatically. |
| `Indeterminate` | `boolean` | `false` | Start the sweep at build time — identical to calling `SetIndeterminate(true)` right after creation. |

## API

| Method | Returns | Notes |
|---|---|---|
| `Get()` | `number` | Returns the current value (`0..1`). |
| `Set(p)` | `nil` | Animates the fill to `p` (clamped to `0..1`). Always cancels an indeterminate sweep first. |
| `SetIndeterminate(b)` | `nil` | Starts or stops the sweep. See below. |
| `SetLocked(b)` | `nil` | Overlays a scrim that blocks interaction when `true`. |
| `Destroy()` | `nil` | Removes the element from the UI. |

## Filling

`Set` eases the fill to its new value over a distance-aware duration: a small step takes about
`Motion.base`, and a full `0` to `1` climb stretches to `Motion.slow`, so a long move does not feel
as abrupt as a nudge.

Two details keep the ends of the range honest:

- **Reaching 1 from below flashes.** As the value completes, the fill lifts to `Opacity.flash` and
  fades back to fully opaque, a brief acknowledgement for someone already watching the bar. It is
  over in a fraction of a second, so it is not a substitute for a toast if the reader may have
  looked away. It fires on the crossing only — `Set(1)` on a bar that already holds `1` flashes
  nothing — and it always ends opaque, including with animation disabled (reduced motion), where the
  fade is applied instantly.
- **A tiny value still reads as a bar.** The fill has a minimum width (`Sizes.progress`), so
  `Set(0.01)` renders as a small rounded nub rather than a sliver thinner than its own corner
  radius. A true zero is the exception: at `0` the fill is hidden outright, so an empty bar is empty
  rather than showing that floor. Its width still returns to zero underneath, so the next `Set`
  animates from the left edge.

The track carries a hairline stroke (`Stroke.track`), so an empty bar reads as a groove in the row
rather than a gap in it.

## Indeterminate

`SetIndeterminate(true)` (or `Indeterminate = true`) replaces the measured fill with a short block
that travels across the track on a loop. Reach for it when you know work has started but not how
long it will take — an HTTP request, a datastore read — and switch back to `Set` as soon as you have
a real number.

- The sweep is **not** a value. `Get()` keeps returning whatever the bar last held, and the
  duration of the work makes no difference to it.
- **Any `Set(n)` cancels it**: the travelling block is put back at the left of the track and its
  width eases from whatever it had reached to the real value. You never have to turn the sweep off
  first.
- `SetIndeterminate(false)` cancels it too, and restores the value that was underneath.
- Calling `SetIndeterminate(true)` twice is a no-op — two sweeps never stack on one bar.
- With animation disabled (reduced motion) nothing travels: the bar rests as a static half fill
  instead, which still reads as "waiting" without moving.

```lua
local pb = tab:AddProgressBar({ Default = 0 })

tab:AddButton({
  Text = "Fetch",
  Callback = function()
    pb.SetIndeterminate(true)        -- we don't know how long this takes
    task.spawn(function()
      local rows = fetchRows()       -- may yield
      pb.Set(1)                      -- a real value cancels the sweep on its own
      print(#rows)
    end)
  end,
})
```

## Examples

```lua
local pb = tab:AddProgressBar({ Default = 0.4 })
local p = 0.4

tab:AddButton({
  Text = "+20%",
  Callback = function()
    p = math.min(1, p + 0.2)
    pb.Set(p)
  end,
})

tab:AddButton({
  Text = "Reset",
  Variant = "secondary",
  Callback = function()
    p = 0
    pb.Set(0)
  end,
})

-- Custom fill color
tab:AddProgressBar({ Default = 0.7, Color = Color3.fromRGB(34, 197, 94) })
```
