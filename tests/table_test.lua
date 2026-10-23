local h = require("tests.helper")
local R = h.loadLib(); local Tbl, Create = R.Table, R.Create
h.describe("table", function()
  h.it("renders header + data rows; SetData rebuilds", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "Name", "Score" },
      Rows = { { "A", "10" }, { "B", "20" } } })
    local rows0 = 0
    for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then rows0 = rows0 + 1 end end
    h.expect(rows0).toBe(2)
    t.SetData({ { "C", "30" } })
    local rows = 0
    for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then rows = rows + 1 end end
    h.expect(rows).toBe(1)
  end)
  h.it("draws a HeaderRule hairline under the header on the root (not in Body)", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
    local rule = t.Frame:FindFirstChild("HeaderRule")
    h.expect(rule ~= nil).toBeTruthy()
    h.expect(rule.BackgroundColor3).toBe(R.Theme.Colors.border)
    h.expect(rule.BackgroundTransparency).toBe(R.Theme.Stroke.divider)
    h.expect(rule.Size.Y.Offset).toBe(1)
    h.expect(t.Body:FindFirstChild("HeaderRule")).toBe(nil)
  end)
  h.it("cells use the muted font role (12px) and truncate; header cells are Medium", function()
    local t = Tbl.new({ Columns = { "A" }, Rows = { { "1" } } })
    local hc = t.Frame:FindFirstChild("Header"):FindFirstChild("Cell")
    h.expect(hc.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(hc.FontFace.Weight).toBe(h.roblox.Enum.FontWeight.Medium)
    h.expect(hc.TextTruncate).toBe(h.roblox.Enum.TextTruncate.AtEnd)
    local row; for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then row = c end end
    local bc = row:FindFirstChild("Cell")
    h.expect(bc.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(bc.FontFace.Weight).toBe(h.roblox.Enum.FontWeight.Regular)
    h.expect(row:FindFirstChildOfClass("UICorner").CornerRadius.Offset).toBe(R.Theme.Radius.xs)
  end)
  h.it("Body scrollbar comes from the scrollbar recipe and is recoloured on reskin", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local t = Tbl.new({ Columns = { "A" }, Rows = { { "1" } }, AccentReg = reg })
    h.expect(t.Body.ScrollBarThickness).toBe(R.Theme.Sizes.scrollbar)
    h.expect(t.Body.ScrollBarImageColor3).toBe(R.Theme.Colors.border)
    h.expect(t.Body.ScrollBarImageTransparency).toBe(R.Theme.Scrollbar.alpha)
    local rule = t.Frame:FindFirstChild("HeaderRule")
    local other = h.roblox.Color3.fromRGB(1, 2, 3)
    t.Body.ScrollBarImageColor3 = other; rule.BackgroundColor3 = other
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(t.Body.ScrollBarImageColor3).toBe(R.Theme.Colors.border)
    h.expect(rule.BackgroundColor3).toBe(R.Theme.Colors.border)
  end)
end)

-- Plan 3.4: an empty table reads as "nothing here yet", not as blank space. The block lives on a
-- layout-free holder over the Body rect -- never inside Body, which lays its children out as rows.
h.describe("table empty state", function()
  local function area(t) return t.Frame:FindFirstChild("EmptyArea") end
  local function block(t) local a = area(t); return a and a:FindFirstChild("Empty") end
  local function rows(t)
    local n = 0
    for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then n = n + 1 end end
    return n
  end

  h.it("a table with no rows shows a muted 'No rows' block with the inbox icon", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" } })
    local em = block(t)
    h.expect(em ~= nil).toBeTruthy()
    h.expect(em.Visible).toBe(true)
    h.expect(em:FindFirstChild("Text").Text).toBe("No rows")
    h.expect(em:FindFirstChild("Text").TextColor3).toBe(R.Theme.Colors.mutedForeground)
    h.expect(em:FindFirstChild("Icon").Image).toBe(R.Icons.get("inbox").Id)
  end)

  h.it("the block sits over the Body rect on the root, never inside Body", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" } })
    local a = area(t)
    h.expect(t.Body:FindFirstChild("Empty")).toBeNil()
    h.expect(t.Body:FindFirstChild("EmptyArea")).toBeNil()
    h.expect(rows(t)).toBe(0)                            -- and it is never mistaken for a row
    h.expect(a.Position.Y.Offset).toBe(t.Body.Position.Y.Offset)
    h.expect(a.Size.Y.Offset).toBe(t.Body.Size.Y.Offset)
    h.expect(a.Size.X.Scale).toBe(1)
    h.expect(a.BackgroundTransparency).toBe(1)
    -- siblings compare ZIndex: 2 draws above Body, which is left at the engine default (1)
    h.expect(a.ZIndex).toBe(2)
    h.expect(t.Body.ZIndex).toBeNil()
  end)

  h.it("a row hides the block and Clear brings it back", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
    h.expect(block(t).Visible).toBe(false)
    t.Clear()
    h.expect(block(t).Visible).toBe(true)
    h.expect(rows(t)).toBe(0)
    t.AddRow({ "2" })
    h.expect(block(t).Visible).toBe(false)
    t.SetData({})                                        -- SetData with nothing empties it again
    h.expect(block(t).Visible).toBe(true)
    t.SetData({ { "3" }, { "4" } })
    h.expect(block(t).Visible).toBe(false)
    h.expect(rows(t)).toBe(2)
  end)

  h.it("the reskin closure re-reads the muted tokens for the block", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local theme = R.Theme.new()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Theme = theme, AccentReg = reg })
    local text = block(t):FindFirstChild("Text")
    text.TextColor3 = h.roblox.Color3.fromRGB(1, 2, 3)
    R.Theme.applyMode(theme, "light")
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(text.TextColor3).toBe(theme.Colors.mutedForeground)
  end)
