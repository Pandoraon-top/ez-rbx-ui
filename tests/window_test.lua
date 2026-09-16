local h = require("tests.helper")
local Window = h.loadLib().Window

local function newWin()
  local screen = h.roblox.Instance.new("ScreenGui")
  return Window.new({ Title = "My Hub", Parent = screen })
end

h.describe("window", function()
  h.it("builds a gui with a content scroll (CanvasSize driven explicitly per tab)", function()
    local w = newWin()
    h.expect(w.Gui ~= nil).toBeTruthy()
    h.expect(w.ContentScroll.AutomaticCanvasSize.Name).toBe("None")
  end)
  h.it("first AddTab is auto-selected", function()
    local w = newWin()
    local t1 = w:AddTab({ Name = "Home", Icon = "home" })
    h.expect(t1:IsSelected()).toBe(true)
  end)
  h.it("selecting a second tab deselects the first", function()
    local w = newWin()
    local t1 = w:AddTab({ Name = "A" })
    local t2 = w:AddTab({ Name = "B" })
    h.expect(t1:IsSelected()).toBe(true)
    h.expect(t2:IsSelected()).toBe(false)
    t2.Button.MouseButton1Click:Fire()
    h.expect(t1:IsSelected()).toBe(false)
    h.expect(t2:IsSelected()).toBe(true)
  end)
  h.it("Hide/Show/Toggle flips visibility", function()
    local w = newWin()
    h.expect(w:IsVisible()).toBe(true)
    w:Hide(); h.expect(w:IsVisible()).toBe(false)
    w:Toggle(); h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("FAB is the reopen button: hidden when shown, appears on hide, no shadow, tap restores", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true,
      Theme = R.Theme.new({ Effect = { shadowId = "" } }) })   -- no asset: the depth layers are skipped
    local function findFab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    local fab = findFab()
    h.expect(fab ~= nil).toBeTruthy()
    h.expect(fab.Visible).toBe(false)
    h.expect(fab:GetAttribute("FabType")).toBe("simple")
    h.expect(fab:FindFirstChild("Chevron") ~= nil).toBeTruthy()
    -- This window was built with the shadow-off theme below, so the FAB shadow layer is never
    -- built. The name has to be the one the code actually uses ("FabShadow"): a stale name would
    -- pass no matter what the code does.
    local shadow; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FabShadow" then shadow = c end end
    h.expect(shadow).toBe(nil)
    w:Hide()
    h.expect(findFab().Visible).toBe(true)
    w:Show()
    h.expect(findFab().Visible).toBe(false)
    w:Minimize()
    h.expect(findFab().Visible).toBe(true)
    findFab().MouseButton1Click:Fire()
    h.expect(w:IsVisible()).toBe(true)
  end)
  -- Drag a revealed FAB to mid-screen, release, and report its resting X offset.
  local function dragReleaseFabX(fabType)
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = fabType } })
    R.Overlay.get(screen).AbsoluteSize = h.roblox.Vector2.new(1280, 720)
    w:Minimize() -- reveal the FAB and wire its drag handlers
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local UIS = h.roblox.game:GetService("UserInputService")
    local MB1 = h.roblox.Enum.UserInputType.MouseButton1
    fab.InputBegan:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(0, 0) })
    fab.Position = h.roblox.UDim2.new(0, 700, 0.5, -25) -- dropped near the middle, right of center
    UIS.InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(700, 0) })
    return fab.Position.X.Offset
  end
  h.it("circle/square FAB has no magnet: it stays where it is dropped", function()
    h.expect(dragReleaseFabX("circle")).toBe(700)
    h.expect(dragReleaseFabX("square")).toBe(700)
  end)
  h.it("simple FAB still magnets to the nearest edge on release", function()
    local x = dragReleaseFabX("simple")
    h.expect(x ~= 700).toBeTruthy()        -- it moved off the drop point
    h.expect(x).toBe(1280 - 50 + 15)       -- docked at the right edge, peeking 15px
  end)
  h.it("minimize hides the whole window and a floating toggle restores it", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    w:Minimize()
    h.expect(w.Main.Visible).toBe(false)
    h.expect(w:IsVisible()).toBe(false)
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab ~= nil).toBeTruthy()
    fab.MouseButton1Click:Fire()
    h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("has a resize grip", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    h.expect(w.Main:FindFirstChild("ResizeGrip") ~= nil).toBeTruthy()
  end)
  h.it("Close does a graceful full shutdown", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local fired = {}
    local w = R.Window.new({ Title = "C", Parent = screen, Config = { FileName = "CL", AutoSave = false },
      OnClose = function() fired.onClose = true end })
    w:SetCloseCallback(function() fired.cb = true end)
    local gui = w.Gui
    w:Close()
    h.expect(fired.onClose).toBeTruthy()
    h.expect(fired.cb).toBeTruthy()
    h.expect(gui._destroyed).toBeTruthy()  -- gui torn down
    w:AddTab({ Name = "X" })                -- no-op after close, must not error
    h.expect(w:IsVisible()).toBe(false)
  end)
  h.it("SaveConfiguration / LoadConfiguration delegate to the config object", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, Config = { FileName = "WCfg", AutoSave = false } })
    local tab = w:AddTab({ Name = "T" })
    tab:AddToggle({ Text = "x", Flag = "x", Default = true })
    h.expect(w:SaveConfiguration()).toBeTruthy()
    h.expect(type(w:LoadConfiguration())).toBe("boolean")
  end)
  h.it("light mode re-skins the acrylic gradient + stroke to light tokens", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    w:SetMode("light")
    local grad = w.Main:FindFirstChildOfClass("UIGradient")
    local stroke = w.Main:FindFirstChildOfClass("UIStroke")
    h.expect(grad.Color.color[1].Value).toBe(R.Theme.PALETTES.light.card)  -- gradient top now card (chrome darker)
    h.expect(stroke.Color).toBe(R.Theme.PALETTES.light.border)
  end)
  h.it("sidebar handle resizes the sidebar width", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local handle = body:FindFirstChild("SidebarHandle")
    h.expect(handle ~= nil).toBeTruthy()
    local sidebar = body:FindFirstChild("Sidebar")
    local w0 = sidebar.Size.X.Offset
    body.AbsolutePosition = h.roblox.Vector2.new(0, 0)
    handle.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(w0, 50) })
    local uis = h.roblox.game:GetService("UserInputService")
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(w0 + 40, 50) })
    h.expect(sidebar.Size.X.Offset > w0).toBeTruthy()
  end)
  h.it("sidebar handle resizes via touch and is finger-sized on touch", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local handle = body:FindFirstChild("SidebarHandle")
    local sidebar = body:FindFirstChild("Sidebar")
    h.expect(handle.Size.X.Offset >= 44).toBeTruthy()
    local w0 = sidebar.Size.X.Offset
    body.AbsolutePosition = h.roblox.Vector2.new(0, 0)
    local touch = { UserInputType = h.roblox.Enum.UserInputType.Touch, Position = h.roblox.Vector2.new(w0, 50) }
    handle.InputBegan:Fire(touch)
    touch.Position = h.roblox.Vector2.new(w0 + 40, 50)
    uis.InputChanged:Fire(touch)
    h.expect(sidebar.Size.X.Offset > w0).toBeTruthy()
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)
  h.it("settings APIs: notifications gate, UI scale, acrylic transparency, toggle key", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    R.Notification.clearAll()
    w:SetNotificationsEnabled(false)
    h.expect(w:Notify({ Title = "x", Duration = 0 })).toBe(nil)
    h.expect(R.Notification.count()).toBe(0)
    w:SetNotificationsEnabled(true)
    w:SetUIScale(1.2)
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    h.expect(sc ~= nil).toBeTruthy(); h.expect(sc.Scale).toBe(1.2)
    w:SetTransparency(0.5)
    h.expect(w.Main.BackgroundTransparency).toBe(0.5)
    h.expect(w:SetToggleKey(h.roblox.Enum.KeyCode.K)).toBe(h.roblox.Enum.KeyCode.K)
  end)
  h.it("closes an open popover when switching tabs", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); local ov = R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local t1 = w:AddTab({ Name = "One" }); local t2 = w:AddTab({ Name = "Two" })
    local sb = t1:AddSelectBox({ Text = "S", Options = { "a", "b" } })
    sb.Open()
    local hasDrop = false; for _, c in ipairs(ov:GetChildren()) do if c.Name == "SelectDropdown" then hasDrop = true end end
    h.expect(hasDrop).toBe(true)
    t2.Button.MouseButton1Click:Fire()
    local stillOpen = false; for _, c in ipairs(ov:GetChildren()) do if c.Name == "SelectDropdown" then stillOpen = true end end
    h.expect(stillOpen).toBe(false)
  end)
  h.it("floating toggle honors Size and Position overrides", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "circle" } })
    w:SetFloatingToggle({ Type = "circle", Size = h.roblox.UDim2.new(0, 150, 0, 40), Position = h.roblox.UDim2.new(0, 30, 1, -80) })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab.Size.X.Offset).toBe(150)
    h.expect(fab.Size.Y.Offset).toBe(40)
    h.expect(fab.Position.X.Offset).toBe(30)
    h.expect(fab.Position.Y.Offset).toBe(-80)
  end)
  h.it("simple floating toggle docks at the left edge (magnet)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab.Position.X.Offset).toBe(-15)
    h.expect(fab.Position.Y.Scale).toBe(0.5)
  end)
  h.it("FAB chevron + title-bar icons are accent and follow the mode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab:FindFirstChild("Chevron").ImageColor3.R8).toBe(250)
    local close = w.Main:FindFirstChild("TitleBar"):FindFirstChild("Close")
    h.expect(close.ImageColor3.R8).toBe(R.Theme.Colors.mutedForeground.R8)  -- topbar icons rest neutral now
    w:SetMode("light")
    h.expect(fab:FindFirstChild("Chevron").ImageColor3).toBe(R.Theme.PALETTES.light.primary)
    h.expect(close.ImageColor3).toBe(R.Theme.PALETTES.light.mutedForeground)
  end)
  h.it("magnet snaps to the correct edge using logical position (slow-drag safe)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui")
    local ov = R.Overlay.get(screen); ov.AbsoluteSize = h.roblox.Vector2.new(600, 400)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local fab; for _, c in ipairs(ov:GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local uis = h.roblox.game:GetService("UserInputService")
    fab.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(400, 0) })
    uis.InputEnded:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(400, 0) })
    h.expect(fab.Position.X.Offset > 300).toBeTruthy()
    fab.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(-500, 0) })
    uis.InputEnded:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(-500, 0) })
    h.expect(fab.Position.X.Offset).toBe(-15)
  end)
  h.it("magnet still snaps when the click handler fires before InputEnded (slow-drag race)", function()
    -- On a slow drag the cursor stays over the FAB, so MouseButton1Click fires (clearing the
    -- click-vs-drag flag) BEFORE the global InputEnded. The release must still magnet to the
    -- nearest edge from the knob's current position, regardless of that ordering.
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui")
    local ov = R.Overlay.get(screen); ov.AbsoluteSize = h.roblox.Vector2.new(600, 400)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local fab; for _, c in ipairs(ov:GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local uis = h.roblox.game:GetService("UserInputService")
    fab.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(0, 0) })
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(400, 0) })
    fab.MouseButton1Click:Fire()  -- click races ahead of InputEnded
    uis.InputEnded:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(400, 0) })
    h.expect(fab.Position.X.Offset).toBe(565)  -- docked at the right edge (vp.X - w + peek), not left of drag
    h.expect(w:IsVisible()).toBe(true)         -- the 400px drag was NOT a tap: the click must not toggle
  end)
  h.it("simple FAB uses a neutral surface color that follows the mode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    -- compare by value: the window deep-copies its theme (distinct Color3 identity from the module)
    h.expect(fab.BackgroundColor3.R8).toBe(R.Theme.PALETTES.dark.surface.R8)        -- 39 (not white primary)
    h.expect(fab:FindFirstChild("Chevron").ImageColor3.R8).toBe(R.Theme.PALETTES.dark.foreground.R8) -- 250
    w:SetMode("light")
    h.expect(fab.BackgroundColor3.R8).toBe(R.Theme.PALETTES.light.surface.R8)        -- 244 (follows mode)
  end)
  h.it("square floating toggle renders the given image and SetFloatingToggle swaps type", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = "rbxassetid://123", Draggable = false } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local img = fab:FindFirstChildOfClass("ImageLabel")
    h.expect(img.Image).toBe("rbxassetid://123")
    w:SetFloatingToggle({ Type = "simple" })
    local fab2; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab2 = c end end
    h.expect(fab2:GetAttribute("FabType")).toBe("simple")
    w:Minimize()
    fab2.MouseButton1Click:Fire()
    h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("the square floating toggle has no border stroke", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "square", Image = "rbxassetid://9" } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab:FindFirstChildOfClass("UIStroke")).toBe(nil)
  end)
  h.it("a configured logo fills the FAB edge-to-edge (no background frame)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "square", Image = "rbxassetid://7" } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local img = fab:FindFirstChild("Img")
    h.expect(img.Size.X.Scale).toBe(1); h.expect(img.Size.X.Offset).toBe(0)  -- fills, no inset frame
    h.expect(img.Size.Y.Scale).toBe(1); h.expect(img.Size.Y.Offset).toBe(0)
    h.expect(img.Position.X.Offset).toBe(0); h.expect(img.Position.Y.Offset).toBe(0)
    h.expect(img.Image).toBe("rbxassetid://7")
  end)
  h.it("GetFloatingToggleType reflects the configured/current type", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "square", Image = "rbxassetid://1" } })
    h.expect(w:GetFloatingToggleType()).toBe("square")
    w:SetFloatingToggle({ Type = "circle" })
    h.expect(w:GetFloatingToggleType()).toBe("circle")
    local w2 = R.Window.new({ Title = "M2", Parent = h.roblox.Instance.new("ScreenGui"), FloatingToggle = true })
    h.expect(w2:GetFloatingToggleType()).toBe("simple")     -- default when no Type given
  end)
  h.it("SetFloatingToggle merges over existing options: changing Type keeps the Image", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = "rbxassetid://123" } })
    w:SetFloatingToggle({ Type = "circle" })       -- only the type changes; the logo must survive
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab:GetAttribute("FabType")).toBe("circle")
    h.expect(fab:FindFirstChild("Img").Image).toBe("rbxassetid://123")
  end)
  h.it("SetAccent(Color3) picks a readable foreground by luminance", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" }); local b = tab:AddButton({ Text = "Go" })
    w:SetAccent(h.roblox.Color3.fromRGB(255, 255, 255))
    h.expect(b.Frame:FindFirstChild("Surface"):FindFirstChild("Label").TextColor3.R8).toBe(24)
    w:SetAccent(h.roblox.Color3.fromRGB(20, 20, 20))
    h.expect(b.Frame:FindFirstChild("Surface"):FindFirstChild("Label").TextColor3.R8).toBe(250)
  end)
  h.it("SetAccent accepts a preset name (used by the Settings accent selector)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local b = tab:AddButton({ Text = "Go" })
    w:SetAccent("Emerald")
    h.expect(b.Frame:FindFirstChild("Surface").BackgroundColor3).toBe(R.Themer.accent("Emerald").Primary)
  end)
  h.it("topbar tag recolors on SetMode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tag = w:Tag({ Text = "Beta" })
    w:SetMode("light")
    local tb = w.Main:FindFirstChild("TitleBar")
    local pill; for _, c in ipairs(tb:GetChildren()) do if c.Name == "Tag" then pill = c end end
    h.expect(pill.BackgroundColor3).toBe(R.Theme.PALETTES.light.surface)
    h.expect(pill:FindFirstChild("TagText").TextColor3).toBe(R.Theme.PALETTES.light.foreground)
  end)
  h.it("Window:Tag adds a topbar pill that can be removed", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tag = w:Tag({ Text = "Beta" })
    local tb = w.Main:FindFirstChild("TitleBar")
    local pill; for _, c in ipairs(tb:GetChildren()) do if c.Name == "Tag" then pill = c end end
    h.expect(pill ~= nil).toBeTruthy()
    h.expect(pill:FindFirstChild("TagText").Text).toBe("Beta")
    tag.Destroy()
    local gone = true; for _, c in ipairs(tb:GetChildren()) do if c.Name == "Tag" then gone = false end end
    h.expect(gone).toBe(true)
  end)
  h.it("resize grip shows a visible grip icon", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local grip = w.Main:FindFirstChild("ResizeGrip")
    h.expect(tostring(grip.Image):sub(1, 13)).toBe("rbxassetid://")
  end)
  h.it("touch resize grip shrinks the window (and the size persists)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen })
    local w0, h0 = w.Main.Size.X.Offset, w.Main.Size.Y.Offset   -- 576 x 432 at 1280x720
    local hit = w.Main:FindFirstChild("ResizeHit")
    h.expect(hit ~= nil).toBeTruthy()
    local touch = { UserInputType = h.roblox.Enum.UserInputType.Touch, Position = h.roblox.Vector2.new(700, 500) }
    hit.InputBegan:Fire(touch)
    touch.Position = h.roblox.Vector2.new(600, 400)             -- drag up-left to shrink
    uis.InputChanged:Fire(touch)
    h.expect(w.Main.Size.X.Offset < w0).toBeTruthy()
    h.expect(w.Main.Size.Y.Offset < h0).toBeTruthy()
    local shrunkW = w.Main.Size.X.Offset
    w:AdaptToViewport()                                          -- mid-state refit must NOT re-inflate
    h.expect(w.Main.Size.X.Offset).toBe(shrunkW)
    uis.InputEnded:Fire(touch)
    w:AdaptToViewport()                                          -- after release: manual size preserved
    h.expect(w.Main.Size.X.Offset).toBe(shrunkW)
    uis.TouchEnabled = false; uis.MouseEnabled = true            -- restore baseline for later tests
  end)
  h.it("resize hit target is finger-sized on touch", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen })
    local hit = w.Main:FindFirstChild("ResizeHit")
    h.expect(hit.Size.X.Offset >= 44).toBeTruthy()
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)
  h.it("ToggleKey input toggles visibility", function()
    local w = newWin()
    local uis = h.roblox.game:GetService("UserInputService")
    uis.InputBegan:Fire({ KeyCode = h.roblox.Enum.KeyCode.RightControl }, false)
    h.expect(w:IsVisible()).toBe(false)
  end)
  h.it("ToggleKey ignores presses while another control consumed the input (gameProcessed)", function()
    local w = newWin()
    local uis = h.roblox.game:GetService("UserInputService")
    uis.InputBegan:Fire({ KeyCode = h.roblox.Enum.KeyCode.RightControl }, true)
    h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("a rebind keybind drives SetToggleKey without becoming a second toggler (no blink)", function()
    local R = h.loadLib()
    local screen = h.roblox.Instance.new("ScreenGui")
    local w = R.Window.new({ Title = "M", Parent = screen, ToggleKey = h.roblox.Enum.KeyCode.RightControl })
    -- mirrors the settings example: the keybind REBINDS the toggle key, it does not toggle
    R.Keybind.new({ Parent = R.Create("Frame", {}), Text = "Toggle UI key",
      Default = h.roblox.Enum.KeyCode.RightControl,
      OnChanged = function(key) w:SetToggleKey(key) end })
    local uis = h.roblox.game:GetService("UserInputService")
    -- one press of the bound key toggles exactly once (hide), not hide+show
    uis.InputBegan:Fire({ KeyCode = h.roblox.Enum.KeyCode.RightControl, UserInputType = h.roblox.Enum.UserInputType.Keyboard }, false)
    h.expect(w:IsVisible()).toBe(false)
    -- rebinding to LeftAlt repoints the window's single handler; LeftAlt now toggles it back
    w:SetToggleKey(h.roblox.Enum.KeyCode.LeftAlt)
    uis.InputBegan:Fire({ KeyCode = h.roblox.Enum.KeyCode.LeftAlt, UserInputType = h.roblox.Enum.UserInputType.Keyboard }, false)
    h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("flat chrome: darker base, rounded card content panel, no separators", function()
    local R = h.loadLib()
    local w = newWin()
    h.expect(w.Main:FindFirstChild("HeaderSeparator")).toBe(nil)
    h.expect(w.Main:FindFirstChild("HeaderShadow")).toBe(nil)
    h.expect(w.Main.BackgroundColor3.R8).toBe(R.Theme.Colors.background.R8)
    local body = w.Main:FindFirstChild("Body")
    local panel = body:FindFirstChild("ContentPanel")
    h.expect(panel ~= nil).toBeTruthy()
    h.expect(panel.BackgroundColor3.R8).toBe(R.Theme.Colors.card.R8)
    h.expect(w.ContentScroll.Parent.Name).toBe("ContentPanel")
  end)
  h.it("close button asks for confirmation by default; ConfirmClose=false closes immediately", function()
    local R = h.loadLib()
    local screen = h.roblox.Instance.new("ScreenGui"); local ov = R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local close = w.Main:FindFirstChild("TitleBar"):FindFirstChild("Close")
    close.MouseButton1Click:Fire()
    h.expect(w.Main:FindFirstChild("Dialog") ~= nil).toBeTruthy()  -- window dialog scrim scoped to the window
    h.expect(w:IsVisible()).toBe(true)
    local screen2 = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen2)
    local w2 = R.Window.new({ Title = "M2", Parent = screen2, ConfirmClose = false })
    w2.Main:FindFirstChild("TitleBar"):FindFirstChild("Close").MouseButton1Click:Fire()
    h.expect(w2:IsVisible()).toBe(false)
  end)
  h.it("content scroll uses explicit CanvasSize driven by the active tab", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    tab:AddParagraph("hello"); tab:AddButton({ Text = "Go" })
    tab:Select()
    h.expect(w.ContentScroll.AutomaticCanvasSize.Name).toBe("None")
    h.expect(w.ContentScroll.CanvasSize.Y.Offset).toBe(2 * R.Theme.Spacing.pad)
  end)
  h.it("topbar minimize/close icons rest neutral and colour on hover", function()
    local R = h.loadLib()
    local w = newWin()
    local bar = w.Main:FindFirstChild("TitleBar")
    local close = bar:FindFirstChild("Close")
    local mn = bar:FindFirstChild("Minimize")
    h.expect(close.ImageColor3.R8).toBe(R.Theme.Colors.mutedForeground.R8)
    close.MouseEnter:Fire(); h.expect(close.ImageColor3.R8).toBe(R.Theme.Colors.destructive.R8)
    close.MouseLeave:Fire(); h.expect(close.ImageColor3.R8).toBe(R.Theme.Colors.mutedForeground.R8)
    mn.MouseEnter:Fire(); h.expect(mn.ImageColor3.R8).toBe(R.Theme.Colors.primary.R8)
    mn.MouseLeave:Fire(); h.expect(mn.ImageColor3.R8).toBe(R.Theme.Colors.mutedForeground.R8)
  end)
  h.it("Transparency sets the window background and keeps the frosted stack", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, Transparency = 0.3 })
    h.expect(w.Main.BackgroundTransparency).toBe(0.3)
    h.expect(w.Main:FindFirstChild("AcrylicNoise") ~= nil).toBeTruthy()  -- frosted always on
    h.expect(w:SetTransparency(0.5)).toBe(0.5)
    h.expect(w.Main.BackgroundTransparency).toBe(0.5)
  end)
  h.it("Ratio is screen fractions: { Width, Height } sizes the window as a % of the viewport", function()
    -- headless viewport falls back to 1280x720
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, Ratio = { Width = 0.4, Height = 0.55 } })
    h.expect(w.Main.Size.X.Offset).toBe(math.floor(1280 * 0.4))   -- 512
    h.expect(w.Main.Size.Y.Offset).toBe(math.floor(720 * 0.55))   -- 396
  end)
  h.it("default Ratio (~45% x 60% of the viewport) when none is given", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local def = R.Window.new({ Title = "M", Parent = screen })
    h.expect(def.Main.Size.X.Offset).toBe(math.floor(1280 * 0.45))  -- 576
    h.expect(def.Main.Size.Y.Offset).toBe(math.floor(720 * 0.6))    -- 432
  end)
  h.it("Ratio as a single number applies the same fraction to both axes", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, Ratio = 0.5 })
    h.expect(w.Main.Size.X.Offset).toBe(math.floor(1280 * 0.5))   -- 640
    h.expect(w.Main.Size.Y.Offset).toBe(math.floor(720 * 0.5))    -- 360
  end)
  h.it("StartHidden starts the window hidden with only the floating toggle showing", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, StartHidden = true, FloatingToggle = { Type = "simple" } })
    h.expect(w:IsVisible()).toBe(false)
    h.expect(w.Main.Visible).toBe(false)
    local function findFab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    h.expect(findFab() ~= nil).toBeTruthy()
    h.expect(findFab().Visible).toBe(true)        -- FAB shown so the user can open the window
    findFab().MouseButton1Click:Fire()
    h.expect(w:IsVisible()).toBe(true)            -- tapping the FAB opens it
  end)
  h.it("Subtitle + Image build a taller (56px) title bar with both slots", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Subtitle = "v3.0", Image = "rbxassetid://42", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    h.expect(bar.Size.Y.Offset).toBe(56)
    h.expect(bar:FindFirstChild("TitleImage").Image).toBe("rbxassetid://42")
    h.expect(bar:FindFirstChild("Subtitle").Text).toBe("v3.0")
    w:SetSubtitle("v3.1")
    h.expect(bar:FindFirstChild("Subtitle").Text).toBe("v3.1")
  end)
  h.it("plain title keeps the 40px bar with no subtitle/image slots", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    h.expect(bar.Size.Y.Offset).toBe(40)
    h.expect(bar:FindFirstChild("Subtitle")).toBe(nil)
    h.expect(bar:FindFirstChild("TitleImage")).toBe(nil)
  end)
  h.it("FloatingToggle AutoHide=false keeps the FAB visible while the window is shown", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { AutoHide = false } })
    local function findFab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    h.expect(findFab().Visible).toBe(true)           -- visible even though the window is shown
    w:Hide()
    h.expect(findFab().Visible).toBe(true)
    findFab().MouseButton1Click:Fire()               -- toggles back open
    h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("FloatingToggle=false disables the FAB entirely", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = false })
    local function findFab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    h.expect(findFab()).toBe(nil)
    w:Hide()                                          -- must not create/restore a FAB
    h.expect(findFab()).toBe(nil)
    h.expect(w:IsVisible()).toBe(false)
  end)
  h.it("AdaptToViewport keeps a user-moved window's position but re-centers an untouched one", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    local uis = h.roblox.game:GetService("UserInputService")
    bar.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(100, 10) })
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(140, 30) })
    bar.InputEnded:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(140, 30) })
    w:AdaptToViewport()
    h.expect(w.Main.Position.X.Scale).toBe(0)   -- user-moved: clamped pure-offset position, not re-centered
    h.expect(w.Main.Position.Y.Scale).toBe(0)
    local w2 = R.Window.new({ Title = "M", Parent = screen })
    w2:AdaptToViewport()
    h.expect(w2.Main.Position.X.Scale).toBe(0.5) -- untouched window still re-centers
  end)
  h.it("title bar drags the window on touch", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    local x0 = w.Main.Position.X.Offset
    local touch = { UserInputType = h.roblox.Enum.UserInputType.Touch, Position = h.roblox.Vector2.new(100, 10) }
    bar.InputBegan:Fire(touch)
    touch.Position = h.roblox.Vector2.new(160, 10)   -- drag right by 60
    uis.InputChanged:Fire(touch)
    h.expect(w.Main.Position.X.Offset).toBe(x0 + 60)
    uis.InputEnded:Fire(touch)
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)
  h.it("SetImage updates the title-bar image", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Image = "rbxassetid://42", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    w:SetImage("rbxassetid://99")
    h.expect(bar:FindFirstChild("TitleImage").Image).toBe("rbxassetid://99")
  end)
  h.it("FloatingToggle simple Position docks as a tab (default MidLeft, MidRight on the right)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local function lastFab() local r; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then r = c end end return r end
    R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "simple" } })
    local def = lastFab()
    h.expect(def.Position.X.Offset).toBe(-15); h.expect(def.Position.Y.Scale).toBe(0.5)  -- default MidLeft tab
    R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "simple", Position = "MidRight" } })
    local mr = lastFab()
    h.expect(mr.Position.X.Scale).toBe(1); h.expect(mr.Position.Y.Scale).toBe(0.5)        -- right-edge tab
  end)
  h.it("FloatingToggle circle Position anchors fully visible (default TopLeft, BottomRight)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local function lastFab() local r; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then r = c end end return r end
    R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "circle" } })
    local def = lastFab()
    h.expect(def.Position.X.Scale).toBe(0); h.expect(def.Position.X.Offset).toBe(16)       -- default TopLeft, fully visible
    h.expect(def.Position.Y.Scale).toBe(0); h.expect(def.Position.Y.Offset).toBe(16)
    R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "circle", Position = "BottomRight" } })
    local br = lastFab()
    h.expect(br.Position.X.Scale).toBe(1); h.expect(br.Position.X.Offset).toBe(-60)        -- 44 + 16 margin
    h.expect(br.Position.Y.Scale).toBe(1); h.expect(br.Position.Y.Offset).toBe(-60)
  end)
  h.it("entrance leaves the window at full scale and target transparency; Close fades then tears down", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local fired = {}
    local w = R.Window.new({ Title = "C", Parent = screen, Transparency = 0.2, OnClose = function() fired.c = true end })
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    h.expect(sc.Scale).toBe(1)                       -- entrance settled to full scale
    h.expect(w.Main.BackgroundTransparency).toBe(0.2) -- faded to the configured transparency
    w:SetUIScale(1.5)
    h.expect(w.Main:FindFirstChildOfClass("UIScale").Scale).toBe(1.5) -- still one shared UIScale
    local gui = w.Gui
    w:Close()
    h.expect(fired.c).toBeTruthy()
    h.expect(gui._destroyed).toBeTruthy()            -- destroyed AFTER the close tween completes
  end)
  h.it("a single sliding active indicator lives in the body and shows on the selected tab", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local function indicator() return body:FindFirstChild("ActiveIndicator") end
    h.expect(indicator() ~= nil).toBeTruthy()
    local t1 = w:AddTab({ Name = "A" })
    h.expect(indicator().Visible).toBe(true)   -- first tab auto-selected
    local t2 = w:AddTab({ Name = "B" })
    t2.Button.MouseButton1Click:Fire()
    h.expect(indicator().Visible).toBe(true)
  end)
  h.it("active indicator re-anchors on sidebar scroll and resize (stays glued, no error)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local sidebar = body:FindFirstChild("Sidebar")
    w:AddTab({ Name = "A" })                      -- auto-selected, indicator shown
    local ind = body:FindFirstChild("ActiveIndicator")
    h.expect(ind.Visible).toBe(true)
    -- scrolling the nav list / resizing fires these; the window must reanchor the indicator
    sidebar:GetPropertyChangedSignal("CanvasPosition"):Fire()
    sidebar:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    body:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    h.expect(ind.Visible).toBe(true)
  end)
  h.it("the navigation sidebar exposes a visible, themed scroll indicator", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local sidebar = w.Main:FindFirstChild("Body"):FindFirstChild("Sidebar")
    h.expect(sidebar.ScrollBarThickness > 0).toBeTruthy()                 -- was 0 (invisible)
    h.expect(sidebar.ScrollBarImageColor3.R8).toBe(R.Theme.Colors.border.R8)
  end)
  h.it("FAB pops in on hide (scale 1) and hover/press scale it", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local function fab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    w:Hide()
    local f = fab()
    local sc = f:FindFirstChildOfClass("UIScale")
    h.expect(f.Visible).toBe(true)
    h.expect(sc.Scale).toBe(1)
    f.MouseEnter:Fire(); h.expect(sc.Scale).toBe(1.06)
    f.MouseButton1Down:Fire(); h.expect(sc.Scale).toBe(0.92)
    f.MouseButton1Up:Fire(); h.expect(sc.Scale).toBe(1.06)
    f.MouseLeave:Fire(); h.expect(sc.Scale).toBe(1)
    w:Show(); h.expect(fab().Visible).toBe(false)
  end)
  -- Runs BEFORE any explicit Animations/SetAnimationsEnabled in this file: the explicit latch is
  -- process-wide and, once set, applyDefault never writes again.
  h.it("OS reduce-motion is the default when no Animations config was given (not an explicit choice)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local guiService = h.roblox.game:GetService("GuiService")
    h.expect(R.Animate.isExplicit()).toBe(false)
    guiService.ReducedMotionEnabled = true
    R.Window.new({ Title = "M", Parent = screen })
    h.expect(R.Animate.isEnabled()).toBe(false)     -- OS preference applied
    h.expect(R.Animate.isExplicit()).toBe(false)    -- ...but only as a default
    guiService.ReducedMotionEnabled = false
    R.Window.new({ Title = "M2", Parent = screen })
    h.expect(R.Animate.isEnabled()).toBe(true)      -- default follows the OS flag while nobody chose
  end)
  h.it("Animations=false flips the Animate choke point off; SetAnimationsEnabled toggles it", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    R.Window.new({ Title = "M", Parent = screen, Animations = false })
    h.expect(R.Animate.isEnabled()).toBe(false)
    local w2 = R.Window.new({ Title = "M2", Parent = screen, Animations = true })
    h.expect(R.Animate.isEnabled()).toBe(true)
    h.expect(w2:SetAnimationsEnabled(false)).toBe(false)
    h.expect(R.Animate.isEnabled()).toBe(false)
    w2:SetAnimationsEnabled(true)   -- restore the global default for any later suites
    h.expect(R.Animate.isEnabled()).toBe(true)
  end)
  h.it("Hide defers the floating-toggle reveal when capability is absent", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local function fab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    R.Safe._setCapabilityCheck(function() return false end)
    w:Hide()
    h.expect(fab().Visible).toBe(false)        -- deferred: FAB not revealed yet
    h.mock.stepHeartbeat(0)
    h.expect(fab().Visible).toBe(true)         -- revealed in a capability context
    R.Safe._setCapabilityCheck(nil)
  end)
  h.it("SetMode from a no-capability thread does not error and state is synchronous", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    R.Safe._setCapabilityCheck(function() return false end)
    w:SetMode("light")
    h.expect(w:GetMode()).toBe("light")        -- Lua state is synchronous, not deferred
    h.mock.stepHeartbeat(0)                    -- reskin flushes without error
    R.Safe._setCapabilityCheck(nil)
  end)
  h.it("ImageAdaptive tints the title logo to the foreground token and flips on SetMode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Image = "rbxassetid://42", ImageAdaptive = true, Parent = screen })
    local img = w.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage")
    h.expect(img.ImageColor3.R8).toBe(R.Theme.PALETTES.dark.foreground.R8)   -- 250 in dark
    w:SetMode("light")
    h.expect(img.ImageColor3.R8).toBe(R.Theme.PALETTES.light.foreground.R8)  -- 24 in light
  end)
  h.it("FloatingToggle Adaptive tints the logo to foreground and flips on SetMode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = "rbxassetid://7", Adaptive = true } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local img = fab:FindFirstChild("Img")
    h.expect(img.ImageColor3.R8).toBe(R.Theme.PALETTES.dark.foreground.R8)
    w:SetMode("light")
    h.expect(img.ImageColor3.R8).toBe(R.Theme.PALETTES.light.foreground.R8)
  end)
  h.it("Image as a { dark, light } table swaps the title logo per mode (Fit, full tile)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Parent = screen,
      Image = { dark = "rbxassetid://11", light = "rbxassetid://22" } })
    local img = w.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage")
    h.expect(img.Image).toBe("rbxassetid://11")   -- dark variant at start (default dark mode)
    h.expect(img.ScaleType.Name).toBe("Fit")      -- full self-contained tile, never cropped
    w:SetMode("light")
    h.expect(img.Image).toBe("rbxassetid://22")   -- swapped to the light variant
    w:SetMode("dark")
    h.expect(img.Image).toBe("rbxassetid://11")
  end)
  h.it("FloatingToggle Image as a { dark, light } table swaps the FAB logo per mode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = { dark = "rbxassetid://11", light = "rbxassetid://22" } } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local img = fab:FindFirstChild("Img")
    h.expect(img.Image).toBe("rbxassetid://11")
    h.expect(img.ScaleType.Name).toBe("Fit")
    w:SetMode("light")
    h.expect(img.Image).toBe("rbxassetid://22")
  end)
  h.it("a { dark, light } title image ignores ImageAdaptive (full-color tiles are not tinted)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Parent = screen, ImageAdaptive = true,
      Image = { dark = "rbxassetid://11", light = "rbxassetid://22" } })
    local img = w.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage")
    h.expect(img.ImageColor3.R8).toBe(255)        -- untinted white: the tile renders its own colors
  end)
  h.it("SetImage accepts a { dark, light } table and keeps swapping on mode change", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Image = "rbxassetid://1", Parent = screen })
    w:SetImage({ dark = "rbxassetid://11", light = "rbxassetid://22" })
    local img = w.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage")
    h.expect(img.Image).toBe("rbxassetid://11")
    w:SetMode("light")
    h.expect(img.Image).toBe("rbxassetid://22")
  end)
  h.it("an adaptive title logo uses ScaleType.Fit (padded glyph not cropped); non-adaptive keeps Crop", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local adaptive = R.Window.new({ Title = "A", Image = "rbxassetid://42", ImageAdaptive = true, Parent = screen })
    local aImg = adaptive.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage")
    h.expect(aImg.ScaleType.Name).toBe("Fit")
    local plain = R.Window.new({ Title = "B", Image = "rbxassetid://42", Parent = h.roblox.Instance.new("ScreenGui") })
    local pImg = plain.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage")
    h.expect(pImg.ScaleType.Name).toBe("Crop")   -- full-color logos keep cover behavior
  end)
  h.it("an adaptive FAB logo uses ScaleType.Fit", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = "rbxassetid://7", Adaptive = true } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab:FindFirstChild("Img").ScaleType.Name).toBe("Fit")
  end)
  h.it("a non-adaptive FAB logo keeps ScaleType.Crop", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = "rbxassetid://7" } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    h.expect(fab:FindFirstChild("Img").ScaleType.Name).toBe("Crop")
  end)
  h.it("a non-adaptive FAB logo stays full-color white across mode changes", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen,
      FloatingToggle = { Type = "square", Image = "rbxassetid://7" } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local img = fab:FindFirstChild("Img")
    h.expect(img.ImageColor3.R8).toBe(255)   -- white: tints nothing, renders the full-color logo as-is
    w:SetMode("light")
    h.expect(img.ImageColor3.R8).toBe(255)   -- still white (not re-tinted to a theme token)
  end)
  h.it("manually-resized window never shrinks below MIN_W/MIN_H on a tiny viewport", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local cam = h.roblox.workspace.CurrentCamera
    local w = R.Window.new({ Title = "M", Parent = screen })
    local hit = w.Main:FindFirstChild("ResizeHit")
    local touch = { UserInputType = h.roblox.Enum.UserInputType.Touch, Position = h.roblox.Vector2.new(700, 500) }
    hit.InputBegan:Fire(touch)
    touch.Position = h.roblox.Vector2.new(600, 400)   -- shrink to ~476x332 (userResized)
    uis.InputChanged:Fire(touch)
    uis.InputEnded:Fire(touch)
    cam.ViewportSize = h.roblox.Vector2.new(300, 320)  -- tiny viewport, below MIN
    w:AdaptToViewport()
    h.expect(w.Main.Size.X.Offset >= 380).toBeTruthy()  -- MIN_W
    h.expect(w.Main.Size.Y.Offset >= 260).toBeTruthy()  -- MIN_H
    cam.ViewportSize = h.roblox.Vector2.new(1280, 720)   -- restore shared mock state
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)
  h.it("Animations=false is explicit; a later Window.new without Animations does not flip it back on", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    R.Window.new({ Title = "M", Parent = screen, Animations = false })
    h.expect(R.Animate.isEnabled()).toBe(false)
    h.expect(R.Animate.isExplicit()).toBe(true)
    R.Window.new({ Title = "M2", Parent = screen })   -- e.g. a second demo window with no config
    h.expect(R.Animate.isEnabled()).toBe(false)       -- applyDefault must not override the explicit choice
    R.Animate.setEnabled(true)                         -- restore the global default for later suites
  end)
  h.it("a Theme.Motion override is routed into Animate.useMotion", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    R.Window.new({ Title = "M", Parent = screen, Theme = { Motion = { fast = 0.5 } } })
    local f = h.roblox.Instance.new("Frame")
    R.Animate.to(f, "fast", { BackgroundTransparency = 0.2 })
    h.expect(h.mock.lastTween.Info.Time).toBe(0.5)
    R.Animate.useMotion(nil)
    R.Animate.to(f, "fast", { BackgroundTransparency = 0.3 })
    h.expect(h.mock.lastTween.Info.Time).toBe(R.Theme.Motion.fast)
  end)
  h.it("Main acrylic sheen: dark top is MODE_EFFECTS.sheenTop, light top falls back to card, one UIGradient/UIStroke", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local grad = w.Main:FindFirstChildOfClass("UIGradient")
    h.expect(grad.Color.color[1].Value).toBe(R.Theme.MODE_EFFECTS.dark.sheenTop)
    h.expect(grad.Color.color[2].Value).toBe(R.Theme.MODE_EFFECTS.dark.sheenBottom)
    h.expect(w.Main.BackgroundColor3.R8).toBe(R.Theme.Colors.background.R8)
    w:SetMode("light")
    h.expect(grad.Color.color[1].Value).toBe(R.Theme.PALETTES.light.card)
    h.expect(w.Main.BackgroundColor3).toBe(R.Theme.PALETTES.light.background)
    h.expect(w.Main:FindFirstChildOfClass("UIStroke").Color).toBe(R.Theme.PALETTES.light.border)
    w:SetMode("dark")
    h.expect(grad.Color.color[1].Value).toBe(R.Theme.MODE_EFFECTS.dark.sheenTop)
    local grads, strokes = 0, 0
    for _, c in ipairs(w.Main:GetChildren()) do
      if c.ClassName == "UIGradient" then grads = grads + 1 elseif c.ClassName == "UIStroke" then strokes = strokes + 1 end
    end
    h.expect(grads).toBe(1); h.expect(strokes).toBe(1)
  end)
  h.it("SetTransparency reskins through Acrylic: background updated, sheen band rescaled, still one UIGradient", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    h.expect(w.Main.BackgroundTransparency).toBe(R.Theme.Acrylic.frost)   -- default frost token
    w:SetTransparency(0.5)
    h.expect(w.Main.BackgroundTransparency).toBe(0.5)
    local grads = 0
    for _, c in ipairs(w.Main:GetChildren()) do if c.ClassName == "UIGradient" then grads = grads + 1 end end
    h.expect(grads).toBe(1)
    local band = w.Main:FindFirstChild("AcrylicSheen"):FindFirstChildOfClass("UIGradient").Transparency.keypoints[1].Value
    h.expect(band).toBeCloseTo(1 - (1 - R.Theme.MODE_EFFECTS.dark.highlight) * (1 - 0.5))
    w:SetMode("light")                                   -- the shell closure keeps the user's transparency
    h.expect(w.Main.BackgroundTransparency).toBe(0.5)
  end)
  h.it("ContentPanel carries one hairline stroke at Stroke.panel for the mode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local panel = w.Main:FindFirstChild("Body"):FindFirstChild("ContentPanel")
    local strokes = 0
    for _, c in ipairs(panel:GetChildren()) do if c.ClassName == "UIStroke" then strokes = strokes + 1 end end
    h.expect(strokes).toBe(1)
    local st = panel:FindFirstChildOfClass("UIStroke")
    h.expect(st.Thickness).toBe(1)
    h.expect(st.Color.R8).toBe(R.Theme.Colors.border.R8)
    h.expect(st.Transparency).toBe(R.Theme.Stroke.panel.dark)
    w:SetMode("light")
    h.expect(st.Color).toBe(R.Theme.PALETTES.light.border)
    h.expect(st.Transparency).toBe(R.Theme.Stroke.panel.light)
  end)
  h.it("sidebar search stroke: Stroke.search per mode, focus ring thickens to ring colour and re-derives on SetMode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local search = w.Main:FindFirstChild("Body"):FindFirstChild("Search")
    local st = search:FindFirstChildOfClass("UIStroke")
    local input = search:FindFirstChild("SearchInput")
    h.expect(st.Thickness).toBe(1)
    h.expect(st.Transparency).toBe(R.Theme.Stroke.search.dark)
    h.expect(st.Color.R8).toBe(R.Theme.Colors.border.R8)
    input.Focused:Fire()
    h.expect(st.Thickness).toBe(R.Theme.Stroke.focusThickness)   -- 2
    h.expect(st.Color.R8).toBe(R.Theme.Colors.ring.R8)
    -- the ring goes opaque while focused: drawn at the hairline's 0.8 it would barely read
    h.expect(st.Transparency).toBe(R.Theme.Stroke.control)
    w:SetMode("light")                                           -- still focused: ring in the light palette
    h.expect(st.Color).toBe(R.Theme.PALETTES.light.ring)
    h.expect(st.Transparency).toBe(R.Theme.Stroke.control)       -- a reskin must not fade a live ring
    input.FocusLost:Fire()
    h.expect(st.Thickness).toBe(1)
    h.expect(st.Color).toBe(R.Theme.PALETTES.light.border)
    h.expect(st.Transparency).toBe(R.Theme.Stroke.search.light)  -- blurred: back to the mode's hairline
  end)
  h.it("Title/Subtitle use the title/muted roles with end truncation", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "Hub", Subtitle = "v3", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    local title, sub = bar:FindFirstChild("Title"), bar:FindFirstChild("Subtitle")
    h.expect(title.TextSize).toBe(R.Theme.Font.title.Size)
    h.expect(title.FontFace.Weight.Name).toBe(R.Theme.Font.title.Weight.Name)   -- Bold (enum copied by deepMerge)
    h.expect(title.TextTruncate.Name).toBe("AtEnd")
    h.expect(sub.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(sub.TextTruncate.Name).toBe("AtEnd")
    local input = w.Main:FindFirstChild("Body"):FindFirstChild("Search"):FindFirstChild("SearchInput")
    h.expect(input.TextSize).toBe(R.Theme.Font.muted.Size)
  end)
  h.it("GroupHeader is an overline row (Font.overline, bottom-aligned) whose colour re-derives on SetMode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local g = w:AddTabGroup("Main"); g:AddTab({ Name = "Home" })
    local sidebar = w.Main:FindFirstChild("Body"):FindFirstChild("Sidebar")
    local header; for _, c in ipairs(sidebar:GetChildren()) do if c.Name == "GroupHeader" then header = c end end
    h.expect(header ~= nil).toBeTruthy()
    h.expect(header.Text).toBe("MAIN")
    h.expect(header.TextSize).toBe(R.Theme.Font.overline.Size)
    h.expect(header.TextYAlignment.Name).toBe("Bottom")
    h.expect(header.Size.Y.Offset).toBe(R.Theme.Spacing.major)
    h.expect(header.TextColor3.R8).toBe(R.Theme.Colors.mutedForeground.R8)
    w:SetMode("light")
    h.expect(header.TextColor3).toBe(R.Theme.PALETTES.light.mutedForeground)
  end)
  h.it("Tag width is measured through TextService (x fudge) and falls back to the per-char estimate without it", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local bar = w.Main:FindFirstChild("TitleBar")
    local function lastPill() local r; for _, c in ipairs(bar:GetChildren()) do if c.Name == "Tag" then r = c end end return r end
    local size = R.Theme.Font.muted.Size
    local measured = h.roblox.game:GetService("TextService"):GetTextSize("Beta", size, h.roblox.Enum.Font.BuilderSans, h.roblox.Vector2.new(1e4, size)).X
    w:Tag({ Text = "Beta" })
    local expected = 8 + math.ceil(measured * R.Theme.Sizes.tagMeasureFudge) + 8
    h.expect(lastPill().Size.X.Offset).toBe(expected)
    h.expect(expected ~= 8 + #"Beta" * 7 + 8).toBeTruthy()      -- the measured path really ran
    h.expect(lastPill():FindFirstChild("TagText").TextSize).toBe(size)
    h.mock.hidden = { TextService = true }                       -- executor without TextService
    w:Tag({ Text = "Beta" })
    h.mock.hidden = nil
    h.expect(lastPill().Size.X.Offset).toBe(8 + #"Beta" * 7 + 8)
  end)
  h.it("Notify/ShowLoading/Dialog pass an AccentReg hook backed by the window themer", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local seen = {}
    local origShow, origLoading, origDialog = R.Notification.show, R.Notification.loading, R.Dialog.open
    R.Notification.show = function(o) seen.show = o; return origShow(o) end
    R.Notification.loading = function(o) seen.loading = o; return origLoading(o) end
    R.Dialog.open = function(o) seen.dialog = o; return origDialog(o) end
    w:Notify({ Title = "x", Duration = 0 })
    w:ShowLoading({ Title = "l" })
    local dlg = w:Dialog({ Title = "d", Buttons = { { Text = "OK" } } })
    R.Notification.show, R.Notification.loading, R.Dialog.open = origShow, origLoading, origDialog
    for _, k in ipairs({ "show", "loading", "dialog" }) do
      h.expect(type(seen[k].AccentReg)).toBe("function")
      h.expect(seen[k].Theme ~= nil).toBeTruthy()
    end
    local n = 0
    local unreg = seen.show.AccentReg(function() n = n + 1 end)
    w:SetMode("light"); h.expect(n).toBe(1)
    w:SetAccent("Indigo"); h.expect(n).toBe(2)
    unreg(); w:SetMode("dark"); h.expect(n).toBe(2)   -- unregistered closure is left alone
    if dlg and dlg.Close then dlg.Close() end
    R.Notification.clearAll()
  end)
  h.it("themer closures receive the reason: SetAccent does not re-fetch a { dark, light } title tile", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local calls, orig = 0, R.Asset.imageAsync
    R.Asset.imageAsync = function(...) calls = calls + 1; return orig(...) end
    local w = R.Window.new({ Title = "Hub", Parent = screen, Image = { dark = "rbxassetid://11", light = "rbxassetid://22" },
      FloatingToggle = { Type = "square", Image = { dark = "rbxassetid://31", light = "rbxassetid://32" } } })
    local base = calls
    w:SetAccent("Indigo")
    h.expect(calls).toBe(base)                        -- accent never swaps a tile
    w:SetMode("light")
    h.expect(calls).toBe(base + 2)                    -- title + FAB tile re-resolved for the new mode
    R.Asset.imageAsync = orig
    h.expect(w.Main:FindFirstChild("TitleBar"):FindFirstChild("TitleImage").Image).toBe("rbxassetid://22")
  end)
  h.it("circle FAB placeholder glyph is primaryForeground (readable on the primary fill) and follows the mode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "circle" } })
    local fab; for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local img = fab:FindFirstChild("Img")
    h.expect(img.ImageColor3.R8).toBe(R.Theme.PALETTES.dark.primaryForeground.R8)   -- 24, not primary-on-primary
    h.expect(fab.Size.X.Offset).toBe(R.Theme.Sizes.fab.size)
    w:SetMode("light")
    h.expect(img.ImageColor3).toBe(R.Theme.PALETTES.light.primaryForeground)
    h.expect(fab.BackgroundColor3).toBe(R.Theme.PALETTES.light.primary)
    local w2 = R.Window.new({ Title = "M2", Parent = h.roblox.Instance.new("ScreenGui"), FloatingToggle = { Type = "square" } })
    local fab2; for _, c in ipairs(R.Overlay.get(w2.Gui):GetChildren()) do if c.Name == "FloatingToggle" then fab2 = c end end
    h.expect(fab2:FindFirstChild("Img").ImageColor3.R8).toBe(R.Theme.PALETTES.dark.primary.R8)  -- square: primary on surface
  end)

  -- ---- phase 2: centre pivot, clamps and grip geometry (2.1 / 2.23 / 2.24) ----------------------
  -- Every helper below reads the mock viewport (1280x720) explicitly: Position is the window's
  -- CENTRE now, so a raw Offset says nothing without the Scale half and the size.
  local VPX, VPY = 1280, 720
  local function centreOf(main)
    local p = main.Position
    return p.X.Scale * VPX + p.X.Offset, p.Y.Scale * VPY + p.Y.Offset
  end
  local function edgesOf(main)
    local cx, cy = centreOf(main)
    return cx - main.Size.X.Offset / 2, cy - main.Size.Y.Offset / 2
  end
  local MB1 = h.roblox.Enum.UserInputType.MouseButton1
  local MOVE = h.roblox.Enum.UserInputType.MouseMovement
  local function dragBarTo(w, x, y, from)
    local bar = w.Main:FindFirstChild("TitleBar")
    local uis = h.roblox.game:GetService("UserInputService")
    if from then bar.InputBegan:Fire({ UserInputType = MB1, Position = from }) end
    uis.InputChanged:Fire({ UserInputType = MOVE, Position = h.roblox.Vector2.new(x, y) })
  end
  h.it("Main pivots from its centre: AnchorPoint (0.5,0.5) at Position (0.5,0,0.5,0)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    h.expect(w.Main.AnchorPoint.X).toBe(0.5)
    h.expect(w.Main.AnchorPoint.Y).toBe(0.5)
    h.expect(w.Main.Position.X.Scale).toBe(0.5); h.expect(w.Main.Position.X.Offset).toBe(0)
    h.expect(w.Main.Position.Y.Scale).toBe(0.5); h.expect(w.Main.Position.Y.Offset).toBe(0)
    local left, top = edgesOf(w.Main)
    h.expect(left).toBeCloseTo((VPX - w.Main.Size.X.Offset) / 2)   -- still centred on screen
    h.expect(top).toBeCloseTo((VPY - w.Main.Size.Y.Offset) / 2)
  end)
  h.it("resize keeps the left/top edge still (the centre moves by half the size delta)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen })
    local left0, top0 = edgesOf(w.Main)
    local w0, h0 = w.Main.Size.X.Offset, w.Main.Size.Y.Offset
    local hit = w.Main:FindFirstChild("ResizeHit")
    local touch = { UserInputType = h.roblox.Enum.UserInputType.Touch, Position = h.roblox.Vector2.new(700, 500) }
    hit.InputBegan:Fire(touch)
    touch.Position = h.roblox.Vector2.new(600, 400)      -- shrink by 100 x 100 from the corner
    uis.InputChanged:Fire(touch)
    h.expect(w.Main.Size.X.Offset).toBe(w0 - 100)
    h.expect(w.Main.Size.Y.Offset).toBe(h0 - 100)
    local left1, top1 = edgesOf(w.Main)
    h.expect(left1).toBeCloseTo(left0)                    -- the corner the user is NOT dragging
    h.expect(top1).toBeCloseTo(top0)
    uis.InputEnded:Fire(touch)
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)
  h.it("title-bar drag clamps the centre: dragKeep of the bar always stays on screen", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local keep, bar = R.Theme.Sizes.dragKeep, R.Theme.Sizes.titleBar
    local halfW, halfH = w.Main.Size.X.Offset / 2, w.Main.Size.Y.Offset / 2
    dragBarTo(w, -4900, 10, h.roblox.Vector2.new(100, 10))   -- 5000px to the left
    local cx = centreOf(w.Main)
    h.expect(cx).toBeCloseTo(keep - halfW)                   -- 40px of title bar still on screen
    dragBarTo(w, 9100, -5000)                                -- far right and far above
    local cx2, cy2 = centreOf(w.Main)
    h.expect(cx2).toBeCloseTo(VPX - keep + halfW)
    h.expect(cy2).toBeCloseTo(halfH)                         -- top edge pinned at y = 0
    dragBarTo(w, 100, 9000)                                  -- far below
    local _, cy3 = centreOf(w.Main)
    h.expect(cy3).toBeCloseTo(VPY - bar + halfH)             -- the bar itself never leaves the screen
    w.Main:FindFirstChild("TitleBar").InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(100, 10) })
  end)
  h.it("a small drag is still start + delta (no clamp in the middle of the screen)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local cx0, cy0 = centreOf(w.Main)
    dragBarTo(w, 160, 40, h.roblox.Vector2.new(100, 10))
    local cx, cy = centreOf(w.Main)
    h.expect(cx).toBeCloseTo(cx0 + 60); h.expect(cy).toBeCloseTo(cy0 + 30)
    h.expect(w.Main.Position.X.Scale).toBe(0.5)   -- the start's Scale halves survive the write
    w.Main:FindFirstChild("TitleBar").InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(160, 40) })
  end)
  h.it("AdaptToViewport clamps a user-moved window by its centre (whole frame stays on screen)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    dragBarTo(w, -4900, 10, h.roblox.Vector2.new(100, 10))
    w.Main:FindFirstChild("TitleBar").InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(-4900, 10) })
    w:AdaptToViewport()
    local left, top = edgesOf(w.Main)
    h.expect(w.Main.Position.X.Scale).toBe(0)     -- user-moved: rewritten as a pure offset centre
    h.expect(left).toBeCloseTo(0)                 -- left edge flush, not 40px of bar off-screen
    h.expect(top >= 0).toBeTruthy()
  end)
  h.it("resize grip sits in the corner gutter and its hit target is centred on the corner", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen })
    local grip = w.Main:FindFirstChild("ResizeGrip")
    h.expect(grip.Size.X.Offset).toBe(R.Theme.Sizes.resizeGrip)
    h.expect(grip.Position.X.Offset).toBe(-R.Theme.Sizes.resizeGripInset)
    h.expect(grip.Position.Y.Offset).toBe(-R.Theme.Sizes.resizeGripInset)
    local hit = w.Main:FindFirstChild("ResizeHit")
    h.expect(hit.Size.X.Offset >= 44).toBeTruthy()          -- still finger-sized on touch
    h.expect(hit.AnchorPoint.X).toBe(0.5); h.expect(hit.AnchorPoint.Y).toBe(0.5)
    h.expect(hit.Position.X.Scale).toBe(1); h.expect(hit.Position.X.Offset).toBe(0)
    h.expect(hit.Position.Y.Scale).toBe(1); h.expect(hit.Position.Y.Offset).toBe(0)
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)

  -- ---- phase 2: depth + edge light (2.3 / 2.4) ---------------------------------------------------
  -- Effect.shadowId is '' by default, so Effects.shadow returns nil and the window must work
  -- without a shadow layer at all; SHADOW_ON overrides it so the same call sites can be inspected.
  -- The id is a placeholder: the real 9-slice asset is only chosen after a Studio pass.
  local SHADOW_ON = { Effect = { shadowId = "rbxassetid://1" } }
  local function shadowWin(R, screen, extra)
    local o = { Title = "M", Parent = screen, Theme = SHADOW_ON }
    for k, v in pairs(extra or {}) do o[k] = v end
    return R.Window.new(o)
  end
  h.it("no shadow layer when no shadow asset is configured: every call site tolerates nil", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    -- explicit: the default theme now ships an uploaded sprite, so shadows are ON by default
    local w = R.Window.new({ Title = "M", Parent = screen, Theme = R.Theme.new({ Effect = { shadowId = "" } }) })
    h.expect(w.Gui:FindFirstChild("WindowShadow")).toBe(nil)
    w:SetTransparency(0.4); w:SetUIScale(1.2); w:SetMode("light"); w:AdaptToViewport()
    dragBarTo(w, 160, 40, h.roblox.Vector2.new(100, 10))
    w.Main:FindFirstChild("TitleBar").InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(160, 40) })
    w:Hide(); w:Show()
    h.expect(w:IsVisible()).toBe(true)      -- the whole flow ran without a shadow
  end)
  h.it("the drop shadow is a sibling of Main under the ScreenGui, mirrored from its geometry", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = shadowWin(R, screen)
    local sh = w.Gui:FindFirstChild("WindowShadow")
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.Parent).toBe(w.Gui)                 -- sibling, never a child (ZIndexBehavior.Sibling)
    h.expect(sh.ZIndex).toBe(0)                     -- under Main (1) and the overlay root (1000)
    h.expect(w.Main:FindFirstChild("WindowShadow")).toBe(nil)
    h.expect(sh.AnchorPoint.X).toBe(0.5)            -- same pivot as Main
    h.expect(sh:FindFirstChildOfClass("UIScale") ~= nil).toBeTruthy()   -- follows the window scale
    local lv = R.Theme.Effect.window
    h.expect(sh.Size.X.Offset).toBe(w.Main.Size.X.Offset + 2 * lv.spread)
    h.expect(sh.Size.Y.Offset).toBe(w.Main.Size.Y.Offset + 2 * lv.spread)
    h.expect(sh.Position.X.Scale).toBe(w.Main.Position.X.Scale)
    h.expect(sh.Position.Y.Offset).toBe(w.Main.Position.Y.Offset + lv.offsetY)
    h.expect(sh.ImageTransparency).toBeCloseTo(R.Theme.MODE_EFFECTS.dark.shadow + R.Theme.Acrylic.frost * 0.5)
    R.Animate.useMotion(nil)
  end)
  h.it("the shadow is re-mirrored after every Main geometry write (drag, resize, adapt, scale)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = shadowWin(R, screen)
    local sh = w.Gui:FindFirstChild("WindowShadow")
    local lv = R.Theme.Effect.window
    -- `grow` = the extra spread a lifted shadow keeps while the grab is in flight: mirror must
    -- carry it through, otherwise every drag frame would undo Effects.lift.
    local function agrees(grow)
      return sh.Position.X.Offset == w.Main.Position.X.Offset
        and sh.Position.Y.Offset == w.Main.Position.Y.Offset + lv.offsetY
        and sh.Size.X.Offset == w.Main.Size.X.Offset + 2 * lv.spread + (grow or 0)
    end
    local grabGrow = 2 * R.Theme.Effect.lift.spreadDelta
    local hit = w.Main:FindFirstChild("ResizeHit")
    local touch = { UserInputType = h.roblox.Enum.UserInputType.Touch, Position = h.roblox.Vector2.new(700, 500) }
    hit.InputBegan:Fire(touch)
    touch.Position = h.roblox.Vector2.new(640, 460)
    uis.InputChanged:Fire(touch)
    h.expect(agrees(grabGrow)).toBe(true)            -- resize (grip held: shadow still lifted)
    uis.InputEnded:Fire(touch)
    uis.TouchEnabled = false; uis.MouseEnabled = true
    dragBarTo(w, 200, 90, h.roblox.Vector2.new(100, 10))
    h.expect(agrees(grabGrow)).toBe(true)            -- drag (title bar held)
    w.Main:FindFirstChild("TitleBar").InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(200, 90) })
    w:AdaptToViewport()
    h.expect(agrees()).toBe(true)                    -- viewport refit
    w:SetUIScale(1.3)
    h.expect(sh:FindFirstChildOfClass("UIScale").Scale).toBe(1.3)   -- scales about the same centre
    h.expect(agrees()).toBe(true)
    R.Animate.useMotion(nil)
  end)
  h.it("grabbing the title bar lifts the shadow and drives the shell hairline opaque", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = shadowWin(R, screen)
    local sh = w.Gui:FindFirstChild("WindowShadow")
    local stroke = w.Main:FindFirstChildOfClass("UIStroke")
    local rest, restAlpha = sh.Size.X.Offset, sh.ImageTransparency
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.window)
    local bar = w.Main:FindFirstChild("TitleBar")
    bar.InputBegan:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(100, 10) })
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.floating)                     -- opaque while held
    h.expect(sh.Size.X.Offset).toBe(rest + 2 * R.Theme.Effect.lift.spreadDelta)     -- spreads
    h.expect(sh.ImageTransparency).toBeCloseTo(restAlpha + R.Theme.Effect.lift.alphaDelta)
    dragBarTo(w, 160, 40)
    h.expect(sh.Size.X.Offset).toBe(rest + 2 * R.Theme.Effect.lift.spreadDelta)     -- mirror keeps the lift
    bar.InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(160, 40) })
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.window)
    h.expect(sh.Size.X.Offset).toBe(rest)
    h.expect(sh.ImageTransparency).toBeCloseTo(restAlpha)
    R.Animate.useMotion(nil)
  end)
  h.it("the shadow follows SetTransparency and re-skins with the mode", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = shadowWin(R, screen)
    local sh = w.Gui:FindFirstChild("WindowShadow")
    w:SetTransparency(0.5)
    h.expect(sh.ImageTransparency).toBeCloseTo(R.Theme.MODE_EFFECTS.dark.shadow + 0.5 * 0.5)
    w:SetMode("light")   -- light mode: the shadow is the only thing separating the panel from the world
    h.expect(sh.ImageTransparency).toBe(1)   -- 0.8 + 0.25 saturates: a half-frosted light window casts none
    w:SetTransparency(0)
    h.expect(sh.ImageTransparency).toBeCloseTo(R.Theme.MODE_EFFECTS.light.shadow)
    R.Animate.useMotion(nil)
  end)
  h.it("Main wears the edge light: a rim gradient inside its stroke plus the top glint", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local stroke = w.Main:FindFirstChildOfClass("UIStroke")
    local rim = stroke:FindFirstChildOfClass("UIGradient")
    h.expect(rim ~= nil).toBeTruthy()
    h.expect(rim.Transparency.keypoints[1].Value).toBe(R.Theme.MODE_EFFECTS.dark.edgeTop)
    h.expect(rim.Transparency.keypoints[2].Value).toBe(R.Theme.MODE_EFFECTS.dark.edgeBottom)
    h.expect(stroke.Color.R8).toBe(R.Theme.Colors.border.R8)  -- the rim never touches the stroke colour
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.window)
    local glint = w.Main:FindFirstChild("AcrylicGlint")
    h.expect(glint ~= nil).toBeTruthy()
    h.expect(glint.BackgroundTransparency).toBe(R.Theme.MODE_EFFECTS.dark.glint)
    h.expect(glint.Visible).toBe(true)
    -- the rim lives INSIDE the stroke: Main still carries exactly one gradient and one stroke
    local grads, strokes = 0, 0
    for _, c in ipairs(w.Main:GetChildren()) do
      if c.ClassName == "UIGradient" then grads = grads + 1 elseif c.ClassName == "UIStroke" then strokes = strokes + 1 end
    end
    h.expect(grads).toBe(1); h.expect(strokes).toBe(1)
    w:SetMode("light")                                     -- the shell closure keeps the edge opts
    h.expect(rim.Transparency.keypoints[1].Value).toBe(R.Theme.MODE_EFFECTS.light.edgeTop)
    h.expect(rim.Transparency.keypoints[2].Value).toBe(R.Theme.MODE_EFFECTS.light.edgeBottom)
    h.expect(glint.Visible).toBe(false)                    -- glint is a dark-mode detail (alpha 1)
  end)

  -- ---- phase 2: one fold/unfold recipe (2.2) -----------------------------------------------------
  h.it("Hide folds scale, hairline and shadow together, drifts to the FAB and hands off to it", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = shadowWin(R, screen, { FloatingToggle = true })
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    local stroke = w.Main:FindFirstChildOfClass("UIStroke")
    local sh = w.Gui:FindFirstChild("WindowShadow")
    local restAlpha, restX = sh.ImageTransparency, w.Main.Position.X.Offset
    h.mock.resetTweens()
    w:Hide()
    -- the drift: Main and its shadow travel together (same TweenInfo, shadow one offsetY lower)
    local mainDrift, shadowDrift
    for _, tw in ipairs(h.mock.tweensFor(w.Main)) do if tw.Goal.Position then mainDrift = tw end end
    for _, tw in ipairs(h.mock.tweensFor(sh)) do if tw.Goal.Position then shadowDrift = tw end end
    h.expect(mainDrift ~= nil).toBeTruthy()
    h.expect(mainDrift.Goal.Position.X.Offset).toBeCloseTo(restX - R.Theme.Motion.hideDrift)  -- FAB docks left
    h.expect(shadowDrift.Goal.Position.Y.Offset).toBe(mainDrift.Goal.Position.Y.Offset + R.Theme.Effect.window.offsetY)
    h.expect(shadowDrift.Info.Time).toBe(mainDrift.Info.Time)
    -- end state: invisible, every layer folded out, the resting Position restored
    h.expect(w.Main.Visible).toBe(false)
    h.expect(w.Main.Position.X.Offset).toBe(restX)
    h.expect(stroke.Transparency).toBe(1)
    h.expect(sh.ImageTransparency).toBe(1)
    h.expect(sc.Scale).toBe(1)
    local function fab() for _, c in ipairs(R.Overlay.get(screen):GetChildren()) do if c.Name == "FloatingToggle" then return c end end end
    h.expect(fab().Visible).toBe(true)                            -- pop-in fires from the completion
    h.expect(fab():FindFirstChildOfClass("UIScale").Scale).toBe(1)
    w:Show()                                                      -- ...and Show puts it all back
    h.expect(w.Main.Visible).toBe(true)
    h.expect(sc.Scale).toBe(1)
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.window)
    h.expect(sh.ImageTransparency).toBeCloseTo(restAlpha)
    h.expect(w.Main.BackgroundTransparency).toBe(R.Theme.Acrylic.frost)
    R.Animate.useMotion(nil)
  end)
  h.it("the entrance is that same unfold, one beat slower (Back/Out over Motion.enter)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    h.mock.resetTweens()
    local w = R.Window.new({ Title = "M", Parent = screen, Transparency = 0.2 })
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    local tws = h.mock.tweensFor(sc)
    h.expect(#tws).toBe(1)
    h.expect(tws[1].Info.Time).toBe(R.Theme.Motion.enter)
    h.expect(tws[1].Info.EasingStyle.Name).toBe("Back")
    h.expect(tws[1].Info.EasingDirection.Name).toBe("Out")
    h.expect(sc.Scale).toBe(1)
    h.expect(w.Main.BackgroundTransparency).toBe(0.2)
    h.expect(w.Main:FindFirstChildOfClass("UIStroke").Transparency).toBe(R.Theme.Stroke.window)
  end)
  h.it("Show unfolds over Motion.release; Close folds Back/In over Motion.base to transparent", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    w:Hide()
    h.mock.resetTweens()
    w:Show()
    local up = h.mock.tweensFor(sc)[1]
    h.expect(up.Info.Time).toBe(R.Theme.Motion.release)
    h.expect(up.Info.EasingStyle.Name).toBe("Back")
    h.expect(up.Info.EasingDirection.Name).toBe("Out")
    h.expect(up.Goal.Scale).toBe(1)
    local gui = w.Gui
    h.mock.resetTweens()
    w:Close()
    local down = h.mock.tweensFor(sc)[1]
    h.expect(down.Info.Time).toBe(R.Theme.Motion.base)          -- not the 0.12 hiccup
    h.expect(down.Info.EasingStyle.Name).toBe("Back")
    h.expect(down.Info.EasingDirection.Name).toBe("In")
    h.expect(down.Goal.Scale).toBeCloseTo(R.Theme.Motion.exitScale)
    h.expect(w.Main.BackgroundTransparency).toBe(1)             -- dissolves instead of blinking out
    h.expect(gui._destroyed).toBeTruthy()
  end)
  h.it("a stale fold cannot hide a window that was shown again (generation guard)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    R.Safe._setCapabilityCheck(function() return false end)
    w:Hide()                                    -- the whole fold is parked until the next Heartbeat
    R.Safe._setCapabilityCheck(nil)
    w:Show()                                    -- runs inline: the window is up again
    h.expect(w.Main.Visible).toBe(true)
    h.mock.stepHeartbeat(0)                     -- the stale fold lands now...
    h.expect(w.Main.Visible).toBe(true)         -- ...and is ignored
    h.expect(w.Main:FindFirstChildOfClass("UIScale").Scale).toBe(1)
    h.expect(w:IsVisible()).toBe(true)
  end)
  h.it("StartHidden skips the entrance and pre-sets every layer's rest value", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    h.mock.resetTweens()
    local w = shadowWin(R, screen, { StartHidden = true, Transparency = 0.3, FloatingToggle = { Type = "simple" } })
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    local sh = w.Gui:FindFirstChild("WindowShadow")
    h.expect(w.Main.Visible).toBe(false)
    h.expect(#h.mock.tweensFor(sc)).toBe(0)                     -- no entrance tween at all
    h.expect(sc.Scale).toBe(1)
    h.expect(w.Main.BackgroundTransparency).toBe(0.3)
    h.expect(w.Main:FindFirstChildOfClass("UIStroke").Transparency).toBe(R.Theme.Stroke.window)
    h.expect(sh:FindFirstChildOfClass("UIScale").Scale).toBe(1)
    h.expect(sh.ImageTransparency).toBeCloseTo(R.Theme.MODE_EFFECTS.dark.shadow + 0.3 * 0.5)
    w:Show()
    h.expect(w.Main.Visible).toBe(true)
    h.expect(sc.Scale).toBe(1)
    R.Animate.useMotion(nil)
  end)
  h.it("a Hide/Show round trip stays inside the tween budget (<= 8 each, shadow included)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = shadowWin(R, screen, { FloatingToggle = true })
    h.mock.resetTweens()
    w:Hide()
    local folded = h.mock.tweenCount()
    h.mock.resetTweens()
    w:Show()
    local unfolded = h.mock.tweenCount()
    h.expect(folded > 0).toBeTruthy()
    h.expect(folded <= 8).toBeTruthy()      -- measured: 7 (stroke, shadow alpha, 2x drift, 2x scale, FAB pop)
    h.expect(unfolded <= 8).toBeTruthy()    -- measured: 6 (stroke, shadow alpha, bg, 2x scale, FAB pop-out)
    R.Animate.useMotion(nil)
  end)
  h.it("reduced motion: Hide/Show land on their end state with no tweens at all", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = shadowWin(R, screen)
    local sc = w.Main:FindFirstChildOfClass("UIScale")
    local stroke = w.Main:FindFirstChildOfClass("UIStroke")
    local sh = w.Gui:FindFirstChild("WindowShadow")
    h.withReducedMotion(R, function()
      h.mock.resetTweens()
      w:Hide()
      h.expect(w.Main.Visible).toBe(false)
      h.expect(stroke.Transparency).toBe(1)
      h.expect(sh.ImageTransparency).toBe(1)
      w:Show()
      h.expect(w.Main.Visible).toBe(true)
      h.expect(sc.Scale).toBe(1)
      h.expect(stroke.Transparency).toBe(R.Theme.Stroke.window)
      h.expect(h.mock.tweenCount()).toBe(0)
    end)
    R.Animate.useMotion(nil)
  end)

  -- ---- phase 2: recessed content panel (2.5) -----------------------------------------------------
  h.it("the content panel is recessed: an inset shade on top and card-coloured scroll fades", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local panel = w.Main:FindFirstChild("Body"):FindFirstChild("ContentPanel")
    local shade = panel:FindFirstChildOfClass("UIGradient")
    h.expect(shade.Name).toBe("PanelInset")
    h.expect(shade.Rotation).toBe(90)
    h.expect(shade.Color.color[1].Value).toBe(R.Theme.MODE_EFFECTS.dark.inset)
    h.expect(shade.Color.color[2].Time).toBe(0.06)            -- only the top 6% is shaded
    local top, bot = panel:FindFirstChild("ScrollFadeTop"), panel:FindFirstChild("ScrollFadeBottom")
    h.expect(top ~= nil).toBeTruthy(); h.expect(bot ~= nil).toBeTruthy()
    h.expect(top.Parent).toBe(panel)                          -- the PANEL, never the scrolling Content
    h.expect(w.ContentScroll:FindFirstChild("ScrollFadeTop")).toBe(nil)
    h.expect(w.ContentScroll.CanvasSize.Y.Offset).toBe(0)     -- canvas maths untouched
    h.expect(top.ZIndex).toBe(2); h.expect(top.Active).toBe(false)
    h.expect(top.Size.X.Scale).toBe(1)                        -- Scale width: applySidebarWidth needs no change
    h.expect(top.BackgroundColor3.R8).toBe(R.Theme.Colors.card.R8)
    h.expect(top.Visible).toBe(false); h.expect(bot.Visible).toBe(false)   -- unmeasured: both hidden
    h.expect(top:FindFirstChildOfClass("UIGradient").Transparency.keypoints[1].Value).toBe(0)
    h.expect(bot:FindFirstChildOfClass("UIGradient").Transparency.keypoints[1].Value).toBe(1)
    w:SetMode("light")
    h.expect(shade.Color.color[1].Value).toBe(R.Theme.MODE_EFFECTS.light.inset)
    h.expect(top.BackgroundColor3).toBe(R.Theme.PALETTES.light.card)
  end)
  h.it("scroll fades show only where content runs past the edge, by Visible and never by tween", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local panel = w.Main:FindFirstChild("Body"):FindFirstChild("ContentPanel")
    local top, bot = panel:FindFirstChild("ScrollFadeTop"), panel:FindFirstChild("ScrollFadeBottom")
    local sf = w.ContentScroll
    local function fire(prop) sf:GetPropertyChangedSignal(prop):Fire() end  -- the mock never auto-fires
    sf.AbsoluteWindowSize = h.roblox.Vector2.new(400, 300)
    sf.CanvasSize = h.roblox.UDim2.new(0, 0, 0, 900)
    sf.CanvasPosition = h.roblox.Vector2.new(0, 0)
    fire("CanvasSize")
    h.expect(top.Visible).toBe(false)     -- pinned at the top: nothing above
    h.expect(bot.Visible).toBe(true)      -- 600px still below
    sf.CanvasPosition = h.roblox.Vector2.new(0, 120)
    fire("CanvasPosition")
    h.expect(top.Visible).toBe(true); h.expect(bot.Visible).toBe(true)
    sf.CanvasPosition = h.roblox.Vector2.new(0, 600)          -- scrolled to the very bottom
    fire("CanvasPosition")
    h.expect(top.Visible).toBe(true); h.expect(bot.Visible).toBe(false)
    h.mock.resetTweens()
    sf.CanvasPosition = h.roblox.Vector2.new(0, 300)
    fire("CanvasPosition")
    h.expect(h.mock.tweenCount()).toBe(0)                     -- touch scroll fires this hundreds of times/s
  end)
  h.it("SetTransparency bleeds 60% into the panel and its fades (no opaque slab in a frosted shell)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, Transparency = 0.5 })
    local panel = w.Main:FindFirstChild("Body"):FindFirstChild("ContentPanel")
    h.expect(panel.BackgroundTransparency).toBeCloseTo(0.5 * 0.6)
    w:SetTransparency(0.2)
    h.expect(panel.BackgroundTransparency).toBeCloseTo(0.2 * 0.6)
    h.expect(panel:FindFirstChild("ScrollFadeTop").BackgroundTransparency).toBeCloseTo(0.2 * 0.6)
    w:SetMode("light")                                        -- the shell closure keeps the user's value
    h.expect(panel.BackgroundTransparency).toBeCloseTo(0.2 * 0.6)
  end)

  -- ---- phase 2: sidebar indicator, halo, grip (2.6) -----------------------------------------------
  h.it("the active indicator is a centre-anchored pill carrying an accent halo child", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local ind = w.Main:FindFirstChild("Body"):FindFirstChild("ActiveIndicator")
    h.expect(ind.AnchorPoint.X).toBe(0); h.expect(ind.AnchorPoint.Y).toBe(0.5)
    local IND = R.Theme.Sizes.indicator
    local halo = ind:FindFirstChild("Halo")
    h.expect(halo ~= nil).toBeTruthy()
    h.expect(halo.Parent).toBe(ind)                           -- a child: it rides the spring for free
    h.expect(halo.Size.X.Offset).toBe(IND.haloW); h.expect(halo.Size.Y.Offset).toBe(IND.haloH)
    h.expect(halo.BackgroundTransparency).toBe(IND.haloAlpha)
    h.expect(halo.BackgroundColor3.R8).toBe(R.Theme.Colors.primary.R8)
    w:SetMode("light")
    h.expect(halo.BackgroundColor3).toBe(R.Theme.PALETTES.light.primary)
  end)
  h.it("switching tabs stretches the pill, springs it a distance-aware beat and settles it back", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local ind = body:FindFirstChild("ActiveIndicator")
    local IND = R.Theme.Sizes.indicator
    local t1 = w:AddTab({ Name = "A" })
    body.AbsolutePosition = h.roblox.Vector2.new(0, 0)
    t1.Button.AbsolutePosition = h.roblox.Vector2.new(0, 0); t1.Button.AbsoluteSize = h.roblox.Vector2.new(120, 34)
    local t2 = w:AddTab({ Name = "B" })
    t2.Button.AbsolutePosition = h.roblox.Vector2.new(0, 300); t2.Button.AbsoluteSize = h.roblox.Vector2.new(120, 34)
    h.mock.resetTweens()
    t2.Button.MouseButton1Click:Fire()
    local sizes, moves = {}, {}
    for _, tw in ipairs(h.mock.tweensFor(ind)) do
      if tw.Goal.Size then sizes[#sizes + 1] = tw elseif tw.Goal.Position then moves[#moves + 1] = tw end
    end
    h.expect(#sizes).toBe(2)                                   -- stretch out, then settle back
    h.expect(sizes[1].Goal.Size.Y.Offset).toBe(IND.stretch)
    h.expect(sizes[2].Goal.Size.Y.Offset).toBe(IND.h)
    h.expect(sizes[2].Info.DelayTime).toBe(R.Theme.Motion.fast)  -- engine-side delay, not task.delay
    h.expect(#moves).toBe(1)
    h.expect(moves[1].Goal.Position.Y.Offset).toBe(317)        -- the button's CENTRE (AnchorPoint 0.5)
    h.expect(moves[1].Info.Time > R.Theme.Motion.base).toBeTruthy()   -- 300px of travel takes longer
    h.expect(moves[1].Info.Time <= R.Theme.Motion.slow).toBeTruthy() -- ...but never longer than 'slow'
    h.expect(ind.Size.Y.Offset).toBe(IND.h)                    -- settled
    h.expect(ind.Visible).toBe(true)
  end)
  h.it("the indicator fades out when its tab scrolls out of the band, and reappears synchronously", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local sidebar = body:FindFirstChild("Sidebar")
    local ind = body:FindFirstChild("ActiveIndicator")
    local t1 = w:AddTab({ Name = "A" })
    body.AbsolutePosition = h.roblox.Vector2.new(0, 0)
    sidebar.AbsolutePosition = h.roblox.Vector2.new(0, 36); sidebar.AbsoluteSize = h.roblox.Vector2.new(150, 200)
    t1.Button.AbsolutePosition = h.roblox.Vector2.new(0, 900)   -- scrolled far below the visible band
    t1.Button.AbsoluteSize = h.roblox.Vector2.new(120, 34)
    h.mock.resetTweens()
    sidebar:GetPropertyChangedSignal("CanvasPosition"):Fire()
    h.expect(ind.Visible).toBe(false)
    local faded = false
    for _, tw in ipairs(h.mock.tweensFor(ind)) do if tw.Goal.BackgroundTransparency == 1 then faded = true end end
    h.expect(faded).toBe(true)                                  -- a fade, not a blink
    t1.Button.AbsolutePosition = h.roblox.Vector2.new(0, 60)    -- scrolled back into view
    sidebar:GetPropertyChangedSignal("CanvasPosition"):Fire()
    h.expect(ind.Visible).toBe(true)                            -- written synchronously before any tween
    h.expect(ind.BackgroundTransparency).toBe(0)
  end)
  h.it("the sidebar handle straddles the divider and its grip pill answers hover and drag", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local body = w.Main:FindFirstChild("Body")
    local handle, sidebar = body:FindFirstChild("SidebarHandle"), body:FindFirstChild("Sidebar")
    local gap = R.Theme.Spacing.gap
    local centre = handle.Position.X.Offset + handle.Size.X.Offset / 2
    h.expect(centre).toBeCloseTo(sidebar.Size.X.Offset + gap / 2)   -- centred ON the divider, not beside it
    local grip = handle:FindFirstChild("SidebarGrip")
    h.expect(grip ~= nil).toBeTruthy()
    h.expect(grip.Size.X.Offset).toBe(R.Theme.Sizes.grip.w)
    h.expect(grip.Size.Y.Offset).toBe(R.Theme.Sizes.grip.h)
    h.expect(grip.BackgroundColor3.R8).toBe(R.Theme.Colors.border.R8)
    h.expect(grip.BackgroundTransparency).toBe(1)                  -- invisible until a pointer finds it
    handle.MouseEnter:Fire()
    h.expect(grip.BackgroundTransparency).toBe(0.3)
    local uis = h.roblox.game:GetService("UserInputService")
    body.AbsolutePosition = h.roblox.Vector2.new(0, 0)
    handle.InputBegan:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(154, 50) })
    h.expect(grip.BackgroundTransparency).toBe(0)                  -- solid while dragging
    uis.InputChanged:Fire({ UserInputType = MOVE, Position = h.roblox.Vector2.new(204, 50) })
    h.expect(sidebar.Size.X.Offset).toBe(200)                      -- the divider still tracks the pointer 1:1
    h.expect(handle.Position.X.Offset).toBeCloseTo(200 + gap / 2 - handle.Size.X.Offset / 2)
    uis.InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(204, 50) })
    handle.MouseLeave:Fire()
    h.expect(grip.BackgroundTransparency).toBe(1)
    w:SetMode("light")
    h.expect(grip.BackgroundColor3).toBe(R.Theme.PALETTES.light.border)
  end)

  -- ---- phase 2: title-bar hit targets + search wash (2.7, window half) -----------------------------
  h.it("Close/Minimize keep their 18px glyph and gain a hit target that forwards the same handlers", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, ConfirmClose = false })
    local bar = w.Main:FindFirstChild("TitleBar")
    local closeHit, minHit = bar:FindFirstChild("CloseHit"), bar:FindFirstChild("MinimizeHit")
    h.expect(closeHit ~= nil).toBeTruthy(); h.expect(minHit ~= nil).toBeTruthy()
    h.expect(closeHit.Size.X.Offset).toBe(R.Theme.Sizes.iconButton)
    h.expect(bar:FindFirstChild("Close").Size.X.Offset).toBe(18)   -- the glyph itself is untouched
    h.expect(closeHit.Parent).toBe(bar)                            -- a sibling, never a child of the glyph
    h.expect(closeHit.AnchorPoint.X).toBe(0.5)
    h.expect(closeHit.Position.X.Scale).toBe(1); h.expect(closeHit.Position.X.Offset).toBe(-9)
    minHit.MouseEnter:Fire()
    h.expect(bar:FindFirstChild("Minimize").ImageColor3.R8).toBe(R.Theme.Colors.primary.R8)
    minHit.MouseLeave:Fire()
    h.expect(bar:FindFirstChild("Minimize").ImageColor3.R8).toBe(R.Theme.Colors.mutedForeground.R8)
    minHit.MouseButton1Click:Fire()                                -- the hit forwards the click
    h.expect(w:IsVisible()).toBe(false)
    w:Show()
    local gui = w.Gui
    closeHit.MouseButton1Click:Fire()
    h.expect(gui._destroyed).toBeTruthy()
  end)
  h.it("the title-bar hit targets grow on touch but never overlap each other", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local ok, err = pcall(function()
      local w = R.Window.new({ Title = "M", Parent = screen })
      local bar = w.Main:FindFirstChild("TitleBar")
      local closeHit, minHit = bar:FindFirstChild("CloseHit"), bar:FindFirstChild("MinimizeHit")
      local glyph = bar:FindFirstChild("Close").Size.X.Offset
      -- Bigger than the 18px glyph, but capped: the two centres are 26px apart, so a full 44px
      -- target on each would overlap by 18px and the later sibling (Minimize) would swallow the
      -- left edge of the X. Tiling them edge to edge is the most finger a pair this close allows.
      h.expect(closeHit.Size.X.Offset > glyph).toBeTruthy()
      h.expect(closeHit.Size.X.Offset <= R.Theme.Sizes.touchHit).toBeTruthy()
      local gap = minHit.Position.X.Offset - closeHit.Position.X.Offset
      h.expect(closeHit.Size.X.Offset <= math.abs(gap)).toBeTruthy()   -- no overlap
      h.expect(closeHit.ZIndex > minHit.ZIndex).toBeTruthy()           -- Close wins any future overlap
    end)
    uis.TouchEnabled = false; uis.MouseEnabled = true   -- restore BEFORE rethrowing: a bare
    if not ok then error(err, 0) end                    -- assertion here would leak touch mode
  end)                                                  -- into every later test in this file
  h.it("the sidebar search field wears the hover wash, inset to cancel its own padding", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local search = w.Main:FindFirstChild("Body"):FindFirstChild("Search")
    local wash = search:FindFirstChild("Hover")
    h.expect(wash ~= nil).toBeTruthy()
    h.expect(wash.Position.X.Offset).toBe(-8); h.expect(wash.Size.X.Offset).toBe(16)
    h.expect(wash.BackgroundTransparency).toBe(1)
    search.MouseEnter:Fire()
    h.expect(wash.BackgroundTransparency).toBe(R.Theme.Opacity.hoverWash)
    search.MouseLeave:Fire()
    h.expect(wash.BackgroundTransparency).toBe(1)
    w:SetMode("light")
    h.expect(wash.BackgroundColor3).toBe(R.Theme.PALETTES.light.foreground)
  end)

  -- ---- phase 2: floating button (2.18) --------------------------------------------------------------
  h.it("the FAB chevron rotates instead of swapping sprites and the docked tab peeks on hover", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui")
    local ov = R.Overlay.get(screen); ov.AbsoluteSize = h.roblox.Vector2.new(1280, 720)
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = true })
    local fab; for _, c in ipairs(ov:GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    local chev = fab:FindFirstChild("Chevron")
    local sprite, F = chev.Image, R.Theme.Sizes.fab
    h.expect(chev.AnchorPoint.X).toBe(0.5)          -- Rotation pivots about the AnchorPoint
    h.expect(chev.Rotation).toBe(0)                  -- docked left
    local restX = fab.Position.X.Offset
    fab.MouseEnter:Fire()
    h.expect(fab.Position.X.Offset).toBe(restX + F.hoverPeek)   -- leans further out of the edge
    fab.MouseLeave:Fire()
    h.expect(fab.Position.X.Offset).toBe(restX)
    local uis = h.roblox.game:GetService("UserInputService")
    fab.InputBegan:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(0, 0) })
    uis.InputChanged:Fire({ UserInputType = MOVE, Position = h.roblox.Vector2.new(900, 0) })
    uis.InputEnded:Fire({ UserInputType = MB1, Position = h.roblox.Vector2.new(900, 0) })
    h.expect(chev.Image).toBe(sprite)                -- the SAME sprite...
    h.expect(chev.Rotation).toBe(180)                -- ...turned to face the other way
    h.expect(fab.Position.X.Offset).toBe(1280 - F.simple + F.peek)
    local snap; for _, tw in ipairs(h.mock.tweensFor(fab)) do if tw.Goal.Position then snap = tw end end
    h.expect(snap.Info.Time).toBe(R.Theme.Motion.snap)
    h.expect(snap.Info.EasingStyle.Name).toBe(R.Animate.EASING.snap.Name)
  end)
  h.it("the FAB's glow and shadow are overlay-root siblings, mirrored and faded with the pop", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui")
    local ov = R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen, Theme = SHADOW_ON, FloatingToggle = { Type = "circle" } })
    local function child(n) for _, c in ipairs(ov:GetChildren()) do if c.Name == n then return c end end end
    local fab, sh, gl = child("FloatingToggle"), child("FabShadow"), child("FabGlow")
    h.expect(sh ~= nil).toBeTruthy(); h.expect(gl ~= nil).toBeTruthy()
    h.expect(sh.Parent).toBe(ov)                                 -- siblings, never children of the FAB
    h.expect(fab:FindFirstChild("FabShadow")).toBe(nil)
    h.expect(fab:FindFirstChild("FabGlow")).toBe(nil)      -- neither layer is ever a child of the FAB
    h.expect(sh.ZIndex).toBe(R.Overlay.Z.fab - 2)
    h.expect(gl.ZIndex).toBe(R.Overlay.Z.fab - 1)
    h.expect(fab.ZIndex).toBe(R.Overlay.Z.fab)
    h.expect(sh.ImageTransparency).toBe(1)                       -- hidden while the FAB is
    h.expect(gl.ImageTransparency).toBe(1)
    local lv = R.Theme.Effect.popover
    h.expect(sh.Size.X.Offset).toBe(fab.Size.X.Offset + 2 * lv.spread)
    h.expect(sh.Position.X.Offset).toBeCloseTo(fab.Position.X.Offset + fab.Size.X.Offset / 2)
    h.expect(sh.Position.Y.Offset).toBeCloseTo(fab.Position.Y.Offset + fab.Size.Y.Offset / 2 + lv.offsetY)
    w:Hide()
    h.expect(sh.ImageTransparency).toBeCloseTo(R.Theme.MODE_EFFECTS.dark.shadow)  -- faded in WITH the pop
    fab.MouseEnter:Fire()
    h.expect(gl.ImageTransparency).toBe(R.Theme.Opacity.glowHover)
    h.expect(gl.ImageColor3.R8).toBe(R.Theme.Colors.primary.R8)  -- the window deep-copies its theme
    fab.MouseLeave:Fire()
    h.expect(gl.ImageTransparency).toBe(1)
    w:Show()
    h.expect(sh.ImageTransparency).toBe(1)
    R.Animate.useMotion(nil)
  end)
  h.it("the FAB drag ignores a stray touch and uses Sizes.dragThreshold for click-vs-drag", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui")
    local ov = R.Overlay.get(screen); ov.AbsoluteSize = h.roblox.Vector2.new(1280, 720)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true; uis.MouseEnabled = false
    local w = R.Window.new({ Title = "M", Parent = screen, FloatingToggle = { Type = "circle" } })
    local fab; for _, c in ipairs(ov:GetChildren()) do if c.Name == "FloatingToggle" then fab = c end end
    w:Minimize()
    local x0 = fab.Position.X.Offset
    local TOUCH = h.roblox.Enum.UserInputType.Touch
    uis.InputChanged:Fire({ UserInputType = TOUCH, Position = h.roblox.Vector2.new(400, 400) })
    h.expect(fab.Position.X.Offset).toBe(x0)       -- a move with no begin on the FAB moves nothing
    local mine = { UserInputType = TOUCH, Position = h.roblox.Vector2.new(0, 0) }
    local stray = { UserInputType = TOUCH, Position = h.roblox.Vector2.new(500, 500) }
    fab.InputBegan:Fire(mine)
    uis.InputChanged:Fire(stray)                   -- a DIFFERENT InputObject: the cross-fire bug
    h.expect(fab.Position.X.Offset).toBe(x0)
    local wobble = R.Theme.Sizes.dragThreshold - 2  -- read the token the test is named after
    mine.Position = h.roblox.Vector2.new(wobble, 0) -- under Sizes.dragThreshold: still a tap
    uis.InputChanged:Fire(mine)
    h.expect(fab.Position.X.Offset).toBe(x0 + wobble)
    uis.InputEnded:Fire(mine)
    fab.MouseButton1Click:Fire()
    h.expect(w:IsVisible()).toBe(true)             -- a sub-threshold wobble still counts as a tap
    -- The other side of the gate: a move PAST the threshold must swallow the click, or every
    -- drag would also toggle the window. Without this case the `moved` flag is unverified.
    w:Minimize()
    h.expect(w:IsVisible()).toBe(false)
    local mine2 = { UserInputType = TOUCH, Position = h.roblox.Vector2.new(0, 0) }
    fab.InputBegan:Fire(mine2)
    mine2.Position = h.roblox.Vector2.new(R.Theme.Sizes.dragThreshold * 5, 0)  -- a real drag
    uis.InputChanged:Fire(mine2)
    uis.InputEnded:Fire(mine2)
    fab.MouseButton1Click:Fire()
    h.expect(w:IsVisible()).toBe(false)            -- swallowed: a drag is not a tap
    uis.TouchEnabled = false; uis.MouseEnabled = true
  end)

  -- ---- phase 2: UI-scale forwarding (2.22, window half) ---------------------------------------------
  h.it("SetUIScale forwards to the overlay and the toast container, never onto the overlay root", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); local ov = R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local seen, orig = nil, R.Notification.setScale
    R.Notification.setScale = function(n) seen = n end   -- stubbed: this half only owns the forwarding
    w:SetUIScale(1.3)
    R.Notification.setScale = orig
    h.expect(w.Main:FindFirstChildOfClass("UIScale").Scale).toBe(1.3)
    h.expect(R.Overlay.scale()).toBe(1.3)
    h.expect(seen).toBe(1.3)
    h.expect(ov:FindFirstChildOfClass("UIScale")).toBe(nil)  -- the (1,0,1,0) catcher must stay full-screen
    R.Overlay.setScale(1)
  end)
end)

h.run()
