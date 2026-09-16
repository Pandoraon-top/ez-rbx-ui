local h = require("tests.helper")
local mockmod = require("tests.mock_roblox")
local Create = h.requireModule("core.create")
local Enum = h.roblox.Enum
local Instance = h.roblox.Instance

-- strict-mode toggle scoped to one test (verify_bundle runs the whole mock strict)
local function withStrict(fn)
  mockmod.strict = true
  local ok, err = pcall(fn)
  mockmod.strict = false
  if not ok then error(err, 0) end
end

-- Hand-built theme so these tests pin Create.text's contract, not core/theme.lua's live tokens.
local function fakeTheme(faceFn)
  return {
    Font = {
      title = { Weight = Enum.FontWeight.Bold, Size = 18, LineHeight = 1.2 },
      body = { Weight = Enum.FontWeight.Regular, Size = 14 },
    },
    FontFace = faceFn,
  }
end

h.describe("create", function()
  h.it("sets properties and parents children", function()
    local parent = h.roblox.Instance.new("ScreenGui")
    local frame = Create("Frame", {
      Name = "Root",
      BackgroundTransparency = 0.15,
      Parent = parent,
      Create("UICorner", { CornerRadius = h.roblox.UDim.new(0, 10) }),
      Create("TextLabel", { Name = "Title" }),
    })
    h.expect(frame.Name).toBe("Root")
    h.expect(frame.Parent).toBe(parent)
    h.expect(#frame:GetChildren()).toBe(2)
    h.expect(frame:FindFirstChild("Title").ClassName).toBe("TextLabel")
  end)
  h.it("corner helper builds UICorner", function()
    local c = Create.corner(8)
    h.expect(c.ClassName).toBe("UICorner")
    h.expect(c.CornerRadius.Offset).toBe(8)
  end)
  h.it("listLayout sets vertical padding", function()
    local l = Create.listLayout({ Padding = 8 })
    h.expect(l.ClassName).toBe("UIListLayout")
    h.expect(l.Padding.Offset).toBe(8)
  end)
end)

h.describe("create.stroke", function()
  h.it("defaults thickness to 1 and leaves Transparency unwritten", function()
    local col = h.roblox.Color3.fromRGB(1, 2, 3)
    local s = Create.stroke(col)
    h.expect(s.ClassName).toBe("UIStroke")
    h.expect(s.Color).toBe(col)
    h.expect(s.Thickness).toBe(1)
    h.expect(s.Transparency).toBeNil()
  end)
  h.it("writes Transparency only when the third arg is given (0 counts)", function()
    local col = h.roblox.Color3.fromRGB(1, 2, 3)
    h.expect(Create.stroke(col, 2, 0.4).Transparency).toBe(0.4)
    h.expect(Create.stroke(col, 2, 0).Transparency).toBe(0)
    h.expect(Create.stroke(col, 2).Transparency).toBeNil()
    h.expect(Create.stroke(col, 2, nil).Transparency).toBeNil()
  end)
end)

h.describe("create.gradient", function()
  h.it("builds a UIGradient whose Color is an array of ColorSequenceKeypoints", function()
    local a, b = h.roblox.Color3.fromRGB(10, 20, 30), h.roblox.Color3.fromRGB(40, 50, 60)
    local g = Create.gradient({ rotation = 90, stops = { { 0, a }, { 1, b } } })
    h.expect(g.ClassName).toBe("UIGradient")
    h.expect(g.Rotation).toBe(90)
    h.expect(#g.Color.color).toBe(2)
    h.expect(g.Color.color[1].Time).toBe(0)
    h.expect(g.Color.color[1].Value).toBe(a)   -- identity: same token, not a copy
    h.expect(g.Color.color[2].Time).toBe(1)
    h.expect(g.Color.color[2].Value).toBe(b)
    h.expect(g.Transparency).toBeNil()          -- a colour gradient never touches alpha
  end)
  h.it("defaults rotation to 0 and keeps stop order for 3+ stops", function()
    local c = h.roblox.Color3.fromRGB(1, 1, 1)
    local g = Create.gradient({ stops = { { 0, c }, { 0.5, c }, { 1, c } } })
    h.expect(g.Rotation).toBe(0)
    h.expect(#g.Color.color).toBe(3)
    h.expect(g.Color.color[2].Time).toBe(0.5)
  end)
  h.it("throws a clear error when stops are missing or empty", function()
    h.expect(function() Create.gradient({ rotation = 45 }) end).toThrow("Create.gradient: stops")
    h.expect(function() Create.gradient({ stops = {} }) end).toThrow("Create.gradient: stops")
    h.expect(function() Create.gradient() end).toThrow("Create.gradient: stops")
  end)
end)

h.describe("create.shade", function()
  h.it("builds a UIGradient whose Transparency is a NumberSequence keypoint array", function()
    local g = Create.shade({ rotation = 90, stops = { { 0, 0 }, { 1, 0.6 } } })
    h.expect(g.ClassName).toBe("UIGradient")
    h.expect(g.Rotation).toBe(90)
    h.expect(#g.Transparency.keypoints).toBe(2)
    h.expect(g.Transparency.keypoints[1].Time).toBe(0)
    h.expect(g.Transparency.keypoints[1].Value).toBe(0)
    h.expect(g.Transparency.keypoints[2].Time).toBe(1)
    h.expect(g.Transparency.keypoints[2].Value).toBe(0.6)
    h.expect(g.Color).toBeNil()                 -- a shade never recolours the fill
  end)
  h.it("defaults rotation to 0 and throws without stops", function()
    h.expect(Create.shade({ stops = { { 0, 1 }, { 1, 0 } } }).Rotation).toBe(0)
    h.expect(function() Create.shade({}) end).toThrow("Create.shade: stops")
  end)
end)

h.describe("create.text", function()
  h.it("applies Font, TextSize, LineHeight and FontFace from the role", function()
    local seen
    local theme = fakeTheme(function(w) seen = w; return h.roblox.Font.fromName("BuilderSans", w) end)
    local lbl = Create.text(Instance.new("TextLabel"), theme, "title")
    h.expect(lbl.Font).toBe(Enum.Font.BuilderSans)
    h.expect(lbl.TextSize).toBe(18)
    h.expect(lbl.LineHeight).toBe(1.2)
    h.expect(seen).toBe(Enum.FontWeight.Bold)    -- the role's weight reaches Theme.FontFace
    h.expect(lbl.FontFace.Family).toBe("BuilderSans")
    h.expect(lbl.FontFace.Weight).toBe(Enum.FontWeight.Bold)
  end)
  h.it("returns the label so calls chain into Create() child lists", function()
    local theme = fakeTheme(nil)
    local lbl = Instance.new("TextLabel")
    h.expect(Create.text(lbl, theme, "body")).toBe(lbl)
  end)
  h.it("skips LineHeight for roles without one and FontFace when the theme resolves nil", function()
    local theme = fakeTheme(function() return nil end)
    local lbl = Create.text(Instance.new("TextLabel"), theme, "body")
    h.expect(lbl.TextSize).toBe(14)
    h.expect(lbl.LineHeight).toBeNil()
    h.expect(lbl.FontFace).toBeNil()
    h.expect(lbl.Font).toBe(Enum.Font.BuilderSans) -- Font still set so the face is BuilderSans
  end)
  h.it("tolerates a theme without FontFace", function()
    local lbl = Create.text(Instance.new("TextLabel"), fakeTheme(nil), "title")
    h.expect(lbl.TextSize).toBe(18)
    h.expect(lbl.FontFace).toBeNil()
  end)
  h.it("falls back to body for an unknown role", function()
    local theme = fakeTheme(function(w) return h.roblox.Font.fromName("BuilderSans", w) end)
    local lbl = Create.text(Instance.new("TextLabel"), theme, "nope")
    h.expect(lbl.TextSize).toBe(14)
    h.expect(lbl.LineHeight).toBeNil()
    h.expect(lbl.FontFace.Weight).toBe(Enum.FontWeight.Regular)
  end)
  h.it("throws a clear error when the theme has no usable Font table", function()
    h.expect(function() Create.text(Instance.new("TextLabel"), nil, "title") end).toThrow("Create.text")
    h.expect(function() Create.text(Instance.new("TextLabel"), { Font = {} }, "title") end).toThrow("Create.text")
  end)
  h.it("works on TextButton and TextBox under the strict mock (text-only props)", function()
    local theme = fakeTheme(function(w) return h.roblox.Font.fromName("BuilderSans", w) end)
    withStrict(function()
      for _, cls in ipairs({ "TextLabel", "TextButton", "TextBox" }) do
        local inst = Create.text(Instance.new(cls), theme, "title")
        h.expect(inst.TextSize).toBe(18)
        h.expect(inst.FontFace ~= nil).toBeTruthy()
      end
    end)
  end)
  h.it("integrates with a real Theme.new() instance", function()
    local Theme = h.requireModule("core/theme")
    local theme = Theme.new()
    local lbl = Create.text(Instance.new("TextLabel"), theme, "title")
    h.expect(lbl.Font).toBe(Enum.Font.BuilderSans)
    h.expect(lbl.TextSize).toBe(theme.Font.title.Size)
    h.expect(lbl.LineHeight).toBe(theme.Font.title.LineHeight)
    -- FontFace mirrors whatever the live theme resolves (nil-safe either way)
    local resolved = theme.FontFace(theme.Font.title.Weight)
    if resolved ~= nil then h.expect(lbl.FontFace ~= nil).toBeTruthy() else h.expect(lbl.FontFace).toBeNil() end
  end)
end)

h.run()
