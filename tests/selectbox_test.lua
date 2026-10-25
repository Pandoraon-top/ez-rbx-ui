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
  h.it("a small move of the control (a status line above it grew) carries the dropdown along", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sb.Open()
    local function dd() for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then return c end end end
    local pop = dd()
    local y0 = pop.Position.Y.Offset
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 118)          -- 18 px down: one more text line
    sb.Frame:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    h.expect(dd()).toBe(pop)                                            -- still open
    h.expect(pop.Position.Y.Offset).toBe(y0 + 18)                       -- and moved with the control
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 140)          -- 40 px from where it opened
    sb.Frame:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    h.expect(dd()).toBeNil()
  end)
  h.it("a dropdown that follows its control stays inside the screen", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 400)
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = { "A", "B" }, Default = "A" })
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(390, 100)          -- near the right edge
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sb.Open()
    local dd; for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local right0 = dd.Position.X.Offset + dd.Size.X.Offset
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(410, 100)          -- 20 px further right
    sb.Frame:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    h.expect(dd.Position.X.Offset + dd.Size.X.Offset <= math.max(right0, 600)).toBeTruthy()
    sb.Close()
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
  h.it("dropdown is a ScrollingFrame whose canvas holds the whole list so long lists scroll", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local big = {}; for i = 1, 20 do big[i] = "I" .. i end
    local sb = SelectBox.new({ Parent = Create("Frame", {}), Options = big, Default = "I1" })
    sb.Open()
    local dd; for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "SelectDropdown" then dd = c end end
    local list = dd:FindFirstChild("List")
    h.expect(list.ClassName).toBe("ScrollingFrame")
    h.expect(list.CanvasSize.Y.Offset).toBe(20 * 26 + 19 * 2)   -- every row, 2 px apart
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
  h.it("no shadow layer when no shadow asset is configured", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    -- explicit: the default theme now carries an uploaded sprite, so shadows are ON by default
    local sb, root = anchored(gui, { Theme = R.Theme.new({ Effect = { shadowId = "" } }) })
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

  -- ---- visual-polish phase 3 (3.1 loading skeleton, 3.4 empty state, 3.7 scrollbar pill) ----
  local function loadingBody(gui) return dropdownIn(gui):FindFirstChild("List"):FindFirstChild("Loading") end
  local function sweeps(body)
    local out = {}
    for _, c in ipairs(body:GetChildren()) do
      local g = c:FindFirstChildOfClass("UIGradient")
      if g then out[#out + 1] = h.mock.tweensFor(g)[1] end
    end
    return out
  end
  h.it("the loading body is three shimmer skeleton lines of uneven width, not a text row (3.1)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Loading = true })
    h.mock.resetTweens()
    sb.Open()
    local body = loadingBody(gui)
    h.expect(body ~= nil).toBeTruthy()   -- the name every caller probes the loading state by
    h.expect(body.ClassName).toBe("Frame")
    local line = {}
    for _, c in ipairs(body:GetChildren()) do if c.ClassName == "Frame" then line[c.Name] = c end end
    h.expect(line.Line1.Size.X.Scale).toBe(0.6)
    h.expect(line.Line2.Size.X.Scale).toBe(0.8)
    h.expect(line.Line3.Size.X.Scale).toBe(0.45) -- ragged on purpose: text arriving, not a progress bar
    h.expect(line.Line1.Position.Y.Offset).toBe(0)
    h.expect(line.Line3.Position.Y.Offset > line.Line2.Position.Y.Offset).toBeTruthy()
    h.expect(line.Line1.BackgroundColor3).toBe(R.Theme.Colors.surface)
    h.expect(line.Line1.ZIndex > body.ZIndex).toBeTruthy()
    local tws = sweeps(body)
    h.expect(#tws).toBe(3)                       -- one endless sweep per line, no more
    h.expect(tws[1].Info.RepeatCount).toBe(-1)
    -- the popover is sized for what it shows: three lines + gaps, not one 28px text row
    h.expect(dropdownIn(gui).Size.Y.Offset > 28 + 8).toBeTruthy()
    sb.Close()
  end)
  h.it("options landing stop every shimmer loop and drop the skeleton body (3.1)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Loading = true })
    sb.Open()
    local body = loadingBody(gui)
    local tws = sweeps(body)
    h.expect(#tws).toBe(3)
    sb.SetLoading(false)                         -- the open dropdown rebuilds around the real options
    for _, tw in ipairs(tws) do h.expect(tw.cancelled).toBe(true) end
    h.expect(body.Parent).toBeNil()              -- nothing survives the rebuild
    local dd = dropdownIn(gui)
    h.expect(dd:FindFirstChild("List"):FindFirstChild("Loading")).toBe(nil)
    local n = 0; for _, o in ipairs(listChildren(dd)) do if o.Name == "Opt" then n = n + 1 end end
    h.expect(n).toBe(2)
    sb.Close()
  end)
  h.it("Close cancels the shimmer loops and takes the skeleton with it (3.1)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Loading = true })
    sb.Open()
    local body = loadingBody(gui)
    local line, tws = body:FindFirstChild("Line1"), sweeps(body)
    sb.Close()
    h.expect(dropdownIn(gui)).toBe(nil)          -- teardown stays synchronous for the caller
    for _, tw in ipairs(tws) do h.expect(tw.cancelled).toBe(true) end
    h.expect(line.Parent).toBeNil()
    h.expect(body.Parent).toBeNil()
  end)
  h.it("Destroy while loading and open leaves no shimmer loop running (3.1)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Loading = true })
    sb.Open()
    local tws = sweeps(loadingBody(gui))
    sb.Destroy()
    for _, tw in ipairs(tws) do h.expect(tw.cancelled).toBe(true) end
  end)
  h.it("reduced motion: the skeleton is a static block and Stop destroys it without a fade (3.1)", function()
    h.withReducedMotion(R, function()
      local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
      local sb = anchored(gui, { Loading = true })
      h.mock.resetTweens()
      sb.Open()
      local body = loadingBody(gui)
      h.expect(body ~= nil).toBeTruthy()
      local line = body:FindFirstChild("Line1")
      h.expect(line.BackgroundColor3).toBe(R.Theme.Colors.surface)
      h.expect(h.mock.tweenCount()).toBe(0)      -- no sweep and no pop
      sb.Close()
      h.expect(h.mock.tweenCount()).toBe(0)      -- and no fade on the way out
      h.expect(line.Parent).toBeNil()
    end)
  end)
  h.it("a search that filters every option away shows the muted 'no results' block (3.4)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Options = { "Alpha", "Beta" }, Default = "Alpha", Searchable = true })
    sb.Open()
    local dd = dropdownIn(gui)
    local list, empty = dd:FindFirstChild("List"), dd:FindFirstChild("Empty")
    h.expect(empty ~= nil).toBeTruthy()
    h.expect(empty.Parent).toBe(dd)                    -- on the popover ROOT...
    h.expect(list:FindFirstChild("Empty")).toBe(nil)   -- ...never inside the laid-out List
    h.expect(empty.ZIndex > list.ZIndex).toBeTruthy()
    -- ...and over the LIST rect, never across the pinned search band above it: Recipes.empty is
    -- born (1,0,1,0), so a centred icon/label stack would otherwise land on the search field.
    h.expect(empty.Position.Y.Offset).toBe(list.Position.Y.Offset)
    h.expect(empty.Size.Y.Offset).toBe(list.Size.Y.Offset)
    h.expect(empty.Visible).toBe(false)                -- hidden while anything matches
    sb.Filter("zzz")
    h.expect(empty.Visible).toBe(true)
    h.expect(empty:FindFirstChild("Text").Text).toBe("No results")
    h.expect(empty:FindFirstChild("Text").TextColor3).toBe(R.Theme.Colors.mutedForeground)
    sb.Filter("al")                                    -- a row matches again
    h.expect(empty.Visible).toBe(false)
    sb.Filter("")
    h.expect(empty.Visible).toBe(false)
    sb.Close()
    h.expect(dd.Parent).toBeNil()                      -- leaves the tree with the (parked) popover
    h.expect(empty.Parent).toBe(dd)                    -- ...riding along for the next Open
  end)
  h.it("the search box drives the empty block through the live filter (3.4)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Options = { "Alpha", "Beta" }, Default = "Alpha", Searchable = true })
    sb.Open()
    local dd = dropdownIn(gui)
    local input = dd:FindFirstChild("Search"):FindFirstChild("Input")
    input.Text = "qqq"
    input:GetPropertyChangedSignal("Text"):Fire()
    h.expect(dd:FindFirstChild("Empty").Visible).toBe(true)
    sb.Close()
  end)
  h.it("the empty-state glyph actually resolves in the atlas (3.4)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    sb.Open()
    local icon = dropdownIn(gui):FindFirstChild("Empty"):FindFirstChild("Icon")
    h.expect(icon ~= nil).toBeTruthy()
    h.expect(R.Icons.get("search") ~= nil).toBeTruthy() -- 'search-x' is NOT in core/icons.lua
    h.expect(icon.Image).toBe(R.Icons.get("search").Id) -- so the block never ships a nil glyph
    h.expect(icon.ImageColor3).toBe(R.Theme.Colors.mutedForeground)
    sb.Close()
  end)
  h.it("no empty block while the dropdown is loading; it appears once the options land (3.4)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Loading = true })
    sb.Open()
    h.expect(dropdownIn(gui):FindFirstChild("Empty")).toBe(nil) -- the skeleton already speaks
    sb.SetLoading(false)
    local dd = dropdownIn(gui)
    h.expect(dd:FindFirstChild("Empty") ~= nil).toBeTruthy()
    h.expect(dd:FindFirstChild("Empty").Visible).toBe(false)    -- two options match
    sb.Close()
  end)
  h.it("a dropdown built with no options at all says so straight away (3.4)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui, { Options = {} })
    sb.Open()
    local dd = dropdownIn(gui)
    h.expect(dd:FindFirstChild("Empty").Visible).toBe(true)
    -- Visible alone is vacuous under the mock, which does not clip: with zero rows the popover
    -- would be 8px tall and ClipsDescendants would cut the whole block away in Studio. It must be
    -- sized for the block it shows -- icon + gap + one muted line, the 3.1 rule applied to 3.4.
    local T = R.Theme
    h.expect(dd.Size.Y.Offset >= T.Sizes.icon + T.Spacing.gap * 2 + T.Font.muted.Size).toBeTruthy()
    sb.Close()
  end)
  h.it("the dropdown list wears the shared scrollbar pill (3.7)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local sb = anchored(gui)
    sb.Open()
    local list = dropdownIn(gui):FindFirstChild("List")
    h.expect(list.ScrollBarThickness).toBe(R.Theme.Sizes.scrollbar)
    h.expect(list.ScrollBarImageColor3).toBe(R.Theme.Colors.border)
    h.expect(list.ScrollBarImageTransparency).toBe(R.Theme.Scrollbar.alpha)
    sb.Close()
  end)
  h.it("SetMode repaints the skeleton blocks and the scrollbar of an OPEN dropdown (3.1/3.7)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reg = regCollector()
    local t = R.Theme.new({})
    local sb = anchored(gui, { Theme = t, AccentReg = reg.AccentReg, Loading = true })
    sb.Open()
    local dd = dropdownIn(gui)
    local list = dd:FindFirstChild("List")
    local line = list:FindFirstChild("Loading"):FindFirstChild("Line1")
    h.expect(line.BackgroundColor3).toBe(t.Colors.surface)
    R.Theme.applyMode(t, "light")
    reg.reskin("mode")
    local light = R.Theme.PALETTES.light
    h.expect(line.BackgroundColor3).toBe(light.surface)
    h.expect(list.ScrollBarImageColor3).toBe(light.border)
    h.expect(list.ScrollBarImageTransparency).toBe(t.Scrollbar.alpha)
    sb.Close()
  end)
  h.it("SetMode repaints the empty block of an OPEN dropdown (3.4)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reg = regCollector()
    local t = R.Theme.new({})
    local sb = anchored(gui, { Theme = t, AccentReg = reg.AccentReg, Searchable = true })
    sb.Open()
    local empty = dropdownIn(gui):FindFirstChild("Empty")
    sb.Filter("zzz")
    h.expect(empty.Visible).toBe(true)
    R.Theme.applyMode(t, "light")
    reg.reskin("mode")
    local light = R.Theme.PALETTES.light
    h.expect(empty:FindFirstChild("Text").TextColor3).toBe(light.mutedForeground)
    h.expect(empty:FindFirstChild("Icon").ImageColor3).toBe(light.mutedForeground)
    h.expect(empty.Visible).toBe(true)   -- a re-skin replays state, it does not reset the filter
    sb.Close()
  end)
end)

-- SetOptions on an OPEN dropdown used to tear the popover down and build it again: every row, the
-- scroll position and the search query went with it (a hub refreshing a 300-pet list every 2.5 s
-- paid a whole Open each time, and the list jumped to the top under the player's finger).
h.describe("selectbox: SetOptions on an open dropdown updates the rows in place", function()
  local function setup(extra)
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local o = { Parent = Create("Frame", {}) }
    for k, v in pairs(extra or {}) do o[k] = v end
    local sb = SelectBox.new(o)
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    local function dd() for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then return c end end end
    return sb, dd
  end
  -- The list is virtual: an option that is not shown has no visible row (its slot is hidden or
  -- shows another option), so only VISIBLE rows count.
  local function rows(dd)
    local out = {}
    for _, o in ipairs(dd:FindFirstChild("List"):GetChildren()) do
      if o.Name == "Opt" and o.Visible ~= false then out[#out + 1] = o end
    end
    table.sort(out, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    return out
  end
  local function rowFor(dd, v)
    for _, o in ipairs(rows(dd)) do if o:GetAttribute("OptValue") == v then return o end end
  end
  local function shown(dd, v) return rowFor(dd, v) ~= nil end
  local function pets(n, tag)
    local t = {}
    for i = 1, n do t[i] = { Value = "pet" .. i, Text = "Cat " .. i .. " | " .. tag } end
    return t
  end

  h.it("keeps the popover, its scroll position and the search query, and filters again", function()
    local sb, dd = setup({ Options = pets(40, "1.0 KG"), Multi = true, Searchable = true, AllowNone = true })
    sb.Open()
    local pop, list = dd(), dd():FindFirstChild("List")
    list.CanvasPosition = h.roblox.Vector2.new(0, 300)
    list:GetPropertyChangedSignal("CanvasPosition"):Fire()
    sb.SetOptions(pets(40, "1.1 KG"))
    h.expect(dd()).toBe(pop)                                    -- not rebuilt
    h.expect(pop:FindFirstChild("List")).toBe(list)
    h.expect(list.CanvasPosition.Y).toBe(300)                   -- scroll kept
    local input = pop:FindFirstChild("Search"):FindFirstChild("Input")
    input.Text = "cat 2"
    input:GetPropertyChangedSignal("Text"):Fire()
    sb.SetOptions(pets(40, "1.2 KG"))
    h.expect(input.Text).toBe("cat 2")
    h.expect(shown(pop, "pet2")).toBe(true)                     -- "Cat 2 | 1.2 KG" still matches
    h.expect(shown(pop, "pet21")).toBe(true)
    h.expect(shown(pop, "pet3")).toBe(false)                    -- the filter still holds
    sb.Close()
  end)

  h.it("the list follows the new options: order, labels, new values and gone values", function()
    local sb, dd = setup({ Options = { { Value = "a", Text = "A1" }, { Value = "b", Text = "B1" }, { Value = "c", Text = "C1" } } })
    sb.Open()
    local pop = dd()
    local before = rows(pop)
    sb.SetOptions({ { Value = "c", Text = "C2" }, { Value = "d", Text = "D2" }, { Value = "a", Text = "A2" } })
    local now = rows(pop)
    h.expect(#now).toBe(3)
    h.expect(now[1]:GetAttribute("OptValue")).toBe("c")         -- order follows the new list
    h.expect(now[2]:GetAttribute("OptValue")).toBe("d")
    h.expect(now[3]:GetAttribute("OptValue")).toBe("a")
    h.expect(now[1]:FindFirstChild("OptLabel").Text).toBe("C2")
    h.expect(now[3]:FindFirstChild("OptLabel").Text).toBe("A2")
    h.expect(shown(pop, "b")).toBe(false)                       -- "b" is gone
    for i = 1, 3 do h.expect(now[i]).toBe(before[i]) end        -- the same three rows, re-bound in place
    sb.Close()
  end)

  h.it("a reused row picks up a new description and icon", function()
    local sb, dd = setup({ Options = { { Value = "a", Text = "A" }, { Value = "b", Text = "B", Desc = "old" } } })
    sb.Open()
    local pop = dd()
    sb.SetOptions({ { Value = "a", Text = "A", Desc = "now" }, { Value = "b", Text = "B", Desc = "new", Icon = "home" } })
    local ra, rb = rowFor(pop, "a"), rowFor(pop, "b")
    h.expect(ra:FindFirstChild("Desc").Text).toBe("now")
    h.expect(ra.Size.Y.Offset).toBe(38)                         -- a description makes the row taller
    h.expect(rb:FindFirstChild("Desc").Text).toBe("new")
    h.expect(rb:FindFirstChild("Lead") ~= nil).toBeTruthy()
    h.expect(rb:FindFirstChild("OptLabel").Position.X.Offset).toBe(40) -- text moves past the icon
    sb.Close()
  end)

  h.it("selection follows the new list: a picked value that disappears loses its check", function()
    local sb, dd = setup({ Options = { "A", "B", "C" }, Multi = true, Default = { "A", "B" } })
    sb.Open()
    local pop = dd()
    sb.SetOptions({ "A", "C", "D" })
    h.expect(#sb.GetValue()).toBe(1)
    h.expect(rowFor(pop, "A"):FindFirstChild("Check").Visible).toBe(true)
    h.expect(rowFor(pop, "C"):FindFirstChild("Check").Visible).toBe(false)
    h.expect(rowFor(pop, "D"):FindFirstChild("Check").Visible).toBe(false)
    sb.Close()
  end)

  h.it("SetValue on an open dropdown re-ticks the rows", function()
    local sb, dd = setup({ Options = { "A", "B", "C" }, Multi = true, Default = { "A" } })
    sb.Open()
    local pop = dd()
    sb.SetValue({ "B", "C" })
    h.expect(rowFor(pop, "A"):FindFirstChild("Check").Visible).toBe(false)
    h.expect(rowFor(pop, "A").BackgroundTransparency).toBe(1)
    h.expect(rowFor(pop, "B"):FindFirstChild("Check").Visible).toBe(true)
    h.expect(rowFor(pop, "B").BackgroundTransparency).toBe(0)
    h.expect(dd()).toBe(pop)
    sb.Close()
  end)

  h.it("costs a small fraction of an Open", function()
    local sb = setup({ Options = pets(300, "1.0 KG"), Multi = true, Searchable = true, AllowNone = true,
      Default = { "pet1", "pet5", "pet9" } })
    h.mock.writes = 0
    sb.Open()
    local openCost = h.mock.writes
    h.mock.writes = 0
    sb.SetOptions(pets(300, "1.1 KG"))   -- every label changes, as a growing pet's KG does
    local syncCost = h.mock.writes
    h.mock.writes = 0
    sb.SetOptions(pets(300, "1.1 KG"))   -- nothing changes
    local idleCost = h.mock.writes
    h.expect(syncCost * 10 < openCost).toBeTruthy()
    h.expect(idleCost < 20).toBeTruthy()
    sb.Close()
  end)

  h.it("rows that arrive go through the active filter and the empty block follows", function()
    local sb, dd = setup({ Options = { "Alpha", "Beta" }, Searchable = true })
    sb.Open()
    local pop = dd()
    sb.Filter("zzz")
    local empty = pop:FindFirstChild("Empty")
    h.expect(empty.Visible).toBe(true)
    sb.SetOptions({ "Alpha", "Beta", "zzz top" })
    h.expect(shown(pop, "zzz top")).toBe(true)
    h.expect(shown(pop, "Alpha")).toBe(false)
    h.expect(empty.Visible).toBe(false)
    sb.SetOptions({ "Alpha" })
    h.expect(empty.Visible).toBe(true)
    sb.Close()
  end)

  h.it("dividers follow the new list", function()
    local sb, dd = setup({ Options = { "A", { Divider = true }, "B" } })
    sb.Open()
    local pop = dd()
    sb.SetOptions({ "A", { Divider = true }, "B", { Divider = true }, "C" })
    local divs = {}
    for _, c in ipairs(pop:FindFirstChild("List"):GetChildren()) do
      if c.Name == "Divider" then divs[#divs + 1] = c.LayoutOrder end
    end
    table.sort(divs)
    h.expect(#divs).toBe(2)
    h.expect(divs[1]).toBe(2)
    h.expect(divs[2]).toBe(4)
    h.expect(rowFor(pop, "C").LayoutOrder).toBe(5)
    sb.Close()
  end)

  h.it("two options with the same Value keep two rows", function()
    local sb, dd = setup({ Options = { "A", "B" } })
    sb.Open()
    sb.SetOptions({ "A", "A", "B" })
    h.expect(#rows(dd())).toBe(3)
    sb.SetOptions({ "A", "B" })
    h.expect(#rows(dd())).toBe(2)
    sb.Close()
  end)

  h.it("a list that outgrows its popover grows it in place and keeps the search query", function()
    local sb, dd = setup({ Options = { "A", "B" }, Searchable = true })
    sb.Open()
    local pop = dd()
    local before = pop.Size.Y.Offset
    local input = pop:FindFirstChild("Search"):FindFirstChild("Input")
    input.Text = "b"
    input:GetPropertyChangedSignal("Text"):Fire()
    local opts = {}
    for i = 1, 12 do opts[i] = (i % 2 == 0) and ("b" .. i) or ("a" .. i) end
    sb.SetOptions(opts)
    h.expect(dd()).toBe(pop)
    h.expect(pop.Size.Y.Offset > before).toBeTruthy()
    h.expect(#rows(pop)).toBe(6)                                -- the six "b" rows match the query
    h.expect(input.Text).toBe("b")
    h.expect(shown(pop, "a1")).toBe(false)
    h.expect(shown(pop, "b2")).toBe(true)
    sb.Close()
  end)

  h.it("a short list that crosses the search threshold gets its search box", function()
    local sb, dd = setup({ Options = { "A", "B", "C" } })
    sb.Open()
    h.expect(dd():FindFirstChild("Search")).toBeNil()
    sb.SetOptions({ "A", "B", "C", "D", "E", "F", "G", "H" })
    h.expect(dd():FindFirstChild("Search") ~= nil).toBeTruthy()
    h.expect(#rows(dd())).toBe(8)
    sb.Close()
  end)

  h.it("a click on a reused row still picks its value", function()
    local sb, dd = setup({ Options = { "A", "B" }, Default = "A" })
    sb.Open()
    sb.SetOptions({ "B", "A" })
    rowFor(dd(), "B").MouseButton1Click:Fire()
    h.expect(sb.GetValue()).toBe("B")
  end)

  local function collector()
    local c = { fns = {} }
    function c.AccentReg(fn)
      c.fns[#c.fns + 1] = fn
      return function() for i, f in ipairs(c.fns) do if f == fn then table.remove(c.fns, i); break end end end
    end
    function c.reskin() local snap = {}; for i, f in ipairs(c.fns) do snap[i] = f end; for _, f in ipairs(snap) do f("mode") end end
    return c
  end

  h.it("a valueless option (an 'Any' row) is ticked while nothing is picked, and a re-skin agrees", function()
    local reg = collector()
    local sb, dd = setup({ AllowNone = true, AccentReg = reg.AccentReg,
      Options = { { Text = "Any" }, { Value = "a", Text = "A" } } })
    sb.SetValue(nil)
    sb.Open()
    local pop = dd()
    local any
    for _, o in ipairs(rows(pop)) do if o:FindFirstChild("OptLabel").Text == "Any" then any = o end end
    h.expect(any:FindFirstChild("Check").Visible).toBe(true)
    h.expect(any.BackgroundTransparency).toBe(0)
    reg.reskin()
    h.expect(any:FindFirstChild("Check").Visible).toBe(true)
    sb.SetValue("a")
    h.expect(any:FindFirstChild("Check").Visible).toBe(false)
    reg.reskin()
    h.expect(any:FindFirstChild("Check").Visible).toBe(false)
    sb.SetOptions({ { Text = "Any" }, { Value = "a", Text = "A" }, { Value = "b", Text = "B" } })
    h.expect(any.Parent ~= nil).toBeTruthy()             -- the valueless row is kept, not rebuilt
    sb.Close()
  end)

  h.it("a re-skin after a sync repaints the rows and dividers that the sync added", function()
    local reg = collector()
    local t = R.Theme.new({})
    local sb, dd = setup({ Theme = t, AccentReg = reg.AccentReg, Options = { "A", "B" } })
    sb.Open()
    local pop = dd()
    sb.SetOptions({ "A", { Divider = true }, "B", "C" })
    R.Theme.applyMode(t, "light")
    reg.reskin()
    local light = R.Theme.PALETTES.light
    for _, c in ipairs(pop:FindFirstChild("List"):GetChildren()) do
      if c.Name == "Divider" then h.expect(c.BackgroundColor3).toBe(light.border) end
      if c.Name == "Opt" then h.expect(c:FindFirstChild("OptLabel").TextColor3).toBe(light.foreground) end
    end
    sb.Close()
  end)

  h.it("a resize stops the entrance slide so it cannot carry the popover back", function()
    local sb, dd = setup({ Options = { "A", "B" }, Searchable = true })
    h.mock.resetTweens()
    sb.Open()
    local pop = dd()
    local slide
    for _, tw in ipairs(h.mock.tweensFor(pop)) do if tw.Goal.Position ~= nil then slide = tw end end
    h.expect(slide ~= nil).toBeTruthy()
    local opts = {}
    for i = 1, 12 do opts[i] = "o" .. i end
    sb.SetOptions(opts)
    h.expect(slide.cancelled).toBe(true)
    sb.Close()
  end)

  h.it("a popover built while loading is rebuilt with rows, never synced into the skeleton", function()
    local sb, dd = setup({ Options = { "A", "B" }, Loading = true })
    sb.Open()
    h.expect(dd():FindFirstChild("List"):FindFirstChild("Loading") ~= nil).toBeTruthy()
    R.Safe._setCapabilityCheck(function() return false end)
    sb.SetLoading(false)                                 -- the rebuild is queued, loading is already off
    R.Safe._setCapabilityCheck(nil)
    sb.SetOptions({ "A", "B", "C" })                     -- runs before the queued rebuild lands
    local list = dd():FindFirstChild("List")
    h.expect(list:FindFirstChild("Loading")).toBeNil()
    h.expect(#rows(dd())).toBe(3)
    h.mock.stepHeartbeat(0)
    h.expect(#rows(dd())).toBe(3)
    sb.Close()
  end)

  h.it("an off-thread SetOptions lands on the next Heartbeat with the same in-place update", function()
    local sb, dd = setup({ Options = { "A", "B" } })
    sb.Open()
    local pop = dd()
    local ra = rowFor(pop, "A")
    R.Safe._setCapabilityCheck(function() return false end)
    sb.SetOptions({ "A", "C" })
    h.expect(rowFor(pop, "C")).toBeNil()                -- queued, not applied yet
    R.Safe._setCapabilityCheck(nil)
    h.mock.stepHeartbeat(0)
    h.expect(rowFor(pop, "A")).toBe(ra)
    h.expect(rowFor(pop, "C") ~= nil).toBeTruthy()
    h.expect(rowFor(pop, "B")).toBeNil()
    sb.Close()
  end)
end)

-- Opening a 300-pet picker built every row at once (about 1,500 instances). The list is virtual
-- now: only the rows in view plus a buffer exist, and scrolling binds them to the options below.
h.describe("selectbox: a long list builds only the rows in view", function()
  local function setup(extra)
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local o = { Parent = Create("Frame", {}) }
    for k, v in pairs(extra or {}) do o[k] = v end
    local sb = SelectBox.new(o)
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    local function dd() for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then return c end end end
    return sb, dd
  end
  local function pets(n)
    local t = {}
    for i = 1, n do t[i] = { Value = "pet" .. i, Text = "Cat " .. i } end
    return t
  end
  local function slots(dd)
    local all, visible = 0, 0
    for _, o in ipairs(dd:FindFirstChild("List"):GetChildren()) do
      if o.Name == "Opt" then all = all + 1; if o.Visible ~= false then visible = visible + 1 end end
    end
    return all, visible
  end
  local function rowFor(dd, v)
    for _, o in ipairs(dd:FindFirstChild("List"):GetChildren()) do
      if o.Name == "Opt" and o.Visible ~= false and o:GetAttribute("OptValue") == v then return o end
    end
  end
  local function scrollTo(dd, y)
    local list = dd:FindFirstChild("List")
    list.CanvasPosition = h.roblox.Vector2.new(0, y)
    list:GetPropertyChangedSignal("CanvasPosition"):Fire()
  end

  h.it("opening 300 options builds only the rows in view plus a buffer", function()
    local sb, dd = setup({ Options = pets(300), Multi = true })
    sb.Open()
    local all = slots(dd())
    h.expect(all <= 20).toBeTruthy()
    h.expect(rowFor(dd(), "pet1") ~= nil).toBeTruthy()
    h.expect(rowFor(dd(), "pet300")).toBeNil()
    h.expect(dd():FindFirstChild("List").CanvasSize.Y.Offset).toBe(300 * 26 + 299 * 2)
    sb.Close()
  end)

  h.it("rows sit where the list layout put them: 28 px apart, 38 with a description", function()
    local sb, dd = setup({ Options = { "A", { Value = "B", Desc = "two lines" }, { Divider = true }, "C" } })
    sb.Open()
    h.expect(rowFor(dd(), "A").Position.Y.Offset).toBe(0)
    h.expect(rowFor(dd(), "B").Position.Y.Offset).toBe(28)
    h.expect(rowFor(dd(), "B").Size.Y.Offset).toBe(38)
    local div
    for _, c in ipairs(dd():FindFirstChild("List"):GetChildren()) do if c.Name == "Divider" then div = c end end
    h.expect(div.Position.Y.Offset).toBe(28 + 38 + 2)
    h.expect(rowFor(dd(), "C").Position.Y.Offset).toBe(28 + 38 + 2 + 1 + 2)
    sb.Close()
  end)

  h.it("scrolling binds the same slots to the rows coming into view", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    scrollTo(dd(), 100 * 28)
    local band = slots(dd())                                 -- the view plus a buffer each side
    h.expect(band <= 20).toBeTruthy()
    scrollTo(dd(), 280 * 28)
    h.expect(slots(dd())).toBe(band)                         -- recycled, not built
    h.expect(rowFor(dd(), "pet281") ~= nil).toBeTruthy()
    h.expect(rowFor(dd(), "pet281").Position.Y.Offset).toBe(280 * 28)
    h.expect(rowFor(dd(), "pet1")).toBeNil()
    sb.Close()
  end)

  h.it("a click on a recycled row picks the option it shows now", function()
    local sb, dd = setup({ Options = pets(300), Multi = true })
    sb.Open()
    scrollTo(dd(), 200 * 28)
    rowFor(dd(), "pet205").MouseButton1Click:Fire()
    local v = sb.GetValue()
    h.expect(#v).toBe(1)
    h.expect(v[1]).toBe("pet205")
    h.expect(rowFor(dd(), "pet205"):FindFirstChild("Check").Visible).toBe(true)
    sb.Close()
  end)

  h.it("a picked option scrolled into view shows its tick, an unpicked one in its slot does not", function()
    local sb, dd = setup({ Options = pets(300), Multi = true, Default = { "pet3", "pet250" } })
    sb.Open()
    h.expect(rowFor(dd(), "pet3"):FindFirstChild("Check").Visible).toBe(true)
    scrollTo(dd(), 249 * 28)
    h.expect(rowFor(dd(), "pet250"):FindFirstChild("Check").Visible).toBe(true)
    h.expect(rowFor(dd(), "pet251"):FindFirstChild("Check").Visible).toBe(false)
    sb.Close()
  end)

  h.it("the search reaches options far down the list", function()
    local sb, dd = setup({ Options = pets(300), Searchable = true })
    sb.Open()
    sb.Filter("cat 299")
    h.expect(rowFor(dd(), "pet299") ~= nil).toBeTruthy()
    local _, visible = slots(dd())
    h.expect(visible).toBe(1)
    h.expect(rowFor(dd(), "pet299").Position.Y.Offset).toBe(0)
    sb.Close()
  end)

  h.it("a filter that shortens the list keeps the scroll inside it", function()
    local sb, dd = setup({ Options = pets(300), Searchable = true })
    sb.Open()
    scrollTo(dd(), 250 * 28)
    sb.Filter("cat 29")                                      -- 11 rows: pet29, pet290..299
    local canvas, view = 11 * 26 + 10 * 2, 240 - 34 - 4
    h.expect(dd():FindFirstChild("List").CanvasPosition.Y).toBe(canvas - view)   -- the new bottom
    h.expect(rowFor(dd(), "pet299") ~= nil).toBeTruthy()
    sb.Close()
  end)

  h.it("at a UI scale the list scrolls to its real bottom (the view is not read in screen px)", function()
    R.Overlay.setScale(1.25)
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local list = dd():FindFirstChild("List")
    local view = 240 - 34 - 4
    list.AbsoluteWindowSize = h.roblox.Vector2.new(200, view * 1.25)   -- what the engine reports
    local bottom = (300 * 26 + 299 * 2) - view
    scrollTo(dd(), bottom)
    h.expect(list.CanvasPosition.Y).toBe(bottom)
    h.expect(rowFor(dd(), "pet300") ~= nil).toBeTruthy()
    sb.Close()
    R.Overlay.setScale(1)
  end)

  h.it("a press on a row that scrolls to another option before the release picks nothing", function()
    local sb, dd = setup({ Options = pets(300), Multi = true })
    sb.Open()
    local row = rowFor(dd(), "pet2")
    row.MouseButton1Down:Fire()
    scrollTo(dd(), 95 * 28)                                  -- the slot now shows another option
    row.MouseButton1Click:Fire()
    h.expect(#sb.GetValue()).toBe(0)
    rowFor(dd(), "pet97").MouseButton1Down:Fire()            -- an ordinary press and release still picks
    rowFor(dd(), "pet97").MouseButton1Click:Fire()
    h.expect(sb.GetValue()[1]).toBe("pet97")
    sb.Close()
  end)

  h.it("a tick on a recycled row keeps the same hover recipe (no rebinding while scrolling)", function()
    local sb, dd = setup({ Options = pets(300), Multi = true, Default = { "pet150" } })
    sb.Open()
    local row = rowFor(dd(), "pet3")
    row.MouseEnter:Fire()                                    -- the pointer rests on this row
    h.expect(row.BackgroundTransparency).toBe(R.Theme.Opacity.optionHover)
    scrollTo(dd(), 147 * 28)
    local now = rowFor(dd(), "pet150")
    h.expect(now:FindFirstChild("Check").Visible).toBe(true)
    now.MouseLeave:Fire()
    h.expect(now.BackgroundTransparency).toBe(0)             -- a picked row rests filled
    sb.Close()
  end)

  h.it("an option whose Value cannot be an attribute still shows and picks", function()
    local key = { id = 7 }
    local sb, dd = setup({ Options = { { Value = key, Text = "Seven" }, { Value = "b", Text = "B" } } })
    sb.Open()
    local seven
    for _, o in ipairs(dd():FindFirstChild("List"):GetChildren()) do
      if o.Name == "Opt" and o:FindFirstChild("OptLabel").Text == "Seven" then seven = o end
    end
    h.expect(seven:GetAttribute("OptValue")).toBeNil()       -- a table is never written as an attribute
    seven.MouseButton1Click:Fire()
    h.expect(sb.GetValue()).toBe(key)
  end)

  h.it("an off-thread scroll is drawn on the next Heartbeat; a closed list ignores it", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local pop = dd()
    local list = pop:FindFirstChild("List")
    R.Safe._setCapabilityCheck(function() return false end)
    list.CanvasPosition = h.roblox.Vector2.new(0, 100 * 28)
    list:GetPropertyChangedSignal("CanvasPosition"):Fire()
    R.Safe._setCapabilityCheck(nil)
    h.expect(rowFor(pop, "pet101")).toBeNil()
    h.mock.stepHeartbeat(0)
    h.expect(rowFor(pop, "pet101") ~= nil).toBeTruthy()
    sb.Close()
    list:GetPropertyChangedSignal("CanvasPosition"):Fire()   -- disconnected: nothing happens
  end)
end)

h.describe("selectbox: a reopened dropdown revives the parked popover instead of rebuilding", function()
  local function setup(extra)
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, 800)
    local o = { Parent = Create("Frame", {}) }
    for k, v in pairs(extra or {}) do o[k] = v end
    local sb = SelectBox.new(o)
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    local function dd() for _, c in ipairs(root:GetChildren()) do if c.Name == "SelectDropdown" then return c end end end
    return sb, dd, root
  end
  local function pets(n)
    local t = {}
    for i = 1, n do t[i] = { Value = "pet" .. i, Text = "Cat " .. i } end
    return t
  end
  local function rowFor(dd, v)
    for _, o in ipairs(dd:FindFirstChild("List"):GetChildren()) do
      if o.Name == "Opt" and o.Visible ~= false and o:GetAttribute("OptValue") == v then return o end
    end
  end

  h.it("close detaches the popover (contract: gone from the overlay) but keeps it alive", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    h.expect(dd()).toBeNil()             -- a closed box leaves nothing in the overlay root
    h.expect(first.Parent).toBeNil()     -- detached, not destroyed: Destroy would drop the children
    h.expect(first:FindFirstChild("List") ~= nil).toBeTruthy()
  end)

  h.it("reopening mounts the SAME popover back, for a fraction of the build writes", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    h.mock.writes = 0
    sb.Open()
    local reopenWrites = h.mock.writes
    h.expect(dd()).toBe(first)           -- the parked frame, not a rebuild
    h.expect(reopenWrites < 100).toBeTruthy()
    h.expect(rowFor(first, "pet1") ~= nil).toBeTruthy()
    sb.Close()
  end)

  h.it("a reopened popover is placed for where the control is NOW", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    sb.Frame.AbsolutePosition = h.roblox.Vector2.new(120, 200)
    sb.Open()
    h.expect(dd()).toBe(first)
    h.expect(first.Position.X.Offset).toBe(120)
    h.expect(first.Position.Y.Offset).toBe(242)   -- 200 + 38 + 4 gap
    sb.Close()
  end)

  h.it("a SetValue while closed ticks the revived rows", function()
    local sb, dd = setup({ Options = pets(300), Default = "pet1" })
    sb.Open(); sb.Close()
    sb.SetValue("pet3")
    sb.Open()
    h.expect(rowFor(dd(), "pet3"):FindFirstChild("Check").Visible).toBe(true)
    h.expect(rowFor(dd(), "pet1"):FindFirstChild("Check").Visible).toBe(false)
    sb.Close()
  end)

  h.it("a same-shape SetOptions while closed re-binds the revived rows in place", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    local renamed = pets(300); renamed[1].Text = "Dog 1"
    sb.SetOptions(renamed)
    sb.Open()
    h.expect(dd()).toBe(first)
    h.expect(rowFor(first, "pet1"):FindFirstChild("OptLabel").Text).toBe("Dog 1")
    sb.Close()
  end)

  h.it("a SetOptions that changes the popover shape while closed rebuilds it", function()
    local sb, dd = setup({ Options = { "A", "B" } })   -- short: no search box
    sb.Open()
    local first = dd()
    h.expect(first:FindFirstChild("Search")).toBeNil()
    sb.Close()
    sb.SetOptions(pets(300))                           -- crosses the search threshold
    sb.Open()
    local second = dd()
    h.expect(second == first).toBe(false)
    h.expect(second:FindFirstChild("Search") ~= nil).toBeTruthy()
    h.expect(first.Parent).toBeNil()                   -- the stale cache was dropped
    sb.Close()
  end)

  h.it("the search query does not survive a close", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    local input = first:FindFirstChild("Search"):FindFirstChild("Input")
    input.Text = "cat 2"
    input:GetPropertyChangedSignal("Text"):Fire()   -- the engine fires this on the write
    h.expect(rowFor(first, "pet1")).toBeNil()
    sb.Close()
    sb.Open()
    h.expect(dd()).toBe(first)
    h.expect(input.Text).toBe("")
    h.expect(rowFor(first, "pet1") ~= nil).toBeTruthy()
    sb.Close()
  end)

  h.it("Filter while closed is a no-op: the next Open still starts clean", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open(); local first = dd(); sb.Close()
    sb.Filter("cat 2")
    sb.Open()
    h.expect(dd()).toBe(first)
    h.expect(rowFor(first, "pet1") ~= nil).toBeTruthy()
    sb.Close()
  end)

  h.it("a click landing on a parked row (the exit fold) picks nothing", function()
    local picked
    local sb, dd = setup({ Options = pets(300), Default = "pet1", Callback = function(v) picked = v end })
    sb.Open()
    local row = rowFor(dd(), "pet2")
    sb.Close()
    row.MouseButton1Down:Fire(); row.MouseButton1Click:Fire()   -- still on screen while folding
    h.expect(sb.GetValue()).toBe("pet1")
    h.expect(picked).toBeNil()
  end)

  h.it("hover state does not survive the park: a revived row rests", function()
    local sb, dd = setup({ Options = pets(300), Default = "pet1" })
    sb.Open()
    local first = dd()
    local row = rowFor(first, "pet2")
    row.MouseEnter:Fire(0, 0)
    h.expect(row.BackgroundTransparency < 1).toBeTruthy()   -- hover wash on
    sb.Close()                                              -- no MouseLeave for a detached frame
    sb.Open()
    h.expect(rowFor(first, "pet2").BackgroundTransparency).toBe(1)   -- back at its rest
    sb.Close()
  end)

  h.it("Overlay.reset (the window teardown) destroys the parked popover", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open(); local first = dd(); sb.Close()
    R.Overlay.reset()
    h.expect(first:FindFirstChild("List")).toBeNil()   -- dropped, not orphaned off-tree
  end)

  h.it("a reopened popover starts at the top again", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    local list = first:FindFirstChild("List")
    list.CanvasPosition = h.roblox.Vector2.new(0, 100 * 28)
    list:GetPropertyChangedSignal("CanvasPosition"):Fire()
    sb.Close()
    sb.Open()
    h.expect(list.CanvasPosition.Y).toBe(0)
    h.expect(rowFor(first, "pet1") ~= nil).toBeTruthy()
    h.expect(rowFor(first, "pet101")).toBeNil()
    sb.Close()
  end)

  h.it("only one popover stays parked: a second box parking drops the first", function()
    local sbA, ddA = setup({ Options = pets(300) })
    sbA.Open()
    local frameA = ddA()
    sbA.Close()
    local sbB = SelectBox.new({ Parent = Create("Frame", {}), Options = pets(300) })
    sbB.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
    sbB.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 38)
    sbB.Open(); sbB.Close()
    sbA.Open()
    h.expect(ddA() == frameA).toBe(false)   -- A's cache was dropped when B parked
    sbA.Close()
  end)

  h.it("a palette change while parked repaints the revived popover", function()
    local t = R.Theme.new({})
    local sb, dd = setup({ Options = pets(300), Theme = t })
    sb.Open()
    local first = dd()
    sb.Close()
    R.Theme.applyMode(t, "light")   -- no registration while parked: nothing repaints it here
    sb.Open()
    local light = R.Theme.PALETTES.light
    h.expect(dd()).toBe(first)
    h.expect(first.BackgroundColor3).toBe(light.card)
    h.expect(rowFor(first, "pet1"):FindFirstChild("OptLabel").TextColor3).toBe(light.foreground)
    sb.Close()
    R.Theme.applyMode(t, "dark")
  end)

  h.it("a scale change while parked rebuilds for the new scale", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    R.Overlay.setScale(1.3)
    sb.Open()
    local second = dd()
    h.expect(second == first).toBe(false)
    h.expect(second:FindFirstChildOfClass("UIScale").Scale).toBe(1.3)
    sb.Close()
    R.Overlay.setScale(1)
  end)

  h.it("a field width change while parked rebuilds for the new width", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    sb.Frame.AbsoluteSize = h.roblox.Vector2.new(320, 38)
    sb.Open()
    local second = dd()
    h.expect(second == first).toBe(false)
    h.expect(second.Size.X.Offset).toBe(320)
    sb.Close()
  end)

  h.it("a loading popover is never parked", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.SetLoading(true)
    sb.Open()
    local first = dd()
    h.expect(first:FindFirstChild("List"):FindFirstChild("Loading") ~= nil).toBeTruthy()
    sb.Close()
    sb.SetLoading(false)
    sb.Open()
    h.expect(dd() == first).toBe(false)
    sb.Close()
  end)

  h.it("a SetLoading while parked rebuilds the skeleton popover on the next Open", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    sb.SetLoading(true)
    sb.Open()
    local second = dd()
    h.expect(second == first).toBe(false)
    h.expect(second:FindFirstChild("List"):FindFirstChild("Loading") ~= nil).toBeTruthy()
    sb.Close()
    sb.SetLoading(false)
  end)

  h.it("Destroy drops the parked popover", function()
    local sb, dd = setup({ Options = pets(300) })
    sb.Open()
    local first = dd()
    sb.Close()
    sb.Destroy()
    h.expect(first:FindFirstChild("List")).toBeNil()   -- destroyed, not just detached
  end)

  h.it("while parked, a themer replay paints nothing (the registration is released)", function()
    local reg = { fns = {} }
    function reg.AccentReg(fn) reg.fns[#reg.fns + 1] = fn; return function()
      for i, f in ipairs(reg.fns) do if f == fn then table.remove(reg.fns, i); break end end
    end end
    local sb, dd = setup({ Options = pets(300), AccentReg = reg.AccentReg })
    h.expect(#reg.fns).toBe(1)
    sb.Open()
    h.expect(#reg.fns).toBe(2)
    sb.Close()
    h.expect(#reg.fns).toBe(1)   -- parked popover holds no registration
    sb.Open()
    h.expect(#reg.fns).toBe(2)   -- revived popover re-registers
    sb.Close()
  end)
end)

h.run()
