-- Minimal Roblox API surface for headless logic tests.
local M = {}
M.strict = false -- when true (verify-bundle), validate cross-class property writes like Roblox
M.mock = nil     -- per-run mock table (set by installInto); newInstance reads mock.imagesLoaded

-- ---- strict property allowlists ---------------------------------------------------------
-- Writing a property on a class that lacks it throws in real Roblox ("X is not a valid member
-- of <Class>"); the lenient mock would store it. Each rule maps a property to the SET of
-- classes that own it, so a property shared by several classes (Rotation on any GuiObject
-- *and* UIGradient, Color on UIStroke *and* UIGradient) stays valid on all of them. Enabled
-- only in strict mode so unit tests stay terse.
local function set(list) local t = {} for _, n in ipairs(list) do t[n] = true end return t end
local function union(a, b) local t = {} for k in pairs(a) do t[k] = true end for k in pairs(b) do t[k] = true end return t end
local GUI_OBJECTS = set({ "Frame", "ScrollingFrame", "CanvasGroup", "TextLabel", "TextButton", "TextBox",
  "ImageLabel", "ImageButton", "ViewportFrame", "VideoFrame" })
local TEXT_CLASSES = set({ "TextLabel", "TextButton", "TextBox" })
local IMAGE_CLASSES = set({ "ImageLabel", "ImageButton" })
local BTN_CLASSES = set({ "TextButton", "ImageButton" })
local SCROLL_CLASSES = set({ "ScrollingFrame" })

local RULES = {}
local function rule(props, classes) for _, p in ipairs(props) do RULES[p] = classes end end
rule({ "Text", "TextColor3", "TextSize", "TextWrapped", "TextXAlignment", "TextYAlignment", "TextTruncate", "RichText",
  "TextScaled", "LineHeight", "Font", "FontFace", "TextTransparency", "MaxVisibleGraphemes" }, TEXT_CLASSES)
-- TextBox-only: a TextLabel/TextButton has no placeholder, caret or editability
rule({ "PlaceholderText", "PlaceholderColor3", "ClearTextOnFocus", "TextEditable", "CursorPosition", "MultiLine" },
  set({ "TextBox" }))
rule({ "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType", "ResampleMode",
  "SliceCenter", "SliceScale", "TileSize" }, IMAGE_CLASSES)
rule({ "AutoButtonColor", "Modal", "Style" }, BTN_CLASSES)
rule({ "Offset" }, set({ "UIGradient" }))
rule({ "Rotation" }, union(GUI_OBJECTS, set({ "UIGradient" })))
rule({ "Color", "Transparency" }, set({ "UIStroke", "UIGradient" }))
rule({ "Thickness", "ApplyStrokeMode", "LineJoinMode" }, set({ "UIStroke" }))
rule({ "GroupTransparency", "GroupColor3" }, set({ "CanvasGroup" }))
rule({ "Scale" }, set({ "UIScale" }))
rule({ "CanvasSize", "CanvasPosition", "AbsoluteWindowSize", "AutomaticCanvasSize", "ScrollingDirection",
  "ScrollingEnabled", "ElasticBehavior" }, SCROLL_CLASSES) -- every ScrollBar* prop too (prefix rule in validateProp)
rule({ "CornerRadius" }, set({ "UICorner" }))
rule({ "MinSize", "MaxSize" }, set({ "UISizeConstraint" }))
rule({ "SelectionImageObject" }, GUI_OBJECTS)

local function validateProp(cls, k)
  if not M.strict or type(k) ~= "string" or not cls then return end
  local allowed = RULES[k] or (k:sub(1, 9) == "ScrollBar" and SCROLL_CLASSES) or nil
  if allowed and not allowed[cls] then error(k .. " is not a valid member of " .. cls, 3) end
end

-- Signals that exist on mock instances (created lazily on first read). Any other unset
-- member reads as nil, except `_`-prefixed names which throw (see __index).
local EVENTS = set({ "MouseButton1Click", "MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged",
  "Activated", "Completed", "MouseButton1Down", "MouseButton1Up", "Changed", "FocusLost", "Focused",
  "SelectionGained", "SelectionLost", "Destroying", "MouseMoved" })

local function enumNs(names)
  local ns = {}
  for _, n in ipairs(names) do ns[n] = { Name = n, EnumType = true } end
  return ns
end

local function makeSignal()
  local handlers = {}
  local sig = {}
  -- tagged so mock typeof() reports "RBXScriptConnection" (real events return userdata)
  function sig:Connect(fn) handlers[fn] = true; return { __isConnection = true, Disconnect = function() handlers[fn] = nil end } end
  function sig:Once(fn) local c; c = sig:Connect(function(...) c.Disconnect(); fn(...) end); return c end
  -- Snapshot handlers before dispatch (like a real RBXScriptSignal): a handler may connect or
  -- disconnect during the fire (e.g. Heartbeat:Once flush, or a deferred build that connects a
  -- new Heartbeat handler) without breaking iteration. Handlers disconnected before their turn
  -- are skipped; handlers connected during the fire run on the next fire, not this one.
  function sig:Fire(...)
    local snap, i = {}, 0
    for fn in pairs(handlers) do i = i + 1; snap[i] = fn end
    for k = 1, i do local fn = snap[k]; if handlers[fn] then fn(...) end end
  end
  -- test-only accessor: live handler count (mock.heartbeatHandlers() leak assertions)
  function sig:__count() local n = 0; for _ in pairs(handlers) do n = n + 1 end; return n end
  return sig
end
M.makeSignal = makeSignal

local function newInstance(cls)
  local children = {}
  local props = { ClassName = cls }
  local signals = {}
  -- mock.imagesLoaded=false models an asset still downloading: images are born with
  -- IsLoaded=false and the test flips IsLoaded then fires GetPropertyChangedSignal("IsLoaded")
  -- itself (property signals never auto-fire). nil keeps today's behaviour (IsLoaded unset).
  if IMAGE_CLASSES[cls] and M.mock and M.mock.imagesLoaded ~= nil then props.IsLoaded = M.mock.imagesLoaded end
  local inst
  local function destroy()
    if props._destroyed then return end -- Roblox: Destroy on a destroyed Instance is a no-op
    props._destroyed = true
    if signals.Destroying then signals.Destroying:Fire() end
    if props.Parent and props.Parent.__removeChild then props.Parent.__removeChild(inst) end
    props.Parent = nil
    -- Roblox tears down the whole subtree: every descendant loses its Parent and fires its own
    -- Destroying, so liveness checks (frame.Parent == nil) and per-control Destroying cleanups
    -- behave like production. Iterate a snapshot: each child's Destroy() removes it from `children`.
    local snap = {}
    for i, c in ipairs(children) do snap[i] = c end
    for _, c in ipairs(snap) do c:Destroy() end
    for i = #children, 1, -1 do children[i] = nil end
  end
  inst = setmetatable({}, {
    __index = function(_, k)
      if props[k] ~= nil then return props[k] end
      if k == "GetChildren" then return function() local t = {} for i, c in ipairs(children) do t[i] = c end return t end end
      if k == "FindFirstChild" then return function(_, name) for _, c in ipairs(children) do if c.Name == name then return c end end end end
      if k == "FindFirstChildOfClass" then return function(_, c2) for _, c in ipairs(children) do if c.ClassName == c2 then return c end end end end
      if k == "IsA" then return function(_, c2) return props.ClassName == c2 end end
      if k == "Destroy" then return destroy end
      if k == "SetAttribute" then return function(_, ak, av) props["_attr_" .. ak] = av end end
      if k == "GetAttribute" then return function(_, ak) return props["_attr_" .. ak] end end
      -- cached per (instance, prop); never auto-fires — tests set the prop then :Fire() themselves
      if k == "GetPropertyChangedSignal" then return function(_, p) signals["chg_" .. p] = signals["chg_" .. p] or makeSignal(); return signals["chg_" .. p] end end
      -- event fields created on demand
      if EVENTS[k] then signals[k] = signals[k] or makeSignal(); return signals[k] end
      -- Roblox throws when reading an invalid member. Underscore-prefixed names are
      -- never valid Roblox members, so reading an UNSET one is a mock-ism leaking into
      -- production code (e.g. root._destroyed). Throw to catch it, like Roblox would.
      if type(k) == "string" and k:sub(1, 1) == "_" then
        error(tostring(k) .. " is not a valid member (mock strict: unset internal field read)", 2)
      end
      return nil
    end,
    __newindex = function(_, k, v)
      validateProp(props.ClassName, k)
      if k == "Parent" then
        if props.Parent and props.Parent.__removeChild then props.Parent.__removeChild(inst) end
        props.Parent = v
        if v and v.__addChild then v.__addChild(inst) end
      else
        props[k] = v
      end
    end,
  })
  rawset(inst, "__addChild", function(c) children[#children + 1] = c end)
  rawset(inst, "__removeChild", function(c)
    for i = #children, 1, -1 do if children[i] == c then table.remove(children, i) end end
  end)
  rawset(inst, "__isInstance", true) -- so mock typeof() reports "Instance"
  return inst
end

function M.installInto(env, mock, strict)
  M.strict = strict or false
  M.mock = mock
  env.Color3 = {
    fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, R8 = r, G8 = g, B8 = b } end,
    new = function(r, g, b) return { R = r, G = g, B = b, R8 = math.floor((r or 0) * 255), G8 = math.floor((g or 0) * 255), B8 = math.floor((b or 0) * 255) } end,
    fromHSV = function(h, s, v)
      -- real Roblox returns an RGB Color3; compute it so .R/.G/.B exist
      local r, g, b
      local i = math.floor(h * 6); local f = h * 6 - i
      local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
      i = i % 6
      if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
      elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
      return { R = r, G = g, B = b, R8 = math.floor(r * 255 + 0.5), G8 = math.floor(g * 255 + 0.5), B8 = math.floor(b * 255 + 0.5) }
    end,
  }
  env.Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
  env.UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
  env.UDim2 = { new = function(xs, xo, ys, yo) return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } } end }
  env.Rect = { new = function(x0, y0, x1, y1) return { Min = { X = x0, Y = y0 }, Max = { X = x1, Y = y1 } } end }
  env.Enum = {
    Font = enumNs({ "BuilderSans", "SourceSans", "Gotham" }),
    FontWeight = enumNs({ "Regular", "Medium", "SemiBold", "Bold" }),
    FontStyle = enumNs({ "Normal", "Italic" }),
    EasingStyle = enumNs({ "Quart", "Quint", "Linear", "Sine", "Back", "Quad", "Cubic", "Exponential", "Elastic", "Bounce", "Circular" }),
    EasingDirection = enumNs({ "In", "Out", "InOut" }),
    PlaybackState = enumNs({ "Begin", "Delayed", "Playing", "Paused", "Completed", "Cancelled" }),
    ApplyStrokeMode = enumNs({ "Border", "Contextual" }),
    LineJoinMode = enumNs({ "Round", "Bevel", "Miter" }),
    AutomaticSize = enumNs({ "None", "X", "Y", "XY" }),
    SortOrder = enumNs({ "LayoutOrder", "Name" }),
    TextXAlignment = enumNs({ "Left", "Center", "Right" }),
    TextYAlignment = enumNs({ "Top", "Center", "Bottom" }),
    TextTruncate = enumNs({ "None", "AtEnd", "SplitWord" }),
    VerticalAlignment = enumNs({ "Top", "Center", "Bottom" }),
    HorizontalAlignment = enumNs({ "Left", "Center", "Right" }),
    FillDirection = enumNs({ "Horizontal", "Vertical" }),
    KeyCode = enumNs({ "RightControl", "LeftAlt", "E", "P", "Insert", "Unknown", "Escape", "Return", "ButtonA", "ButtonB" }),
    UserInputType = enumNs({ "MouseButton1", "MouseMovement", "Touch", "Keyboard", "MouseWheel", "Gamepad1" }),
    ZIndexBehavior = enumNs({ "Sibling", "Global" }),
    ScaleType = enumNs({ "Stretch", "Fit", "Crop", "Tile", "Slice" }),
    UIFlexMode = enumNs({ "None", "Grow", "Shrink", "Fill" }),
    UIFlexAlignment = enumNs({ "None", "Fill", "Center", "Start", "End" }),
  }
  -- Same arity as Roblox (name, weight, style) so an arity bug in the library (e.g. a
  -- fromEnum-style two-arg call) is not masked by the stub.
  env.Font = { fromName = function(name, weight, style)
    return { Family = name, Weight = weight or env.Enum.FontWeight.Regular, Style = style }
  end }
  env.Instance = { new = newInstance }
  -- Roblox typeof(): Instances/connections are userdata in real Roblox. The mock tags
  -- them so maid.lua's typeof-based cleanup exercises the SAME branch it will in Roblox.
  env.typeof = function(v)
    if type(v) == "table" then
      if rawget(v, "__isInstance") then return "Instance" end
      if rawget(v, "__isConnection") then return "RBXScriptConnection" end
    end
    return type(v)
  end

  -- Timers. 'immediate' (default) runs task.delay callbacks synchronously, as every existing
  -- test expects. 'queued' parks them in mock.timers until mock.advance(dt) moves the mock
  -- clock past their due time, so hover-intent / revert-after-delay paths can be observed
  -- mid-flight. task.delay returns a real coroutine handle (typeof "thread", like Roblox)
  -- that task.cancel accepts in both modes (a no-op when nothing is queued for it).
  mock.timerMode = mock.timerMode or "immediate"
  mock.now = 0
  mock.timers = {}
  local seq = 0
  local function delay(dt, fn, ...)
    local th = coroutine.create(fn)
    if mock.timerMode ~= "queued" then fn(...); return th end
    seq = seq + 1
    mock.timers[#mock.timers + 1] = { thread = th, due = mock.now + (tonumber(dt) or 0), fn = fn,
      args = { ... }, n = select("#", ...), seq = seq, cancelled = false }
    return th
  end
  local function cancel(th)
    for _, t in ipairs(mock.timers) do if t.thread == th then t.cancelled = true end end
  end
  -- Advance the clock and run every due, non-cancelled entry in (due, insertion) order.
  -- Callbacks may queue more timers; those run in the same advance if already due.
  mock.advance = function(dt)
    mock.now = mock.now + (dt or 0)
    while true do
      local pick, at
      for i, t in ipairs(mock.timers) do
        if not t.cancelled and t.due <= mock.now
          and (not pick or t.due < pick.due or (t.due == pick.due and t.seq < pick.seq)) then pick, at = t, i end
      end
      if not pick then break end
      table.remove(mock.timers, at)
      pick.fn(unpack(pick.args, 1, pick.n))
    end
  end
  mock.timerCount = function() local n = 0; for _, t in ipairs(mock.timers) do if not t.cancelled then n = n + 1 end end; return n end
  mock.resetTimers = function() mock.timers = {} end
  env.task = {
    spawn = function(fn, ...) fn(...) end,
    defer = function(fn, ...) fn(...) end,
    delay = delay,
    cancel = cancel,
    wait = function() return 0 end,
  }
  env.wait = function() return 0 end
  env.tick = function() return mock.now end

  -- in-memory filesystem
  mock.fs = {}
  env.writefile = function(p, c) mock.fs[p] = c end
  env.readfile = function(p) return mock.fs[p] end
  env.isfile = function(p) return mock.fs[p] ~= nil end
  env.isfolder = function(p) for k in pairs(mock.fs) do if k:sub(1, #p) == p then return true end end return false end
  env.makefolder = function() end
  env.delfile = function(p) mock.fs[p] = nil end
  env.listfiles = function(dir)
    local out = {}
    for k in pairs(mock.fs) do if k:sub(1, #dir + 1) == dir .. "/" then out[#out + 1] = k end end
    return out
  end

  -- services
  local HttpService = {
    JSONEncode = function(_, t) return M.jsonEncode(t) end,
    JSONDecode = function(_, s) return M.jsonDecode(s) end,
    GenerateGUID = function() return "guid" end,
  }
  -- Every Create() is captured in mock.tweens (plus mock.lastTween) so tests can count tweens
  -- per action or find the one aimed at a given instance. Play stays synchronous: the goal
  -- lands once and Completed fires once, even for RepeatCount -1 loops (a spinner that really
  -- looped would never yield back to the test).
  mock.tweens = {}
  mock.resetTweens = function() mock.tweens = {}; mock.lastTween = nil end
  mock.tweenCount = function() return #mock.tweens end
  mock.tweensFor = function(inst)
    local out = {}
    for _, tw in ipairs(mock.tweens) do if tw.Instance == inst then out[#out + 1] = tw end end
    return out
  end
  local PlaybackState = env.Enum.PlaybackState
  local TweenService = {
    Create = function(_, inst, info, goal)
      local tw = { Instance = inst, Info = info, Goal = goal, played = false, paused = false, cancelled = false,
        PlaybackState = PlaybackState.Begin, Completed = makeSignal() }
      function tw:Play()
        self.played = true; self.PlaybackState = PlaybackState.Completed
        for k, v in pairs(goal) do inst[k] = v end
        self.Completed:Fire(PlaybackState.Completed)
      end
      function tw:Pause() self.paused = true; self.PlaybackState = PlaybackState.Paused end
      function tw:Cancel() self.cancelled = true; self.PlaybackState = PlaybackState.Cancelled end
      mock.lastTween = tw
      mock.tweens[#mock.tweens + 1] = tw
      return tw
    end,
  }
  local uisPropSignals = {}
  local UserInputService = {
    InputBegan = makeSignal(), InputChanged = makeSignal(), InputEnded = makeSignal(),
    LastInputTypeChanged = makeSignal(),
    TouchEnabled = false, MouseEnabled = true, KeyboardEnabled = true, GamepadEnabled = false,
  }
  function UserInputService:GetLastInputType() return mock.lastInputType or env.Enum.UserInputType.Keyboard end
  function UserInputService:GetPropertyChangedSignal(p)
    uisPropSignals[p] = uisPropSignals[p] or makeSignal()
    return uisPropSignals[p]
  end
  local guiPropSignals = {}
  local GuiService = { IsTenFootInterface = function(_) return mock.tenFoot == true end, ReducedMotionEnabled = false }
  function GuiService:GetPropertyChangedSignal(p)
    guiPropSignals[p] = guiPropSignals[p] or makeSignal()
    return guiPropSignals[p]
  end
  -- Rough glyph metric (0.55em average advance) so measured-width code paths run headless
  -- instead of only their fallback branch.
  local TextService = {
    GetTextSize = function(_, text, size, font, bounds) return env.Vector2.new(#text * size * 0.55, size) end,
  }
  local Camera = newInstance("Camera")
  Camera.ViewportSize = env.Vector2.new(1280, 720)
  env.workspace = env.workspace or {}
  env.workspace.CurrentCamera = Camera
  mock.camera = Camera
  local playerList = { { Name = "Tester", UserId = 1 } }
  local PlayerGui = newInstance("PlayerGui"); PlayerGui.Name = "PlayerGui"
  local LocalPlayer = { Name = "Tester", UserId = 1 }
  function LocalPlayer:FindFirstChildOfClass(c) if c == "PlayerGui" then return PlayerGui end end
  function LocalPlayer:WaitForChild(n) if n == "PlayerGui" then return PlayerGui end end
  local Players = {
    LocalPlayer = LocalPlayer,
    GetPlayers = function() return playerList end, -- persistent list; tests mutate the returned ref
    PlayerAdded = makeSignal(),
    PlayerRemoving = makeSignal(),
    GetUserThumbnailAsync = function() return "rbxassetid://0" end,
  }
  local RunService = { RenderStepped = makeSignal(), Heartbeat = makeSignal(),
    IsStudio = function() return mock.isStudio == true end }
  mock.stepHeartbeat = function(dt) RunService.Heartbeat:Fire(dt) end
  mock.heartbeatHandlers = function() return RunService.Heartbeat:__count() end
  local CoreGui = newInstance("CoreGui"); CoreGui.Name = "CoreGui"
  mock.coreGui = CoreGui
  mock.playerGui = PlayerGui
  local services = { HttpService = HttpService, TweenService = TweenService, UserInputService = UserInputService,
    Players = Players, RunService = RunService, CoreGui = CoreGui, GuiService = GuiService, TextService = TextService }
  env.game = { GetService = function(_, name)
    if mock.hidden and mock.hidden[name] then return nil end
    return services[name]
  end, HttpGet = function() return "" end }
  -- TweenInfo.new(time, style, dir, repeatCount, reverses, delay) with Roblox defaults. Strict
  -- mode mirrors Roblox's argument checks so a nil that slips into a numeric slot (a missing
  -- duration, a delay token that resolved to nothing) fails here instead of only in Studio.
  -- Trailing nil style/dir are tolerated (Roblox treats a trailing nil as absent).
  env.TweenInfo = { new = function(...)
    local n = select("#", ...)
    local t, style, dir, rep, rev, delayTime = ...
    if M.strict then
      local function bad(i, want, got)
        error(("invalid argument #%d to 'new' (%s expected, got %s)"):format(i, want, type(got)), 3)
      end
      if n >= 1 and type(t) ~= "number" then bad(1, "number", t) end
      if n >= 2 and ((style ~= nil and type(style) ~= "table") or (style == nil and n > 2)) then bad(2, "EnumItem", style) end
      if n >= 3 and ((dir ~= nil and type(dir) ~= "table") or (dir == nil and n > 3)) then bad(3, "EnumItem", dir) end
      if n >= 4 and type(rep) ~= "number" then bad(4, "number", rep) end
      if n >= 5 and type(rev) ~= "boolean" then bad(5, "boolean", rev) end
      if n >= 6 and type(delayTime) ~= "number" then bad(6, "number", delayTime) end
    end
    return { Time = (t == nil) and 1 or t, EasingStyle = style or env.Enum.EasingStyle.Quad,
      EasingDirection = dir or env.Enum.EasingDirection.Out, RepeatCount = rep or 0,
      Reverses = rev or false, DelayTime = delayTime or 0 }
  end }
  env.NumberSequence = { new = function(a) return { keypoints = a } end }
  env.NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
  env.ColorSequence = { new = function(c) return { color = c } end }
  env.ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
  env.mock = mock
end

-- tiny JSON (objects/arrays/strings/numbers/bools/nil) — sufficient for config tests
function M.jsonEncode(t)
  local function enc(v)
    local tv = type(v)
    if tv == "string" then return '"' .. v:gsub('"', '\\"') .. '"' end
    if tv == "number" or tv == "boolean" then return tostring(v) end
    if tv == "table" then
      local isArr, n = true, 0
      for k in pairs(v) do n = n + 1; if type(k) ~= "number" then isArr = false end end
      local parts = {}
      if isArr then
        for _, e in ipairs(v) do parts[#parts + 1] = enc(e) end
        return "[" .. table.concat(parts, ",") .. "]"
      end
      for k, e in pairs(v) do parts[#parts + 1] = '"' .. tostring(k) .. '":' .. enc(e) end
      return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
  end
  return enc(t)
end

function M.jsonDecode(s)
  -- delegate to a Lua chunk eval after converting JSON to a Lua table literal (test-only, trusted input).
  -- ORDER MATTERS: convert array brackets [ ] -> { } FIRST, otherwise the [ ] we introduce for
  -- string keys (`"k":` -> `["k"]=`) get clobbered by the array substitution.
  local lua = s
    :gsub("%[", "{")
    :gsub("%]", "}")
    :gsub('"([^"]-)"%s*:', '["%1"]=')
    :gsub("null", "nil")
  local loadstr = loadstring or load -- 5.1 uses loadstring; 5.2+/LuaJIT accept string via load
  local f = loadstr("return " .. lua)
  return f and f() or {}
end

return M
