local h = require("tests.helper")
local Theme = h.requireModule("core.theme")

h.describe("theme", function()
  h.it("has exact zinc background", function()
    h.expect(Theme.Colors.background.R8).toBe(9)
    h.expect(Theme.Colors.background.G8).toBe(9)
    h.expect(Theme.Colors.background.B8).toBe(11)
  end)
  h.it("primary is mono white", function()
    h.expect(Theme.Colors.primary.R8).toBe(250)
    h.expect(Theme.Colors.primaryForeground.R8).toBe(24)
  end)
  h.it("radius base-10 scale", function()
    h.expect(Theme.Radius.sm).toBe(6)
    h.expect(Theme.Radius.md).toBe(8)
    h.expect(Theme.Radius.lg).toBe(10)
    h.expect(Theme.Radius.xl).toBe(14)
  end)
  h.it("new() overrides primary without mutating default", function()
    local t = Theme.new({ Colors = { primary = h.roblox.Color3.fromRGB(59,130,246) } })
    h.expect(t.Colors.primary.R8).toBe(59)
    h.expect(Theme.Colors.primary.R8).toBe(250) -- default untouched
    h.expect(t.Colors.background.R8).toBe(9)     -- inherited
  end)
  h.it("ships dark + light palettes", function()
    h.expect(Theme.PALETTES.dark ~= nil).toBeTruthy()
    h.expect(Theme.PALETTES.light ~= nil).toBeTruthy()
  end)
  h.it("applyMode swaps base tokens in place but keeps the accent", function()
    local t = Theme.new()
    t.Colors.primary = h.roblox.Color3.fromRGB(1, 2, 3) -- a custom accent
    Theme.applyMode(t, "light")
    h.expect(t.Colors.background).toBe(Theme.PALETTES.light.background) -- by reference: survives palette retunes
    h.expect(t.Colors.foreground.R8).toBe(24)
    h.expect(t.Colors.primary.R8).toBe(1) -- accent preserved
  end)
  h.it("light palette is a four-step tonal ladder: chrome 240 / surface 244 / input 250 / card 255", function()
    local L = Theme.PALETTES.light
    h.expect(L.background.R8).toBe(240); h.expect(L.background.B8).toBe(243)
    h.expect(L.border.R8).toBe(228);     h.expect(L.border.B8).toBe(231)
    h.expect(L.input.R8).toBe(250);      h.expect(L.input.B8).toBe(250)
    h.expect(L.surface.R8).toBe(244);    h.expect(L.surface.B8).toBe(245)
    h.expect(L.card.R8).toBe(255)
    -- mock Color3 has no __eq, so distinctness is checked on the channel tuple, not table identity
    local seen = {}
    for _, k in ipairs({ "background", "card", "surface", "input" }) do
      local key = L[k].R8 .. "," .. L[k].G8 .. "," .. L[k].B8
      h.expect(seen[key]).toBeNil()
      seen[key] = k
    end
  end)
  h.it("switchTrackOff is visibly darker than the row surface in both modes (plan 2.9)", function()
    local function tuple(c) return c.R8 .. "," .. c.G8 .. "," .. c.B8 end
    h.expect(tuple(Theme.PALETTES.dark.switchTrackOff)).toBe("63,63,70")
    h.expect(tuple(Theme.PALETTES.light.switchTrackOff)).toBe("212,212,216")
    h.expect(tuple(Theme.PALETTES.dark.switchTrackOff) ~= tuple(Theme.PALETTES.dark.surface)).toBeTruthy()
    h.expect(tuple(Theme.PALETTES.light.switchTrackOff) ~= tuple(Theme.PALETTES.light.surface)).toBeTruthy()
    h.expect(Theme.Colors.switchTrackOff).toBe(Theme.PALETTES.dark.switchTrackOff) -- module default is the dark palette
  end)
  h.it("controls recolor on SetMode (text/input backgrounds follow light tokens)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local lbl = tab:AddLabel("Hello")
    local tb = tab:AddTextBox({ Text = "Name" })
    local kb = tab:AddKeybind({ Text = "Bind" })
    w:SetMode("light")
    h.expect(lbl.Frame.TextColor3).toBe(R.Theme.PALETTES.light.foreground)
    h.expect(tb.Frame:FindFirstChild("Box").BackgroundColor3).toBe(R.Theme.PALETTES.light.background)
    h.expect(kb.Frame.BackgroundColor3).toBe(R.Theme.PALETTES.light.surface)
  end)
  h.it("accordion lead icon is accent and re-tints on SetMode (not stuck white)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local acc = tab:AddAccordion({ Title = "Cfg", Icon = "settings-2" })
    local lead = acc.Header:FindFirstChild("Icon")
    h.expect(lead.ImageColor3.R8).toBe(250)
    w:SetMode("light")
    h.expect(lead.ImageColor3).toBe(R.Theme.PALETTES.light.primary)
    -- structural caret (plan 1.4): muted at rest, foreground once expanded -- never the accent
    local caret = acc.Header:FindFirstChild("Caret")
    h.expect(caret.ImageColor3).toBe(R.Theme.PALETTES.light.mutedForeground)
    acc:Expand()
    h.expect(caret.ImageColor3).toBe(R.Theme.PALETTES.light.foreground)
  end)
  h.it("slider track has a roomy bottom margin", function()
    local R = h.loadLib()
    local sl = R.Slider.new({ Parent = R.Create("Frame", {}), Text = "Vol", Min = 0, Max = 100, Default = 10 })
    h.expect(sl.Frame:FindFirstChild("Track").Position.Y.Offset).toBe(-16)
    h.expect(sl.Frame.Size.Y.Offset).toBe(62)  -- 46 inner + 2*inputY(8) vertical breathing room
  end)
  h.it("slider row is opaque with a bordered track; selectbox has a bordered Field", function()
    local R = h.loadLib(); local p = R.Create("Frame", {})
    local sl = R.Slider.new({ Parent = p, Text = "Vol", Min = 0, Max = 100, Default = 10 })
    h.expect(sl.Frame.BackgroundTransparency).toBe(0)
    h.expect(sl.Frame:FindFirstChild("Track"):FindFirstChildOfClass("UIStroke") ~= nil).toBeTruthy()
    local sb = R.SelectBox.new({ Parent = p, Text = "Mode", Options = { "A", "B" }, Default = "A" })
    local field = sb.Frame:FindFirstChild("Field")
    h.expect(field ~= nil).toBeTruthy()
    h.expect(field:FindFirstChildOfClass("UIStroke") ~= nil).toBeTruthy()
    h.expect(field:FindFirstChild("Value") ~= nil).toBeTruthy()
    h.expect(field:FindFirstChild("Caret") ~= nil).toBeTruthy()
    h.expect(field.BackgroundColor3.R8).toBe(R.Theme.Colors.background.R8)
  end)
  h.it("inputs render an optional Description", function()
    local R = h.loadLib(); local p = R.Create("Frame", {})
    local kb = R.Keybind.new({ Parent = p, Text = "Bind", Description = "press a key" })
    h.expect(kb.Frame:FindFirstChild("Description").Text).toBe("press a key")
    local cp = R.ColorPicker.new({ Parent = p, Text = "Color", Description = "pick one" })
    h.expect(cp.Frame:FindFirstChild("Description") ~= nil).toBeTruthy()
    local sb = R.SelectBox.new({ Parent = p, Text = "Mode", Description = "choose", Options = { "A" } })
    h.expect(sb.Frame:FindFirstChild("Description") ~= nil).toBeTruthy()
    local sl = R.Slider.new({ Parent = p, Text = "Vol", Description = "0-100", Min = 0, Max = 100 })
    h.expect(sl.Frame:FindFirstChild("Description") ~= nil).toBeTruthy()
  end)
  h.it("table rows recolor on SetMode (not stuck dark)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local tbl = tab:AddTable({ Columns = { "A", "B" }, Rows = { { "1", "2" } } })
    w:SetMode("light")
    local body = tbl.Frame:FindFirstChild("Body")
    local firstRow; for _, c in ipairs(body:GetChildren()) do if c.Name == "Row" then firstRow = c end end
    h.expect(firstRow.BackgroundColor3).toBe(R.Theme.PALETTES.light.surface)
  end)
  h.it("containers recolor on SetMode (accordion card + divider)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tab = w:AddTab({ Name = "T" })
    local acc = tab:AddAccordion({ Title = "A" })
    w:SetMode("light")
    h.expect(acc.Container.BackgroundColor3).toBe(R.Theme.PALETTES.light.card)
    h.expect(acc.Container:FindFirstChild("Divider").BackgroundColor3).toBe(R.Theme.PALETTES.light.border)
  end)
end)

