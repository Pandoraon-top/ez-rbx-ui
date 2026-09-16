-- Deps injected via Init(R). Layer kit: 9-slice shadow/glow siblings, gradient rim on a
-- UIStroke, lift/reskin helpers and a skeleton shimmer. Under ZIndexBehavior.Sibling a child
-- always renders above its parent's fill, so dark/glow layers are SIBLINGS of the host with a
-- lower ZIndex (never children); the caller picks that ZIndex.
--
-- Every function takes the owning window's theme explicitly (2nd positional arg on the
-- constructors, trailing arg on the geometry helpers) and throws without one: the module never
-- reads a global theme, so light/dark values always come from the theme actually being rendered.
--
--   Effects.shadow(parent, theme, { name, level, zIndex })  -> ImageLabel | nil (shadowId == '')
--   Effects.glow(parent, theme, colorToken, level, zIndex, name) -> ImageLabel | nil (mobile/'off')
--   Effects.place(shadow, x, y, w, h, level, theme)          one-shot geometry (px, host top-left)
--   Effects.mirror(shadow, host, level, theme)              geometry from host.Position/Size
--   Effects.follow(shadow, host, level, theme, maid)        Absolute* property signals -> place
--   Effects.rim(stroke, theme)                              gradient child on a UIStroke
--   Effects.lift(shadow, theme, on)                         drag/resize spread + darken
--   Effects.reskin(layer, theme, kind, colorToken)          re-apply per-mode alpha/tint
--   Effects.skeleton(parent, theme, { size, radius, ... })  -> { Frame, Gradient, Stop }
-- `level` is a key of theme.Effect holding { spread, offsetY }: window/dialog/popover/toast/
-- tooltip/control. Every helper that takes a layer tolerates nil (shadows are nil until the
-- 9-slice asset id is verified in Studio), so call sites need no `if shadow then` of their own.
local Effects = {}
local Create, Theme, Animate, Safe, Device

-- Skeleton shimmer defaults until theme.lua grows an Effect.skeleton group; a theme that
-- defines { period, rotation, band } under Effect.skeleton wins over these.
local SKELETON = { period = 1.1, rotation = 15 }
-- Per-layer bookkeeping (level, kind, tint token, rest size, lifted flag) keyed weakly by the
-- instance so a destroyed layer never pins its entry.
local meta = setmetatable({}, { __mode = "k" })

function Effects.Init(R)
  Create = R.Create; Theme = R.Theme; Animate = R.Animate; Safe = R.Safe; Device = R.Device
end

local function need(theme, fn)
  if type(theme) ~= "table" or type(theme.Effect) ~= "table" then
    error("Effects." .. fn .. ": theme (Theme.new instance) required", 3)
  end
  return theme
end

local function metaOf(layer)
  local m = meta[layer]
  if not m then m = {}; meta[layer] = m end
  return m
end

-- A layer remembers the level it was created with, so geometry calls may omit it.
local function levelOf(theme, level, layer)
  local key = level or (meta[layer] and meta[layer].level) or "control"
  local lv = theme.Effect[key]
  if type(lv) ~= "table" or type(lv.spread) ~= "number" then
    error("Effects: unknown level '" .. tostring(key) .. "' (window/dialog/popover/toast/tooltip/control)", 3)
  end
  return lv
end

local function shadowId(theme)
  local id = theme.Effect.shadowId
  if type(id) ~= "string" or id == "" then return nil end
  return id
end

-- Shared 9-slice ImageLabel for shadow and glow. SliceCenter only where Rect exists: an executor
-- without the Rect global would otherwise throw here, and a stretched slice still renders as a
-- soft blob rather than nothing.
local function sliceLayer(parent, theme, props)
  local img = Create("ImageLabel", {
    Name = props.name, Image = shadowId(theme), ScaleType = Enum.ScaleType.Slice,
    ImageColor3 = props.color, ImageTransparency = props.alpha,
    AnchorPoint = Vector2.new(0.5, 0.5), Active = false, BackgroundTransparency = 1,
    ZIndex = props.zIndex or 0, Parent = parent,
  })
  if Rect and Rect.new then
    local s = theme.Effect.slice
    img.SliceCenter = Rect.new(s.x0, s.y0, s.x1, s.y1)
  end
  return img
end

-- Filled (not hollow) 9-slice shadow, black tint, per-mode alpha. nil while Effect.shadowId is
-- '' (the default until the asset is verified in Studio).
function Effects.shadow(parent, theme, opts)
  need(theme, "shadow"); opts = opts or {}
  if not shadowId(theme) then return nil end
  local img = sliceLayer(parent, theme, {
    name = opts.name or "Shadow", color = Color3.new(0, 0, 0), alpha = Theme.fx(theme).shadow, zIndex = opts.zIndex,
  })
  local m = metaOf(img); m.kind = "shadow"; m.level = opts.level
  return img
end

-- controlGlow 'auto' skips glows on phones (small screens, no hover to reveal them), 'off'
-- skips them everywhere; anything else keeps them.
local function glowAllowed(theme)
  local mode = theme.Effect.controlGlow
  if mode == "off" or mode == false then return false end
  if mode == "auto" and Device.IsMobile() then return false end
  return true
