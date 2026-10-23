local h = require("tests.helper")
local R = h.loadLib()
local Button, Create = R.Button, R.Create

local function surfaceOf(b) return b.Frame:FindFirstChild("Surface") end
local function goalOf(inst, key)
  for i = #h.mock.tweens, 1, -1 do
    local tw = h.mock.tweens[i]
    if tw.Instance == inst and tw.Goal[key] ~= nil then return tw end
  end
end

h.describe("button", function()
  h.it("default variant uses primary bg, fires Callback on click", function()
    local p = Create("Frame", {})
    local clicks = 0
    local b = Button.new({ Parent = p, Text = "Go", Callback = function() clicks = clicks + 1 end, LayoutOrder = 2 })
    h.expect(b.Frame:FindFirstChild("Surface").BackgroundColor3.R8).toBe(250)  -- primary mono
    h.expect(b.Frame.LayoutOrder).toBe(2)
    b.Frame.MouseButton1Click:Fire()
    h.expect(clicks).toBe(1)
  end)
  h.it("Action=ResetConfig calls Window:ResetConfiguration", function()
    local reset = 0
    local fakeWindow = { ResetConfiguration = function() reset = reset + 1 end }
    local b = Button.new({ Text = "Reset", Variant = "destructive", Action = "ResetConfig", Window = fakeWindow })
    b.Frame.MouseButton1Click:Fire()
    h.expect(reset).toBe(1)
  end)
  h.it("ghost variant is invisible at rest but reveals a surface wash on hover", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Ghost", Variant = "ghost" })
    local surface = b.Frame:FindFirstChild("Surface")
    h.expect(surface.BackgroundColor3.R8).toBe(R.Theme.Colors.surface.R8)  -- muted wash, not card (was invisible)
    h.expect(surface.BackgroundTransparency).toBe(1)                       -- fully transparent at rest
    b.Frame.MouseEnter:Fire()
    h.expect(surface.BackgroundTransparency).toBe(0.4)                     -- visible hover fill
    b.Frame.MouseLeave:Fire()
    h.expect(surface.BackgroundTransparency).toBe(1)                       -- back to invisible
  end)
  h.it("presses in on MouseButton1Down and springs back on MouseButton1Up", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go" })
    -- the press UIScale lives on the inner Surface (not the laid-out Button) so siblings never reflow
    local sc = b.Frame:FindFirstChild("Surface"):FindFirstChildOfClass("UIScale")
    b.Frame.MouseButton1Down:Fire()
    h.expect(sc.Scale).toBe(0.97)
    b.Frame.MouseButton1Up:Fire()
    h.expect(sc.Scale).toBe(1)
  end)
  h.it("SetText defers the label write when capability is absent", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    local b = R.Button.new({ Text = "old", Parent = R.Create("Frame", {}) })
    local function labelText() return b.Frame:FindFirstChild("Surface"):FindFirstChild("Label").Text end
    R.Safe._setCapabilityCheck(function() return false end)
    b.SetText("new")
    h.expect(labelText()).toBe("old")        -- deferred: not applied yet (fails before the wrap exists)
    h.mock.stepHeartbeat(0)
    h.expect(labelText()).toBe("new")        -- applied in a capability context
    R.Safe._setCapabilityCheck(nil)
  end)
  h.it("AutoWidth sizes the button to its content with a min width", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Cancel", AutoWidth = true })
    h.expect(b.Frame.AutomaticSize.Name).toBe("X")
    h.expect(b.Frame.Size.X.Scale).toBe(0)
    local con = b.Frame:FindFirstChildOfClass("UISizeConstraint")
    h.expect(con ~= nil).toBeTruthy()
    h.expect(con.MinSize.X).toBe(72)
    local label = b.Frame:FindFirstChild("Surface"):FindFirstChild("Label")
    h.expect(label.AutomaticSize.Name).toBe("X")
  end)
  h.it("default button stays full width when AutoWidth is omitted", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Wide" })
    h.expect(b.Frame.Size.X.Scale).toBe(1)
    h.expect(b.Frame.AutomaticSize.Name).toBe("None")
  end)
  h.it("Label carries the theme label role in both layouts (1.2)", function()
    for _, auto in ipairs({ false, true }) do
      local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", AutoWidth = auto })
      local label = b.Frame:FindFirstChild("Surface"):FindFirstChild("Label")
      h.expect(label.TextSize).toBe(R.Theme.Font.label.Size)
      h.expect(label.Font).toBe(h.roblox.Enum.Font.BuilderSans)
      h.expect(label.FontFace.Weight).toBe(R.Theme.Font.label.Weight)
    end
  end)

  -- ---- 2.19 press / release tokens -----------------------------------------
  h.it("press and release read Motion.press / Motion.release, not the 'fast' literal (2.19)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go" })
    local sc = surfaceOf(b):FindFirstChildOfClass("UIScale")
    h.mock.resetTweens()
    b.Frame.MouseButton1Down:Fire()
    local down = goalOf(sc, "Scale")
    h.expect(down.Info.Time).toBe(R.Theme.Motion.press)
    h.expect(sc.Scale).toBe(R.Theme.Motion.pressScale)
    h.mock.resetTweens()
    b.Frame.MouseButton1Up:Fire()
    local up = goalOf(sc, "Scale")
    h.expect(up.Info.Time).toBe(R.Theme.Motion.release)
    h.expect(up.Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Back)
    h.expect(up.Info.EasingDirection).toBe(h.roblox.Enum.EasingDirection.Out)
  end)
  h.it("a MouseLeave while held springs back with the release curve (2.19)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go" })
    local sc = surfaceOf(b):FindFirstChildOfClass("UIScale")
    b.Frame.MouseEnter:Fire()
    b.Frame.MouseButton1Down:Fire()
    h.expect(sc.Scale).toBe(R.Theme.Motion.pressScale)
    h.mock.resetTweens()
    b.Frame.MouseLeave:Fire()
    local tw = goalOf(sc, "Scale")
    h.expect(tw.Info.Time).toBe(R.Theme.Motion.release)
    h.expect(sc.Scale).toBe(1)
    h.mock.resetTweens()
    b.Frame.MouseLeave:Fire()                 -- not pressed -> no tween spent going 1 -> 1
    h.expect(goalOf(sc, "Scale")).toBeNil()
  end)
  h.it("the outline stroke lifts to the ring colour on hover and drops back to border (2.19)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Variant = "outline" })
    local line = surfaceOf(b):FindFirstChildOfClass("UIStroke")
    h.expect(line.Color).toBe(R.Theme.Colors.border)
    b.Frame.MouseEnter:Fire()
    h.expect(line.Color).toBe(R.Theme.Colors.ring)
    b.Frame.MouseLeave:Fire()
    h.expect(line.Color).toBe(R.Theme.Colors.border)
  end)
  h.it("the press fill alphas come from the Opacity tokens (2.7)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go" })
    local surface = surfaceOf(b)
    b.Frame.MouseEnter:Fire()
    h.expect(surface.BackgroundTransparency).toBe(R.Theme.Opacity.hoverFill)
    b.Frame.MouseButton1Down:Fire()
    h.expect(surface.BackgroundTransparency).toBe(R.Theme.Opacity.pressFill)
    b.Frame.MouseButton1Up:Fire()
    h.expect(surface.BackgroundTransparency).toBe(R.Theme.Opacity.hoverFill)
  end)

  -- ---- 2.8 disabled ---------------------------------------------------------
  h.it("SetEnabled(false) dims the surface and guards the callback (2.8)", function()
    local clicks = 0
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Icon = "play",
      Callback = function() clicks = clicks + 1 end })
    local surface = surfaceOf(b)
    b.SetEnabled(false)
    local dim = R.Theme.Opacity.disabled
    h.expect(b.Frame.Active).toBe(false)
    h.expect(surface.BackgroundTransparency).toBe(dim)
    h.expect(surface:FindFirstChild("Label").TextTransparency).toBe(dim)
    h.expect(surface:FindFirstChild("Icon").ImageTransparency).toBe(dim)
    b.Frame.MouseButton1Click:Fire()
    h.expect(clicks).toBe(0)                  -- the callback no longer fires (it used to)
    b.Frame.MouseEnter:Fire()
    h.expect(surface.BackgroundTransparency).toBe(dim)   -- hover ignored while disabled
    b.SetEnabled(true)
    h.expect(surface.BackgroundTransparency).toBe(0)
    b.Frame.MouseButton1Click:Fire()
    h.expect(clicks).toBe(1)
  end)
  h.it("the outline variant dims its stroke rather than only its fill (2.8)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Variant = "outline" })
    b.SetEnabled(false)
    h.expect(surfaceOf(b):FindFirstChildOfClass("UIStroke").Transparency).toBe(R.Theme.Opacity.disabled)
    b.SetEnabled(true)
    h.expect(surfaceOf(b):FindFirstChildOfClass("UIStroke").Transparency).toBe(R.Theme.Stroke.control)
  end)
  h.it("the ghost variant keeps its transparent surface while disabled (2.8)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "G", Variant = "ghost" })
    b.SetEnabled(false)
    h.expect(surfaceOf(b).BackgroundTransparency).toBe(1)  -- dimming a hole would reveal it
    h.expect(surfaceOf(b):FindFirstChild("Label").TextTransparency).toBe(R.Theme.Opacity.disabled)
  end)

  -- ---- 2.19 loading ---------------------------------------------------------
  h.it("SetLoading fades the label, spins a loader glyph and blocks clicks (2.19)", function()
    h.mock.resetTweens()
    local clicks = 0
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Callback = function() clicks = clicks + 1 end })
    local surface = surfaceOf(b)
    b.SetLoading(true)
    local spinner = surface:FindFirstChild("Spinner")
    h.expect(spinner ~= nil).toBeTruthy()
    h.expect(spinner.Visible).toBe(true)
    h.expect(surface:FindFirstChild("Label").TextTransparency).toBe(1)
    local tw = h.mock.tweensFor(spinner)[1]
    h.expect(tw.Info.RepeatCount).toBe(-1)          -- endless until SetLoading(false)
    h.expect(tw.cancelled).toBe(false)
    b.Frame.MouseButton1Click:Fire()
    h.expect(clicks).toBe(0)
    b.SetLoading(false)
    h.expect(tw.cancelled).toBe(true)
    h.expect(spinner.Rotation).toBe(0)
    h.expect(spinner.Visible).toBe(false)
    h.expect(surface:FindFirstChild("Label").TextTransparency).toBe(0)
    b.Frame.MouseButton1Click:Fire()
    h.expect(clicks).toBe(1)
  end)
  h.it("AutoWidth hides the label while loading so the row does not lay out twice (2.19)", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", AutoWidth = true })
    local label = surfaceOf(b):FindFirstChild("Label")
    b.SetLoading(true)
    h.expect(label.Visible).toBe(false)
    b.SetLoading(false)
    h.expect(label.Visible).toBe(true)
  end)
  -- A full-width button used to pin the icon at centre-44 and centre the label across the whole
  -- surface, so any label wider than that gap slid under the icon. Both widths now lay the icon
  -- and the label out as ONE centred group, and the full-width label shrinks (truncating with an
  -- ellipsis) only when the group would not fit.
  h.it("full width: icon and label are one centred group, a long label truncates instead of overlapping", function()
    local b = Button.new({ Parent = Create("Frame", {}), Icon = "play",
      Text = "Teleport to the selected island and start farming automatically" })
    h.expect(b.Frame.Size.X.Scale).toBe(1)                        -- still full width
    local surface = surfaceOf(b)
    local list = surface:FindFirstChildOfClass("UIListLayout")
    h.expect(list ~= nil).toBeTruthy()
    h.expect(list.FillDirection.Name).toBe("Horizontal")
    h.expect(list.HorizontalAlignment.Name).toBe("Center")
    local icon, label = surface:FindFirstChild("Icon"), surface:FindFirstChild("Label")
    h.expect(icon.LayoutOrder < label.LayoutOrder).toBeTruthy()    -- icon leads, beside the text
    h.expect(label.AutomaticSize.Name).toBe("X")                  -- as wide as its text, no wider
    h.expect(label.TextTruncate.Name).toBe("AtEnd")
    local flex = label:FindFirstChildOfClass("UIFlexItem")
    h.expect(flex ~= nil and flex.FlexMode.Name).toBe("Shrink")    -- gives way only on overflow
  end)
  h.it("full width: no icon pinned by hand, no label offset, and only full width shrinks its label", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Icon = "play" })
    local surface = surfaceOf(b)
    -- the literal geometry from the bug report is gone: the list layout places both
    local function unplaced(inst) return inst.Position == nil or inst.Position.X.Offset == 0 end
    h.expect(unplaced(surface:FindFirstChild("Icon"))).toBeTruthy()
    h.expect(unplaced(surface:FindFirstChild("Label"))).toBeTruthy()
    local plain = Button.new({ Parent = Create("Frame", {}), Text = "Teleport to the selected island" })
    local label = surfaceOf(plain):FindFirstChild("Label")                       -- no icon: same rules
    h.expect(label.TextTruncate.Name).toBe("AtEnd")
    h.expect(label:FindFirstChildOfClass("UIFlexItem") ~= nil).toBeTruthy()
    local auto = Button.new({ Parent = Create("Frame", {}), Text = "Go", AutoWidth = true })
    h.expect(surfaceOf(auto):FindFirstChild("Label"):FindFirstChildOfClass("UIFlexItem")).toBeNil()
  end)
  -- The spinner shares the label's slot in the centred group. Shown while the label is still
  -- fading, the group would hold [label][spinner] for a beat and then jump; it takes the slot only
  -- once the label has gone. The mock plays tweens synchronously, so the fade is held open here.
  h.it("loading: the spinner takes the label's slot only after the label has faded out", function()
    for _, auto in ipairs({ false, true }) do
      local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Icon = "play", AutoWidth = auto })
      local surface = surfaceOf(b)
      local label = surface:FindFirstChild("Label")
      local realToThen, pending = R.Animate.toThen, nil
      R.Animate.toThen = function(_, _, _, done) pending = done; return { Cancel = function() end } end
      b.SetLoading(true)
      R.Animate.toThen = realToThen
      local spinner = surface:FindFirstChild("Spinner")
      h.expect(label.Visible ~= false).toBeTruthy()     -- mid-fade: the label still holds the slot
      h.expect(spinner == nil or spinner.Visible == false).toBeTruthy()
      pending()
      spinner = surface:FindFirstChild("Spinner")
      h.expect(label.Visible).toBe(false)
      h.expect(spinner.Visible).toBe(true)
      b.SetLoading(false)
      h.expect(label.Visible ~= false).toBeTruthy()
      h.expect(spinner.Visible).toBe(false)
    end
  end)
  h.it("loading: a fade that lands after SetLoading(false) leaves the button idle", function()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go" })
    local realToThen, pending = R.Animate.toThen, nil
    R.Animate.toThen = function(_, _, _, done) pending = done; return { Cancel = function() end } end
    b.SetLoading(true)
    R.Animate.toThen = realToThen
    b.SetLoading(false)
    pending()                                            -- the superseded fade completes late
    local surface = surfaceOf(b)
    h.expect(surface:FindFirstChild("Label").Visible ~= false).toBeTruthy()
    local spinner = surface:FindFirstChild("Spinner")
    h.expect(spinner == nil or spinner.Visible == false).toBeTruthy()
  end)
  h.it("Destroy cancels a running spin loop (2.19)", function()
    h.mock.resetTweens()
    local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Loading = true })
    local tw = h.mock.tweensFor(surfaceOf(b):FindFirstChild("Spinner"))[1]
    h.expect(tw.cancelled).toBe(false)
    b.Destroy()
    h.expect(tw.cancelled).toBe(true)
  end)
  h.it("reduced motion: no spin tween and the glyph rests at 0 (2.19)", function()
    h.withReducedMotion(R, function()
      h.mock.resetTweens()
      local b = Button.new({ Parent = Create("Frame", {}), Text = "Go", Loading = true })
      local spinner = surfaceOf(b):FindFirstChild("Spinner")
      h.expect(#h.mock.tweensFor(spinner)).toBe(0)
      h.expect(spinner.Rotation).toBe(0)
      b.SetLoading(false)
    end)
  end)
end)

h.run()
