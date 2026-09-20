# SelectBox

A dropdown for choosing one or many options, with optional search, per-item icons/descriptions, async loading, and flag persistence.

## Basic usage

```lua
local sel = tab:AddSelectBox({ Text = "Mode", Options = { "Auto", "Manual", "Hybrid" }, Default = "Auto" })
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | — | Field label |
| `Options` | `table` | `{}` | Strings, or `{ Value, Text/Label, Icon?, Desc? }`, or `{ Divider = true }` |
| `Default` | any | — | Selected value (or table of values when `Multi`) |
| `Multi` | `bool` | `false` | Allow multiple selections |
| `AllowNone` | `bool` | `false` | Permit an empty selection |
| `Searchable` | `bool` | auto | Search box. Left unset it appears once there are **more than 5** selectable options (`Divider` entries are not counted); `true` or `false` forces it either way. Never shown while the list is loading |
| `Disabled` | `bool` | `false` | Builds dimmed; the field will not open. See [Enabled and disabled](/controls/#enabled-and-disabled) |
| `Loading` | `bool` | `false` | Start in the loading state — see [Loading](#loading) |
| `Description` | `string` | — | Helper text under the label |
| `OnOpen` | `function` | — | `OnOpen(api)` — refresh options each time the dropdown opens |
| `LoadOptions` | `function` | — | Provider that returns the options table. While the call is pending the field and the dropdown both show their [loading state](#loading); both clear when the function returns. The fetch is **deferred to the next `Heartbeat`**, so a loader that yields (HTTP/datastore) never blocks the rest of the UI from rendering; the GUI update runs in a signal-handler context that keeps the executor capability needed to mutate a protected (`gethui`/`CoreGui`) UI (a `task.spawn` thread loses it). Combine with `OnOpen = function(api) api.Reload() end` to refetch on every open. |
| `Timeout` | `number` | `60` | Seconds after which the loading spinner is cleared if `LoadOptions` has not returned. A result that arrives later still applies. |
| `Callback` | `function` | — | Called with the new value on change |
| `Flag` | `string` | — | Persist the selected `Value` to config |

When an option is a table, `Value` is stored/flagged and `Text`/`Label` is shown in the UI.

## API

| Method | Returns | Notes |
|---|---|---|
| `GetValue()` | any | Current value(s) |
| `SetValue(v)` | `nil` | Set selection programmatically |
| `SetOptions(o)` | `nil` | Replace the option list |
| `SetDisabled(b)` | `nil` | Dims the field and the caret and blocks `Open`. `SetValue` and flag restores still apply — see [Enabled and disabled](/controls/#enabled-and-disabled) |
| `SetLoading(b)` | `nil` | Toggle the loading state |
| `Reload()` | `nil` | Re-run `LoadOptions` (loading state is handled automatically) |
| `Open()` | `nil` | Open the dropdown. Does nothing while disabled or already open; runs `OnOpen` first |
| `Close()` | `nil` | Close the dropdown |
| `Filter(q)` | `nil` | Apply the same filter the search box applies: a case-insensitive substring match over each option's value, label and description. `Filter("")` shows everything again |
| `Destroy()` | `nil` | Closes the dropdown and removes the control |

## The dropdown

The dropdown is a floating popover, not part of the tab's scroll content. It opens just below the
field, flips above it when there is no room below (and there is room above), and is clamped
horizontally so it can never run off the side of the screen. It follows the window's UI scale, and
it closes on a click anywhere outside it or as soon as the control is scrolled out of view.

It grows out of the field rather than simply appearing: the list starts a few pixels nearer the
field and just under full size, then slides into place — downward when it opened below the field,
upward when it flipped above it — so the direction of the movement tells you which side it took.
The caret at the right of the field turns over at the same time, pointing up for as long as there
is a list attached to it, and turns back on close. Closing reverses the
growth: the dropdown is gone as far as your code is concerned the moment `Close()` returns, while
the detached frame shrinks away and is destroyed once that finishes. The slide distance is
`Motion.popSlide`. With animations disabled each of these lands in place instead, the turned caret
included.

The popover is frosted like the window shell, but one step lighter so the content it covers stays
readable through it. That alpha is its own token, `Acrylic.popoverFrost`, shared with the color
picker's popover — see [Theming — Acrylic](/guide/theming#acrylic).

### Empty results

When every option is filtered away — by the search box or by a `Filter(q)` call — the list is
replaced by a muted **No results** block. A select box built with no options at all shows the same
block the moment it is opened. The first option coming back into view hides it again.

### Loading

While the list is loading, the field hides its current value and reads `Loading…`, and the caret
is replaced by a spinner. Opening it shows three shimmering placeholder lines of uneven width
where the options will land, rather than an empty box or a single line of text — and no search
box, since there is nothing yet to search. All of it clears when the options arrive.

The state is entered by `Loading = true`, by `SetLoading(true)`, and automatically for the whole
time a `LoadOptions` call is pending.

## Examples

Single, multi, and per-item icon/description:

```lua
tab:AddSelectBox({ Text = "Tags", Options = { "A", "B", "C" }, Multi = true, Default = { "A" } })

tab:AddSelectBox({ Text = "Weapon", AllowNone = true, Options = {
  { Value = "Bow", Icon = "target", Desc = "Ranged" },
  { Divider = true },
  { Value = "Shield", Icon = "shield", Desc = "Defense" },
} })
```

Async load with `LoadOptions` — one function returns the options (it may yield). The field
shows its loading state automatically until the function returns, and the call is async so it
never blocks other controls. The stored `Value` differs from the shown `Text`:

```lua
local WEAPON_DB = { wpn_001 = "Bow", wpn_002 = "Shield", wpn_003 = "Sword" }
local function weaponOptions()
  task.wait(3) -- HTTP, datastore, etc. — may take a few seconds
  local out = {}
  for id, name in pairs(WEAPON_DB) do out[#out + 1] = { Value = id, Text = name } end
  return out
end

-- loads on creation; Timeout defaults to 60s. No manual SetLoading needed.
local wsel = tab:AddSelectBox({ Text = "Weapon", Flag = "weapon_id", LoadOptions = weaponOptions })

-- re-run the loader any time (loading is handled for you)
tab:AddButton({ Text = "Reload", Callback = function() wsel.Reload() end })
```

Runtime option replacement and callback notification:

```lua
local sel = tab:AddSelectBox({ Text = "Mode", Options = { "Auto", "Manual", "Hybrid" }, Default = "Auto" })

-- shuffle options at runtime
sel.SetOptions({ "Apple", "Banana", "Cherry" })

-- flag-bound — value persists across sessions
tab:AddSelectBox({ Text = "Saved choice", Flag = "ex_select", Options = { "One", "Two", "Three" }, Default = "One" })

-- notify on change
tab:AddSelectBox({ Text = "Notify", Options = { "Red", "Green", "Blue" }, Default = "Red",
  Callback = function(v) print("Picked:", v) end })
```
