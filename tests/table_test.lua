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
h.run()
