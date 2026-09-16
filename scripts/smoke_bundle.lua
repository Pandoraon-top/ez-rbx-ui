-- Runtime smoke for a BUNDLED artifact: loadfile() only parses, so it cannot catch a bundle whose
-- modules parse but whose Init(R) wiring is gone (which is exactly what `lua-bundler --release`
-- produces: Window's DefaultTheme upvalue ends up nil and CreateWindow throws on the first index).
-- Usage: luajit scripts/smoke_bundle.lua [path]   (default dist/ez-rbx-ui.lua)
package.path = "./?.lua;" .. package.path
local mockmod = require("tests.mock_roblox")
local env, mock = {}, {}
mockmod.installInto(env, mock)
local target = ... or "dist/ez-rbx-ui.lua"
local chunk = assert(loadfile(target))
local fenv = setmetatable({}, { __index = function(_, k)
  if env[k] ~= nil then return env[k] end
  if k == "require" then return function(p) error("leaked require: " .. tostring(p)) end end
  return _G[k]
end })
setfenv(chunk, fenv)
local ok, EzUI = pcall(chunk)
assert(ok, "runtime error: " .. tostring(EzUI))
assert(type(EzUI.CreateWindow) == "function", "no CreateWindow")
local screen = env.Instance.new("ScreenGui")
local w = EzUI:CreateWindow({ Title = "Smoke", Parent = screen })
local tab = w:AddTab({ Name = "T", Icon = "home" })
tab:AddToggle({ Text = "t" }); tab:AddSlider({ Text = "s", Min = 0, Max = 10 })
tab:AddNumberBox({ Text = "n" }); tab:AddSelectBox({ Text = "sel", Options = { "A", "B" } })
w:Notify({ Title = "hi" }); w:SetMode("light"); w:SetAccent("Indigo"); w:SetUIScale(1.1)
print("BUNDLE OK: " .. target .. " builds a window + controls, version " .. tostring(EzUI.Version))
