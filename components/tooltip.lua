-- Deps injected via Init(R). Mixin-style: Tooltip.attach(target, text) wires hover.
local Tooltip = {}
local Create, DefaultTheme, Maid, Overlay, Animate
function Tooltip.Init(R) Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Animate = R.Animate end

function Tooltip.attach(target, text, themeArg)
  local theme = themeArg or DefaultTheme
  local maid = Maid.new()
  local tip
  local function show()
    if tip then return end
    local ap = target.AbsolutePosition
    -- Built fresh on every hover from the live palette, so a tooltip never needs a themer
    -- registration: the next MouseEnter after SetMode/SetAccent already paints the new colours.
    tip = Create("TextLabel", { Name = "Tooltip", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0,
      Text = text, TextColor3 = theme.Colors.foreground,
      Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X,
      Position = UDim2.new(0, ap and ap.X or 0, 0, (ap and ap.Y or 0) - 26),
      ZIndex = 2000, Create.corner(theme.Radius.sm), Create.padding({ left = 6, right = 6 }) })
    Create.text(tip, theme, "muted")
    -- floating surface: opaque hairline (Stroke.floating) like toasts/popovers
    Create.stroke(theme.Colors.border, 1, theme.Stroke.floating).Parent = tip
    Overlay.mount(tip)
    Animate.pop(tip, "fast")
  end
  local function hide() if tip then tip:Destroy(); tip = nil end end
  maid:Give(target.MouseEnter:Connect(show))
  maid:Give(target.MouseLeave:Connect(hide))
  maid:Give(function() hide() end)
  return { Destroy = function() maid:DoCleanup() end }
end
return Tooltip
