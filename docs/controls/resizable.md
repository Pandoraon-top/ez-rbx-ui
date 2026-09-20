# Resizable

A split-pane container with a draggable grip that lets users resize two or more panes at runtime. Each pane is itself a full control host — you can call any `Add*` method on it, just like a tab or accordion. A pane is not quite a tab, though: see [What a pane does and does not forward](#pane-context).

## Basic usage

```lua
local rz = tab:AddResizable({
  Direction = "Horizontal",
  Panes = { { Default = 0.4 }, { Default = 0.6 } },
  Height = 140,
})

rz.Panes[1]:AddLabel("Left pane")
rz.Panes[1]:AddButton({ Text = "Action" })
rz.Panes[2]:AddLabel("Right pane")
rz.Panes[2]:AddToggle({ Text = "Option" })
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Direction` | `"Horizontal" \| "Vertical"` | `"Horizontal"` | Orientation of the split. Horizontal places panes side-by-side; Vertical stacks them. |
| `Panes` | `{ { Default?, Min? } }[]` | two equal panes | Array of pane definitions. `Default` is the initial size fraction (auto-normalized so fractions need not sum to 1). `Min` is the minimum fraction a pane can shrink to when dragging (default `0.1`). |
| `Height` | `number` | `160` (H) / `200` (V) | Container height in pixels. |

## API

| Member | Type | Notes |
|---|---|---|
| `Panes` | `host[]` | Array of pane host objects, one per pane definition. Each pane supports the full `Add*` control API (e.g. `rz.Panes[1]:AddLabel(…)`, `rz.Panes[2]:AddToggle(…)`). |
| `Destroy()` | `nil` | Removes the entire resizable container and disconnects all drag listeners. |

## What a pane does and does not forward {#pane-context}

A pane builds its controls through the same host mixin a tab uses, so most of the context comes
through — but two window-level registries do not reach it.

**Forwarded:**

- A `Flag` on a control in a pane persists through the window's
  [config](/guide/config-and-flags) like any other.
- Every control in a pane carries the host-injected `SetLocked(b)`, and `Locked = true` at build
  time works.
- The theme, the accent/mode re-skin hook and `Tooltip` all apply as usual.

- The tab's search indexes it: [`Window:SearchTabs(q)`](/api/window#searchtabs-query) hides and
  reveals a control inside a pane like any other, and its text keeps the tab in the filtered
  sidebar.
- `Window:LockAll()` reaches it, so a pane control is covered by the window-wide lock rather than
  staying live underneath it.

```lua
local rz = tab:AddResizable({ Panes = { {}, {} }, Height = 140 })
local t = rz.Panes[1]:AddToggle({ Text = "Auto farm", Flag = "autofarm" })

window:SearchTabs("Auto")   -- reveals it, hides everything that does not match
window:LockAll()            -- covers it too; t.SetLocked(true) still locks just this one
```

## Touch

On a touch device the grip's hit area widens to the theme's `Sizes.touchHit` (44 px by default) so
the seam can be grabbed with a thumb. Only the hit area changes — the gap between the panes, the
seam line and the grip pill stay exactly where they are, so a phone layout does not shift relative
to a desktop one.

## Examples

```lua
-- Horizontal split with custom initial sizes and min-size constraints
local rz = tab:AddResizable({
  Direction = "Horizontal",
  Panes = {
    { Default = 0.4, Min = 0.2 },
    { Default = 0.6, Min = 0.2 },
  },
  Height = 140,
})
rz.Panes[1]:AddLabel("Left pane")
rz.Panes[1]:AddButton({ Text = "Action" })
rz.Panes[2]:AddLabel("Right pane")
rz.Panes[2]:AddToggle({ Text = "Option" })

-- Vertical split
local rv = tab:AddResizable({
  Direction = "Vertical",
  Panes = { {}, {} },
  Height = 200,
})
rv.Panes[1]:AddLabel("Top pane")
rv.Panes[2]:AddLabel("Bottom pane")

-- Inside an accordion
local acc = tab:AddAccordion({ Title = "Split view", Icon = "columns-2" })
local r1 = acc:AddResizable({ Panes = { {}, {} }, Height = 100 })
r1.Panes[1]:AddLabel("Left")
r1.Panes[2]:AddLabel("Right")
```

Drag the centre grip to resize the panes. The `Min` option clamps how small a pane can become. See [Controls overview](/controls/) for the full list of `Add*` methods available on each pane.
