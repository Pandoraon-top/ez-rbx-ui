# Button

A clickable action element available in five visual variants. Buttons support an optional leading icon and a built-in `"ResetConfig"` action that resets all saved flags without extra wiring.

## Basic usage

```lua
tab:AddButton({
  Text     = "Confirm",
  Callback = function()
    window:ShowSuccess({ Title = "Done" })
  end,
})
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | `"Button"` | Label displayed on the button. |
| `Variant` | `string` | `"default"` | Visual style — see the table below. |
| `Icon` | `string` | — | Lucide icon name (e.g. `"play"`). Rendered to the left of the label. |
| `AutoWidth` | `boolean` | `false` | Sizes the button to its own label instead of stretching to the row width, with a 72 px minimum so a short label stays tappable. |
| `Callback` | `function` | — | Called with no arguments when the button is clicked. |
| `Action` | `string` | — | Pass `"ResetConfig"` to wire the built-in config-reset without a callback. |
| `Disabled` | `boolean` | `false` | Builds the button dimmed and unclickable. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Loading` | `boolean` | `false` | Builds the button in the loading state — identical to calling `SetLoading(true)` right after creation. |

### Variants

| Value | Appearance |
|---|---|
| `"default"` | Filled with the theme primary color. |
| `"secondary"` | Filled with the muted surface color. |
| `"outline"` | Card-colored fill with a border stroke that lifts to the ring color on hover. |
| `"ghost"` | No fill and no border; tinted on hover. |
| `"destructive"` | Filled with the destructive (red) color. |

## API

| Method | Returns | Notes |
|---|---|---|
| `SetText(s)` | `nil` | Replaces the button label at runtime. |
| `SetEnabled(b)` | `nil` | When `false`, dims the label and disables clicks. `SetText` and a re-skin still apply — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `SetLoading(b)` | `nil` | Swaps the label for a spinning loader and refuses clicks until it is turned off. Independent of `SetEnabled`: a loading button is blocked whether or not it is disabled. |
| `Destroy()` | `nil` | Removes the button from the UI. |

## How it answers a press

Pressing dips the button: the coloured surface scales to `Motion.pressScale` while it is held and
springs back — slightly past its resting size, then settling — when the press ends. The scale is
applied to the surface *inside* the button rather than to the button itself, so its footprint never
changes and the controls around it never reflow. Dragging off a button while still holding it
springs the surface back the same way a real release does.

The fill answers too. Every variant except `ghost` raises its fill's transparency to
`Opacity.hoverFill` on hover and `Opacity.pressFill` while held, letting a little of the panel
behind it show through; `ghost` rests fully transparent instead and reveals a muted surface wash at
`Opacity.ghostHover` / `ghostPress`. On touch there is no pointer to leave, so a release goes
straight back to rest rather than holding the hover fill until something else clears it.

`outline` is the only variant whose *border* carries a state as well: on top of the fill change
above, its stroke lifts from the `border` colour to the `ring` colour while the pointer is over it
and drops back when the pointer leaves. A hovered outline keeps the ring colour across a
`SetAccent` or `SetMode` re-skin.

A disabled or loading button answers none of this — hover, press and release are all refused while
it is in either state.

## Examples

```lua
-- All five variants
tab:AddButton({ Text = "Default" })
tab:AddButton({ Text = "Secondary",   Variant = "secondary" })
tab:AddButton({ Text = "Outline",     Variant = "outline" })
tab:AddButton({ Text = "Ghost",       Variant = "ghost" })
tab:AddButton({ Text = "Destructive", Variant = "destructive" })

-- With a leading icon
tab:AddButton({ Text = "Play", Icon = "play" })

-- Built-in reset — no callback required
tab:AddButton({
  Text    = "Reset config",
  Variant = "destructive",
  Action  = "ResetConfig",
})

-- Inside an accordion
local acc = tab:AddAccordion({ Title = "Actions", Icon = "rows-3" })
acc:AddButton({ Text = "Action" })
```
