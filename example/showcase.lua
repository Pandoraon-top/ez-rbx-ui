--[[
  EzUI — visual showcase. A LOOK at the phase 1 + 2 polish, not an API playground.

  Build to one pasteable file — this is what `make showcase` runs. dist/ is the ONE build output
  that is committed (release/ is gitignored), so a raw GitHub URL can serve the tour directly:
    lua-bundler -e ./example/showcase.lua -o ./dist/showcase.lua
  Then paste dist/showcase.lua into an executor (or loadstring it).
]]
local EzUI = require("../output/bundle")

-- The EzUI brand mark as a WHITE-on-transparent PNG on the docs site. It is a single-colour glyph,
-- so `*Adaptive` tints it to the theme foreground (near-white in dark, near-black in light) and
-- re-tints it on SetMode — one asset that reads in both modes. Downloading it needs the executor's
-- writefile + getcustomasset; where those are missing Asset.resolvable says so and the title bar is
-- built with no logo at all, exactly as in example/main.lua. Nothing here depends on it landing.
local LOGO = "https://alfin-efendy.github.io/ez-rbx-ui/brand/ezui-blade-zu-icon.png"

local window = EzUI:CreateWindow({
  Title = "EzUI Showcase",
  Subtitle = "A tour of the visual polish",
  Image = LOGO,                                    -- title-bar logo, left of the title
  ImageAdaptive = true,                            -- mono glyph: tint it to the foreground token
  -- Big enough that the drop shadow, the lit top edge and the sidebar indicator all have room
  -- to read, small enough that the shadow spread is still visible against the game behind it.
  Ratio = { Width = 0.46, Height = 0.62 },
  Transparency = 0.12,                             -- the default frost; the Look tab moves it live
  ToggleKey = Enum.KeyCode.RightControl,
  -- The same mark on the floating button. "simple" is a chevron tab and ignores an Image, but the
  -- Look tab switches the type live and circle/square both wear it — Adaptive tinted, so the FAB
  -- logo follows dark/light too.
  FloatingToggle = { Type = "simple", Image = LOGO, Adaptive = true, AutoHide = true },
  -- NO Config on purpose. Window.new only builds a Config object when config.Config is present
  -- (components/window.lua: `if cfgOpts and ...`), so with it omitted nothing is ever written to
  -- the executor's workspace folder. Every control below is therefore Flag-less and in-memory.
})

-- Sidebar categories. Every page is `function(window)` and calls `window:AddTab`, so each one is
-- handed a stand-in whose AddTab lands inside the group; every other method forwards to the real
-- window untouched. Grouping is what puts the overline headers in the sidebar — and what lets
-- SearchTabs hide a header once every tab under it has been filtered out.
local function category(name)
  local group = window:AddTabGroup(name)
  return setmetatable({ AddTab = function(_, o) return group:AddTab(o) end }, {
    __index = function(_, k)
      local v = window[k]
      if type(v) ~= "function" then return v end
      return function(_, ...) return v(window, ...) end
    end,
  })
end

-- literal requires only — the bundler rewrites nothing else
local shell = category("The shell")
require("showcase/look")(shell)
local contents = category("The contents")
require("showcase/motion")(contents)
require("showcase/overlays")(contents)
require("showcase/surfaces")(contents, LOGO)

window:Tag({ Text = "polish", Icon = "sparkles" })
window:ShowInfo({
  Title = "EzUI Showcase",
  Message = "Four tabs under two sidebar headers. Start on Look — it explains the window itself.",
  Duration = 6000,
})
