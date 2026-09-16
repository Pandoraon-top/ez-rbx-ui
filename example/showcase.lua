--[[
  EzUI — visual showcase. A LOOK at the phase 1 + 2 polish, not an API playground.

  Build to one pasteable file:
    lua-bundler -e ./example/showcase.lua -o ./release/showcase.lua
  Then paste release/showcase.lua into an executor (or loadstring it).
]]
local EzUI = require("../output/bundle")

local window = EzUI:CreateWindow({
  Title = "EzUI Showcase",
  Subtitle = "A tour of the visual polish",
  -- Big enough that the drop shadow, the lit top edge and the sidebar indicator all have room
  -- to read, small enough that the shadow spread is still visible against the game behind it.
  Ratio = { Width = 0.46, Height = 0.62 },
  Transparency = 0.12,                             -- the default frost; the Look tab moves it live
  ToggleKey = Enum.KeyCode.RightControl,
  FloatingToggle = { Type = "simple", AutoHide = true },
  -- NO Config on purpose. Window.new only builds a Config object when config.Config is present
  -- (components/window.lua: `if cfgOpts and ...`), so with it omitted nothing is ever written to
  -- the executor's workspace folder. Every control below is therefore Flag-less and in-memory.
})

-- literal requires only — the bundler rewrites nothing else
require("showcase/look")(window)
require("showcase/motion")(window)
require("showcase/overlays")(window)
require("showcase/surfaces")(window)

window:Tag({ Text = "polish", Icon = "sparkles" })
window:ShowInfo({
  Title = "EzUI Showcase",
  Message = "Four tabs. Start on Look — it explains what changed in the window itself.",
  Duration = 6000,
})
