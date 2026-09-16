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
h.run()
