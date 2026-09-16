local mockmod = require("tests.mock_roblox")

local H = { roblox = {}, _tests = {}, _suite = "" }
local mock = {}
mockmod.installInto(H.roblox, mock)
H.mock = mock

-- require a project module ("core/signal" or "core.signal") with Roblox globals injected
local cache = {}
function H.requireModule(path)
  local key = path:gsub("/", ".")
  if cache[key] then return cache[key] end
  local file = key:gsub("%.", "/") .. ".lua"
  local chunk, err = loadfile(file)
  if not chunk then error("cannot load " .. file .. ": " .. tostring(err)) end

  local env = setmetatable({}, { __index = function(_, k)
    if H.roblox[k] ~= nil then return H.roblox[k] end
    return _G[k]
  end })
  -- project modules use require("a/b"); route those through requireModule
  env.require = function(p) return H.requireModule(p) end

  setfenv(chunk, env) -- Lua 5.1 / LuaJIT
  local ok, mod = pcall(chunk)
  if not ok then error("error running " .. file .. ": " .. tostring(mod)) end
  cache[key] = mod
  return mod
end

-- Load the whole library the way main.lua does: require each module once, then
-- inject the dependency registry R via Module.Init(R). Mirrors the Init pattern the
-- bundler requires (modules must NOT require each other). Returns R.
function H.loadLib()
  local R = {}
  R.Theme = H.requireModule("core/theme")
  R.Create = H.requireModule("core/create")
  R.Safe = H.requireModule("core/safe")
  R.Signal = H.requireModule("core/signal")
  R.Maid = H.requireModule("core/maid")
  R.Icons = H.requireModule("core/icons")
  R.Config = H.requireModule("core/config")
  R.Flag = H.requireModule("core/flag")
  R.Animate = H.requireModule("core/animate")
  R.Overlay = H.requireModule("core/overlay")
  R.Mount = H.requireModule("core/mount")
  R.Acrylic = H.requireModule("core/acrylic")
  R.Asset = H.requireModule("core/asset")
  R.Numfmt = H.requireModule("core/numfmt")
  R.Themer = H.requireModule("core/themer")
  R.Device = H.requireModule("core/device")
  R.Drag = H.requireModule("core/drag")
  R.Effects = H.requireModule("core/effects")
  R.Recipes = H.requireModule("core/recipes")
  R.Separator = H.requireModule("components/separator")
  R.Label = H.requireModule("components/label")
  R.Button = H.requireModule("components/button")
  R.Card = H.requireModule("components/card")
  R.Toggle = H.requireModule("components/toggle")
  R.TextBox = H.requireModule("components/textbox")
  R.NumberBox = H.requireModule("components/numberbox")
  R.SelectBox = H.requireModule("components/selectbox")
  R.Image = H.requireModule("components/image")
  R.ProgressBar = H.requireModule("components/progressbar")
  R.Slider = H.requireModule("components/slider")
  R.Keybind = H.requireModule("components/keybind")
  R.Tooltip = H.requireModule("components/tooltip")
  R.Dialog = H.requireModule("components/dialog")
  R.Notification = H.requireModule("components/notification")
  R.Table = H.requireModule("components/table")
  R.ColorPicker = H.requireModule("components/colorpicker")
  R.Host = H.requireModule("components/host")
  R.Resizable = H.requireModule("components/resizable")
  R.Accordion = H.requireModule("components/accordion")
  R.Tab = H.requireModule("components/tab")
  R.Window = H.requireModule("components/window")
  for _, m in pairs(R) do
    if type(m) == "table" and type(m.Init) == "function" then m.Init(R) end
  end
  if R.Overlay.reset then R.Overlay.reset() end
  return R
end

function H.describe(name, fn) H._suite = name; fn(); H._suite = "" end
function H.it(name, fn)
  H._tests[#H._tests + 1] = { name = (H._suite ~= "" and H._suite .. " > " or "") .. name, fn = fn }
end

function H.expect(v)
  local E = {}
  function E.toBe(x) if v ~= x then error("expected " .. tostring(x) .. " got " .. tostring(v), 2) end end
  function E.toBeNil() if v ~= nil then error("expected nil got " .. tostring(v), 2) end end
  function E.toBeTruthy() if not v then error("expected truthy got " .. tostring(v), 2) end end
  function E.toHaveLength(n) if #v ~= n then error("expected length " .. n .. " got " .. #v, 2) end end
  -- numeric tolerance for eased/derived values (default 1e-6)
  function E.toBeCloseTo(x, eps)
    eps = eps or 1e-6
    if type(v) ~= "number" or math.abs(v - x) > eps then
      error("expected " .. tostring(x) .. " (+-" .. tostring(eps) .. ") got " .. tostring(v), 2)
    end
  end
  function E.toEqual(x)
    local function deep(a, b)
      if type(a) ~= "table" or type(b) ~= "table" then return a == b end
      for k, av in pairs(a) do if not deep(av, b[k]) then return false end end
      for k in pairs(b) do if a[k] == nil then return false end end
      return true
    end
    if not deep(v, x) then error("tables not equal", 2) end
  end
  function E.toThrow(substr)
    local ok, err = pcall(v)
    if ok then error("expected function to throw", 2) end
    if substr and not tostring(err):find(substr, 1, true) then
      error("threw '" .. tostring(err) .. "', expected to contain '" .. substr .. "'", 2)
    end
  end
  return E
end

-- Run fn with motion disabled (Animate.setEnabled(false)) and restore the previous state even
-- if fn throws. Takes the registry from H.loadLib() so the helper never requires core modules.
function H.withReducedMotion(R, fn)
  local Animate = R and R.Animate
  if type(fn) ~= "function" or not Animate then error("withReducedMotion(R, fn): R.Animate and fn required", 2) end
  local prev = Animate.isEnabled()
  Animate.setEnabled(false)
  local ok, err = pcall(fn)
  Animate.setEnabled(prev)
  if not ok then error(err, 0) end
end

-- Run fn with task.delay parked in mock.timers (fire them with mock.advance(dt)); restores the
-- previous timer mode and drops any leftover queued callbacks so later tests start clean.
function H.withQueuedTimers(fn)
  local prev = H.mock.timerMode
  H.mock.timerMode = "queued"
  H.mock.resetTimers()
  local ok, err = pcall(fn)
  H.mock.timerMode = prev
  H.mock.resetTimers()
  if not ok then error(err, 0) end
end

function H.run()
  local passed, failed = 0, 0
  for _, t in ipairs(H._tests) do
    local ok, err = pcall(t.fn)
    if ok then
      passed = passed + 1; print("PASS  " .. t.name)
    else
      failed = failed + 1; print("FAIL  " .. t.name .. "\n      " .. tostring(err))
    end
  end
  print(string.format("TOTAL: %d passed, %d failed", passed, failed))
  if failed > 0 then os.exit(1) end
end

return H
