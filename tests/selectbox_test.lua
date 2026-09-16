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
  h.it("caret rests at mutedForeground and lifts to foreground while open (survives a rebuild)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    local caret = sb.Frame:FindFirstChild("Field"):FindFirstChild("Caret")
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
    h.mock.resetTweens()
    sb.Open()
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
    local tws = h.mock.tweensFor(caret) -- tinted through Icons.tint (a tween), not snapped
    h.expect(#tws).toBe(1)
    h.expect(tws[1].Goal.ImageColor3).toBe(R.Theme.Colors.foreground)
    sb.SetOptions({ "C", "D" }) -- rebuilds the open dropdown without dropping the open state
    h.expect(caret.ImageColor3).toBe(R.Theme.Colors.foreground)
    h.expect(#h.mock.tweensFor(caret)).toBe(1)
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
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A",
      AccentReg = function(fn) reskin = fn; return function() end end })
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
end)

h.run()
