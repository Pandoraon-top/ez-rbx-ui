local Theme = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- Every number a component used to hardcode lives here (durations, alphas, sizes, offsets),
-- with TODAY'S literal as the default so adding a token never moves a pixel on its own. Groups
-- are named-field tables only (no arrays): deepMerge recurses into named fields, so a window
-- override like { Sizes = { fab = { size = 48 } } } replaces one leaf and inherits the rest.
local DEFAULT = {
  Colors = {
    background = rgb(9, 9, 11),
    card = rgb(24, 24, 27),
    surface = rgb(39, 39, 42),
    border = rgb(63, 63, 70),
    input = rgb(39, 39, 42),
    ring = rgb(212, 212, 216),
    mutedForeground = rgb(161, 161, 170),
    foreground = rgb(250, 250, 250),
    primary = rgb(250, 250, 250),
    primaryForeground = rgb(24, 24, 27),
    destructive = rgb(239, 68, 68),
    success = rgb(34, 197, 94),
    warning = rgb(234, 179, 8),
    info = rgb(59, 130, 246),
    -- OFF track sits one step above surface (39) so the pill reads against its own row (plan 2.9)
    switchTrackOff = rgb(63, 63, 70),
  },
  Radius = { sm = 6, md = 8, lg = 10, xl = 14, window = 12, input = 6, xs = 2 },
  Spacing = { pad = 16, padLg = 24, inputX = 12, inputY = 8, gap = 8, section = 16, major = 24, icon = 8 },
  Font = {
    title = { Weight = Enum.FontWeight.Bold, Size = 18 },
    header = { Weight = Enum.FontWeight.Medium, Size = 16 },
    label = { Weight = Enum.FontWeight.Medium, Size = 14 },
    body = { Weight = Enum.FontWeight.Regular, Size = 14, LineHeight = 1.25 },
    muted = { Weight = Enum.FontWeight.Regular, Size = 12 },
    overline = { Weight = Enum.FontWeight.Medium, Size = 11 },
  },
  -- fast/base/slow are pinned by animate_test; the rest is the motion grammar (unfold in, fold out)
  Motion = {
    fast = 0.12, base = 0.18, slow = 0.28,
    enter = 0.28, exit = 0.14, hover = 0.12, press = 0.08, release = 0.22, stagger = 0.035,
    enterScale = 0.94, exitScale = 0.96, pressScale = 0.97, hoverScale = 1.06, popFrom = 0.9,
    knobStretch = 1.2, handleGrow = 1.3, handleHover = 1.15, spin = 0.8, snap = 0.3, hideDrift = 12,
    popSlide = 6, dialogRise = 12, dialogDrop = 8, bumpPx = 2,
    shake = { amp = 3, steps = 4, step = 0.04 },
    cascade = { x = 6, y = 8 },
  },
  -- shadowId '' = shadows off until the 9-slice asset is verified in Studio; controlGlow 'auto' = off on mobile
  Effect = {
    shadowId = "", slice = { x0 = 49, y0 = 49, x1 = 450, y1 = 450 },
    window = { spread = 28, offsetY = 6 }, dialog = { spread = 32, offsetY = 10 }, popover = { spread = 18, offsetY = 4 },
    toast = { spread = 16, offsetY = 4 }, tooltip = { spread = 10, offsetY = 2 }, control = { spread = 6, offsetY = 0 },
    lift = { spreadDelta = 8, alphaDelta = -0.12 }, controlGlow = "auto",
    skeleton = { period = 1.1, rotation = 15 },   -- shimmer sweep period (s) and band angle (deg)
  },
  -- UIStroke transparencies; panel/search are per-mode (read through Theme.modeVal)
  Stroke = {
    window = 0.3, floating = 0, control = 0, divider = 0.4, focusThickness = 2,
    panel = { dark = 0.6, light = 0 }, search = { dark = 0.8, light = 0.5 },
  },
  Opacity = {
    hoverWash = 0.94, pressWash = 0.9, hoverFill = 0.12, pressFill = 0.2, ghostHover = 0.4, ghostPress = 0.25,
    tabHover = 0.92, tabPress = 0.88, optionHover = 0.6, rowHover = 0.94, disabled = 0.5, scrim = 0.45,
    dialogScrim = { dark = 0.5, light = 0.6 }, glowHover = 0.7,
  },
  -- frost = default host transparency behind the sheen; glintFade = fade band at each end of the top glint line
  Acrylic = { noiseId = "rbxassetid://9968344105", tileSize = 128, strokeAlpha = 0.3, highlightBand = 0.45, frost = 0.12, glintFade = 0.25 },
  Scrollbar = { imageId = "", alpha = 0.35 },
  Sizes = {
    icon = 16, iconSm = 14, iconButton = 26, touchHit = 44, scrollbar = 4, progress = 8, sliderHit = 24, chip = 22,
    knob = 20, tagMeasureFudge = 1.08, dragKeep = 40,
    titleBar = 40, titleBarTall = 56, -- window.lua TITLE_H / TITLE_H_TALL (title image or subtitle)
    resizeGrip = 12, resizeGripInset = 4, splitGap = 12,
    indicator = { w = 3, h = 18, stretch = 26, radius = 2, haloW = 9, haloH = 26, haloAlpha = 0.85 },
    grip = { w = 2, h = 24 },
    fab = { size = 44, simple = 50, peek = 15, hoverPeek = 7, margin = 16, radius = 12, popFrom = 0.6 },
  },
  -- icon tint roles: names of Colors tokens, resolved at paint time so SetMode/SetAccent re-tint
  Icon = { structural = "mutedForeground", structuralActive = "foreground", accent = "primary" },
  Tooltip = { delay = 0.35, gap = 6, padX = 8, height = 24 },
  Toast = {
    width = 300, inset = 16, gap = 8, peek = 10, maxVisible = 3, peekScale = 0.05, peekFade = 0.18, barHeight = 3,
    padX = 12, padY = 8, progressInset = 0, slide = 48, exitSlide = 32, exitScale = 0.95, typeTint = 0.35,
    badgeAlpha = 0.85, staggerCap = 5,
  },
}

