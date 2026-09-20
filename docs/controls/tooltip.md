# Tooltip

A tooltip is not a control you add — it is an option on the controls you already add. Pass
`Tooltip = "…"` to any `Add*` method and the control gains a hover hint: rest the pointer anywhere
on the row and a small chip appears next to it.

## Basic usage

```lua
tab:AddButton({ Text = "Rejoin", Tooltip = "Teleports you back into the same server." })
tab:AddToggle({ Text = "Auto farm", Tooltip = "Keeps running while you are AFK." })
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Tooltip` | `string` | — | Hint text shown while the pointer rests on the control. Accepted by every `Add*` control method — Label, Paragraph, Section, Separator, Button, Toggle, TextBox, NumberBox, SelectBox, Slider, Keybind, ColorPicker, Image, Table, ProgressBar, Resizable and Card. The container methods `AddTab`, `AddTabGroup` and `AddAccordion` do not take it. |

There is no separate handle to keep and nothing to destroy: the tip belongs to the control it was
attached to, and `Destroy()` on that control takes the hover connections — and any chip still on
screen — with it.

## Behaviour

**It waits before it shows.** Hovering does not show the chip straight away; the pointer has to
rest on the control for `Tooltip.delay` first. Leaving before then cancels the pending tip, so
sweeping the pointer down a column of rows does not strobe a trail of chips behind it. The delay is
a [theme token](/guide/theming#tooltip) if you want it shorter or longer.

**It is inverted.** The chip is filled with the theme's foreground color and its text is drawn in
the background color, with no border — the inversion is the edge, and it reads as a label *about*
the UI rather than as another panel of it. It reads the live palette every time it shows, so a
`SetMode` swap that happens while it is hidden is already applied the next time it appears.

**It anchors above the control**, centred on it, with `Tooltip.gap` of air between the two. When
there is no room above — a control near the top of the screen — it flips below instead.
Horizontally it is clamped to the viewport, so a control at the right edge gets a chip that stops
at the edge rather than running off it. The chip lives in the overlay above the window, follows the
window's UI scale, and carries a soft shadow when the theme has a shadow sprite (see
[Depth layers](/guide/theming#depth-layers)).

**It fades out before it is destroyed.** Moving the pointer away starts the fade and releases the
chip immediately, so a fresh hover during the fade builds a new chip instead of reviving the one on
its way out. With animations disabled the chip simply appears and disappears — the hover delay
still applies either way, since that is intent, not motion.

## Touch devices never see one

On any device with a touchscreen, `Tooltip` is a complete no-op: no hover connections are made and
no chip is ever built. A tap has no matching "leave", so a tip shown on touch would be stranded on
screen with nothing to dismiss it.

This is keyed to the presence of a touchscreen and not to the device class, so a laptop with a
touchscreen — which EzUI otherwise reports as a desktop — gets no tooltips either. See
[Device](/guide/device) for how the two differ.

**So never put anything in a tooltip that a user needs in order to work the control.** Whatever is
required belongs in the control's `Text` or `Description`, where every device can read it. Treat a
tooltip as the extra sentence a mouse user gets for free.

## Examples

```lua
-- A hint on a control whose label has to stay short
tab:AddSlider({ Text = "FOV", Min = 40, Max = 120, Default = 90,
  Tooltip = "Applies on your next respawn." })

-- Controls nested in an accordion take it too
local adv = tab:AddAccordion({ Title = "Advanced" })
adv:AddToggle({ Text = "Verbose logs", Tooltip = "Writes every request to the console." })

-- The part the user needs goes in Description; the tooltip only adds to it
tab:AddSelectBox({
  Text        = "Target",
  Description = "Who the farm attacks first.",
  Tooltip     = "Nearest is measured from your character, not the camera.",
  Options     = { "Nearest", "Lowest HP", "Highest bounty" },
  Default     = "Nearest",
})
```
