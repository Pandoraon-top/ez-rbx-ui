# Table

A scrollable data table with a fixed header row and a scrollable body. Columns are defined once; rows can be supplied at creation time or added/replaced at runtime. Columns can be weighted wider than others, and can be made editable so the player types values straight into the cells. A table with no rows says so rather than showing an empty box.

## Basic usage

```lua
local t = tab:AddTable({
  Columns = { "Player", "Kills", "Deaths" },
  Rows    = {
    { "Alpha", "12", "3" },
    { "Bravo", "8",  "5" },
  },
})
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Columns` | `{ string \| column }` | `{}` | Column headers. Each entry is a header string, or a column table (below). |
| `Rows` | `{ row }` | `{}` | Initial rows. A row is a table of cell strings (`{ "Alpha", "12" }`) or a keyed row (`{ Key = k, Cells = { ... } }`). |
| `Height` | `number` | `120` | Height (px) of the scrollable body. The total control height is `Height + 26` (header). |
| `OnEdit` | `function(rowKey, col, text, oldText)` | `nil` | Called when the player commits an edit in an editable cell. See [Editable cells](#editable-cells). |
| `Disabled` | `boolean` | `false` | Builds the table with its editable cells read-only and dimmed. |

A column table takes these keys:

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | `""` | Header label. |
| `Editable` | `boolean` | `false` | Cells in this column are input fields the player can type in. |
| `Placeholder` | `string` | `""` | Muted hint shown in an empty editable cell. |
| `Width` | `number` | `1` | Flex weight. A column with `Width = 2` gets twice the share of a column with the default `1`. It must be a positive number; anything else is an error when the table is built. |

## API

| Method | Returns | Notes |
|---|---|---|
| `AddRow(cells, key?)` | `Frame?` | Appends one row. Pass the cells and an optional key, or one keyed row `{ Key = k, Cells = { ... } }`. Returns the row `Frame`, or `nil` when it is called from a thread that cannot touch the GUI. In that case the row is built on the next frame, and `GetCell` and `SetCell` already work on it. |
| `SetData(rows)` | `nil` | Clears all existing rows and renders `rows` from scratch. Takes both row shapes. |
| `SetCell(key, col, text)` | `boolean` | Writes one cell's text from code. It never calls `OnEdit`. Returns `false` when there is no such row or column. |
| `GetCell(key, col)` | `string?` | The cell's committed text, or `nil` when there is no such cell. |
| `SetEnabled(b)` / `SetDisabled(b)` | `nil` | Makes the editable cells read-only and dimmed, or editable again. If the player is typing in a cell when the table is disabled, that edit is dropped and `OnEdit` is not called. `SetCell` and `SetData` still work while disabled. |
| `Clear()` | `nil` | Removes all body rows without changing the header, and brings the empty block back. |
| `Destroy()` | `nil` | Removes the table from the UI. |

A row without a `Key` is keyed by its 1-based position. Positions start again at 1 after `Clear()` or `SetData()`. When two rows share a key, `SetCell` and `GetCell` reach the one added last.

## Editable cells

A column with `Editable = true` renders its body cells as small input fields with the same look as `AddTextBox`: a field background, a border, a hover wash and the focus ring. The header cell stays a plain label. Non-editable columns are unchanged.

The player taps or clicks a cell to edit it. A drag that starts on a cell still scrolls the table on a phone. The edit is committed whenever the cell loses focus, as with `AddTextBox`: Enter, a click or tap elsewhere, and Escape all commit. Then `OnEdit(rowKey, col, text, oldText)` runs, and its return value decides what the cell shows:

| `OnEdit` returns | The cell shows |
|---|---|
| `nil` (or nothing) | the text as typed |
| `false` | `oldText` again (the edit is rejected) |
| a string or number | that value instead, for example a normalized `"1.5"` for a typed `"1,5"` |

`OnEdit` is not called when the text did not change, and `SetCell` never calls it. If `OnEdit` throws an error, the cell goes back to `oldText` and the error is printed with `warn`.

`SetData` rebuilds every row. If the player is typing in a cell, that edit is dropped and the keyboard closes. To update values while the table is open, use `SetCell`.

An editable cell costs about seven instances, against two for a plain cell, and `SetData` rebuilds all of them. A few dozen editable rows is fine. For hundreds of rows, keep the rows and update them with `SetCell` rather than calling `SetData` on a timer.

```lua
local saved = { ["{uuid-1}"] = { 0.6, 0 } }

local t = tab:AddTable({
  Columns = {
    { Text = "Pet", Width = 2 },
    { Text = "Before pickup (s)", Editable = true, Placeholder = "0" },
    { Text = "Before placing back (s)", Editable = true, Placeholder = "0" },
  },
  Rows = { { Key = "{uuid-1}", Cells = { "Peacock", "0.6", "0" } } },
  OnEdit = function(key, col, text)
    local n = tonumber((text:gsub(",", ".")))
    if not n or n < 0 then return false end   -- not a number >= 0: put the old value back
    saved[key][col - 1] = n
    return tostring(n)                        -- show the normalized number
  end,
})
```

## The empty state

Whenever the body holds no rows, a muted **No rows** message with an inbox glyph is shown over the
body area. It appears on a table built without `Rows`, after `Clear()`, and after `SetData({})`, and
the first `AddRow` hides it again. It is drawn over the body rather than inside it, so it is never
mistaken for a row and never raises a scrollbar of its own.

## Examples

```lua
-- Initial data
local t = tab:AddTable({
  Columns = { "Player", "Kills", "Deaths" },
  Rows    = { { "Alpha", "12", "3" }, { "Bravo", "8", "5" } },
})

-- Add a row at runtime (e.g. from a button)
local n = 2
tab:AddButton({
  Text     = "Add row",
  Callback = function()
    n = n + 1
    t.AddRow({ "P" .. n, tostring(n), "0" })
  end,
})

-- Replace all data at once
t.SetData({
  { "Charlie", "15", "1" },
  { "Delta",   "6",  "9" },
})

-- Clear all rows
t.Clear()
```
