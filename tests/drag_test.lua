local h = require("tests.helper")
local R = h.loadLib()
local Drag = R.Drag
local UIT = h.roblox.Enum.UserInputType

local function btn() return h.roblox.Instance.new("ImageButton") end
local function uis() return h.roblox.game:GetService("UserInputService") end

h.describe("drag helper", function()
  h.it("mouse: MouseButton1 begin + MouseMovement reports the delta", function()
    local b, maid = btn(), R.Maid.new()
    local dx, dy, pos
    Drag.bind(b, { onChange = function(a, c, p) dx, dy, pos = a, c, p end }, maid)
    b.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(100, 100) })
    uis().InputChanged:Fire({ UserInputType = UIT.MouseMovement, Position = h.roblox.Vector2.new(140, 120) })
    h.expect(dx).toBe(40); h.expect(dy).toBe(20)
    h.expect(pos.X).toBe(140); h.expect(pos.Y).toBe(120)
    maid:DoCleanup()
  end)
  h.it("touch: only the originating finger drives the drag", function()
    local b, maid = btn(), R.Maid.new()
    local calls, lastdx = 0, nil
    Drag.bind(b, { onChange = function(a) calls = calls + 1; lastdx = a end }, maid)
    local touch = { UserInputType = UIT.Touch, Position = h.roblox.Vector2.new(0, 0) }
    local other = { UserInputType = UIT.Touch, Position = h.roblox.Vector2.new(999, 999) }
    b.InputBegan:Fire(touch)
    uis().InputChanged:Fire(other)               -- a different finger -> ignored
    h.expect(calls).toBe(0)
    touch.Position = h.roblox.Vector2.new(30, 0)
    uis().InputChanged:Fire(touch)               -- the originating finger -> counted
    h.expect(calls).toBe(1); h.expect(lastdx).toBe(30)
    maid:DoCleanup()
  end)
  h.it("onEnd fires and stops further onChange", function()
    local b, maid = btn(), R.Maid.new()
    local ended, changes = false, 0
    Drag.bind(b, { onChange = function() changes = changes + 1 end, onEnd = function() ended = true end }, maid)
    b.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    uis().InputEnded:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    h.expect(ended).toBe(true)
    uis().InputChanged:Fire({ UserInputType = UIT.MouseMovement, Position = h.roblox.Vector2.new(50, 50) })
    h.expect(changes).toBe(0)
    maid:DoCleanup()
  end)
  h.it("touch: a different finger's InputEnded does not end the active drag", function()
    local b, maid = btn(), R.Maid.new()
    local changes, ended = 0, false
    Drag.bind(b, { onChange = function() changes = changes + 1 end, onEnd = function() ended = true end }, maid)
    local touch = { UserInputType = UIT.Touch, Position = h.roblox.Vector2.new(0, 0) }
    local other = { UserInputType = UIT.Touch, Position = h.roblox.Vector2.new(5, 5) }
    b.InputBegan:Fire(touch)
    uis().InputEnded:Fire(other)                 -- a different finger lifts -> must NOT end our drag
    h.expect(ended).toBe(false)
    touch.Position = h.roblox.Vector2.new(20, 0)
    uis().InputChanged:Fire(touch)               -- originating finger still drives the drag
    h.expect(changes).toBe(1)
    uis().InputEnded:Fire(touch)                 -- originating finger lifts -> ends
    h.expect(ended).toBe(true)
    maid:DoCleanup()
  end)
end)

-- A drag helper used to listen to every mouse move for the window's whole life: four of them plus
-- the slider ran on each movement event, drag or not. They listen only while a drag is held now.
h.describe("drag listens only while it is held", function()
  local function counts()
    local u = uis()
    return u.InputChanged:__count(), u.InputEnded:__count()
  end
  h.it("no global input handler until a press, and none after the release", function()
    local changed0, ended0 = counts()
    local b, maid = btn(), R.Maid.new()
    local moves = 0
    Drag.bind(b, { onChange = function() moves = moves + 1 end }, maid)
    h.expect((counts())).toBe(changed0)
    b.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    h.expect((counts())).toBe(changed0 + 1)
    uis().InputChanged:Fire({ UserInputType = UIT.MouseMovement, Position = h.roblox.Vector2.new(5, 0) })
    h.expect(moves).toBe(1)
    uis().InputEnded:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(5, 0) })
    local changed, ended = counts()
    h.expect(changed).toBe(changed0)
    h.expect(ended).toBe(ended0)
    maid:DoCleanup()
  end)
  h.it("cleanup during a drag releases the listeners", function()
    local changed0 = counts()
    local b, maid = btn(), R.Maid.new()
    Drag.bind(b, {}, maid)
    b.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    maid:DoCleanup()
    h.expect((counts())).toBe(changed0)
  end)
  h.it("a window and a slider at rest add no global input handler", function()
    local changed0, ended0 = counts()
    local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    w:AddTab({ Name = "T" }):AddSlider({ Text = "s", Min = 0, Max = 10 })
    local changed, ended = counts()
    h.expect(changed).toBe(changed0)
    h.expect(ended).toBe(ended0)
  end)
end)

h.describe("drag and focus loss", function()
  h.it("losing the window focus mid-drag ends the drag and drops the listeners", function()
    local u = uis()
    local changed0 = u.InputChanged:__count()
    local b, maid = btn(), R.Maid.new()
    local ended = 0
    Drag.bind(b, { onEnd = function() ended = ended + 1 end }, maid)
    b.InputBegan:Fire({ UserInputType = UIT.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    u.WindowFocusReleased:Fire()
    h.expect(ended).toBe(1)
    h.expect(u.InputChanged:__count()).toBe(changed0)
    maid:DoCleanup()
  end)
end)

h.run()
