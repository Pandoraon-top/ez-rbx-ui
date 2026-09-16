-- Deps injected via Init(R). Never call other modules from Init (pairs()-ordered).
local Acrylic = {}
local Create, Theme, Effects

function Acrylic.Init(R) Create = R.Create; Theme = R.Theme; Effects = R.Effects end

-- 2D frosted paint stack (NO Lighting/Workspace mutation): translucent fill + tiled noise grain
-- (clipped by a UICorner) + colour sheen + top highlight band + 1px stroke, all readable over any
-- background. Two rendering facts drive the shape of this file:
--   * UIGradient.Color MULTIPLIES BackgroundColor3. A card-over-background gradient crushed the
--     dark shell to ~black (9 * 24/255); the sheen therefore runs white-ish (fx.sheenTop) at the
--     top so the multiply LIFTS the fill, and light mode (sheenTop nil) uses theme.Colors.card
--     as an identity multiplier. A Transparency gradient on the host would multiply its
--     transparency and make the panel see-through, so the highlight is its own child Frame.
--   * ZIndexBehavior.Sibling renders children above the parent's fill, so noise/sheen/glint are
--     ZIndex 0 children and the rim is a UIGradient on the UIStroke (never a second UIStroke or
--     a second direct-child UIGradient: window_test/acrylic_test look those up by class).
-- opts (F10 signature, shared by decorate and reskin):
--   solid        opaque, no frost layers (dialog card: its UIListLayout would lay them out)
--   transparency host BackgroundTransparency (decorate default FROST; reskin leaves it alone)
--   base         fill Color3 (default theme.Colors.card); pass the LIVE token each call
--   strokeAlpha  UIStroke.Transparency (default theme.Acrylic.strokeAlpha)
--   radius       UICorner radius of the noise/sheen layers + glint inset (default Radius.window)
--   edge         Effects.rim on the stroke + 'AcrylicGlint' hairline (non-solid hosts only)
--   padInset     host UIPadding in px: layers are sized (1,2p,1,2p) at (0,-p,0,-p) so they still
--                reach the rounded edge that the padding pushes every child away from
-- Today's values; a theme that defines Acrylic.frost / Acrylic.glintFade overrides them.
local FROST = 0.12       -- default host BackgroundTransparency
local GLINT_FADE = 0.25  -- glint fades out over this fraction at each end
local HAIRLINE = 1       -- stroke + glint thickness (px)

-- Non-colour opts remembered per host (weak) so a later reskin(frame, theme, { base = ... })
-- keeps the stroke alpha / radius / inset / edge the host was decorated with instead of
-- silently reverting to the defaults. Colours are never stored: applyMode re-assigns the
-- theme.Colors tokens, so a stored Color3 would be stale after a mode switch.
local meta = setmetatable({}, { __mode = "k" })

local function tokens(theme) return theme.Acrylic or Theme.Acrylic end
local function white() return Color3.new(1, 1, 1) end

local function resolve(frame, theme, opts)
  opts = opts or {}
  local A, m = tokens(theme), meta[frame] or {}
  local function pick(k, default)
    local v = opts[k]
    if v == nil then v = m[k] end
    if v == nil then v = default end
    return v
  end
  local o = {
    solid = pick("solid", false) and true or false,
    strokeAlpha = pick("strokeAlpha", A.strokeAlpha),
    radius = pick("radius", theme.Radius.window),
    edge = pick("edge", false) and true or false,
    padInset = pick("padInset", 0),
    base = opts.base or theme.Colors.card,
    transparency = opts.transparency,
  }
  meta[frame] = { solid = o.solid, strokeAlpha = o.strokeAlpha, radius = o.radius, edge = o.edge, padInset = o.padInset }
  return o
end

-- ---- sequences --------------------------------------------------------------------------------
local function colorSeq(stops)
  local kps = {}
  for i, s in ipairs(stops) do kps[i] = ColorSequenceKeypoint.new(s[1], s[2]) end
  return ColorSequence.new(kps)
end

local function numberSeq(stops)
  local kps = {}
  for i, s in ipairs(stops) do kps[i] = NumberSequenceKeypoint.new(s[1], s[2]) end
  return NumberSequence.new(kps)
end

local function sheenStops(theme, fx)
  return { { 0, fx.sheenTop or theme.Colors.card }, { 1, fx.sheenBottom } }
end

-- Highlight band: fx.highlight at the top fading to nothing by Acrylic.highlightBand. The top
-- alpha is scaled by the host's own (1 - transparency) so a Transparency 0.6 window is not
-- over-bright; highlight 1 (light mode) yields a fully transparent band and the layer hides.
local function highlightStops(theme, fx, transparency)
  local top = 1 - (1 - fx.highlight) * (1 - transparency)
  return { { 0, top }, { tokens(theme).highlightBand, 1 }, { 1, 1 } }
end

local function glintStops(theme)
  local fade = tokens(theme).glintFade or GLINT_FADE
  return { { 0, 1 }, { fade, 0 }, { 1 - fade, 0 }, { 1, 1 } }
end

-- ---- geometry ---------------------------------------------------------------------------------
local function layerGeometry(inst, p)
  inst.Position = UDim2.new(0, -p, 0, -p)
  inst.Size = UDim2.new(1, 2 * p, 1, 2 * p)
end