end

-- Same asset tinted with the token Color3 itself (not a copy) so identity compares and reskin
-- work; rests hidden (ImageTransparency 1), the owner tweens it to Theme.fx(theme).glow.
function Effects.glow(parent, theme, colorToken, level, zIndex, name)
  need(theme, "glow")
  if colorToken == nil then error("Effects.glow: colorToken (a theme.Colors value) required", 2) end
  if not shadowId(theme) or not glowAllowed(theme) then return nil end
  local img = sliceLayer(parent, theme, { name = name or "Glow", color = colorToken, alpha = 1, zIndex = zIndex })
  local m = metaOf(img); m.kind = "glow"; m.level = level; m.token = colorToken
  return img
end

-- ---- geometry ---------------------------------------------------------------------------------
-- A lifted layer keeps its extra spread through place/mirror so the per-frame mirror during a
-- drag does not undo lift(); `rest` is the unlifted size the next lift(false) returns to.
local function growth(theme, m)
  return m.lifted and 2 * theme.Effect.lift.spreadDelta or 0
end

local function writeGeometry(shadow, theme, m, rest, xs, xo, ys, yo)
  m.rest = rest
  local g = growth(theme, m)
  shadow.Size = UDim2.new(rest[1], rest[2] + g, rest[3], rest[4] + g)
  shadow.Position = UDim2.new(xs, xo, ys, yo)
end

-- One-shot geometry from a host rect in px (top-left x/y, size w/h): the layer is centred on
-- the host, grown by 2*spread and dropped by offsetY (popover, tooltip, dialog via follow).
function Effects.place(shadow, x, y, w, h, level, theme)
  if not shadow then return nil end
  need(theme, "place")
  local lv, m = levelOf(theme, level, shadow), metaOf(shadow)
  writeGeometry(shadow, theme, m, { 0, w + 2 * lv.spread, 0, h + 2 * lv.spread }, 0, x + w / 2, 0, y + h / 2 + lv.offsetY)
  return shadow
end

-- Geometry from host.Position/host.Size (UDim2 math: same Scale, Offset + 2*spread / + offsetY).
-- Honours host.AnchorPoint, so a centre-pivoted window and a top-left FAB both get a centred
-- shadow; with AnchorPoint (0.5, 0.5) the Position is simply the host's plus offsetY.
function Effects.mirror(shadow, host, level, theme)
  if not (shadow and host) then return nil end
  need(theme, "mirror")
  local pos, size = host.Position, host.Size
  if not (pos and size) then return shadow end
  local lv, m = levelOf(theme, level, shadow), metaOf(shadow)
  local a = host.AnchorPoint
  local ax, ay = a and a.X or 0, a and a.Y or 0
  local sp = 2 * lv.spread
  writeGeometry(shadow, theme, m, { size.X.Scale, size.X.Offset + sp, size.Y.Scale, size.Y.Offset + sp },
    pos.X.Scale + (0.5 - ax) * size.X.Scale, pos.X.Offset + (0.5 - ax) * size.X.Offset,
    pos.Y.Scale + (0.5 - ay) * size.Y.Scale, pos.Y.Offset + (0.5 - ay) * size.Y.Offset + lv.offsetY)
  return shadow
end

-- Track an AutomaticSize host (dialog card) through its Absolute* property signals. Signal
-- handlers run on engine threads, so the write goes through Safe.mutate; nil Absolute* (headless
-- mock, or a host not yet laid out) skips the sync. Absolute coordinates are screen-space, so
-- the shadow's parent origin is subtracted to land in the shared parent's local space.
-- Returns { Sync, Disconnect } (maid-compatible) and gives it to `maid` when one is passed.
function Effects.follow(shadow, host, level, theme, maid)
  if not (shadow and host) then return nil end
  need(theme, "follow")
  levelOf(theme, level, shadow)
  local function sync()
    local ap, as = host.AbsolutePosition, host.AbsoluteSize
    if not (ap and as) then return end
    local parent = shadow.Parent
    local pp = parent and parent.AbsolutePosition
    local px, py = pp and pp.X or 0, pp and pp.Y or 0
    Effects.place(shadow, ap.X - px, ap.Y - py, as.X, as.Y, level, theme)
  end
  local function deferred() Safe.mutate(sync) end
  local c1 = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(deferred)
  local c2 = host:GetPropertyChangedSignal("AbsolutePosition"):Connect(deferred)
  local handle = { Sync = sync, Disconnect = function() c1:Disconnect(); c2:Disconnect() end }
  if maid then maid:Give(handle) end
  sync()
  return handle
end

-- ---- rim ----------------------------------------------------------------------------------------
local function rimStops(fx) return { { 0, fx.edgeTop }, { 1, fx.edgeBottom } } end

local function paintRim(g, fx)
  g.Rotation = 90
  g.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, fx.edgeTop), NumberSequenceKeypoint.new(1, fx.edgeBottom),
  })
  return g
