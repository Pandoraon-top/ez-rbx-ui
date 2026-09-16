local h = require("tests.helper")
local R = h.loadLib()
local function tipOf(root)
  for _, c in ipairs(root:GetChildren()) do if c.Name == "Tooltip" then return c end end
end
local function newTarget(x, y, w, hgt)
  local t = h.roblox.Instance.new("TextButton")
  if x then
    t.AbsolutePosition = h.roblox.Vector2.new(x, y)
    t.AbsoluteSize = h.roblox.Vector2.new(w, hgt)
  end
  return t
end
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

  -- ---- visual-polish (1.2 muted role, 2.14 inverted chip / hover intent / anchoring) ----
  h.it("inverted chip: foreground fill, background text, muted Font role and no stroke", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello")
    target.MouseEnter:Fire()
    local tip = tipOf(R.Overlay.get(gui))
    h.expect(tip ~= nil).toBeTruthy()
    h.expect(tip.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(tip.Font).toBe(h.roblox.Enum.Font.BuilderSans)
    -- inverted: it is a label ABOUT the UI, not another surface of it (2.14 replaces the
    -- card-coloured chip + hairline stroke that phase 1 shipped)
    h.expect(tip.BackgroundColor3).toBe(R.Theme.Colors.foreground)
    h.expect(tip.TextColor3).toBe(R.Theme.Colors.background)
    h.expect(tip:FindFirstChildOfClass("UIStroke")).toBeNil()   -- the inversion IS the edge
    h.expect(tip.Size.Y.Offset).toBe(R.Theme.Tooltip.height)
    h.expect(tip.ZIndex).toBe(R.Overlay.Z.tooltip)
    target.MouseLeave:Fire()
  end)

  h.it("a themed tooltip reads the live palette on every show (no stale colour after a mode swap)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local t = R.Theme.new()
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello", t)
    target.MouseEnter:Fire(); target.MouseLeave:Fire()
    t.Colors.foreground = h.roblox.Color3.fromRGB(1, 2, 3)
    t.Colors.background = h.roblox.Color3.fromRGB(4, 5, 6)
    target.MouseEnter:Fire()
    local tip = tipOf(R.Overlay.get(gui))
    h.expect(tip.BackgroundColor3).toBe(t.Colors.foreground)
    h.expect(tip.TextColor3).toBe(t.Colors.background)
    target.MouseLeave:Fire()
  end)

  h.it("hover intent: nothing is built until Tooltip.delay has elapsed", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello")
    h.withQueuedTimers(function()
      target.MouseEnter:Fire()
      h.expect(tipOf(root)).toBeNil()                         -- pointer merely sweeping past
      h.mock.advance(R.Theme.Tooltip.delay + 0.01)
      h.expect(tipOf(root) ~= nil).toBeTruthy()
      target.MouseLeave:Fire()
      h.expect(tipOf(root)).toBeNil()
    end)
  end)

  h.it("a MouseLeave before the delay elapses cancels the pending build", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello")
    h.withQueuedTimers(function()
      target.MouseEnter:Fire()
      target.MouseLeave:Fire()
      h.mock.advance(0.4)                                     -- past the delay
      h.expect(tipOf(root)).toBeNil()                         -- the armed token was dropped
      target.MouseEnter:Fire()                                -- a later hover still works
      h.mock.advance(0.4)
      h.expect(tipOf(root) ~= nil).toBeTruthy()
      target.MouseLeave:Fire()
    end)
  end)

  h.it("anchors above the target, flips below near the top and clamps inside the viewport", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local T = R.Theme.Tooltip
    local target = newTarget(400, 300, 100, 30)
    R.Tooltip.attach(target, "Hi")
    target.MouseEnter:Fire()
    local tip = tipOf(root)
    h.expect(tip.AnchorPoint.X).toBe(0.5)
    h.expect(tip.AnchorPoint.Y).toBe(1)                        -- grows upward from its own bottom
    h.expect(tip.Position.X.Offset).toBe(450)                  -- centred over the target
    h.expect(tip.Position.Y.Offset).toBe(300 - T.gap)
    target.MouseLeave:Fire()
    local top = newTarget(400, 4, 100, 30)
    R.Tooltip.attach(top, "Hi")
    top.MouseEnter:Fire()
    tip = tipOf(root)
    h.expect(tip.Position.Y.Offset).toBe(4 + 30 + T.gap + T.height)   -- no room above: below
    top.MouseLeave:Fire()
    local edge = newTarget(1910, 300, 20, 30)
    R.Tooltip.attach(edge, "A long tooltip label")
    edge.MouseEnter:Fire()
    tip = tipOf(root)
    h.expect(tip.Position.X.Offset < 1920).toBeTruthy()        -- clamped by half the chip width
    edge.MouseLeave:Fire()
  end)

  h.it("fades out (fold-out curve) before it is destroyed", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hello")
    target.MouseEnter:Fire()
    local tip = tipOf(root)
    h.expect(tip.BackgroundTransparency).toBe(0)               -- faded in on show
    h.mock.resetTweens()
    target.MouseLeave:Fire()
    local tws = h.mock.tweensFor(tip)
    h.expect(tws[1].Goal.BackgroundTransparency).toBe(1)
    h.expect(tws[1].Goal.TextTransparency).toBe(1)
    h.expect(tws[1].Info.EasingDirection).toBe(h.roblox.Enum.EasingDirection.In)
    h.expect(tipOf(root)).toBeNil()                            -- destroyed once the fade completes
  end)

  h.it("touch: attach returns an inert handle and never builds a chip", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true
    local target = h.roblox.Instance.new("TextButton")
    local handle = R.Tooltip.attach(target, "Hi")
    uis.TouchEnabled = false
    target.MouseEnter:Fire()
    h.expect(tipOf(root)).toBeNil()                            -- no connections were ever made
    handle.Destroy()                                           -- and tearing it down is safe
  end)

  h.it("TooltipShadow: none without a shadow asset; a sibling one layer below the chip otherwise", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local plain = h.roblox.Instance.new("TextButton")
    -- state the no-asset path: the default theme now ships an uploaded sprite. A bare assertion
    -- failing here would also skip the MouseLeave below and strand the chip in the shared overlay
    -- root, which every later test in this file reads.
    R.Tooltip.attach(plain, "Hi", R.Theme.new({ Effect = { shadowId = "" } }))
    plain.MouseEnter:Fire()
    h.expect(root:FindFirstChild("TooltipShadow")).toBeNil()
    plain.MouseLeave:Fire()
    local t = R.Theme.new({ Effect = { shadowId = "rbxassetid://1" } })
    local lit = newTarget(400, 300, 100, 30)
    R.Tooltip.attach(lit, "Hi", t)
    lit.MouseEnter:Fire()
    local sh = root:FindFirstChild("TooltipShadow")
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.ZIndex).toBe(R.Overlay.Z.tooltip - 1)          -- under the chip, never over it
    h.expect(sh.ImageTransparency).toBe(R.Theme.MODE_EFFECTS.dark.shadow)
    h.expect(sh.Position.X.Offset).toBe(450)                   -- centred on the chip
    lit.MouseLeave:Fire()
    h.expect(root:FindFirstChild("TooltipShadow")).toBeNil()   -- destroyed with the chip
  end)

  h.it("takes the overlay UI scale on its own root (never on the overlay root)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hi")
    R.Overlay.setScale(1.5)
    target.MouseEnter:Fire()
    local tip = tipOf(root)
    h.expect(tip:FindFirstChildOfClass("UIScale").Scale).toBe(1.5)
    h.expect(root:FindFirstChildOfClass("UIScale")).toBeNil()
    target.MouseLeave:Fire()
    R.Overlay.setScale(1)                                      -- restore process-wide state
  end)

  h.it("reduced motion: the chip appears and vanishes with no tweens", function()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local target = h.roblox.Instance.new("TextButton")
    R.Tooltip.attach(target, "Hi")
    h.withReducedMotion(R, function()
      h.mock.resetTweens()
      target.MouseEnter:Fire()
      local tip = tipOf(root)
      h.expect(tip ~= nil).toBeTruthy()
      h.expect(tip.BackgroundTransparency).toBe(0)
      h.expect(tip:FindFirstChildOfClass("UIScale").Scale).toBe(1)
      h.expect(h.mock.tweenCount()).toBe(0)
      target.MouseLeave:Fire()
      h.expect(tipOf(root)).toBeNil()
      h.expect(h.mock.tweenCount()).toBe(0)
    end)
  end)
end)
h.run()
