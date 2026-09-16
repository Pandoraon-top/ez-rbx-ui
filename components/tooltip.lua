-- Deps injected via Init(R). Mixin-style: Tooltip.attach(target, text) wires hover.
-- An INVERTED chip (foreground fill, background text) with a soft shadow, shown only after
-- Tooltip.delay so a pointer sweeping a column of rows never strobes a trail of tips behind it.
local Tooltip = {}
local Create, DefaultTheme, Maid, Overlay, Animate, Device, Safe, Effects
local TextService = game:GetService("TextService")

function Tooltip.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Animate = R.Animate
  Device = R.Device; Safe = R.Safe; Effects = R.Effects
end

-- Average glyph advance, used only when TextService is unavailable. The chip itself is
-- AutomaticSize.X: this width only drives the viewport clamp and the shadow rectangle.
local GLYPH_W = 0.55

local function measure(text, size)
  local ok, v = pcall(function()
    return TextService:GetTextSize(text, size, Enum.Font.BuilderSans, Vector2.new(10000, 10000))
  end)
  if ok and v and v.X then return v.X end
  return #tostring(text) * size * GLYPH_W
end

function Tooltip.attach(target, text, themeArg)
  local theme = themeArg or DefaultTheme
  local maid = Maid.new()
  local handle = { Destroy = function() maid:DoCleanup() end }
  -- Touch has no hover: a tap would leave the chip stranded on screen with nothing to dismiss it,
  -- so the whole mixin is a no-op there (no connections, no handle state).
  if Device and Device.IsTouch() then return handle end

  local tip, shadow, armed

  -- Anchored bottom-centre above the target, clamped inside the viewport and flipped BELOW when
  -- the chip would run off the top. Absolute* are nil headless / before the first layout pass, so
  -- everything degrades to the top-left corner rather than erroring.
  local function geometry(scale)
    local T = theme.Tooltip
    local ap, as = target.AbsolutePosition, target.AbsoluteSize
    local tx, ty = (ap and ap.X or 0), (ap and ap.Y or 0)
    local tw, th = (as and as.X or 0), (as and as.Y or 0)
    local gap, hgt = T.gap * scale, T.height * scale
    local w = (measure(text, theme.Font.muted.Size) + 2 * T.padX) * scale
    local vp = Overlay.viewport()
    local y = ty - gap                                     -- AnchorPoint (0.5, 1): y is the BOTTOM
    if y - hgt < 0 then y = ty + th + gap + hgt end        -- no room above -> flip below
    if y > vp.Y then y = vp.Y end
    local half = w / 2
    local x = math.max(half, math.min(tx + tw / 2, vp.X - half))
    return x, y, w, hgt
  end

  local function build()
    if tip then return end
    local T = theme.Tooltip
    local scale = Overlay.scale()                          -- 2.22: the tip owns its own UIScale
    local x, y, w, hgt = geometry(scale)
    -- Inverted: the chip is the foreground colour with background-coloured text, so it reads as a
    -- label ABOUT the UI rather than another surface of it. No stroke -- the inversion is the edge.
    tip = Create("TextLabel", {
      Name = "Tooltip", BackgroundColor3 = theme.Colors.foreground, BackgroundTransparency = 1,
      BorderSizePixel = 0, Text = text, TextColor3 = theme.Colors.background, TextTransparency = 1,
      AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, x, 0, y),
      Size = UDim2.new(0, 0, 0, T.height), AutomaticSize = Enum.AutomaticSize.X,
      ZIndex = Overlay.Z.tooltip,
      Create.corner(theme.Radius.sm), Create.padding({ left = T.padX, right = T.padX }),
    })
    Create.text(tip, theme, "muted")
    -- ONE UIScale: the UI scale with the pop folded into it (Animate.pop would overwrite it with 1).
    local us = Create("UIScale", { Scale = scale * theme.Motion.popFrom, Parent = tip })
    Overlay.mount(tip)
    -- Sibling shadow one layer below the chip; nil while Effect.shadowId is ''.
    shadow = Effects.shadow(tip.Parent, theme, { name = "TooltipShadow", level = "tooltip",
      zIndex = Overlay.Z.tooltip - 1 })
    if shadow then
      shadow.ImageTransparency = 1
      Effects.place(shadow, x - w / 2, y - hgt, w, hgt, "tooltip", theme)
      Animate.to(shadow, "fast", { ImageTransparency = (theme.fx or DefaultTheme.fx)(theme).shadow })
    end
    Animate.springTo(us, "fast", { Scale = scale })
    Animate.to(tip, "fast", { BackgroundTransparency = 0, TextTransparency = 0 })
  end

  -- Fade out first, destroy on completion: the chip is cleared from `tip` immediately so a new
  -- hover during the fade builds a fresh one instead of adopting the dying instance.
  local function hide()
    local t, s = tip, shadow
    tip, shadow = nil, nil
    if not t then return end
    if s then Animate.to(s, "exit", { ImageTransparency = 1 }, Animate.EASING.exit, Animate.DIR.In) end
    Animate.toThen(t, "exit", { BackgroundTransparency = 1, TextTransparency = 1 }, function()
      t:Destroy()
      if s then s:Destroy() end
    end, Animate.EASING.exit, Animate.DIR.In)
  end

  -- Hover intent: arm a token, and only build if the SAME token is still armed when the delay
  -- elapses -- a MouseLeave (or a second enter) in the meantime drops it. The callback runs on a
  -- task.delay thread, which has no GUI capability on strict executors, hence Safe.mutate.
  local function onEnter()
    if tip then return end
    local token = {}
    armed = token
    local function fire()
      if armed == token and not tip then Safe.mutate(build) end
    end
    if type(task) == "table" and task.delay then task.delay(theme.Tooltip.delay, fire) else fire() end
  end

  local function onLeave()
    armed = nil
    hide()
  end

  maid:Give(target.MouseEnter:Connect(onEnter))
  maid:Give(target.MouseLeave:Connect(onLeave))
  maid:Give(function() onLeave() end)
  return handle
end

return Tooltip
