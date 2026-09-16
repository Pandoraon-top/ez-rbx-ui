local h = require("tests.helper")
local R = h.loadLib()
h.describe("tooltip", function()
  h.it("shows on hover into overlay and hides on leave", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello")
    target.MouseEnter:Fire()
    local root = R.Overlay.get(gui); local shown = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "Tooltip" then shown = true end end
    h.expect(shown).toBeTruthy()
    target.MouseLeave:Fire()
    local still = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "Tooltip" then still = true end end
    h.expect(still).toBe(false)
  end)

  -- ---- visual-polish phase 1 (1.2 muted role, 1.5 floating stroke) ----
  h.it("tooltip uses the muted Font role and the floating stroke alpha", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello")
    target.MouseEnter:Fire()
    local tip
    for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "Tooltip" then tip = c end end
    h.expect(tip ~= nil).toBeTruthy()
    h.expect(tip.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(tip.Font).toBe(h.roblox.Enum.Font.BuilderSans)
    h.expect(tip.BackgroundColor3).toBe(R.Theme.Colors.card)
    h.expect(tip.TextColor3).toBe(R.Theme.Colors.foreground)
    local stroke = tip:FindFirstChildOfClass("UIStroke")
    h.expect(stroke ~= nil).toBeTruthy()
    h.expect(stroke.Color).toBe(R.Theme.Colors.border)
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.floating)
    h.expect(stroke.Thickness).toBe(1)
    target.MouseLeave:Fire()
  end)

  h.it("a themed tooltip reads the live palette on every show (no stale colour after a mode swap)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local t = R.Theme.new()
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello", t)
    target.MouseEnter:Fire(); target.MouseLeave:Fire()
    t.Colors.card = h.roblox.Color3.fromRGB(1, 2, 3)
    target.MouseEnter:Fire()
    local tip
    for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "Tooltip" then tip = c end end
    h.expect(tip.BackgroundColor3).toBe(t.Colors.card)
    target.MouseLeave:Fire()
  end)
end)
h.run()
