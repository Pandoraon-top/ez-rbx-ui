-- Deps injected via Init(R) (bundler cannot rewrite require() inside embedded modules).
local UserInputService = game:GetService("UserInputService")

local Window = {}
local Create, DefaultTheme, Animate, Maid, Icons, Overlay, Acrylic, Tab, ConfigMod, DialogMod, Notif, Asset, Themer, Mount, Safe, Drag, Device, Recipes, Effects

function Window.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid
  Icons = R.Icons; Overlay = R.Overlay; Acrylic = R.Acrylic; Tab = R.Tab; ConfigMod = R.Config; DialogMod = R.Dialog
  Notif = R.Notification; Asset = R.Asset; Themer = R.Themer
  Mount = R.Mount; Safe = R.Safe; Drag = R.Drag; Device = R.Device; Recipes = R.Recipes; Effects = R.Effects
end

-- Title bar heights, FAB geometry and the indicator pill read theme.Sizes (titleBar/titleBarTall,
-- fab.*, indicator.*) so a window Theme override can retune them; the literals that stay below are
-- layout constants no token names yet (sidebar band, minimum size, viewport fractions).
local SIDEBAR_W = 150
local SIDEBAR_MIN, SIDEBAR_MAX = 110, 260
local MIN_W, MIN_H = 380, 260
local VP_MARGIN = 0.92                  -- never exceed 92% of the viewport on either axis
local DEF_WF, DEF_HF = 0.45, 0.6       -- default window size as a fraction of the viewport (W x H)
local FALLBACK_VP = { X = 1280, Y = 720 }
-- Distance between the Close and Minimize glyph centres (they sit at -18 and -44 from the right
-- edge, both 18px wide). It is also the widest a hit target may be before the two overlap.
local TITLE_BTN_GAP = 26
-- Group header text inset: matches the TabButton's own left padding (tab.lua) so the overline
-- and the tab rows share one left edge. Keep in sync until a Sizes token names it.
local GROUP_HEADER_INSET = 10
-- TextService measuring bound: wide enough that a Tag label never wraps.
local MEASURE_MAX_W = 1e4
-- How much of Window:SetTransparency bleeds into the drop shadow: a frosted shell sits closer to
-- the wall, so its shadow must lighten with it. No token names this ratio yet.
local SHADOW_FOLLOW = 0.5
-- ...and how much of it reaches the content panel: a frosted shell must not contain an opaque
-- slab, but the panel still has to read as a tonal step above the chrome, so it follows at 60%.
local PANEL_FOLLOW = 0.6
-- Recessed panel: the inset shade covers the top INSET_BAND of it and the scroll edge fades are
-- SCROLL_FADE_H px tall. No token names either number yet.
local INSET_BAND = 0.06
local SCROLL_FADE_H = 14
-- Sidebar divider band width behind a pointer (touch uses Sizes.touchHit), and the search
-- field's side padding, shared by its UIPadding and the hover wash that has to cancel it.
local SIDEBAR_HANDLE_W = 12
local SEARCH_PAD = 8
-- Indicator travel: one extra second of spring per IND_TRAVEL_PX px of distance (clamped to
-- Motion.base..Motion.slow), so a jump across the whole sidebar reads slower than a hop.
local IND_TRAVEL_PX = 900
-- Sidebar grip pill alphas: invisible at rest behind a pointer, a hint on hover, solid while
-- dragging, and permanently half-lit on touch where there is no hover to reveal it.
local GRIP_ALPHA = { rest = 1, hover = 0.3, drag = 0, touch = 0.5 }
local function clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end
local FAB_ANCHORS = { TopLeft = true, MidLeft = true, BottomLeft = true, TopRight = true, MidRight = true, BottomRight = true }
-- Map a named anchor + the FAB kind/size to a Position UDim2 (S = theme.Sizes.fab).
-- simple = a docked edge tab (left peeks at -S.peek; right starts near the edge so the on-show
-- magnet settles it); circle/square = fully visible at the anchor with S.margin. Vertical
-- band (Top/Mid/Bottom) is the same for both.
local function fabAnchorPos(name, kind, w, h, S)
  local yScale, yOff
  if name:find("Top") then yScale, yOff = 0, S.margin
  elseif name:find("Mid") then yScale, yOff = 0.5, -h / 2
  else yScale, yOff = 1, -(h + S.margin) end
  local isLeft = name:find("Left") ~= nil
  if kind == "simple" then
    if isLeft then return UDim2.new(0, -S.peek, yScale, yOff) end
    return UDim2.new(1, -(w - S.peek), yScale, yOff)
  end
  if isLeft then return UDim2.new(0, S.margin, yScale, yOff) end
  return UDim2.new(1, -(w + S.margin), yScale, yOff)
end -- headless / no CurrentCamera

-- Tag pill text width. TextService:GetTextSize takes the legacy Enum.Font (no weight), so a
-- Medium face measures narrower than it renders: Sizes.tagMeasureFudge covers the gap.
-- GetTextBoundsAsync would yield on the build thread, so it is never used here. pcall guards
-- an executor without TextService; the fallback is the old per-character estimate.
local function measureTagText(text, size, theme)
  local ok, measured = pcall(function()
    return game:GetService("TextService"):GetTextSize(text, size, Enum.Font.BuilderSans, Vector2.new(MEASURE_MAX_W, size))
  end)
  if ok and measured and type(measured.X) == "number" then
    return math.ceil(measured.X * theme.Sizes.tagMeasureFudge)
  end
  return #text * 7
end

