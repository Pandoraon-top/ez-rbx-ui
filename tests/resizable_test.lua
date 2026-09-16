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
h.run()
