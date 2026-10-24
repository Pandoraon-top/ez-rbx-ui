local h = require("tests.helper")

-- Effects = "light" draws flat surfaces: no acrylic noise, sheen, glint or gradients, no 9-slice
-- shadows or glows; strokes, corners and colours stay. "auto" is light on a touch-only device.
h.describe("window Effects budget", function()
  local function make(cfg)
    local R = h.loadLib(); local screen = h.roblox.Instance.new("ScreenGui"); R.Overlay.get(screen)
    cfg = cfg or {}; cfg.Title = "M"; cfg.Parent = screen; cfg.FloatingToggle = cfg.FloatingToggle or true
    return R.Window.new(cfg), R, screen
  end
  local function find(root, name)
    for _, c in ipairs(root:GetChildren()) do
      if c.Name == name then return c end
      local hit = find(c, name)
      if hit then return hit end
    end
  end
  local function countClass(root, cls)
    local n = 0
    for _, c in ipairs(root:GetChildren()) do
      if c.ClassName == cls then n = n + 1 end
      n = n + countClass(c, cls)
    end
    return n
  end

  h.it("full (the default) keeps the acrylic shell and the shadow", function()
    local w = make()
    h.expect(w.Main:FindFirstChild("AcrylicNoise") ~= nil).toBeTruthy()
    h.expect(w.Gui:FindFirstChild("WindowShadow") ~= nil).toBeTruthy()
  end)

  h.it("light: a flat shell, no gradient anywhere in the window, no shadow, no scroll fades", function()
    local w = make({ Effects = "light" })
    for _, name in ipairs({ "AcrylicNoise", "AcrylicSheen", "AcrylicGlint", "ScrollFadeTop", "ScrollFadeBottom" }) do
      h.expect(find(w.Main, name)).toBeNil()
    end
    h.expect(w.Gui:FindFirstChild("WindowShadow")).toBeNil()
    h.expect(countClass(w.Main, "UIGradient")).toBe(0)
    h.expect(w.Main:FindFirstChildOfClass("UIStroke") ~= nil).toBeTruthy()   -- the hairline stays
  end)

  h.it("light: no glow on a toggle that is on, no shadow on the floating button", function()
    local w, R, screen = make({ Effects = "light" })
    local t = w:AddTab({ Name = "T" }):AddToggle({ Text = "x" })
    t.Set(true)
    h.expect(find(t.Frame, "TrackGlow")).toBeNil()
    local overlay = R.Overlay.get(screen)
    h.expect(find(overlay, "FabShadow")).toBeNil()
    h.expect(find(overlay, "FabGlow")).toBeNil()
  end)

  h.it("light: a dropdown is a plain card: no acrylic layers, no gradient, no shadow", function()
    local w, R, screen = make({ Effects = "light" })
    local sb = w:AddTab({ Name = "T" }):AddSelectBox({ Text = "s", Options = { "a", "b" } })
    sb.Open()
    local root = R.Overlay.get(screen)
    local dd = find(root, "SelectDropdown")
    h.expect(dd ~= nil).toBeTruthy()
    h.expect(countClass(dd, "UIGradient")).toBe(0)
    h.expect(dd:FindFirstChild("AcrylicNoise")).toBeNil()
    h.expect(find(root, "SelectDropdownShadow")).toBeNil()
    h.expect(dd:FindFirstChildOfClass("UIStroke") ~= nil).toBeTruthy()
    sb.Close()
  end)

  h.it("light: dialogs and toasts cast no shadow", function()
    local w, R, screen = make({ Effects = "light" })
    w:Notify({ Title = "t", Duration = 0 })
    w:Dialog({ Title = "d", Message = "m", Buttons = { { Text = "OK" } } })
    local root = R.Overlay.get(screen)
    h.expect(find(root, "StackShadow")).toBeNil()
    h.expect(find(w.Main, "DialogShadow")).toBeNil()
    h.expect(countClass(w.Main, "UIGradient")).toBe(0)        -- no rim on the dialog's hairline either
    R.Notification.clearAll()
  end)

  h.it("auto: light on a touch-only device, full with a mouse", function()
    local uis = h.roblox.game:GetService("UserInputService")
    uis.TouchEnabled = true; uis.MouseEnabled = false
    local phone = make({ Effects = "auto" })
    h.expect(phone.Main:FindFirstChild("AcrylicNoise")).toBeNil()
    uis.TouchEnabled = false; uis.MouseEnabled = true
    local desk = make({ Effects = "auto" })
    h.expect(desk.Main:FindFirstChild("AcrylicNoise") ~= nil).toBeTruthy()
  end)

  h.it("an unknown budget warns and keeps the full look", function()
    local ok, w = pcall(make, { Effects = "shiny" })
    h.expect(ok).toBe(true)
    h.expect(w.Main:FindFirstChild("AcrylicNoise") ~= nil).toBeTruthy()
  end)
end)

h.run()
