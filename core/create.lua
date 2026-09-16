-- Callable table: Create("Frame", {...}) builds an instance; Create.corner/padding/... are helpers.
local Create = {}

local function build(className, props)
  local inst = Instance.new(className)
  props = props or {}
  local parent
  for k, v in pairs(props) do
    if type(k) == "number" then
      v.Parent = inst                 -- child
    elseif k == "Parent" then
      parent = v                      -- defer
    else
      inst[k] = v
    end
  end
  if parent then inst.Parent = parent end
  return inst
end

setmetatable(Create, { __call = function(_, className, props) return build(className, props) end })

function Create.corner(radius)
  return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Create.padding(t)
  t = t or {}
  return Create("UIPadding", {
    PaddingTop = UDim.new(0, t.top or t.all or 0),
    PaddingBottom = UDim.new(0, t.bottom or t.all or 0),
    PaddingLeft = UDim.new(0, t.left or t.all or 0),
    PaddingRight = UDim.new(0, t.right or t.all or 0),
  })
end

function Create.listLayout(opts)
  opts = opts or {}
  return Create("UIListLayout", {
    Padding = UDim.new(0, opts.Padding or 0),
    FillDirection = opts.FillDirection or Enum.FillDirection.Vertical,
    SortOrder = opts.SortOrder or Enum.SortOrder.LayoutOrder,
  })
end

-- Transparency is passed through the constructor table: a nil value never becomes a key, so
-- callers that omit it leave the UIStroke default (0) untouched and existing stroke assertions
-- keep their shape.
function Create.stroke(color, thickness, transparency)
  return Create("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency })
end

-- Keypoint array from { {t, value}, ... } pairs. Always an array literal (never the single-value
-- or two-value Sequence overloads) so the mock exposes Color.color[1] (window_test reads it) and
-- Roblox takes the same multi-keypoint constructor path headless and in Studio. Fails fast here
-- instead of at Roblox's opaque "keypoint" error inside Sequence.new.
local function keypoints(stops, ctor, what)
  if type(stops) ~= "table" or #stops == 0 then
    error("Create." .. what .. ": stops = { {t, value}, ... } required", 3)
  end
  local out = {}
  for i, s in ipairs(stops) do out[i] = ctor(s[1], s[2]) end
  return out
end

-- Colour gradient: { rotation = deg, stops = { {0, Color3}, {1, Color3} } }
function Create.gradient(opts)
  opts = opts or {}
  return Create("UIGradient", {
    Rotation = opts.rotation or 0,
    Color = ColorSequence.new(keypoints(opts.stops, ColorSequenceKeypoint.new, "gradient")),
  })
end

-- Transparency-only gradient (a "shade" over an existing fill): stops = { {t, alpha}, ... }.
-- Colour is left at the UIGradient default (white) so it multiplies the fill to itself.
function Create.shade(opts)
  opts = opts or {}
  return Create("UIGradient", {
    Rotation = opts.rotation or 0,
    Transparency = NumberSequence.new(keypoints(opts.stops, NumberSequenceKeypoint.new, "shade")),
  })
end

-- Apply a theme Font role (title/header/label/body/muted) to a TextLabel/TextButton/TextBox.
-- Unknown roles degrade to body instead of a nil index so a typo still renders. FontFace is
-- written only when the theme resolves one (Theme.FontFace may return nil where Font.fromName
-- is unavailable); Font stays BuilderSans either way so the label never falls back to the
-- engine default face. LineHeight is written only for roles that declare it.
function Create.text(label, theme, role)
  local fonts = type(theme) == "table" and theme.Font or nil
  local spec = fonts and (fonts[role] or fonts.body)
  if not spec then error("Create.text: theme.Font[" .. tostring(role) .. "] (or .body fallback) required", 2) end
  label.Font = Enum.Font.BuilderSans
  label.TextSize = spec.Size
  if spec.LineHeight ~= nil then label.LineHeight = spec.LineHeight end
  local face = type(theme.FontFace) == "function" and theme.FontFace(spec.Weight) or nil
  if face ~= nil then label.FontFace = face end
  return label
end

return Create
