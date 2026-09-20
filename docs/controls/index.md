# Controls

Controls are UI elements that you call on a **tab** or an **accordion**. Every `Add*` method is available on both.

```lua
local tab = window:AddTab({ Name = "Settings" })
tab:AddLabel("Hello")

local acc = tab:AddAccordion({ Title = "Advanced" })
acc:AddLabel("Nested")
```

Any control that accepts a `Flag` option automatically saves and restores its value via the config system — see [Config & Flags](/guide/config-and-flags).

## Control reference

| Control | Purpose |
|---|---|
| [Label](/controls/label) | Text with runtime `SetText`; single-line, or multi-line via `Variant = "paragraph"` |
| [Paragraph](/controls/paragraph) | Multi-line wrapped text (wraps + honors `\n`) for descriptions |
| [Section](/controls/section) | Uppercase group heading |
| [Separator](/controls/separator) | 1 px horizontal divider |
| [Button](/controls/button) | Clickable action button |
| [Toggle](/controls/toggle) | On/off boolean switch |
| [TextBox](/controls/textbox) | Single-line text input |
| [NumberBox](/controls/numberbox) | Numeric text input with min/max clamping |
| [Slider](/controls/slider) | Draggable range input |
| [SelectBox](/controls/selectbox) | Dropdown option picker |
| [Keybind](/controls/keybind) | Keyboard shortcut recorder |
| [ColorPicker](/controls/colorpicker) | HSV color picker in a floating popover |
| [Image](/controls/image) | Roblox asset or Lucide glyph |
| [ProgressBar](/controls/progressbar) | Animated fill bar (0–1), or an indeterminate sweep |
| [Table](/controls/table) | Scrollable data table |
| [Card](/controls/card) | Rich content card with banner, title, body, and action buttons |
| [Resizable](/controls/resizable) | Draggable split-pane container; each pane is a full control host |
| [Accordion](/controls/accordion) | Collapsible section that hosts nested controls |

## Common handle members

Every control handle exposes a `Destroy()` method that removes it from the UI, and receives a host-injected `SetLocked(b)` (used by the accordion lock behavior) — this is injected on every control with a `.Frame`, not only those inside an Accordion.

Most controls use dot-call style (`ctl.Method()` — e.g. SelectBox, Keybind, ColorPicker, Table), while Accordion uses colon-call style (`acc:Method()`).

## Enabled and disabled

Toggle, Slider, Keybind, NumberBox, TextBox, SelectBox, ColorPicker and [Button](/controls/button)
can be taken out of the user's reach. The method is not spelled the same on all of them, so check
the control's own page; every one of them also accepts a `Disabled = true` build option that starts
the control in that state.

| Control | Method |
|---|---|
| [Toggle](/controls/toggle) | `SetEnabled(b)` |
| [Slider](/controls/slider) | `SetEnabled(b)` |
| [Keybind](/controls/keybind) | `SetEnabled(b)` |
| [NumberBox](/controls/numberbox) | `SetEnabled(b)` |
| [TextBox](/controls/textbox) | `SetEnabled(b)`, or `SetDisabled(b)` for the inverse |
| [SelectBox](/controls/selectbox) | `SetDisabled(b)` |
| [ColorPicker](/controls/colorpicker) | `SetDisabled(b)` |
| [Button](/controls/button) | `SetEnabled(b)` |

The contract behind them is the same everywhere:

- **It blocks user input only.** `Set`, `SetValue`, `SetText`, `SetColor` and a
  [`Flag`](/guide/config-and-flags) restore still update both the value and the visuals while the
  control is disabled. Disabling is not a way to freeze a value.
- **Refused input fires nothing.** A click, drag, keystroke or scroll that the disabled state
  turned away does not run `Callback` or `OnChanged`.
- **A gesture already under way is finished, not abandoned.** Disabling a Slider or a ColorPicker
  mid-drag ends the drag and keeps the value it had reached; a Keybind that was listening for a
  key stops listening instead of staying armed.
- **Re-enabling restores what each part was showing**, not a blanket default — a NumberBox step
  glyph that was dimmed because the value sits at `Max` comes back dimmed.
- **It is independent of `SetLocked`.** The dimmed state and the lock scrim can be on at the same
  time, and clearing one never clears the other.

```lua
local t = tab:AddToggle({ Text = "Auto farm", Flag = "autofarm" })

t.SetEnabled(false)   -- dimmed; clicking it does nothing
t.Set(true)           -- ...but this still applies, and the switch still slides across
print(t.Get())        -- true
t.SetEnabled(true)
```
