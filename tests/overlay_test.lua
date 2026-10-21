local h = require("tests.helper")
local Overlay = h.loadLib().Overlay
Overlay.reset()

-- Fresh overlay root with a measured viewport (mock AbsoluteSize is nil until a test writes it).
local function rootWithViewport(w, ht)
  Overlay.reset()
  local gui = h.roblox.Instance.new("ScreenGui")
  local root = Overlay.get(gui)
  root.AbsoluteSize = h.roblox.Vector2.new(w, ht)
  return root
end

h.describe("overlay", function()
  -- Roblox caches each ScreenGui's appearance and recomputes ALL of it the frame after ANY
  -- descendant changes (Static UI Performance Improvements, devforum 222557, and the ScreenGui
  -- reference). Toasts count down, tooltips fade, dropdowns open: if they share the window's
  -- ScreenGui, every one of those frames re-renders the whole hub. Their own ScreenGui keeps the
  -- window's cache intact while they move.
  h.it("a mounted window gui gets the overlay in a sibling ScreenGui drawn just above it", function()
    Overlay.reset()
    local host = h.roblox.Instance.new("Folder")
    local gui = h.roblox.Instance.new("ScreenGui")
    gui.DisplayOrder = 50; gui.Parent = host
    local root = Overlay.get(gui)
    local layer = root.Parent
    h.expect(layer ~= gui).toBeTruthy()
    h.expect(layer.ClassName).toBe("ScreenGui")
    h.expect(layer.Parent).toBe(host)
    h.expect(layer.DisplayOrder).toBe(51)
    h.expect(layer.ResetOnSpawn).toBe(false)
    h.expect(#gui:GetChildren()).toBe(0)             -- nothing dynamic left in the window's gui
    Overlay.reset()
  end)
  h.it("reset destroys the overlay's own ScreenGui with it", function()
    Overlay.reset()
    local host = h.roblox.Instance.new("Folder")
    local gui = h.roblox.Instance.new("ScreenGui"); gui.Parent = host
    local layer = Overlay.get(gui).Parent
    Overlay.reset()
    h.expect(layer.Parent).toBe(nil)
    h.expect(Overlay.peek()).toBe(nil)
  end)
  h.it("destroying the window's gui directly takes the overlay layer with it", function()
    Overlay.reset()
    local host = h.roblox.Instance.new("Folder")
    local gui = h.roblox.Instance.new("ScreenGui"); gui.Parent = host
    local layer = Overlay.get(gui).Parent
    gui:Destroy()                                    -- a hub's own cleanup, not Window:Close()
    h.expect(layer.Parent).toBe(nil)                 -- no orphaned FAB or toast left on screen
    h.expect(Overlay.peek()).toBe(nil)
  end)
  -- The layer belongs to the window that created it. Before the split, the root lived inside
  -- that window's gui, so closing ANOTHER window could not destroy it; the layer must keep that.
  h.it("releasing from a window that does not own the layer leaves it alone", function()
    Overlay.reset()
    local host = h.roblox.Instance.new("Folder")
    local a = h.roblox.Instance.new("ScreenGui"); a.Parent = host
    local b = h.roblox.Instance.new("ScreenGui"); b.Parent = host
    local layer = Overlay.get(a).Parent
    Overlay.get(b)                                   -- B shares A's overlay
    Overlay.release(b)                               -- B closes
    h.expect(layer.Parent).toBe(host)                -- A's FAB and toasts survive
    h.expect(Overlay.peek() ~= nil).toBeTruthy()
    Overlay.release(a)                               -- the owner closes: now it goes
    h.expect(layer.Parent).toBe(nil)
  end)
  h.it("the layer is tagged for the re-execute sweep, follows the window's inset and is protected", function()
    Overlay.reset()
    local host = h.roblox.Instance.new("Folder")
    local gui = h.roblox.Instance.new("ScreenGui"); gui.IgnoreGuiInset = true; gui.Parent = host
    local protected = nil
    local layer = Overlay.get(gui, { protect = function(g) protected = g end }).Parent
    h.expect(layer:GetAttribute("__ezui")).toBe(true)  -- Mount.finalize sweeps a stale one
    h.expect(layer.IgnoreGuiInset).toBe(true)
    h.expect(protected).toBe(layer)
    Overlay.reset()
    local studio = nil
    Overlay.get(gui, { studio = true, protect = function(g) studio = g end })
    h.expect(studio).toBe(nil)                       -- Studio has no protect functions
    Overlay.reset()
  end)
  h.it("a re-execute's Mount.finalize sweeps the previous overlay layer", function()
    local R = h.loadLib()
    local host = h.roblox.Instance.new("Folder")
    local old = h.roblox.Instance.new("ScreenGui"); old.Parent = host
    R.Mount.finalize(old, {})
    local oldLayer = R.Overlay.get(old).Parent
    local fresh = h.roblox.Instance.new("ScreenGui"); fresh.Parent = host
    R.Mount.finalize(fresh, {})                      -- what a second execute does first
    h.expect(oldLayer.Parent).toBe(nil)
    h.expect(old.Parent).toBe(nil)
    R.Overlay.reset()
  end)
  h.it("a detached gui keeps the root inside it (nowhere to put a sibling)", function()
    Overlay.reset()
    local gui = h.roblox.Instance.new("ScreenGui")
    h.expect(Overlay.get(gui).Parent).toBe(gui)
    Overlay.reset()
  end)
  h.it("creates one root and reuses it", function()
    local gui = h.roblox.Instance.new("ScreenGui")
    local r1 = Overlay.get(gui)
    local r2 = Overlay.get(gui)
    h.expect(r1).toBe(r2)
    h.expect(r1.ClipsDescendants).toBe(false)
  end)
  h.it("closeAll invokes tracked popover closers once", function()
    Overlay.reset()
    local gui = h.roblox.Instance.new("ScreenGui"); Overlay.get(gui)
    local closed = 0
    local fn = function() closed = closed + 1 end
    Overlay.trackPopover(fn)
    Overlay.closeAll()
    h.expect(closed).toBe(1)
    Overlay.closeAll() -- cleared, not called again
    h.expect(closed).toBe(1)
  end)
  h.it("mount parents element to overlay root", function()
    local gui = h.roblox.Instance.new("ScreenGui")
    local root = Overlay.get(gui)
    local popup = h.roblox.Instance.new("Frame")
    Overlay.mount(popup)
    h.expect(popup.Parent).toBe(root)
  end)
end)

h.describe("overlay.Z", function()
  h.it("exposes the layer table with today's values", function()
    h.expect(Overlay.Z).toEqual({ catcher = 1000, popover = 1001, modal = 1500, fab = 1700, toast = 1800, tooltip = 2000 })
  end)
  h.it("root and click-catcher use Z.catcher", function()
    Overlay.reset()
    local gui = h.roblox.Instance.new("ScreenGui")
    local root = Overlay.get(gui)
    h.expect(root.ZIndex).toBe(Overlay.Z.catcher)
    Overlay.trackPopover(function() end) -- first tracked popover creates the catcher
    local catcher = root:FindFirstChildOfClass("ImageButton")
    h.expect(catcher ~= nil).toBeTruthy()
    h.expect(catcher.ZIndex).toBe(Overlay.Z.catcher)
    Overlay.closeAll()
  end)
end)

h.describe("overlay.placePopover", function()
  local anchorSize = { X = 200, Y = 38 }
  h.it("opens below the anchor when there is room (selectbox parity: 100+38+4)", function()
    rootWithViewport(600, 800)
    local x, y, up = Overlay.placePopover({ X = 50, Y = 100 }, anchorSize, 200, 120, 4)
    h.expect(x).toBe(50)
    h.expect(y).toBe(142)
    h.expect(up).toBe(false)
  end)
  h.it("flips upward when there is no room below but room above", function()
    rootWithViewport(600, 400)
    local x, y, up = Overlay.placePopover({ X = 50, Y = 380 }, anchorSize, 200, 100, 4)
    h.expect(x).toBe(50)
    h.expect(y).toBe(276) -- 380 - 4 - 100
    h.expect(up).toBe(true)
  end)
  h.it("stays below when there is no room above either", function()
    rootWithViewport(600, 400)
    local _, y, up = Overlay.placePopover({ X = 50, Y = 50 }, anchorSize, 200, 380, 4)
    h.expect(y).toBe(92) -- 50 + 38 + 4, overflow tolerated rather than a negative y
    h.expect(up).toBe(false)
  end)
  h.it("clamps x to the right edge minus gap", function()
    rootWithViewport(600, 800)
    local x = Overlay.placePopover({ X = 550, Y = 100 }, anchorSize, 200, 100, 4)
    h.expect(x).toBe(396) -- 600 - 200 - 4
  end)
  h.it("clamps x to zero on the left", function()
    rootWithViewport(600, 800)
    local x = Overlay.placePopover({ X = -30, Y = 100 }, anchorSize, 200, 100, 4)
    h.expect(x).toBe(0)
  end)
  h.it("defaults the gap to today's 4px and tolerates nil anchor tables", function()
    rootWithViewport(600, 800)
    local _, y = Overlay.placePopover({ X = 50, Y = 100 }, anchorSize, 200, 120)
    h.expect(y).toBe(142)
    local x2, y2, up2 = Overlay.placePopover(nil, nil, 200, 120)
    h.expect(x2).toBe(0); h.expect(y2).toBe(4); h.expect(up2).toBe(false)
  end)
  h.it("uses the 1920x1080 viewport fallback when the root is unmeasured", function()
    Overlay.reset()
    local x, y, up = Overlay.placePopover({ X = 1800, Y = 1000 }, anchorSize, 200, 200, 4)
    h.expect(x).toBe(1716) -- 1920 - 200 - 4
    h.expect(y).toBe(796)  -- 1000 - 4 - 200 (flipped: 1042 + 200 > 1080)
    h.expect(up).toBe(true)
  end)
  h.it("honours the scaled size the caller passes (2.22: w*scale, h*scale)", function()
    rootWithViewport(600, 400)
    local scale = 1.3
    local _, y, up = Overlay.placePopover({ X = 50, Y = 300 }, anchorSize, 200 * scale, 60 * scale, 4)
    h.expect(up).toBe(true)
    h.expect(y).toBeCloseTo(300 - 4 - 60 * scale)
  end)
end)

h.describe("overlay.scale", function()
  h.it("defaults to 1", function()
    Overlay.reset()
    h.expect(Overlay.scale()).toBe(1)
  end)
  h.it("setScale is process-wide, last writer wins", function()
    Overlay.reset()
    h.expect(Overlay.setScale(1.3)).toBe(1.3)
    h.expect(Overlay.scale()).toBe(1.3)
    Overlay.setScale(0.8)
    h.expect(Overlay.scale()).toBe(0.8)
  end)
  h.it("never attaches a UIScale to the overlay root", function()
    Overlay.reset()
    local gui = h.roblox.Instance.new("ScreenGui")
    local root = Overlay.get(gui)
    Overlay.setScale(1.5)
    h.expect(root:FindFirstChildOfClass("UIScale")).toBeNil()
    h.expect(#root:GetChildren()).toBe(0)
  end)
  h.it("rejects non-positive or non-number values", function()
    Overlay.reset()
    Overlay.setScale(1.2)
    h.expect(function() Overlay.setScale(0) end).toThrow("positive number")
    h.expect(function() Overlay.setScale(-1) end).toThrow("positive number")
    h.expect(function() Overlay.setScale("1.3") end).toThrow("positive number")
    h.expect(function() Overlay.setScale(nil) end).toThrow("positive number")
    h.expect(function() Overlay.setScale(0 / 0) end).toThrow("positive number")
    h.expect(Overlay.scale()).toBe(1.2) -- a rejected write leaves the previous value intact
  end)
  h.it("reset restores the default scale", function()
    Overlay.setScale(2)
    Overlay.reset()
    h.expect(Overlay.scale()).toBe(1)
  end)
end)

h.describe("overlay.dialogDepth", function()
  h.it("starts at 0 and push/pop return the new depth", function()
    Overlay.reset()
    h.expect(Overlay.dialogDepth()).toBe(0)
    h.expect(Overlay.pushDialog()).toBe(1)
    h.expect(Overlay.pushDialog()).toBe(2)
    h.expect(Overlay.dialogDepth()).toBe(2)
    h.expect(Overlay.popDialog()).toBe(1)
    h.expect(Overlay.popDialog()).toBe(0)
    h.expect(Overlay.dialogDepth()).toBe(0)
  end)
  h.it("never goes below 0 on unbalanced pops", function()
    Overlay.reset()
    h.expect(Overlay.popDialog()).toBe(0)
    h.expect(Overlay.popDialog()).toBe(0)
    h.expect(Overlay.dialogDepth()).toBe(0)
    Overlay.pushDialog()
    h.expect(Overlay.dialogDepth()).toBe(1)
  end)
  h.it("reset clears the depth", function()
    Overlay.pushDialog(); Overlay.pushDialog()
    Overlay.reset()
    h.expect(Overlay.dialogDepth()).toBe(0)
  end)
end)

h.run()
