# Table

A scrollable data table with a fixed header row and a scrollable body. Columns are defined once; rows can be supplied at creation time or added/replaced at runtime. A table with no rows says so rather than showing an empty box.

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
| `Columns` | `{ string }` | `{}` | Column header labels. The number of entries determines how many cells each row must have. |
| `Rows` | `{ { string } }` | `{}` | Initial row data. Each row is a table of cell strings matching the column count. |
| `Height` | `number` | `120` | Height (px) of the scrollable body. The total control height is `Height + 26` (header). |

## API

| Method | Returns | Notes |
|---|---|---|
| `AddRow(cells)` | `Frame` | Appends one row to the body. `cells` is a table of strings matching the column count. Returns the row `Frame`. |
| `SetData(rows)` | `nil` | Clears all existing rows and renders `rows` from scratch. |
| `Clear()` | `nil` | Removes all body rows without changing the header, and brings the empty block back. |
| `Destroy()` | `nil` | Removes the table from the UI. |

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