function Window.new(config)
  config = config or {}
  -- merge a partial Theme override onto the defaults (verbatim use would crash on missing tokens)
  local theme = DefaultTheme.new(config.Theme or {})
  -- a Theme = { Motion = {...} } override retunes every Animate token name (process-wide, like enabled)
  Animate.useMotion(theme.Motion)
  if config.Mode == "light" then DefaultTheme.applyMode(theme, "light") else theme.Mode = "dark" end
  -- reduced-motion toggle. Process-wide by design (single-window norm; last writer wins) —
  -- see api:SetAnimationsEnabled. Don't "fix" into per-window state without revisiting the spec.
  -- No config -> the OS preference is only a DEFAULT: applyDefault never overrides an explicit
  -- choice, so a second window without Animations cannot re-enable motion the user switched off.
  if config.Animations ~= nil then Animate.setEnabled(config.Animations ~= false)
  else Animate.applyDefault(not Device.PrefersReducedMotion()) end
  local S = theme.Sizes
  if config.NotificationPosition then Notif.setPosition(config.NotificationPosition) end
  theme.AccentName = "Adaptive"
  local maid = Maid.new()
  -- Ratio = the window size as a fraction of the viewport (per axis):
  --   { Width = 0.4, Height = 0.55 } -> 40% of viewport width x 55% of viewport height
  --   a single number n             -> the same fraction n on both axes
  -- omitted -> the default (DEF_WF x DEF_HF). Values are floored only by MIN_W/MIN_H and
  -- capped at VP_MARGIN of the viewport (see computeSize).
  local function fractionsFromRatio(r)
    local wf, hf
    if type(r) == "table" then
      wf = tonumber(r.Width or r[1]); hf = tonumber(r.Height or r[2])
    elseif type(r) == "number" then
      wf = r; hf = r
    end
    if not (wf and wf > 0) then wf = DEF_WF end
    if not (hf and hf > 0) then hf = DEF_HF end
    return wf, hf
  end
  local widthFrac, heightFrac = fractionsFromRatio(config.Ratio)
  local function viewportSize()
    local cam = workspace and workspace.CurrentCamera
    local vp = cam and cam.ViewportSize
    if vp and vp.X and vp.X > 0 then return vp end
    return FALLBACK_VP
  end
  local function computeSize()
    local vp = viewportSize()
    local w = vp.X * widthFrac
    local h = vp.Y * heightFrac
    local maxW, maxH = vp.X * VP_MARGIN, vp.Y * VP_MARGIN
    if w > maxW then w = maxW end
    if h > maxH then h = maxH end
    w = math.max(w, MIN_W)
    h = math.max(h, MIN_H)
    return math.floor(w), math.floor(h)
  end
  local width, height = computeSize()
  local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
  local tabs = {}
  local selectedIndex = 0  -- index of the active tab; drives the carousel direction on switch
  local visible = true
  local fab, fabScale, fabFullSize, fabSnap, fabMaid, showFab, hideFab, fabFade
  local fabEnabled, autoHide
  local sidebarW = SIDEBAR_W
  local closed = false
  local startHidden = config.StartHidden == true  -- start collapsed to just the FAB; open via the FAB/toggle key
  local userMoved = false  -- set when the user drags/resizes; viewport changes then clamp instead of re-centering
  local dragging = false   -- title-bar drag in flight (read by AdaptToViewport and the fold drift)
  local userResized = false  -- set when the user drags the grip; AdaptToViewport then preserves the manual size
  local closeCallback
  local themer = Themer.new()
  local lockables = {}
  local function registerControl(c) lockables[#lockables + 1] = c end

  -- optional config persistence (controls register their flags against this)
  local cfg = nil
  local cfgOpts = config.Config
  if cfgOpts and cfgOpts.Enabled ~= false and (cfgOpts.FileName or cfgOpts.Enabled) then
    cfg = ConfigMod.new({
      FolderName = cfgOpts.FolderName, FileName = cfgOpts.FileName,
      AutoSave = cfgOpts.AutoSave, AutoLoad = cfgOpts.AutoLoad,
    })
  end

  local mountCtx = config._mountCtx or { parent = config.Parent }
  local gui = Create("ScreenGui", {
    Name = Mount.guiName(config, mountCtx.studio),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior and Enum.ZIndexBehavior.Sibling or nil,
    DisplayOrder = config.DisplayOrder or 1000000,
    Parent = config.Parent,
  })
  Mount.finalize(gui, mountCtx)

  -- AnchorPoint (0.5, 0.5) puts the UIScale pivot in the middle, so every scale animation
  -- (entrance, Show, Hide, Close, SetUIScale) grows from the centre instead of the top-left
  -- corner. Position is therefore the window's CENTRE everywhere below: drag, resize and
  -- AdaptToViewport all do their clamping in centre coordinates.
  local main = Create("Frame", {
    Name = "Main",
    Size = UDim2.new(0, width, 0, height),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BorderSizePixel = 0,
    Parent = gui,
    Create.corner(theme.Radius.window),
  })
  local transp = type(config.Transparency) == "number" and config.Transparency or theme.Acrylic.frost
  -- The shell hairline has ONE source: the acrylic repaint and the fold/grab tweens below both
  -- read Stroke.window, so a re-skin mid-drag cannot disagree with the dissolve.
  local function strokeRest() return theme.Stroke.window end
  -- base = background (the chrome); Acrylic owns the sheen so no card-over-background gradient
  -- multiplies the dark shell to black any more. edge = the rim gradient on the stroke plus the
  -- top glint hairline. Re-painted by Acrylic.reskin in the shell closure.
  Acrylic.decorate(main, theme, { transparency = transp, base = theme.Colors.background,
    edge = true, strokeAlpha = strokeRest() })
  -- held as a local: the fold and grab tweens must not re-find it through the child list
  local mainStroke = main:FindFirstChildOfClass("UIStroke")
  local winScale = Create("UIScale", { Scale = 1, Parent = main })
  local userScale = 1
  -- Drop shadow: a SIBLING of Main under the ScreenGui with a LOWER ZIndex (Main is 1, the
  -- overlay root 1000) -- under ZIndexBehavior.Sibling a child would render above its parent's
  -- fill. It carries its own UIScale so it can follow the window scale about the same centre.
  -- nil until theme.Effect.shadowId is verified in Studio, so every use below tolerates nil.
  local shadow = Effects.shadow(gui, theme, { name = "WindowShadow", level = "window", zIndex = 0 })
  local shadowScale = shadow and Create("UIScale", { Scale = 1, Parent = shadow })
  -- Zero signals: the shadow is re-mirrored explicitly after every write of Main's Position/Size.
  local function syncShadow() Effects.mirror(shadow, main, "window", theme) end
  -- ONE formula for the shadow alpha: the mode's value, darkened while grabbed (Effect.lift) and
  -- lightened by the window's own transparency -- a see-through shell must not cast a solid
  -- shadow. Every writer below (paint, fold, grab) reads it, so they can never disagree.
  local lifted = false  -- a title-bar/grip grab is in flight
  local function shadowAlpha(on)
    local a = theme.fx(theme).shadow + transp * SHADOW_FOLLOW
    if on then a = a + theme.Effect.lift.alphaDelta end
    return clamp(a, 0, 1)
  end
  local function paintShadow()
    if not shadow then return end
    Effects.reskin(shadow, theme, "shadow")        -- kit: per-mode base (and the lift flag)
    shadow.ImageTransparency = shadowAlpha(lifted) -- plus this window's transparency follow
  end
  syncShadow(); paintShadow()
  -- Grab feedback shared by the title-bar drag and the resize grip: the shadow spreads and
  -- darkens while the shell hairline goes opaque; the maid resets it so a Close mid-drag cannot
  -- leave the window lifted. The alpha rides lift's OWN tween (its 4th argument): a separate
  -- tween on the same instance would cancel lift's, and the shadow would keep the alpha but
  -- never finish growing -- it stayed oversized for the rest of the session. lift also records
  -- the lifted state, which is what keeps the spread while a drag re-mirrors every move.
  local function grabbed(on)
    lifted = on and true or false
    if shadow then Effects.lift(shadow, theme, on, shadowAlpha(lifted)) end
    if mainStroke then Animate.to(mainStroke, "fast", { Transparency = on and theme.Stroke.floating or strokeRest() }) end
  end
  maid:Give(function() if lifted then grabbed(false) end end)
  local grip -- resize grip glyph; built after the shell, re-tinted by the shell closure below

  -- A logo source is either a string (one image, optionally ImageAdaptive-tinted) or a
  -- { dark = ..., light = ... } table that swaps per color mode -- for full-color tiles that ship a
  -- baked-in background per mode. `srcFor` picks the variant for the active mode (or the string itself).
  local function srcFor(value, mode)
    if type(value) == "table" then return value[mode] or value.dark or value.light end
    return value
  end

  -- title bar (grows to fit a subtitle and/or image)
  local titleSrc = config.Image
  local imageIsModal = type(titleSrc) == "table"
  -- Adaptive = tint a monochrome glyph (currentColor SVG) to the foreground token so it follows
  -- dark/light. Modal tiles are full-color, so ImageAdaptive is ignored for them (tinting would wreck
  -- the baked-in colors). Both are re-applied on SetMode by the window-shell reskin closure below.
  local imageAdaptive = config.ImageAdaptive == true and not imageIsModal
  local hasTitleImg = Asset.resolvable(srcFor(titleSrc, theme.Mode))
  local hasSubtitle = type(config.Subtitle) == "string" and config.Subtitle ~= ""
  local titleH = (hasTitleImg or hasSubtitle) and S.titleBarTall or S.titleBar
  local titleBar = Create("Frame", {
    Name = "TitleBar",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, titleH),
    Parent = main,
    Create.padding({ left = theme.Spacing.pad, right = theme.Spacing.pad }),
  })
  local titleTextX = 0
  local titleImg
  local applyTitleImage   -- (re)resolves the current-mode variant and writes it; set when the image exists
  if hasTitleImg then
    local imgSize = 36
    titleImg = Create("ImageLabel", {
      -- Glyphs (adaptive) and self-contained tiles (modal) use Fit so the whole mark shows; Crop
      -- (cover) would scale up and clip a padded/centered mark. Plain full-bleed logos keep Crop.
      Name = "TitleImage", BackgroundTransparency = 1,
      ScaleType = (imageAdaptive or imageIsModal) and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
      AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
      Size = UDim2.new(0, imgSize, 0, imgSize), Image = "", Parent = titleBar,
      Create.corner(theme.Radius.md),
    })
    if imageAdaptive then titleImg.ImageColor3 = theme.Colors.foreground
    elseif imageIsModal then titleImg.ImageColor3 = Color3.fromRGB(255, 255, 255) end -- render the tile's own colors
    -- Fill it (and re-fill on mode change) with the active variant. URLs download off the construction
    -- thread, so the window never blocks on game:HttpGet; the write is marshalled to a capability ctx.
    applyTitleImage = function()
      Asset.imageAsync(srcFor(titleSrc, theme.Mode), function(id)
        Safe.mutate(function() if titleImg.Parent then titleImg.Image = id end end)
      end)
    end
    applyTitleImage()
    titleTextX = imgSize + 8
  end
  local titleLabel = Create("TextLabel", {
    Name = "Title",
    BackgroundTransparency = 1,
    Text = config.Title or "EzUI",
    TextColor3 = theme.Colors.foreground,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = hasSubtitle and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.new(0, titleTextX, 0, 0),
    Size = hasSubtitle and UDim2.new(1, -(titleTextX + 60), 0.5, 0) or UDim2.new(1, -(titleTextX + 60), 1, 0),
    Parent = titleBar,
  })
  Create.text(titleLabel, theme, "title")
  if hasSubtitle then
    local subtitle = Create("TextLabel", {
      Name = "Subtitle",
      BackgroundTransparency = 1,
      Text = config.Subtitle,
      TextColor3 = theme.Colors.mutedForeground,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Top,
      TextTruncate = Enum.TextTruncate.AtEnd,
      Position = UDim2.new(0, titleTextX, 0.5, 0),
      Size = UDim2.new(1, -(titleTextX + 60), 0.5, 0),
      Parent = titleBar,
    })
    Create.text(subtitle, theme, "muted")
  end
  -- The 18px glyphs stay the glyphs; Recipes.iconButton hangs a transparent Sizes.iconButton
  -- sibling (touchHit on touch) over each one so a finger has somewhere to land, and binds the
  -- hover tint AND the click to BOTH -- so every existing caller that fires on the button itself
  -- still works. The click bodies need `api`, which does not exist yet, hence the forward
  -- declarations; they are assigned once the window API is built.
  local onClosePressed, onMinimizePressed
  local closeBtn = Create("ImageButton", {
    Name = "Close",
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 18, 0, 18),
    Position = UDim2.new(1, -18, 0.5, -9),
    Parent = titleBar,
  })
  local minBtn = Create("ImageButton", {
    Name = "Minimize", AutoButtonColor = false, BackgroundTransparency = 1,
    Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -44, 0.5, -9), Parent = titleBar,
  })
  -- The two glyph centres sit TITLE_BTN_GAP apart, so a finger-sized 44px hit on each would
  -- overlap by 18px -- and MinimizeHit, created second, wins that overlap: tapping the left edge
  -- of the X minimised instead of closing. Two controls this close cannot both carry 44px, so the
  -- targets tile exactly edge to edge instead, and CloseHit still outranks its neighbour in case
  -- the spacing ever changes.
  local hitSize = math.min(theme.Sizes.touchHit, TITLE_BTN_GAP)
  local closeIcon = Recipes.iconButton(closeBtn, { theme = theme, icon = "x", rest = theme.Icon.structural,
    hover = "destructive", hitSize = hitSize,
    onClick = function() if onClosePressed then onClosePressed() end end })
  local minIcon = Recipes.iconButton(minBtn, { theme = theme, icon = "minus", rest = theme.Icon.structural,
    hover = theme.Icon.accent, hitSize = hitSize,
    onClick = function() if onMinimizePressed then onMinimizePressed() end end })
  closeIcon.Hit.ZIndex = minIcon.Hit.ZIndex + 1
  maid:Give(closeIcon.disconnect); maid:Give(minIcon.disconnect)

  -- body: sidebar + content
  local body = Create("Frame", {
    Name = "Body",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, titleH),
    Size = UDim2.new(1, 0, 1, -titleH),
    Parent = main,
  })
  -- sidebar search box (pinned above the tab list)
  -- Stroke.search is per-mode (light needs a firmer hairline over the 240 chrome); the same
  -- stroke doubles as the focus ring (Recipes.focus below), so its colour has ONE source.
  local searchBox = Create("Frame", {
    Name = "Search", BackgroundColor3 = theme.Colors.input, BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(0, sidebarW - 16, 0, 24), Parent = body,
    Create.corner(theme.Radius.sm), Create.padding({ left = SEARCH_PAD, right = SEARCH_PAD }),
  })
  local searchStroke = Create.stroke(theme.Colors.border, 1, theme.modeVal(theme, theme.Stroke.search))
  searchStroke.Parent = searchBox
  local searchInput = Create("TextBox", {
    Name = "SearchInput", BackgroundTransparency = 1, Text = "", PlaceholderText = "Search…",
    PlaceholderColor3 = theme.Colors.mutedForeground, TextColor3 = theme.Colors.foreground,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false, Size = UDim2.new(1, 0, 1, 0), Parent = searchBox,
  })
  Create.text(searchInput, theme, "muted")
  local searchFocused = false
  local function searchStrokeColor() return searchFocused and theme.Colors.ring or theme.Colors.border end
  -- the recipe owns Thickness (1 <-> Stroke.focusThickness); the flag is recorded in the colour
  -- callback so the shell closure re-derives the same colour after SetMode
  local function searchRestAlpha() return theme.modeVal(theme, theme.Stroke.search) end
  local searchFocus = Recipes.focus(searchStroke, searchInput, function(focused)
    searchFocused = focused
    return searchStrokeColor()
  end, { theme = theme, restAlpha = searchRestAlpha })
  maid:Give(searchFocus.disconnect)
  -- Hover wash on the field itself (2.7): the negative inset cancels its UIPadding so the wash
  -- covers the whole box instead of only the text area.
  local searchHover = Recipes.hover(searchBox, { theme = theme, corner = theme.Radius.sm,
    inset = { x = SEARCH_PAD, y = 0 } })
  maid:Give(searchHover.disconnect)

  local sidebar = Create("ScrollingFrame", {
    Name = "Sidebar",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = theme.Colors.border,
    Position = UDim2.new(0, 0, 0, 36),
    Size = UDim2.new(0, sidebarW, 1, -36),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = body,
    Create.listLayout({ Padding = 4 }),
    Create.padding({ all = 8 }),
  })
  local cgap = theme.Spacing.gap
  -- A frosted shell must not hold an opaque slab: the panel -- and its edge fades, which are the
  -- same card colour -- carry PANEL_FOLLOW of the window's own transparency.
  local function panelAlpha() return clamp(transp * PANEL_FOLLOW, 0, 1) end
  local contentPanel = Create("Frame", {
    Name = "ContentPanel", BackgroundColor3 = theme.Colors.card, BackgroundTransparency = panelAlpha(),
    BorderSizePixel = 0,
    Position = UDim2.new(0, sidebarW + cgap, 0, cgap),
    Size = UDim2.new(1, -(sidebarW + cgap * 2), 1, -cgap * 2),
    Parent = body, ClipsDescendants = true, Create.corner(theme.Radius.lg),
  })
  -- Stroke.panel: faint in dark, opaque in light where card 255 over chrome 240 needs an edge
  local contentStroke = Create.stroke(theme.Colors.border, 1, theme.modeVal(theme, theme.Stroke.panel))
  contentStroke.Parent = contentPanel
  -- Recessed: a UIGradient on the panel multiplies ITS OWN fill only, so a short shade across the
  -- top INSET_BAND reads as the card being chiselled into the chrome rather than stuck on top of
  -- it. White below the band is the identity multiplier.
  local WHITE = Color3.new(1, 1, 1)
  local function insetStops() return { { 0, theme.fx(theme).inset }, { INSET_BAND, WHITE }, { 1, WHITE } } end
  local function colorSeq(stops)
    local kps = {}
    for i, st in ipairs(stops) do kps[i] = ColorSequenceKeypoint.new(st[1], st[2]) end
    return ColorSequence.new(kps)
  end
  local insetShade = Create.gradient({ rotation = 90, stops = insetStops() })
  insetShade.Name = "PanelInset"; insetShade.Parent = contentPanel
  local contentScroll = Create("ScrollingFrame", {
    Name = "Content",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.Colors.border,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.None,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ClipsDescendants = true,
    Parent = contentPanel,
  })
  -- Scroll edge fades: card-coloured slabs pinned to the PANEL, never to the scrolling Content
  -- (whose CanvasSize maths and MountRow order must not move), each dissolving away from its own
  -- edge. ZIndex 2 puts them over the rows (Sibling behaviour); Active false keeps them out of
  -- the input path; Scale sizing means applySidebarWidth never has to touch them.
  local function makeFade(name, anchorY, stops)
    return Create("Frame", {
      Name = name, BackgroundColor3 = theme.Colors.card, BackgroundTransparency = panelAlpha(),
      BorderSizePixel = 0, AnchorPoint = Vector2.new(0, anchorY),
      Position = UDim2.new(0, 0, anchorY, 0), Size = UDim2.new(1, 0, 0, SCROLL_FADE_H),
      ZIndex = 2, Active = false, Visible = false, Parent = contentPanel,
      Create.shade({ rotation = 90, stops = stops }),
    })
  end
  local fadeTop = makeFade("ScrollFadeTop", 0, { { 0, 0 }, { 1, 1 } })
  local fadeBottom = makeFade("ScrollFadeBottom", 1, { { 0, 1 }, { 1, 0 } })
  -- Visible is TOGGLED, never tweened: touch scrolling fires these signals hundreds of times a
  -- second and two tweens per event is not a budget. Unmeasured (any of the three nil, as
  -- headless) hides BOTH rather than flashing one on, and a write only happens on a real change.
  local function updateFades()
    local cp, cs, aws = contentScroll.CanvasPosition, contentScroll.CanvasSize, contentScroll.AbsoluteWindowSize
    local top, bottom = false, false
    if cp and cs and aws then
      local y = cp.Y or 0
      top = y > 0
      bottom = y + (aws.Y or 0) < (cs.Y and cs.Y.Offset or 0)
    end
    if fadeTop.Visible ~= top then fadeTop.Visible = top end
    if fadeBottom.Visible ~= bottom then fadeBottom.Visible = bottom end
  end
  -- property signals fire on engine threads (no GUI capability on strict executors) -> marshal
  for _, prop in ipairs({ "CanvasPosition", "CanvasSize", "AbsoluteWindowSize" }) do
    maid:Give(contentScroll:GetPropertyChangedSignal(prop):Connect(function() Safe.mutate(updateFades) end))
  end
  updateFades()
  -- ONE painter for the recessed stack, so the shell closure and SetTransparency cannot disagree.
  local function paintPanel()
    local a = panelAlpha()
    contentPanel.BackgroundColor3 = theme.Colors.card
    contentPanel.BackgroundTransparency = a
    contentStroke.Color = theme.Colors.border
    contentStroke.Transparency = theme.modeVal(theme, theme.Stroke.panel)
    insetShade.Color = colorSeq(insetStops())
    fadeTop.BackgroundColor3 = theme.Colors.card; fadeTop.BackgroundTransparency = a
    fadeBottom.BackgroundColor3 = theme.Colors.card; fadeBottom.BackgroundTransparency = a
  end

  -- Draggable sidebar↔content divider. The band now STRADDLES the divider (x = the divider
  -- centre minus half the band) instead of hanging off its right edge, so a finger-sized target
  -- no longer covers the first row of the content panel -- and the grip pill inside it is not
  -- visibly off-centre. The drag maths subtracts the same half-gap, so the divider still tracks
  -- the pointer 1:1.
  local hitW = Device.IsTouch() and S.touchHit or SIDEBAR_HANDLE_W
  local function handleX(wpx) return wpx + cgap / 2 - hitW / 2 end
  local sidebarHandle = Create("ImageButton", {
    Name = "SidebarHandle", AutoButtonColor = false, BackgroundTransparency = 1,
    ZIndex = 6, Size = UDim2.new(0, hitW, 1, 0), Position = UDim2.new(0, handleX(sidebarW), 0, 0), Parent = body,
  })
  -- The divider finally reads as one: a Sizes.grip pill centred in the band, invisible until a
  -- pointer finds it, solid while dragging, and permanently half-lit on touch (no hover there).
  local sidebarGrip = Create("Frame", {
    Name = "SidebarGrip", BackgroundColor3 = theme.Colors.border, BorderSizePixel = 0,
    BackgroundTransparency = Device.IsTouch() and GRIP_ALPHA.touch or GRIP_ALPHA.rest,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, S.grip.w, 0, S.grip.h), Active = false, Parent = sidebarHandle,
    Create.corner(theme.Radius.xs),
  })
  local function applySidebarWidth(wpx)
    sidebarW = math.max(SIDEBAR_MIN, math.min(SIDEBAR_MAX, wpx))
    sidebar.Size = UDim2.new(0, sidebarW, 1, -36)
    searchBox.Size = UDim2.new(0, sidebarW - 16, 0, 24)
    contentPanel.Position = UDim2.new(0, sidebarW + cgap, 0, cgap)
    contentPanel.Size = UDim2.new(1, -(sidebarW + cgap * 2), 1, -cgap * 2)
    sidebarHandle.Position = UDim2.new(0, handleX(sidebarW), 0, 0)
  end
  local sbDrag, sbHover = false, false
  local function paintGrip()
    local a = Device.IsTouch() and GRIP_ALPHA.touch or GRIP_ALPHA.rest
    if sbDrag then a = GRIP_ALPHA.drag elseif sbHover then a = GRIP_ALPHA.hover end
    Animate.to(sidebarGrip, "hover", { BackgroundTransparency = a })
  end
  if Device.SupportsHover() then
    maid:Give(sidebarHandle.MouseEnter:Connect(function() sbHover = true; paintGrip() end))
    maid:Give(sidebarHandle.MouseLeave:Connect(function() sbHover = false; paintGrip() end))
  end
  Drag.bind(sidebarHandle, {
    onBegin = function() sbDrag = true; paintGrip(); Overlay.closeAll() end,
    onChange = function(_, _, pos)
      local bp = body.AbsolutePosition
      applySidebarWidth(pos.X - (bp and bp.X or 0) - cgap / 2)
    end,
    onEnd = function() sbDrag = false; paintGrip() end,
  }, maid)

  -- single active-tab indicator that slides between sidebar buttons (lives in Body so the
  -- sidebar's UIListLayout does not lay it out; Body positions its children manually).
  local IND = S.indicator
  -- AnchorPoint (0, 0.5): Position IS the selected button's centre, so the pill stretches
  -- symmetrically about it and the travel has ONE goal instead of a position/size pair to keep
  -- in step.
  local activeIndicator = Create("Frame", {
    Name = "ActiveIndicator", BackgroundColor3 = theme.Colors.primary, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Size = UDim2.new(0, IND.w, 0, IND.h), Position = UDim2.new(0, 2, 0, 0), Visible = false, ZIndex = 5,
    Parent = body, Create.corner(IND.radius),
  })
  -- Accent halo: a CHILD of the pill, so it travels and re-centres with it for free -- no second
  -- tween, no second position to keep in sync. (A child renders above its parent's fill under
  -- ZIndexBehavior.Sibling; at haloAlpha that is a bloom around the bar, not a wash over it.)
  local halo = Create("Frame", {
    Name = "Halo", BackgroundColor3 = theme.Colors.primary, BackgroundTransparency = IND.haloAlpha,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, IND.haloW, 0, IND.haloH), Active = false, Parent = activeIndicator,
    Create.corner(theme.Radius.sm),
  })
  local activeTabButton
  -- `indShown` tracks the FADE, not the raw Visible: going away lands Visible=false in the
  -- tween's completion, while a reappear has to write Visible and the alpha SYNCHRONOUSLY
  -- (callers read Visible immediately) before any tween starts.
  local indShown = false
  local function showIndicator(on)
    if on == indShown then return end
    indShown = on
    if on then
      activeIndicator.Visible = true
      activeIndicator.BackgroundTransparency = 0
      halo.BackgroundTransparency = IND.haloAlpha
      return
    end
    -- fade, never blink: the halo leaves on the same curve so nothing is left glowing behind it
    Animate.to(halo, "fast", { BackgroundTransparency = 1 })
    Animate.toThen(activeIndicator, "fast", { BackgroundTransparency = 1 }, function()
      if not indShown then activeIndicator.Visible = false end
    end)
  end
  local function moveIndicatorTo(btn, instant)
    activeTabButton = btn
    if not btn or btn.Visible == false then showIndicator(false); return end
    local bp, sp = btn.AbsolutePosition, body.AbsolutePosition
    local by = (bp and sp and (bp.Y - sp.Y)) or 0
    local bh = (btn.AbsoluteSize and btn.AbsoluteSize.Y) or 34
    -- Clip to the sidebar's visible vertical band (body-relative): fade out when the selected
    -- button is scrolled out of view so the indicator never drifts over the search box or
    -- off the window edge.
    local sTop = (sidebar.AbsolutePosition and sp and (sidebar.AbsolutePosition.Y - sp.Y)) or 0
    local sBot = sTop + ((sidebar.AbsoluteSize and sidebar.AbsoluteSize.Y) or 0)
    local center = by + bh / 2
    if sBot > sTop and (center < sTop or center > sBot) then showIndicator(false); return end
    local travelled = indShown   -- a pill that was hidden has no meaningful "from" to spring out of
    showIndicator(true)
    local target = UDim2.new(0, 2, 0, center)
    if instant or not travelled then activeIndicator.Position = target; return end
    -- A living pill: stretch as it leaves, spring across with a distance-aware duration, then
    -- settle back to its rest height through the engine-side `delay` argument of Animate.to.
    local dur = clamp(theme.Motion.base + math.abs(center - activeIndicator.Position.Y.Offset) / IND_TRAVEL_PX,
      theme.Motion.base, theme.Motion.slow)
    Animate.chain({
      { activeIndicator, "fast", { Size = UDim2.new(0, IND.w, 0, IND.stretch) }, Animate.EASING.smooth },
      { activeIndicator, dur, { Position = target }, Animate.EASING.pop },
    })
    Animate.to(activeIndicator, "release", { Size = UDim2.new(0, IND.w, 0, IND.h) }, nil, nil, theme.Motion.fast)
  end
  -- Keep the window-owned indicator glued to the selected button: its Y is a body-relative
  -- offset from the button's AbsolutePosition, so recompute it (instantly, no spring) whenever
  -- the button moves on screen -- sidebar scroll (CanvasPosition), sidebar/body resize
  -- (AbsoluteSize), or a list reflow (AbsoluteContentSize). Without these it desyncs on scroll
  -- or resize and can drift right out of the window.
  -- Driven by property-changed signals (engine thread, no GUI capability on strict executors), so
  -- moveIndicatorTo's protected reads/writes must be marshalled (inline when capable).
  local function reanchorIndicator() if activeTabButton then Safe.mutate(function() moveIndicatorTo(activeTabButton, true) end) end end
  maid:Give(sidebar:GetPropertyChangedSignal("CanvasPosition"):Connect(reanchorIndicator))
  maid:Give(sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(reanchorIndicator))
  maid:Give(body:GetPropertyChangedSignal("AbsoluteSize"):Connect(reanchorIndicator))
  do
    local sbLayout = sidebar:FindFirstChildOfClass("UIListLayout")
    if sbLayout then maid:Give(sbLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(reanchorIndicator)) end
  end

  Overlay.get(gui)

  local api = { Gui = gui, Main = main, ContentScroll = contentScroll, Overlay = Overlay.get(gui), Config = cfg, Maid = maid }

  local tabEntries = {}
  local groups = {}
  local searchIndex = {} -- { entry = tabEntry, frame = controlFrame, text = lowercased }
  local sidebarOrder = 0
  local function nextSidebarOrder() sidebarOrder = sidebarOrder + 1; return sidebarOrder end

  local function addTab(tabOpts)
    tabOpts = tabOpts or {}
    local entry = { name = tabOpts.Name or "Tab" }
    tabOpts.SidebarParent = sidebar
    tabOpts.ContentParent = contentScroll
    tabOpts.Theme = theme
    tabOpts.Config = cfg
    tabOpts.Window = api
    tabOpts.AccentThemer = themer
    tabOpts.RegisterControl = registerControl
    -- controls register their searchable text here (full-text search across components)
    tabOpts.RegisterSearchable = function(frame, text)
      searchIndex[#searchIndex + 1] = { entry = entry, frame = frame, text = (text or ""):lower() }
    end
    tabOpts.OnActivate = function(selectedTab)
      Overlay.closeAll()
      local newIndex = selectedIndex
      for i, t in ipairs(tabs) do if t == selectedTab then newIndex = i break end end
      -- carousel direction: +1 going to a lower/later tab, -1 going to a higher/earlier one
      local dir = (selectedIndex == 0 or newIndex >= selectedIndex) and 1 or -1
      selectedIndex = newIndex
      for _, t in ipairs(tabs) do
        if t == selectedTab then t:Select(dir) else t:Deselect(dir) end
      end
      moveIndicatorTo(selectedTab.Button)
    end
    local tab = Tab.new(tabOpts)
    entry.tab = tab
    entry.button = tab.Button
    tabs[#tabs + 1] = tab
    tabEntries[#tabEntries + 1] = entry
    if #tabs == 1 then tab:Select(1); selectedIndex = 1; moveIndicatorTo(tab.Button) end
    return tab
  end

  function api:AddTab(o)
    if closed then return end
    o = o or {}
    o.LayoutOrder = nextSidebarOrder()
    return addTab(o)
  end

  function api:AddTabGroup(name)
    -- Overline row one Spacing.major tall with the text sat at the bottom: the empty top half is
    -- the breathing room between the previous group and this header.
    local header = Create("TextLabel", {
      Name = "GroupHeader", BackgroundTransparency = 1, Text = string.upper(name or "Group"),
      TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Bottom, Size = UDim2.new(1, 0, 0, theme.Spacing.major),
      LayoutOrder = nextSidebarOrder(), Parent = sidebar, Create.padding({ left = GROUP_HEADER_INSET }),
    })
    Create.text(header, theme, "overline")
    local group = { _header = header, _entries = {} }
    groups[#groups + 1] = group
    function group:AddTab(o)
      o = o or {}
      o.LayoutOrder = nextSidebarOrder()
      local tab = addTab(o)
      self._entries[#self._entries + 1] = tabEntries[#tabEntries]
      return tab
    end
    return group
  end

  function api:SearchTabs(query)
    query = (query or ""):lower()
    -- 1) component-level (full text): show only matching control rows
    for _, s in ipairs(searchIndex) do
      s.frame.Visible = (query == "" or (s.text ~= "" and s.text:find(query, 1, true) ~= nil))
    end
    -- 2) tab buttons: visible if the tab name matches OR any of its components match
    for _, e in ipairs(tabEntries) do
      local match = (query == "" or e.name:lower():find(query, 1, true) ~= nil)
      if not match then
        for _, s in ipairs(searchIndex) do
          if s.entry == e and s.frame.Visible then match = true break end
        end
      end
      e.button.Visible = match
    end
    -- 3) group headers: visible if any grouped tab is visible
    for _, g in ipairs(groups) do
      local anyVisible = false
      for _, e in ipairs(g._entries) do if e.button.Visible then anyVisible = true break end end
      g._header.Visible = anyVisible
    end
    if activeTabButton then moveIndicatorTo(activeTabButton) end
  end

  maid:Give(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
    -- Text-changed fires on an engine thread; SearchTabs toggles many .Visible (protected) -> marshal.
    Safe.mutate(function() api:SearchTabs(searchInput.Text) end)
  end))

  function api:IsVisible() return visible end

  -- Fold direction: toward the floating button, so hiding reads as the window turning INTO it.
  -- No FAB (or one sitting under the window centre) -> straight down. Everything is computed in
  -- viewport px from the UDim2s, so it works headless where Absolute* is nil.
  local function driftGoal(from)
    local d, vp = theme.Motion.hideDrift, viewportSize()
    local dx, dy = 0, d
    if fab and fab.Position and fab.Size then
      local fp, fs = fab.Position, fab.Size
      local vx = fp.X.Scale * vp.X + fp.X.Offset + fs.X.Offset / 2 - (from.X.Scale * vp.X + from.X.Offset)
      local vy = fp.Y.Scale * vp.Y + fp.Y.Offset + fs.Y.Offset / 2 - (from.Y.Scale * vp.Y + from.Y.Offset)
      local len = math.sqrt(vx * vx + vy * vy)
      if len > 1 then dx, dy = d * vx / len, d * vy / len end
    end
    return UDim2.new(from.X.Scale, from.X.Offset + dx, from.Y.Scale, from.Y.Offset + dy)
  end

  -- Show, Hide, the entrance and Close are one gesture at different speeds, so ONE local drives
  -- every layer together: the window scale, its background, the shell hairline and the drop
  -- shadow (which carries its own UIScale, pivoting about the same centre).
  --   on    true = unfold (grow to rest), false = fold (shrink to Motion.exitScale)
  --   dur   a Motion token name
  --   opts  style/dir (default Back/Out unfolding, Quart/In folding), bg (a BackgroundTransparency
  --         goal), drift (a Position goal tweened in parallel, shadow included), onDone
  local hideGen = 0  -- bumped by every Show/Hide/Close: a stale fold must not hide a live window
  local function materialise(on, dur, opts)
    opts = opts or {}
    local style = opts.style or (on and Animate.EASING.pop or Animate.EASING.exit)
    local dir = opts.dir or (on and Animate.DIR.Out or Animate.DIR.In)
    local goal = on and userScale or userScale * theme.Motion.exitScale
    -- the hairline and the shadow lead the fold out and trail the unfold back in
    local fade = on and "base" or "fast"
    if mainStroke then Animate.to(mainStroke, fade, { Transparency = on and strokeRest() or 1 }) end
    if shadow then Animate.to(shadow, fade, { ImageTransparency = on and shadowAlpha(lifted) or 1 }) end
    -- Quart, never the scale's Back: an overshoot on a transparency leaves the 0..1 range
    if opts.bg ~= nil then Animate.to(main, dur, { BackgroundTransparency = opts.bg }, Animate.EASING.exit, dir) end
    if opts.drift then
      Animate.to(main, dur, { Position = opts.drift }, style, dir)
      if shadow then -- mirror geometry = the same Position one offsetY lower
        local g, off = opts.drift, theme.Effect.window.offsetY
        Animate.to(shadow, dur, { Position = UDim2.new(g.X.Scale, g.X.Offset, g.Y.Scale, g.Y.Offset + off) }, style, dir)
      end
    end
    if shadowScale then Animate.to(shadowScale, dur, { Scale = goal }, style, dir) end
    -- last: under the synchronous test mock every tween above has landed before onDone runs
    Animate.toThen(winScale, dur, { Scale = goal }, opts.onDone, style, dir)
  end

  function api:Show()
    if closed then return end
    visible = true
    hideGen = hideGen + 1
    local gen = hideGen
    Safe.mutate(function()
      if gen ~= hideGen then return end  -- superseded while we waited for a capability context
      main.Visible = true
      winScale.Scale = userScale * theme.Motion.exitScale
      if shadowScale then shadowScale.Scale = winScale.Scale end
      syncShadow()
      materialise(true, "release", { bg = transp })
    end)
    if autoHide and hideFab then hideFab() end
  end
  function api:Hide()
    if closed then return end
    visible = false
    hideGen = hideGen + 1
    local gen = hideGen
    Safe.mutate(function()
      if gen ~= hideGen then return end
      local restPos = main.Position
      -- never drift while the title bar is being dragged: that gesture owns Position
      local drift = (not dragging) and driftGoal(restPos) or nil
      materialise(false, "exit", {
        drift = drift,
        onDone = function()
          -- the drift is transient: put the window back, but only if nothing else moved it in
          -- the meantime (a drag started mid-fold would already own Position)
          if drift and main.Position == drift then main.Position = restPos; syncShadow() end
          if gen ~= hideGen then return end  -- a Show raced the fold: it owns Visible now
          main.Visible = false
          winScale.Scale = userScale
          if shadowScale then shadowScale.Scale = userScale end
          if showFab then showFab() end  -- the pop-in belongs to the fold's completion
        end,
      })
    end)
  end
  function api:Toggle() if closed then return end; if visible then api:Hide() else api:Show() end end
  function api:SetTitle(s) Safe.mutate(function() titleLabel.Text = s end) end
  function api:SetSubtitle(s)
    Safe.mutate(function()
      local sub = titleBar:FindFirstChild("Subtitle")
      if sub then sub.Text = s end
    end)
  end
  function api:SetImage(v)
    -- v is a string or a { dark, light } table; keep the source so SetMode can keep swapping variants.
    titleSrc = v
    imageIsModal = type(v) == "table"
    imageAdaptive = config.ImageAdaptive == true and not imageIsModal
    Safe.mutate(function()
      local img = titleImg or titleBar:FindFirstChild("TitleImage")
      if img then
        img.ScaleType = (imageAdaptive or imageIsModal) and Enum.ScaleType.Fit or Enum.ScaleType.Crop
        img.ImageColor3 = imageAdaptive and theme.Colors.foreground or Color3.fromRGB(255, 255, 255)
      end
    end)
    if applyTitleImage then applyTitleImage() return end
    Asset.imageAsync(srcFor(v, theme.Mode), function(id)
      Safe.mutate(function()
        local img = titleBar:FindFirstChild("TitleImage")
        if img then img.Image = id end
      end)
    end)
  end
  -- Overlays that outlive a SetMode/SetAccent (toasts, dialogs) register a temporary closure
  -- through opts.AccentReg and unregister it on dismiss/close (cross-component contract).
  local function accentReg(fn) return themer.register(fn) end
  function api:Dialog(o) o = o or {}; o.Theme = theme; o.Window = api; o.AccentReg = accentReg; return DialogMod.open(o) end
  function api:Notify(o) o = o or {}; o.Theme = theme; o.AccentReg = accentReg; return Notif.show(o) end
  function api:SetNotificationsEnabled(b) Notif.setEnabled(b); return b end
  -- reskin (not a bare write) so the acrylic sheen band rescales with the new transparency
  function api:SetTransparency(n)
    transp = n
    Safe.mutate(function()
      Acrylic.reskin(main, theme, { base = theme.Colors.background, transparency = n })
      paintShadow()   -- a see-through shell casts a lighter shadow...
      paintPanel()    -- ...and holds no opaque slab: PANEL_FOLLOW of it reaches the content panel
    end)
    return n
  end
  function api:SetAnimationsEnabled(b) Animate.setEnabled(b and true or false); return b end
  function api:SetToggleKey(k) toggleKey = k; return k end
  function api:SetUIScale(n)
    userScale = n
    Safe.mutate(function()
      winScale.Scale = n
      if shadowScale then shadowScale.Scale = n end
      -- Overlay-hosted surfaces (toasts, tips, dropdowns, standalone dialogs) are NOT children of
      -- Main, so they scale themselves from these process-wide numbers when they build. Never a
      -- UIScale on the overlay root: its (1,0,1,0) click catcher would stop covering the screen.
      -- Guarded so a junk argument cannot start throwing where it only used to render oddly.
      if type(n) == "number" and n == n and n > 0 then
        Overlay.setScale(n)
        if Notif.setScale then Notif.setScale(n) end   -- toast container scale (cross-group contract)
      end
      syncShadow()   -- last: mirror the geometry everything else just settled on
    end)
    return n
  end
  function api:ShowSuccess(o) o = o or {}; o.Type = "success"; return api:Notify(o) end
  function api:ShowWarning(o) o = o or {}; o.Type = "warning"; return api:Notify(o) end
  function api:ShowError(o) o = o or {}; o.Type = "error"; return api:Notify(o) end
  function api:ShowInfo(o) o = o or {}; o.Type = "info"; return api:Notify(o) end
  function api:ShowLoading(o) o = o or {}; o.Theme = theme; o.AccentReg = accentReg; return Notif.loading(o) end
  function api:Promise(fn, o) o = o or {}; o.Theme = theme; o.AccentReg = accentReg; return Notif.promise(fn, o) end
  function api:SetNotificationPosition(p) return Notif.setPosition(p) end
  function api:DismissNotification(id) Notif.dismiss(id) end
  function api:ClearNotifications() Notif.clearAll() end

  function api:ResetFlag(flag) if cfg then cfg:ResetFlag(flag) end end
  function api:ConfigProfiles() return cfg and cfg:ListProfiles() or { "Default" } end
  function api:UseConfigProfile(name) if cfg then cfg:SwitchProfile(name) end end
  function api:SaveConfiguration() return cfg and cfg:Save() or false end
  function api:LoadConfiguration() return cfg and cfg:Load() or false end

  function api:ResetConfiguration(o)
    o = o or {}
    if not cfg then return end
    local function doReset()
      cfg:Reset({ ClearFile = o.ClearFile })
      api:ShowSuccess({ Title = "Reset", Message = "Settings restored to defaults." })
    end
    if o.Confirm == false then
      doReset()
    else
      api:Dialog({ Title = "Reset settings?", Message = "This restores all options to their defaults.", Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Reset", Variant = "destructive", Callback = doReset },
      } })
    end
  end

  function api:GetThemer() return themer end
  function api:LockAll() for _, c in ipairs(lockables) do if c.SetLocked then c.SetLocked(true) end end end
  function api:UnlockAll() for _, c in ipairs(lockables) do if c.SetLocked then c.SetLocked(false) end end end

  local tagX = 70 -- offset from the right, left of the min/close buttons
  function api:Tag(o)
    o = o or {}
    local hasIcon = o.Icon ~= nil
    local width = (hasIcon and 22 or 8) + measureTagText(tostring(o.Text or ""), theme.Font.muted.Size, theme) + 8
    local pill = Create("Frame", { Name = "Tag", BackgroundColor3 = o.Color or theme.Colors.surface, BorderSizePixel = 0,
      AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -tagX, 0.5, 0), Size = UDim2.new(0, width, 0, 20),
      Parent = titleBar, Create.corner(theme.Radius.sm), Create.padding({ left = 6, right = 6 }) })
    Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = pill })
    if hasIcon then
      local ic = Create("ImageLabel", { Name = "TagIcon", BackgroundTransparency = 1, Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 0, 0.5, -6), Parent = pill })
      Icons.apply(ic, o.Icon, theme.Colors.primary)
    end
    local txt = Create("TextLabel", { Name = "TagText", BackgroundTransparency = 1, Text = o.Text or "",
      TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
      Size = UDim2.new(1, hasIcon and -16 or 0, 1, 0),
      Position = UDim2.new(0, hasIcon and 16 or 0, 0, 0), Parent = pill })
    Create.text(txt, theme, "muted")
    tagX = tagX + width + 8
    local unreg = themer.register(function()
      pill.BackgroundColor3 = o.Color or theme.Colors.surface
      local st = pill:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
      txt.TextColor3 = theme.Colors.foreground
      local ic = pill:FindFirstChild("TagIcon"); if ic then Icons.apply(ic, o.Icon, theme.Colors.primary) end
    end)
    return { SetText = function(s) Safe.mutate(function() txt.Text = s end) end, Destroy = function() unreg(); pill:Destroy() end }
  end
  local function fgForColor(c)
    local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
    return (lum > 0.55) and Color3.fromRGB(24, 24, 27) or Color3.fromRGB(250, 250, 250)
  end
  function api:SetAccent(nameOrColor)
    if type(nameOrColor) ~= "string" then -- a Color3 (typeof is unreliable under the mock)
      theme.AccentName = "Custom"
      theme.Colors.primary = nameOrColor
      theme.Colors.primaryForeground = fgForColor(nameOrColor)
    elseif nameOrColor == "Adaptive" then
      theme.AccentName = "Adaptive"
      local p = DefaultTheme.PALETTES[theme.Mode] or DefaultTheme.PALETTES.dark
      theme.Colors.primary = p.primary
      theme.Colors.primaryForeground = p.primaryForeground
    else
      local a = Themer.accent(nameOrColor)
      if not a then return end
      theme.AccentName = nameOrColor
      theme.Colors.primary = a.Primary
      theme.Colors.primaryForeground = a.Foreground
    end
    Safe.mutate(function() themer.reskin("accent") end)
  end
  function api:GetMode() return theme.Mode end
  function api:SetMode(mode)
    DefaultTheme.applyMode(theme, mode)
    if theme.AccentName == "Adaptive" then
      local p = DefaultTheme.PALETTES[mode] or DefaultTheme.PALETTES.dark
      theme.Colors.primary = p.primary
      theme.Colors.primaryForeground = p.primaryForeground
    end
    Safe.mutate(function() themer.reskin("mode") end)
  end

  -- window-shell live re-skin. `reason` is 'mode' | 'accent' (nil from legacy callers): only a
  -- mode switch swaps the { dark, light } title tile, so an accent change skips the re-download.
  themer.register(function(reason)
    Acrylic.reskin(main, theme, { base = theme.Colors.background, edge = true })  -- fill, sheen, stroke, rim, glint, grain
    paintShadow()
    titleLabel.TextColor3 = theme.Colors.foreground
    if titleImg and imageAdaptive then titleImg.ImageColor3 = theme.Colors.foreground end
    if applyTitleImage and imageIsModal and reason ~= "accent" then applyTitleImage() end
    local sub = titleBar:FindFirstChild("Subtitle")
    if sub then sub.TextColor3 = theme.Colors.mutedForeground end
    closeIcon.reskin(); minIcon.reskin()   -- glyph tint (current hover state) + hit wash
    if grip then Icons.apply(grip, "move-diagonal-2", theme.Colors[theme.Icon.structural]) end
    searchBox.BackgroundColor3 = theme.Colors.input
    searchStroke.Color = searchStrokeColor()
    -- keep the ring opaque while the field is still focused; only a blurred field wears the hairline
    searchStroke.Transparency = searchFocused and theme.Stroke.control or searchRestAlpha()
    searchHover.reskin()
    local si = searchBox:FindFirstChild("SearchInput")
    if si then si.TextColor3 = theme.Colors.foreground; si.PlaceholderColor3 = theme.Colors.mutedForeground end
    paintPanel()   -- fill, hairline, inset shade and both scroll fades from one place
    activeIndicator.BackgroundColor3 = theme.Colors.primary
    halo.BackgroundColor3 = theme.Colors.primary
    sidebarGrip.BackgroundColor3 = theme.Colors.border
    for _, g in ipairs(groups) do g._header.TextColor3 = theme.Colors.mutedForeground end
  end)

  fabEnabled = config.FloatingToggle ~= false
  local fabOpts = (type(config.FloatingToggle) == "table") and config.FloatingToggle or {}
  autoHide = fabOpts.AutoHide ~= false   -- default true: hide the FAB while the window is shown
  local function ensureFab()
    if fab then return fab end
    if fabMaid then fabMaid:DoCleanup() end
    fabMaid = Maid.new(); maid:Give(fabMaid)
    local kind = fabOpts.Type or "simple"
    -- The FAB logo source mirrors the title: a string, or a { dark, light } table that swaps per mode.
    local fabImageModal = type(fabOpts.Image) == "table"
    local hasImage = fabImageModal or (type(fabOpts.Image) == "string" and fabOpts.Image ~= "")
    -- Adaptive tints a monochrome glyph to foreground (re-tinted on SetMode). Modal tiles are
    -- full-color and swap per mode instead, so Adaptive is ignored for them.
    local fabAdaptive = fabOpts.Adaptive == true and not fabImageModal
    local fabImg
    -- Fill the FAB with the configured logo edge-to-edge (no background frame showing around it), once
    -- the asset resolves (URLs fetch off-thread so the FAB never blocks). Reset the glyph's sprite crop
    -- and tint so a full image renders clean. The write is marshalled to a capability-bearing context.
    -- No-op when no Image is configured (the gamepad placeholder stays).
    local function applyFabImage(img)
      Asset.imageAsync(srcFor(fabOpts.Image, theme.Mode), function(id)
        Safe.mutate(function()
          if not img.Parent then return end
          img.Image = id
          img.ImageRectOffset = Vector2.new(0, 0)
          img.ImageRectSize = Vector2.new(0, 0)
          img.ImageColor3 = fabAdaptive and theme.Colors.foreground or Color3.fromRGB(255, 255, 255)
        end)
      end)
    end
    -- The gamepad placeholder sits on primary for a circle FAB (so it needs primaryForeground) and
    -- on a neutral surface for square (primary). Resolved live: the fab closure re-tints it.
    local function placeholderColor()
      return (kind == "circle") and theme.Colors.primaryForeground or theme.Colors.primary
    end
    -- A logo fills the whole FAB (rounded to the FAB shape); the gamepad placeholder is a small
    -- centered glyph. `radius` clips the fill to match the FAB's own corner.
    local function makeFabImg(radius)
      if hasImage then
        return Create("ImageLabel", { Name = "Img", BackgroundTransparency = 1,
          -- glyph (adaptive) or self-contained tile (modal): Fit (show whole mark); plain logo: Crop (fill)
          ScaleType = (fabAdaptive or fabImageModal) and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
          Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0), Image = "", Parent = fab, Create.corner(radius) })
      end
      local img = Create("ImageLabel", { Name = "Img", BackgroundTransparency = 1, Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0.5, -12, 0.5, -12), Parent = fab })
      Icons.apply(img, "gamepad-2", placeholderColor())
      return img
    end
    -- ONE chevron sprite that ROTATES to face the other way; `dockedLeft` is the single source
    -- of both that rotation and the direction the tab leans on hover.
    local chev, dockedLeft = nil, true
    local F = S.fab
    fab = Create("ImageButton", { Name = "FloatingToggle", AutoButtonColor = false, BackgroundTransparency = 0,
      Visible = false, Size = UDim2.new(0, F.size, 0, F.size), Position = UDim2.new(0, F.margin, 1, -(F.size + F.margin)),
      ZIndex = Overlay.Z.fab, Parent = Overlay.get(gui) })
    fab:SetAttribute("FabType", kind)
    fabScale = Create("UIScale", { Scale = 1, Parent = fab })
    if kind == "square" then
      fab.BackgroundColor3 = theme.Colors.surface
      Create("UICorner", { CornerRadius = UDim.new(0, theme.Radius.lg), Parent = fab })
      fabImg = makeFabImg(theme.Radius.lg); applyFabImage(fabImg)
    elseif kind == "circle" then
      fab.BackgroundColor3 = theme.Colors.primary
      Create("UICorner", { CornerRadius = UDim.new(0, F.size / 2), Parent = fab })
      fabImg = makeFabImg(F.size / 2); applyFabImage(fabImg)
    else -- simple: F.simple square chevron tab, neutral surface (follows the mode)
      fab.Size = UDim2.new(0, F.simple, 0, F.simple)
      fab.Position = UDim2.new(0, -F.peek, 0.5, -F.simple / 2) -- dock at the left edge, peeking F.peek px (magnet)
      fab.BackgroundColor3 = theme.Colors.surface
      Create("UICorner", { CornerRadius = UDim.new(0, F.radius), Parent = fab })
      Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = fab })
      -- AnchorPoint 0.5: Rotation pivots about the AnchorPoint, so the 180 flip has to spin
      -- about the glyph's own centre and not about its top-left corner.
      chev = Create("ImageLabel", { Name = "Chevron", BackgroundTransparency = 1, Size = UDim2.new(0, 24, 0, 24),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Parent = fab })
      Icons.apply(chev, "chevron-right", theme.Colors.primary)
    end
    -- Size override (accept UDim2 or {Width,Height} table)
    if fabOpts.Size then
      if type(fabOpts.Size) == "table" and type(fabOpts.Size.Width) == "number" then
        fab.Size = UDim2.new(0, fabOpts.Size.Width, 0, fabOpts.Size.Height or 44)
      else fab.Size = fabOpts.Size end
    end
    -- Position: a named anchor ("TopLeft".."BottomRight"), a raw UDim2, or default per kind
    local defaultAnchor = (kind == "simple") and "MidLeft" or "TopLeft"
    local pos = fabOpts.Position
    if type(pos) == "string" then
      if not FAB_ANCHORS[pos] then pos = defaultAnchor end
      fab.Position = fabAnchorPos(pos, kind, fab.Size.X.Offset, fab.Size.Y.Offset, F)
    elseif pos ~= nil then
      fab.Position = pos -- raw UDim2
    else
      fab.Position = fabAnchorPos(defaultAnchor, kind, fab.Size.X.Offset, fab.Size.Y.Offset, F)
    end
    fabFullSize = fab.Size
    dockedLeft = (fab.Position.X.Scale or 0) < 0.5
    if chev then chev.Rotation = dockedLeft and 0 or 180 end

    -- Depth layers are SIBLINGS of the FAB in the overlay root, never children: under
    -- ZIndexBehavior.Sibling a child always renders over its parent's fill, so a 9-slice glow
    -- parented to the FAB would wash out its whole face and the glyph with it. Both are nil
    -- until Effect.shadowId is verified in Studio (the glow also on phones), and every Effects
    -- helper tolerates nil, so the geometry below needs no guard of its own.
    local overlayRoot = Overlay.get(gui)
    local fabShadow = Effects.shadow(overlayRoot, theme, { name = "FabShadow", level = "popover", zIndex = Overlay.Z.fab - 2 })
    local fabGlow = Effects.glow(overlayRoot, theme, theme.Colors.primary, "control", Overlay.Z.fab - 1, "FabGlow")
    if fabShadow then fabMaid:Give(fabShadow) end
    if fabGlow then fabMaid:Give(fabGlow) end
    local fabHover, peeked = false, false
    -- ONE formula per layer: both rest hidden while the FAB itself is hidden, and the glow only
    -- lights under a pointer. Every writer (paint, pop, hover) reads these, so a re-skin
    -- mid-hover cannot disagree with the hover tween.
    local function shadowRest() return fab.Visible and theme.fx(theme).shadow or 1 end
    local function glowRest() return (fab.Visible and fabHover) and theme.Opacity.glowHover or 1 end
    local function paintFabLayers()
      if fabShadow then Effects.reskin(fabShadow, theme, "shadow"); fabShadow.ImageTransparency = shadowRest() end
      if fabGlow then Effects.reskin(fabGlow, theme, "glow", theme.Colors.primary); fabGlow.ImageTransparency = glowRest() end
    end
    local function mirrorFab()
      Effects.mirror(fabShadow, fab, "popover", theme)
      Effects.mirror(fabGlow, fab, "control", theme)
    end
    -- Position goal for a mirrored layer: the centre Effects.mirror lands on (an AnchorPoint 0.5
    -- layer over the AnchorPoint 0 FAB), dropped by the level's offsetY. Used whenever the FAB's
    -- Position is TWEENED, so the layers travel WITH it instead of teleporting to the
    -- destination while the button is still sliding.
    local function layerGoal(goal, level)
      local sz, off = fab.Size, theme.Effect[level].offsetY
      return UDim2.new(goal.X.Scale + sz.X.Scale / 2, goal.X.Offset + sz.X.Offset / 2,
        goal.Y.Scale + sz.Y.Scale / 2, goal.Y.Offset + sz.Y.Offset / 2 + off)
    end
    local function moveFab(goal, dur, style)
      Animate.to(fab, dur, { Position = goal }, style)
      if fabShadow then Animate.to(fabShadow, dur, { Position = layerGoal(goal, "popover") }, style) end
      if fabGlow then Animate.to(fabGlow, dur, { Position = layerGoal(goal, "control") }, style) end
    end
    -- a no-op tween is still a tween (and the Hide/Show budget counts them): only spend one
    -- when the alpha actually moves -- the glow rests at 1 and stays there unless hovered.
    local function fadeLayer(layer, dur, goal)
      if layer and layer.ImageTransparency ~= goal then Animate.to(layer, dur, { ImageTransparency = goal }) end
    end
    fabFade = function(on)
      local dur = on and "slow" or "fast"
      fadeLayer(fabShadow, dur, on and theme.fx(theme).shadow or 1)
      fadeLayer(fabGlow, dur, on and glowRest() or 1)
    end
    mirrorFab(); paintFabLayers()

    -- Only the "simple" slide-out tab magnets to an edge. circle/square FABs are free-floating:
    -- they stay wherever the user drops them (no snap), so this is a no-op for them.
    fabSnap = function()
      if kind ~= "simple" then return end
      local vp = Overlay.get(gui).AbsoluteSize
      if not vp or vp.X <= 0 then return end
      local w2 = (fabFullSize and fabFullSize.X.Offset) or F.simple
      local cx = fab.Position.X.Scale * vp.X + fab.Position.X.Offset + w2 / 2
      local ys, yo = fab.Position.Y.Scale, fab.Position.Y.Offset
      dockedLeft = cx < vp.X / 2
      peeked = false   -- the snap writes an absolute rest position; any hover lean is spent
      if chev then Animate.rotateTo(chev, "base", dockedLeft and 0 or 180) end
      -- slide-out tab: dock to the edge, peeking F.peek px
      moveFab(UDim2.new(0, dockedLeft and -F.peek or (vp.X - w2 + F.peek), ys, yo), "snap", Animate.EASING.snap)
    end

    -- Hover peek: the docked tab is the only kind that hides behind the screen edge, so it leans
    -- F.hoverPeek px further out while a pointer is on it. Relative (and latched by `peeked`) so
    -- it composes with whatever rest position the magnet last chose.
    local function hoverPeek(on)
      if kind ~= "simple" or on == peeked then return end
      peeked = on
      local d = (dockedLeft and F.hoverPeek or -F.hoverPeek) * (on and 1 or -1)
      local p = fab.Position
      moveFab(UDim2.new(p.X.Scale, p.X.Offset + d, p.Y.Scale, p.Y.Offset), "hover")
    end

    local moved = false
    if fabOpts.Draggable ~= false then
      local fabStart
      -- Drag.bind captures the SPECIFIC InputObject that began the gesture, so a stray second
      -- finger (or another handle's drag) can no longer cross-fire into the FAB -- the same bug
      -- it was written for on the title bar, re-introduced here by hand-rolled handlers.
      Drag.bind(fab, {
        onBegin = function() moved = false; peeked = false; fabStart = fab.Position end,
        onChange = function(dx, dy)
          if math.abs(dx) > S.dragThreshold or math.abs(dy) > S.dragThreshold then moved = true end
          fab.Position = UDim2.new(fabStart.X.Scale, fabStart.X.Offset + dx, fabStart.Y.Scale, fabStart.Y.Offset + dy)
          mirrorFab()
        end,
        -- Always magnet from the knob's CURRENT position on release, whatever the click handler
        -- did to `moved` first (on a slow drag the click fires before InputEnded and clears it).
        onEnd = function() if fabSnap then fabSnap() end end,
      }, fabMaid)
    end
    fabMaid:Give(fab.MouseButton1Click:Connect(function()
      if moved then moved = false; return end
      api:Toggle()
    end))
    fabMaid:Give(themer.register(function(reason)
      if kind == "circle" then
        fab.BackgroundColor3 = theme.Colors.primary
      else -- square + simple are neutral surface
        fab.BackgroundColor3 = theme.Colors.surface
        local st = fab:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
        if chev then Icons.apply(chev, "chevron-right", theme.Colors.primary) end  -- Rotation untouched
      end
      if fabImg and not hasImage then Icons.apply(fabImg, "gamepad-2", placeholderColor()) end
      if fabImg and fabAdaptive and hasImage then fabImg.ImageColor3 = theme.Colors.foreground end
      -- swap to the active-mode tile; an accent change never changes the tile, so skip the fetch
      if fabImg and fabImageModal and reason ~= "accent" then applyFabImage(fabImg) end
      paintFabLayers()   -- the glow is accent-tinted, the shadow per-mode
    end))
    fabMaid:Give(fab.MouseEnter:Connect(function()
      fabHover = true
      Animate.to(fabScale, "fast", { Scale = theme.Motion.hoverScale })
      fadeLayer(fabGlow, "fast", glowRest())
      hoverPeek(true)
    end))
    fabMaid:Give(fab.MouseLeave:Connect(function()
      fabHover = false
      Animate.to(fabScale, "fast", { Scale = 1 })
      fadeLayer(fabGlow, "fast", glowRest())
      hoverPeek(false)
    end))
    fabMaid:Give(fab.MouseButton1Down:Connect(function() Animate.to(fabScale, "fast", { Scale = 0.92 }) end))
    fabMaid:Give(fab.MouseButton1Up:Connect(function() Animate.springTo(fabScale, "base", { Scale = fabHover and theme.Motion.hoverScale or 1 }) end))
    fabMaid:Give(fab)
    return fab
  end

  showFab = function()
    if not fabEnabled then return end
    Safe.mutate(function()
      ensureFab()
      fab.Visible = true
      fabScale.Scale = S.fab.popFrom
      if fabFade then fabFade(true) end   -- the depth layers fade in WITH the pop, not after it
      Animate.toThen(fabScale, "slow", { Scale = 1 }, function()
        if fabSnap and fab:GetAttribute("FabType") == "simple" then fabSnap() end
      end, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
  end
  hideFab = function()
    Safe.mutate(function()
      if not fab or not fab.Visible then return end
      if fabFade then fabFade(false) end
      Animate.toThen(fabScale, "fast", { Scale = S.fab.popFrom }, function()
        fab.Visible = false; fabScale.Scale = 1
      end)
    end)
  end

  function api:SetFloatingToggle(opts)
    local wasHidden = not visible
    if fab then fab:Destroy(); fab = nil end
    -- Merge over the current options so changing one field (e.g. Type, from the Settings selector)
    -- keeps the rest -- otherwise switching type would drop a configured Image/Size/Position.
    local merged = {}
    for k, v in pairs(fabOpts) do merged[k] = v end
    for k, v in pairs(opts or {}) do merged[k] = v end
    fabOpts = merged
    fabEnabled = true
    autoHide = fabOpts.AutoHide ~= false
    ensureFab()
    if wasHidden or not autoHide then showFab() end
  end
  function api:GetFloatingToggleType() return fabOpts.Type or "simple" end

  function api:Minimize()
    Overlay.closeAll()
    api:Hide()
  end
  onMinimizePressed = function() api:Minimize() end   -- fired by the glyph AND by its hit target

  -- drag by title bar
  local dragStartPos
  Drag.bind(titleBar, {
    onBegin = function() dragging = true; dragStartPos = main.Position; Overlay.closeAll(); grabbed(true) end,
    onChange = function(dx, dy)
      -- still start + delta, but the CENTRE (AnchorPoint 0.5) is clamped so the window can never
      -- be thrown off screen: at least Sizes.dragKeep of the title bar stays inside the viewport
      -- and the top edge stays in [0, vp.Y - titleH]. The Scale halves of the start Position are
      -- preserved, so a window that was never dropped keeps its 0.5/0.5 anchoring.
      -- AdaptToViewport is NOT involved (it early-returns while dragging): one clamp, one writer.
      local vp = viewportSize()
      local baseX, baseY = dragStartPos.X.Scale * vp.X, dragStartPos.Y.Scale * vp.Y
      local cx = clamp(baseX + dragStartPos.X.Offset + dx, S.dragKeep - width / 2, vp.X - S.dragKeep + width / 2)
      local cy = clamp(baseY + dragStartPos.Y.Offset + dy, height / 2, vp.Y - titleH + height / 2)
      main.Position = UDim2.new(dragStartPos.X.Scale, cx - baseX, dragStartPos.Y.Scale, cy - baseY)
      userMoved = true
      syncShadow()
    end,
    onEnd = function() dragging = false; grabbed(false) end,
  }, maid)

  -- resize via bottom-right grip. The glyph lives in the rounded corner gutter (Sizes.resizeGrip
  -- square, Sizes.resizeGripInset in from the corner) so it no longer lies over the content
  -- panel. The transparent hit target is CENTRED on the corner: only its inner quadrant overlaps
  -- the window, so a finger-sized square stops swallowing taps meant for the controls in the
  -- panel's bottom-right corner while still being touchHit wide where the finger lands.
  grip = Create("ImageButton", {
    Name = "ResizeGrip", AutoButtonColor = false, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 1), Size = UDim2.new(0, S.resizeGrip, 0, S.resizeGrip),
    Position = UDim2.new(1, -S.resizeGripInset, 1, -S.resizeGripInset),
    ZIndex = 50, Parent = main,
  })
  Icons.apply(grip, "move-diagonal-2", theme.Colors[theme.Icon.structural])
  local gripHitPx = Device.IsTouch() and S.touchHit or 22
  local resizeHit = Create("ImageButton", {
    Name = "ResizeHit", AutoButtonColor = false, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, gripHitPx, 0, gripHitPx), Position = UDim2.new(1, 0, 1, 0),
    ZIndex = 51, Parent = main,
  })
  maid:Give(resizeHit.MouseEnter:Connect(function() Icons.apply(grip, "move-diagonal-2", theme.Colors.foreground) end))
  maid:Give(resizeHit.MouseLeave:Connect(function() Icons.apply(grip, "move-diagonal-2", theme.Colors.mutedForeground) end))
  local resizing = false
  local rSize, rPos
  Drag.bind(resizeHit, {
    onBegin = function()
      resizing = true; rSize = { X = width, Y = height }; rPos = main.Position
      Overlay.closeAll(); grabbed(true)
    end,
    onChange = function(dx, dy)
      width = math.max(MIN_W, rSize.X + dx)
      height = math.max(MIN_H, rSize.Y + dy)
      local vp = viewportSize()
      width = math.min(width, vp.X); height = math.min(height, vp.Y)
      main.Size = UDim2.new(0, width, 0, height)
      -- centre pivot: half of every size delta goes into Position, otherwise growing the window
      -- from the bottom-right corner would walk its top-left corner up and to the left. Derived
      -- from the drag START each event, so it never accumulates rounding.
      main.Position = UDim2.new(rPos.X.Scale, rPos.X.Offset + (width - rSize.X) / 2,
        rPos.Y.Scale, rPos.Y.Offset + (height - rSize.Y) / 2)
      widthFrac = width / vp.X      -- keep proportions current; only used when not userResized
      heightFrac = height / vp.Y
      userMoved = true
      userResized = true
      syncShadow()
    end,
    onEnd = function() resizing = false; grabbed(false) end,
  }, maid)

  -- toggle key
  maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then api:Toggle() end
  end))

  onClosePressed = function()
    if config.ConfirmClose == false then api:Close(); return end
    api:Dialog({ Title = "Close window?", Message = "You can reopen it with the toggle key or the floating button.",
      Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Close", Variant = "destructive", Callback = function() api:Close() end },
      } })
  end

  -- responsive: always re-fit to the viewport, preserving the configured Ratio
  function api:AdaptToViewport()
    if dragging or resizing or sbDrag then return end  -- don't fight an active drag/resize
    local vp = viewportSize()
    if userResized then
      -- honor the user's manual size; only shrink to fit a smaller viewport
      width = math.max(MIN_W, math.min(width, math.floor(vp.X * VP_MARGIN)))
      height = math.max(MIN_H, math.min(height, math.floor(vp.Y * VP_MARGIN)))
    else
      width, height = computeSize()
    end
    main.Size = UDim2.new(0, width, 0, height)
    if userMoved then
      -- honor the user's placement; just keep it on-screen in the new viewport. Position is the
      -- centre, so clamp the top-left corner derived from it and write the centre back.
      local cx = main.Position.X.Scale * vp.X + main.Position.X.Offset
      local cy = main.Position.Y.Scale * vp.Y + main.Position.Y.Offset
      local left = clamp(cx - width / 2, 0, vp.X - width)
      local top = clamp(cy - height / 2, 0, vp.Y - height)
      main.Position = UDim2.new(0, left + width / 2, 0, top + height / 2)
    else
      main.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
    syncShadow()
  end
  api:AdaptToViewport()
  do
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.GetPropertyChangedSignal then
      maid:Give(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() Safe.mutate(function() api:AdaptToViewport() end) end))
    end
  end

  -- mobile/touch floating toggle button
  if fabEnabled then
    ensureFab() -- reopen button; hidden until the window hides (unless AutoHide = false or StartHidden)
    if not autoHide or startHidden then showFab() end
  end
  function api:SetFloatingToggleVisible(b) if b then showFab() else hideFab() end end

  if startHidden then
    -- start collapsed to just the FAB: no entrance animation; pre-set the REST value of every
    -- layer (scale, background, hairline, shadow) so the first api:Show() (FAB tap or toggle key)
    -- reveals a correctly-rendered window instead of one still wearing its folded values.
    visible = false
    main.Visible = false
    winScale.Scale = userScale
    main.BackgroundTransparency = transp
    if mainStroke then mainStroke.Transparency = strokeRest() end
    if shadowScale then shadowScale.Scale = userScale end
    paintShadow()
  else
    -- entrance: the same unfold as Show, one beat slower ('enter')
    winScale.Scale = userScale * theme.Motion.exitScale
    main.BackgroundTransparency = 1
    if mainStroke then mainStroke.Transparency = 1 end
    if shadow then shadow.ImageTransparency = 1 end
    if shadowScale then shadowScale.Scale = winScale.Scale end
    materialise(true, "enter", { bg = transp })
  end

  maid:Give(gui)

  function api:SetCloseCallback(fn) closeCallback = fn end
  function api:Close()
    if closed then return end
    closed = true
    visible = false
    hideGen = hideGen + 1
    -- the same fold as Hide, but a beat slower ('base', not the hiccup-fast 0.12) and all the way
    -- to transparent -- the window dissolves instead of blinking out
    materialise(false, "base", { style = Animate.EASING.pop, dir = Animate.DIR.In, bg = 1, onDone = function()
      if config.OnClose then pcall(config.OnClose) end
      if closeCallback then pcall(closeCallback) end
      if cfg then pcall(function() cfg:Save() end) end
      Overlay.closeAll()
      if Notif then Notif.clearAll() end
      maid:DoCleanup()       -- disconnects EVERY connection (drag, resize, toggle-key, close, ...)
      gui:Destroy()
      Overlay.reset()
    end })
  end
  function api.Destroy() api:Close() end

  return api
end

return Window
