-- Deps injected via Init(R).
local Overlay = {}
local Create, Mount
local root = nil
local catcher = nil -- full-screen click-catcher behind open popovers (closes them on outside click)
local popovers = {} -- set of close functions for open popovers (dropdowns, color pickers)

-- Process-wide UI scale (last writer wins, like Animate.setEnabled): the window that last called
-- SetUIScale owns it. Overlay children scale THEMSELVES from this number (UIScale on the toast
-- container / tip / dropdown / card) — never a UIScale on the overlay root, because the catcher's
-- (1,0,1,0) size would then stop covering the screen.
local DEFAULT_SCALE = 1
local uiScale = DEFAULT_SCALE
local dialogDepth = 0 -- stacked-dialog counter (2.12); reset() zeroes it

-- Overlay layers (ZIndexBehavior.Sibling: siblings compare ZIndex). Components read from here
-- instead of repeating the literals: popover content is Z.popover+N, dialog card Z.modal+N, etc.
Overlay.Z = { catcher = 1000, popover = 1001, modal = 1500, fab = 1700, toast = 1800, tooltip = 2000 }

-- Anchor-to-popover gap when the caller passes none: today's selectbox literal (4px), kept
-- as the default so a caller that has not yet forwarded a theme token keeps its geometry.
local DEFAULT_GAP = 4
-- Unmeasured-screen fallback (mock / first frame before AbsoluteSize is valid).
local FALLBACK_VIEWPORT = { X = 1920, Y = 1080 }

function Overlay.Init(R) Create = R.Create; Mount = R.Mount end

-- Anonymous (random at runtime, readable in Studio) name so overlay instances don't carry the
-- "EzUI" signature into the GUI tree. Falls back to the readable label if Mount is unavailable.
local function anon(readable)
  if Mount and Mount.anonName then return Mount.anonName(readable) end
  return readable
end

-- A transparent full-screen button mounted under the popover (Z.catcher, the popover is
-- Z.popover+). A click anywhere outside the popover lands on it and closes everything.
local function ensureCatcher()
  if catcher and catcher.Parent ~= nil then return end
  if not root then return end
  catcher = Create("ImageButton", {
    Name = anon("OverlayCatcher"), AutoButtonColor = false, BackgroundTransparency = 1,
    Active = true, Size = UDim2.new(1, 0, 1, 0), ZIndex = Overlay.Z.catcher, Parent = root,
  })
  catcher.MouseButton1Click:Connect(function() Overlay.closeAll() end)
end

local function removeCatcher()
  if catcher then catcher:Destroy(); catcher = nil end
end

-- Non-creating getter: the live overlay root or nil. Used by Safe's capability probe so it
-- never forces root creation. Roblox-safe liveness check (a destroyed Instance has Parent=nil).
function Overlay.peek()
  if root and root.Parent ~= nil then return root end
  return nil
end

function Overlay.get(parentGui)
  -- Roblox-safe liveness check: reading a non-existent member (e.g. a mock-only
  -- "_destroyed" flag) THROWS on real Instances. A destroyed Instance has Parent=nil.
  if root and root.Parent ~= nil then return root end
  root = Create("Frame", {
    Name = anon("OverlayRoot"),
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = Overlay.Z.catcher,
    ClipsDescendants = false,
    Parent = parentGui,
  })
  return root
end

function Overlay.mount(element)
  assert(root, "Overlay.get(parentGui) must be called before mount")
  element.Parent = root
  return element
end

-- Popover registry: components register their Close fn so the window can close
-- every open popover at once (e.g. on drag/resize/minimize/shutdown).
function Overlay.trackPopover(closeFn) popovers[closeFn] = true; ensureCatcher(); return closeFn end
function Overlay.untrackPopover(closeFn)
  popovers[closeFn] = nil
  if next(popovers) == nil then removeCatcher() end
end
function Overlay.closeAll()
  local fns = popovers; popovers = {}
  for fn in pairs(fns) do pcall(fn) end
  removeCatcher()
end

-- Screen size for popover placement; falls back when unmeasured (mock / first frame).
function Overlay.viewport()
  if root then
    local s = root.AbsoluteSize
    if s and (s.X or 0) > 0 and (s.Y or 0) > 0 then return s end
  end
  return { X = FALLBACK_VIEWPORT.X, Y = FALLBACK_VIEWPORT.Y } -- a copy: callers must not mutate the fallback
end

-- Popover geometry shared by SelectBox / ColorPicker: prefer below the anchor, flip above only
-- when below overflows AND above fits (otherwise stay below: an overflow beats a negative y),
-- and clamp x inside [0, viewport - w - gap]. `w`/`h` are the popover's on-screen size, so a
-- caller with a UIScale passes w*scale, h*scale (2.22). Returns x, y, openUp.
function Overlay.placePopover(anchorPos, anchorSize, w, h, gap)
  gap = gap or DEFAULT_GAP
  local ax, ay = anchorPos and anchorPos.X or 0, anchorPos and anchorPos.Y or 0
  local ah = anchorSize and anchorSize.Y or 0
  local vp = Overlay.viewport()
  local below = ay + ah + gap
  local above = ay - gap - h
  local openUp = (below + h > vp.Y) and (above >= 0)
  local y = openUp and above or below
  local x = math.max(0, math.min(ax, vp.X - w - gap))
  return x, y, openUp
end

-- Process-wide UI scale (see header). Overlay-hosted components read scale() when they build so
-- their own UIScale matches the window; nothing is attached to the root here.
function Overlay.setScale(n)
  if type(n) ~= "number" or n ~= n or n <= 0 then
    error("Overlay.setScale(n): positive number expected, got " .. tostring(n), 2)
  end
  uiScale = n
  return n
end
function Overlay.scale() return uiScale end

-- Stacked dialogs (2.12): each open dialog pushes, each close pops. Depth is clamped at 0 so an
-- unbalanced pop (double-close, close after reset) can never make later dialogs mis-layer.
function Overlay.pushDialog() dialogDepth = dialogDepth + 1; return dialogDepth end
function Overlay.popDialog() dialogDepth = math.max(0, dialogDepth - 1); return dialogDepth end
function Overlay.dialogDepth() return dialogDepth end

function Overlay.reset()
  root = nil; catcher = nil; popovers = {}
  uiScale = DEFAULT_SCALE; dialogDepth = 0
end

return Overlay
