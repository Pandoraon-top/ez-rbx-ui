local h = require("tests.helper")
local R = h.loadLib()
-- Returns (card, dim) for the most-recently-opened Dialog in the overlay, or (nil, nil).
local function dialogCard(R, gui)
  local root = R.Overlay.get(gui); local dim
  for _, c in ipairs(root:GetChildren()) do if c.Name == "Dialog" then dim = c end end
  return dim and dim:FindFirstChild("Card") or nil, dim
end
h.describe("dialog", function()
  h.it("opens into overlay and a button closes + fires callback", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local picked
    R.Dialog.open({ Title = "Sure?", Message = "Confirm.", Buttons = {
      { Text = "Yes", Callback = function() picked = "yes" end },
      { Text = "No", Callback = function() picked = "no" end },
    } })
    local root = R.Overlay.get(gui)
    local card
    for _, c in ipairs(root:GetChildren()) do if c.Name == "Dialog" then card = c end end
    h.expect(card ~= nil).toBeTruthy()
    local row = card:FindFirstChild("Card"):FindFirstChild("Buttons")
    local firstBtn
    for _, c in ipairs(row:GetChildren()) do if c.ClassName == "TextButton" then firstBtn = c; break end end
    firstBtn.MouseButton1Click:Fire()
    h.expect(picked).toBe("yes")
    local stillOpen = false
    for _, c in ipairs(root:GetChildren()) do if c.Name == "Dialog" then stillOpen = true end end
    h.expect(stillOpen).toBe(false)
  end)
  h.it("Window:Dialog forwards to Dialog.open", function()
    local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    local handle = w:Dialog({ Title = "Hi", Buttons = { { Text = "OK" } } })
    h.expect(type(handle.Close)).toBe("function")
  end)
  h.it("uses opts.Width for the card width", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "W", Width = 480, Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    h.expect(card.Size.X.Offset).toBe(480)
  end)
  h.it("clamps the card width to the viewport when wider than available", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "W", Width = 5000, Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    h.expect(card.Size.X.Offset).toBe(1872)  -- viewport fallback 1920 - 2*24 margin
  end)
  h.it("renders an inline header icon left of the title", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "Delete", Icon = "trash-2", Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    local header = card:FindFirstChild("Header")
    h.expect(header ~= nil).toBeTruthy()
    h.expect(header:FindFirstChild("Icon") ~= nil).toBeTruthy()
    h.expect(header:FindFirstChild("Title").TextXAlignment.Name).toBe("Left")
    h.expect(header:FindFirstChild("IconBadge")).toBeNil()
  end)
  h.it("renders a centered icon badge and centers the message when IconBadge is set", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "Delete", Icon = "trash-2", IconBadge = true, Message = "Gone forever.",
      Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    local header = card:FindFirstChild("Header")
    h.expect(header:FindFirstChild("IconBadge") ~= nil).toBeTruthy()
    h.expect(header:FindFirstChild("Title").TextXAlignment.Name).toBe("Center")
    h.expect(card:FindFirstChild("Message").TextXAlignment.Name).toBe("Center")
  end)
  h.it("right-aligns the footer with content-sized buttons on non-touch", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "T", Buttons = { { Text = "Cancel" }, { Text = "Delete", Variant = "destructive" } } })
    local card = dialogCard(R, gui)
    local row = card:FindFirstChild("Buttons")
    local layout = row:FindFirstChildOfClass("UIListLayout")
    h.expect(layout.FillDirection.Name).toBe("Horizontal")
    h.expect(layout.HorizontalAlignment.Name).toBe("Right")
    local firstBtn
    for _, c in ipairs(row:GetChildren()) do if c.ClassName == "TextButton" then firstBtn = c; break end end
    h.expect(firstBtn.AutomaticSize.Name).toBe("X")
  end)
  h.it("stacks the footer full-width and reversed on touch", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true
    R.Dialog.open({ Title = "T", Buttons = { { Text = "Cancel" }, { Text = "Delete", Variant = "destructive" } } })
    uis.TouchEnabled = false
    local card = dialogCard(R, gui)
    local row = card:FindFirstChild("Buttons")
    local layout = row:FindFirstChildOfClass("UIListLayout")
    h.expect(layout.FillDirection.Name).toBe("Vertical")
    h.expect(layout.HorizontalAlignment.Name).toBe("Center")
    local firstBtn  -- authored-first (Cancel) gets the LARGER LayoutOrder so Delete sits on top
    for _, c in ipairs(row:GetChildren()) do if c.ClassName == "TextButton" then firstBtn = c; break end end
    h.expect(firstBtn.LayoutOrder).toBe(2)
  end)
  h.it("fades the backdrop in on open, zooms the card out on close, and is idempotent", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local handle = R.Dialog.open({ Title = "X", Buttons = { { Text = "OK" } } })
    local card, dim = dialogCard(R, gui)
    h.expect(dim.BackgroundTransparency).toBe(0.5)  -- backdrop faded to its modal target (mock runs tweens synchronously)
    local us = card:FindFirstChildOfClass("UIScale")
    handle.Close()
    h.expect(us.Scale).toBe(0.92)                   -- card zoomed out on close
    local _, gone = dialogCard(R, gui)
    h.expect(gone).toBeNil()                        -- removed after the close tween completes
    handle.Close()                                  -- second close is a no-op via the guard (must not error)
  end)

  -- ---- visual-polish phase 1 (1.2 font roles, 1.3 AccentReg, 1.5 floating stroke) ----
  local function fakeReg()
    local reg = { fns = {}, count = 0, released = 0 }
    reg.AccentReg = function(fn)
      reg.count = reg.count + 1; reg.fns[#reg.fns + 1] = fn
      return function() reg.released = reg.released + 1 end
    end
    function reg.fire() for _, fn in ipairs(reg.fns) do fn("mode") end end
    return reg
  end

  h.it("card is a solid acrylic surface with the floating stroke alpha; title/message use Font roles", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "T", Message = "Body text.", Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    h.expect(card.BackgroundTransparency).toBe(0)                       -- solid: no frost
    h.expect(card:FindFirstChild("AcrylicNoise")).toBeNil()
    local stroke = card:FindFirstChildOfClass("UIStroke")
    h.expect(stroke.Transparency).toBe(R.Theme.Stroke.floating)
    h.expect(stroke.Color).toBe(R.Theme.Colors.border)
    local title = card:FindFirstChild("Title")
    h.expect(title.TextSize).toBe(R.Theme.Font.title.Size)
    h.expect(title.Font).toBe(h.roblox.Enum.Font.BuilderSans)
    local msg = card:FindFirstChild("Message")
    h.expect(msg.TextSize).toBe(R.Theme.Font.body.Size)
    h.expect(msg.LineHeight).toBe(R.Theme.Font.body.LineHeight)
  end)

  h.it("AccentReg: the closure re-skins card, stroke, title, message, badge and icon from theme.Colors", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local t = R.Theme.new()
    local reg = fakeReg()
    R.Dialog.open({ Title = "T", Message = "m", Icon = "trash-2", IconBadge = true, Theme = t,
      Buttons = { { Text = "OK" } }, AccentReg = reg.AccentReg })
    local card = dialogCard(R, gui)
    t.Colors.card = h.roblox.Color3.fromRGB(1, 2, 3)
    t.Colors.border = h.roblox.Color3.fromRGB(4, 5, 6)
    t.Colors.foreground = h.roblox.Color3.fromRGB(7, 8, 9)
    t.Colors.mutedForeground = h.roblox.Color3.fromRGB(10, 11, 12)
    t.Colors.surface = h.roblox.Color3.fromRGB(13, 14, 15)
    reg.fire()
    h.expect(card.BackgroundColor3).toBe(t.Colors.card)                              -- by identity
    h.expect(card.BackgroundTransparency).toBe(0)                                     -- reskin keeps it solid
    h.expect(card:FindFirstChildOfClass("UIStroke").Color).toBe(t.Colors.border)
    h.expect(card:FindFirstChildOfClass("UIStroke").Transparency).toBe(t.Stroke.floating)
    local header = card:FindFirstChild("Header")
    h.expect(header:FindFirstChild("Title").TextColor3).toBe(t.Colors.foreground)
    h.expect(card:FindFirstChild("Message").TextColor3).toBe(t.Colors.mutedForeground)
    h.expect(header:FindFirstChild("IconBadge").BackgroundColor3).toBe(t.Colors.surface)
    h.expect(header:FindFirstChild("IconBadge"):FindFirstChild("Icon").ImageColor3).toBe(t.Colors.foreground)
  end)

  h.it("AccentReg: an explicit IconColor survives a reskin", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local t = R.Theme.new()
    local reg = fakeReg()
    local pinned = h.roblox.Color3.fromRGB(200, 30, 30)
    R.Dialog.open({ Title = "T", Icon = "trash-2", IconColor = pinned, Theme = t,
      Buttons = { { Text = "OK" } }, AccentReg = reg.AccentReg })
    local card = dialogCard(R, gui)
    t.Colors.foreground = h.roblox.Color3.fromRGB(7, 8, 9)
    reg.fire()
    h.expect(card:FindFirstChild("Header"):FindFirstChild("Icon").ImageColor3).toBe(pinned)
  end)

  h.it("AccentReg: footer buttons register through it and Close releases every registration", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local reg = fakeReg()
    local handle = R.Dialog.open({ Title = "T", Buttons = { { Text = "Cancel" }, { Text = "Delete", Variant = "destructive" } },
      AccentReg = reg.AccentReg })
    h.expect(reg.count).toBe(3)         -- card closure + one per button
    h.expect(reg.released).toBe(0)
    handle.Close()
    h.expect(reg.released).toBe(3)
    handle.Close()                      -- idempotent: no double release
    h.expect(reg.released).toBe(3)
  end)

  h.it("window contract: SetMode re-skins an open dialog (card, title, message, footer button)", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Dialog({ Title = "D", Message = "m", Buttons = { { Text = "OK" } } })
    local light = R.Theme.PALETTES.light
    w:SetMode("light")
    local card = w.Main:FindFirstChild("Dialog"):FindFirstChild("Card")   -- window-scoped scrim
    h.expect(card.BackgroundColor3).toBe(light.card)
    h.expect(card:FindFirstChildOfClass("UIStroke").Color).toBe(light.border)
    h.expect(card:FindFirstChild("Title").TextColor3).toBe(light.foreground)
    h.expect(card:FindFirstChild("Message").TextColor3).toBe(light.mutedForeground)
    local btn
    for _, c in ipairs(card:FindFirstChild("Buttons"):GetChildren()) do if c.ClassName == "TextButton" then btn = c end end
    h.expect(btn:FindFirstChild("Surface"):FindFirstChild("Label").TextColor3).toBe(light.primaryForeground)
  end)

  h.it("AccentReg: a footer button press closes and releases too", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local reg = fakeReg()
    R.Dialog.open({ Title = "T", Buttons = { { Text = "OK" } }, AccentReg = reg.AccentReg })
    local row = dialogCard(R, gui):FindFirstChild("Buttons")
    local btn
    for _, c in ipairs(row:GetChildren()) do if c.ClassName == "TextButton" then btn = c; break end end
    btn.MouseButton1Click:Fire()
    h.expect(reg.released).toBe(reg.count)
  end)
end)
h.run()
