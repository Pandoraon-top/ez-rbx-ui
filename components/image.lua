-- Deps injected via Init(R).
local Image = {}
local Create, DefaultTheme, Icons, Safe
function Image.Init(R) Create = R.Create; DefaultTheme = R.Theme; Icons = R.Icons; Safe = R.Safe end
function Image.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local img = Create("ImageLabel", {
    Name = "Image", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
    Image = opts.Image or "", ImageColor3 = opts.Color or Color3.fromRGB(255, 255, 255),
    Size = UDim2.new(1, 0, 0, opts.Height or 80), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
  })
  -- A Lucide glyph without an explicit Color follows the foreground token, so it must re-tint on
  -- SetMode; a caller-owned Color3 is left alone. Plain images never register.
  local glyphColor = function() return opts.Color or theme.Colors.foreground end
  if opts.Lucide then Icons.apply(img, opts.Lucide, glyphColor()) end
  local unreg = (opts.Lucide and not opts.Color and opts.AccentReg) and opts.AccentReg(function()
    Icons.apply(img, opts.Lucide, glyphColor())
  end)
  return {
    Frame = img,
    SetImage = function(v) Safe.mutate(function() img.Image = v end) end,
    Destroy = function() if unreg then unreg() end; img:Destroy() end,
  }
end
return Image