-- Hairline inside the top radius: starts r px in from the left edge, spans the width minus both
-- radii; -p pulls it out of the host padding like the other layers.
local function glintGeometry(inst, r, p)
  inst.Position = UDim2.new(0, r - p, 0, -p)
  inst.Size = UDim2.new(1, 2 * p - 2 * r, 0, HAIRLINE)
end

-- ---- creation (idempotent by Name/class) ------------------------------------------------------
local function ensureStroke(frame, theme, o)
  if frame:FindFirstChildOfClass("UIStroke") then return end
  Create.stroke(theme.Colors.border, HAIRLINE, o.strokeAlpha).Parent = frame
end

local function ensureNoise(frame, theme, o, fx)
  local A = tokens(theme)
  if A.noiseId == "" or frame:FindFirstChild("AcrylicNoise") then return end
  local noise = Create("ImageLabel", {
    Name = "AcrylicNoise", BackgroundTransparency = 1, Image = A.noiseId, ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.new(0, A.tileSize, 0, A.tileSize), ImageColor3 = fx.grainTint, ImageTransparency = fx.grain,
    ZIndex = 0, Active = false, Parent = frame, Create.corner(o.radius),
  })
  layerGeometry(noise, o.padInset)
end

local function ensureGradient(frame, theme, fx)
  if frame:FindFirstChildOfClass("UIGradient") then return end
  Create.gradient({ rotation = 90, stops = sheenStops(theme, fx) }).Parent = frame
end

local function ensureSheen(frame, theme, o, fx, transparency)
  if frame:FindFirstChild("AcrylicSheen") then return end
  local sheen = Create("Frame", {
    Name = "AcrylicSheen", BackgroundColor3 = white(), BackgroundTransparency = 0, BorderSizePixel = 0,
    Visible = fx.highlight < 1, ZIndex = 0, Active = false, Parent = frame, Create.corner(o.radius),
    Create.shade({ rotation = 90, stops = highlightStops(theme, fx, transparency) }),
  })
  layerGeometry(sheen, o.padInset)
end

local function ensureGlint(frame, theme, o, fx)
  if frame:FindFirstChild("AcrylicGlint") then return end
  local glint = Create("Frame", {
    Name = "AcrylicGlint", BackgroundColor3 = white(), BorderSizePixel = 0, BackgroundTransparency = fx.glint,
    Visible = fx.glint < 1, ZIndex = 0, Active = false, Parent = frame,
    Create.shade({ rotation = 0, stops = glintStops(theme) }),
  })
  glintGeometry(glint, o.radius, o.padInset)
end

-- ---- paint (re-apply everything that exists) --------------------------------------------------
local function paintStroke(frame, theme, o)
  local stroke = frame:FindFirstChildOfClass("UIStroke")
  if not stroke then return end
  stroke.Color = theme.Colors.border
  stroke.Transparency = o.strokeAlpha
  -- rim on opt-in, and re-painted whenever one already exists (reskin without the edge opt)
  if Effects and (o.edge or stroke:FindFirstChildOfClass("UIGradient")) then Effects.rim(stroke, theme) end
end

local function paintFrost(frame, theme, fx, transparency)
  local grad = frame:FindFirstChildOfClass("UIGradient")
  if grad then grad.Color = colorSeq(sheenStops(theme, fx)) end
  local noise = frame:FindFirstChild("AcrylicNoise")
  if noise then noise.ImageColor3 = fx.grainTint; noise.ImageTransparency = fx.grain end
  local sheen = frame:FindFirstChild("AcrylicSheen")
  if sheen then
    local g = sheen:FindFirstChildOfClass("UIGradient")
    if g then g.Transparency = numberSeq(highlightStops(theme, fx, transparency)) end
    sheen.Visible = fx.highlight < 1
  end
  local glint = frame:FindFirstChild("AcrylicGlint")
  if glint then glint.BackgroundTransparency = fx.glint; glint.Visible = fx.glint < 1 end
end

-- Fill + every existing layer. Creates nothing except the glint on edge opt-in, and only on a
-- host that already carries the frost stack, so a solid card never grows layers from a reskin.
local function paint(frame, theme, o)
  local fx = Theme.fx(theme)
  frame.BackgroundColor3 = o.base
  if o.solid then frame.BackgroundTransparency = 0
  elseif o.transparency ~= nil then frame.BackgroundTransparency = o.transparency end
  paintStroke(frame, theme, o)
  if o.edge and not o.solid and frame:FindFirstChildOfClass("UIGradient") then ensureGlint(frame, theme, o, fx) end
  paintFrost(frame, theme, fx, frame.BackgroundTransparency or 0)
  return frame
end

function Acrylic.decorate(frame, theme, opts)
  local o = resolve(frame, theme, opts)
  if o.transparency == nil then o.transparency = tokens(theme).frost or FROST end
  ensureStroke(frame, theme, o)
  if not o.solid then
    local fx = Theme.fx(theme)
    ensureNoise(frame, theme, o, fx)
    ensureGradient(frame, theme, fx)
    ensureSheen(frame, theme, o, fx, o.transparency)
  end
  return paint(frame, theme, o)
end

-- Live re-skin after SetMode/SetAccent: fill, sheen keypoints, stroke colour + alpha, grain
-- alpha + tint, highlight band, rim and glint. The host's BackgroundTransparency is left as the
-- owner set it (window SetTransparency writes Main directly) unless opts.transparency is given.
function Acrylic.reskin(frame, theme, opts)
  return paint(frame, theme, resolve(frame, theme, opts))
end

return Acrylic