end)

-- Plan 2.7 (table half): rows answer hover with the FILL kind -- the row's own transparency,
-- never a wash Frame (the Row is a horizontal UIListLayout, a Frame would become a column) and
-- never BackgroundColor3 (theme_test pins the first row's colour by identity).
h.describe("table row hover", function()
  local theme, mock = R.Theme, h.mock
  local function firstRow(t)
    for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then return c end end
  end

  h.it("hover tweens the row's own transparency to Opacity.rowHover and back to rest", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
    local row = firstRow(t)
    local colour = row.BackgroundColor3
    h.expect(row.BackgroundTransparency).toBe(0)
    mock.resetTweens()
    row.MouseEnter:Fire()
    h.expect(row.BackgroundTransparency).toBe(theme.Opacity.rowHover)
    local tw = mock.tweensFor(row)[1]
    h.expect(tw ~= nil).toBeTruthy()
    h.expect(tw.Info.Time).toBe(theme.Motion.hover)
    h.expect(row.BackgroundColor3).toBe(colour)          -- identity: the fill kind never writes it
    row.MouseLeave:Fire()
    h.expect(row.BackgroundTransparency).toBe(0)
    h.expect(row.BackgroundColor3).toBe(colour)
  end)
  h.it("adds no child Frame to the row (a wash would lay out as an extra column)", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A", "B" }, Rows = { { "1", "2" } } })
    local row = firstRow(t)
    h.expect(row:FindFirstChild("Hover")).toBeNil()
    local frames = 0
    for _, c in ipairs(row:GetChildren()) do if c.ClassName == "Frame" then frames = frames + 1 end end
    h.expect(frames).toBe(0)
  end)
  h.it("the header row never hovers (it has no fill of its own)", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
    local header = t.Frame:FindFirstChild("Header")
    header.MouseEnter:Fire()
    h.expect(header.BackgroundTransparency).toBe(1)
  end)
  h.it("press dips the row and a release over it returns to the hover value", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
    local row = firstRow(t)
    local Enum, Vector2 = h.roblox.Enum, h.roblox.Vector2
    row.MouseEnter:Fire()
    -- a Row is a plain Frame, so the recipe presses it through InputBegan/InputEnded
    row.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(0, 0) })
    h.expect(row.BackgroundTransparency).toBe(theme.Opacity.rowHover)   -- pressAlpha defaults to hover for fill
    row.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(0, 0) })
    h.expect(row.BackgroundTransparency).toBe(theme.Opacity.rowHover)
    row.MouseLeave:Fire()
    h.expect(row.BackgroundTransparency).toBe(0)
  end)
  h.it("SetData drops the old rows' handlers: an orphaned row no longer repaints", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
    local old = firstRow(t)
    t.SetData({ { "2" } })
    old.MouseEnter:Fire()
    h.expect(old.BackgroundTransparency).toBe(0)         -- disconnected with the row
    local fresh = firstRow(t)
    fresh.MouseEnter:Fire()
    h.expect(fresh.BackgroundTransparency).toBe(theme.Opacity.rowHover)
  end)
  h.it("reduced motion: hover lands the rest/hover values with zero tweens", function()
    h.withReducedMotion(R, function()
      local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A" }, Rows = { { "1" } } })
      local row = firstRow(t)
      mock.resetTweens()
      row.MouseEnter:Fire()
      h.expect(row.BackgroundTransparency).toBe(theme.Opacity.rowHover)
      row.MouseLeave:Fire()
      h.expect(row.BackgroundTransparency).toBe(0)
      h.expect(mock.tweenCount()).toBe(0)
    end)
  end)
