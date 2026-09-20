# Toggle

A labeled on/off switch. An optional description line can be added beneath the label for extra context. Toggles can be bound to a flag key for automatic persistence across sessions.

## Basic usage

```lua
local t = tab:AddToggle({
  Text    = "Enable feature",
  Default = false,
  Callback = function(on)
    print("toggle is now", on)
  end,
})
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | `"Toggle"` | Label displayed to the left of the switch. |
| `Default` | `boolean` | `false` | Initial on/off state. |
| `Description` | `string` | — | Muted secondary line rendered below the label. |
| `Disabled` | `boolean` | `false` | Builds the toggle dimmed and non-interactive. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Flag` | `string` | — | Config key used to persist the value across sessions. |
| `Callback` | `function(bool)` | — | Called with the new boolean value whenever the toggle changes. |

## API

| Method | Returns | Notes |
|---|---|---|
| `Get()` | `boolean` | Returns the current on/off value. |
| `Set(v)` | `nil` | Sets the toggle to `v` and fires `Callback` / `OnChanged`. |
| `OnChanged(fn)` | `nil` | Registers a listener called with the new value on every change. |
| `SetEnabled(b)` | `nil` | Dims the row and blocks clicks when `false`. `Set` and flag restores still apply — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Destroy()` | `nil` | Removes the toggle from the UI. |

## The switch

The knob leans toward where a tap will send it. While the row is held down it stretches to
`Motion.knobStretch` of its width, with the edge it is travelling *away* from pinned — off it grows
to the right, on it grows to the left — and springs back to a circle when the press ends. Moving the
pointer off the row while still holding it springs the knob back the same way.

Turning on does three things at once:

- The knob slides across while the track and the knob take their on-state colours. The move springs
  with a small overshoot; the colours ease on their own curve, so the knob never flashes past its
  tint.
- The hairline around the track dissolves, so the accent pill reads as one clean shape rather than a
  filled rectangle inside an outline. Turning off brings it back.
- An accent glow behind the track fades up, and fades out again when the switch goes off. It is a
  sibling of the track rather than a child, so it never washes over the knob. Like every glow in the
  library it needs `Effect.shadowId`, and the default `controlGlow = "auto"` drops it on phones —
  see [Depth layers](/guide/theming#depth-layers).

The knob carries a thin rim in the window `background` colour (`Stroke.knob`). Without it a white
knob sitting on a white track — which is what the light-mode `Adaptive` accent gives you once the
switch is on — would dissolve into it.

Under a pointer the whole row washes on hover and deepens while it is held. Devices with no pointer
never wire that up, rather than leaving a wash stuck after a tap.

A toggle that is built on (`Default = true`, or a [`Flag`](/guide/config-and-flags) restore) paints
its rest pose with no animation, so a window opens with its switches already in place instead of
sliding them across. With animation disabled (reduced motion) every later change lands the same way.

## Examples

```lua
-- Basic toggle with callback
tab:AddToggle({
  Text    = "Enable feature",
  Default = false,
  Callback = function(on)
    print("toggle", on)
  end,
})

-- With a description line
tab:AddToggle({
  Text        = "With description",
  Description = "Extra context shown under the label.",
  Default     = true,
})

-- Flag-bound — value persists across sessions
tab:AddToggle({
  Text    = "Remember me",
  Flag    = "ex_toggle",
  Default = true,
})

-- Built dimmed; Set still works while it is disabled
local d = tab:AddToggle({ Text = "Needs premium", Disabled = true })
d.Set(true)            -- the switch still slides across
d.SetEnabled(true)     -- now the user can click it too

-- Reading and writing programmatically
local t = tab:AddToggle({ Text = "Dark mode", Default = false })
t.OnChanged(function(v)
  print("dark mode:", v)
end)
t.Set(true)   -- turn on
print(t.Get()) -- true
```
