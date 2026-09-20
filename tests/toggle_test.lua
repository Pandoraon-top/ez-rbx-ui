local h = require("tests.helper")
local R = h.loadLib()
local Toggle, Create, Config, Theme = R.Toggle, R.Create, R.Config, R.Theme

-- A theme with the 9-slice asset filled in; the default '' keeps every Effects layer nil, so the
-- glow paths below are exercised on BOTH sides (nil by default, present with an asset).
local function themed() return Theme.new({ Effect = { shadowId = "rbxassetid://1" } }) end
local function desktop()
  local uis = h.roblox.game:GetService("UserInputService")
  uis.TouchEnabled = false; uis.MouseEnabled = true   -- controlGlow 'auto' keeps glows off phones
end
local function goalOf(inst, key)
  for i = #h.mock.tweens, 1, -1 do
    local tw = h.mock.tweens[i]
    if tw.Instance == inst and tw.Goal[key] ~= nil then return tw end
  end
end

h.describe("toggle", function()
  h.it("reflects default and toggles on click", function()
    local p = Create("Frame", {})
    local changed
    local t = Toggle.new({ Parent = p, Text = "Auto", Default = false, Callback = function(v) changed = v end })
    h.expect(t.Get()).toBe(false)
    t.Frame.MouseButton1Click:Fire()
    h.expect(t.Get()).toBe(true)
    h.expect(changed).toBe(true)
  end)
  h.it("uses shadcn switch proportions and supports a description", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "Share",
      Description = "Focus is shared across devices." })
    local track = t.Frame:FindFirstChild("Track")
    h.expect(track.Size.X.Offset).toBe(44)
    h.expect(track.Size.Y.Offset).toBe(24)
    h.expect(t.Frame.Size.Y.Offset).toBe(50)
    h.expect(t.Frame:FindFirstChild("Description") ~= nil).toBeTruthy()
  end)
  h.it("persists to config flag and restores", function()
    local cfg = Config.new({ FileName = "TG", AutoSave = false })
    local t = Toggle.new({ Text = "X", Default = false, Flag = "x", Config = cfg })
    t.Set(true)
    h.expect(cfg:Get("x")).toBe(true)
    local t2 = Toggle.new({ Text = "X", Default = false, Flag = "x", Config = cfg })
    h.expect(t2.Get()).toBe(true)  -- restored
  end)
  h.it("Set keeps the value synchronous and defers the visual when capability is absent", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local tg = R.Toggle.new({ Text = "x", Default = false, Parent = R.Create("Frame", {}) })
    R.Safe._setCapabilityCheck(function() return false end)
    tg.Set(true)
    h.expect(tg.Get()).toBe(true)            -- value updates synchronously (state not deferred)
    h.mock.stepHeartbeat(0)                   -- visual catches up without error
    R.Safe._setCapabilityCheck(nil)
  end)
  h.it("Label and Description carry their theme Font roles (1.2)", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "Share", Description = "d" })
    local label = t.Frame:FindFirstChild("Label")
    h.expect(label.TextSize).toBe(R.Theme.Font.label.Size)
    h.expect(label.FontFace.Weight).toBe(R.Theme.Font.label.Weight)
    local desc = t.Frame:FindFirstChild("Description")
    h.expect(desc.TextSize).toBe(R.Theme.Font.muted.Size)
    h.expect(desc.FontFace.Weight).toBe(R.Theme.Font.muted.Weight)
  end)

  -- ---- 2.9 knob motion ------------------------------------------------------
  h.it("builds its rest pose without a single tween (2.9)", function()
    h.mock.resetTweens()
    Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = true })
    h.expect(h.mock.tweenCount()).toBe(0)
  end)
  h.it("springs the knob geometry over 'release' and tweens its colour separately with Quart (2.9)", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = false })
    local knob = t.Frame:FindFirstChild("Track"):FindFirstChild("Knob")
    h.mock.resetTweens()
    t.Set(true)
    local geom = goalOf(knob, "Position")
    h.expect(geom.Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Back)
    h.expect(geom.Info.EasingDirection).toBe(h.roblox.Enum.EasingDirection.Out)
    h.expect(geom.Info.Time).toBe(R.Theme.Motion.release)
    h.expect(geom.Goal.BackgroundColor3).toBeNil()          -- colour never rides the spring
    -- a Back/Out overshoot on a Color3 runs past the target and flashes the white knob
    local tint = goalOf(knob, "BackgroundColor3")
    h.expect(tint.Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Quart)
    h.expect(tint.Info.Time).toBe(R.Theme.Motion.base)
    h.expect(knob.Position.X.Offset).toBe(22)               -- 44 - knob(20) - pad(2)
    t.Set(false)
    h.expect(knob.Position.X.Offset).toBe(2)
  end)
  h.it("press stretches the knob toward its destination and release springs it back (2.9)", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = false })
    local knob = t.Frame:FindFirstChild("Track"):FindFirstChild("Knob")
    local stretch = R.Theme.Sizes.knob * R.Theme.Motion.knobStretch
    t.Frame.MouseButton1Down:Fire()
    h.expect(knob.Size.X.Offset).toBe(stretch)
    h.expect(knob.Position.X.Offset).toBe(2)                -- OFF: leading edge grows right
    t.Frame.MouseButton1Up:Fire()
    h.expect(knob.Size.X.Offset).toBe(R.Theme.Sizes.knob)
    t.Set(true)
    t.Frame.MouseButton1Down:Fire()
    h.expect(knob.Position.X.Offset).toBe(44 - 2 - stretch) -- ON: trailing edge stays pinned right
    t.Frame.MouseLeave:Fire()                               -- mouse-out while held resets too
    h.expect(knob.Size.X.Offset).toBe(R.Theme.Sizes.knob)
    h.expect(knob.Position.X.Offset).toBe(22)
  end)
  h.it("dissolves the track stroke when ON and restores it when OFF (2.9)", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = false })
    local track = t.Frame:FindFirstChild("Track")
    local stroke = track:FindFirstChildOfClass("UIStroke")
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.control)
    t.Set(true)
    h.expect(stroke.Transparency).toBe(1)                   -- accent pill reads as one clean shape
    t.Set(false)
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.control)
  end)
  h.it("gives the knob a rim without adding a second stroke to the track (2.9)", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x" })
    local track = t.Frame:FindFirstChild("Track")
    local rim = track:FindFirstChild("Knob"):FindFirstChildOfClass("UIStroke")
    h.expect(rim ~= nil).toBeTruthy()
    h.expect(rim.Color).toBe(R.Theme.Colors.background)
    h.expect(rim.Transparency).toBe(0.7)
    local strokes = 0
    for _, c in ipairs(track:GetChildren()) do if c.ClassName == "UIStroke" then strokes = strokes + 1 end end
    h.expect(strokes).toBe(1)
  end)

  -- ---- 2.9 accent glow ------------------------------------------------------
  h.it("has no glow when no shadow asset is configured (2.9)", function()
    desktop()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = true,
      Theme = Theme.new({ Effect = { shadowId = "" } }) })
    h.expect(t.Frame:FindFirstChild("TrackGlow")).toBeNil()
  end)
  h.it("parents the glow BESIDE the track (never inside it), below it, and fades it with the value (2.9)", function()
    desktop()
    local th = themed()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = false, Theme = th })
    local track = t.Frame:FindFirstChild("Track")
    local glow = t.Frame:FindFirstChild("TrackGlow")
    h.expect(glow ~= nil).toBeTruthy()
    h.expect(track:FindFirstChild("TrackGlow")).toBeNil()   -- a child would wash over the knob
    h.expect(glow.Parent).toBe(t.Frame)
    h.expect(glow.ZIndex < track.ZIndex).toBeTruthy()
    h.expect(glow.ImageColor3).toBe(th.Colors.primary)      -- token by identity, so SetAccent lands
    local sp = th.Effect.control.spread
    h.expect(glow.Size.X.Offset).toBe(44 + 2 * sp)
    h.expect(glow.Size.Y.Offset).toBe(24 + 2 * sp)
    h.expect(glow.Position.X.Offset).toBe(-22)              -- centred on the track (AnchorPoint .5)
    h.expect(glow.ImageTransparency).toBe(1)
    t.Set(true)
    h.expect(glow.ImageTransparency).toBe(Theme.fx(th).glow)
    t.Set(false)
    h.expect(glow.ImageTransparency).toBe(1)
  end)

  -- ---- 2.7 hover wash -------------------------------------------------------
  h.it("answers hover with a wash and press with a deeper one (2.7)", function()
    desktop()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x" })
    local wash = t.Frame:FindFirstChild("Hover")
    h.expect(wash ~= nil).toBeTruthy()
    h.expect(wash.ZIndex).toBe(0)                            -- above the row fill, below its content
    h.expect(wash.BackgroundTransparency).toBe(1)
    h.expect(wash.Size.X.Offset).toBe(2 * R.Theme.Spacing.inputX)  -- cancels the row padding
    t.Frame.MouseEnter:Fire()
    h.expect(wash.BackgroundTransparency).toBe(R.Theme.Opacity.hoverWash)
    t.Frame.MouseButton1Down:Fire()
    h.expect(wash.BackgroundTransparency).toBe(R.Theme.Opacity.pressWash)
    t.Frame.MouseLeave:Fire()
    h.expect(wash.BackgroundTransparency).toBe(1)
  end)

  -- ---- 2.8 disabled ---------------------------------------------------------
  h.it("SetEnabled(false) dims and blocks the click, but Set still updates state and visuals (2.8)", function()
    local fired = 0
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Description = "d",
      Callback = function() fired = fired + 1 end })
    local track = t.Frame:FindFirstChild("Track")
    t.SetEnabled(false)
    local dim = R.Theme.Opacity.disabled
    h.expect(track.BackgroundTransparency).toBe(dim)
    h.expect(track:FindFirstChild("Knob").BackgroundTransparency).toBe(dim)
    h.expect(t.Frame:FindFirstChild("Label").TextTransparency).toBe(dim)
    h.expect(t.Frame:FindFirstChild("Description").TextTransparency).toBe(dim)
    t.Frame.MouseButton1Click:Fire()
    h.expect(t.Get()).toBe(false); h.expect(fired).toBe(0)   -- user input is blocked
    t.Set(true)                                              -- config/API path still applies
    h.expect(t.Get()).toBe(true)
    h.expect(track.BackgroundColor3).toBe(R.Theme.Colors.primary)
    t.SetEnabled(true)
    h.expect(track.BackgroundTransparency).toBe(0)
    t.Frame.MouseButton1Click:Fire()
    h.expect(t.Get()).toBe(false)
  end)
  h.it("Disabled = true builds dimmed", function()
    local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Disabled = true })
    h.expect(t.Frame:FindFirstChild("Track").BackgroundTransparency).toBe(R.Theme.Opacity.disabled)
  end)
  h.it("SetLocked (host scrim) and SetEnabled (dim) are independent flags (2.8)", function()
    local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local w = R.Window.new({ Title = "M", Parent = screen })
    local tg = w:AddTab({ Name = "T" }):AddToggle({ Text = "x" })
    tg.SetLocked(true); tg.SetEnabled(false)
    local shield = tg.Frame:FindFirstChild("LockShield")   -- built by the first lock, not up front
    h.expect(shield.Visible).toBe(true)
    h.expect(tg.Frame:FindFirstChild("Track").BackgroundTransparency).toBe(R.Theme.Opacity.disabled)
    tg.SetLocked(false)                                      -- dropping one keeps the other
    h.expect(shield.Visible).toBe(false)
    h.expect(tg.Frame:FindFirstChild("Track").BackgroundTransparency).toBe(R.Theme.Opacity.disabled)
    tg.SetEnabled(true)
    h.expect(tg.Frame:FindFirstChild("Track").BackgroundTransparency).toBe(0)
  end)

  h.it("reduced motion lands the knob on its rest pose with no tween (2.9)", function()
    h.withReducedMotion(R, function()
      local t = Toggle.new({ Parent = Create("Frame", {}), Text = "x", Default = false })
      local knob = t.Frame:FindFirstChild("Track"):FindFirstChild("Knob")
      h.mock.resetTweens()
      t.Set(true)
      h.expect(#h.mock.tweensFor(knob)).toBe(0)
      h.expect(knob.Position.X.Offset).toBe(22)
      h.expect(knob.Size.X.Offset).toBe(R.Theme.Sizes.knob)
    end)
  end)
end)

h.run()