Theme.PALETTES = {
  dark = DEFAULT.Colors,
  -- Tonal ladder: chrome 240 -> surface 244 -> input 250 -> card 255 must stay four distinct steps so
  -- window shell, rows, fields and panels separate without relying on strokes (plan 1.13).
  light = {
    background = rgb(240, 240, 243), card = rgb(255, 255, 255), surface = rgb(244, 244, 245),
    border = rgb(228, 228, 231), input = rgb(250, 250, 250), ring = rgb(24, 24, 27),
    mutedForeground = rgb(113, 113, 122), foreground = rgb(24, 24, 27),
    primary = rgb(24, 24, 27), primaryForeground = rgb(250, 250, 250),
    destructive = rgb(239, 68, 68), success = rgb(34, 197, 94), warning = rgb(234, 179, 8),
    info = rgb(59, 130, 246), switchTrackOff = rgb(212, 212, 216), -- OFF track darker than surface 244 (plan 2.9)
  },
}

-- Per-mode effect values live OUTSIDE DEFAULT: applyMode only swaps Colors, so anything that
-- must flip with the mode is looked up through Theme.fx(theme) at paint time instead of being
-- copied into the instance. light.sheenTop is nil on purpose: the acrylic sheen then falls back
-- to theme.Colors.card (an identity multiplier), keeping the light gradient tests green.
Theme.MODE_EFFECTS = {
  dark = {
    sheenTop = rgb(255, 255, 255), sheenBottom = rgb(214, 214, 222), highlight = 0.93,
    grain = 0.92, grainTint = rgb(255, 255, 255), edgeTop = 0.0, edgeBottom = 0.65, glint = 0.86,
    inset = rgb(196, 196, 206), shadow = 0.5, glow = 0.72,
  },
  light = {
    sheenTop = nil, sheenBottom = rgb(240, 240, 243), highlight = 1,
    grain = 0.97, grainTint = rgb(0, 0, 0), edgeTop = 0.2, edgeBottom = 0.7, glint = 1,
    inset = rgb(236, 236, 240), shadow = 0.8, glow = 0.8,
  },
}

-- swap base+semantic tokens in place, preserving the live accent (primary/primaryForeground)
function Theme.applyMode(theme, mode)
  local p = Theme.PALETTES[mode] or Theme.PALETTES.dark
  for k, v in pairs(p) do
    if k ~= "primary" and k ~= "primaryForeground" then theme.Colors[k] = v end
  end
  theme.Mode = mode
  return theme
end

-- Effect table for the theme's current mode; Mode unset (module default) or unknown reads as dark.
function Theme.fx(theme)
  local mode = type(theme) == "table" and theme.Mode or nil
  return Theme.MODE_EFFECTS[mode] or Theme.MODE_EFFECTS.dark
end

-- A token is per-mode when it is a { dark=, light= } table; anything else (numbers, strings,
-- nested groups like Motion.shake) passes through untouched. A per-mode table missing the
-- current mode falls back to its dark value so a partial override never yields nil.
function Theme.modeVal(theme, tok)
  if type(tok) ~= "table" or (tok.dark == nil and tok.light == nil) then return tok end
  local mode = type(theme) == "table" and theme.Mode or nil
  local v = mode and tok[mode]
  if v == nil then v = tok.dark end
  return v
end

-- Manual lerp on .R/.G/.B only: real Color3 exposes nothing else that is safe here (verify_bundle's
-- faithful Color3 throws on R8/Lerp), and Color3.new keeps the result a plain Color3.
function Theme.mix(a, b, t)
  -- nil guard only: a real Color3 is userdata, so a type()=="table" check would throw in Roblox
  if a == nil or b == nil then error("Theme.mix(a, b, t): two Color3 values required", 2) end
  t = tonumber(t) or 0
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function deepMerge(base, over)
  local out = {}
  for k, v in pairs(base) do
    if type(v) == "table" then out[k] = deepMerge(v, (over and over[k]) or {}) else out[k] = v end
  end
  if over then for k, v in pairs(over) do if out[k] == nil then out[k] = v elseif type(v) ~= "table" then out[k] = v end end end
  return out
end

-- expose defaults directly
for k, v in pairs(DEFAULT) do Theme[k] = v end

-- BuilderSans face for a Font role weight. Font.fromName is the only API that carries the weight
-- (Font.fromEnum takes ONE argument and would silently drop it); nil where the Font global is
-- absent so Create.text leaves FontFace alone and the label keeps Font = BuilderSans.
-- BuilderSans ships no 600, so a SemiBold request resolves to Bold rather than a missing face.
function Theme.FontFace(weight)
  if not (Font and Font.fromName) then return nil end
  if weight == nil then weight = Enum.FontWeight.Regular end
  if weight == Enum.FontWeight.SemiBold then weight = Enum.FontWeight.Bold end
  return Font.fromName("BuilderSans", weight)
end

function Theme.new(overrides)
  overrides = overrides or {}
  local t = deepMerge(DEFAULT, overrides)
  -- helpers ride on the instance so a component holding only `theme` can call theme.fx(theme) etc.
  t.FontFace = Theme.FontFace
  t.fx = Theme.fx
  t.modeVal = Theme.modeVal
  t.mix = Theme.mix
  t.new = Theme.new
  return t
end

return Theme
