# NumberBox

A numeric input with − and + step buttons, a scroll wheel, and a field you can type into. `Format`, `Decimals`, `Prefix` and `Suffix` control how the value is rendered; whatever they are set to, the field accepts shorthand like `2k` or `4.4m` when the user types.

## Basic usage

```lua
local nb = tab:AddNumberBox({
  Text    = "Amount",
  Default = 10,
  Min     = 0,
  Max     = 100,
  Step    = 5,
})
print(nb.GetValue())
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | — | Row label. Omit for a label-less box that spans the full width. |
| `Default` | `number` | `0` | Initial value, clamped to `Min..Max`. |
| `Min` | `number` | — | Minimum allowed value. The − button dims when the value reaches this. |
| `Max` | `number` | — | Maximum allowed value. The + button dims when the value reaches this. |
| `Step` | `number` | `1` | Amount added or subtracted per button press or scroll tick. |
| `Format` | `string` | — | `"compact"` renders `1.5k` / `123.5M`; `"comma"` adds thousands separators (`1,234,567`). Omit for plain numbers. Affects display only — see [Typing a value](#typing-a-value). |
| `Decimals` | `number` | — | Decimal places to display. `"compact"` and `"comma"` use `1` when it is omitted; with no `Format` the number is rendered as-is unless `Decimals` is given. Trailing zeros are always stripped, so `Decimals = 2` renders `1500` as `1.5k`, not `1.50k`. |
| `Prefix` | `string` | — | Non-editable text prepended to the displayed value (e.g. `"$"`). Stripped automatically when the user types a new value. |
| `Suffix` | `string` | — | Non-editable text appended to the displayed value (e.g. `"%"`). Stripped automatically when the user types a new value. |
| `Description` | `string` | — | Muted secondary line rendered below the label. |
| `Disabled` | `boolean` | `false` | Builds the field dimmed; stepping, the wheel and typing are all refused. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Flag` | `string` | — | Config key used to persist the value across sessions. |
| `Callback` | `function(number)` | — | Called with the new value after each confirmed change. |

## API

| Method | Returns | Notes |
|---|---|---|
| `GetValue()` | `number` | Returns the current numeric value. |
| `SetValue(n)` | `nil` | Sets the value (clamped to `Min..Max`) and fires `Callback`. |
| `SetMin(n)` | `nil` | Updates the minimum bound; re-clamps the current value. |
| `SetMax(n)` | `nil` | Updates the maximum bound; re-clamps the current value. |
| `SetEnabled(b)` | `nil` | Dims the field and blocks the steppers, the wheel and typing when `false`. `SetValue` and flag restores still apply — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Destroy()` | `nil` | Removes the control from the UI. |

## Stepping

Clicking − or + moves the value by one `Step`. Holding the button down steps once immediately, waits
about a third of a second, and then repeats, accelerating from roughly eight steps a second up to a
ceiling of about thirty. Releasing the button — or sliding the pointer off it — stops the repeat, and
so does reaching a bound.

At a bound the button refuses rather than doing nothing silently: its glyph dims once the value
reaches `Min` (for −) or `Max` (for +), and a press that cannot be honoured nudges the whole field a
couple of pixels toward the side that was pressed before settling back exactly where it started.
With animation disabled (reduced motion) the field does not move at all; the dimmed glyph carries
the message on its own.

## The scroll wheel

The wheel moves the value by one `Step` per tick, but only while the pointer is genuinely over the
field, or while the field holds keyboard focus. A wheel event that merely passes over the row on
its way past is left alone, so scrolling a tab full of number boxes scrolls the tab instead of
rewriting every value it passes.

## Typing a value

While the field is focused it shows the raw number — no `Format`, no `Prefix`, no `Suffix` — so
what you edit is what you get. On focus-loss the text is parsed, clamped to `Min..Max` and
re-rendered in the display format.

Parsing is deliberately forgiving and does **not** depend on `Format`:

| Typed | Parsed as |
|---|---|
| `1k` | 1,000 |
| `4.4m` | 4,400,000 |
| `72B` | 72,000,000,000 |
| `1.5t` | 1,500,000,000,000 |

The `k` / `m` / `b` / `t` suffixes are case-insensitive. Commas, spaces and a leading `+` are
stripped, and so are the configured `Prefix` and `Suffix`, so `$2.5k` parses to 2500 on a field
built with `Prefix = "$"`. Text that is not a number at all (`abc`, an empty field, a bare `k`) is
rejected and the field simply re-renders the value it already had.

## Examples

```lua
-- Basic
tab:AddNumberBox({ Text = "Amount", Default = 10, Min = 0, Max = 100, Step = 5 })

-- With a description
tab:AddNumberBox({
  Text        = "Quantity",
  Description = "Steps of 1.",
  Default     = 5,
  Min         = 0,
  Max         = 50,
})

-- Compact notation (1.5k, 123M); type "2k" or "4.4m" directly
tab:AddNumberBox({
  Text    = "Gold",
  Format  = "compact",
  Default = 1500,
  Min     = 0,
  Max     = 1000000000,
  Step    = 100,
})

-- Comma grouping with a currency prefix
tab:AddNumberBox({
  Text    = "Balance",
  Format  = "comma",
  Prefix  = "$",
  Default = 1234567,
  Min     = 0,
  Max     = 1000000000,
  Step    = 1000,
})

-- Suffix unit
tab:AddNumberBox({ Text = "Volume", Suffix = "%", Default = 80, Min = 0, Max = 100, Step = 5 })

-- Flag-bound — value persists across sessions
tab:AddNumberBox({ Text = "Saved count", Flag = "ex_number", Default = 3, Min = 0, Max = 99 })

-- Adjust bounds at runtime
local nb = tab:AddNumberBox({ Text = "Score", Default = 50, Min = 0, Max = 100 })
nb.SetMax(200)   -- expand the ceiling
nb.SetValue(150) -- set a value that was previously out of range
```
