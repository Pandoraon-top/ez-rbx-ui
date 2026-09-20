# ColorPicker

An inline color swatch that opens a floating HSV picker on click. The picker provides a saturation/value square and a hue slider; click or drag either to change the color. There is no hex field — the value is always read back as a `Color3`.

The popover is placed just below the swatch row, flips above it when there is no room below (and there is room above), and is clamped horizontally so it never runs off the side of the screen. It follows the window's UI scale. Clicking anywhere outside it closes it, and so does scrolling the control out of view.

It grows out of the row rather than simply appearing: the picker starts a few pixels nearer the row
and just under full size, then slides into place — downward when it opened below the row, upward
when it flipped above it. Closing reverses it: the popover is gone as far as your code is concerned
the moment `Close()` returns, while the detached frame shrinks away and is destroyed once that
finishes. The slide distance is `Motion.popSlide`, and with animations disabled the picker lands in
place instead.

Like the select box's dropdown, the popover is frosted one step lighter than the window shell so
the content it covers stays readable through it. Both share the same token for that alpha,
`Acrylic.popoverFrost` — see [Theming — Acrylic](/guide/theming#acrylic).

## Basic usage

```lua
local cp = tab:AddColorPicker({
  Text    = "Box color",
  Default = Color3.fromRGB(120, 160, 255),
  Callback = function(c)
    print("color", c)
  end,
})
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | `"Color"` | Label displayed to the left of the swatch. |
| `Default` | `Color3` | `Color3.fromRGB(255, 255, 255)` | Initial color. |
| `Description` | `string` | — | Muted secondary line rendered below the label. |
| `Disabled` | `boolean` | `false` | Builds the row dimmed; clicking it will not open the picker. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Flag` | `string` | — | Config key used to persist the color across sessions. Stored as an `{r, g, b}` array (0–255). |
| `Callback` | `function(Color3)` | — | Called with the new `Color3` value on every change. |

## API

| Method | Returns | Notes |
|---|---|---|
| `GetColor()` | `Color3` | Returns the current color. |
| `SetColor(c)` | `nil` | Sets the color programmatically and fires `Callback`. |
| `Open()` | `nil` | Opens the picker popover. Does nothing while the control is disabled or the popover is already open. |
| `Close()` | `nil` | Closes the popover. |
| `SetDisabled(b)` | `nil` | Dims the swatch and label and blocks `Open`. `SetColor` still applies, and a drag already under way on the square or the hue bar is ended with its last value — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Destroy()` | `nil` | Removes the control from the UI. |

## Examples

```lua
-- Basic color picker with callback
tab:AddColorPicker({
  Text    = "Box color",
  Default = Color3.fromRGB(120, 160, 255),
  Callback = function(c) print("color", c) end,
})

-- With a description line
tab:AddColorPicker({
  Text        = "With description",
  Description = "Click to open the picker.",
  Default     = Color3.fromRGB(80, 200, 120),
})

-- Flag-bound — color persists across sessions
tab:AddColorPicker({ Text = "Saved color", Flag = "ex_color", Default = Color3.fromRGB(255, 80, 80) })

-- Opened and closed from script
local pop = tab:AddColorPicker({ Text = "Trail", Default = Color3.fromRGB(0, 170, 255) })
tab:AddButton({ Text = "Pick trail color", Callback = function() pop.Open() end })

-- Disabled: dimmed and unopenable, but SetColor still applies
local fixed = tab:AddColorPicker({ Text = "Team color", Disabled = true })
fixed.SetColor(Color3.fromRGB(255, 170, 0))

-- Reading and setting at runtime
local cp = tab:AddColorPicker({ Text = "Tint", Default = Color3.fromRGB(255, 255, 255) })
print(cp.GetColor())                            -- Color3 [255, 255, 255]
cp.SetColor(Color3.fromRGB(255, 0, 0))          -- set to red programmatically
```
