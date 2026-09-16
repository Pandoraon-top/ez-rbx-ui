local h = require("tests.helper")
local R = h.loadLib()
local function toastCount(gui)
  local root = R.Overlay.get(gui)
  local n = 0
  for _, c in ipairs(root:GetChildren()) do
    if c.Name == "ToastContainer" then for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then n = n + 1 end end end
  end
  return n
end
-- 2.13: the toast border is tinted Toast.typeTint toward its type colour, so the stroke is no
-- longer the border token by identity -- compare the mixed value component-wise instead.
local function expectEdge(stroke, theme, accent, border)
  local want = theme.mix(border or theme.Colors.border, accent, theme.Toast.typeTint)
  h.expect(stroke.Color.R).toBeCloseTo(want.R)
  h.expect(stroke.Color.G).toBeCloseTo(want.G)
  h.expect(stroke.Color.B).toBeCloseTo(want.B)
end
h.describe("notification", function()
  h.it("persistent toast mounts; dismiss removes it", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    local id = w:Notify({ Title = "Hi", Type = "success", Duration = 0 })
    h.expect(toastCount(gui)).toBe(1)
    w:DismissNotification(id)
    h.expect(toastCount(gui)).toBe(0)
  end)
  h.it("two persistent toasts stack (both present)", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Notify({ Title = "A", Duration = 0 }); w:Notify({ Title = "B", Duration = 0 })
    h.expect(toastCount(gui)).toBe(2)
  end)
  h.it("countdown bar shrinks, pauses on hover, dismisses at zero", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Notify({ Title = "t", Type = "success", Duration = 1000 }) -- total = 1s
    local function cont() for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then return c end end end
    local function bar() local c = cont(); for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then local p = t:FindFirstChild("Progress"); if p then return p end end end end
    h.expect(bar() ~= nil).toBeTruthy()
    h.expect(bar().BackgroundColor3.G8).toBe(R.Theme.Colors.success.G8) -- success tint (compare by value; window deep-copies its theme)
    h.mock.stepHeartbeat(0.5)
    h.expect(math.abs(bar().Size.X.Scale - 0.5) < 0.12).toBeTruthy()
    cont().MouseEnter:Fire()              -- pause
    h.mock.stepHeartbeat(1.0)             -- would have dismissed if not paused
    h.expect(bar() ~= nil).toBeTruthy()   -- still alive, bar frozen
    cont().MouseLeave:Fire()              -- resume
    h.mock.stepHeartbeat(1.0)             -- past remaining -> dismiss
    h.expect(toastCount(gui)).toBe(0)
  end)
  h.it("persistent toast has no countdown bar", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Notify({ Title = "x", Duration = 0 })
    local has = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
      for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" and t:FindFirstChild("Progress") then has = true end end end end
    h.expect(has).toBe(false)
  end)
  h.it("loading toast: spinner started, no countdown bar, persists", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    local function findToast()
      for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
        for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then return t end end end end
    end
    local id = w:ShowLoading({ Title = "Saving" })
    local toast = findToast()
    h.expect(toast ~= nil).toBeTruthy()
    h.expect(toast:FindFirstChild("Progress")).toBeNil()             -- loading has no countdown bar
    local icon = toast:FindFirstChild("TitleRow"):FindFirstChild("Icon")
    h.expect(icon.Rotation).toBe(360)                                -- spin tween created + played (mock applies goal)
    h.mock.stepHeartbeat(5)                                          -- a timed toast would dismiss here
    h.expect(findToast() ~= nil).toBeTruthy()                        -- still alive: persistent
    w:DismissNotification(id)
    h.expect(findToast()).toBeNil()
  end)
  h.it("show returns id synchronously and defers GUI when capability is absent (FIFO)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); local ov = R.Overlay.get(screen)
    R.Notification.clearAll()
    R.Safe._setCapabilityCheck(function() return false end)
    local function toasts() local n = 0 for _, c in ipairs(ov:GetChildren()) do
      if c.Name == "ToastContainer" then for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then n = n + 1 end end end
    end return n end
    local id1 = R.Notification.show({ Title = "A", Duration = 0 })
    local id2 = R.Notification.show({ Title = "B", Duration = 0 })
    h.expect(type(id1)).toBe("number")          -- id available synchronously
    h.expect(id2).toBe(id1 + 1)                 -- seq is synchronous + FIFO
    h.expect(R.Notification.count()).toBe(2)    -- order slots reserved synchronously
    h.expect(toasts()).toBe(0)                  -- GUI not built yet (deferred)
    h.mock.stepHeartbeat(0)                     -- flush Safe queue
    h.expect(toasts()).toBe(2)                  -- toasts built in a capability context
    R.Safe._setCapabilityCheck(nil)
    R.Notification.clearAll()
  end)
  h.it("update morphs loading -> success: bar + color + title, spinner reset", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    local function findToast()
      for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
        for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then return t end end end end
    end
    local id = w:ShowLoading({ Title = "Saving" })
    R.Notification.update(id, { Type = "success", Title = "Saved", Duration = 1000 })
    local toast = findToast()
    local title = toast:FindFirstChild("TitleRow"):FindFirstChild("Title")
    h.expect(title.Text).toBe("Saved")
    local bar = toast:FindFirstChild("Progress")
    h.expect(bar ~= nil).toBeTruthy()
    h.expect(bar.BackgroundColor3.G8).toBe(R.Theme.Colors.success.G8)  -- compare by value (window deep-copies theme)
    local icon = toast:FindFirstChild("TitleRow"):FindFirstChild("Icon")
    h.expect(icon.Rotation).toBe(0)                                    -- spinner stopped + reset
    h.mock.stepHeartbeat(1.2)                                          -- countdown expires
    h.expect(findToast()).toBeNil()
  end)

  h.it("promise resolves: loading -> success, message fn gets result, finally runs", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    local function findToast()
      for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
        for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then return t end end end end
    end
    local finallyRan = false
    w:Promise(function() return 7 end, {
      Loading = "Working", Success = function(n) return "Got " .. n end,
      Error = "nope", Finally = function() finallyRan = true end, Duration = 1000 })
    h.expect(findToast():FindFirstChild("Progress")).toBeNil()    -- loading state: no bar yet
    h.mock.stepHeartbeat(0)                                       -- fire the Heartbeat:Once runner
    local toast = findToast()
    h.expect(toast:FindFirstChild("TitleRow"):FindFirstChild("Title").Text).toBe("Got 7")
    h.expect(toast:FindFirstChild("Progress") ~= nil).toBeTruthy()
    h.expect(finallyRan).toBe(true)
  end)

  h.it("promise rejects: morphs to error, err passed to Error fn", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    local function findToast()
      for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
        for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then return t end end end end
    end
    w:Promise(function() error("boom") end, {
      Loading = "Working", Success = "ok", Error = function(e) return "Failed: " .. tostring(e) end })
    h.mock.stepHeartbeat(0)
    local toast = findToast()
    h.expect(toast:FindFirstChild("TitleRow"):FindFirstChild("Title").Text:find("Failed:") ~= nil).toBeTruthy()
    h.expect(toast:FindFirstChild("Progress").BackgroundColor3.G8).toBe(R.Theme.Colors.destructive.G8)
  end)

  h.it("promise without capability: build + morph deferred, ends in success (pendingUpdate branch)", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.clearAll()
    R.Safe._setCapabilityCheck(function() return false end)   -- force deferral, like notification_test.lua:58
    local w = R.Window.new({ Title = "W", Parent = gui })
    local function findToast()
      for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
        for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then return t end end end end
    end
    w:Promise(function() return 1 end, { Loading = "Working", Success = "Done", Error = "nope", Duration = 1000 })
    h.expect(findToast()).toBeNil()              -- nothing built yet: show's build + runner are both deferred
    -- Two steps settle the deferred build + morph regardless of mock handler-fire order
    -- (real Roblox Heartbeat is FIFO and settles in one frame; the mock's pairs() order is not,
    -- so step once to flush the build and once more to guarantee the morph is applied).
    h.mock.stepHeartbeat(0)
    h.mock.stepHeartbeat(0)
    local toast = findToast()
    h.expect(toast ~= nil).toBeTruthy()
    h.expect(toast:FindFirstChild("TitleRow"):FindFirstChild("Title").Text).toBe("Done")  -- pendingUpdate applied
    h.expect(toast:FindFirstChild("Progress") ~= nil).toBeTruthy()
    R.Safe._setCapabilityCheck(nil)
    R.Notification.clearAll()
  end)

  h.it("default position bottom-right; setPosition re-anchors live container (normalizes)", function()
    R.Notification.clearAll(); R.Notification.setPosition("bottom-right")
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Notify({ Title = "x", Duration = 0 })
    local function cont() for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then return c end end end
    h.expect(cont().AnchorPoint.X).toBe(1); h.expect(cont().AnchorPoint.Y).toBe(1)
    w:SetNotificationPosition("Top Left")
    h.expect(cont().AnchorPoint.X).toBe(0); h.expect(cont().AnchorPoint.Y).toBe(0)
    R.Notification.setPosition("bottom-right")   -- restore process-wide state
  end)

  h.it("CreateWindow NotificationPosition sets initial position", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui, NotificationPosition = "top-center" })
    w:Notify({ Title = "x", Duration = 0 })
    local cont; for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then cont = c end end
    h.expect(cont.AnchorPoint.X).toBe(0.5); h.expect(cont.AnchorPoint.Y).toBe(0)
    R.Notification.setPosition("bottom-right")   -- restore process-wide state
  end)
  h.it("hover hit-area tracks content height, not full screen (no center-screen false hover)", function()
    R.Notification.clearAll(); R.Notification.setPosition("top-center")
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:ShowLoading({ Title = "Loading" })
    local cont; for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then cont = c end end
    h.expect(cont ~= nil).toBeTruthy()
    -- Container is the MouseEnter/Leave hit-area. It must be sized to the toast stack, NOT the
    -- full screen height (was UDim2.new(0,300,1,-32)) — otherwise resting the mouse anywhere in
    -- the centre column of a top-center/bottom-center stack falsely triggers hover/expand.
    h.expect(cont.Size.Y.Scale).toBe(0)                 -- content-sized, not 1 (full height)
    h.expect(cont.Size.Y.Offset > 0).toBeTruthy()       -- a real (small) hit area exists
    h.expect(cont.Size.Y.Offset < 600).toBeTruthy()     -- nowhere near full viewport height
    R.Notification.setPosition("bottom-right")           -- restore process-wide state
    R.Notification.clearAll()
  end)

  -- ---- visual-polish phase 1 (1.2 font roles, 1.3 AccentReg, 1.5 floating stroke, 1.9 spin) ----
  local function firstToast(root)
    for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
      for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then return t end end end end
  end
  -- Fake themer: hands the closure back so a test can fire it, and counts registrations/releases.
  local function fakeReg()
    local reg = { fns = {}, count = 0, released = 0 }
    reg.AccentReg = function(fn)
      reg.count = reg.count + 1; reg.fns[#reg.fns + 1] = fn
      return function() reg.released = reg.released + 1 end
    end
    function reg.fire() for _, fn in ipairs(reg.fns) do fn("mode") end end
    return reg
  end

  h.it("toast stroke uses the floating alpha and its text parts use Font roles", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.show({ Title = "t", Message = "m", Duration = 0, Action = { Text = "Undo" } })
    local toast = firstToast(root)
    local stroke = toast:FindFirstChildOfClass("UIStroke")
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.floating)
    expectEdge(stroke, R.Theme, R.Theme.Colors.info)          -- untyped toast = info tint
    local title = toast:FindFirstChild("TitleRow"):FindFirstChild("Title")
    h.expect(title.TextSize).toBe(R.Theme.Font.label.Size)
    h.expect(title.Font).toBe(h.roblox.Enum.Font.BuilderSans)
    h.expect(title.TextTruncate).toBe(h.roblox.Enum.TextTruncate.AtEnd)
    h.expect(toast:FindFirstChild("Message").TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(toast:FindFirstChild("Action").TextSize).toBe(R.Theme.Font.muted.Size)
    R.Notification.clearAll()
  end)

  h.it("AccentReg: the registered closure re-skins a live toast from theme.Colors", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local t = R.Theme.new()
    local reg = fakeReg()
    local id = R.Notification.show({ Title = "t", Message = "m", Type = "success", Duration = 1000, Theme = t,
      Action = { Text = "Undo" }, AccentReg = reg.AccentReg })
    h.expect(reg.count).toBe(1)
    local toast = firstToast(root)
    -- swap tokens the way applyMode/SetAccent do (in place on theme.Colors), then fire the closure
    t.Colors.card = h.roblox.Color3.fromRGB(1, 2, 3)
    t.Colors.border = h.roblox.Color3.fromRGB(4, 5, 6)
    t.Colors.foreground = h.roblox.Color3.fromRGB(7, 8, 9)
    t.Colors.mutedForeground = h.roblox.Color3.fromRGB(10, 11, 12)
    t.Colors.primary = h.roblox.Color3.fromRGB(13, 14, 15)
    t.Colors.surface = h.roblox.Color3.fromRGB(16, 17, 18)
    t.Colors.success = h.roblox.Color3.fromRGB(19, 20, 21)
    reg.fire()
    local row = toast:FindFirstChild("TitleRow")
    h.expect(toast.BackgroundColor3).toBe(t.Colors.card)                              -- by identity
    expectEdge(toast:FindFirstChildOfClass("UIStroke"), t, t.Colors.success)
    h.expect(row:FindFirstChild("Title").TextColor3).toBe(t.Colors.foreground)
    h.expect(toast:FindFirstChild("Message").TextColor3).toBe(t.Colors.mutedForeground)
    h.expect(row:FindFirstChild("Close").ImageColor3).toBe(t.Colors.primary)
    h.expect(toast:FindFirstChild("Action").BackgroundColor3).toBe(t.Colors.surface)
    h.expect(toast:FindFirstChild("Action").TextColor3).toBe(t.Colors.foreground)
    h.expect(toast:FindFirstChild("Progress").BackgroundColor3).toBe(t.Colors.success)  -- accent = type colour
    h.expect(row:FindFirstChild("Icon").ImageColor3).toBe(t.Colors.success)
    -- parts replaced by update (new Progress bar, morphed type) are read live, not captured
    R.Notification.update(id, { Type = "error", Duration = 500 })
    t.Colors.destructive = h.roblox.Color3.fromRGB(22, 23, 24)
    reg.fire()
    h.expect(toast:FindFirstChild("Progress").BackgroundColor3).toBe(t.Colors.destructive)
    h.expect(row:FindFirstChild("Icon").ImageColor3).toBe(t.Colors.destructive)
    R.Notification.clearAll()
  end)

  h.it("AccentReg: a Message added by update is re-skinned too", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local t = R.Theme.new()
    local reg = fakeReg()
    local id = R.Notification.show({ Title = "t", Duration = 0, Theme = t, AccentReg = reg.AccentReg })
    R.Notification.update(id, { Message = "later" })
    t.Colors.mutedForeground = h.roblox.Color3.fromRGB(10, 11, 12)
    reg.fire()
    h.expect(firstToast(root):FindFirstChild("Message").TextColor3).toBe(t.Colors.mutedForeground)
    R.Notification.clearAll()
  end)

  h.it("AccentReg: dismiss releases the registration exactly once; clearAll releases every toast", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local reg = fakeReg()
    local id = R.Notification.show({ Title = "a", Duration = 0, AccentReg = reg.AccentReg })
    R.Notification.show({ Title = "b", Duration = 0, AccentReg = reg.AccentReg })
    R.Notification.show({ Title = "c", Duration = 0, AccentReg = reg.AccentReg })
    h.expect(reg.count).toBe(3)
    h.expect(reg.released).toBe(0)
    R.Notification.dismiss(id)
    h.expect(reg.released).toBe(1)
    R.Notification.dismiss(id)                 -- already gone: no double release
    h.expect(reg.released).toBe(1)
    R.Notification.clearAll()
    h.expect(reg.released).toBe(3)
  end)

  h.it("AccentReg: a timed toast releases its registration when the countdown expires", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local reg = fakeReg()
    R.Notification.show({ Title = "a", Duration = 1000, AccentReg = reg.AccentReg })
    h.mock.stepHeartbeat(1.2)
    h.expect(R.Notification.count()).toBe(0)
    h.expect(reg.released).toBe(1)
  end)

  h.it("AccentReg: promise forwards the registration to its loading toast", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local reg = fakeReg()
    R.Notification.promise(function() return 1 end, { Loading = "w", Success = "ok", AccentReg = reg.AccentReg })
    h.expect(reg.count).toBe(1)
    h.mock.stepHeartbeat(0)
    R.Notification.clearAll()
    h.expect(reg.released).toBe(1)
  end)

  h.it("loading spin is an endless Animate.spin loop; update cancels it before the new glyph lands", function()
    R.Notification.clearAll()
    h.mock.resetTweens()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local id = R.Notification.loading({ Title = "Saving" })
    local icon = firstToast(root):FindFirstChild("TitleRow"):FindFirstChild("Icon")
    local tw = h.mock.tweensFor(icon)[1]
    h.expect(tw ~= nil).toBeTruthy()
    h.expect(tw.Info.RepeatCount).toBe(-1)
    h.expect(tw.Goal.Rotation).toBe(360)
    h.expect(tw.cancelled).toBe(false)
    R.Notification.update(id, { Type = "success", Duration = 0 })
    h.expect(tw.cancelled).toBe(true)
    h.expect(icon.Rotation).toBe(0)
    h.expect(#h.mock.tweensFor(icon)).toBe(1)   -- no second spin for a non-loading type
    R.Notification.clearAll()
  end)

  h.it("dismiss cancels a running spin", function()
    R.Notification.clearAll()
    h.mock.resetTweens()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local id = R.Notification.loading({ Title = "Saving" })
    local tw = h.mock.tweensFor(firstToast(root):FindFirstChild("TitleRow"):FindFirstChild("Icon"))[1]
    R.Notification.dismiss(id)
    h.expect(tw.cancelled).toBe(true)
  end)

  h.it("reduced motion: no spin tween is created and the loader glyph rests at 0", function()
    h.withReducedMotion(R, function()
      R.Notification.clearAll()
      h.mock.resetTweens()
      local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
      R.Notification.loading({ Title = "Saving" })
      local icon = firstToast(root):FindFirstChild("TitleRow"):FindFirstChild("Icon")
      h.expect(#h.mock.tweensFor(icon)).toBe(0)
      h.expect(icon.Rotation).toBe(0)
      R.Notification.clearAll()
    end)
  end)

  h.it("window contract: SetMode re-skins live toasts (Notify + ShowLoading) via the window's AccentReg", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Notify({ Title = "t", Message = "m", Duration = 0 })
    w:ShowLoading({ Title = "l" })
    local light = R.Theme.PALETTES.light
    w:SetMode("light")
    local n = 0
    for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then
      for _, t in ipairs(c:GetChildren()) do if t.Name == "Toast" then
        n = n + 1
        h.expect(t.BackgroundColor3).toBe(light.card)
        expectEdge(t:FindFirstChildOfClass("UIStroke"), R.Theme, light.info, light.border)
        h.expect(t:FindFirstChild("TitleRow"):FindFirstChild("Title").TextColor3).toBe(light.foreground)
      end end end end
    h.expect(n).toBe(2)
    w:SetMode("dark")
    h.expect(firstToast(root).BackgroundColor3).toBe(R.Theme.PALETTES.dark.card)
    R.Notification.clearAll()
  end)

  h.it("Init twice: one Heartbeat step counts a timed toast down once (stale ticker disconnected)", function()
    R.Notification.clearAll()
    local base = h.mock.heartbeatHandlers()
    local R2 = h.loadLib()   -- re-runs Notification.Init on the same cached module (helper caches modules)
    local R3 = h.loadLib()
    h.expect(h.mock.heartbeatHandlers() <= base).toBeTruthy()   -- Init released the previous ticker
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R3.Overlay.get(gui)
    R3.Notification.show({ Title = "t", Duration = 1000 })
    local bar = firstToast(root):FindFirstChild("Progress")
    h.mock.stepHeartbeat(0.5)
    h.expect(bar.Size.X.Scale).toBeCloseTo(0.5, 0.01)   -- one ticker: 0.5 remaining, not 0
    h.expect(R3.Notification.count()).toBe(1)
    R3.Notification.clearAll()
  end)

  -- ---- visual-polish phase 2 (2.13 toast motion/depth, 2.7 close+action hover, 2.22 UI scale) ----
  local function toastCont(root)
    for _, c in ipairs(root:GetChildren()) do if c.Name == "ToastContainer" then return c end end
  end
  local function toastsOf(cont)
    local out = {}
    for _, c in ipairs(cont:GetChildren()) do if c.Name == "Toast" then out[#out + 1] = c end end
    return out   -- creation order == order[1..n] (oldest first)
  end

  h.it("entrance owns the pop: one Back/Out spring per axis, nothing fights it for the UIScale", function()
    R.Notification.clearAll(); h.mock.resetTweens()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.show({ Title = "x", Duration = 0 })
    local toast = firstToast(root)
    local us = toast:FindFirstChildOfClass("UIScale")
    local st = h.mock.tweensFor(us)
    h.expect(#st).toBe(1)                                             -- relayout no longer adds a rival tween
    h.expect(st[1].Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Back)
    h.expect(st[1].Goal.Scale).toBe(1)
    local pt = h.mock.tweensFor(toast)
    h.expect(pt[1].Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Back)   -- position springs home
    h.expect(pt[1].Goal.Position.X.Offset).toBe(0)
    h.expect(toast.GroupTransparency).toBe(0)                         -- faded in by the second tween
    R.Notification.clearAll()
  end)

  h.it("dismiss runs a real exit: shrink + fade + slide outward, then destroy", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local id = R.Notification.show({ Title = "x", Duration = 0 })
    local toast = firstToast(root)
    local us = toast:FindFirstChildOfClass("UIScale")
    local restX = toast.Position.X.Offset
    h.mock.resetTweens()
    R.Notification.dismiss(id)
    h.expect(R.Notification.count()).toBe(0)                          -- order slot freed synchronously
    local st = h.mock.tweensFor(us)
    h.expect(st[#st].Goal.Scale).toBe(R.Theme.Toast.exitScale)
    local ft = h.mock.tweensFor(toast)
    h.expect(#ft).toBe(1)                                             -- one tween for the card itself
    h.expect(ft[1].Goal.GroupTransparency).toBe(1)
    h.expect(ft[1].Goal.Position.X.Offset).toBe(restX + R.Theme.Toast.exitSlide)  -- bottom-right: outward = right
    h.expect(ft[1].Info.EasingDirection).toBe(h.roblox.Enum.EasingDirection.In)
    h.expect(firstToast(root)).toBeNil()                              -- destroyed once the fold-out finishes
  end)

  h.it("hover-expand staggers the rows, capped at Toast.staggerCap", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    for i = 1, 7 do R.Notification.show({ Title = "t" .. i, Duration = 0 }) end
    local cont = toastCont(root)
    local list = toastsOf(cont)
    h.expect(#list).toBe(7)
    h.mock.resetTweens()
    cont.MouseEnter:Fire()
    local M, TK = R.Theme.Motion, R.Theme.Toast
    local function delayOf(t) return h.mock.tweensFor(t)[1].Info.DelayTime end
    h.expect(delayOf(list[7])).toBe(0)                                -- front row opens immediately
    h.expect(delayOf(list[6])).toBeCloseTo(M.stagger)
    h.expect(delayOf(list[1])).toBeCloseTo(TK.staggerCap * M.stagger) -- i = 6, capped at 5 steps
    cont.MouseLeave:Fire()
    h.mock.resetTweens()
    R.Notification.show({ Title = "collapsed", Duration = 0 })
    h.expect(h.mock.tweensFor(firstToast(root))[1].Info.DelayTime).toBe(0)  -- collapsed stack never staggers
    R.Notification.clearAll()
  end)

  h.it("an AbsoluteSize measurement never re-tweens a toast that has not moved (2.13)", function()
    -- The engine fires AbsoluteSize as soon as it measures the AutomaticSize toast, and again on
    -- every frame of the entrance (AbsoluteSize includes the UIScale). A measurement-driven pass
    -- that re-issued the steady tweens would cancel the entrance's Back/Out overshoot and replace
    -- it with a Quint from a partial value. The mock never auto-fires property signals, so this
    -- has to set the property and fire it by hand.
    R.Notification.clearAll(); h.mock.resetTweens()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.show({ Title = "x", Duration = 0 })
    local toast = firstToast(root)
    local us = toast:FindFirstChildOfClass("UIScale")
    toast.AbsoluteSize = h.roblox.Vector2.new(360, 58)
    toast:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    toast.AbsoluteSize = h.roblox.Vector2.new(360, 60)
    toast:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    local st = h.mock.tweensFor(us)
    h.expect(#st).toBe(1)                                             -- still ONLY the entrance...
    h.expect(st[1].Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Back)   -- ...overshoot intact
    h.expect(#h.mock.tweensFor(toast)).toBe(2)                        -- entrance Position + fade only
    R.Notification.clearAll()
  end)

  h.it("a measurement while the stack is expanded never re-arms the stagger (2.13)", function()
    -- Rebuilt tweens used to carry delayTime up to staggerCap*stagger on EVERY measurement, so the
    -- back rows restarted their wait and stalled instead of fanning out. Only the expand pass
    -- itself may carry the delay.
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    for i = 1, 4 do R.Notification.show({ Title = "t" .. i, Duration = 0 }) end
    local cont = toastCont(root)
    local list = toastsOf(cont)
    cont.MouseEnter:Fire()                                            -- expand: this one staggers
    h.expect(h.mock.tweensFor(list[1])[#h.mock.tweensFor(list[1])].Info.DelayTime > 0).toBeTruthy()
    h.mock.resetTweens()
    -- a toast grows (AutomaticSize settles): the rows behind it genuinely move, at delay 0
    list[4]:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize = h.roblox.Vector2.new(360, 120)
    list[4].AbsoluteSize = h.roblox.Vector2.new(360, 120)
    list[4]:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    local back = h.mock.tweensFor(list[1])
    h.expect(#back > 0).toBeTruthy()                                  -- it really did have to move
    for _, tw in ipairs(back) do h.expect(tw.Info.DelayTime).toBe(0) end
    cont.MouseLeave:Fire()
    R.Notification.clearAll()
  end)

  h.it("success pops its glyph; error shakes the card and lands square at 0", function()
    R.Notification.clearAll(); h.mock.resetTweens()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.show({ Title = "ok", Type = "success", Duration = 0 })
    local icon = firstToast(root):FindFirstChild("TitleRow"):FindFirstChild("Icon")
    local iconScale = icon:FindFirstChildOfClass("UIScale")
    h.expect(iconScale ~= nil).toBeTruthy()          -- the pop scales a UIScale UNDER the glyph...
    h.expect(#h.mock.tweensFor(icon)).toBe(0)        -- ...never the glyph (its Rotation is the spinner's)
    h.expect(iconScale.Scale).toBe(1)
    R.Notification.clearAll(); h.mock.resetTweens()
    R.Notification.show({ Title = "bad", Type = "error", Duration = 0 })
    local toast = firstToast(root)
    local rots = {}
    for _, tw in ipairs(h.mock.tweensFor(toast)) do
      if tw.Goal.Rotation ~= nil then rots[#rots + 1] = tw.Goal.Rotation end
    end
    h.expect(#rots).toBe(3)
    h.expect(rots[1]).toBe(-R.Theme.Motion.shake.amp)
    h.expect(rots[2]).toBe(R.Theme.Motion.shake.amp)
    h.expect(rots[3]).toBe(0)
    h.expect(toast.Rotation).toBe(0)
    R.Notification.clearAll()
  end)

  h.it("reduced motion: the error shake creates no tween and the card stays square", function()
    h.withReducedMotion(R, function()
      R.Notification.clearAll(); h.mock.resetTweens()
      local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
      R.Notification.show({ Title = "bad", Type = "error", Duration = 0 })
      local toast = firstToast(root)
      h.expect(h.mock.tweenCount()).toBe(0)
      h.expect(toast.GroupTransparency).toBe(0)      -- entrance applied instantly
      h.expect(toast.Rotation).toBeNil()             -- never rotated at all
      R.Notification.clearAll()
      h.expect(toast.Parent).toBeNil()               -- exit is instant too
    end)
  end)

  h.it("type tint: the border mixes toward the type colour and the glyph sits in a tinted badge", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local id = R.Notification.show({ Title = "e", Type = "error", Duration = 0 })
    local toast = firstToast(root)
    expectEdge(toast:FindFirstChildOfClass("UIStroke"), R.Theme, R.Theme.Colors.destructive)
    local badge = toast:FindFirstChild("TitleRow"):FindFirstChild("IconBadge")
    h.expect(badge.BackgroundColor3).toBe(R.Theme.Colors.destructive)
    h.expect(badge.BackgroundTransparency).toBe(R.Theme.Toast.badgeAlpha)
    h.expect(badge.ZIndex).toBe(0)                    -- renders under its sibling glyph
    R.Notification.update(id, { Type = "success" })   -- a morph retints border + badge
    expectEdge(toast:FindFirstChildOfClass("UIStroke"), R.Theme, R.Theme.Colors.success)
    h.expect(badge.BackgroundColor3).toBe(R.Theme.Colors.success)
    R.Notification.clearAll()
  end)

  h.it("Progress stays a direct child of the toast and the padding hugs it to the edge", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    local id = R.Notification.show({ Title = "t", Type = "success", Duration = 1000 })
    local toast = firstToast(root)
    local bar = toast:FindFirstChild("Progress")
    h.expect(bar.Parent).toBe(toast)                                 -- no track wrapper, no sibling row
    h.expect(bar.Size.Y.Offset).toBe(R.Theme.Toast.barHeight)
    local pad = toast:FindFirstChildOfClass("UIPadding")
    h.expect(pad.PaddingTop.Offset).toBe(R.Theme.Toast.padY)
    h.expect(pad.PaddingBottom.Offset).toBe(R.Theme.Toast.progressInset)
    R.Notification.update(id, { Duration = 0 })                      -- bar gone -> padding restored
    h.expect(toast:FindFirstChild("Progress")).toBeNil()
    h.expect(pad.PaddingBottom.Offset).toBe(R.Theme.Toast.padY)
    R.Notification.clearAll()
  end)

  h.it("Close and Action answer hover/press; the close glyph still dismisses", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.show({ Title = "t", Duration = 0, Action = { Text = "Undo" } })
    local toast = firstToast(root)
    local row = toast:FindFirstChild("TitleRow")
    local hit = row:FindFirstChild("CloseHit")
    h.expect(hit ~= nil).toBeTruthy()                                -- comfortable sibling target
    h.expect(hit.Size.X.Offset).toBe(R.Theme.Sizes.iconButton)
    local wash = hit:FindFirstChild("Hover")
    h.expect(wash.BackgroundTransparency).toBe(1)
    hit.MouseEnter:Fire()
    h.expect(wash.BackgroundTransparency).toBe(R.Theme.Opacity.hoverWash)
    local action = toast:FindFirstChild("Action")
    local aw = action:FindFirstChild("Hover")
    action.MouseEnter:Fire()
    h.expect(aw.BackgroundTransparency).toBe(R.Theme.Opacity.hoverWash)
    action.MouseButton1Down:Fire()
    h.expect(aw.BackgroundTransparency).toBe(R.Theme.Opacity.pressWash)
    row:FindFirstChild("Close").MouseButton1Click:Fire()              -- handler still bound to the glyph
    h.expect(R.Notification.count()).toBe(0)
  end)

  h.it("the countdown Heartbeat stops with the last toast and reconnects on the next one", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local base = h.mock.heartbeatHandlers()
    local id = R.Notification.show({ Title = "t", Duration = 1000 })
    h.expect(h.mock.heartbeatHandlers()).toBe(base + 1)
    R.Notification.dismiss(id)
    h.expect(h.mock.heartbeatHandlers()).toBe(base)                   -- released with the stack
    R.Notification.show({ Title = "u", Duration = 1000 })
    h.expect(h.mock.heartbeatHandlers()).toBe(base + 1)               -- reconnected lazily by show
    R.Notification.clearAll()
    h.expect(h.mock.heartbeatHandlers()).toBe(base)
  end)

  h.it("StackShadow: absent while shadowId is empty; a ZIndex 0 sibling once an asset is set", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.show({ Title = "a", Duration = 0 })
    local cont = toastCont(root)
    h.expect(cont:FindFirstChild("StackShadow")).toBeNil()            -- default theme: shadows off
    R.Notification.clearAll()
    local t = R.Theme.new({ Effect = { shadowId = "rbxassetid://1" } })
    R.Notification.show({ Title = "b", Duration = 0, Theme = t })
    local sh = cont:FindFirstChild("StackShadow")
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.Parent).toBe(cont)                                    -- sibling of the toasts...
    h.expect(sh.ZIndex).toBe(0)                                       -- ...below their default ZIndex 1
    h.expect(sh.Visible).toBe(false)                                  -- Absolute* unmeasured headless
    local toast = firstToast(root)
    cont.AbsolutePosition = h.roblox.Vector2.new(10, 20)
    toast.AbsolutePosition = h.roblox.Vector2.new(110, 220)
    toast.AbsoluteSize = h.roblox.Vector2.new(300, 60)
    R.Notification.relayout()
    h.expect(sh.Visible).toBe(true)
    h.expect(sh.Size.X.Offset).toBe(300 + 2 * R.Theme.Effect.toast.spread)
    h.expect(sh.Position.X.Offset).toBe(100 + 150)                    -- host centre in container space
    R.Notification.clearAll()
  end)

  h.it("setScale scales the toast container, never the overlay root", function()
    R.Notification.clearAll()
    local gui = h.roblox.Instance.new("ScreenGui"); local root = R.Overlay.get(gui)
    R.Notification.setScale(1.3)
    R.Notification.show({ Title = "x", Duration = 0 })
    local cont = toastCont(root)
    h.expect(cont:FindFirstChildOfClass("UIScale").Scale).toBe(1.3)
    h.expect(root:FindFirstChildOfClass("UIScale")).toBeNil()         -- catcher must keep covering the screen
    h.expect(cont.Size.X.Offset).toBe(R.Theme.Toast.width)            -- width stays logical px
    R.Notification.setScale(1)                                        -- restore process-wide state
    h.expect(cont:FindFirstChildOfClass("UIScale").Scale).toBe(1)
    R.Notification.clearAll()
  end)
end)
h.run()
