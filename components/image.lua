-- Deps injected via Init(R).
--
-- Loading: an image slot is "expected but not yet arrived" while the content id itself is still
-- being resolved (a URL download leaves Image '' meanwhile, and IsLoaded is TRUE for '', so the
-- flag alone never sees that window) or while the id is set but its pixels are not decoded
-- (IsLoaded == false). While waiting the slot holds an Effects.skeleton block (3.1) and the label
-- itself is transparent; when the pixels land it fades in instead of popping (3.8). IsLoaded is
-- unset (nil) headless and under the mock, which counts as loaded, so the common case never waits
-- at all -- but a wait that DOES start needs a deadline, because neither exit is guaranteed:
-- Asset.imageAsync only ever reports success (a dead URL calls nothing back) and a sprite that
-- fails moderation never flips IsLoaded. Without it the slot would be pinned at
-- ImageTransparency 1 under an endless shimmer, strictly worse than the blank image it drew
-- before 3.1. On expiry the wait is simply declared over and the slot degrades to that blank.
local Image = {}
local Create, DefaultTheme, Icons, Safe, Asset, Animate, Effects
function Image.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Icons = R.Icons; Safe = R.Safe
  Asset = R.Asset; Animate = R.Animate; Effects = R.Effects
end
-- How long a slot may stand empty before the wait is called off. No theme token holds a fetch
-- budget (reported as a deviation), so a module-local fallback in the style core/animate.lua uses
-- for FALLBACK, carrying the same 60s value selectbox.lua gives its LoadOptions timeout.
-- Last resort for the one stuck state nobody reports: a sprite that resolves but never
-- decodes. A failed download now settles through imageAsync's onFail instead.
local RESOLVE_TIMEOUT = 60
function Image.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local img = Create("ImageLabel", {
    Name = "Image", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
    Image = "", ImageColor3 = opts.Color or Color3.fromRGB(255, 255, 255),
    Size = UDim2.new(1, 0, 0, opts.Height or 80), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
  })
  -- A Lucide glyph without an explicit Color follows the foreground token, so it must re-tint on
  -- SetMode; a caller-owned Color3 is left alone. Plain images never register.
  local glyphColor = function() return opts.Color or theme.Colors.foreground end
  if opts.Lucide then Icons.apply(img, opts.Lucide, glyphColor()) end
  local unreg = (opts.Lucide and not opts.Color and opts.AccentReg) and opts.AccentReg(function()
    Icons.apply(img, opts.Lucide, glyphColor())
  end)

  -- ---- resolution + loading state (3.1 / 3.8) ---------------------------------------------
  -- Lucide wins when both are given (they are documented as mutually exclusive), exactly as when
  -- the glyph was applied over the constructor's Image write.
  local src = (not opts.Lucide and type(opts.Image) == "string" and opts.Image ~= "") and opts.Image or nil
  -- Only a source Asset can turn into a content id gets the async treatment; anything else (a
  -- scheme Asset does not model, e.g. rbxgameasset://) is handed to the engine raw, as before.
  local resolvable = src ~= nil and Asset.resolvable(src)
  -- owned: a SetImage has taken the slot, so the in-flight resolve no longer speaks for it.
  -- gaveUp: the deadline expired; there is nothing left to wait for either way.
  local landed, armed, dead, owned, gaveUp = false, false, false, false, false
  local skel, loadConn = nil, nil

  local function waiting()
    if gaveUp then return false end
    if resolvable and not owned and not landed then return true end
    return img.IsLoaded == false
  end
  -- Runs whenever waiting() may have flipped: drop the placeholder and reveal the pixels. Only
  -- meaningful once the slot was actually armed, so an image that was never pending pays nothing
  -- (no skeleton, no connection and -- reduced motion or not -- no tween).
  local function settle()
    if not armed or waiting() then return end
    armed = false
    if loadConn then loadConn:Disconnect(); loadConn = nil end
    if skel then skel.Stop(); skel = nil end
    Animate.to(img, "base", { ImageTransparency = 0 })
  end

  if resolvable then
    -- URLs download off the construction thread, so a tab never blocks on game:HttpGet; the write
    -- comes back on a thread without the GUI capability, hence Safe.mutate (window.lua TitleImage).
    Asset.imageAsync(src, function(id)
      landed = true
      Safe.mutate(function()
        -- A SetImage during the fetch takes the slot for good: this id was decided seconds ago
        -- and must not overwrite what the caller has since asked for.
        if dead or owned then return end
        img.Image = id
        settle()
      end)
    end, function()
      -- The loader now tells us a download will never arrive, so the wait ends on the real signal
      -- rather than on a deadline. The timer below stays as the last resort for the case nobody
      -- can report: a sprite that resolves but never decodes (moderation, a dead asset id).
      landed = true
      Safe.mutate(function()
        if dead or owned then return end
        gaveUp = true
        settle()
      end)
    end)
  elseif src then
    img.Image = src
  end

  if waiting() then
    armed = true
    img.ImageTransparency = 1                       -- there is nothing to show yet; fade in from here
    skel = Effects.skeleton(img, theme, { radius = theme.Radius.sm })
    -- Property signals never auto-fire headless (a test sets IsLoaded then Fires this itself), and
    -- the engine delivers them on a thread that may lack the capability -> Safe.mutate.
    loadConn = img:GetPropertyChangedSignal("IsLoaded"):Connect(function()
      Safe.mutate(function() if not dead then settle() end end)
    end)
    -- The terminal exit neither of the two above can promise (see the header). Runs on a timer
    -- thread with no GUI capability -> Safe.mutate, and is disarmed by the `armed` flag rather
    -- than task.cancel, which throws on an already finished thread (textbox.lua says the same).
    task.delay(RESOLVE_TIMEOUT, function()
      Safe.mutate(function()
        if dead or not armed then return end
        gaveUp = true
        settle()   -- same teardown as a real arrival: block gone, connection dropped, slot visible
      end)
    end)
  end

  return {
    Frame = img,
    -- Takes the slot: whatever is still in flight stops speaking for it, and settle() drops the
    -- placeholder, or the caller's image would sit invisible at ImageTransparency 1 under a live
    -- shimmer for the rest of the control's life.
    SetImage = function(v) Safe.mutate(function() owned = true; img.Image = v; settle() end) end,
    Destroy = function()
      dead = true
      if loadConn then loadConn:Disconnect(); loadConn = nil end
      if skel then skel.Stop(); skel = nil end
      if unreg then unreg() end
      img:Destroy()
    end,
  }
end
return Image