end)
-- Editable cells: a column marked Editable renders an input-like cell (the library's TextBox
-- look: background fill, border stroke, focus ring) that commits on FocusLost through OnEdit.
-- Plain string columns and plain array rows keep today's TextLabel cells untouched.
h.describe("table editable cells", function()
  local theme, Enum = R.Theme, h.roblox.Enum
  local function bodyRows(t)
    local out = {}
    for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then out[#out + 1] = c end end
    table.sort(out, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    return out
  end
  local function cellAt(row, col)
    for _, c in ipairs(row:GetChildren()) do
      if (c.Name == "Cell" or c.Name == "EditCell") and c.LayoutOrder == col then return c end
    end
  end
  local function inputAt(t, rowIndex, col)
    local cell = cellAt(bodyRows(t)[rowIndex], col)
    return cell and cell:FindFirstChild("Input"), cell
  end
  -- type, then lose focus: the commit path a player takes (Enter or clicking away)
  local function typeInto(input, text)
    input.Focused:Fire()
    input.Text = text
    input:GetPropertyChangedSignal("Text"):Fire()
    input.FocusLost:Fire(true)
  end
  local function petTable(extra)
    local opts = {
      Parent = Create("Frame", {}),
      Columns = { { Text = "Pet", Width = 2 }, { Text = "Before pickup (s)", Editable = true, Placeholder = "0" },
        { Text = "Before placing back (s)", Editable = true } },
      Rows = { { Key = "{uuid-1}", Cells = { "Peacock", "0.6", "0" } },
        { Key = "{uuid-2}", Cells = { "Owl", "1", "2" } } },
    }
    for k, v in pairs(extra or {}) do opts[k] = v end
    return Tbl.new(opts)
  end

  h.it("plain string columns and array rows still render TextLabel cells that Fill", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "A", "B" }, Rows = { { "1", 2 } } })
    local row = bodyRows(t)[1]
    for col = 1, 2 do
      local c = cellAt(row, col)
      h.expect(c.ClassName).toBe("TextLabel")
      h.expect(c.Name).toBe("Cell")
      h.expect(c:FindFirstChildOfClass("UIFlexItem").FlexMode).toBe(Enum.UIFlexMode.Fill)
    end
    h.expect(cellAt(row, 2).Text).toBe("2")
    h.expect(row:FindFirstChild("EditCell")).toBeNil()
    local hc = t.Frame:FindFirstChild("Header"):FindFirstChild("Cell")
    h.expect(hc:FindFirstChildOfClass("UIFlexItem").FlexMode).toBe(Enum.UIFlexMode.Fill)
  end)

  h.it("an Editable column renders an input-like cell; the header stays a label", function()
    local t = petTable()
    local input, cell = inputAt(t, 1, 2)
    h.expect(cell.Name).toBe("EditCell")
    h.expect(cell.BackgroundColor3).toBe(theme.Colors.background)
    local stroke = cell:FindFirstChildOfClass("UIStroke")
    h.expect(stroke.Color).toBe(theme.Colors.border)
    h.expect(stroke.Thickness).toBe(1)
    h.expect(cell:FindFirstChildOfClass("UICorner") ~= nil).toBeTruthy()
    -- 2px clear above and below in the 24px row, centred on the line (the ring fills that gap)
    h.expect(cell.Size.Y.Scale).toBe(1)
    h.expect(cell.Size.Y.Offset).toBe(-4)
    h.expect(cell:FindFirstChildOfClass("UIFlexItem").ItemLineAlignment).toBe(Enum.ItemLineAlignment.Center)
    h.expect(input.ClassName).toBe("TextBox")
    h.expect(input.Text).toBe("0.6")
    h.expect(input.ClearTextOnFocus).toBe(false)
    h.expect(input.TextEditable).toBe(true)
    h.expect(input.PlaceholderText).toBe("0")
    h.expect(input.TextColor3).toBe(theme.Colors.foreground)
    h.expect(input.TextSize).toBe(theme.Font.muted.Size)
    h.expect(cellAt(bodyRows(t)[1], 1).ClassName).toBe("TextLabel")   -- Pet is not editable
    local header = t.Frame:FindFirstChild("Header")
    local inset = cell:FindFirstChildOfClass("UIPadding").PaddingLeft.Offset
    for _, c in ipairs(header:GetChildren()) do
      if c.Name == "Cell" and c.LayoutOrder == 2 then
        h.expect(c.ClassName).toBe("TextLabel")
        -- the heading text starts where the value text does, inside the field's padding
        h.expect(c:FindFirstChildOfClass("UIPadding").PaddingLeft.Offset).toBe(inset)
      end
      if c.Name == "Cell" and c.LayoutOrder == 1 then h.expect(c:FindFirstChildOfClass("UIPadding")).toBeNil() end
    end
  end)

  h.it("a commit calls OnEdit(rowKey, col, text, oldText) once and keeps the typed text on nil", function()
    local calls = {}
    local t = petTable({ OnEdit = function(...) calls[#calls + 1] = { ... } end })
    local input = inputAt(t, 2, 3)
    typeInto(input, "4.5")
    h.expect(#calls).toBe(1)
    h.expect(calls[1]).toEqual({ "{uuid-2}", 3, "4.5", "2" })
    h.expect(input.Text).toBe("4.5")
    h.expect(t.GetCell("{uuid-2}", 3)).toBe("4.5")
  end)

  h.it("a blur with the text unchanged is not an edit", function()
    local n = 0
    local t = petTable({ OnEdit = function() n = n + 1 end })
    local input = inputAt(t, 1, 2)
    input.Focused:Fire(); input.FocusLost:Fire(false)
    h.expect(n).toBe(0)
  end)

  h.it("OnEdit returning false puts the previous text back", function()
    local t = petTable({ OnEdit = function() return false end })
    local input = inputAt(t, 1, 2)
    typeInto(input, "-3")
    h.expect(input.Text).toBe("0.6")
    h.expect(t.GetCell("{uuid-1}", 2)).toBe("0.6")
  end)

  h.it("OnEdit returning a string shows that instead, and it becomes the next oldText", function()
    local seen
    local t = petTable({ OnEdit = function(_, _, text, old)
      seen = old
      return (text:gsub(",", "."))
    end })
    local input = inputAt(t, 1, 2)
    typeInto(input, "1,5")
    h.expect(input.Text).toBe("1.5")
    h.expect(t.GetCell("{uuid-1}", 2)).toBe("1.5")
    typeInto(input, "2")
    h.expect(seen).toBe("1.5")
  end)

  h.it("OnEdit returning a number shows it as text", function()
    local t = petTable({ OnEdit = function() return 42 end })
    local input = inputAt(t, 1, 2)
    typeInto(input, "41.9")
    h.expect(input.Text).toBe("42")
    h.expect(t.GetCell("{uuid-1}", 2)).toBe("42")
  end)

  h.it("an OnEdit that throws reverts the cell and warns instead of failing silently", function()
    local prev, said = rawget(_G, "warn"), nil
    _G.warn = function(m) said = m end
    local ok, err = pcall(function()
      local t = petTable({ OnEdit = function() error("boom") end })
      local input = inputAt(t, 1, 2)
      typeInto(input, "9")
      h.expect(input.Text).toBe("0.6")
      h.expect(t.GetCell("{uuid-1}", 2)).toBe("0.6")
    end)
    _G.warn = prev
    if not ok then error(err, 0) end
    h.expect(said ~= nil and said:find("boom", 1, true) ~= nil).toBeTruthy()
  end)

  h.it("SetCell writes the text without calling OnEdit; unknown keys are reported", function()
    local n = 0
    local t = petTable({ OnEdit = function() n = n + 1 end })
    h.expect(t.SetCell("{uuid-1}", 2, 7)).toBe(true)
    local input = inputAt(t, 1, 2)
    h.expect(input.Text).toBe("7")
    h.expect(t.GetCell("{uuid-1}", 2)).toBe("7")
    h.expect(t.SetCell("{uuid-1}", 1, "Peafowl")).toBe(true)        -- a label cell too
    h.expect(cellAt(bodyRows(t)[1], 1).Text).toBe("Peafowl")
    h.expect(t.GetCell("{uuid-1}", 1)).toBe("Peafowl")
    h.expect(n).toBe(0)
    h.expect(t.SetCell("nope", 2, "1")).toBe(false)
    h.expect(t.SetCell("{uuid-1}", 9, "1")).toBe(false)
    h.expect(t.GetCell("nope", 2)).toBeNil()
    typeInto(input, "8")                                              -- the old text is the SetCell one
    h.expect(n).toBe(1)
  end)

  h.it("unkeyed rows are keyed by their 1-based position, counted again after SetData", function()
    local keys = {}
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = { "Name", { Text = "V", Editable = true } },
      Rows = { { "a", "1" }, { "b", "2" } }, OnEdit = function(k) keys[#keys + 1] = k end })
    typeInto(inputAt(t, 2, 2), "5")
    h.expect(keys[1]).toBe(2)
    h.expect(t.GetCell(2, 2)).toBe("5")
    t.SetData({ { "c", "3" } })
    typeInto(inputAt(t, 1, 2), "6")
    h.expect(keys[2]).toBe(1)
  end)

  h.it("AddRow takes (cells, key) or { Key, Cells }, and SetData takes both shapes", function()
    local t = petTable()
    t.AddRow({ "Cat", "3", "4" }, "{uuid-3}")
    t.AddRow({ Key = "{uuid-4}", Cells = { "Dog", "5", "6" } })
    h.expect(t.GetCell("{uuid-3}", 2)).toBe("3")
    h.expect(t.GetCell("{uuid-4}", 3)).toBe("6")
    t.AddRow({ Cells = { "Elk", "1", "2" } }, "{uuid-5}")              -- no Key inside: the argument
    h.expect(t.GetCell("{uuid-5}", 1)).toBe("Elk")
    t.SetData({ { Key = "x", Cells = { "Rat", "7", "8" } }, { "Bat", "9", "10" } })
    h.expect(#bodyRows(t)).toBe(2)
    h.expect(t.GetCell("x", 1)).toBe("Rat")
    h.expect(t.GetCell(2, 2)).toBe("9")
    h.expect(t.GetCell("{uuid-3}", 2)).toBeNil()                      -- gone with the old rows
  end)

  h.it("a row shorter than the columns still gets its editable cells (empty)", function()
    local t = petTable({ Rows = { { Key = "k", Cells = { "Peacock" } } } })
    local input = inputAt(t, 1, 3)
    h.expect(input ~= nil).toBeTruthy()
    h.expect(input.Text).toBe("")
    h.expect(t.GetCell("k", 3)).toBe("")
  end)

  h.it("a tap focuses the input through the hit button, which steps aside while editing", function()
    local t = petTable()
    local input, cell = inputAt(t, 1, 2)
    local focused = 0
    input.CaptureFocus = function() focused = focused + 1 end
    local hit = cell:FindFirstChild("Hit")
    h.expect(hit.ClassName).toBe("TextButton")
    hit.MouseButton1Click:Fire()
    h.expect(focused).toBe(1)
    input.Focused:Fire()
    h.expect(hit.Visible).toBe(false)                               -- clicks now reach the caret
    input.FocusLost:Fire(false)
    h.expect(hit.Visible).toBe(true)
  end)

  h.it("focus draws the ring like the TextBox and a blur puts the border back", function()
    local t = petTable()
    local input, cell = inputAt(t, 1, 2)
    local stroke = cell:FindFirstChildOfClass("UIStroke")
    input.Focused:Fire()
    h.expect(stroke.Color).toBe(theme.Colors.ring)
    h.expect(stroke.Thickness).toBe(theme.Stroke.focusThickness)
    input.FocusLost:Fire(false)
    h.expect(stroke.Color).toBe(theme.Colors.border)
    h.expect(stroke.Thickness).toBe(1)
  end)

  h.it("hovering an editable cell washes it and leaving clears the wash", function()
    local t = petTable()
    local _, cell = inputAt(t, 1, 2)
    cell.MouseEnter:Fire()
    local wash = cell:FindFirstChild("Hover")
    h.expect(wash ~= nil).toBeTruthy()
    h.expect(wash.BackgroundTransparency).toBe(theme.Opacity.hoverWash)
    cell.MouseLeave:Fire()
    h.expect(wash.BackgroundTransparency).toBe(1)
    local row = bodyRows(t)[1]                                      -- the row still answers hover
    row.MouseEnter:Fire()
    h.expect(row.BackgroundTransparency).toBe(theme.Opacity.rowHover)
  end)

  h.it("Width is a flex weight on the header and body cells of that column", function()
    local t = petTable()
    local header = t.Frame:FindFirstChild("Header")
    local hc1
    for _, c in ipairs(header:GetChildren()) do if c.Name == "Cell" and c.LayoutOrder == 1 then hc1 = c end end
    for _, c in ipairs({ hc1, cellAt(bodyRows(t)[1], 1) }) do
      local f = c:FindFirstChildOfClass("UIFlexItem")
      h.expect(f.FlexMode).toBe(Enum.UIFlexMode.Custom)
      h.expect(f.GrowRatio).toBe(2)
      h.expect(f.ShrinkRatio).toBe(2)
    end
    local f2 = cellAt(bodyRows(t)[1], 2):FindFirstChildOfClass("UIFlexItem")
    h.expect(f2.FlexMode).toBe(Enum.UIFlexMode.Fill)                 -- no Width: weight 1, as before
  end)

  h.it("Width weighs an editable column too", function()
    local t = Tbl.new({ Parent = Create("Frame", {}),
      Columns = { "Pet", { Text = "Wait", Editable = true, Width = 3 } }, Rows = { { "Owl", "1" } } })
    local f = cellAt(bodyRows(t)[1], 2):FindFirstChildOfClass("UIFlexItem")
    h.expect(f.FlexMode).toBe(Enum.UIFlexMode.Custom)
    h.expect(f.GrowRatio).toBe(3)
    h.expect(f.ItemLineAlignment).toBe(Enum.ItemLineAlignment.Center)
  end)

  h.it("a Width that is not a positive number fails fast", function()
    h.expect(function() Tbl.new({ Columns = { { Text = "A", Width = 0 } } }) end).toThrow("Width")
    h.expect(function() Tbl.new({ Columns = { { Text = "A", Width = "wide" } } }) end).toThrow("Width")
  end)

  h.it("SetData, Clear and Destroy drop the old cells' handlers", function()
    local n = 0
    local t = petTable({ OnEdit = function() n = n + 1 end })
    local old, oldCell = inputAt(t, 1, 2)
    local oldHit = oldCell:FindFirstChild("Hit")                   -- held: Destroy empties the cell
    local focused = 0
    old.CaptureFocus = function() focused = focused + 1 end
    t.SetData({ { Key = "z", Cells = { "Yak", "1", "1" } } })
    typeInto(old, "3")
    oldHit.MouseButton1Click:Fire()
    h.expect(n).toBe(0)
    h.expect(focused).toBe(0)
    local live = inputAt(t, 1, 2)
    t.Clear()
    typeInto(live, "4")
    h.expect(n).toBe(0)
    t.AddRow({ "Emu", "1", "1" }, "e")
    local last = inputAt(t, 1, 2)
    t.Destroy()
    typeInto(last, "5")
    h.expect(n).toBe(0)
    h.expect(t.GetCell("e", 2)).toBeNil()                          -- the records go with it
    h.expect(t.SetCell("e", 2, "6")).toBe(false)
  end)

  h.it("editable cells follow a reskin (mode) and keep a focused ring", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local th = R.Theme.new()
    local t = petTable({ Theme = th, AccentReg = reg })
    local input, cell = inputAt(t, 1, 2)
    local focusedInput, focusedCell = inputAt(t, 2, 2)
    focusedInput.Focused:Fire()
    R.Theme.applyMode(th, "light")
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(cell.BackgroundColor3).toBe(th.Colors.background)
    h.expect(cell:FindFirstChildOfClass("UIStroke").Color).toBe(th.Colors.border)
    h.expect(input.TextColor3).toBe(th.Colors.foreground)
    h.expect(input.PlaceholderColor3).toBe(th.Colors.mutedForeground)
    h.expect(focusedCell:FindFirstChildOfClass("UIStroke").Color).toBe(th.Colors.ring)
    h.expect(cellAt(bodyRows(t)[1], 1).TextColor3).toBe(th.Colors.foreground)   -- labels as before
  end)

  h.it("SetEnabled(false) makes editable cells read-only, muted and dimmed; true restores", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local t = petTable({ AccentReg = reg })
    local input, cell = inputAt(t, 1, 2)
    local focused = 0
    input.CaptureFocus = function() focused = focused + 1 end
    t.SetEnabled(false)
    h.expect(input.TextEditable).toBe(false)
    h.expect(input.TextColor3).toBe(theme.Colors.mutedForeground)
    h.expect(cell.BackgroundTransparency).toBe(theme.Opacity.disabled)
    cell:FindFirstChild("Hit").MouseButton1Click:Fire()
    h.expect(focused).toBe(0)
    for _, fn in ipairs(fns) do fn("mode") end                      -- a reskin keeps it muted
    h.expect(input.TextColor3).toBe(theme.Colors.mutedForeground)
    t.AddRow({ "Cat", "1", "1" }, "late")                            -- rows added while disabled too
    local lateInput = inputAt(t, 3, 2)
    h.expect(lateInput.TextEditable).toBe(false)
    t.SetEnabled(true)
    h.expect(input.TextEditable).toBe(true)
    h.expect(input.TextColor3).toBe(theme.Colors.foreground)
    h.expect(cell.BackgroundTransparency).toBe(0)
    h.expect(lateInput.TextEditable).toBe(true)
  end)

  h.it("an edit still open when the table is disabled is dropped, not committed", function()
    local n = 0
    local t = petTable({ OnEdit = function() n = n + 1 end })
    local input = inputAt(t, 1, 2)
    local released = 0
    input.ReleaseFocus = function() released = released + 1 end
    input.Focused:Fire()
    input.Text = "99"
    t.SetEnabled(false)
    h.expect(released).toBe(1)                                      -- the keyboard goes away
    input.FocusLost:Fire(false)                                     -- lands after the lock
    h.expect(n).toBe(0)
    h.expect(input.Text).toBe("0.6")
    h.expect(t.GetCell("{uuid-1}", 2)).toBe("0.6")
  end)

  h.it("SetData and Destroy release a cell being edited without committing it", function()
    local n = 0
    local t = petTable({ OnEdit = function() n = n + 1 end })
    local input = inputAt(t, 1, 2)
    local released = 0
    input.ReleaseFocus = function() released = released + 1; input.FocusLost:Fire(false) end
    local idle = inputAt(t, 2, 2)
    local idleReleased = 0
    idle.ReleaseFocus = function() idleReleased = idleReleased + 1 end
    input.Focused:Fire()
    input.Text = "5"
    t.SetData({ { Key = "z", Cells = { "Yak", "1", "1" } } })
    h.expect(released).toBe(1)
    h.expect(idleReleased).toBe(0)                                  -- only the focused one
    h.expect(n).toBe(0)
    local live = inputAt(t, 1, 2)
    local liveReleased = 0
    live.ReleaseFocus = function() liveReleased = liveReleased + 1 end
    live.Focused:Fire()
    t.Destroy()
    h.expect(liveReleased).toBe(1)
  end)

  h.it("Disabled = true builds the table read-only, and SetDisabled mirrors SetEnabled", function()
    local t = petTable({ Disabled = true })
    local input = inputAt(t, 1, 2)
    h.expect(input.TextEditable).toBe(false)
    t.SetDisabled(false)
    h.expect(input.TextEditable).toBe(true)
    t.SetDisabled(true)
    h.expect(input.TextEditable).toBe(false)
  end)
end)
-- Safe.mutate runs a GUI write inline when the thread holds the capability and queues it for
-- the next Heartbeat when it does not, so a hub that fills the table from a spawned thread and
-- clears it from a click mixes both. The row records must never disagree with the screen.
h.describe("table editable cells (deferred GUI writes)", function()
  local Enum = h.roblox.Enum
  local function bodyRows(t)
    local out = {}
    for _, c in ipairs(t.Body:GetChildren()) do if c.Name == "Row" then out[#out + 1] = c end end
    return out
  end
  local function block(t) return t.Frame:FindFirstChild("EmptyArea"):FindFirstChild("Empty") end
  local function cols() return { "Pet", { Text = "Wait", Editable = true } } end
  local function offThread(fn)
    R.Safe._setCapabilityCheck(function() return false end)
    local ok, err = pcall(fn)
    R.Safe._setCapabilityCheck(nil)
    if not ok then error(err, 0) end
  end
  local function inputOf(row)
    for _, c in ipairs(row:GetChildren()) do if c.Name == "EditCell" then return c:FindFirstChild("Input") end end
  end

  h.it("a row queued off-thread and cleared inline never lands, and its key is gone", function()
    local edits = 0
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = cols(), OnEdit = function() edits = edits + 1 end })
    offThread(function() t.AddRow({ "Ghost", "1" }, "ghost") end)
    h.expect(t.GetCell("ghost", 2)).toBe("1")                       -- state is already there
    t.Clear()
    h.mock.stepHeartbeat(0)
    h.expect(#bodyRows(t)).toBe(0)
    h.expect(block(t).Visible).toBe(true)
    h.expect(t.GetCell("ghost", 2)).toBeNil()
    h.expect(edits).toBe(0)
  end)

  h.it("a Clear queued off-thread leaves a row added inline after it", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = cols(), Rows = { { Key = "old", Cells = { "Owl", "2" } } } })
    offThread(function() t.Clear() end)
    t.AddRow({ "Yak", "9" }, "new")
    h.mock.stepHeartbeat(0)
    local rows = bodyRows(t)
    h.expect(#rows).toBe(1)
    h.expect(inputOf(rows[1]).Text).toBe("9")
    h.expect(block(t).Visible).toBe(false)
    h.expect(t.GetCell("new", 2)).toBe("9")
    h.expect(t.GetCell("old", 2)).toBeNil()
  end)

  h.it("a cleared table queued off-thread shows the empty block once the queue lands", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = cols(), Rows = { { "Owl", "2" } } })
    offThread(function() t.Clear() end)
    h.mock.stepHeartbeat(0)
    h.expect(#bodyRows(t)).toBe(0)
    h.expect(block(t).Visible).toBe(true)
  end)

  h.it("SetCell before a queued row lands shows on the built cell", function()
    local t = Tbl.new({ Parent = Create("Frame", {}), Columns = cols() })
    offThread(function()
      t.AddRow({ "Owl", "1" }, "k")
      h.expect(t.SetCell("k", 2, "5")).toBe(true)
    end)
    h.expect(#bodyRows(t)).toBe(0)                                  -- nothing on screen yet
    h.mock.stepHeartbeat(0)
    h.expect(inputOf(bodyRows(t)[1]).Text).toBe("5")
    h.expect(t.GetCell("k", 2)).toBe("5")
  end)
end)
h.run()
