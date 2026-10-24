local h = require("tests.helper")
local R = h.loadLib()

-- Every text setter used to enter Safe.mutate, whose capability probe writes a property, even when
-- the text was already showing: a hub refreshing a title every tick paid that each time. The same
-- text again now costs nothing at all, not even the probe.
h.describe("text setters skip the text already shown", function()
  local function make()
    local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Subtitle = "v1", Parent = screen })
    return w, w:AddTab({ Name = "Main" })
  end
  local function writes(fn) h.mock.writes = 0; fn(); return h.mock.writes end

  h.it("Button.SetText", function()
    local _, tab = make()
    local b = tab:AddButton({ Text = "Go" })
    h.expect(writes(function() b.SetText("Go") end)).toBe(0)
    h.expect(writes(function() b.SetText("Stop") end) > 0).toBeTruthy()
    h.expect(writes(function() b.SetText("Stop") end)).toBe(0)
  end)
  h.it("Accordion:SetTitle", function()
    local _, tab = make()
    local acc = tab:AddAccordion({ Title = "Stats" })
    h.expect(writes(function() acc:SetTitle("Stats") end)).toBe(0)
    h.expect(writes(function() acc:SetTitle("Stats 2") end) > 0).toBeTruthy()
    h.expect(acc.Header:FindFirstChild("Title", true) and true).toBeTruthy()
    h.expect(writes(function() acc:SetTitle("Stats 2") end)).toBe(0)
  end)
  h.it("Window:SetTitle, Window:SetSubtitle and Tab:SetTitle", function()
    local w, tab = make()
    h.expect(writes(function() w:SetTitle("Hub") end)).toBe(0)
    h.expect(writes(function() w:SetSubtitle("v1") end)).toBe(0)
    h.expect(writes(function() tab:SetTitle("Main") end)).toBe(0)
    h.expect(writes(function() w:SetTitle("Hub 2") end) > 0).toBeTruthy()
    h.expect(writes(function() w:SetTitle("Hub 2") end)).toBe(0)
  end)
end)

h.run()