-- F1: token groups + per-mode effect table + helpers (defaults = today's literals, zero visual change)
local Enum = h.roblox.Enum
local GROUPS = { "Motion", "Effect", "Stroke", "Opacity", "Acrylic", "Scrollbar", "Sizes", "Icon", "Tooltip", "Toast" }

-- deepMerge only recurses into named-field tables; an array part would be copied by reference
-- (and an override could not replace one element), so no group may carry integer keys.
local function assertNoArrays(tbl, path)
  for k, v in pairs(tbl) do
    if type(k) ~= "string" then error(path .. " has a non-string key " .. tostring(k), 2) end
    if type(v) == "table" and v.R == nil and v.Name == nil then assertNoArrays(v, path .. "." .. k) end
  end
end

h.describe("theme tokens (F1)", function()
  h.it("exposes every new group on the module and on Theme.new({})", function()
    local t = Theme.new({})
    for _, g in ipairs(GROUPS) do
      h.expect(type(Theme[g])).toBe("table")
      h.expect(type(t[g])).toBe("table")
      assertNoArrays(Theme[g], "Theme." .. g)
    end
  end)
  h.it("keeps the pinned motion trio and today's literals as defaults", function()
    h.expect(Theme.Motion.fast).toBe(0.12)
    h.expect(Theme.Motion.base).toBe(0.18)
    h.expect(Theme.Motion.slow).toBe(0.28)
    h.expect(Theme.Motion.popFrom).toBe(0.9)        -- Animate.pop
    h.expect(Theme.Motion.spin).toBe(0.8)           -- loading toast spinner
    h.expect(Theme.Motion.shake.steps).toBe(4)
    h.expect(Theme.Sizes.titleBar).toBe(40)         -- window.lua TITLE_H (plan's 36 is wrong)
    h.expect(Theme.Sizes.titleBarTall).toBe(56)     -- window.lua TITLE_H_TALL
    h.expect(Theme.Sizes.fab.size).toBe(44)
    h.expect(Theme.Sizes.fab.simple).toBe(50)
    h.expect(Theme.Sizes.fab.peek).toBe(15)
    h.expect(Theme.Sizes.indicator.w).toBe(3)
    h.expect(Theme.Sizes.indicator.h).toBe(18)
    h.expect(Theme.Sizes.knob).toBe(20)
    h.expect(Theme.Toast.width).toBe(300)
    h.expect(Theme.Toast.maxVisible).toBe(3)
    h.expect(Theme.Toast.barHeight).toBe(3)
    h.expect(Theme.Opacity.hoverFill).toBe(0.12)   -- button.lua bgHover
    h.expect(Theme.Opacity.ghostPress).toBe(0.25)  -- button.lua bgPressed (transparent variant)
    h.expect(Theme.Opacity.tabHover).toBe(0.92)
    h.expect(Theme.Opacity.scrim).toBe(0.45)        -- host.lua LockScrim
    h.expect(Theme.Stroke.window).toBe(0.3)         -- acrylic stroke
    h.expect(Theme.Acrylic.tileSize).toBe(128)
    h.expect(Theme.Acrylic.noiseId).toBe("rbxassetid://9968344105")
    -- an uploaded 9-slice sprite (assets/shadow-9slice.png); "" would switch every depth layer off
    h.expect(Theme.Effect.shadowId:sub(1, 13)).toBe("rbxassetid://")
    h.expect(Theme.Effect.slice.x1).toBe(450)
    h.expect(Theme.Radius.input).toBe(6)
    h.expect(Theme.Radius.xs).toBe(2)
    h.expect(Theme.Font.overline.Size).toBe(11)
    h.expect(Theme.Font.overline.Weight).toBe(Enum.FontWeight.Medium)
    h.expect(Theme.Font.body.LineHeight).toBe(1.25)
    h.expect(Theme.Icon.structural).toBe("mutedForeground")
    h.expect(Theme.Icon.accent).toBe("primary")
  end)
  h.it("deep-merges nested group overrides without touching the defaults", function()
    local t = Theme.new({ Sizes = { fab = { size = 48 } }, Motion = { press = 0.1 }, Toast = { width = 320 } })
    h.expect(t.Sizes.fab.size).toBe(48)
    h.expect(t.Sizes.fab.simple).toBe(50)        -- sibling field inherited
    h.expect(t.Sizes.titleBar).toBe(40)          -- sibling group field inherited
    h.expect(t.Motion.press).toBe(0.1)
    h.expect(t.Motion.fast).toBe(0.12)
    h.expect(t.Toast.width).toBe(320)
    h.expect(t.Toast.gap).toBe(8)
    h.expect(Theme.Sizes.fab.size).toBe(44)      -- module defaults untouched
    h.expect(Theme.Motion.press ~= 0.1).toBeTruthy()
    h.expect(Theme.Toast.width).toBe(300)
  end)
  h.it("ships MODE_EFFECTS for both modes; light sheenTop is nil (identity multiplier)", function()
    h.expect(type(Theme.MODE_EFFECTS.dark)).toBe("table")
    h.expect(type(Theme.MODE_EFFECTS.light)).toBe("table")
    h.expect(Theme.MODE_EFFECTS.dark.sheenTop.R8).toBe(255)
    h.expect(Theme.MODE_EFFECTS.light.sheenTop).toBeNil()
    h.expect(Theme.MODE_EFFECTS.dark.shadow).toBe(0.5)
    h.expect(Theme.MODE_EFFECTS.light.shadow).toBe(0.8)
  end)
  h.it("fx(theme) picks the light table after applyMode and falls back to dark", function()
    local t = Theme.new()
    h.expect(Theme.fx(t)).toBe(Theme.MODE_EFFECTS.dark)      -- Mode unset -> dark
    Theme.applyMode(t, "light")
    h.expect(Theme.fx(t)).toBe(Theme.MODE_EFFECTS.light)
    h.expect(t.fx(t)).toBe(Theme.MODE_EFFECTS.light)         -- reachable through the instance
    Theme.applyMode(t, "dark")
    h.expect(Theme.fx(t)).toBe(Theme.MODE_EFFECTS.dark)
    h.expect(Theme.fx(nil)).toBe(Theme.MODE_EFFECTS.dark)
    h.expect(Theme.fx({ Mode = "sepia" })).toBe(Theme.MODE_EFFECTS.dark) -- unknown mode -> dark
  end)
  h.it("modeVal returns the per-mode value or the scalar unchanged", function()
    local t = Theme.new()
    h.expect(Theme.modeVal(t, Theme.Stroke.panel)).toBe(0.6)              -- dark default
    h.expect(Theme.modeVal(t, Theme.Opacity.dialogScrim)).toBe(0.5)
    h.expect(Theme.modeVal(t, 0.42)).toBe(0.42)                            -- scalar passthrough
    h.expect(Theme.modeVal(t, "rbxassetid://1")).toBe("rbxassetid://1")
    Theme.applyMode(t, "light")
    h.expect(Theme.modeVal(t, Theme.Stroke.panel)).toBe(0)
    h.expect(Theme.modeVal(t, Theme.Stroke.search)).toBe(0.5)
    h.expect(t.modeVal(t, Theme.Opacity.dialogScrim)).toBe(0.6)           -- instance reach
    h.expect(Theme.modeVal({ Mode = "sepia" }, { dark = 1, light = 2 })).toBe(1) -- unknown mode -> dark
    local shake = Theme.modeVal(t, Theme.Motion.shake)                     -- not a per-mode table: returned as-is
    h.expect(shake).toBe(Theme.Motion.shake)
  end)
  h.it("mix(a, b, 0.5) is the channel midpoint and reads only .R/.G/.B", function()
    -- BOTH operands throw on any member other than R/G/B: a .R8 or :Lerp() read on either side
    -- would pass silently if only the first one were guarded (verify_bundle's Color3 has no R8).
    local function strictColor(r, g, bl)
      return setmetatable({ R = r, G = g, B = bl }, {
        __index = function(_, k) error(tostring(k) .. " is not a valid member of Color3", 2) end })
    end
    local strict = strictColor(0, 0, 1)
    local b = strictColor(1, 1, 1)
    local m = Theme.mix(strict, b, 0.5)
    h.expect(m.R).toBeCloseTo(0.5)
    h.expect(m.G).toBeCloseTo(0.5)
    h.expect(m.B).toBeCloseTo(1)
    h.expect(Theme.mix(strict, b, 0).B).toBeCloseTo(1)
    h.expect(Theme.mix(strict, b, 1).R).toBeCloseTo(1)
    h.expect(Theme.mix(strict, b, 2).R).toBeCloseTo(1)   -- t clamped to [0,1]
    h.expect(Theme.mix(strict, b, -1).R).toBeCloseTo(0)
    local t = Theme.new({})
    h.expect(t.mix(strict, b, 0.25).R).toBeCloseTo(0.25)  -- instance reach
    h.expect(function() Theme.mix(nil, b, 0.5) end).toThrow("Theme.mix")
  end)
  h.it("FontFace builds a BuilderSans face via Font.fromName and never asks for weight 600", function()
    local f = Theme.FontFace(Enum.FontWeight.Bold)
    h.expect(type(f)).toBe("table")
    h.expect(f.Family).toBe("BuilderSans")
    h.expect(f.Weight).toBe(Enum.FontWeight.Bold)
    h.expect(Theme.FontFace(Enum.FontWeight.SemiBold).Weight).toBe(Enum.FontWeight.Bold) -- BuilderSans has no 600
    h.expect(Theme.FontFace(nil).Weight).toBe(Enum.FontWeight.Regular)
    local t = Theme.new({})
    h.expect(t.FontFace(Enum.FontWeight.Medium).Weight).toBe(Enum.FontWeight.Medium)
    -- Font global absent (older executor): resolve to nil so Create.text skips FontFace
    local saved = h.roblox.Font
    h.roblox.Font = nil
    local ok, res = pcall(Theme.FontFace, Enum.FontWeight.Bold)
    h.roblox.Font = saved
    h.expect(ok).toBeTruthy()
    h.expect(res).toBeNil()
  end)
end)

h.run()
