local h = require("tests.helper")
local R = h.loadLib()
h.describe("locked state", function()
  h.it("Locked control shows a shield; SetLocked toggles it", function()
    local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local b = tab:AddButton({ Text = "Go", Locked = true })
    local shield = b.Frame:FindFirstChild("LockShield")
    h.expect(shield ~= nil).toBeTruthy()
    h.expect(shield.Visible).toBe(true)
    b.SetLocked(false)
    h.expect(shield.Visible).toBe(false)
  end)
  h.it("Window:LockAll locks all registered controls", function()
    local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local t1 = tab:AddToggle({ Text = "a" }); local t2 = tab:AddSlider({ Text = "b", Min = 0, Max = 1 })
    w:LockAll()
    h.expect(t1.Frame:FindFirstChild("LockShield").Visible).toBe(true)
    h.expect(t2.Frame:FindFirstChild("LockShield").Visible).toBe(true)
    w:UnlockAll()
    h.expect(t1.Frame:FindFirstChild("LockShield").Visible).toBe(false)
  end)
end)
-- A hub that rebuilds a section destroys its controls and adds new ones. The window's search index
-- and lock list used to keep every destroyed control (and its frame) forever: LockAll locked 619
-- controls with 273 alive, and nothing they held could be collected.
h.describe("registries forget destroyed controls", function()
  local function make()
    local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    return w, w:AddTab({ Name = "T" })
  end
  h.it("a destroyed control is no longer locked or searched", function()
    local w, tab = make()
    local gone = tab:AddToggle({ Text = "gone" })
    local kept = tab:AddToggle({ Text = "kept" })
    local frame = gone.Frame
    gone.Destroy()
    w:LockAll()
    h.expect(frame:FindFirstChild("LockShield")).toBeNil()      -- never touched
    h.expect(kept.Frame:FindFirstChild("LockShield").Visible).toBe(true)
    w:UnlockAll()
    w:SearchTabs("zzz")
    h.expect(frame.Visible).toBeNil()                           -- the search never wrote to it
    h.expect(kept.Frame.Visible).toBe(false)
    w:SearchTabs("")
  end)
  h.it("a control destroyed with its section is dropped too", function()
    local w, tab = make()
    local acc = tab:AddAccordion({ Title = "S", Expanded = true })
    local inner = acc:AddToggle({ Text = "inner" })
    local frame = inner.Frame
    acc.Container:Destroy()                                     -- the hub drops the whole section
    w:LockAll()
    h.expect(frame:FindFirstChild("LockShield")).toBeNil()
    w:SearchTabs("inner")
    h.expect(frame.Visible).toBeNil()
  end)
  h.it("rebuilding a section many times does not grow what LockAll walks", function()
    local w, tab = make()
    local calls = 0
    for round = 1, 5 do
      local acc = tab:AddAccordion({ Title = "S" .. round })
      for i = 1, 4 do
        local t = acc:AddToggle({ Text = "t" .. i })
        local set = t.SetLocked
        t.SetLocked = function(b) calls = calls + 1; return set(b) end
      end
      if round < 5 then acc.Container:Destroy() end
    end
    w:LockAll()
    h.expect(calls).toBe(4)                                     -- only the live section
  end)
end)

h.run()
