local h = require("tests.helper")
local R = h.loadLib(); local Resizable, Create = R.Resizable, R.Create
h.describe("resizable", function()
  h.it("builds N panes with hosts + N-1 handles; initial fractions", function()
    local rz = Resizable.new({ Parent = Create("Frame", {}), Direction = "Horizontal",
      Panes = { { Default = 0.3 }, { Default = 0.7 } } })
    h.expect(#rz.Panes).toBe(2)
    local handles = 0
    for _, c in ipairs(rz.Frame:GetChildren()) do if c.Name == "Handle" then handles = handles + 1 end end
    h.expect(handles).toBe(1)
    h.expect(math.abs(rz.Panes[1].Frame.Size.X.Scale - 0.3) < 0.06).toBeTruthy()
    h.expect(type(rz.Panes[1].AddToggle)).toBe("function")
  end)
  h.it("each handle has a centered grip pill with a visible icon", function()
    local rz = Resizable.new({ Parent = Create("Frame", {}), Panes = { {}, {} } })
    local handle; for _, c in ipairs(rz.Frame:GetChildren()) do if c.Name == "Handle" then handle = c end end
    local grip = handle:FindFirstChild("Grip")
    h.expect(grip ~= nil).toBeTruthy()
    local icon = grip:FindFirstChildOfClass("ImageLabel")
    h.expect(tostring(icon.Image):sub(1, 13)).toBe("rbxassetid://")
  end)
  h.it("dragging a handle re-fractions the adjacent panes", function()
    local rz = Resizable.new({ Parent = Create("Frame", {}), Panes = { { Default = 0.5 }, { Default = 0.5 } } })
    rz.Frame.AbsoluteSize = h.roblox.Vector2.new(200, 160)
    local handle; for _, c in ipairs(rz.Frame:GetChildren()) do if c.Name == "Handle" then handle = c end end
    handle.InputBegan:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseButton1, Position = h.roblox.Vector2.new(100, 80) })
    local uis = h.roblox.game:GetService("UserInputService")
    uis.InputChanged:Fire({ UserInputType = h.roblox.Enum.UserInputType.MouseMovement, Position = h.roblox.Vector2.new(120, 80) })
    h.expect(rz.Panes[1].Frame.Size.X.Scale > 0.5).toBeTruthy()
  end)
  h.it("grip icon rests on the structural icon token, lifts to foreground on hover", function()
    local rz = Resizable.new({ Parent = Create("Frame", {}), Panes = { {}, {} } })
    local handle; for _, c in ipairs(rz.Frame:GetChildren()) do if c.Name == "Handle" then handle = c end end
    local icon = handle:FindFirstChild("Grip"):FindFirstChildOfClass("ImageLabel")
    h.expect(icon.ImageColor3).toBe(R.Theme.Colors[R.Theme.Icon.structural])
    handle.MouseEnter:Fire()
    h.expect(icon.ImageColor3).toBe(R.Theme.Colors[R.Theme.Icon.structuralActive])
    handle.MouseLeave:Fire()
    h.expect(icon.ImageColor3).toBe(R.Theme.Colors[R.Theme.Icon.structural])
  end)
  h.it("reskin closure recolours the grip stroke and re-derives the icon from hover state", function()
    local fns = {}
    local themer = { register = function(fn) fns[#fns + 1] = fn; return function() end end }
    local rz = Resizable.new({ Parent = Create("Frame", {}), Panes = { {}, {} }, AccentThemer = themer })
    local handle; for _, c in ipairs(rz.Frame:GetChildren()) do if c.Name == "Handle" then handle = c end end
    local grip = handle:FindFirstChild("Grip")
    local st = grip:FindFirstChildOfClass("UIStroke")
    local icon = grip:FindFirstChildOfClass("ImageLabel")
    local other = h.roblox.Color3.fromRGB(1, 2, 3)
    st.Color = other; icon.ImageColor3 = other
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(st.Color).toBe(R.Theme.Colors.border)
    h.expect(icon.ImageColor3).toBe(R.Theme.Colors[R.Theme.Icon.structural])
    handle.MouseEnter:Fire(); icon.ImageColor3 = other
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(icon.ImageColor3).toBe(R.Theme.Colors[R.Theme.Icon.structuralActive])
  end)
end)

-- Plan 2.21: Drag.bind instead of a hand-rolled drag, a touch-sized handle, pane borders,
-- an active grip and the full Host context inside each pane.
h.describe("resizable drag + panes", function()
  local Enum, Vector2, theme = h.roblox.Enum, h.roblox.Vector2, R.Theme
  local uis = h.roblox.game:GetService("UserInputService")

  local function build(panes, extra)
    local o = { Parent = Create("Frame", {}), Panes = panes or { { Default = 0.5 }, { Default = 0.5 } } }
    for k, v in pairs(extra or {}) do o[k] = v end
    local rz = Resizable.new(o)
    rz.Frame.AbsoluteSize = Vector2.new(200, 160)
    local handle; for _, c in ipairs(rz.Frame:GetChildren()) do if c.Name == "Handle" then handle = c end end
    return rz, handle
  end
  local function beginAt(handle, x, y)
    handle.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(x, y) })
  end
  local function moveTo(x, y)
    uis.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector2.new(x, y) })
  end

  h.it("each pane carries a 1px border stroke, recoloured by the reskin closure", function()
    local fns = {}
    local themer = { register = function(fn) fns[#fns + 1] = fn; return function() end end }
    local rz = build(nil, { AccentThemer = themer })
    for i = 1, 2 do
      local st = rz.Panes[i].Frame:FindFirstChildOfClass("UIStroke")
      h.expect(st ~= nil).toBeTruthy()
      h.expect(st.Color).toBe(theme.Colors.border)
      h.expect(st.Thickness).toBe(1)
      h.expect(st.Transparency).toBe(theme.Stroke.control)
    end
    local st = rz.Panes[1].Frame:FindFirstChildOfClass("UIStroke")
    st.Color = h.roblox.Color3.fromRGB(1, 2, 3)
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(st.Color).toBe(theme.Colors.border)
  end)
  -- The bug Drag.bind exists to fix: the old handler reacted to ANY Touch InputChanged, so a
  -- second finger anywhere on screen re-fractioned the panes.
  h.it("a stray touch with no begin, and a stray touch mid-mouse-drag, move nothing", function()
    local rz, handle = build()
    local before = rz.Panes[1].Frame.Size.X.Scale
    uis.InputChanged:Fire({ UserInputType = Enum.UserInputType.Touch, Position = Vector2.new(190, 80) })
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBe(before)
    beginAt(handle, 100, 80)
    uis.InputChanged:Fire({ UserInputType = Enum.UserInputType.Touch, Position = Vector2.new(190, 80) })
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBe(before)
    moveTo(120, 80)                                     -- the mouse that DID grab still works
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBeCloseTo(0.6, 1e-9)
  end)
  h.it("deltas are measured from the grab point: returning to it restores the fractions exactly", function()
    local rz, handle = build()
    beginAt(handle, 100, 80)
    moveTo(140, 80)
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBeCloseTo(0.7, 1e-9)
    moveTo(190, 80)                                     -- clamped away (pane 2 would fall under Min)
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBeCloseTo(0.7, 1e-9)
    moveTo(100, 80)                                     -- back on the grab point
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBeCloseTo(0.5, 1e-9)
  end)
  h.it("the grip grows to Motion.handleGrow while dragging and springs back on release", function()
    local rz, handle = build()
    local scale = handle:FindFirstChild("Grip"):FindFirstChildOfClass("UIScale")
    h.expect(scale ~= nil).toBeTruthy()
    h.expect(scale.Scale).toBe(1)
    beginAt(handle, 100, 80)
    h.expect(scale.Scale).toBe(theme.Motion.handleGrow)
    uis.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(100, 80) })
    h.expect(scale.Scale).toBe(1)
    moveTo(160, 80)                                     -- released: no further re-fractioning
    h.expect(rz.Panes[1].Frame.Size.X.Scale).toBeCloseTo(0.5, 1e-9)
  end)
  h.it("desktop handle spans the split gap and stays centred on the seam", function()
    local rz, handle = build()
    h.expect(handle.Size.X.Offset).toBe(theme.Sizes.splitGap)
    h.expect(handle.Position.X.Offset).toBe(-theme.Sizes.splitGap / 2)
    h.expect(handle.Position.X.Scale).toBeCloseTo(0.5, 1e-9)
    h.expect(rz.Panes[1].Frame.Size.X.Offset).toBe(-theme.Sizes.splitGap)
  end)
  h.it("touch widens the handle to touchHit but leaves the gap and the centred line/grip alone", function()
    uis.TouchEnabled = true
    local ok, err = pcall(function()
      local rz, handle = build()
      h.expect(handle.Size.X.Offset).toBe(theme.Sizes.touchHit)
      h.expect(handle.Position.X.Offset).toBe(-theme.Sizes.touchHit / 2)   -- still centred in the gap
      h.expect(rz.Panes[1].Frame.Size.X.Offset).toBe(-theme.Sizes.splitGap)
      h.expect(handle:FindFirstChild("Line").Position.X.Scale).toBe(0.5)
      h.expect(handle:FindFirstChild("Grip").Position.X.Scale).toBe(0.5)
    end)
    uis.TouchEnabled = false
    if not ok then error(err, 0) end
  end)
  -- Host context: a control mounted in a pane is indexed, lockable and flag-persisted exactly
  -- like one mounted straight on a Tab.
  h.it("panes forward config, window, search and registerControl to their controls", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui, Config = { FileName = "RZHost", AutoSave = false } })
    local registered, searched = {}, {}
    local rz = Resizable.new({ Parent = Create("Frame", {}), Panes = { {}, {} },
      Config = w.Config, Window = w,
      RegisterControl = function(c) registered[#registered + 1] = c end,
      RegisterSearchable = function(_, text) searched[#searched + 1] = text end })
    local tog = rz.Panes[1]:AddToggle({ Text = "Feat", Default = false, Flag = "feat" })
    tog.Set(true)
    h.expect(w.Config:Get("feat")).toBe(true)            -- Config reached the control
    h.expect(#registered).toBe(1)
    h.expect(registered[1]).toBe(tog)                    -- LockAll can reach it
    h.expect(searched[1]).toBe("Feat")                   -- tab search can find it
    tog.SetLocked(true)
    h.expect(tog.Frame:FindFirstChild("LockScrim").Visible).toBe(true)
  end)
  h.it("reduced motion: the grip lands its grow/release without a tween", function()
    h.withReducedMotion(R, function()
      local _, handle = build()
      local scale = handle:FindFirstChild("Grip"):FindFirstChildOfClass("UIScale")
      h.mock.resetTweens()
      beginAt(handle, 100, 80)
      h.expect(scale.Scale).toBe(theme.Motion.handleGrow)
      uis.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(100, 80) })
      h.expect(scale.Scale).toBe(1)
      h.expect(h.mock.tweenCount()).toBe(0)
    end)
  end)
end)
h.run()
