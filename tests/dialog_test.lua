local h = require("tests.helper")
local R = h.loadLib()
-- Returns (card, dim) for the most-recently-opened Dialog in the overlay, or (nil, nil).
local function dialogCard(R, gui)
  local root = R.Overlay.get(gui); local dim
  for _, c in ipairs(root:GetChildren()) do if c.Name == "Dialog" then dim = c end end
  return dim and dim:FindFirstChild("Card") or nil, dim
end
-- 2.12: the icon badge mixes surface BADGE_TINT toward the icon colour (a destructive dialog must
-- read before its button row does), so it is no longer the surface token by identity. The factor
-- mirrors dialog.lua's local constant -- there is no theme token holding it yet.
local BADGE_TINT = 0.15
local function expectBadge(badge, theme, icon)
  local want = theme.mix(theme.Colors.surface, icon, BADGE_TINT)
  h.expect(badge.BackgroundColor3.R).toBeCloseTo(want.R)
  h.expect(badge.BackgroundColor3.G).toBeCloseTo(want.G)
  h.expect(badge.BackgroundColor3.B).toBeCloseTo(want.B)
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
    expectBadge(header:FindFirstChild("IconBadge"), t, t.Colors.foreground)
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

  -- ---- visual-polish phase 2 (2.12 motion, depth, scrim, footer rule, keyboard, 2.22 UI scale) ----
  local function dims(R, gui)
    local out = {}
    for _, c in ipairs(R.Overlay.get(gui):GetChildren()) do if c.Name == "Dialog" then out[#out + 1] = c end end
    return out
  end
  local function key(name) return { KeyCode = h.roblox.Enum.KeyCode[name] } end

  h.it("card is a CanvasGroup that unfolds fade + zoom + rise and folds out shrink + drop", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    h.mock.resetTweens()
    local handle = R.Dialog.open({ Title = "X", Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    h.expect(card.ClassName).toBe("CanvasGroup")              -- fades as ONE piece
    local ct = h.mock.tweensFor(card)
    h.expect(ct[1].Goal.GroupTransparency).toBe(0)
    h.expect(ct[1].Goal.Position.Y.Offset).toBe(0)            -- risen from Motion.dialogRise to centre
    h.expect(card.GroupTransparency).toBe(0)
    local us = card:FindFirstChildOfClass("UIScale")
    local st = h.mock.tweensFor(us)
    h.expect(st[1].Info.EasingStyle).toBe(h.roblox.Enum.EasingStyle.Back)   -- zoom springs in
    h.expect(us.Scale).toBe(1)
    h.mock.resetTweens()
    handle.Close()
    h.expect(card.GroupTransparency).toBe(1)
    h.expect(card.Position.Y.Offset).toBe(R.Theme.Motion.dialogDrop)        -- drops away
    h.expect(us.Scale).toBe(0.92)
    h.expect(h.mock.tweensFor(card)[1].Info.EasingDirection).toBe(h.roblox.Enum.EasingDirection.In)
  end)

  h.it("Escape closes only the TOP dialog, and gameProcessed input is ignored", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService")
    R.Dialog.open({ Title = "one", Buttons = { { Text = "OK" } } })
    R.Dialog.open({ Title = "two", Buttons = { { Text = "OK" } } })
    h.expect(R.Overlay.dialogDepth()).toBe(2)
    h.expect(#dims(R, gui)).toBe(2)
    uis.InputBegan:Fire(key("Escape"), true)            -- chat/textbox consumed it
    h.expect(#dims(R, gui)).toBe(2)
    uis.InputBegan:Fire(key("Escape"), false)           -- one Escape, one dialog
    h.expect(#dims(R, gui)).toBe(1)
    h.expect(R.Overlay.dialogDepth()).toBe(1)
    uis.InputBegan:Fire(key("Escape"), false)
    h.expect(#dims(R, gui)).toBe(0)
    h.expect(R.Overlay.dialogDepth()).toBe(0)
    uis.InputBegan:Fire(key("Escape"), false)           -- nothing open: must not error
  end)

  h.it("a dialog opened FROM a footer button still answers Escape once its opener closes", function()
    -- fire() runs the callback first and closes its own dialog second, so the ordinary
    -- "a button opens a confirm" flow leaves the INNER dialog alive while the outer one goes.
    -- Gating the keyboard on an open-time depth capture would deafen it forever; only
    -- "am I the top of the stack" is a live test.
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService")
    local confirmed = 0
    R.Dialog.open({ Title = "outer", Buttons = { { Text = "Delete", Callback = function()
      R.Dialog.open({ Title = "confirm", Buttons = { { Text = "Yes", Callback = function() confirmed = confirmed + 1 end } } })
    end } } })
    local row = dialogCard(R, gui):FindFirstChild("Buttons")
    local btn
    for _, c in ipairs(row:GetChildren()) do if c.ClassName == "TextButton" then btn = c; break end end
    btn.MouseButton1Click:Fire()                        -- opens the confirm, then closes the outer
    h.expect(#dims(R, gui)).toBe(1)                     -- only the nested dialog is left
    h.expect(R.Overlay.dialogDepth()).toBe(1)
    uis.InputBegan:Fire(key("Return"), false)           -- ...and it still hears the keyboard
    h.expect(confirmed).toBe(1)
    h.expect(#dims(R, gui)).toBe(0)
    h.expect(R.Overlay.dialogDepth()).toBe(0)
  end)

  h.it("a survivor of a nested pair still closes on Escape", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService")
    local a = R.Dialog.open({ Title = "A", Buttons = { { Text = "OK" } } })
    R.Dialog.open({ Title = "B", Buttons = { { Text = "OK" } } })
    a.Close()                                           -- the OUTER one goes first (out of LIFO order)
    h.expect(#dims(R, gui)).toBe(1)
    uis.InputBegan:Fire(key("Escape"), false)
    h.expect(#dims(R, gui)).toBe(0)
    h.expect(R.Overlay.dialogDepth()).toBe(0)
  end)

  h.it("Return fires the LAST button's callback; gamepad A/B behave like Return/Escape", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService")
    local picked
    R.Dialog.open({ Title = "T", Buttons = {
      { Text = "Cancel", Callback = function() picked = "cancel" end },
      { Text = "Delete", Callback = function() picked = "delete" end } } })
    uis.InputBegan:Fire(key("Return"), false)
    h.expect(picked).toBe("delete")                     -- primary = last button
    h.expect(#dims(R, gui)).toBe(0)
    picked = nil
    R.Dialog.open({ Title = "T", Buttons = { { Text = "Cancel", Callback = function() picked = "cancel" end } } })
    uis.InputBegan:Fire(key("ButtonB"), false)          -- gamepad B = close, no callback
    h.expect(picked).toBeNil()
    h.expect(#dims(R, gui)).toBe(0)
    R.Dialog.open({ Title = "T", Buttons = { { Text = "OK", Callback = function() picked = "ok" end } } })
    uis.InputBegan:Fire(key("ButtonA"), false)
    h.expect(picked).toBe("ok")
  end)

  h.it("a second dialog does not double the scrim; the alpha follows the mode", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "one", Buttons = { { Text = "OK" } } })
    local second = R.Dialog.open({ Title = "two", Buttons = { { Text = "OK" } } })
    local d = dims(R, gui)
    h.expect(d[1].BackgroundTransparency).toBe(R.Theme.Opacity.dialogScrim.dark)
    h.expect(d[2].BackgroundTransparency).toBe(1)       -- stacked: no second scrim
    second.Close()
    local light = R.Theme.applyMode(R.Theme.new(), "light")
    R.Dialog.open({ Title = "lit", Theme = light, Buttons = { { Text = "OK" } } })
    local d2 = dims(R, gui)
    h.expect(d2[#d2].BackgroundTransparency).toBe(1)    -- still stacked under the first
    local R2 = h.loadLib(); local gui2 = h.roblox.Instance.new("ScreenGui"); R2.Overlay.get(gui2)
    R2.Dialog.open({ Title = "lit", Theme = R2.Theme.applyMode(R2.Theme.new(), "light"), Buttons = { { Text = "OK" } } })
    h.expect(dims(R2, gui2)[1].BackgroundTransparency).toBe(R2.Theme.Opacity.dialogScrim.light)
  end)

  h.it("a hairline rule sits above the footer on non-touch and is absent on touch", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "T", Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    local rule = card:FindFirstChild("FooterRule")
    h.expect(rule ~= nil).toBeTruthy()
    h.expect(rule.Size.Y.Offset).toBe(1)
    h.expect(rule.BackgroundColor3).toBe(R.Theme.Colors.border)
    h.expect(rule.BackgroundTransparency).toBe(R.Theme.Stroke.divider)
    h.expect(rule.LayoutOrder < card:FindFirstChild("Buttons").LayoutOrder).toBeTruthy()
    local R2 = h.loadLib(); local gui2 = h.roblox.Instance.new("ScreenGui"); R2.Overlay.get(gui2)
    local uis = h.roblox.game:GetService("UserInputService"); uis.TouchEnabled = true
    R2.Dialog.open({ Title = "T", Buttons = { { Text = "OK" } } })
    uis.TouchEnabled = false
    h.expect(dialogCard(R2, gui2):FindFirstChild("FooterRule")).toBeNil()
  end)

  h.it("DialogShadow: none while shadowId is empty; otherwise a modal-layer sibling that follows the card", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Dialog.open({ Title = "T", Theme = R.Theme.new({ Effect = { shadowId = "" } }), Buttons = { { Text = "OK" } } })
    local _, dim = dialogCard(R, gui)
    h.expect(dim:FindFirstChild("DialogShadow")).toBeNil()         -- no asset configured: layer skipped
    local R2 = h.loadLib(); local gui2 = h.roblox.Instance.new("ScreenGui"); R2.Overlay.get(gui2)
    local t = R2.Theme.new({ Effect = { shadowId = "rbxassetid://1" } })
    R2.Dialog.open({ Title = "T", Theme = t, Buttons = { { Text = "OK" } } })
    local card2, dim2 = dialogCard(R2, gui2)
    local sh = dim2:FindFirstChild("DialogShadow")
    h.expect(sh ~= nil).toBeTruthy()
    h.expect(sh.ZIndex).toBe(R2.Overlay.Z.modal)
    h.expect(sh.ZIndex < card2.ZIndex).toBeTruthy()                -- sibling BELOW the card
    h.expect(sh.ImageTransparency).toBe(R2.Theme.MODE_EFFECTS.dark.shadow)
    -- follow(): property signals never auto-fire, so set the Absolute* pair then fire it
    dim2.AbsolutePosition = h.roblox.Vector2.new(0, 0)
    card2.AbsolutePosition = h.roblox.Vector2.new(100, 50)
    card2.AbsoluteSize = h.roblox.Vector2.new(320, 200)
    card2:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    h.expect(sh.Size.X.Offset).toBe(320 + 2 * R2.Theme.Effect.dialog.spread)
    h.expect(sh.Position.Y.Offset).toBe(50 + 100 + R2.Theme.Effect.dialog.offsetY)
  end)

  h.it("a standalone card takes the overlay UI scale; a window-scoped one never scales twice", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    R.Overlay.setScale(1.3)
    R.Dialog.open({ Title = "T", Buttons = { { Text = "OK" } } })
    local card = dialogCard(R, gui)
    h.expect(card:FindFirstChildOfClass("UIScale").Scale).toBe(1.3)  -- zoom resolved to the UI scale
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Dialog({ Title = "inside", Buttons = { { Text = "OK" } } })
    local wcard = w.Main:FindFirstChild("Dialog"):FindFirstChild("Card")
    h.expect(wcard:FindFirstChildOfClass("UIScale").Scale).toBe(1)   -- Main already carries winScale
    R.Overlay.setScale(1)
  end)

  h.it("reduced motion: open and close land on their end state with no tweens at all", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    h.withReducedMotion(R, function()
      h.mock.resetTweens()
      local handle = R.Dialog.open({ Title = "T", Message = "m", Buttons = { { Text = "OK" } } })
      local card, dim = dialogCard(R, gui)
      h.expect(h.mock.tweenCount()).toBe(0)
      h.expect(card.GroupTransparency).toBe(0)                            -- unfolded instantly
      h.expect(card.Position.Y.Offset).toBe(0)
      h.expect(card:FindFirstChildOfClass("UIScale").Scale).toBe(1)
      h.expect(dim.BackgroundTransparency).toBe(R.Theme.Opacity.dialogScrim.dark)
      handle.Close()
      h.expect(#dims(R, gui)).toBe(0)                                     -- and folded away instantly
      h.expect(h.mock.tweenCount()).toBe(0)
    end)
  end)

  h.it("a dialog torn down with its window releases the keyboard slot", function()
    local R = h.loadLib(); local gui = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(gui)
    local uis = h.roblox.game:GetService("UserInputService")
    local w = R.Window.new({ Title = "W", Parent = gui })
    w:Dialog({ Title = "inside", Buttons = { { Text = "OK" } } })
    h.expect(R.Overlay.dialogDepth()).toBe(1)
    w.Main:FindFirstChild("Dialog"):Destroy()          -- window teardown: no handle.Close()
    uis.InputBegan:Fire(key("Escape"), false)
    h.expect(R.Overlay.dialogDepth()).toBe(0)          -- slot released, not blocked forever
    local picked
    R.Dialog.open({ Title = "next", Buttons = { { Text = "OK", Callback = function() picked = "ok" end } } })
    uis.InputBegan:Fire(key("Return"), false)
    h.expect(picked).toBe("ok")                        -- the next dialog is reachable again
  end)
  h.it("opening a dialog closes any popover left open underneath it (2.12)", function()
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    -- A dropdown parks itself in the overlay via trackPopover; a dialog takes the whole screen, so
    -- a survivor would float ABOVE the scrim (dropdowns sit at Z.popover, the scrim at Z.modal-...
    -- only by ZIndex, and the stale list would also leak into the next closeAll).
    local closed = false
    R.Overlay.trackPopover(function() closed = true end)
    R.Dialog.open({ Title = "t", Buttons = { { Text = "OK" } } })
    h.expect(closed).toBe(true)
  end)
end)
h.run()
