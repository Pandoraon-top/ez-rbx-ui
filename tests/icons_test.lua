local h = require("tests.helper")
local Icons = h.requireModule("core.icons")
local mock = h.mock
local Color3 = h.roblox.Color3
local Instance = h.roblox.Instance

-- Records every property WRITE made through the proxy while reads fall through to the real
-- mock instance, so a test can assert exactly which properties apply() touched.
local function spy(inst)
  local writes = {}
  local proxy = setmetatable({}, {
    __index = function(_, k) return inst[k] end,
    __newindex = function(_, k, v) writes[#writes + 1] = k; inst[k] = v end,
  })
  return proxy, writes
end

h.describe("icons", function()
  h.it("curated set includes chrome icons", function()
    h.expect(Icons.data["chevron-right"] ~= nil).toBeTruthy()
    h.expect(Icons.data["home"] ~= nil).toBeTruthy()
  end)
  h.it("house alias resolves to home", function()
    h.expect(Icons.data["house"]).toBeNil()       -- not a raw data key
    h.expect(Icons.get("house") ~= nil).toBeTruthy() -- but get() aliases it
  end)
  h.it("get returns rbxassetid + both rect props", function()
    local a = Icons.get("house")
    h.expect(tostring(a.Id):sub(1, 13)).toBe("rbxassetid://")
    h.expect(a.ImageRectSize.X).toBe(48)
  end)
  h.it("apply sets image + tint, returns true", function()
    local img = Instance.new("ImageLabel")
    local ok = Icons.apply(img, "play", Color3.fromRGB(250, 250, 250))
    h.expect(ok).toBeTruthy()
    h.expect(img.ImageColor3.R8).toBe(250)
    h.expect(img.ImageRectOffset ~= nil).toBeTruthy()
  end)
  h.it("unknown icon returns nil/false", function()
    h.expect(Icons.get("definitely-not-an-icon")).toBeNil()
    local img = Instance.new("ImageLabel")
    h.expect(Icons.apply(img, "definitely-not-an-icon")).toBe(false)
  end)
end)

h.describe("icons apply fast-path", function()
  h.it("re-applying the same icon only writes ImageColor3 (Image/rects untouched, no tween)", function()
    local img = Instance.new("ImageLabel")
    local proxy, writes = spy(img)
    Icons.apply(proxy, "play", Color3.fromRGB(1, 2, 3))
    h.expect(#writes >= 4).toBeTruthy() -- first apply: Image + both rects + tint
    local imageBefore, rectBefore = img.Image, img.ImageRectOffset
    local tweensBefore = mock.tweenCount()
    for i = #writes, 1, -1 do writes[i] = nil end
    local c2 = Color3.fromRGB(9, 9, 9)
    h.expect(Icons.apply(proxy, "play", c2)).toBeTruthy()
    h.expect(writes).toEqual({ "ImageColor3" })    -- fast path: only the tint
    h.expect(img.Image).toBe(imageBefore)
    h.expect(img.ImageRectOffset).toBe(rectBefore) -- same Vector2 object: never rewritten
    h.expect(img.ImageColor3).toBe(c2)
    h.expect(mock.tweenCount()).toBe(tweensBefore) -- apply stays synchronous
  end)
  h.it("fast path is skipped when the sprite differs (rewrites Image + rects)", function()
    local img = Instance.new("ImageLabel")
    Icons.apply(img, "play", Color3.fromRGB(1, 2, 3))
    local offBefore = img.ImageRectOffset
    local proxy, writes = spy(img)
    Icons.apply(proxy, "home", Color3.fromRGB(1, 2, 3))
    h.expect(writes).toEqual({ "Image", "ImageRectSize", "ImageRectOffset", "ImageColor3" })
    h.expect(img.ImageRectOffset ~= offBefore).toBeTruthy()
    h.expect(img.ImageRectOffset.X == Icons.data["home"].x and img.ImageRectOffset.Y == Icons.data["home"].y).toBeTruthy()
  end)
  h.it("apply without a colour on a matching sprite writes nothing", function()
    local img = Instance.new("ImageLabel")
    Icons.apply(img, "play")
    local proxy, writes = spy(img)
    h.expect(Icons.apply(proxy, "play")).toBeTruthy()
    h.expect(writes).toEqual({})
  end)
end)

-- Registered BEFORE the Init-based tests: bodies run in registration order (h.run), so this
-- observes the module before any test injects Animate.
h.describe("icons tint (no Animate injected)", function()
  h.it("writes ImageColor3 directly and records no tween", function()
    local img = Instance.new("ImageLabel")
    local before = mock.tweenCount()
    local c = Color3.fromRGB(4, 5, 6)
    Icons.tint(img, c)
    h.expect(img.ImageColor3).toBe(c)
    h.expect(mock.tweenCount()).toBe(before)
  end)
  h.it("nil colour is a no-op", function()
    local img = Instance.new("ImageLabel")
    h.expect(Icons.tint(img, nil)).toBeNil()
    h.expect(img.ImageColor3).toBeNil()
  end)
end)

h.describe("icons tint (Animate injected)", function()
  -- Minimal registry mirroring main.lua's Init pattern: modules only capture references.
  local R
  local function lib()
    if R then return R end
    R = { Theme = h.requireModule("core/theme"), Animate = h.requireModule("core/animate"), Icons = Icons }
    R.Animate.Init(R); R.Icons.Init(R)
    return R
  end
  h.it("records a tween with the ImageColor3 goal at Motion.fast", function()
    local R = lib()
    local img = Instance.new("ImageLabel")
    mock.resetTweens()
    local c = Color3.fromRGB(7, 8, 9)
    local tw = Icons.tint(img, c)
    h.expect(mock.tweenCount()).toBe(1)
    h.expect(mock.lastTween).toBe(tw)
    h.expect(mock.lastTween.Instance).toBe(img)
    h.expect(mock.lastTween.Goal.ImageColor3).toBe(c)
    h.expect(mock.lastTween.Info.Time).toBe(R.Theme.Motion.fast)
    h.expect(img.ImageColor3).toBe(c) -- mock plays synchronously
  end)
  h.it("honours an explicit duration token or number", function()
    local R = lib()
    local img = Instance.new("ImageLabel")
    mock.resetTweens()
    Icons.tint(img, Color3.fromRGB(1, 1, 1), "slow")
    h.expect(mock.lastTween.Info.Time).toBe(R.Theme.Motion.slow)
    Icons.tint(img, Color3.fromRGB(2, 2, 2), 0.5)
    h.expect(mock.lastTween.Info.Time).toBe(0.5)
    h.expect(mock.tweenCount()).toBe(2)
  end)
  h.it("applies instantly with no tween under reduced motion", function()
    local R = lib()
    h.withReducedMotion(R, function()
      local img = Instance.new("ImageLabel")
      mock.resetTweens()
      local c = Color3.fromRGB(3, 3, 3)
      Icons.tint(img, c)
      h.expect(mock.tweenCount()).toBe(0)
      h.expect(img.ImageColor3).toBe(c)
    end)
  end)
  h.it("apply still writes ImageColor3 synchronously after Init (no tween)", function()
    lib()
    local img = Instance.new("ImageLabel")
    Icons.apply(img, "play", Color3.fromRGB(1, 1, 1))
    mock.resetTweens()
    local c = Color3.fromRGB(2, 2, 2)
    Icons.apply(img, "play", c)
    h.expect(img.ImageColor3).toBe(c)
    h.expect(mock.tweenCount()).toBe(0)
  end)
end)

h.run()
