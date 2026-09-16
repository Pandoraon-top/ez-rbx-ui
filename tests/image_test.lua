local h = require("tests.helper")
local R = h.loadLib(); local Image, Create = R.Image, R.Create
h.describe("image", function()
  h.it("sets rbxassetid image", function()
    local i = Image.new({ Parent = Create("Frame", {}), Image = "rbxassetid://123", LayoutOrder = 1 })
    h.expect(i.Frame.Image).toBe("rbxassetid://123")
    h.expect(i.Frame.ClassName).toBe("ImageLabel")
  end)
  h.it("Lucide name resolves via Icons", function()
    local i = Image.new({ Lucide = "home" })
    h.expect(tostring(i.Frame.Image):sub(1, 13)).toBe("rbxassetid://")
  end)
  h.it("SetImage defers the image write when capability is absent", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local im = R.Image.new({ Image = "rbxassetid://1", Parent = R.Create("Frame", {}) })
    R.Safe._setCapabilityCheck(function() return false end)
    im.SetImage("rbxassetid://2")
    h.expect(im.Frame.Image).toBe("rbxassetid://1")   -- deferred: not applied yet (fails before the wrap)
    h.mock.stepHeartbeat(0)
    h.expect(im.Frame.Image).toBe("rbxassetid://2")   -- applied in a capability context
    R.Safe._setCapabilityCheck(nil)
  end)
  h.it("a Lucide glyph is re-tinted to foreground by the reskin closure; Destroy unregisters", function()
    local fns, unregs = {}, 0
    local reg = function(fn) fns[#fns + 1] = fn; return function() unregs = unregs + 1 end end
    local i = Image.new({ Lucide = "home", AccentReg = reg })
    h.expect(#fns).toBe(1)
    i.Frame.ImageColor3 = h.roblox.Color3.fromRGB(1, 2, 3)
    fns[1]("mode")
    h.expect(i.Frame.ImageColor3).toBe(R.Theme.Colors.foreground)
    i.Destroy()
    h.expect(unregs).toBe(1)
  end)
  h.it("an explicit Color is kept across reskin", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local tint = h.roblox.Color3.fromRGB(9, 8, 7)
    local i = Image.new({ Lucide = "home", Color = tint, AccentReg = reg })
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(i.Frame.ImageColor3).toBe(tint)
  end)
end)

-- Plan 3.1 (skeleton in the slot) + 3.8 (fade in on IsLoaded). The mock leaves IsLoaded unset
-- (nil) by default = loaded; mock.imagesLoaded = false models an asset still decoding, and the
-- test flips IsLoaded then fires the property signal itself (signals never auto-fire).
h.describe("image loading", function()
  local M = R.Theme.Motion
  -- Timers are QUEUED throughout this block: a wait arms a give-up deadline, and the default
  -- 'immediate' mode runs task.delay synchronously, which would expire it at construction and
  -- tear the block down before the test can see it.
  local function withUnloadedImages(fn)
    h.mock.imagesLoaded = false
    local ok, err = pcall(h.withQueuedTimers, fn)
    h.mock.imagesLoaded = nil
    if not ok then error(err, 0) end
  end
  -- resolvable (the executor globals are all there) but the download yields no content id, so
  -- Asset.imageAsync -- which only ever reports success -- never calls back at all.
  local function withDeadFetch(fn)
    h.roblox.getcustomasset = function() return nil end
    local ok, err = pcall(h.withQueuedTimers, fn)
    h.roblox.getcustomasset = nil
    if not ok then error(err, 0) end
  end
  local function load(img)
    img.IsLoaded = true
    img:GetPropertyChangedSignal("IsLoaded"):Fire()
  end

  h.it("an image that is already loaded gets no skeleton and no fade (3.1/3.8)", function()
    h.mock.resetTweens()
    local i = Image.new({ Parent = Create("Frame", {}), Image = "rbxassetid://123" })
    h.expect(i.Frame.Image).toBe("rbxassetid://123")   -- the raw id, not a placeholder
    h.expect(i.Frame:FindFirstChild("Skeleton")).toBeNil()
    h.expect(h.mock.tweenCount()).toBe(0)
    h.expect(i.Frame.ImageTransparency).toBeNil()      -- never written: nothing to reveal
  end)

  h.it("holds a skeleton block in the slot while the pixels are missing (3.1)", function()
    withUnloadedImages(function()
      local i = Image.new({ Parent = Create("Frame", {}), Image = "rbxassetid://123" })
      local img = i.Frame
      h.expect(img.ClassName).toBe("ImageLabel")
      h.expect(img.Image).toBe("rbxassetid://123")     -- the id is written even while it decodes
      h.expect(img.ImageTransparency).toBe(1)
      local sk = img:FindFirstChild("Skeleton")
      h.expect(sk ~= nil).toBeTruthy()
      h.expect(sk.BackgroundColor3).toBe(R.Theme.Colors.surface)
      h.expect(sk:FindFirstChildOfClass("UICorner").CornerRadius.Offset).toBe(R.Theme.Radius.sm)
      h.expect(sk:FindFirstChildOfClass("UIGradient") ~= nil).toBeTruthy()
    end)
  end)

  h.it("the IsLoaded flip stops the skeleton and fades the image in (3.1/3.8)", function()
    withUnloadedImages(function()
      local parent = Create("Frame", {})
      local i = Image.new({ Parent = parent, Image = "rbxassetid://123" })
      local img = i.Frame
      local shimmer = h.mock.tweensFor(img:FindFirstChild("Skeleton"):FindFirstChildOfClass("UIGradient"))[1]
      h.mock.resetTweens()
      load(img)
      h.expect(img:FindFirstChild("Skeleton")).toBeNil()
      h.expect(shimmer.cancelled).toBe(true)
      local fade = h.mock.tweensFor(img)[1]
      h.expect(fade ~= nil).toBeTruthy()
      h.expect(fade.Goal.ImageTransparency).toBe(0)
      h.expect(fade.Info.Time).toBe(M.base)
      h.expect(img.ImageTransparency).toBe(0)
      h.mock.resetTweens()
      load(img)                                        -- a second flip is inert (disconnected)
      h.expect(h.mock.tweenCount()).toBe(0)
    end)
  end)

  h.it("a Lucide glyph waits on the same gate (3.1)", function()
    withUnloadedImages(function()
      local i = Image.new({ Parent = Create("Frame", {}), Lucide = "home" })
      h.expect(i.Frame:FindFirstChild("Skeleton") ~= nil).toBeTruthy()
      h.expect(tostring(i.Frame.Image):sub(1, 13)).toBe("rbxassetid://")
      load(i.Frame)
      h.expect(i.Frame:FindFirstChild("Skeleton")).toBeNil()
      h.expect(i.Frame.ImageTransparency).toBe(0)
    end)
  end)

  h.it("reduced motion: a static block, then an instant reveal with no tween (3.1/3.8)", function()
    withUnloadedImages(function()
      h.withReducedMotion(R, function()
        local i = Image.new({ Parent = Create("Frame", {}), Image = "rbxassetid://123" })
        local img = i.Frame
        h.mock.resetTweens()
        h.expect(img:FindFirstChild("Skeleton") ~= nil).toBeTruthy()
        h.expect(h.mock.tweenCount()).toBe(0)
        load(img)
        h.expect(img:FindFirstChild("Skeleton")).toBeNil()
        h.expect(img.ImageTransparency).toBe(0)
        h.expect(h.mock.tweenCount()).toBe(0)
      end)
    end)
  end)

  h.it("Destroy while still loading drops the block and the IsLoaded handler (3.1)", function()
    withUnloadedImages(function()
      local parent = Create("Frame", {})
      local i = Image.new({ Parent = parent, Image = "rbxassetid://123" })
      local img = i.Frame
      i.Destroy()
      h.expect(img.Parent).toBeNil()
      h.expect(parent:FindFirstChild("Image")).toBeNil()
      h.mock.resetTweens()
      load(img)                                        -- late signal on a dead control: no work
      h.expect(h.mock.tweenCount()).toBe(0)
    end)
  end)

  -- A fetch can end three ways, and each one has to leave the slot in a sane state.
  h.it("a download that fails reports at once: no block is ever flashed up (3.1)", function()
    withDeadFetch(function()
      h.mock.resetTweens()
      local i = Image.new({ Parent = Create("Frame", {}), Image = "https://example.com/dead.png" })
      local img = i.Frame
      -- Asset.imageAsync now calls onFail, so the wait is over before the holder is even armed:
      -- an instantly-dead URL must not blink a shimmer into existence just to destroy it.
      h.expect(img:FindFirstChild("Skeleton")).toBeNil()
      -- never armed, so the fade never wrote the property: nil here is the mock reporting the
      -- engine default. What matters is that the slot is not pinned invisible.
      h.expect(img.ImageTransparency ~= 1).toBeTruthy()
      h.expect(h.mock.timerCount()).toBe(0)            -- nothing left to wait for
    end)
  end)

  -- A resolve that neither succeeds nor reports (a sprite that never decodes) is the one case
  -- nobody can signal, so the deadline is what ends it. Stubbing imageAsync is the only way to
  -- model it: under the mock task.spawn runs inline, so a real fetch always settles synchronously.
  local function withPendingFetch(fn)
    local real = R.Asset.imageAsync
    R.Asset.imageAsync = function() end               -- never calls back, never fails
    -- Asset.resolvable gates the holder, and for an http URL it needs the executor file API to
    -- look present; without this the slot is never armed and there is nothing to test.
    h.roblox.getcustomasset = function() return nil end
    local ok, err = pcall(h.withQueuedTimers, fn)
    h.roblox.getcustomasset = nil
    R.Asset.imageAsync = real
    if not ok then error(err, 0) end
  end

  h.it("a resolve that never settles gives up on the deadline instead of shimmering forever (3.1)", function()
    withPendingFetch(function()
      local i = Image.new({ Parent = Create("Frame", {}), Image = "https://example.com/never.png" })
      local img = i.Frame
      local sk = img:FindFirstChild("Skeleton")
      h.expect(sk ~= nil).toBeTruthy()                 -- an id was expected; none arrived
      h.expect(img.Image).toBe("")
      h.expect(img.ImageTransparency).toBe(1)
      local shimmer = h.mock.tweensFor(sk:FindFirstChildOfClass("UIGradient"))[1]
      h.expect(shimmer.Info.RepeatCount).toBe(-1)      -- endless, so something must end it
      h.expect(h.mock.timerCount()).toBe(1)            -- ...and that is the deadline the wait arms
      h.mock.advance(60)
      h.expect(img:FindFirstChild("Skeleton")).toBeNil()
      h.expect(shimmer.cancelled).toBe(true)
      h.expect(img.ImageTransparency).toBe(0)          -- a blank slot, as before 3.1 -- never a pinned one
    end)
  end)

  h.it("SetImage during a pending resolve takes the slot and is actually visible (3.1)", function()
    withPendingFetch(function()
      local i = Image.new({ Parent = Create("Frame", {}), Image = "https://example.com/taken.png" })
      local img = i.Frame
      local sk = img:FindFirstChild("Skeleton")
      h.expect(sk ~= nil).toBeTruthy()
      local shimmer = h.mock.tweensFor(sk:FindFirstChildOfClass("UIGradient"))[1]
      i.SetImage("rbxassetid://99")
      h.expect(img.Image).toBe("rbxassetid://99")
      h.expect(img:FindFirstChild("Skeleton")).toBeNil()   -- the placeholder has nothing left to hold
      h.expect(shimmer.cancelled).toBe(true)
      h.expect(img.ImageTransparency).toBe(0)              -- ...and the caller's image is not hidden under it
      h.mock.advance(60)                                   -- the deadline finds the wait already over
      h.expect(img.Image).toBe("rbxassetid://99")
      h.expect(img.ImageTransparency).toBe(0)
    end)
  end)
end)
h.run()