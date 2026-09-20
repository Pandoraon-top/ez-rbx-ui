# Accordion

A collapsible card that hosts any [Controls](/controls/) inside it. Clicking the header toggles the body open or closed with an animated resize. An optional leading icon can be set, and the panel can start expanded by default.

## Basic usage

```lua
local acc = tab:AddAccordion({ Title = "Advanced settings", Icon = "settings-2" })
acc:AddToggle({ Text = "Nested toggle", Default = true })
acc:AddSlider({ Text = "Nested slider", Min = 0, Max = 10, Default = 5 })
acc:AddButton({ Text = "Nested button" })
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Title` | `string` | `"Section"` | Header text. |
| `Icon` | `string` | — | Lucide icon name shown to the left of the title (e.g. `"settings-2"`, `"rows-3"`). |
| `Expanded` | `bool` | `false` | When `true` the accordion starts open. |

## API

The accordion handle exposes all the same `AddX` methods as a tab (e.g. `AddToggle`, `AddSlider`, `AddButton`, `AddSelectBox`, etc.), plus the following lifecycle methods:

| Method | Returns | Notes |
|---|---|---|
| `Toggle()` | `boolean` | Toggles open/closed; returns the new `expanded` state. |
| `Expand()` | `nil` | Opens the accordion (no-op if already open). |
| `Collapse()` | `nil` | Closes the accordion (no-op if already closed). |
| `IsExpanded()` | `boolean` | Returns `true` when the panel is currently open. |
| `SetTitle(s)` | `nil` | Updates the header text at runtime. |
| `SetIcon(name)` | `nil` | Swaps the leading icon. Only applies when an `Icon` was set at creation. |
| `Destroy()` | `nil` | Removes the accordion and all its children from the UI. |

## Opening and closing

Expanding and collapsing are mirror images of each other, not a grow and a snap:

- **Expanding** places the content one `Spacing.gap` below its resting position and slides it up
  while the card's height opens to fit. The divider under the header fades in from nothing rather
  than arriving with the first pixel of height.
- **Collapsing** runs the same move backwards on the exit curve: the divider fades out *before* it
  is hidden, the content slides back down that same gap, and the height closes to the 34 px header.
  The content and the divider are only hidden once the height has finished closing, so nothing
  vanishes mid-slide.

The caret turns 90 degrees on a calm curve over `Motion.base`, with no overshoot — a Back curve on a
16 px glyph reads as a jitter rather than a flourish — and its tint lifts from the muted structural
colour to the foreground one while the panel is open. The acknowledgement of the click lives on its
scale instead: every toggle, whether from a click or from `Expand()` / `Collapse()`, dips the caret
to `Motion.popFrom` and springs it back to full size.

The header answers a pointer on its own: a wash inside the header fades in on hover and deepens
while it is held, and the card behind it keeps its own colour throughout. Devices with no pointer
skip the wash entirely.

Once an expanded card has finished opening, its height is handed back to the engine, so controls
added to an open accordion afterwards keep fitting with no re-measure. An accordion with nothing in
it skips the height animation altogether and simply grows when its first row is mounted.

`Expanded = true` starts the accordion open with no animation at all, and with animation disabled
(reduced motion) every open and close lands in place.

## Examples

```lua
-- Collapsed by default; nest multiple controls
local acc = tab:AddAccordion({ Title = "Advanced settings", Icon = "settings-2", Expanded = false })
acc:AddToggle({ Text = "Nested toggle", Default = true })
acc:AddSlider({ Text = "Nested slider", Min = 0, Max = 10, Default = 5 })
acc:AddButton({ Text = "Nested button" })

-- Expanded by default
local acc2 = tab:AddAccordion({ Title = "Open on load", Icon = "settings-2", Expanded = true })
acc2:AddToggle({ Text = "Nested toggle", Default = false })
acc2:AddButton({ Text = "Nested button" })

-- Control programmatically
local acc3 = tab:AddAccordion({ Title = "Controlled", Icon = "rows-3" })
acc3:AddLabel("Some content")

acc3:Expand()
print(acc3:IsExpanded())  -- true
acc3:Collapse()
acc3:Toggle()             -- opens again

acc3:SetTitle("Renamed section")
acc3:SetIcon("star")
```
