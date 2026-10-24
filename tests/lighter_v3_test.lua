local h = require("tests.helper")

-- A hub's third audit: what still cost work it did not need -- an accordion animating its height in
-- a light window, three hidden images per select box, a probe write per mutation, setters that
-- repaint an unchanged value, and a CanvasGroup dialog in a light window.
local function window(cfg)
  local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
  cfg = cfg or {}; cfg.Title = cfg.Title or "M"; cfg.Parent = screen
  return R.Window.new(cfg), R, screen
end
local function writes(fn) h.mock.writes = 0; fn(); return h.mock.writes end

h.describe("accordion: no height animation when it is not wanted", function()
  local function sizeTweens(inst)
    local n = 0
    for _, tw in ipairs(h.mock.tweensFor(inst)) do if tw.Goal.Size then n = n + 1 end end
    return n
  end
  h.it("a light window opens and closes a section at once, caret included", function()
    local w = window({ Effects = "light" })
    local acc = w:AddTab({ Name = "T" }):AddAccordion({ Title = "S" })
    acc:AddToggle({ Text = "x" })
    h.mock.resetTweens()
    acc:Expand()
    h.expect(sizeTweens(acc.Container)).toBe(0)
    h.expect(acc.Container.AutomaticSize.Name).toBe("Y")
    h.expect(acc.Content.Visible).toBe(true)
    acc:Collapse()
    h.expect(sizeTweens(acc.Container)).toBe(0)
    h.expect(acc.Content.Visible).toBe(false)
    h.expect(acc.Container.AutomaticSize.Name).toBe("None")
  end)
  h.it("with motion off the section takes the instant branch (no AutomaticSize flip)", function()
    local w, R = window()
    local acc = w:AddTab({ Name = "T" }):AddAccordion({ Title = "S" })
    acc:AddToggle({ Text = "x" })
    -- measured content: the animated branch would go through None to tween the height
    acc.Content:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize = h.roblox.Vector2.new(0, 40)
    h.withReducedMotion(R, function()
      local seen = {}
      local c = acc.Container
      local mt = getmetatable(c)
      local set = mt.__newindex
      mt.__newindex = function(t, k, v) if k == "AutomaticSize" then seen[#seen + 1] = v.Name end; set(t, k, v) end
      acc:Expand()
      mt.__newindex = set
      h.expect(#seen).toBe(1)                                   -- straight to Y, never through None
      h.expect(seen[1]).toBe("Y")
    end)
  end)
  h.it("the full look with motion on still animates", function()
    local w = window()
    local acc = w:AddTab({ Name = "T" }):AddAccordion({ Title = "S" })
    acc:AddToggle({ Text = "x" })
    -- the mock has no layout engine: give the list a measured height so there is one to animate to
    acc.Content:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize = h.roblox.Vector2.new(0, 40)
    h.mock.resetTweens()
    acc:Expand()
    h.expect(sizeTweens(acc.Container) > 0).toBeTruthy()
  end)
end)

h.describe("select box: hidden parts are built when first needed", function()
  local function parts(sb)
    local field = sb.Frame:FindFirstChild("Field")
    return field:FindFirstChild("Spinner"), field:FindFirstChild("Clear"), field:FindFirstChild("FieldIcon")
  end
  h.it("a plain closed select box builds no spinner, clear button or field icon", function()
    local w = window()
    local sb = w:AddTab({ Name = "T" }):AddSelectBox({ Text = "s", Options = { "a", "b" } })
    local spinner, clear, icon = parts(sb)
    h.expect(spinner).toBeNil(); h.expect(clear).toBeNil(); h.expect(icon).toBeNil()
  end)
  h.it("each part appears when it has something to show", function()
    local w = window()
    local tab = w:AddTab({ Name = "T" })
    local multi = tab:AddSelectBox({ Text = "m", Multi = true, Options = { "a", "b" } })
    h.expect((select(2, parts(multi)))).toBeNil()
    multi.SetValue({ "a" })
    h.expect(select(2, parts(multi)).Visible).toBe(true)        -- the clear button, on the first pick
    local iconic = tab:AddSelectBox({ Text = "i", Options = { { Value = "x", Icon = "home" } } })
    h.expect(select(3, parts(iconic)).Visible).toBe(true)       -- the field icon, for an option with one
    local loading = tab:AddSelectBox({ Text = "l", Options = { "a" } })
    loading.SetLoading(true)
    h.expect(parts(loading).Visible).toBe(true)                 -- the spinner, on SetLoading(true)
    loading.SetLoading(false)
    h.expect(parts(loading).Visible).toBe(false)
  end)
  h.it("every focus ring shares one invisible selection adornment", function()
    local _, R = window()
    local a = R.Create("TextBox", {}); local b = R.Create("TextBox", {})
    R.Recipes.focus(R.Create.stroke(R.Theme.Colors.border, 1), a, function() return R.Theme.Colors.border end)
    R.Recipes.focus(R.Create.stroke(R.Theme.Colors.border, 1), b, function() return R.Theme.Colors.border end)
    h.expect(a.SelectionImageObject ~= nil).toBeTruthy()
    h.expect(a.SelectionImageObject).toBe(b.SelectionImageObject)
  end)
  h.it("a light window is opaque unless a Transparency is given", function()
    local light = window({ Effects = "light" })
    h.expect(light.Main.BackgroundTransparency).toBe(0)
    local seeThrough = window({ Effects = "light", Transparency = 0.3 })
    h.expect(seeThrough.Main.BackgroundTransparency).toBe(0.3)
    local full = window()
    h.expect(full.Main.BackgroundTransparency).toBe(full.Main.BackgroundTransparency)   -- unchanged default
    h.expect(full.Main.BackgroundTransparency > 0).toBeTruthy()
  end)
end)

h.describe("Safe.mutate probes once per thread per frame", function()
  h.it("ten mutations in one frame cost one probe write; the next frame probes again", function()
    local _, R = window()
    local n = 0
    -- a fresh thread: nothing cached for it yet (the main thread probed while the window built)
    local co = coroutine.create(function() for _ = 1, 10 do R.Safe.mutate(function() n = n + 1 end) end end)
    local mutated = writes(function() coroutine.resume(co) end)
    h.expect(n).toBe(10)
    h.expect(mutated).toBe(1)
    -- the next frame asks again (another Heartbeat handler may be the one that probes first)
    h.expect(writes(function() h.mock.stepHeartbeat(0); R.Safe.mutate(function() end) end) >= 1).toBeTruthy()
  end)
  h.it("another thread in the same frame is probed for itself", function()
    local _, R = window()
    R.Safe.mutate(function() end)                                -- the main thread is cached
    local w0 = h.mock.writes
    local co = coroutine.create(function() R.Safe.mutate(function() end) end)
    h.mock.writes = 0
    coroutine.resume(co)
    h.expect(h.mock.writes).toBe(1)
    h.mock.writes = w0
  end)
end)

h.describe("setters with an unchanged value write nothing", function()
  h.it("Toggle.Set with the value it shows writes nothing and still calls back", function()
    local w = window()
    local calls = 0
    local t = w:AddTab({ Name = "T" }):AddToggle({ Text = "x", Default = true, Callback = function() calls = calls + 1 end })
    h.expect(writes(function() t.Set(true) end)).toBe(0)
    h.expect(calls).toBe(1)
    h.expect(writes(function() t.Set(false) end) > 0).toBeTruthy()
  end)
  h.it("SelectBox.SetValue with the same picks (a new table) and SetOptions with the same list write nothing", function()
    local w = window()
    local sb = w:AddTab({ Name = "T" }):AddSelectBox({ Text = "s", Multi = true,
      Options = { { Value = "a", Text = "A" }, { Value = "b", Text = "B" } }, Default = { "a" } })
    h.expect(writes(function() sb.SetValue({ "a" }) end)).toBe(0)
    h.expect(writes(function() sb.SetOptions({ { Value = "a", Text = "A" }, { Value = "b", Text = "B" } }) end)).toBe(0)
    h.expect(writes(function() sb.SetOptions({ { Value = "a", Text = "A2" }, { Value = "b", Text = "B" } }) end) > 0).toBeTruthy()
  end)
  h.it("a picks table changed in place still counts as a change", function()
    local w = window()
    local sb = w:AddTab({ Name = "T" }):AddSelectBox({ Text = "s", Multi = true, Options = { "a", "b" } })
    local picks = { "a" }
    sb.SetValue(picks)
    picks[2] = "b"
    sb.SetValue(picks)
    h.expect(sb.Frame:FindFirstChild("Field"):FindFirstChild("Value").Text).toBe("a, b")   -- repainted
  end)
  h.it("a value a config reset restores is not mistaken for the one set before it", function()
    local _, R = window()
    local cfg = R.Config.new({ FileName = "V3", AutoSave = false })
    local t = R.Toggle.new({ Parent = R.Create("Frame", {}), Text = "x", Flag = "f", Config = cfg, Default = false })
    t.Set(true)
    cfg:ResetFlag("f")                                          -- applies false through the config, not Set
    h.expect(t.Get()).toBe(false)
    t.Set(true)                                                 -- same value as the last Set: must still apply
    h.expect(t.Get()).toBe(true)
  end)
end)

h.describe("dialog in a light window", function()
  h.it("the card is a plain Frame (a CanvasGroup re-renders its texture on any change)", function()
    local light = window({ Effects = "light" })
    light:Dialog({ Title = "d", Message = "m", Buttons = { { Text = "OK" } } })
    h.expect(light.Main:FindFirstChild("Dialog"):FindFirstChild("Card").ClassName).toBe("Frame")
    local full = window()
    full:Dialog({ Title = "d", Message = "m", Buttons = { { Text = "OK" } } })
    h.expect(full.Main:FindFirstChild("Dialog"):FindFirstChild("Card").ClassName).toBe("CanvasGroup")
  end)
end)

-- The review's two blockers: a setter skipped because the control had changed its own value off
-- that path, and a remembered capability trusted after the thread had lost it.
h.describe("same-value skipping never drops a real change", function()
  h.it("a select box that pruned its value takes the old value back", function()
    local w = window()
    local tab = w:AddTab({ Name = "T" })
    local sb = tab:AddSelectBox({ Text = "s", Options = { "a", "b" }, Default = "a" })
    sb.SetOptions({ "b", "c" })                                 -- "a" gone: pruned to "b"
    sb.SetOptions({ "a", "b" })
    sb.SetValue("a")
    h.expect(sb.GetValue()).toBe("a")
    local multi = tab:AddSelectBox({ Text = "m", Multi = true, Options = { "a", "b" }, Default = { "a" } })
    multi.SetOptions({ "b" })                                   -- picks pruned to {}
    multi.SetOptions({ "a", "b" })
    multi.SetValue({ "a" })
    h.expect(#multi.GetValue()).toBe(1)
  end)
  h.it("a number box re-checks its bounds when the range widens", function()
    local w = window()
    local nb = w:AddTab({ Name = "T" }):AddNumberBox({ Text = "n", Min = 0, Max = 100, Default = 0 })
    local function minus()
      for _, c in ipairs(nb.Frame:GetChildren()) do
        local m = c.Name == "Minus" and c or c:FindFirstChild("Minus")
        if m then return m end
      end
    end
    h.expect(minus().Active).toBe(false)                        -- at Min
    nb.SetMin(-50)
    h.expect(minus().Active).toBe(true)
  end)
  h.it("a text box the player typed in can still be cleared", function()
    local w = window()
    local tb = w:AddTab({ Name = "T" }):AddTextBox({ Text = "name", Clearable = true })
    local input
    local function find(x) for _, c in ipairs(x:GetChildren()) do if c.ClassName == "TextBox" then input = input or c end; find(c) end end
    find(tb.Frame)
    input.Text = "abc"
    input:GetPropertyChangedSignal("Text"):Fire()
    tb.Clear()
    h.expect(input.Text).toBe("")
  end)
end)

h.describe("a remembered capability is checked when it fails", function()
  local function lostRoot(R)
    local peek = R.Overlay.peek
    R.Overlay.peek = function()
      return setmetatable({}, { __index = function() error("lacking capability Plugin") end,
        __newindex = function() error("lacking capability Plugin") end })
    end
    return function() R.Overlay.peek = peek end
  end
  h.it("a thread that lost it since the probe has its job moved to the Heartbeat, not thrown", function()
    local _, R = window()
    R.Safe.mutate(function() end)                                -- this thread is remembered as capable
    local restore = lostRoot(R)
    local ran, tries = false, 0
    local ok = pcall(R.Safe.mutate, function()
      tries = tries + 1
      if tries == 1 then error("lacking capability Plugin") end
      ran = true
    end)
    restore()
    h.expect(ok).toBe(true)                                      -- nothing escaped into the caller
    h.expect(ran).toBe(false)
    h.mock.stepHeartbeat(0)
    h.expect(ran).toBe(true)                                     -- retried where the capability is
  end)
  h.it("a job that is simply broken still raises its error", function()
    local _, R = window()
    R.Safe.mutate(function() end)
    local ok, err = pcall(R.Safe.mutate, function() error("boom") end)
    h.expect(ok).toBe(false)
    h.expect(tostring(err):find("boom", 1, true) ~= nil).toBeTruthy()
  end)
end)

h.describe("a paint that was queued and lost is painted again", function()
  h.it("Toggle.Set repaints when the earlier paint of that value died on the Heartbeat", function()
    local w, R = window()
    local t = w:AddTab({ Name = "T" }):AddToggle({ Text = "x" })
    R.Safe._setCapabilityCheck(function() return false end)
    t.Set(true)                                                 -- queued for the Heartbeat
    R.Safe._setCapabilityCheck(nil)
    local spring = R.Animate.springTo
    R.Animate.springTo = function() error("lost") end           -- the queued paint dies there
    h.mock.stepHeartbeat(0)
    R.Animate.springTo = spring
    h.expect(writes(function() t.Set(true) end) > 0).toBeTruthy()
  end)
  h.it("SelectBox.SetValue repaints when the earlier paint of that value died on the Heartbeat", function()
    local w, R = window()
    local sb = w:AddTab({ Name = "T" }):AddSelectBox({ Text = "s", Options = { "a", "b" }, Default = "a" })
    R.Safe._setCapabilityCheck(function() return false end)
    sb.SetValue("b")
    R.Safe._setCapabilityCheck(nil)
    local apply = R.Icons.apply
    local label = sb.Frame:FindFirstChild("Field"):FindFirstChild("Value")
    local mt = getmetatable(label)
    local set = mt.__newindex
    mt.__newindex = function(t, k, v) if k == "Text" then error("lost") end; set(t, k, v) end
    h.mock.stepHeartbeat(0)
    mt.__newindex = set
    h.expect(label.Text).toBe("a")                              -- the paint did not land
    sb.SetValue("b")
    h.expect(label.Text).toBe("b")
  end)
end)

h.run()
