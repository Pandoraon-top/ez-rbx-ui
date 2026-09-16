-- Deps injected via Init(R).
local Separator = {}
local Create, DefaultTheme

function Separator.Init(R) Create = R.Create; DefaultTheme = R.Theme end

function Separator.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local frame = Create("Frame", {
    Name = "Separator",
    BackgroundColor3 = theme.Colors.border,
    BackgroundTransparency = theme.Stroke.divider,   -- divider alpha role, shared with accordion/table rules
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 1),
    LayoutOrder = opts.LayoutOrder or 0,
    Parent = opts.Parent,
  })
  -- keep the unregister so Destroy drops the closure (one used to leak per destroyed separator)
  local unreg = opts.AccentReg and opts.AccentReg(function() frame.BackgroundColor3 = theme.Colors.border end)
  return { Frame = frame, Destroy = function() if unreg then unreg() end; frame:Destroy() end }
end

return Separator
