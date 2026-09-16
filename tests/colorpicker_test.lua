local h = require("tests.helper")
local R = h.loadLib(); local ColorPicker, Create, Overlay, Config = R.ColorPicker, R.Create, R.Overlay, R.Config

local function popoverIn(gui)
  for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "ColorPopover" then return c end end
end
-- A measured control in a measured viewport: the popover is 180x152, so at (50,100) in 600x800
-- it opens below at 100 + 34 + gap(4) = 138.
local function anchored(gui, vpY, extra)
  local root = R.Overlay.get(gui); root.AbsoluteSize = h.roblox.Vector2.new(600, vpY or 800)
  local o = { Parent = Create("Frame", {}), Default = h.roblox.Color3.fromRGB(255, 255, 255) }
  for k, v in pairs(extra or {}) do o[k] = v end
  local cp = ColorPicker.new(o)
  cp.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 100)
  cp.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 34)
  return cp, root
end

h.describe("colorpicker", function()
  h.it("SetColor/GetColor round-trip and persist as rgb array", function()
    local cfg = Config.new({ FileName = "CP", AutoSave = false })
    local cp = ColorPicker.new({ Parent = Create("Frame", {}), Text = "ESP", Default = h.roblox.Color3.fromRGB(255,0,0), Flag = "esp", Config = cfg })
    h.expect(cp.GetColor().R8).toBe(255)
    cp.SetColor(h.roblox.Color3.fromRGB(0,128,255))
    h.expect(cp.GetColor().B8).toBe(255)
    local saved = cfg:Get("esp")
    h.expect(saved[1]).toBe(0)    -- r
    h.expect(saved[3]).toBe(255)  -- b
  end)
  h.it("Open mounts a picker popover into the overlay", function()
    local gui = h.roblox.Instance.new("ScreenGui"); Overlay.get(gui)
    local cp = ColorPicker.new({ Parent = Create("Frame", {}), Default = h.roblox.Color3.fromRGB(255,255,255) })
    cp.Open()
    local root = Overlay.get(gui); local found = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "ColorPopover" then found = true end end
    h.expect(found).toBeTruthy()
  end)
  h.it("scrolling the control closes the color popover", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset(); R.Overlay.get(gui)
    local cp = ColorPicker.new({ Parent = Create("Frame", {}), Default = h.roblox.Color3.fromRGB(255,255,255) })
    cp.Open()
    local function open()
      for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "ColorPopover" then return true end end
      return false
    end
    h.expect(open()).toBe(true)
    cp.Frame.AbsolutePosition = h.roblox.Vector2.new(10, 10)
    cp.Frame:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    h.expect(open()).toBe(false)
  end)
  h.it("Label and Description carry their theme Font roles (1.2)", function()
    local cp = ColorPicker.new({ Parent = Create("Frame", {}), Text = "ESP", Description = "d" })
    local label = cp.Frame:FindFirstChild("Label")
    h.expect(label.TextSize).toBe(R.Theme.Font.label.Size)
    h.expect(label.FontFace.Weight).toBe(R.Theme.Font.label.Weight)
    h.expect(cp.Frame:FindFirstChild("Description").TextSize).toBe(R.Theme.Font.muted.Size)
  end)

  -- ---- visual-polish phase 2 (2.11 popover motion/depth, 2.8 dim, 2.22 UI scale) ----
  h.it("the popover is placed through Overlay.placePopover: anchored below, clamped in x", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local cp = anchored(gui)
    cp.Open()
    local pv = popoverIn(gui)
    h.expect(pv.Position.Y.Offset).toBe(138) -- 100 + 34 + gap, not the old blind +36
    h.expect(pv.Position.X.Offset).toBe(50)
    cp.Close()
  end)
  h.it("the popover flips above the control when there is no room below", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local cp = anchored(gui, 380)
    cp.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 200) -- 200 + 34 + 4 + 152 overflows 380
    cp.Open()
    h.expect(popoverIn(gui).Position.Y.Offset).toBe(200 - 4 - 152) -- opens upward instead of off-screen
    cp.Close()
  end)
  h.it("the popover grows out of the row and Close drops it synchronously", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local cp = anchored(gui)
    h.mock.resetTweens()
    cp.Open()
    local pv = popoverIn(gui)
    local us = pv:FindFirstChildOfClass("UIScale")
    h.expect(us ~= nil).toBeTruthy()
    h.expect(us.Scale).toBe(1)               -- pops from Motion.exitScale and rests at 1
    h.expect(pv.Position.Y.Offset).toBe(138) -- the slide ends on the computed spot
    cp.Close()
    h.expect(popoverIn(gui)).toBe(nil) -- gone for the caller before the exit finishes
    h.expect(pv.Parent).toBe(nil)      -- destroyed in the completion
    cp.Open()
    h.expect(popoverIn(gui) ~= nil).toBeTruthy()
    cp.Close()
  end)
  h.it("re-opening does NOT pile up UserInputService listeners (per-open maid)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local uis = h.roblox.game:GetService("UserInputService")
    local cp = anchored(gui)
    local base = uis.InputChanged:__count()
    cp.Open()
    local open1 = uis.InputChanged:__count()
    h.expect(open1).toBe(base + 1)
    cp.Close()
    h.expect(uis.InputChanged:__count()).toBe(base)
    cp.Open(); cp.Close(); cp.Open()
    h.expect(uis.InputChanged:__count()).toBe(base + 1) -- one live listener, not one per open
    cp.Destroy()
    h.expect(uis.InputChanged:__count()).toBe(base)
  end)
  h.it("both markers carry a hairline so they stay visible over light areas", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local cp = anchored(gui)
    cp.Open()
    local pv = popoverIn(gui)
    local dot = pv:FindFirstChild("SV"):FindFirstChild("Dot")
    local hueDot = pv:FindFirstChild("Hue"):FindFirstChild("HueDot")
    local ds, hs = dot:FindFirstChildOfClass("UIStroke"), hueDot:FindFirstChildOfClass("UIStroke")
    h.expect(ds ~= nil).toBeTruthy()
    h.expect(ds.Color).toBe(R.Theme.Colors.background) -- token by identity
    h.expect(ds.Thickness).toBe(1)
    h.expect(hs ~= nil).toBeTruthy()
    h.expect(hs.Color).toBe(R.Theme.Colors.background)
    cp.Close()
  end)
  h.it("the popover is frosted and its layers reach past the host padding (padInset)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local cp = anchored(gui)
    cp.Open()
    local pv, pad = popoverIn(gui), R.Theme.Spacing.gap
    local noise = pv:FindFirstChild("AcrylicNoise")
    h.expect(noise ~= nil).toBeTruthy()
    h.expect(pv:FindFirstChild("AcrylicSheen") ~= nil).toBeTruthy()
    h.expect(pv:FindFirstChild("AcrylicGlint") ~= nil).toBeTruthy() -- edge = true
    h.expect(noise.Position.X.Offset).toBe(-pad)    -- pulled back over the UIPadding...
    h.expect(noise.Size.X.Offset).toBe(2 * pad)     -- ...and grown by both sides
    local strokes = 0
    for _, c in ipairs(pv:GetChildren()) do if c.ClassName == "UIStroke" then strokes = strokes + 1 end end
    h.expect(strokes).toBe(1) -- decorate adopts the floating hairline instead of adding one
    h.expect(pv:FindFirstChildOfClass("UIStroke").Transparency).toBe(R.Theme.Stroke.floating)
    h.expect(pv.BackgroundTransparency > 0).toBeTruthy()
    h.expect(pv.BackgroundTransparency < R.Theme.Acrylic.frost).toBeTruthy()
    cp.Close()
  end)
  h.it("the open popover gets a shadow sibling that dies with it (none without a shadow asset)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    -- state the no-asset path explicitly: the default theme now ships an uploaded sprite
    local plain, root = anchored(gui, nil, { Theme = R.Theme.new({ Effect = { shadowId = "" } }) })
    plain.Open()
    local found = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "ColorPopoverShadow" then found = true end end
    h.expect(found).toBe(false) -- Effects.shadow returns nil by default: the call site tolerates it
    plain.Close()
    local cp = anchored(gui, 800, { Theme = R.Theme.new({ Effect = { shadowId = "rbxassetid://1" } }) })
    cp.Open()
    local sh; for _, c in ipairs(root:GetChildren()) do if c.Name == "ColorPopoverShadow" then sh = c end end
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.ZIndex).toBe(R.Overlay.Z.catcher) -- sibling UNDER the popover, never a child
    local pv, spread = popoverIn(gui), R.Theme.Effect.popover.spread
    h.expect(sh.Size.X.Offset).toBe(pv.Size.X.Offset + 2 * spread)
    h.expect(sh.Size.Y.Offset).toBe(pv.Size.Y.Offset + 2 * spread)
    cp.Close()
    h.expect(sh.Parent).toBe(nil)
  end)
  h.it("the popover carries the overlay UI scale and flips on its SCALED height", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local cp = anchored(gui, 400)
    cp.Frame.AbsolutePosition = h.roblox.Vector2.new(50, 200)
    cp.Open()
    h.expect(popoverIn(gui).Position.Y.Offset).toBe(238) -- 152 still fits below 200 + 34 + 4
    cp.Close()
    R.Overlay.setScale(1.25)
    cp.Open()
    local pv = popoverIn(gui)
    h.expect(pv:FindFirstChildOfClass("UIScale").Scale).toBe(1.25)
    h.expect(pv.Position.Y.Offset).toBe(200 - 4 - 152 * 1.25)     -- 190 overflows: opens upward
    h.expect(R.Overlay.get(gui):FindFirstChildOfClass("UIScale")).toBe(nil) -- never on the overlay root
    cp.Close()
    R.Overlay.setScale(1)
  end)
  h.it("disabled dims the swatch and label, blocks Open and ends an in-flight drag", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local uis = h.roblox.game:GetService("UserInputService")
    local cp = anchored(gui)
    local swatch, label = cp.Frame:FindFirstChild("Swatch"), cp.Frame:FindFirstChild("Label")
    h.expect(swatch.BackgroundTransparency).toBe(0)
    cp.Open()
    local sv = popoverIn(gui):FindFirstChild("SV")
    sv.AbsolutePosition = h.roblox.Vector2.new(0, 0); sv.AbsoluteSize = h.roblox.Vector2.new(100, 100)
    sv.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(50, 50) })
    cp.SetDisabled(true)
    h.expect(swatch.BackgroundTransparency).toBe(R.Theme.Opacity.disabled)
    h.expect(label.TextTransparency).toBe(R.Theme.Opacity.disabled)
    local held = cp.GetColor()
    -- the drag was ended, not frozen: further movement no longer writes the colour
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(90, 10) })
    h.expect(cp.GetColor()).toBe(held)
    cp.Close()
    cp.Open()
    h.expect(popoverIn(gui)).toBe(nil) -- Open is guarded while disabled
    cp.SetDisabled(false)
    h.expect(swatch.BackgroundTransparency).toBe(0)
    h.expect(label.TextTransparency).toBe(0)
    cp.Open()
    h.expect(popoverIn(gui) ~= nil).toBeTruthy()
    cp.Close()
  end)
  -- 2.11: the OPEN popover registers a themer closure of its own, so a SetMode/SetAccent that
  -- lands while it is up repaints it. Collects EVERY registration (the control's plus the
  -- popover's temporary one) and replays them the way the window's themer does.
  local function regCollector()
    local c = { fns = {}, released = 0 }
    function c.AccentReg(fn)
      c.fns[#c.fns + 1] = fn
      return function()
        c.released = c.released + 1
        for i, f in ipairs(c.fns) do if f == fn then table.remove(c.fns, i); break end end
      end
    end
    function c.reskin(reason)
      local snapshot = {}
      for i, f in ipairs(c.fns) do snapshot[i] = f end
      for _, f in ipairs(snapshot) do f(reason) end
    end
    return c
  end
  h.it("SetMode re-skins an OPEN popover: fill, hairline and both marker rings (2.11)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reg = regCollector()
    local t = R.Theme.new({})
    local cp = anchored(gui, 800, { Theme = t, AccentReg = reg.AccentReg })
    local before = #reg.fns
    cp.Open()
    h.expect(#reg.fns).toBe(before + 1)                        -- the popover's own, while open
    local pv = popoverIn(gui)
    local ds = pv:FindFirstChild("SV"):FindFirstChild("Dot"):FindFirstChildOfClass("UIStroke")
    local hs = pv:FindFirstChild("Hue"):FindFirstChild("HueDot"):FindFirstChildOfClass("UIStroke")
    h.expect(pv.BackgroundColor3).toBe(t.Colors.card)          -- born in the theme's palette...
    R.Theme.applyMode(t, "light")                              -- applyMode writes the palette's
    reg.reskin("mode")                                         -- own tables in, so identity holds
    local light = R.Theme.PALETTES.light
    h.expect(pv.BackgroundColor3).toBe(light.card)             -- ...repainted live
    h.expect(pv:FindFirstChildOfClass("UIStroke").Color).toBe(light.border)
    h.expect(pv.BackgroundTransparency).toBe(t.Acrylic.popoverFrost)
    h.expect(ds.Color).toBe(light.background)                  -- the dot rings follow the shell
    h.expect(hs.Color).toBe(light.background)
    cp.Close()
    h.expect(reg.released).toBe(1)                             -- released the moment it folds
    h.expect(#reg.fns).toBe(before)
    reg.reskin("mode")                                         -- and never paints the dead frame
  end)
  h.it("SetMode re-applies the open popover shadow's per-mode alpha when an asset is set (2.11)", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
    local reg = regCollector()
    local t = R.Theme.new({ Effect = { shadowId = "rbxassetid://1" } })
    local cp, root = anchored(gui, 800, { Theme = t, AccentReg = reg.AccentReg })
    cp.Open()
    local sh; for _, c in ipairs(root:GetChildren()) do if c.Name == "ColorPopoverShadow" then sh = c end end
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.ImageTransparency).toBe(R.Theme.MODE_EFFECTS.dark.shadow)
    R.Theme.applyMode(t, "light")
    reg.reskin("mode")
    h.expect(sh.ImageTransparency).toBe(R.Theme.MODE_EFFECTS.light.shadow)
    cp.Close()
  end)
  h.it("reduced motion: the popover snaps in and out with no tween", function()
    h.withReducedMotion(R, function()
      local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.reset()
      local cp = anchored(gui)
      h.mock.resetTweens()
      cp.Open()
      local pv = popoverIn(gui)
      h.expect(pv.Position.Y.Offset).toBe(138)
      h.expect(pv:FindFirstChildOfClass("UIScale").Scale).toBe(1)
      h.expect(h.mock.tweenCount()).toBe(0)
      cp.Close()
      h.expect(popoverIn(gui)).toBe(nil)
      h.expect(pv.Parent).toBe(nil)
    end)
  end)
end)
h.run()