end

-- Edge light: ONE UIGradient child on the stroke whose Transparency multiplies the stroke's
-- (lit at the top, fading down). stroke.Color is never touched (tests compare it by reference)
-- and a second call updates the existing gradient in place (reskin path).
function Effects.rim(stroke, theme)
  if not stroke then return nil end
  local fx = Theme.fx(need(theme, "rim"))
  local g = stroke:FindFirstChildOfClass("UIGradient")
  if g then return paintRim(g, fx) end
  g = Create.shade({ rotation = 90, stops = rimStops(fx) })
  g.Name = "Rim"; g.Parent = stroke
  return g
end

-- ---- lift / reskin --------------------------------------------------------------------------
-- Rest size: what place/mirror last wrote, else the current Size (a shadow lifted before any
-- placement is assumed unlifted).
local function restOf(shadow, m)
  if m.rest then return m.rest end
  local s = shadow.Size
  if not s then return nil end
  m.rest = { s.X.Scale, s.X.Offset, s.Y.Scale, s.Y.Offset }
  return m.rest
end

local function shadowAlpha(theme, lifted)
  local fx = Theme.fx(theme)
  return lifted and (fx.shadow + theme.Effect.lift.alphaDelta) or fx.shadow
end

-- Grab feedback (drag/resize): spread grows by 2*lift.spreadDelta and the alpha shifts by
-- lift.alphaDelta while `on`; back to rest on release. Motion.fast either way.
function Effects.lift(shadow, theme, on)
  if not shadow then return nil end
  need(theme, "lift")
  local m = metaOf(shadow)
  m.lifted = on and true or false
  local goal = { ImageTransparency = shadowAlpha(theme, m.lifted) }
  local rest = restOf(shadow, m)
  if rest then
    local g = growth(theme, m)
    goal.Size = UDim2.new(rest[1], rest[2] + g, rest[3], rest[4] + g)
  end
  return Animate.to(shadow, "fast", goal)
end

-- Re-apply per-mode alpha/tint after SetMode/SetAccent. `kind` and `colorToken` default to what
-- the layer was created with. A shown glow (alpha < 1) picks up the new mode's glow alpha; a
-- hidden one stays hidden. 'rim' accepts the UIStroke or its gradient.
function Effects.reskin(layer, theme, kind, colorToken)
  if not layer then return nil end
  need(theme, "reskin")
  local m = meta[layer]
  kind = kind or (m and m.kind)
  if kind == "shadow" then
    layer.ImageTransparency = shadowAlpha(theme, m and m.lifted)
  elseif kind == "glow" then
    local tok = colorToken or (m and m.token)
    if tok then layer.ImageColor3 = tok; metaOf(layer).token = tok end
    if (layer.ImageTransparency or 1) < 1 then layer.ImageTransparency = Theme.fx(theme).glow end
  elseif kind == "rim" then
    if layer.ClassName == "UIStroke" then return Effects.rim(layer, theme) end
    paintRim(layer, Theme.fx(theme))
  else
    error("Effects.reskin: kind 'shadow' | 'glow' | 'rim' required", 2)
  end
  return layer
end

-- ---- skeleton -------------------------------------------------------------------------------
-- Loading placeholder: a surface block with a diagonal band swept across it by ONE looping
-- gradient tween (Offset -1 -> 1). Under reduced motion Animate.loop rests the gradient at its
-- goal (band swept out of view) and creates no tween, so the block is static. Stop() cancels the
-- loop, fades the block out (fold-out curve) and destroys it; instant when motion is off.
-- opts: size (UDim2), radius, name, position, zIndex, band (Color3 multiplier at the band centre).
function Effects.skeleton(parent, theme, opts)
  need(theme, "skeleton"); opts = opts or {}
  local sk = theme.Effect.skeleton or SKELETON
  local frame = Create("Frame", {
    Name = opts.name or "Skeleton", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
    Size = opts.size or UDim2.new(1, 0, 1, 0), Position = opts.position, ZIndex = opts.zIndex,
    Active = false, Parent = parent,
  })
  Create.corner(opts.radius or theme.Radius.sm).Parent = frame
  local white = Color3.new(1, 1, 1)
  local band = opts.band or sk.band or Theme.fx(theme).inset
  local g = Create.gradient({ rotation = sk.rotation or SKELETON.rotation, stops = { { 0, white }, { 0.5, band }, { 1, white } } })
  g.Name = "Shimmer"; g.Offset = Vector2.new(-1, 0); g.Parent = frame
  local loop = Animate.loop(g, sk.period or SKELETON.period, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Linear)
  local stopped = false
  local function Stop()
    if stopped then return end
    stopped = true
    loop.Cancel()
    -- owner already torn down (parent destroyed) -> nothing left to fade
    if frame.Parent == nil then frame:Destroy(); return end
    Animate.exitTo(frame, "exit", { BackgroundTransparency = 1 }, function() frame:Destroy() end)
  end
  return { Frame = frame, Gradient = g, Stop = Stop }
end

return Effects
