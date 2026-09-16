local h = require("tests.helper")
local R = h.loadLib()
local SelectBox, Create, Overlay, Config = R.SelectBox, R.Create, R.Overlay, R.Config

-- Options/dividers/the Loading row live in the inner "List" scroll frame; the search bar
-- is pinned directly on the dropdown so it stays sticky while the list scrolls.
local function listChildren(dd) return (dd:FindFirstChild("List") or dd):GetChildren() end

h.describe("selectbox", function()
  h.it("the closed value truncates (does not overflow into the caret)", function()
    local s = SelectBox.new({ Parent = Create("Frame", {}), Text = "Mode",
      Options = { "A", "B", "C" }, Default = "A" })
    local val = s.Frame:FindFirstChild("Field"):FindFirstChild("Value")
    h.expect(val.TextTruncate.Name).toBe("AtEnd")
  end)
  h.it("single select reflects default and SetValue persists", function()
    local cfg = Config.new({ FileName = "SB", AutoSave = false })
    local s = SelectBox.new({ Parent = Create("Frame", {}), Text = "Mode",
      Options = { "A", "B", "C" }, Default = "A", Flag = "mode", Config = cfg })
    h.expect(s.GetValue()).toBe("A")
    s.SetValue("C")
    h.expect(s.GetValue()).toBe("C")
    h.expect(cfg:Get("mode")).toBe("C")
  end)
  h.it("Open mounts the dropdown into the overlay (not clipped)", function()
    local gui = h.roblox.Instance.new("ScreenGui")
    Overlay.get(gui)
    local s = SelectBox.new({ Parent = Create("Frame", {}), Options = { "X", "Y" }, Default = "X" })
    s.Open()
    local root = Overlay.get(gui)
    local found = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then found = true end end
    h.expect(found).toBeTruthy()
  end)
  h.it("clicking the overlay catcher (outside) closes the dropdown", function()
    R.Overlay.reset()
    local gui = h.roblox.Instance.new("ScreenGui")
    Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "X", "Y" }, Default = "X" })
    sb.Open()
    local root = Overlay.get(gui)
    local catcher; for _, c in ipairs(root:GetChildren()) do if c.ClassName == "ImageButton" then catcher = c end end -- name is anonymized; identify by class
    h.expect(catcher ~= nil).toBeTruthy()
    catcher.MouseButton1Click:Fire()
    local stillOpen = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then stillOpen = true end end
    h.expect(stillOpen).toBe(false)
  end)
  h.it("dropdown has a search box that filters options", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local s = SelectBox.new({ Parent = Create("Frame", {}), Options = { "Alpha", "Beta", "Gamma" }, Default = "Alpha", Searchable = true })
    s.Open()
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    h.expect(dd:FindFirstChild("Search") ~= nil).toBeTruthy()
    s.Filter("be")
    local function optVisible(text)
      for _, o in ipairs(listChildren(dd)) do
        if o.Name == "Opt" then
          for _, l in ipairs(o:GetChildren()) do
            if l.ClassName == "TextLabel" and l.Text == text then return o.Visible end
          end
        end
      end
    end
    h.expect(optVisible("Beta")).toBe(true)
    h.expect(optVisible("Alpha")).toBe(false)
  end)
  h.it("search box auto-hides for short lists, shows when long or Searchable", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local short = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    short.Open()
    local function dd()
      for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then return c end end
    end
    h.expect(dd():FindFirstChild("Search")).toBe(nil)
    short.Close()
    local many = SelectBox.new({ Parent = Create("Frame", {}),
      Options = { "A", "B", "C", "D", "E", "F", "G" }, Default = "A" })
    many.Open()
    h.expect(dd():FindFirstChild("Search") ~= nil).toBeTruthy()
  end)
  h.it("dropdown opens upward when there is no room below", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui)
    root.AbsoluteSize = h.roblox.Vector2.new(600, 400)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B", "C" }, Default = "A" })
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 380)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sb.Open()
    local dd; for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    h.expect(dd.Position.Y.Offset < 380).toBeTruthy()
  end)
  h.it("scrolling the control (AbsolutePosition change) closes the dropdown", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sb.Open()
    local function open()
      for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then return true end end
      return false
    end
    h.expect(open()).toBe(true)
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 60)
    sb.Frame:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    h.expect(open()).toBe(false)
  end)
  h.it("dropdown opens below when there is room", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui)
    root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sb.Open()
    local dd; for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    h.expect(dd.Position.Y.Offset).toBe(142)
  end)
  h.it("multi select returns an array and toggles", function()
    local s = SelectBox.new({ Options = { "A", "B", "C" }, Multi = true, Default = { "A" } })
    h.expect(#s.GetValue()).toBe(1)
    s.SetValue({ "A", "C" })
    h.expect(#s.GetValue()).toBe(2)
  end)
  h.it("multi pick re-tints the row in place without rebuilding (preserves scroll)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local big = {}; for i = 1, 20 do big[i] = "I" .. i end
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Multi = true, Options = big, Default = { "I1" } })
    sb.Open()
    local function dropdown() for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then return c end end end
    local dd1 = dropdown()
    local list = dd1:FindFirstChild("List")
    list.CanvasPosition = h.roblox.Vector2.new(0, 120) -- scrolled down
    local optC; for _, o in ipairs(list:GetChildren()) do if o.Name == "Opt" and o:GetAttribute("OptValue") == "I9" then optC = o end end
    optC.MouseButton1Click:Fire()
    h.expect(dropdown()).toBe(dd1)                                   -- same instance: not rebuilt
    h.expect(dropdown():FindFirstChild("List").CanvasPosition.Y).toBe(120) -- scroll preserved
    h.expect(#sb.GetValue()).toBe(2)
    h.expect(optC:FindFirstChild("Check").Visible).toBe(true)        -- row re-tinted as selected
    optC.MouseButton1Click:Fire()                                    -- toggle off
    h.expect(#sb.GetValue()).toBe(1)
    h.expect(optC:FindFirstChild("Check").Visible).toBe(false)
  end)
  h.it("search box is sticky: a direct child of the dropdown, not inside the scrolling list", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local s = SelectBox.new({ Parent = Create("Frame", {}), Options = { "Alpha", "Beta", "Gamma" }, Default = "Alpha", Searchable = true })
    s.Open()
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local list = dd:FindFirstChild("List")
    h.expect(list ~= nil).toBeTruthy()
    h.expect(list.ClassName).toBe("ScrollingFrame")
    h.expect(dd:FindFirstChild("Search") ~= nil).toBeTruthy()  -- search pinned on the dropdown
    h.expect(list:FindFirstChild("Search")).toBe(nil)          -- not scrolling with the options
  end)
  h.it("renders opts.Text as a Title (and omits it when absent)", function()
    local s = SelectBox.new({ Parent = Create("Frame", {}), Text = "Mode", Options = { "A", "B" }, Default = "A" })
    local ti = s.Frame:FindFirstChild("Title")
    h.expect(ti ~= nil).toBeTruthy()
    h.expect(ti.Text).toBe("Mode")
    local s2 = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A" } })
    h.expect(s2.Frame:FindFirstChild("Title")).toBe(nil)
  end)
  h.it("selected option uses a surface highlight + foreground text (not accent)", function()
    local ov = Overlay.get(h.roblox.Instance.new("ScreenGui"))
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    sb.Open()
    local dd; for _, c in ipairs(ov:GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local optA; for _, c in ipairs(listChildren(dd)) do if c.Name == "Opt" and c:GetAttribute("OptValue") == "A" then optA = c end end
    h.expect(optA.BackgroundTransparency).toBe(0)
    h.expect(optA.BackgroundColor3).toBe(R.Theme.Colors.surface)
    h.expect(optA:FindFirstChild("OptLabel").TextColor3).toBe(R.Theme.Colors.foreground)
  end)
  h.it("per-item options without Default show the first value, not a table address", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}),
      Options = { { Value = "Bow", Icon = "target", Desc = "Ranged" }, { Value = "Shield" } } })
    h.expect(sb.GetValue()).toBe("Bow")
    local field = sb.Frame:FindFirstChild("Field")
    h.expect(field:FindFirstChild("Value").Text).toBe("Bow")
  end)
  h.it("Disabled blocks opening and mutes the field", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A", Disabled = true })
    sb.Frame.MouseButton1Click:Fire()
    local function dropdownOpen()
      for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then return true end end
      return false
    end
    h.expect(dropdownOpen()).toBe(false)
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Value").TextColor3).toBe(R.Theme.Colors.mutedForeground)
    sb.SetDisabled(false)
    sb.Frame.MouseButton1Click:Fire()
    h.expect(dropdownOpen()).toBe(true)
  end)
  h.it("multi shows truncated 'A, B +N' with a clear button", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B", "C", "D" },
      Multi = true, Default = { "A", "B", "C", "D" } })
    local field = sb.Frame:FindFirstChild("Field")
    h.expect(field:FindFirstChild("Value").Text).toBe("A, B +2")
    local clear = field:FindFirstChild("Clear")
    h.expect(clear.Visible).toBe(true)
    clear.MouseButton1Click:Fire()
    h.expect(#sb.GetValue()).toBe(0)
    h.expect(field:FindFirstChild("Value").Text).toBe("None")
    h.expect(clear.Visible).toBe(false)
  end)
  h.it("single per-item shows the selected option icon in the field", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}),
      Options = { { Value = "Bow", Icon = "target" }, { Value = "Shield", Icon = "shield" } } })
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("FieldIcon").Visible).toBe(true)
  end)
  h.it("dropdown is a ScrollingFrame with auto canvas so long lists scroll", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local big = {}; for i = 1, 20 do big[i] = "I" .. i end
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = big, Default = "I1" })
    sb.Open()
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local list = dd:FindFirstChild("List")
    h.expect(list.ClassName).toBe("ScrollingFrame")
    h.expect(list.AutomaticCanvasSize).toBe(h.roblox.Enum.AutomaticSize.Y)
  end)
  h.it("Loading shows a spinner + Loading row; SetLoading(false) restores options", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A", Loading = true })
    local field = sb.Frame:FindFirstChild("Field")
    h.expect(field:FindFirstChild("Spinner").Visible).toBe(true)
    h.expect(field:FindFirstChild("Caret").Visible).toBe(false)
    sb.Open()
    local function dd() for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then return c end end end
    h.expect((dd():FindFirstChild("List")):FindFirstChild("Loading") ~= nil).toBeTruthy()
    local opts0 = 0; for _, o in ipairs(listChildren(dd())) do if o.Name == "Opt" then opts0 = opts0 + 1 end end
    h.expect(opts0).toBe(0)
    sb.SetLoading(false)
    h.expect(field:FindFirstChild("Spinner").Visible).toBe(false)
    h.expect(field:FindFirstChild("Caret").Visible).toBe(true)
    local n = 0; for _, o in ipairs(listChildren(dd())) do if o.Name == "Opt" then n = n + 1 end end
    h.expect(n).toBe(2)
  end)
  h.it("OnOpen fires on open and can refresh options", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local calls = 0
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A" },
      OnOpen = function(api) calls = calls + 1; api.SetOptions({ "X", "Y" }) end })
    sb.Open()
    h.expect(calls).toBe(1)
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local n = 0; for _, o in ipairs(listChildren(dd)) do if o.Name == "Opt" then n = n + 1 end end
    h.expect(n).toBe(2)
  end)
  h.it("SetOptions rebuilds an open dropdown", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    sb.Open()
    sb.SetOptions({ "C", "D", "E" })
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local n = 0; for _, o in ipairs(listChildren(dd)) do if o.Name == "Opt" then n = n + 1 end end
    h.expect(n).toBe(3)
  end)
  h.it("option Text shows as label while Value is stored and persisted", function()
    local cfg = Config.new({ FileName = "SBVL", AutoSave = false })
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Text = "Weapon", Flag = "wid", Config = cfg,
      Options = { { Value = "wpn_001", Text = "Bow" }, { Value = "wpn_002", Text = "Shield" } } })
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Value").Text).toBe("Bow")
    h.expect(sb.GetValue()).toBe("wpn_001")
    sb.SetValue("wpn_002")
    h.expect(sb.GetValue()).toBe("wpn_002")
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Value").Text).toBe("Shield")
    h.expect(cfg:Get("wid")).toBe("wpn_002")
  end)
  h.it("falls back to the raw value when no label/option matches", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { { Value = "a", Text = "Alpha" } }, Default = "zzz" })
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Value").Text).toBe("zzz")
  end)
  h.it("normOpt accepts lowercase keys (value/text) from JSON-style data", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}),
      Options = { { value = "a", text = "Alpha" }, { value = "b", text = "Beta" } }, Default = "a" })
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Value").Text).toBe("Alpha")
    h.expect(sb.GetValue()).toBe("a")
  end)
  h.it("LoadOptions loads on the next Heartbeat (deferred, non-blocking) and clears the loading state", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Text = "Weapon",
      LoadOptions = function() return { { Value = "a", Text = "Alpha" }, { Value = "b", Text = "Beta" } } end })
    local function optCount()
      local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
      local n = 0; for _, o in ipairs(listChildren(dd)) do if o.Name == "Opt" then n = n + 1 end end
      return n
    end
    -- deferred to Heartbeat so it never blocks construction: nothing loaded yet
    sb.Open(); h.expect(optCount()).toBe(0); sb.Close()
    h.mock.stepHeartbeat() -- fire the deferred load
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Spinner").Visible).toBe(false)
    sb.Open()
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    h.expect(dd:FindFirstChild("List"):FindFirstChild("Loading")).toBe(nil)
    h.expect(optCount()).toBe(2)
  end)
  h.it("Reload re-runs LoadOptions (deferred) without a manual SetLoading", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local calls, sets = 0, { { { Value = "a", Text = "A" } }, { { Value = "x", Text = "X" }, { Value = "y", Text = "Y" } } }
    local sb = SelectBox.new({ Parent = Create("Frame", {}),
      LoadOptions = function() calls = calls + 1; return sets[calls] end })
    h.expect(calls).toBe(0) -- deferred to Heartbeat, not called yet
    h.mock.stepHeartbeat()
    h.expect(calls).toBe(1)
    sb.Reload()
    h.expect(calls).toBe(1) -- deferred again
    h.mock.stepHeartbeat()
    h.expect(calls).toBe(2)
    sb.Open()
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local n = 0; for _, o in ipairs(listChildren(dd)) do if o.Name == "Opt" then n = n + 1 end end
    h.expect(n).toBe(2) -- second set
  end)
  h.it("LoadOptions errors are swallowed and the loading state still clears", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), LoadOptions = function() error("boom") end })
    h.mock.stepHeartbeat() -- fire the deferred load (which errors)
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Spinner").Visible).toBe(false)
  end)
  h.it("field shows 'Loading…' (not the value) while loading, then the value once done", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}),
      Options = { { Value = "A", Icon = "star" }, { Value = "B" } }, Default = "A", Loading = true })
    local field = sb.Frame:FindFirstChild("Field")
    h.expect(field:FindFirstChild("Value").Text).toBe("Loading…")
    h.expect(field:FindFirstChild("FieldIcon").Visible).toBe(false) -- selected icon hidden while loading
    sb.SetLoading(false)
    h.expect(field:FindFirstChild("Value").Text).toBe("A")
    h.expect(field:FindFirstChild("FieldIcon").Visible).toBe(true)
  end)
  h.it("SetOptions drops values no longer present", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B", "C" }, Default = "A" })
    sb.SetOptions({ "X", "Y", "Z" })
    h.expect(sb.GetValue()).toBe("X")
    local m = SelectBox.new({ Options = { "A", "B", "C" }, Multi = true, Default = { "A", "B" } })
    m.SetOptions({ "B", "D" })
    h.expect(#m.GetValue()).toBe(1)
    h.expect(m.GetValue()[1]).toBe("B")
  end)
  h.it("renders per-item icon/desc and a divider, and AllowNone deselects", function()
    local ov = Overlay.get(h.roblox.Instance.new("ScreenGui"))
    local sb = SelectBox.new({ Parent = Create("Frame", {}),
      Options = { { Value = "A", Icon = "star", Desc = "alpha" }, { Divider = true }, { Value = "B" } },
      Default = "A", AllowNone = true })
    sb.Open()
    local dd; for _, c in ipairs(ov:GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local hasLead, hasDivider, optA = false, false, nil
    for _, c in ipairs(listChildren(dd)) do
      if c.Name == "Opt" and c:FindFirstChild("Lead") then hasLead = true end
      if c.Name == "Divider" then hasDivider = true end
      if c.Name == "Opt" and c:GetAttribute("OptValue") == "A" then optA = c end
    end
    h.expect(hasLead).toBe(true)
    h.expect(hasDivider).toBe(true)
    optA.MouseButton1Click:Fire() -- A is selected + AllowNone => deselect
    h.expect(sb.GetValue()).toBe(nil)
  end)
  -- ---- visual-polish phase 1 (1.2 font roles, 1.4 caret tint, 1.7 field ring, 1.9 spin) ----
  local function dropdownIn(gui)
    for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then return c end end
  end
  h.it("Title/Description/Value carry the label/muted/body font roles", function()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Text = "Mode", Description = "pick one",
      Options = { "A", "B" }, Default = "A" })
    local ti, de = sb.Frame:FindFirstChild("Title"), sb.Frame:FindFirstChild("Description")
    local val = sb.Frame:FindFirstChild("Field"):FindFirstChild("Value")
    h.expect(ti.TextSize).toBe(R.Theme.Font.label.Size)
    h.expect(ti.FontFace.Weight).toBe(R.Theme.Font.label.Weight)
    h.expect(de.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(val.TextSize).toBe(R.Theme.Font.body.Size)
    h.expect(val.FontFace.Weight).toBe(R.Theme.Font.body.Weight)
    h.expect(val.Font).toBe(h.roblox.Enum.Font.BuilderSans)
  end)
  h.it("option rows use the body role for the label and muted for the description", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { { Value = "A", Desc = "alpha" } }, Default = "A" })
    sb.Open()
    local opt; for _, c in ipairs(listChildren(dropdownIn(gui))) do if c.Name == "Opt" then opt = c end end
    h.expect(opt:FindFirstChild("OptLabel").TextSize).toBe(R.Theme.Font.body.Size)
    h.expect(opt:FindFirstChild("Desc").TextSize).toBe(R.Theme.Font.muted.Size)
  end)
  -- The caret now carries two tweens while opening (tint + the 2.11 rotation), so tint assertions
  -- filter by goal instead of counting every tween aimed at the glyph.
  local function tintTweens(img)
    local out = {}
    for _, tw in ipairs(h.mock.tweensFor(img)) do if tw.Goal.ImageColor3 ~= nil then out[#out + 1] = tw end end
    return out
  end
  h.it("caret rests at mutedForeground and lifts to foreground while open (survives a rebuild)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    local caret = sb.Frame:FindFirstChild("Field"):FindFirstChild("Caret")
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
    h.mock.resetTweens()
    sb.Open()
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
    local tws = tintTweens(caret) -- tinted through Icons.tint (a tween), not snapped
    h.expect(#tws).toBe(1)
    h.expect(tws[1].Goal.ImageColor3).toBe(R.Theme.Colors.foreground)
    sb.SetOptions({ "C", "D" }) -- rebuilds the open dropdown without dropping the open state
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
    h.expect(#tintTweens(caret)).toBe(1)
    sb.Close()
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
  end)
  h.it("disabled mutes the caret even while open", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A", Disabled = true })
    local caret = sb.Frame:FindFirstChild("Field"):FindFirstChild("Caret")
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
    sb.SetDisabled(false)
    sb.Open()
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
    sb.SetDisabled(true)
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
    sb.Close()
  end)
  h.it("field stroke becomes the ring at focusThickness while open and returns to the 1px border on Close", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    local stroke = sb.Frame:FindFirstChild("Field"):FindFirstChildOfClass("UIStroke")
    h.expect(stroke.Thickness).toBe(1)
    h.expect(stroke.Color).toBe(R.Theme.Colors.border)
    sb.Open()
    h.expect(stroke.Thickness).toBe(R.Theme.Stroke.focusThickness)
    h.expect(stroke.Color).toBe(R.Theme.Colors.ring)
    sb.SetOptions({ "C" }) -- rebuild keeps the ring
    h.expect(stroke.Thickness).toBe(R.Theme.Stroke.focusThickness)
    sb.Close()
    h.expect(stroke.Thickness).toBe(1)
    h.expect(stroke.Color).toBe(R.Theme.Colors.border)
  end)
  h.it("themer closure re-derives caret and field stroke from the open flag", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local reskin
    -- `reskin or fn` keeps the CONTROL's closure: an open popover registers a second, temporary
    -- one (2.11) and plain assignment would silently swap this test onto it.
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A",
      AccentReg = function(fn) reskin = reskin or fn; return function() end end })
    local field = sb.Frame:FindFirstChild("Field")
    local caret, stroke = field:FindFirstChild("Caret"), field:FindFirstChildOfClass("UIStroke")
    sb.Open()
    reskin()
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
    h.expect(stroke.Color).toBe(R.Theme.Colors.ring)
    sb.Close()
    reskin()
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
    h.expect(stroke.Color).toBe(R.Theme.Colors.border)
  end)
  h.it("dropdown search carries a hairline stroke that becomes the ring on focus", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A", Searchable = true })
    sb.Open()
    local search = dropdownIn(gui):FindFirstChild("Search")
    local stroke, input = search:FindFirstChildOfClass("UIStroke"), search:FindFirstChild("Input")
    h.expect(stroke ~= nil).toBeTruthy()
    h.expect(stroke.Thickness).toBe(1)
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.search.dark)
    h.expect(input.TextSize).toBe(R.Theme.Font.muted.Size)
    input.Focused:Fire()
    h.expect(stroke.Thickness).toBe(R.Theme.Stroke.focusThickness)
    h.expect(stroke.Color).toBe(R.Theme.Colors.ring)
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.control)
    input.FocusLost:Fire()
    h.expect(stroke.Thickness).toBe(1)
    h.expect(stroke.Color).toBe(R.Theme.Colors.border)
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.search.dark)
    sb.Close()
  end)
  h.it("spinner runs an endless Animate.spin loop that SetLoading(false) cancels", function()
    h.mock.resetTweens()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A" }, Default = "A", Loading = true })
    local spinner = sb.Frame:FindFirstChild("Field"):FindFirstChild("Spinner")
    local tw = h.mock.tweensFor(spinner)[1]
    h.expect(tw ~= nil).toBeTruthy()
    h.expect(tw.Info.RepeatCount).toBe(-1)
    h.expect(tw.cancelled).toBe(false)
    sb.SetLoading(false)
    h.expect(tw.cancelled).toBe(true)
    h.expect(spinner.Rotation).toBe(0)
  end)
  h.it("Destroy cancels a running spin loop", function()
    h.mock.resetTweens()
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A" }, Default = "A", Loading = true })
    local tw = h.mock.tweensFor(sb.Frame:FindFirstChild("Field"):FindFirstChild("Spinner"))[1]
    sb.Destroy()
    h.expect(tw.cancelled).toBe(true)
  end)
  h.it("reduced motion: no spin tween, glyph rests at 0, caret and ring snap instantly", function()
    h.withReducedMotion(R, function()
      local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
      h.mock.resetTweens()
      local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A", Loading = true })
      local field = sb.Frame:FindFirstChild("Field")
      local spinner, caret, stroke = field:FindFirstChild("Spinner"), field:FindFirstChild("Caret"), field:FindFirstChildOfClass("UIStroke")
      h.expect(#h.mock.tweensFor(spinner)).toBe(0)
      h.expect(spinner.Rotation).toBe(0)
      sb.SetLoading(false)
      sb.Open()
      h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
      h.expect(stroke.Thickness).toBe(R.Theme.Stroke.focusThickness)
      h.expect(#h.mock.tweensFor(caret)).toBe(0)
      h.expect(#h.mock.tweensFor(stroke)).toBe(0)
      sb.Close()
      h.expect(stroke.Thickness).toBe(1)
    end)
  end)

  -- ---- visual-polish phase 2 (2.11 popover motion/depth, 2.7 row hover, 2.8 dim, 2.22 UI scale) ----
  -- Anchored at (50,100) in a 600x800 viewport: a 2-option list (2*28 + 8 = 64px) fits below, so
  -- the dropdown lands at 100 + 38 + gap(4) = 142.
  local function anchored(gui, extra)
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local o = { Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" }
    for k, v in pairs(extra or {}) do o[k] = v end
    local sb = SelectBox.new(o)
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    return sb, root
  end
  h.it("the dropdown grows out of the field and still lands on the computed position", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    h.mock.resetTweens()
    sb.Open()
    local dd = dropdownIn(gui)
    local us = dd:FindFirstChildOfClass("UIScale")
    h.expect(us ~= nil).toBeTruthy()
    h.expect(us.Scale).toBe(1)               -- pops from Motion.exitScale and rests at 1
    h.expect(dd.Position.Y.Offset).toBe(142) -- the slide ends on the computed spot
    local slid = false
    for _, tw in ipairs(h.mock.tweensFor(dd)) do if tw.Goal.Position ~= nil then slid = true end end
    h.expect(slid).toBe(true)
    sb.Close()
  end)
  h.it("Close drops the dropdown synchronously and destroys the detached frame on the way out", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    sb.Open()
    local dd = dropdownIn(gui)
    sb.Close()
    h.expect(dropdownIn(gui)).toBe(nil) -- gone for the caller before the exit finishes
    h.expect(dd.Parent).toBe(nil)       -- and destroyed in the completion
    sb.Open()
    h.expect(dropdownIn(gui) ~= nil).toBeTruthy() -- reopens cleanly after an animated close
    sb.Close()
  end)
  h.it("the caret turns 0 -> 180 while the list is open and back on Close", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    local caret = sb.Frame:FindFirstChild("Field"):FindFirstChild("Caret")
    h.expect(caret.Rotation or 0).toBe(0)
    h.mock.resetTweens()
    sb.Open()
    h.expect(caret.Rotation).toBe(180)
    local spun; for _, tw in ipairs(h.mock.tweensFor(caret)) do if tw.Goal.Rotation ~= nil then spun = tw end end
    h.expect(spun ~= nil).toBeTruthy() -- rotated through a tween, not snapped
    h.expect(spun.Goal.Rotation).toBe(180)
    sb.Close()
    h.expect(caret.Rotation).toBe(0)
  end)
  h.it("option rows answer hover on transparency only (the row colour stays the surface token)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    sb.Open()
    local dd = dropdownIn(gui)
    local optA, optB
    for _, c in ipairs(listChildren(dd)) do
      if c.Name == "Opt" and c:GetAttribute("OptValue") == "A" then optA = c end
      if c.Name == "Opt" and c:GetAttribute("OptValue") == "B" then optB = c end
    end
    optB.MouseEnter:Fire()
    h.expect(optB.BackgroundTransparency).toBe(R.Theme.Opacity.optionHover)
    h.expect(optB.BackgroundColor3).toBe(R.Theme.Colors.surface) -- identity: no colour tween
    h.expect(optB:FindFirstChild("Hover")).toBe(nil)             -- fill kind: no wash Frame per row
    optB.MouseLeave:Fire()
    h.expect(optB.BackgroundTransparency).toBe(1)
    optA.MouseEnter:Fire(); optA.MouseLeave:Fire()
    h.expect(optA.BackgroundTransparency).toBe(0) -- the selected row rests lit, not cleared
    sb.Close()
  end)
  h.it("a multi pick re-binds the row hover so the row rests at its NEW selection", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Multi = true, Default = { "A" } })
    sb.Open()
    local optB; for _, c in ipairs(listChildren(dropdownIn(gui))) do
      if c.Name == "Opt" and c:GetAttribute("OptValue") == "B" then optB = c end
    end
    optB.MouseButton1Click:Fire() -- selected in place (no rebuild)
    h.expect(optB.BackgroundTransparency).toBe(0)
    optB.MouseEnter:Fire(); optB.MouseLeave:Fire()
    h.expect(optB.BackgroundTransparency).toBe(0)
    optB.MouseButton1Click:Fire() -- deselected again
    optB.MouseEnter:Fire(); optB.MouseLeave:Fire()
    h.expect(optB.BackgroundTransparency).toBe(1)
    sb.Close()
  end)
  h.it("the popover is frosted: the acrylic layers ride on the single floating hairline", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    sb.Open()
    local dd = dropdownIn(gui)
    h.expect(dd:FindFirstChild("AcrylicNoise") ~= nil).toBeTruthy()
    h.expect(dd:FindFirstChild("AcrylicSheen") ~= nil).toBeTruthy()
    h.expect(dd:FindFirstChild("AcrylicGlint") ~= nil).toBeTruthy() -- edge = true
    local strokes = 0
    for _, c in ipairs(dd:GetChildren()) do if c.ClassName == "UIStroke" then strokes = strokes + 1 end end
    h.expect(strokes).toBe(1) -- decorate adopts the hairline instead of adding a second one
    local stroke = dd:FindFirstChildOfClass("UIStroke")
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.floating)
    h.expect(stroke:FindFirstChildOfClass("UIGradient") ~= nil).toBeTruthy() -- rim on the stroke
    h.expect(dd.BackgroundColor3).toBe(R.Theme.Colors.card)
    h.expect(dd.BackgroundTransparency > 0).toBeTruthy()
    h.expect(dd.BackgroundTransparency < R.Theme.Acrylic.frost).toBeTruthy() -- lighter than the shell
    sb.Close()
  end)
  h.it("a theme that names Acrylic.popoverFrost owns the popover transparency", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Theme = R.Theme.new({ Acrylic = { popoverFrost = 0.2 } }) })
    sb.Open()
    h.expect(dropdownIn(gui).BackgroundTransparency).toBe(0.2)
    sb.Close()
  end)
  h.it("the open dropdown gets a popover shadow sibling that dies with it", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb, root = anchored(gui, { Theme = R.Theme.new({ Effect = { shadowId = "rbxassetid://1" } }) })
    sb.Open()
    local sh; for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdownShadow" then sh = c end end
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.ZIndex).toBe(R.Overlay.Z.catcher) -- sibling UNDER the popover, never a child
    h.expect(sh.Parent).toBe(root)
    local dd, spread = dropdownIn(gui), R.Theme.Effect.popover.spread
    h.expect(sh.Size.X.Offset).toBe(dd.Size.X.Offset + 2 * spread)
    h.expect(sh.Size.Y.Offset).toBe(dd.Size.Y.Offset + 2 * spread)
    h.expect(sh.Position.Y.Offset).toBe(142 + dd.Size.Y.Offset / 2 + R.Theme.Effect.popover.offsetY)
    sb.Close()
    h.expect(sh.Parent).toBe(nil)
  end)
  h.it("no shadow layer while Effect.shadowId is '' (today's default)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb, root = anchored(gui)
    sb.Open()
    local found = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdownShadow" then found = true end end
    h.expect(found).toBe(false) -- Effects.shadow returns nil: every call site stays nil-tolerant
    sb.Close()
    h.expect(dropdownIn(gui)).toBe(nil)
  end)
  -- 2.11: the OPEN popover registers a themer closure of its own, so a SetMode/SetAccent that
  -- lands while it is up repaints it. Collects EVERY registration (the control's plus the
  -- popover's temporary one) and replays them the way the window's themer does.
  local function regCollector()
    local c = { fns = {}, released = 0 }
    function c.AccentReg(fn)
      c.fns[#c.fns + 1] = fn
      return function()
        c.released = c.released + 1
        for i, f in ipairs(c.fns) do if f == fn then table.remove(c.fns, i); break end end
      end
    end
    function c.reskin(reason)
      local snapshot = {}
      for i, f in ipairs(c.fns) do snapshot[i] = f end
      for _, f in ipairs(snapshot) do f(reason) end
    end
    return c
  end
  h.it("SetMode re-skins an OPEN dropdown: frost, hairline, search, dividers and rows (2.11)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reg = regCollector()
    local t = R.Theme.new({})
    local sb = anchored(gui, { Theme = t, AccentReg = reg.AccentReg, Searchable = true,
      Options = { "A", { Divider = true }, { Value = "B", Text = "Bee", Desc = "second", Icon = "check" } } })
    h.expect(#reg.fns).toBe(1)                                 -- the control's own closure
    sb.Open()
    h.expect(#reg.fns).toBe(2)                                 -- ...plus the popover's, while open
    local dd = dropdownIn(gui)
    local list = dd:FindFirstChild("List")
    local search = dd:FindFirstChild("Search")
    local divider, row, labelled
    for _, c in ipairs(list:GetChildren()) do
      if c.Name == "Divider" then divider = c
      elseif c.Name == "Opt" then row = row or c; if c:FindFirstChild("Desc") then labelled = c end end
    end
    h.expect(dd.BackgroundColor3).toBe(t.Colors.card)          -- born in the theme's palette...
    R.Theme.applyMode(t, "light")                              -- applyMode writes the palette's
    reg.reskin("mode")                                         -- own tables in, so identity holds
    local light = R.Theme.PALETTES.light
    h.expect(dd.BackgroundColor3).toBe(light.card)             -- ...repainted live
    h.expect(dd:FindFirstChildOfClass("UIStroke").Color).toBe(light.border)
    h.expect(dd.BackgroundTransparency).toBe(t.Acrylic.popoverFrost)
    h.expect(list.ScrollBarImageColor3).toBe(light.border)
    h.expect(search.BackgroundColor3).toBe(light.surface)
    h.expect(search:FindFirstChild("Input").TextColor3).toBe(light.foreground)
    h.expect(search:FindFirstChild("Input").PlaceholderColor3).toBe(light.mutedForeground)
    h.expect(search:FindFirstChildOfClass("UIStroke").Color).toBe(light.border)
    h.expect(divider.BackgroundColor3).toBe(light.border)
    h.expect(row.BackgroundColor3).toBe(light.surface)
    h.expect(labelled:FindFirstChild("OptLabel").TextColor3).toBe(light.foreground)
    h.expect(labelled:FindFirstChild("Desc").TextColor3).toBe(light.mutedForeground)
    sb.Close()
    h.expect(reg.released).toBe(1)                             -- released the moment it folds
    h.expect(#reg.fns).toBe(1)
    reg.reskin("mode")                                         -- and never paints the dead frame
  end)
  h.it("SetMode re-applies the open dropdown shadow's per-mode alpha when an asset is set (2.11)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reg = regCollector()
    local t = R.Theme.new({ Effect = { shadowId = "rbxassetid://1" } })
    local sb, root = anchored(gui, { Theme = t, AccentReg = reg.AccentReg })
    sb.Open()
    local sh; for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdownShadow" then sh = c end end
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.ImageTransparency).toBe(R.Theme.MODE_EFFECTS.dark.shadow)
    R.Theme.applyMode(t, "light")
    reg.reskin("mode")
    h.expect(sh.ImageTransparency).toBe(R.Theme.MODE_EFFECTS.light.shadow)
    sb.Close()
  end)
  h.it("the dropdown carries the overlay UI scale and flips on its SCALED height", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 460)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B", "C" }, Default = "A" })
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 300)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sb.Open()
    h.expect(dropdownIn(gui).Position.Y.Offset).toBe(342) -- 3*28 + 8 = 92 still fits below
    h.expect(dropdownIn(gui):FindFirstChildOfClass("UIScale").Scale).toBe(1)
    sb.Close()
    R.Overlay.setScale(1.3)
    sb.Open()
    local dd = dropdownIn(gui)
    h.expect(dd:FindFirstChildOfClass("UIScale").Scale).toBe(1.3)
    h.expect(dd.Position.Y.Offset < 300).toBeTruthy()         -- 92*1.3 overflows: opens upward
    h.expect(root:FindFirstChildOfClass("UIScale")).toBe(nil) -- never on the overlay root
    sb.Close()
    R.Overlay.setScale(1)
  end)
  h.it("disabled dims the field and the value, blocks Open, and survives a re-skin", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reskin
    local sb = anchored(gui, { AccentReg = function(fn) reskin = reskin or fn; return function() end end })
    local field = sb.Frame:FindFirstChild("Field")
    local val = field:FindFirstChild("Value")
    h.expect(field.BackgroundTransparency).toBe(0)
    sb.SetDisabled(true)
    h.expect(field.BackgroundTransparency).toBe(R.Theme.Opacity.disabled)
    h.expect(val.TextTransparency).toBe(R.Theme.Opacity.disabled)
    sb.Open()
    h.expect(dropdownIn(gui)).toBe(nil) -- api.Open is guarded, not just the click handler
    reskin()
    h.expect(field.BackgroundTransparency).toBe(R.Theme.Opacity.disabled)
    sb.SetDisabled(false)
    h.expect(field.BackgroundTransparency).toBe(0)
    h.expect(val.TextTransparency).toBe(0)
    sb.Open()
    h.expect(dropdownIn(gui) ~= nil).toBeTruthy()
    sb.Close()
  end)
  h.it("reduced motion: the popover snaps in and out and the caret turns instantly", function()
    h.withReducedMotion(R, function()
      local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
      local sb = anchored(gui)
      local caret = sb.Frame:FindFirstChild("Field"):FindFirstChild("Caret")
      h.mock.resetTweens()
      sb.Open()
      local dd = dropdownIn(gui)
      h.expect(dd.Position.Y.Offset).toBe(142)
      h.expect(dd:FindFirstChildOfClass("UIScale").Scale).toBe(1)
      h.expect(caret.Rotation).toBe(180)
      h.expect(h.mock.tweenCount()).toBe(0)
      sb.Close()
      h.expect(dropdownIn(gui)).toBe(nil)
      h.expect(dd.Parent).toBe(nil)
      h.expect(caret.Rotation).toBe(0)
    end)
  end)
end)

h.run()
