



local EmbeddedModules = {}


EmbeddedModules["../output/bundle"] = function()




local EmbeddedModules = {}


EmbeddedModules["components/image"] = function()













local Image = {}
local Create, DefaultTheme, Icons, Safe, Asset, Animate, Effects
function Image.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Icons = R.Icons; Safe = R.Safe
Asset = R.Asset; Animate = R.Animate; Effects = R.Effects
end





local RESOLVE_TIMEOUT = 60
function Image.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local img = Create("ImageLabel", {
Name = "Image", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
Image = "", ImageColor3 = opts.Color or Color3.fromRGB(255, 255, 255),
Size = UDim2.new(1, 0, 0, opts.Height or 80), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
})


local glyphColor = function() return opts.Color or theme.Colors.foreground end
if opts.Lucide then Icons.apply(img, opts.Lucide, glyphColor()) end
local unreg = (opts.Lucide and not opts.Color and opts.AccentReg) and opts.AccentReg(function()
Icons.apply(img, opts.Lucide, glyphColor())
end)




local src = (not opts.Lucide and type(opts.Image) == "string" and opts.Image ~= "") and opts.Image or nil


local resolvable = src ~= nil and Asset.resolvable(src)


local landed, armed, dead, owned, gaveUp = false, false, false, false, false
local skel, loadConn = nil, nil
local watchDecode

local function waiting()
if gaveUp then return false end
if resolvable and not owned and not landed then return true end
return img.IsLoaded == false
end



local function settle()
if not armed or waiting() then return end
armed = false
if loadConn then loadConn:Disconnect(); loadConn = nil end
if skel then skel.Stop(); skel = nil end
Animate.to(img, "base", { ImageTransparency = 0 })
end






watchDecode = function()
if not armed or img.Image == "" then return end
if loadConn then loadConn:Disconnect() end
loadConn = Asset.awaitLoaded(img, function(loaded)
Safe.mutate(function()
if dead then return end


if not loaded then gaveUp = true end
settle()
end)
end)
end

if resolvable then


Asset.imageAsync(src, function(id)
landed = true
Safe.mutate(function()


if dead or owned then return end
img.Image = id
settle()
watchDecode()
end)
end, function()



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
img.ImageTransparency = 1
skel = Effects.skeleton(img, theme, { radius = theme.Radius.sm })




watchDecode()



task.delay(RESOLVE_TIMEOUT, function()
Safe.mutate(function()
if dead or not armed then return end
gaveUp = true
settle()
end)
end)
end

return {
Frame = img,



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

end


EmbeddedModules["core/create"] = function()

local Create = {}

local function build(className, props)
local inst = Instance.new(className)
props = props or {}
local parent
for k, v in pairs(props) do
if type(k) == "number" then
v.Parent = inst
elseif k == "Parent" then
parent = v
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




function Create.stroke(color, thickness, transparency)
return Create("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency })
end





local function keypoints(stops, ctor, what)
if type(stops) ~= "table" or #stops == 0 then
error("Create." .. what .. ": stops = { {t, value}, ... } required", 3)
end
local out = {}
for i, s in ipairs(stops) do out[i] = ctor(s[1], s[2]) end
return out
end


function Create.gradient(opts)
opts = opts or {}
return Create("UIGradient", {
Rotation = opts.rotation or 0,
Color = ColorSequence.new(keypoints(opts.stops, ColorSequenceKeypoint.new, "gradient")),
})
end



function Create.shade(opts)
opts = opts or {}
return Create("UIGradient", {
Rotation = opts.rotation or 0,
Transparency = NumberSequence.new(keypoints(opts.stops, NumberSequenceKeypoint.new, "shade")),
})
end






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

end


EmbeddedModules["components/keybind"] = function()

local Keybind = {}
local Create, DefaultTheme, Maid, Flag, Safe, Recipes, Animate
local UserInputService = game:GetService("UserInputService")
function Keybind.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Flag = R.Flag; Safe = R.Safe; Recipes = R.Recipes
Animate = R.Animate
end


local LISTEN_TEXT = "Press a key"




local function pulseTok(theme, k)
if k == "period" then return theme.Motion.pulse end
return theme.Stroke.pulse[k]
end




local ESCAPE = (function()
local ok, kc = pcall(function() return Enum.KeyCode.Escape end)
if ok then return kc end
return nil
end)()




local function keyName(k)
if type(k) == "string" then return k end
if k ~= nil then
local ok, name = pcall(function() return k.Name end)
if ok and type(name) == "string" then return name end
end
return "Unknown"
end




local function toKeyCode(name)
local ok, kc = pcall(function() return Enum.KeyCode[name] end)
if ok and kc then return kc end
return Enum.KeyCode.Unknown
end

function Keybind.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local listening = false
local enabled = true
local keyCode = "Unknown"
local onPressed

local hasDesc = opts.Description ~= nil and opts.Description ~= ""
local btn = Create("TextButton", { Name = "Keybind", AutoButtonColor = false, Text = "",
BackgroundColor3 = theme.Colors.surface, Size = UDim2.new(1, 0, 0, hasDesc and 50 or 34), LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent, Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }) })
Create.text(Create("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = opts.Text or "Keybind",
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
Position = UDim2.new(0, 0, 0, hasDesc and 8 or 0), Size = UDim2.new(1, -80, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn }),
theme, "label")
if hasDesc then
Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -80, 0, 18), Parent = btn }), theme, "muted")
end



local keyBox = Create.text(Create("TextLabel", { Name = "Key", BackgroundColor3 = theme.Colors.background,
Text = "...", TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Center,
AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5),
Size = UDim2.new(0, 0, 0, theme.Sizes.chip), Position = UDim2.new(1, 0, 0.5, 0), Parent = btn,
Create.corner(theme.Radius.sm),
Create.padding({ left = theme.Spacing.gap, right = theme.Spacing.gap }),
Create("UISizeConstraint", { MinSize = Vector2.new(theme.Sizes.touchHit, theme.Sizes.chip) }) }),
theme, "muted")



local chipStroke = Create.stroke(theme.Colors.border, 1); chipStroke.Parent = keyBox
local function chipColor(on) return on and theme.Colors.ring or theme.Colors.border end
local ring = Recipes.focus(chipStroke, keyBox, chipColor, { theme = theme })
maid:Give(ring.disconnect)


local hover = Recipes.hover(btn, { theme = theme, host = btn, corner = theme.Radius.md,
inset = { x = theme.Spacing.inputX, y = 0 } })
maid:Give(hover.disconnect)
maid:Give(Recipes.press(btn, keyBox, { theme = theme }).disconnect)



local function chipText() return listening and LISTEN_TEXT or keyCode end
local function chipTint() return listening and theme.Colors.mutedForeground or theme.Colors.foreground end
local function paintChip() keyBox.Text = chipText(); keyBox.TextColor3 = chipTint() end




local pulse
local function stopPulse()
if pulse then pulse.Cancel(); pulse = nil end
chipStroke.Transparency = theme.Stroke.control
end
local function startPulse()
stopPulse()
if not Animate.isEnabled() then return end
chipStroke.Transparency = pulseTok(theme, "low")
pulse = Animate.pulse(chipStroke, pulseTok(theme, "period"),
{ Transparency = pulseTok(theme, "high") }, Enum.EasingStyle.Sine)
end
maid:Give(stopPulse)



local function setListening(on)
listening = on and true or false
Safe.mutate(function()
paintChip()
if listening then startPulse() else stopPulse() end
ring.set(listening)
end)
end








local function flashCapture()
Safe.mutate(function()
Animate.pop(keyBox, "fast")
chipStroke.Color = theme.Colors.primary
Animate.to(chipStroke, "base", { Color = chipColor(false), Transparency = theme.Stroke.control })
end)
end

local function apply(name)
keyCode = keyName(name)
Safe.mutate(paintChip)
end
local commit = Flag.bind(opts, keyName(opts.Default or "Unknown"), apply)




local function setKey(k)
commit(keyName(k))
if opts.OnChanged then opts.OnChanged(toKeyCode(keyCode)) end
end



local function setEnabled(b)
b = b and true or false
if enabled == b then return end
enabled = b
if not b and listening then setListening(false) end
Safe.mutate(function()
Recipes.disabled({ { keyBox, "BackgroundTransparency", 0 }, { keyBox, "TextTransparency", 0 } }, not b, theme)
end)
end
if opts.Disabled then setEnabled(false) end

local api = { Frame = btn }
function api.GetKey() return toKeyCode(keyCode) end
function api.SetKey(k) setKey(k) end
function api.OnPressed(fn) onPressed = fn end
function api.SetEnabled(b) setEnabled(b) end
function api.Destroy() maid:DoCleanup() end

maid:Give(btn.MouseButton1Click:Connect(function()
if not enabled then return end
setListening(true)
end))
maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
if listening then



if ESCAPE ~= nil and input.KeyCode == ESCAPE then setListening(false); return end
flashCapture()
setListening(false)
setKey(input.KeyCode)
elseif not gameProcessed and input.KeyCode == toKeyCode(keyCode) then
if opts.Callback then opts.Callback() end
if onPressed then onPressed() end
end
end))
maid:Give(btn)

if opts.AccentReg then maid:Give(opts.AccentReg(function()
btn.BackgroundColor3 = theme.Colors.surface
local lab = btn:FindFirstChild("Label"); if lab then lab.TextColor3 = theme.Colors.foreground end
local de = btn:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
keyBox.BackgroundColor3 = theme.Colors.background
paintChip()
chipStroke.Color = chipColor(listening)
hover.reskin()
end)) end

return api
end
return Keybind

end


EmbeddedModules["components/window"] = function()

local UserInputService = game:GetService("UserInputService")

local Window = {}
local Create, DefaultTheme, Animate, Maid, Icons, Overlay, Acrylic, Tab, ConfigMod, DialogMod, Notif, Asset, Themer, Mount, Safe, Drag, Device, Recipes, Effects

function Window.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid
Icons = R.Icons; Overlay = R.Overlay; Acrylic = R.Acrylic; Tab = R.Tab; ConfigMod = R.Config; DialogMod = R.Dialog
Notif = R.Notification; Asset = R.Asset; Themer = R.Themer
Mount = R.Mount; Safe = R.Safe; Drag = R.Drag; Device = R.Device; Recipes = R.Recipes; Effects = R.Effects
end




local SIDEBAR_W = 150
local SIDEBAR_MIN, SIDEBAR_MAX = 110, 260
local MIN_W, MIN_H = 380, 260
local VP_MARGIN = 0.92
local DEF_WF, DEF_HF = 0.45, 0.6
local FALLBACK_VP = { X = 1280, Y = 720 }


local TITLE_BTN_GAP = 26


local GROUP_HEADER_INSET = 10

local MEASURE_MAX_W = 1e4


local SHADOW_FOLLOW = 0.5


local PANEL_FOLLOW = 0.6


local INSET_BAND = 0.06
local SCROLL_FADE_H = 14


local SIDEBAR_HANDLE_W = 12
local SEARCH_PAD = 8


local IND_TRAVEL_PX = 900


local GRIP_ALPHA = { rest = 1, hover = 0.3, drag = 0, touch = 0.5 }


local SIDEBAR_TOP = 36





local HALO_OUT, HALO_CYCLES = 12, 5

local SIDEBAR_EMPTY_ICON = "search"



local RESOLVE_TIMEOUT = 60
local function clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end
local FAB_ANCHORS = { TopLeft = true, MidLeft = true, BottomLeft = true, TopRight = true, MidRight = true, BottomRight = true }




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
end





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




local function themeOverrides()
local over, words = config.Theme or {}, config.Strings
if words == nil then return over end
if type(words) ~= "table" then error("CreateWindow: Strings must be a table of strings", 4) end
local known = DefaultTheme.Strings or {}
local merged, all = {}, {}
for k, v in pairs(over) do merged[k] = v end
if type(over.Strings) == "table" then for k, v in pairs(over.Strings) do all[k] = v end end
for k, v in pairs(words) do
if type(v) ~= "string" then
error(("CreateWindow: Strings.%s must be a string, got %s"):format(tostring(k), type(v)), 4)
end
if known[k] == nil then
if warn then warn(("[EzUI] CreateWindow: unknown Strings key %q is ignored"):format(tostring(k))) end
else
all[k] = v
end
end
merged.Strings = all
return merged
end

local theme = DefaultTheme.new(themeOverrides())




local effects = config.Effects or "full"
if effects ~= "full" and effects ~= "light" and effects ~= "auto" then
if warn then warn(("[EzUI] CreateWindow: unknown Effects %q, using full"):format(tostring(effects))) end
effects = "full"
end
if effects == "auto" then effects = (Device.IsTouch() and not Device.SupportsHover()) and "light" or "full" end
theme.Lite = effects == "light"

Animate.useMotion(theme.Motion)
if config.Mode == "light" then DefaultTheme.applyMode(theme, "light") else theme.Mode = "dark" end




if config.Animations ~= nil then Animate.setEnabled(config.Animations ~= false)
else Animate.applyDefault(not Device.PrefersReducedMotion()) end
local S = theme.Sizes
if config.NotificationPosition then Notif.setPosition(config.NotificationPosition) end
theme.AccentName = "Adaptive"
local maid = Maid.new()





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






local function sizeOption(name)
local v = config[name]
if v == nil then return nil end
local w = type(v) == "table" and tonumber(v.Width or v[1]) or nil
local ht = type(v) == "table" and tonumber(v.Height or v[2]) or nil
if not (w and ht and w > 0 and ht > 0 and w < math.huge and ht < math.huge) then
error(("CreateWindow: %s must be { Width = n, Height = n } with positive numbers"):format(name), 4)
end
return { math.max(MIN_W, math.floor(w)), math.max(MIN_H, math.floor(ht)) }
end


local tabTransition = config.TabTransition or "slide"
if tabTransition ~= "slide" and tabTransition ~= "none" then
if warn then warn(("[EzUI] CreateWindow: unknown TabTransition %q, sliding"):format(tostring(tabTransition))) end
tabTransition = "slide"
end
local fixedSize, startSize = sizeOption("FixedSize"), sizeOption("StartSize")
if fixedSize and startSize then error("CreateWindow: give FixedSize or StartSize, not both", 3) end
local presetSize = fixedSize or startSize
local function viewportSize()
local cam = workspace and workspace.CurrentCamera
local vp = cam and cam.ViewportSize
if vp and vp.X and vp.X > 0 then return vp end
return FALLBACK_VP
end
local function computeSize()
if presetSize then return presetSize[1], presetSize[2] end
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
local selectedIndex = 0
local visible = true
local fab, fabScale, fabFullSize, fabSnap, fabMaid, showFab, hideFab, fabFade
local fabPulse
local fabEnabled, autoHide
local sidebarW = SIDEBAR_W
local closed = false
local startHidden = config.StartHidden == true
local userMoved = false
local dragging = false
local userResized = false


local userW, userH


local adaptPending, flushAdapt = false, nil
local closeCallback
local themer = Themer.new()





local function removeFrom(list, item)
for i = #list, 1, -1 do if list[i] == item then table.remove(list, i); return end end
end


local function readParent(f) return f.Parent end
local function inTree(frame)
local ok, parent = pcall(readParent, frame)
return not ok or parent ~= nil
end
local function prune(list, frameOf)
local n = 0
for i = 1, #list do
local item = list[i]
local f = frameOf(item)
if f == nil or inTree(f) then n = n + 1; list[n] = item end
end
for i = #list, n + 1, -1 do list[i] = nil end
end


local function grown(list, mark, frameOf)
if #list > math.max(64, 2 * mark) then prune(list, frameOf); return #list end
return mark
end
local function controlFrame(c) return c.Frame end
local function searchFrame(s) return s.frame end
local lockables, lockMark = {}, 0
local function registerControl(c)
lockables[#lockables + 1] = c
lockMark = grown(lockables, lockMark, controlFrame)
return function() removeFrom(lockables, c) end
end


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







Overlay.get(gui, mountCtx)





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


local function strokeRest() return theme.Stroke.window end



Acrylic.decorate(main, theme, { transparency = transp, base = theme.Colors.background,
edge = true, strokeAlpha = strokeRest() })

local mainStroke = main:FindFirstChildOfClass("UIStroke")
local winScale = Create("UIScale", { Scale = 1, Parent = main })
local userScale = 1


local function shownScale()
return (type(userScale) == "number" and userScale > 0 and userScale < math.huge) and userScale or 1
end






local shadow = Effects.shadow(gui, theme, { name = "WindowShadow", level = "window", zIndex = 0 })
local shadowScale = shadow and Create("UIScale", { Scale = 1, Parent = shadow })

local function syncShadow() Effects.mirror(shadow, main, "window", theme) end



local lifted = false
local function shadowAlpha(on)
local a = theme.fx(theme).shadow + transp * SHADOW_FOLLOW
if on then a = a + theme.Effect.lift.alphaDelta end
return clamp(a, 0, 1)
end
local function paintShadow()
if not shadow then return end
Effects.reskin(shadow, theme, "shadow")
shadow.ImageTransparency = shadowAlpha(lifted)
end
syncShadow(); paintShadow()






local function grabbed(on)
lifted = on and true or false
if shadow then Effects.lift(shadow, theme, on, shadowAlpha(lifted)) end
if mainStroke then Animate.to(mainStroke, "fast", { Transparency = on and theme.Stroke.floating or strokeRest() }) end
end
maid:Give(function() if lifted then grabbed(false) end end)


local grip, gripRest




local function srcFor(value, mode)
if type(value) == "table" then return value[mode] or value.dark or value.light end
return value
end


local titleSrc = config.Image
local imageIsModal = type(titleSrc) == "table"



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
local applyTitleImage
if hasTitleImg then
local imgSize = 36
titleImg = Create("ImageLabel", {


Name = "TitleImage", BackgroundTransparency = 1,
ScaleType = (imageAdaptive or imageIsModal) and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
Size = UDim2.new(0, imgSize, 0, imgSize), Image = "", Parent = titleBar,
Create.corner(theme.Radius.md),
})
if imageAdaptive then titleImg.ImageColor3 = theme.Colors.foreground
elseif imageIsModal then titleImg.ImageColor3 = Color3.fromRGB(255, 255, 255) end








local titleSkel, titleLoadConn
local function titleLoaded() return titleImg.Image ~= "" and titleImg.IsLoaded ~= false end
local function stopTitleSkeleton()
if titleLoadConn then titleLoadConn:Disconnect(); titleLoadConn = nil end
if titleSkel then titleSkel.Stop(); titleSkel = nil end
end







local function watchTitleDecode()
if not titleSkel or titleImg.Image == "" then return end
if titleLoadConn then titleLoadConn:Disconnect() end




titleLoadConn = Asset.awaitLoaded(titleImg, function() Safe.mutate(stopTitleSkeleton) end)
end
local function startTitleSkeleton()
if titleSkel or titleLoaded() then return end
titleSkel = Effects.skeleton(titleBar, theme, { name = "TitleImageSkeleton", radius = theme.Radius.md,
size = UDim2.new(0, imgSize, 0, imgSize), position = UDim2.new(0, 0, 0.5, 0),




zIndex = 0 })
titleSkel.Frame.AnchorPoint = Vector2.new(0, 0.5)
watchTitleDecode()








local mine = titleSkel
task.delay(RESOLVE_TIMEOUT, function()
Safe.mutate(function() if titleSkel == mine then stopTitleSkeleton() end end)
end)
end
maid:Give(stopTitleSkeleton)
applyTitleImage = function()
Asset.imageAsync(srcFor(titleSrc, theme.Mode), function(id)
Safe.mutate(function()
if titleImg.Parent then titleImg.Image = id end




if titleLoaded() then stopTitleSkeleton() else watchTitleDecode() end
end)
end, function()


Safe.mutate(stopTitleSkeleton)
end)


startTitleSkeleton()
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

local subtitleLabel
if hasSubtitle then
subtitleLabel = Create("TextLabel", {
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
Create.text(subtitleLabel, theme, "muted")
end





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





local hitSize = math.min(theme.Sizes.touchHit, TITLE_BTN_GAP)
local closeIcon = Recipes.iconButton(closeBtn, { theme = theme, icon = "x", rest = theme.Icon.structural,
hover = "destructive", hitSize = hitSize,
onClick = function() if onClosePressed then onClosePressed() end end })
local minIcon = Recipes.iconButton(minBtn, { theme = theme, icon = "minus", rest = theme.Icon.structural,
hover = theme.Icon.accent, hitSize = hitSize,
onClick = function() if onMinimizePressed then onMinimizePressed() end end })
closeIcon.Hit.ZIndex = minIcon.Hit.ZIndex + 1
maid:Give(closeIcon.disconnect); maid:Give(minIcon.disconnect)


local body = Create("Frame", {
Name = "Body",
BackgroundTransparency = 1,
Position = UDim2.new(0, 0, 0, titleH),
Size = UDim2.new(1, 0, 1, -titleH),
Parent = main,
})



local searchBox = Create("Frame", {
Name = "Search", BackgroundColor3 = theme.Colors.input, BorderSizePixel = 0,
Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(0, sidebarW - 16, 0, 24), Parent = body,
Create.corner(theme.Radius.sm), Create.padding({ left = SEARCH_PAD, right = SEARCH_PAD }),
})
local searchStroke = Create.stroke(theme.Colors.border, 1, theme.modeVal(theme, theme.Stroke.search))
searchStroke.Parent = searchBox
local searchInput = Create("TextBox", {
Name = "SearchInput", BackgroundTransparency = 1, Text = "", PlaceholderText = theme.Strings.Search,
PlaceholderColor3 = theme.Colors.mutedForeground, TextColor3 = theme.Colors.foreground,
TextXAlignment = Enum.TextXAlignment.Left,
ClearTextOnFocus = false, Size = UDim2.new(1, 0, 1, 0), Parent = searchBox,
})
Create.text(searchInput, theme, "muted")
local searchFocused = false
local function searchStrokeColor() return searchFocused and theme.Colors.ring or theme.Colors.border end


local function searchRestAlpha() return theme.modeVal(theme, theme.Stroke.search) end
local searchFocus = Recipes.focus(searchStroke, searchInput, function(focused)
searchFocused = focused
return searchStrokeColor()
end, { theme = theme, restAlpha = searchRestAlpha })
maid:Give(searchFocus.disconnect)


local searchHover = Recipes.hover(searchBox, { theme = theme, corner = theme.Radius.sm,
inset = { x = SEARCH_PAD, y = 0 } })
maid:Give(searchHover.disconnect)

local sidebar = Create("ScrollingFrame", {
Name = "Sidebar",
BackgroundTransparency = 1,
BorderSizePixel = 0,
Position = UDim2.new(0, 0, 0, SIDEBAR_TOP),
Size = UDim2.new(0, sidebarW, 1, -SIDEBAR_TOP),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.new(0, 0, 0, 0),
Parent = body,
Create.listLayout({ Padding = 4 }),
Create.padding({ all = 8 }),
})



Recipes.scrollbar(sidebar, theme)




local sidebarEmpty = Recipes.empty(body, { theme = theme, text = theme.Strings.NoMatches,
icon = SIDEBAR_EMPTY_ICON, zIndex = 4 })
sidebarEmpty.Frame.Position = UDim2.new(0, 0, 0, SIDEBAR_TOP)
sidebarEmpty.Frame.Size = UDim2.new(0, sidebarW, 1, -SIDEBAR_TOP)

Create.padding({ left = theme.Spacing.gap, right = theme.Spacing.gap }).Parent = sidebarEmpty.Frame
local cgap = theme.Spacing.gap


local function panelAlpha() return clamp(transp * PANEL_FOLLOW, 0, 1) end
local contentPanel = Create("Frame", {
Name = "ContentPanel", BackgroundColor3 = theme.Colors.card, BackgroundTransparency = panelAlpha(),
BorderSizePixel = 0,
Position = UDim2.new(0, sidebarW + cgap, 0, cgap),
Size = UDim2.new(1, -(sidebarW + cgap * 2), 1, -cgap * 2),
Parent = body, ClipsDescendants = true, Create.corner(theme.Radius.lg),
})

local contentStroke = Create.stroke(theme.Colors.border, 1, theme.modeVal(theme, theme.Stroke.panel))
contentStroke.Parent = contentPanel



local WHITE = Color3.new(1, 1, 1)
local function insetStops() return { { 0, theme.fx(theme).inset }, { INSET_BAND, WHITE }, { 1, WHITE } } end
local function colorSeq(stops)
local kps = {}
for i, st in ipairs(stops) do kps[i] = ColorSequenceKeypoint.new(st[1], st[2]) end
return ColorSequence.new(kps)
end
local insetShade
if not theme.Lite then
insetShade = Create.gradient({ rotation = 90, stops = insetStops() })
insetShade.Name = "PanelInset"; insetShade.Parent = contentPanel
end
local contentScroll = Create("ScrollingFrame", {
Name = "Content",
BackgroundTransparency = 1,
BorderSizePixel = 0,
Position = UDim2.new(0, 0, 0, 0),
Size = UDim2.new(1, 0, 1, 0),
AutomaticCanvasSize = Enum.AutomaticSize.None,
CanvasSize = UDim2.new(0, 0, 0, 0),
ClipsDescendants = true,
Parent = contentPanel,
})
Recipes.scrollbar(contentScroll, theme)




local function makeFade(name, anchorY, stops)
return Create("Frame", {
Name = name, BackgroundColor3 = theme.Colors.card, BackgroundTransparency = panelAlpha(),
BorderSizePixel = 0, AnchorPoint = Vector2.new(0, anchorY),
Position = UDim2.new(0, 0, anchorY, 0), Size = UDim2.new(1, 0, 0, SCROLL_FADE_H),
ZIndex = 2, Active = false, Visible = false, Parent = contentPanel,
Create.shade({ rotation = 90, stops = stops }),
})
end

local fadeTop, fadeBottom
if not theme.Lite then
fadeTop = makeFade("ScrollFadeTop", 0, { { 0, 0 }, { 1, 1 } })
fadeBottom = makeFade("ScrollFadeBottom", 1, { { 0, 1 }, { 1, 0 } })
end



local function updateFades()
if not fadeTop then return end
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

if fadeTop then
for _, prop in ipairs({ "CanvasPosition", "CanvasSize", "AbsoluteWindowSize" }) do
maid:Give(contentScroll:GetPropertyChangedSignal(prop):Connect(function() Safe.mutate(updateFades) end))
end
updateFades()
end

local function paintPanel()
local a = panelAlpha()
contentPanel.BackgroundColor3 = theme.Colors.card
contentPanel.BackgroundTransparency = a
contentStroke.Color = theme.Colors.border
contentStroke.Transparency = theme.modeVal(theme, theme.Stroke.panel)
if insetShade then insetShade.Color = colorSeq(insetStops()) end
if fadeTop then
fadeTop.BackgroundColor3 = theme.Colors.card; fadeTop.BackgroundTransparency = a
fadeBottom.BackgroundColor3 = theme.Colors.card; fadeBottom.BackgroundTransparency = a
end
end






local hitW = Device.IsTouch() and S.touchHit or SIDEBAR_HANDLE_W
local function handleX(wpx) return wpx + cgap / 2 - hitW / 2 end
local sidebarHandle = Create("ImageButton", {
Name = "SidebarHandle", AutoButtonColor = false, BackgroundTransparency = 1,
ZIndex = 6, Size = UDim2.new(0, hitW, 1, 0), Position = UDim2.new(0, handleX(sidebarW), 0, 0), Parent = body,
})


local sidebarGrip = Create("Frame", {
Name = "SidebarGrip", BackgroundColor3 = theme.Colors.border, BorderSizePixel = 0,
BackgroundTransparency = Device.IsTouch() and GRIP_ALPHA.touch or GRIP_ALPHA.rest,
AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
Size = UDim2.new(0, S.grip.w, 0, S.grip.h), Active = false, Parent = sidebarHandle,
Create.corner(theme.Radius.xs),
})
local function applySidebarWidth(wpx)
sidebarW = math.max(SIDEBAR_MIN, math.min(SIDEBAR_MAX, wpx))
sidebar.Size = UDim2.new(0, sidebarW, 1, -SIDEBAR_TOP)
sidebarEmpty.Frame.Size = UDim2.new(0, sidebarW, 1, -SIDEBAR_TOP)
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
onEnd = function() sbDrag = false; paintGrip(); if flushAdapt then flushAdapt() end end,
}, maid)



local IND = S.indicator



local activeIndicator = Create("Frame", {
Name = "ActiveIndicator", BackgroundColor3 = theme.Colors.primary, BorderSizePixel = 0,
AnchorPoint = Vector2.new(0, 0.5),
Size = UDim2.new(0, IND.w, 0, IND.h), Position = UDim2.new(0, 2, 0, 0), Visible = false, ZIndex = 5,
Parent = body, Create.corner(IND.radius),
})



local halo = Create("Frame", {
Name = "Halo", BackgroundColor3 = theme.Colors.primary, BackgroundTransparency = IND.haloAlpha,
BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
Size = UDim2.new(0, IND.haloW, 0, IND.haloH), Active = false, Parent = activeIndicator,
Create.corner(theme.Radius.sm),
})
local activeTabButton



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



local sTop = (sidebar.AbsolutePosition and sp and (sidebar.AbsolutePosition.Y - sp.Y)) or 0
local sBot = sTop + ((sidebar.AbsoluteSize and sidebar.AbsoluteSize.Y) or 0)
local center = by + bh / 2
if sBot > sTop and (center < sTop or center > sBot) then showIndicator(false); return end
local travelled = indShown
showIndicator(true)
local target = UDim2.new(0, 2, 0, center)
if instant or not travelled then activeIndicator.Position = target; return end


local dur = clamp(theme.Motion.base + math.abs(center - activeIndicator.Position.Y.Offset) / IND_TRAVEL_PX,
theme.Motion.base, theme.Motion.slow)
Animate.chain({
{ activeIndicator, "fast", { Size = UDim2.new(0, IND.w, 0, IND.stretch) }, Animate.EASING.smooth },
{ activeIndicator, dur, { Position = target }, Animate.EASING.pop },
})
Animate.to(activeIndicator, "release", { Size = UDim2.new(0, IND.w, 0, IND.h) }, nil, nil, theme.Motion.fast)
end







local function reanchorIndicator() if activeTabButton then Safe.mutate(function() moveIndicatorTo(activeTabButton, true) end) end end
maid:Give(sidebar:GetPropertyChangedSignal("CanvasPosition"):Connect(reanchorIndicator))
maid:Give(sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(reanchorIndicator))
maid:Give(body:GetPropertyChangedSignal("AbsoluteSize"):Connect(reanchorIndicator))
do
local sbLayout = sidebar:FindFirstChildOfClass("UIListLayout")
if sbLayout then maid:Give(sbLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(reanchorIndicator)) end
end

Overlay.get(gui, mountCtx)

local api = { Gui = gui, Main = main, ContentScroll = contentScroll, Overlay = Overlay.get(gui, mountCtx), Config = cfg, Maid = maid }

local tabEntries = {}
local groups = {}
local searchIndex, searchMark = {}, 0
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
tabOpts.Transition = tabTransition

tabOpts.RegisterSearchable = function(frame, text)
local rec = { entry = entry, frame = frame, text = (text or ""):lower() }
searchIndex[#searchIndex + 1] = rec
searchMark = grown(searchIndex, searchMark, searchFrame)
return function() removeFrom(searchIndex, rec) end
end
tabOpts.OnActivate = function(selectedTab)
Overlay.closeAll()
local newIndex = selectedIndex
for i, t in ipairs(tabs) do if t == selectedTab then newIndex = i break end end

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
prune(searchIndex, searchFrame)

for _, s in ipairs(searchIndex) do
s.frame.Visible = (query == "" or (s.text ~= "" and s.text:find(query, 1, true) ~= nil))
end

local anyTab = false
for _, e in ipairs(tabEntries) do
local match = (query == "" or e.name:lower():find(query, 1, true) ~= nil)
if not match then
for _, s in ipairs(searchIndex) do
if s.entry == e and s.frame.Visible then match = true break end
end
end
e.button.Visible = match
if match then anyTab = true end
end

for _, g in ipairs(groups) do
local anyVisible = false
for _, e in ipairs(g._entries) do if e.button.Visible then anyVisible = true break end end
g._header.Visible = anyVisible
end


sidebarEmpty.SetVisible(#tabEntries > 0 and not anyTab)
if activeTabButton then moveIndicatorTo(activeTabButton) end
end

maid:Give(searchInput:GetPropertyChangedSignal("Text"):Connect(function()

Safe.mutate(function() api:SearchTabs(searchInput.Text) end)
end))

function api:IsVisible() return visible end




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








local hideGen = 0







local function offsetY(pos, dy) return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + dy) end
local restingPos
local function shadowAt(pos) return offsetY(pos, theme.Effect.window.offsetY) end




local cover = Create("Frame", { Name = "RevealCover", BackgroundColor3 = theme.Colors.background,
BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false, ZIndex = 1000,
Size = UDim2.new(1, 0, 1, 0), Parent = main, Create.corner(theme.Radius.window) })

local function materialise(on, dur, opts)
opts = opts or {}


local style = opts.style or (on and Animate.EASING.enter or Animate.EASING.exit)
local dir = opts.dir or (on and Animate.DIR.Out or Animate.DIR.In)

local fade = on and "base" or "fast"
if mainStroke then Animate.to(mainStroke, fade, { Transparency = on and strokeRest() or 1 }) end
if shadow then Animate.to(shadow, fade, { ImageTransparency = on and shadowAlpha(lifted) or 1 }) end
if opts.bg ~= nil then Animate.to(main, dur, { BackgroundTransparency = opts.bg }, Animate.EASING.exit, dir) end

cover.BackgroundColor3 = theme.Colors.background
cover.Visible = true
cover.BackgroundTransparency = on and 0 or 1
Animate.toThen(cover, dur, { BackgroundTransparency = on and 1 or 0 }, function()
if on then cover.Visible = false end
end, style, dir)
local goal = opts.to or main.Position
if shadow then Animate.to(shadow, dur, { Position = shadowAt(goal) }, style, dir) end

Animate.toThen(main, dur, { Position = goal }, opts.onDone, style, dir)
end

function api:Show()
if closed then return end
visible = true
hideGen = hideGen + 1
local gen = hideGen
Safe.mutate(function()
if gen ~= hideGen then return end
main.Visible = true


local rest = restingPos or main.Position
restingPos = nil
main.Position = offsetY(rest, theme.Motion.hideDrift)
syncShadow()
materialise(true, "release", { to = rest })




if fabPulse then fabPulse.stop() end
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
restingPos = restPos

local drift = (not dragging) and driftGoal(restPos) or nil
materialise(false, "exit", {
to = drift or restPos,
onDone = function()



if drift and main.Position == drift then main.Position = restingPos or restPos; syncShadow() end
if gen ~= hideGen then return end
restingPos = nil
main.Visible = false
if showFab then showFab() end
end,
})
end)
end
function api:Toggle() if closed then return end; if visible then api:Hide() else api:Show() end end

local shownTitle, shownSubtitle = config.Title or "EzUI", config.Subtitle
function api:SetTitle(s)
if s == shownTitle then return end
Safe.mutate(function() titleLabel.Text = s; shownTitle = s end)
end
function api:SetSubtitle(s)
if s == shownSubtitle then return end
Safe.mutate(function()
local sub = titleBar:FindFirstChild("Subtitle")
if sub then sub.Text = s; shownSubtitle = s end
end)
end
function api:SetImage(v)

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


local function accentReg(fn) return themer.register(fn) end
function api:Dialog(o) o = o or {}; o.Theme = theme; o.Window = api; o.AccentReg = accentReg; return DialogMod.open(o) end
function api:Notify(o) o = o or {}; o.Theme = theme; o.AccentReg = accentReg; return Notif.show(o) end
function api:SetNotificationsEnabled(b) Notif.setEnabled(b); return b end

function api:SetTransparency(n)
transp = n
Safe.mutate(function()
Acrylic.reskin(main, theme, { base = theme.Colors.background, transparency = n })
paintShadow()
paintPanel()
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




if type(n) == "number" and n == n and n > 0 then
Overlay.setScale(n)
if Notif.setScale then Notif.setScale(n) end
end

if userMoved and api.AdaptToViewport then api:AdaptToViewport() end
syncShadow()
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
api:ShowSuccess({ Title = theme.Strings.Reset, Message = theme.Strings.ResetDone })
end
if o.Confirm == false then
doReset()
else
local words = theme.Strings
api:Dialog({ Title = words.ResetTitle, Message = words.ResetMessage, Buttons = {
{ Text = words.Cancel, Variant = "secondary" },
{ Text = words.Reset, Variant = "destructive", Callback = doReset },
} })
end
end

function api:GetThemer() return themer end
function api:LockAll()
prune(lockables, controlFrame)
for _, c in ipairs(lockables) do if c.SetLocked then c.SetLocked(true) end end
end
function api:UnlockAll()
prune(lockables, controlFrame)
for _, c in ipairs(lockables) do if c.SetLocked then c.SetLocked(false) end end
end

local tagX = 70
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
local shown = o.Text or ""
return {
SetText = function(s)
if s == shown then return end
Safe.mutate(function() txt.Text = s; shown = s end)
end,
Destroy = function() unreg(); pill:Destroy() end,
}
end
local function fgForColor(c)
local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
return (lum > 0.55) and Color3.fromRGB(24, 24, 27) or Color3.fromRGB(250, 250, 250)
end
function api:SetAccent(nameOrColor)
if type(nameOrColor) ~= "string" then
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



themer.register(function(reason)
Acrylic.reskin(main, theme, { base = theme.Colors.background, edge = true })
paintShadow()
titleLabel.TextColor3 = theme.Colors.foreground
if titleImg and imageAdaptive then titleImg.ImageColor3 = theme.Colors.foreground end
if applyTitleImage and imageIsModal and reason ~= "accent" then applyTitleImage() end
local sub = titleBar:FindFirstChild("Subtitle")
if sub then sub.TextColor3 = theme.Colors.mutedForeground end
closeIcon.reskin(); minIcon.reskin()
if grip and gripRest then Icons.apply(grip, "move-diagonal-2", gripRest()) end
searchBox.BackgroundColor3 = theme.Colors.input
searchStroke.Color = searchStrokeColor()

searchStroke.Transparency = searchFocused and theme.Stroke.control or searchRestAlpha()
searchHover.reskin()
local si = searchBox:FindFirstChild("SearchInput")
if si then si.TextColor3 = theme.Colors.foreground; si.PlaceholderColor3 = theme.Colors.mutedForeground end
paintPanel()
Recipes.scrollbar(sidebar, theme)
Recipes.scrollbar(contentScroll, theme)
sidebarEmpty.reskin()
activeIndicator.BackgroundColor3 = theme.Colors.primary
halo.BackgroundColor3 = theme.Colors.primary
sidebarGrip.BackgroundColor3 = theme.Colors.border
for _, g in ipairs(groups) do g._header.TextColor3 = theme.Colors.mutedForeground end
end)

fabEnabled = config.FloatingToggle ~= false
local fabOpts = (type(config.FloatingToggle) == "table") and config.FloatingToggle or {}
autoHide = fabOpts.AutoHide ~= false
local function ensureFab()
if fab then return fab end
if fabMaid then fabMaid:DoCleanup() end
fabMaid = Maid.new(); maid:Give(fabMaid)
local kind = fabOpts.Type or "simple"

local fabImageModal = type(fabOpts.Image) == "table"
local hasImage = fabImageModal or (type(fabOpts.Image) == "string" and fabOpts.Image ~= "")


local fabAdaptive = fabOpts.Adaptive == true and not fabImageModal
local fabImg




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


local function placeholderColor()
return (kind == "circle") and theme.Colors.primaryForeground or theme.Colors.primary
end


local function makeFabImg(radius)
if hasImage then
return Create("ImageLabel", { Name = "Img", BackgroundTransparency = 1,

ScaleType = (fabAdaptive or fabImageModal) and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0), Image = "", Parent = fab, Create.corner(radius) })
end
local img = Create("ImageLabel", { Name = "Img", BackgroundTransparency = 1, Size = UDim2.new(0, 24, 0, 24),
Position = UDim2.new(0.5, -12, 0.5, -12), Parent = fab })
Icons.apply(img, "gamepad-2", placeholderColor())
return img
end


local chev, dockedLeft = nil, true
local F = S.fab
fab = Create("ImageButton", { Name = "FloatingToggle", AutoButtonColor = false, BackgroundTransparency = 0,
Visible = false, Size = UDim2.new(0, F.size, 0, F.size), Position = UDim2.new(0, F.margin, 1, -(F.size + F.margin)),
ZIndex = Overlay.Z.fab, Parent = Overlay.get(gui, mountCtx) })
fab:SetAttribute("FabType", kind)
fabScale = Create("UIScale", { Scale = 1, Parent = fab })
local fabRadius
if kind == "square" then
fabRadius = theme.Radius.lg
fab.BackgroundColor3 = theme.Colors.surface
Create("UICorner", { CornerRadius = UDim.new(0, theme.Radius.lg), Parent = fab })
fabImg = makeFabImg(theme.Radius.lg); applyFabImage(fabImg)
elseif kind == "circle" then
fabRadius = F.size / 2
fab.BackgroundColor3 = theme.Colors.primary
Create("UICorner", { CornerRadius = UDim.new(0, F.size / 2), Parent = fab })
fabImg = makeFabImg(F.size / 2); applyFabImage(fabImg)
else
fabRadius = F.radius
fab.Size = UDim2.new(0, F.simple, 0, F.simple)
fab.Position = UDim2.new(0, -F.peek, 0.5, -F.simple / 2)
fab.BackgroundColor3 = theme.Colors.surface
Create("UICorner", { CornerRadius = UDim.new(0, F.radius), Parent = fab })
Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = fab })


chev = Create("ImageLabel", { Name = "Chevron", BackgroundTransparency = 1, Size = UDim2.new(0, 24, 0, 24),
AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Parent = fab })
Icons.apply(chev, "chevron-right", theme.Colors.primary)
end

if fabOpts.Size then
if type(fabOpts.Size) == "table" and type(fabOpts.Size.Width) == "number" then
fab.Size = UDim2.new(0, fabOpts.Size.Width, 0, fabOpts.Size.Height or 44)
else fab.Size = fabOpts.Size end
end

local defaultAnchor = (kind == "simple") and "MidLeft" or "TopLeft"
local pos = fabOpts.Position
if type(pos) == "string" then
if not FAB_ANCHORS[pos] then pos = defaultAnchor end
fab.Position = fabAnchorPos(pos, kind, fab.Size.X.Offset, fab.Size.Y.Offset, F)
elseif pos ~= nil then
fab.Position = pos
else
fab.Position = fabAnchorPos(defaultAnchor, kind, fab.Size.X.Offset, fab.Size.Y.Offset, F)
end
fabFullSize = fab.Size
dockedLeft = (fab.Position.X.Scale or 0) < 0.5
if chev then chev.Rotation = dockedLeft and 0 or 180 end






local overlayRoot = Overlay.get(gui, mountCtx)
local fabShadow = Effects.shadow(overlayRoot, theme, { name = "FabShadow", level = "popover", zIndex = Overlay.Z.fab - 2 })
local fabGlow = Effects.glow(overlayRoot, theme, theme.Colors.primary, "control", Overlay.Z.fab - 1, "FabGlow")
if fabShadow then fabMaid:Give(fabShadow) end
if fabGlow then fabMaid:Give(fabGlow) end
local fabHover, peeked = false, false



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


local function fadeLayer(layer, dur, goal)
if layer and layer.ImageTransparency ~= goal then Animate.to(layer, dur, { ImageTransparency = goal }) end
end
fabFade = function(on)
local dur = on and "slow" or "fast"
fadeLayer(fabShadow, dur, on and theme.fx(theme).shadow or 1)
fadeLayer(fabGlow, dur, on and glowRest() or 1)
end
mirrorFab(); paintFabLayers()








local haloStroke, haloLoop
if fabOpts.Pulse == true then
local fabHalo = Create("Frame", {
Name = "Halo", BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
Size = UDim2.new(1, HALO_OUT, 1, HALO_OUT), Parent = fab,
Create.corner(fabRadius + HALO_OUT / 2),
})
haloStroke = Create.stroke(theme.Colors.primary, theme.Stroke.focusThickness, theme.Stroke.pulse.high)
haloStroke.Parent = fabHalo
end




local function haloRest() return fabHover and theme.Stroke.pulse.low or theme.Stroke.pulse.high end
local function stopPulse()
if haloLoop then haloLoop.Cancel(); haloLoop = nil end
if not haloStroke then return end

local goal = haloRest()
if haloStroke.Transparency ~= goal then Animate.to(haloStroke, "hover", { Transparency = goal }) end
end
fabPulse = {
start = function()
if not haloStroke then return end
if haloLoop then haloLoop.Cancel(); haloLoop = nil end
haloStroke.Transparency = theme.Stroke.pulse.high
if not Animate.isEnabled() then return end
haloLoop = Animate.pulse(haloStroke, "pulse", { Transparency = theme.Stroke.pulse.low },
Enum.EasingStyle.Sine, HALO_CYCLES)
end,
stop = stopPulse,
}
fabMaid:Give(function() if haloLoop then haloLoop.Cancel(); haloLoop = nil end end)



fabSnap = function()
if kind ~= "simple" then return end
local vp = Overlay.get(gui, mountCtx).AbsoluteSize
if not vp or vp.X <= 0 then return end
local w2 = (fabFullSize and fabFullSize.X.Offset) or F.simple
local cx = fab.Position.X.Scale * vp.X + fab.Position.X.Offset + w2 / 2
local ys, yo = fab.Position.Y.Scale, fab.Position.Y.Offset
dockedLeft = cx < vp.X / 2
peeked = false
if chev then Animate.rotateTo(chev, "base", dockedLeft and 0 or 180) end

moveFab(UDim2.new(0, dockedLeft and -F.peek or (vp.X - w2 + F.peek), ys, yo), "snap", Animate.EASING.snap)
end




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



Drag.bind(fab, {
onBegin = function() moved = false; peeked = false; fabStart = fab.Position end,
onChange = function(dx, dy)
if math.abs(dx) > S.dragThreshold or math.abs(dy) > S.dragThreshold then moved = true end
fab.Position = UDim2.new(fabStart.X.Scale, fabStart.X.Offset + dx, fabStart.Y.Scale, fabStart.Y.Offset + dy)
mirrorFab()
end,


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
else
fab.BackgroundColor3 = theme.Colors.surface
local st = fab:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
if chev then Icons.apply(chev, "chevron-right", theme.Colors.primary) end
end
if fabImg and not hasImage then Icons.apply(fabImg, "gamepad-2", placeholderColor()) end
if fabImg and fabAdaptive and hasImage then fabImg.ImageColor3 = theme.Colors.foreground end

if fabImg and fabImageModal and reason ~= "accent" then applyFabImage(fabImg) end
if haloStroke then haloStroke.Color = theme.Colors.primary end
paintFabLayers()
end))
fabMaid:Give(fab.MouseEnter:Connect(function()
fabHover = true
Animate.to(fabScale, "fast", { Scale = theme.Motion.hoverScale })
fadeLayer(fabGlow, "fast", glowRest())
stopPulse()
hoverPeek(true)
end))
fabMaid:Give(fab.MouseLeave:Connect(function()
fabHover = false
Animate.to(fabScale, "fast", { Scale = 1 })
fadeLayer(fabGlow, "fast", glowRest())
stopPulse()
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
if fabFade then fabFade(true) end
if fabPulse then fabPulse.start() end
Animate.toThen(fabScale, "slow", { Scale = 1 }, function()
if fabSnap and fab:GetAttribute("FabType") == "simple" then fabSnap() end
end, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end)
end
hideFab = function()
Safe.mutate(function()
if not fab or not fab.Visible then return end
if fabPulse then fabPulse.stop() end
if fabFade then fabFade(false) end
Animate.toThen(fabScale, "fast", { Scale = S.fab.popFrom }, function()
fab.Visible = false; fabScale.Scale = 1
end)
end)
end

function api:SetFloatingToggle(opts)
local wasHidden = not visible
if fab then fab:Destroy(); fab = nil end


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
onMinimizePressed = function() api:Minimize() end


local dragStartPos
Drag.bind(titleBar, {
onBegin = function() dragging = true; dragStartPos = main.Position; Overlay.closeAll(); grabbed(true) end,
onChange = function(dx, dy)






local vp = viewportSize()
local s = shownScale()
local sw, sh, sbar = width * s, height * s, titleH * s
local baseX, baseY = dragStartPos.X.Scale * vp.X, dragStartPos.Y.Scale * vp.Y
local cx = clamp(baseX + dragStartPos.X.Offset + dx, S.dragKeep - sw / 2, vp.X - S.dragKeep + sw / 2)
local cy = clamp(baseY + dragStartPos.Y.Offset + dy, sh / 2, vp.Y - sbar + sh / 2)
main.Position = UDim2.new(dragStartPos.X.Scale, cx - baseX, dragStartPos.Y.Scale, cy - baseY)
userMoved = true
syncShadow()
end,
onEnd = function() dragging = false; grabbed(false); flushAdapt() end,
}, maid)










grip = Create("ImageLabel", {
Name = "ResizeGrip", BackgroundTransparency = 1,
Visible = not fixedSize,
AnchorPoint = Vector2.new(1, 1), Size = UDim2.new(0, S.resizeGrip, 0, S.resizeGrip),
Position = UDim2.new(1, -S.resizeGripInset, 1, -S.resizeGripInset),
ZIndex = 50, Parent = main,
})



gripRest = function()
return theme.Colors[Device.IsTouch() and theme.Icon.structuralActive or theme.Icon.structural]
end
Icons.apply(grip, "move-diagonal-2", gripRest())





local gripReach = 2 * (S.resizeGripInset + S.resizeGrip)
local gripHitPx = math.max(gripReach, Device.IsTouch() and S.touchHit or 0)
local resizeHit = Create("ImageButton", {
Name = "ResizeHit", AutoButtonColor = false, BackgroundTransparency = 1,
Visible = not fixedSize, Active = not fixedSize,
AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, gripHitPx, 0, gripHitPx), Position = UDim2.new(1, 0, 1, 0),
ZIndex = 51, Parent = main,
})
maid:Give(resizeHit.MouseEnter:Connect(function() Icons.apply(grip, "move-diagonal-2", theme.Colors.foreground) end))
maid:Give(resizeHit.MouseLeave:Connect(function() Icons.apply(grip, "move-diagonal-2", gripRest()) end))
local resizing = false
local rSize, rPos
Drag.bind(resizeHit, {
onBegin = function()
resizing = true; rSize = { X = width, Y = height }; rPos = main.Position
Overlay.closeAll(); grabbed(true)
end,
onChange = function(dx, dy)

local s = shownScale()
width = math.max(MIN_W, rSize.X + dx / s)
height = math.max(MIN_H, rSize.Y + dy / s)
local vp = viewportSize()
width = math.min(width, vp.X / s); height = math.min(height, vp.Y / s)
main.Size = UDim2.new(0, width, 0, height)



main.Position = UDim2.new(rPos.X.Scale, rPos.X.Offset + (width - rSize.X) * s / 2,
rPos.Y.Scale, rPos.Y.Offset + (height - rSize.Y) * s / 2)
widthFrac = width / vp.X
heightFrac = height / vp.Y
userW, userH = width, height
userMoved = true
userResized = true
syncShadow()
end,
onEnd = function() resizing = false; grabbed(false); flushAdapt() end,
}, maid)


maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
if not gameProcessed and input.KeyCode == toggleKey then api:Toggle() end
end))

onClosePressed = function()
if config.ConfirmClose == false then api:Close(); return end


local words = theme.Strings
api:Dialog({ Title = words.CloseTitle, Message = words.CloseMessage,
Buttons = {
{ Text = words.Cancel, Variant = "secondary" },
{ Text = words.Close, Variant = "destructive", Callback = function() api:Close() end },
} })
end


function api:AdaptToViewport()

if dragging or resizing or sbDrag then adaptPending = true; return end
adaptPending = false
local vp = viewportSize()
local s = shownScale()
if userResized then

width = math.max(MIN_W, math.min(userW or width, math.floor(vp.X * VP_MARGIN / s)))
height = math.max(MIN_H, math.min(userH or height, math.floor(vp.Y * VP_MARGIN / s)))
else
width, height = computeSize()
end
main.Size = UDim2.new(0, width, 0, height)


local folding = restingPos ~= nil
local place
if userMoved then



local at = restingPos or main.Position
local sw, sh = width * s, height * s
local cx = at.X.Scale * vp.X + at.X.Offset
local cy = at.Y.Scale * vp.Y + at.Y.Offset
local left = clamp(cx - sw / 2, 0, vp.X - sw)
local top = clamp(cy - sh / 2, 0, vp.Y - sh)
place = UDim2.new(0, left + sw / 2, 0, top + sh / 2)
else
place = UDim2.new(0.5, 0, 0.5, 0)
end
if folding then restingPos = place else main.Position = place; syncShadow() end
end
flushAdapt = function() if adaptPending then api:AdaptToViewport() end end
api:AdaptToViewport()
do
local cam = workspace and workspace.CurrentCamera
if cam and cam.GetPropertyChangedSignal then
maid:Give(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() Safe.mutate(function() api:AdaptToViewport() end) end))
end
end


if fabEnabled then
ensureFab()
if not autoHide or startHidden then showFab() end
end
function api:SetFloatingToggleVisible(b) if b then showFab() else hideFab() end end








local function entranceCascade()
if Device.IsTouch() or not Animate.isEnabled() then return end
local stagger, cascade = theme.Motion.stagger, theme.Motion.cascade
local function slideIn(label, beat)
if not label then return end
local rest = label.Position
label.TextTransparency = 1
label.Position = UDim2.new(rest.X.Scale, rest.X.Offset - cascade.x, rest.Y.Scale, rest.Y.Offset)
Animate.to(label, "enter", { TextTransparency = 0, Position = rest },
Animate.EASING.enter, Animate.DIR.Out, beat * stagger)
end
slideIn(titleLabel, 1); slideIn(subtitleLabel, 1)
local rest = contentPanel.Position
contentPanel.BackgroundTransparency = 1
contentPanel.Position = UDim2.new(rest.X.Scale, rest.X.Offset, rest.Y.Scale, rest.Y.Offset + cascade.y)
Animate.to(contentPanel, "enter", { BackgroundTransparency = panelAlpha(), Position = rest },
Animate.EASING.enter, Animate.DIR.Out, 2 * stagger)
end

if startHidden then



visible = false
main.Visible = false
winScale.Scale = userScale
main.BackgroundTransparency = transp
if mainStroke then mainStroke.Transparency = strokeRest() end
if shadowScale then shadowScale.Scale = userScale end
paintShadow()
else



local rest = main.Position
main.BackgroundTransparency = transp
main.Position = offsetY(rest, theme.Motion.hideDrift)
if mainStroke then mainStroke.Transparency = 1 end
if shadow then shadow.ImageTransparency = 1 end
syncShadow()
materialise(true, "enter", { to = rest })
entranceCascade()
end

maid:Give(gui)

function api:SetCloseCallback(fn) closeCallback = fn end
function api:Close()
if closed then return end
closed = true
visible = false
hideGen = hideGen + 1


local rest = restingPos or main.Position
materialise(false, "base", { to = offsetY(rest, theme.Motion.hideDrift), onDone = function()
if config.OnClose then pcall(config.OnClose) end
if closeCallback then pcall(closeCallback) end
if cfg then pcall(function() cfg:Save() end) end
Overlay.closeAll()
if Notif then Notif.clearAll() end
maid:DoCleanup()
gui:Destroy()
Overlay.release(gui)
end })
end
function api.Destroy() api:Close() end

return api
end

return Window

end


EmbeddedModules["core/icons"] = function()


local DATA = {
["home"] = { id = 16898613509, w = 48, h = 48, x = 820, y = 147 },
["settings"] = { id = 16898613777, w = 48, h = 48, x = 771, y = 257 },
["settings-2"] = { id = 16898613777, w = 48, h = 48, x = 0, y = 771 },
["shapes"] = { id = 16898613777, w = 48, h = 48, x = 257, y = 771 },
["target"] = { id = 16898613869, w = 48, h = 48, x = 514, y = 771 },
["image"] = { id = 16898613509, w = 48, h = 48, x = 306, y = 918 },
["table"] = { id = 16898613777, w = 48, h = 48, x = 820, y = 955 },
["columns-2"] = { id = 16898613044, w = 48, h = 48, x = 820, y = 661 },
["rows-3"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 661 },
["message-square"] = { id = 16898613613, w = 48, h = 48, x = 355, y = 820 },
["chevron-right"] = { id = 16898612819, w = 48, h = 48, x = 869, y = 759 },
["chevron-down"] = { id = 16898612819, w = 48, h = 48, x = 196, y = 918 },
["chevron-left"] = { id = 16898612819, w = 48, h = 48, x = 404, y = 967 },
["chevron-up"] = { id = 16898612819, w = 48, h = 48, x = 710, y = 918 },
["play"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 257 },
["pause"] = { id = 16898613699, w = 48, h = 48, x = 0, y = 771 },
["x"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 906 },
["search"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 857 },
["user"] = { id = 16898613869, w = 48, h = 48, x = 661, y = 869 },
["users"] = { id = 16898613869, w = 48, h = 48, x = 967, y = 98 },
["check"] = { id = 16898612819, w = 48, h = 48, x = 710, y = 869 },
["plus"] = { id = 16898613699, w = 48, h = 48, x = 257, y = 918 },
["minus"] = { id = 16898613613, w = 48, h = 48, x = 771, y = 196 },
["copy"] = { id = 16898613044, w = 48, h = 48, x = 918, y = 612 },
["trash-2"] = { id = 16898613869, w = 48, h = 48, x = 257, y = 918 },
["eye"] = { id = 16898613353, w = 48, h = 48, x = 771, y = 563 },
["eye-off"] = { id = 16898613353, w = 48, h = 48, x = 820, y = 514 },
["lock"] = { id = 16898613509, w = 48, h = 48, x = 918, y = 857 },
["unlock"] = { id = 16898613869, w = 48, h = 48, x = 771, y = 710 },
["zap"] = { id = 16898613869, w = 48, h = 48, x = 918, y = 906 },
["swords"] = { id = 16898613777, w = 48, h = 48, x = 967, y = 759 },
["crosshair"] = { id = 16898613044, w = 48, h = 48, x = 453, y = 869 },
["map-pin"] = { id = 16898613613, w = 48, h = 48, x = 820, y = 257 },
["bell"] = { id = 16898612819, w = 48, h = 48, x = 820, y = 257 },
["star"] = { id = 16898613777, w = 48, h = 48, x = 967, y = 147 },
["heart"] = { id = 16898613509, w = 48, h = 48, x = 661, y = 771 },
["shield"] = { id = 16898613777, w = 48, h = 48, x = 869, y = 0 },
["gamepad-2"] = { id = 16898613353, w = 48, h = 48, x = 710, y = 967 },
["sliders-horizontal"] = { id = 16898613777, w = 48, h = 48, x = 820, y = 355 },
["toggle-left"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 49 },
["palette"] = { id = 16898613613, w = 48, h = 48, x = 453, y = 918 },
["info"] = { id = 16898613509, w = 48, h = 48, x = 612, y = 869 },
["circle-alert"] = { id = 16898612819, w = 48, h = 48, x = 918, y = 808 },
["circle-check"] = { id = 16898612819, w = 48, h = 48, x = 869, y = 955 },
["triangle-alert"] = { id = 16898613869, w = 48, h = 48, x = 967, y = 0 },
["loader"] = { id = 16898613509, w = 48, h = 48, x = 710, y = 967 },
["refresh-cw"] = { id = 16898613699, w = 48, h = 48, x = 404, y = 869 },
["power"] = { id = 16898613699, w = 48, h = 48, x = 820, y = 147 },
["activity"] = { id = 16898612629, w = 48, h = 48, x = 514, y = 771 },
["alarm-clock"] = { id = 16898612629, w = 48, h = 48, x = 257, y = 820 },
["align-center"] = { id = 16898612629, w = 48, h = 48, x = 0, y = 869 },
["align-justify"] = { id = 16898612629, w = 48, h = 48, x = 563, y = 820 },
["align-left"] = { id = 16898612629, w = 48, h = 48, x = 514, y = 869 },
["align-right"] = { id = 16898612629, w = 48, h = 48, x = 918, y = 0 },
["anchor"] = { id = 16898612629, w = 48, h = 48, x = 306, y = 869 },
["aperture"] = { id = 16898612629, w = 48, h = 48, x = 771, y = 661 },
["archive"] = { id = 16898612629, w = 48, h = 48, x = 918, y = 49 },
["arrow-down"] = { id = 16898612629, w = 48, h = 48, x = 967, y = 49 },
["arrow-left"] = { id = 16898612629, w = 48, h = 48, x = 98, y = 918 },
["arrow-right"] = { id = 16898612629, w = 48, h = 48, x = 453, y = 820 },
["arrow-up"] = { id = 16898612629, w = 48, h = 48, x = 967, y = 355 },
["arrow-up-right"] = { id = 16898612629, w = 48, h = 48, x = 918, y = 147 },
["award"] = { id = 16898612629, w = 48, h = 48, x = 918, y = 661 },
["badge"] = { id = 16898612629, w = 48, h = 48, x = 661, y = 967 },
["ban"] = { id = 16898612629, w = 48, h = 48, x = 196, y = 967 },
["battery"] = { id = 16898612629, w = 48, h = 48, x = 967, y = 857 },
["bike"] = { id = 16898612819, w = 48, h = 48, x = 771, y = 563 },
["binary"] = { id = 16898612819, w = 48, h = 48, x = 563, y = 771 },
["bluetooth"] = { id = 16898612819, w = 48, h = 48, x = 771, y = 355 },
["bold"] = { id = 16898612819, w = 48, h = 48, x = 355, y = 771 },
["book"] = { id = 16898612819, w = 48, h = 48, x = 820, y = 612 },
["book-open"] = { id = 16898612819, w = 48, h = 48, x = 820, y = 355 },
["bookmark"] = { id = 16898612819, w = 48, h = 48, x = 514, y = 918 },
["box"] = { id = 16898612819, w = 48, h = 48, x = 771, y = 196 },
["briefcase"] = { id = 16898612819, w = 48, h = 48, x = 771, y = 453 },
["brush"] = { id = 16898612819, w = 48, h = 48, x = 404, y = 820 },
["bug"] = { id = 16898612819, w = 48, h = 48, x = 257, y = 967 },
["building"] = { id = 16898612819, w = 48, h = 48, x = 918, y = 563 },
["calculator"] = { id = 16898612819, w = 48, h = 48, x = 563, y = 918 },
["calendar"] = { id = 16898612819, w = 48, h = 48, x = 355, y = 918 },
["camera"] = { id = 16898612819, w = 48, h = 48, x = 967, y = 563 },
["cast"] = { id = 16898612819, w = 48, h = 48, x = 869, y = 453 },
["check-check"] = { id = 16898612819, w = 48, h = 48, x = 967, y = 612 },
["chevrons-down"] = { id = 16898612819, w = 48, h = 48, x = 967, y = 196 },
["chevrons-up"] = { id = 16898612819, w = 48, h = 48, x = 869, y = 808 },
["chevrons-left"] = { id = 16898612819, w = 48, h = 48, x = 967, y = 453 },
["chevrons-right"] = { id = 16898612819, w = 48, h = 48, x = 967, y = 710 },
["circle"] = { id = 16898613044, w = 48, h = 48, x = 771, y = 355 },
["circle-dot"] = { id = 16898613044, w = 48, h = 48, x = 514, y = 771 },
["circle-help"] = { id = 16898613044, w = 48, h = 48, x = 820, y = 257 },
["circle-x"] = { id = 16898613044, w = 48, h = 48, x = 820, y = 306 },
["clipboard"] = { id = 16898613044, w = 48, h = 48, x = 49, y = 869 },
["clock"] = { id = 16898613044, w = 48, h = 48, x = 771, y = 661 },
["cloud"] = { id = 16898613044, w = 48, h = 48, x = 918, y = 306 },
["cloud-download"] = { id = 16898613044, w = 48, h = 48, x = 612, y = 820 },
["cloud-upload"] = { id = 16898613044, w = 48, h = 48, x = 967, y = 257 },
["code"] = { id = 16898613044, w = 48, h = 48, x = 355, y = 869 },
["coffee"] = { id = 16898613044, w = 48, h = 48, x = 967, y = 514 },
["coins"] = { id = 16898613044, w = 48, h = 48, x = 869, y = 612 },
["compass"] = { id = 16898613044, w = 48, h = 48, x = 514, y = 967 },
["contact"] = { id = 16898613044, w = 48, h = 48, x = 49, y = 967 },
["cookie"] = { id = 16898613044, w = 48, h = 48, x = 869, y = 404 },
["cpu"] = { id = 16898613044, w = 48, h = 48, x = 196, y = 869 },
["credit-card"] = { id = 16898613044, w = 48, h = 48, x = 98, y = 967 },
["crop"] = { id = 16898613044, w = 48, h = 48, x = 918, y = 404 },
["crown"] = { id = 16898613044, w = 48, h = 48, x = 404, y = 918 },
["database"] = { id = 16898613044, w = 48, h = 48, x = 710, y = 869 },
["diamond"] = { id = 16898613044, w = 48, h = 48, x = 196, y = 918 },
["disc"] = { id = 16898613044, w = 48, h = 48, x = 661, y = 967 },
["dollar-sign"] = { id = 16898613044, w = 48, h = 48, x = 820, y = 857 },
["door-open"] = { id = 16898613044, w = 48, h = 48, x = 967, y = 759 },
["download"] = { id = 16898613044, w = 48, h = 48, x = 820, y = 906 },
["droplet"] = { id = 16898613044, w = 48, h = 48, x = 820, y = 955 },
["ear"] = { id = 16898613044, w = 48, h = 48, x = 967, y = 955 },
["egg"] = { id = 16898613353, w = 48, h = 48, x = 514, y = 771 },
["equal"] = { id = 16898613353, w = 48, h = 48, x = 0, y = 820 },
["eraser"] = { id = 16898613353, w = 48, h = 48, x = 820, y = 257 },
["expand"] = { id = 16898613353, w = 48, h = 48, x = 306, y = 771 },
["external-link"] = { id = 16898613353, w = 48, h = 48, x = 257, y = 820 },
["factory"] = { id = 16898613353, w = 48, h = 48, x = 514, y = 820 },
["fast-forward"] = { id = 16898613353, w = 48, h = 48, x = 820, y = 49 },
["feather"] = { id = 16898613353, w = 48, h = 48, x = 771, y = 98 },
["file"] = { id = 16898613353, w = 48, h = 48, x = 820, y = 661 },
["file-text"] = { id = 16898613353, w = 48, h = 48, x = 869, y = 355 },
["files"] = { id = 16898613353, w = 48, h = 48, x = 771, y = 710 },
["film"] = { id = 16898613353, w = 48, h = 48, x = 710, y = 771 },
["filter"] = { id = 16898613353, w = 48, h = 48, x = 612, y = 869 },
["flag"] = { id = 16898613353, w = 48, h = 48, x = 98, y = 918 },
["flame"] = { id = 16898613353, w = 48, h = 48, x = 967, y = 306 },
["flask-conical"] = { id = 16898613353, w = 48, h = 48, x = 453, y = 820 },
["folder"] = { id = 16898613353, w = 48, h = 48, x = 404, y = 967 },
["folder-open"] = { id = 16898613353, w = 48, h = 48, x = 820, y = 759 },
["frame"] = { id = 16898613353, w = 48, h = 48, x = 710, y = 918 },
["gauge"] = { id = 16898613353, w = 48, h = 48, x = 771, y = 955 },
["gem"] = { id = 16898613353, w = 48, h = 48, x = 918, y = 857 },
["ghost"] = { id = 16898613353, w = 48, h = 48, x = 869, y = 906 },
["gift"] = { id = 16898613353, w = 48, h = 48, x = 820, y = 955 },
["git-branch"] = { id = 16898613353, w = 48, h = 48, x = 918, y = 906 },
["globe"] = { id = 16898613509, w = 48, h = 48, x = 771, y = 563 },
["grip"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 257 },
["grip-vertical"] = { id = 16898613509, w = 48, h = 48, x = 0, y = 869 },
["grip-horizontal"] = { id = 16898613509, w = 48, h = 48, x = 49, y = 820 },
["hammer"] = { id = 16898613509, w = 48, h = 48, x = 306, y = 820 },
["hand"] = { id = 16898613509, w = 48, h = 48, x = 563, y = 820 },
["hard-drive"] = { id = 16898613509, w = 48, h = 48, x = 820, y = 98 },
["hash"] = { id = 16898613509, w = 48, h = 48, x = 147, y = 771 },
["headphones"] = { id = 16898613509, w = 48, h = 48, x = 306, y = 869 },
["hexagon"] = { id = 16898613509, w = 48, h = 48, x = 967, y = 0 },
["history"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 98 },
["inbox"] = { id = 16898613509, w = 48, h = 48, x = 918, y = 563 },
["infinity"] = { id = 16898613509, w = 48, h = 48, x = 661, y = 820 },
["italic"] = { id = 16898613509, w = 48, h = 48, x = 967, y = 49 },
["key"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 404 },
["keyboard"] = { id = 16898613509, w = 48, h = 48, x = 453, y = 820 },
["lamp"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 661 },
["languages"] = { id = 16898613509, w = 48, h = 48, x = 710, y = 820 },
["laptop"] = { id = 16898613509, w = 48, h = 48, x = 563, y = 967 },
["layers"] = { id = 16898613509, w = 48, h = 48, x = 98, y = 967 },
["leaf"] = { id = 16898613509, w = 48, h = 48, x = 918, y = 661 },
["library"] = { id = 16898613509, w = 48, h = 48, x = 710, y = 869 },
["life-buoy"] = { id = 16898613509, w = 48, h = 48, x = 661, y = 918 },
["lightbulb"] = { id = 16898613509, w = 48, h = 48, x = 918, y = 196 },
["link"] = { id = 16898613509, w = 48, h = 48, x = 918, y = 453 },
["list"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 808 },
["list-checks"] = { id = 16898613509, w = 48, h = 48, x = 404, y = 967 },
["locate"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 857 },
["log-in"] = { id = 16898613509, w = 48, h = 48, x = 869, y = 906 },
["log-out"] = { id = 16898613509, w = 48, h = 48, x = 820, y = 955 },
["mail"] = { id = 16898613613, w = 48, h = 48, x = 820, y = 0 },
["map"] = { id = 16898613613, w = 48, h = 48, x = 306, y = 771 },
["maximize"] = { id = 16898613613, w = 48, h = 48, x = 771, y = 563 },
["medal"] = { id = 16898613613, w = 48, h = 48, x = 563, y = 771 },
["megaphone"] = { id = 16898613613, w = 48, h = 48, x = 869, y = 0 },
["mic"] = { id = 16898613613, w = 48, h = 48, x = 820, y = 612 },
["minimize"] = { id = 16898613613, w = 48, h = 48, x = 918, y = 49 },
["monitor"] = { id = 16898613613, w = 48, h = 48, x = 404, y = 820 },
["moon"] = { id = 16898613613, w = 48, h = 48, x = 306, y = 918 },
["mountain"] = { id = 16898613613, w = 48, h = 48, x = 869, y = 612 },
["mouse-pointer"] = { id = 16898613613, w = 48, h = 48, x = 612, y = 869 },
["move"] = { id = 16898613613, w = 48, h = 48, x = 453, y = 820 },
["move-diagonal-2"] = { id = 16898613613, w = 48, h = 48, x = 967, y = 49 },
["music"] = { id = 16898613613, w = 48, h = 48, x = 967, y = 563 },
["navigation"] = { id = 16898613613, w = 48, h = 48, x = 771, y = 759 },
["network"] = { id = 16898613613, w = 48, h = 48, x = 710, y = 820 },
["newspaper"] = { id = 16898613613, w = 48, h = 48, x = 661, y = 869 },
["octagon"] = { id = 16898613613, w = 48, h = 48, x = 404, y = 918 },
["package"] = { id = 16898613613, w = 48, h = 48, x = 918, y = 196 },
["paintbrush"] = { id = 16898613613, w = 48, h = 48, x = 918, y = 453 },
["paperclip"] = { id = 16898613613, w = 48, h = 48, x = 918, y = 857 },
["pen"] = { id = 16898613699, w = 48, h = 48, x = 771, y = 49 },
["pencil"] = { id = 16898613699, w = 48, h = 48, x = 820, y = 257 },
["percent"] = { id = 16898613699, w = 48, h = 48, x = 771, y = 563 },
["phone"] = { id = 16898613699, w = 48, h = 48, x = 0, y = 869 },
["pie-chart"] = { id = 16898613699, w = 48, h = 48, x = 869, y = 514 },
["pin"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 0 },
["pizza"] = { id = 16898613699, w = 48, h = 48, x = 820, y = 98 },
["plane"] = { id = 16898613699, w = 48, h = 48, x = 98, y = 820 },
["plug"] = { id = 16898613699, w = 48, h = 48, x = 404, y = 771 },
["pointer"] = { id = 16898613699, w = 48, h = 48, x = 661, y = 771 },
["printer"] = { id = 16898613699, w = 48, h = 48, x = 196, y = 771 },
["puzzle"] = { id = 16898613699, w = 48, h = 48, x = 49, y = 918 },
["qr-code"] = { id = 16898613699, w = 48, h = 48, x = 967, y = 257 },
["radio"] = { id = 16898613699, w = 48, h = 48, x = 306, y = 918 },
["redo"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 355 },
["repeat"] = { id = 16898613699, w = 48, h = 48, x = 820, y = 710 },
["reply"] = { id = 16898613699, w = 48, h = 48, x = 612, y = 918 },
["rocket"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 147 },
["rotate-cw"] = { id = 16898613699, w = 48, h = 48, x = 869, y = 453 },
["rss"] = { id = 16898613699, w = 48, h = 48, x = 771, y = 808 },
["ruler"] = { id = 16898613699, w = 48, h = 48, x = 710, y = 869 },
["save"] = { id = 16898613699, w = 48, h = 48, x = 918, y = 453 },
["scale"] = { id = 16898613699, w = 48, h = 48, x = 404, y = 967 },
["scan"] = { id = 16898613699, w = 48, h = 48, x = 967, y = 196 },
["scissors"] = { id = 16898613699, w = 48, h = 48, x = 820, y = 857 },
["send"] = { id = 16898613699, w = 48, h = 48, x = 967, y = 857 },
["server"] = { id = 16898613777, w = 48, h = 48, x = 771, y = 0 },
["share"] = { id = 16898613777, w = 48, h = 48, x = 514, y = 771 },
["shield-check"] = { id = 16898613777, w = 48, h = 48, x = 820, y = 257 },
["shopping-bag"] = { id = 16898613777, w = 48, h = 48, x = 49, y = 820 },
["shopping-cart"] = { id = 16898613777, w = 48, h = 48, x = 869, y = 257 },
["shuffle"] = { id = 16898613777, w = 48, h = 48, x = 257, y = 869 },
["panel-left"] = { id = 16898613613, w = 48, h = 48, x = 967, y = 453 },
["signal"] = { id = 16898613777, w = 48, h = 48, x = 918, y = 0 },
["skip-forward"] = { id = 16898613777, w = 48, h = 48, x = 98, y = 820 },
["skull"] = { id = 16898613777, w = 48, h = 48, x = 49, y = 869 },
["smartphone"] = { id = 16898613777, w = 48, h = 48, x = 257, y = 918 },
["smile"] = { id = 16898613777, w = 48, h = 48, x = 869, y = 563 },
["sparkles"] = { id = 16898613777, w = 48, h = 48, x = 918, y = 49 },
["speaker"] = { id = 16898613777, w = 48, h = 48, x = 869, y = 98 },
["square"] = { id = 16898613777, w = 48, h = 48, x = 869, y = 710 },
["sticky-note"] = { id = 16898613777, w = 48, h = 48, x = 918, y = 453 },
["store"] = { id = 16898613777, w = 48, h = 48, x = 404, y = 967 },
["sun"] = { id = 16898613777, w = 48, h = 48, x = 967, y = 453 },
["syringe"] = { id = 16898613777, w = 48, h = 48, x = 918, y = 808 },
["tag"] = { id = 16898613777, w = 48, h = 48, x = 967, y = 906 },
["tags"] = { id = 16898613777, w = 48, h = 48, x = 918, y = 955 },
["terminal"] = { id = 16898613869, w = 48, h = 48, x = 820, y = 257 },
["thermometer"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 257 },
["thumbs-down"] = { id = 16898613869, w = 48, h = 48, x = 820, y = 306 },
["thumbs-up"] = { id = 16898613869, w = 48, h = 48, x = 771, y = 355 },
["ticket"] = { id = 16898613869, w = 48, h = 48, x = 612, y = 771 },
["timer"] = { id = 16898613869, w = 48, h = 48, x = 918, y = 0 },
["trash"] = { id = 16898613869, w = 48, h = 48, x = 918, y = 514 },
["trending-up"] = { id = 16898613869, w = 48, h = 48, x = 514, y = 918 },
["trophy"] = { id = 16898613869, w = 48, h = 48, x = 820, y = 147 },
["truck"] = { id = 16898613869, w = 48, h = 48, x = 771, y = 196 },
["tv"] = { id = 16898613869, w = 48, h = 48, x = 98, y = 869 },
["type"] = { id = 16898613869, w = 48, h = 48, x = 967, y = 257 },
["umbrella"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 355 },
["undo"] = { id = 16898613869, w = 48, h = 48, x = 404, y = 820 },
["unlink"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 612 },
["upload"] = { id = 16898613869, w = 48, h = 48, x = 612, y = 869 },
["usb"] = { id = 16898613869, w = 48, h = 48, x = 563, y = 918 },
["user-check"] = { id = 16898613869, w = 48, h = 48, x = 918, y = 98 },
["user-plus"] = { id = 16898613869, w = 48, h = 48, x = 918, y = 355 },
["user-x"] = { id = 16898613869, w = 48, h = 48, x = 710, y = 820 },
["video"] = { id = 16898613869, w = 48, h = 48, x = 355, y = 967 },
["volume-2"] = { id = 16898613869, w = 48, h = 48, x = 771, y = 808 },
["wallet"] = { id = 16898613869, w = 48, h = 48, x = 147, y = 967 },
["wand"] = { id = 16898613869, w = 48, h = 48, x = 404, y = 967 },
["watch"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 759 },
["waves"] = { id = 16898613869, w = 48, h = 48, x = 820, y = 808 },
["webhook"] = { id = 16898613869, w = 48, h = 48, x = 967, y = 196 },
["wifi"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 808 },
["wind"] = { id = 16898613869, w = 48, h = 48, x = 820, y = 857 },
["wrench"] = { id = 16898613869, w = 48, h = 48, x = 820, y = 906 },
["zoom-in"] = { id = 16898613869, w = 48, h = 48, x = 869, y = 955 },
["zoom-out"] = { id = 16898613869, w = 48, h = 48, x = 967, y = 906 },
["paw-print"] = { id = 16898613699, w = 48, h = 48, x = 771, y = 257 },
["rabbit"] = { id = 16898613699, w = 48, h = 48, x = 869, y = 355 },
["dog"] = { id = 16898613044, w = 48, h = 48, x = 869, y = 808 },
["cat"] = { id = 16898612819, w = 48, h = 48, x = 404, y = 918 },
["squirrel"] = { id = 16898613777, w = 48, h = 48, x = 771, y = 808 },
["turtle"] = { id = 16898613869, w = 48, h = 48, x = 196, y = 771 },
["bird"] = { id = 16898612819, w = 48, h = 48, x = 869, y = 0 },
["fish"] = { id = 16898613353, w = 48, h = 48, x = 869, y = 147 },
["rat"] = { id = 16898613699, w = 48, h = 48, x = 869, y = 612 },
["snail"] = { id = 16898613777, w = 48, h = 48, x = 820, y = 612 },
["worm"] = { id = 16898613869, w = 48, h = 48, x = 918, y = 808 },
["bone"] = { id = 16898612819, w = 48, h = 48, x = 869, y = 514 },
}

local Icons = { data = DATA }








local ALIAS = {
house = "home",
}



local Animate
function Icons.Init(R) Animate = R.Animate end

local function lookup(name) return DATA[name] or DATA[ALIAS[name] or ""] end

function Icons.get(name)
local e = lookup(name)
if not e then return nil end
return {
Id = "rbxassetid://" .. e.id,
ImageRectSize = Vector2.new(e.w, e.h),
ImageRectOffset = Vector2.new(e.x, e.y),
}
end



local function sameRect(v, x, y) return v ~= nil and v.X == x and v.Y == y end





function Icons.apply(imageLabel, name, color3)
local e = lookup(name)
if not e then
if warn then warn("[EzUI] unknown icon: " .. tostring(name)) end
return false
end
local id = "rbxassetid://" .. e.id
if imageLabel.Image ~= id
or not sameRect(imageLabel.ImageRectSize, e.w, e.h)
or not sameRect(imageLabel.ImageRectOffset, e.x, e.y) then
imageLabel.Image = id
imageLabel.ImageRectSize = Vector2.new(e.w, e.h)
imageLabel.ImageRectOffset = Vector2.new(e.x, e.y)
end
if color3 then imageLabel.ImageColor3 = color3 end
return true
end




function Icons.tint(imageLabel, color3, duration)
if not imageLabel or not color3 then return nil end
if not Animate then imageLabel.ImageColor3 = color3; return nil end
return Animate.to(imageLabel, duration or "fast", { ImageColor3 = color3 })
end

return Icons

end


EmbeddedModules["core/flag"] = function()


local Flag = {}

function Flag.bind(opts, default, apply)
opts = opts or {}
local config, flag = opts.Config, opts.Flag
local value = default
if config and flag then
config:Register(flag, default, apply)
local saved = config:Get(flag)
if saved ~= nil then value = saved end
end
apply(value)
return function(v)
apply(v)
if config and flag then config:Set(flag, v) end
end
end

return Flag

end


EmbeddedModules["core/drag"] = function()





local UserInputService = game:GetService("UserInputService")

local Drag = {}











function Drag.bind(target, opts, maid)
local mouseDown = false
local activeTouch = nil
local startPos = nil
local changeConn, endConn, blurConn
local change, finish
local function stopListening()
if changeConn then changeConn:Disconnect(); changeConn = nil end
if endConn then endConn:Disconnect(); endConn = nil end
if blurConn then blurConn:Disconnect(); blurConn = nil end
end


local function abandon()
if not startPos then return end
mouseDown = false; activeTouch = nil; startPos = nil
stopListening()
if opts.onEnd then opts.onEnd() end
end
local function listen()
if changeConn then return end
changeConn = UserInputService.InputChanged:Connect(change)
endConn = UserInputService.InputEnded:Connect(finish)
local blur = UserInputService.WindowFocusReleased
if blur then blurConn = blur:Connect(abandon) end
end

local function begin(input)
if opts.isActive and not opts.isActive() then return end
local t = input.UserInputType
if t == Enum.UserInputType.MouseButton1 then
mouseDown = true; startPos = input.Position
elseif t == Enum.UserInputType.Touch then
activeTouch = input; startPos = input.Position
else
return
end
listen()
if opts.onBegin then opts.onBegin(input) end
end

function change(input)
if not startPos then return end
local isMouse = mouseDown and input.UserInputType == Enum.UserInputType.MouseMovement
local isTouch = activeTouch ~= nil and input == activeTouch
if not (isMouse or isTouch) then return end
local p = input.Position
if opts.onChange then opts.onChange(p.X - startPos.X, p.Y - startPos.Y, p) end
end

function finish(input)
local t = input.UserInputType
local relevant = (mouseDown and t == Enum.UserInputType.MouseButton1)
or (activeTouch ~= nil and input == activeTouch)
if not relevant then return end
mouseDown = false; activeTouch = nil; startPos = nil
stopListening()
if opts.onEnd then opts.onEnd() end
end

maid:Give(target.InputBegan:Connect(begin))
maid:Give(target.InputEnded:Connect(finish))
maid:Give(stopListening)
end

return Drag

end


EmbeddedModules["core/effects"] = function()























local Effects = {}
local Create, Theme, Animate, Safe, Device



local SKELETON = { period = 1.1, rotation = 15 }


local meta = setmetatable({}, { __mode = "k" })



local lazy = setmetatable({}, { __mode = "k" })

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


local function levelOf(theme, level, layer)
local key = level or (meta[layer] and meta[layer].level) or "control"
local lv = theme.Effect[key]
if type(lv) ~= "table" or type(lv.spread) ~= "number" then
error("Effects: unknown level '" .. tostring(key) .. "' (window/dialog/popover/toast/tooltip/control)", 3)
end
return lv
end



local function shadowId(theme)
if theme.Lite then return nil end
local id = theme.Effect.shadowId
if type(id) ~= "string" or id == "" then return nil end
return id
end




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



function Effects.shadow(parent, theme, opts)
need(theme, "shadow"); opts = opts or {}
if not shadowId(theme) then return nil end
local img = sliceLayer(parent, theme, {
name = opts.name or "Shadow", color = Color3.new(0, 0, 0), alpha = Theme.fx(theme).shadow, zIndex = opts.zIndex,
})
local m = metaOf(img); m.kind = "shadow"; m.level = opts.level
return img
end



local function glowAllowed(theme)
local mode = theme.Effect.controlGlow
if mode == "off" or mode == false then return false end
if mode == "auto" and Device.IsMobile() then return false end
return true
end



function Effects.glow(parent, theme, colorToken, level, zIndex, name)
need(theme, "glow")
if colorToken == nil then error("Effects.glow: colorToken (a theme.Colors value) required", 2) end
if not shadowId(theme) or not glowAllowed(theme) then return nil end
local img = sliceLayer(parent, theme, { name = name or "Glow", color = colorToken, alpha = 1, zIndex = zIndex })
local m = metaOf(img); m.kind = "glow"; m.level = level; m.token = colorToken
return img
end





















function Effects.lazyGlow(parent, theme, colorToken, level, zIndex, name, place)
need(theme, "lazyGlow")
if colorToken == nil then error("Effects.lazyGlow: colorToken (a theme.Colors value) required", 2) end
if not shadowId(theme) or not glowAllowed(theme) then return nil end
local st = { token = colorToken }






local released = false
local function show()
if st.layer or released then return st.layer end
st.layer = Effects.glow(parent, theme, st.token, level, zIndex, name)
if st.layer and place then place(st.layer) end
return st.layer
end

local function toShow(alpha)
if not st.layer and (type(alpha) ~= "number" or alpha >= 1) then return nil end
return show()
end
local handle = {
Peek = function() return st.layer end,
Show = show,
Set = function(alpha)
local layer = toShow(alpha)
if layer then layer.ImageTransparency = alpha end
return layer
end,
Fade = function(alpha, dur)
local layer = toShow(alpha)
if not layer then return nil end
return Animate.to(layer, dur or "base", { ImageTransparency = alpha })
end,
Release = function() released = true end,
}
lazy[handle] = st
return handle
end




local function growth(theme, m)
return m.lifted and 2 * theme.Effect.lift.spreadDelta or 0
end




local function writeGeometry(shadow, theme, m, rest, xs, xo, ys, yo)
m.rest = rest
local g = growth(theme, m)
local sw, sh = rest[2] + g, rest[4] + g
local c = m.size
if not c or c[1] ~= rest[1] or c[2] ~= sw or c[3] ~= rest[3] or c[4] ~= sh then
shadow.Size = UDim2.new(rest[1], sw, rest[3], sh)
m.size = { rest[1], sw, rest[3], sh }
end
shadow.Position = UDim2.new(xs, xo, ys, yo)
end



function Effects.place(shadow, x, y, w, h, level, theme)
if not shadow then return nil end
need(theme, "place")
local lv, m = levelOf(theme, level, shadow), metaOf(shadow)
writeGeometry(shadow, theme, m, { 0, w + 2 * lv.spread, 0, h + 2 * lv.spread }, 0, x + w / 2, 0, y + h / 2 + lv.offsetY)
return shadow
end




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


local function rimStops(fx) return { { 0, fx.edgeTop }, { 1, fx.edgeBottom } } end

local function paintRim(g, fx)
g.Rotation = 90
g.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, fx.edgeTop), NumberSequenceKeypoint.new(1, fx.edgeBottom),
})
return g
end




function Effects.rim(stroke, theme)
if not stroke or (type(theme) == "table" and theme.Lite) then return nil end
local fx = Theme.fx(need(theme, "rim"))
local g = stroke:FindFirstChildOfClass("UIGradient")
if g then return paintRim(g, fx) end
g = Create.shade({ rotation = 90, stops = rimStops(fx) })
g.Name = "Rim"; g.Parent = stroke
return g
end




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







function Effects.lift(shadow, theme, on, alpha)
if not shadow then return nil end
need(theme, "lift")
local m = metaOf(shadow)
m.lifted = on and true or false
local goal = { ImageTransparency = type(alpha) == "number" and alpha or shadowAlpha(theme, m.lifted) }
local rest = restOf(shadow, m)
if rest then
local g = growth(theme, m)
goal.Size = UDim2.new(rest[1], rest[2] + g, rest[3], rest[4] + g)


m.size = nil
end
return Animate.to(shadow, "fast", goal)
end




function Effects.reskin(layer, theme, kind, colorToken)
if not layer then return nil end
need(theme, "reskin")



local st = lazy[layer]
if st then
if colorToken ~= nil then st.token = colorToken end
if st.layer then Effects.reskin(st.layer, theme, "glow", st.token) end
return layer
end
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

if frame.Parent == nil then frame:Destroy(); return end
Animate.exitTo(frame, "exit", { BackgroundTransparency = 1 }, function() frame:Destroy() end)
end
return { Frame = frame, Gradient = g, Stop = Stop }
end

return Effects

end


EmbeddedModules["components/separator"] = function()

local Separator = {}
local Create, DefaultTheme

function Separator.Init(R) Create = R.Create; DefaultTheme = R.Theme end

function Separator.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local frame = Create("Frame", {
Name = "Separator",
BackgroundColor3 = theme.Colors.border,
BackgroundTransparency = theme.Stroke.divider,
BorderSizePixel = 0,
Size = UDim2.new(1, 0, 0, 1),
LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent,
})

local unreg = opts.AccentReg and opts.AccentReg(function() frame.BackgroundColor3 = theme.Colors.border end)
return { Frame = frame, Destroy = function() if unreg then unreg() end; frame:Destroy() end }
end

return Separator

end


EmbeddedModules["components/toggle"] = function()

local Toggle = {}
local Create, DefaultTheme, Animate, Maid, Flag, Safe, Effects, Recipes

function Toggle.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Flag = R.Flag; Safe = R.Safe
Effects = R.Effects; Recipes = R.Recipes
end




local TRACK_W, TRACK_H = 44, 24

function Toggle.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local value = false
local onChanged

local hasDesc = opts.Description ~= nil and opts.Description ~= ""
local rowH = hasDesc and 50 or 34
local padY = hasDesc and 8 or 0

local btn = Create("TextButton", {
Name = "Toggle", AutoButtonColor = false, Text = "",
BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent,
Create.corner(theme.Radius.md),
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX, top = padY, bottom = padY }),
})
local label = Create.text(Create("TextLabel", {
Name = "Label", BackgroundTransparency = 1, Text = opts.Text or "Toggle",
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
Size = UDim2.new(1, -54, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn,
}), theme, "label")
local desc
if hasDesc then
desc = Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, -54, 0, 18), Parent = btn }), theme, "muted")
end


local track = Create("Frame", {
Name = "Track", BackgroundColor3 = theme.Colors.switchTrackOff, BorderSizePixel = 0, ZIndex = 2,
Size = UDim2.new(0, TRACK_W, 0, TRACK_H), Position = UDim2.new(1, -TRACK_W, 0.5, -TRACK_H / 2),
Parent = btn, Create.corner(TRACK_H / 2),
})
local trackStroke = Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = track })

local knobSize = theme.Sizes.knob
local knobPad = (TRACK_H - knobSize) / 2
local knobY = -knobSize / 2
local offX, onX = knobPad, TRACK_W - knobSize - knobPad
local stretchW = knobSize * theme.Motion.knobStretch
local knob = Create("Frame", {
Name = "Knob", BackgroundColor3 = theme.Colors.foreground, BorderSizePixel = 0, ZIndex = 3,
Size = UDim2.new(0, knobSize, 0, knobSize), Position = UDim2.new(0, offX, 0.5, knobY),
Parent = track, Create.corner(knobSize / 2),
})

local knobStroke = Create.stroke(theme.Colors.background, 1, theme.Stroke.knob)
knobStroke.Parent = knob





local glow = Effects.lazyGlow(btn, theme, theme.Colors.primary, "control", 1, "TrackGlow",
function(layer) Effects.mirror(layer, track, "control", theme) end)



if glow then maid:Give(glow.Release) end

local function knobRest() return UDim2.new(0, value and onX or offX, 0.5, knobY) end



local built = false
local function apply(v)
value = v and true or false
local instant = not built
Safe.mutate(function()
local trackC = value and theme.Colors.primary or theme.Colors.switchTrackOff
local knobC = value and theme.Colors.primaryForeground or theme.Colors.foreground

local strokeA = value and 1 or theme.Stroke.control
local glowA = value and theme.fx(theme).glow or 1
if instant then
knob.Position = knobRest(); knob.Size = UDim2.new(0, knobSize, 0, knobSize)
knob.BackgroundColor3 = knobC; track.BackgroundColor3 = trackC
trackStroke.Transparency = strokeA
if glow then glow.Set(glowA) end
return
end


Animate.springTo(knob, "release", { Position = knobRest(), Size = UDim2.new(0, knobSize, 0, knobSize) })
Animate.to(knob, "base", { BackgroundColor3 = knobC })
Animate.to(track, "base", { BackgroundColor3 = trackC })
Animate.to(trackStroke, "fast", { Transparency = strokeA })
if glow then glow.Fade(glowA) end
end)
end

local commit = Flag.bind(opts, opts.Default == true, apply)
built = true


local hover = Recipes.hover(btn, { theme = theme, corner = theme.Radius.md,
inset = { x = theme.Spacing.inputX, y = padY } })
maid:Give(hover.disconnect)

local enabled = true
local function setEnabled(b)
enabled = b ~= false
Safe.mutate(function()
local parts = { { track, "BackgroundTransparency", 0 }, { knob, "BackgroundTransparency", 0 },
{ label, "TextTransparency", 0 } }
if desc then parts[#parts + 1] = { desc, "TextTransparency", 0 } end
Recipes.disabled(parts, not enabled, theme)
end)
end



local pressed = false
local function pressKnob()
pressed = true
Animate.to(knob, "press", {
Size = UDim2.new(0, stretchW, 0, knobSize),
Position = UDim2.new(0, value and (TRACK_W - knobPad - stretchW) or knobPad, 0.5, knobY),
})
end
local function releaseKnob()
if not pressed then return end
pressed = false
Animate.springTo(knob, "release", { Size = UDim2.new(0, knobSize, 0, knobSize), Position = knobRest() })
end

if opts.AccentReg then maid:Give(opts.AccentReg(function()
btn.BackgroundColor3 = theme.Colors.surface
label.TextColor3 = theme.Colors.foreground
if desc then desc.TextColor3 = theme.Colors.mutedForeground end
trackStroke.Color = theme.Colors.border
knobStroke.Color = theme.Colors.background
Effects.reskin(glow, theme, "glow", theme.Colors.primary)
hover.reskin()
apply(value)
end)) end

local api = { Frame = btn }
function api.Get() return value end
function api.Set(v)
commit(v and true or false)
if opts.Callback then opts.Callback(value) end
if onChanged then onChanged(value) end
end
function api.OnChanged(fn) onChanged = fn end

function api.SetEnabled(b) setEnabled(b) end
function api.Destroy() maid:DoCleanup() end

maid:Give(btn.MouseButton1Down:Connect(function() if enabled then pressKnob() end end))
maid:Give(btn.MouseButton1Up:Connect(releaseKnob))
maid:Give(btn.MouseLeave:Connect(releaseKnob))
maid:Give(btn.MouseButton1Click:Connect(function() if enabled then api.Set(not value) end end))
maid:Give(btn)
if opts.Disabled then setEnabled(false) end
return api
end

return Toggle

end


EmbeddedModules["components/progressbar"] = function()





local ProgressBar = {}
local Create, DefaultTheme, Animate, Safe
function ProgressBar.Init(R) Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Safe = R.Safe end




local IND = { width = 0.3, rest = 0.5, period = 1.1 }

local function clamp01(n) n = tonumber(n) or 0; if n < 0 then return 0 elseif n > 1 then return 1 end return n end

function ProgressBar.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local value = clamp01(opts.Default or 0)
local root = Create("Frame", { Name = "ProgressBar", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 8), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent })
local track = Create("Frame", { Name = "Track", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
Size = UDim2.new(1, 0, 1, 0), Parent = root, Create.corner(4) })

local trackStroke = Create.stroke(theme.Colors.border, 1, theme.Stroke.track)
trackStroke.Parent = track
local fill = Create("Frame", { Name = "Fill", BackgroundColor3 = opts.Color or theme.Colors.primary, BorderSizePixel = 0,
Size = UDim2.new(value, 0, 1, 0), Visible = value > 0, Parent = track, Create.corner(4) })



Create("UISizeConstraint", { MinSize = Vector2.new(theme.Sizes.progress, 0), Parent = fill })
local unreg
if opts.AccentReg then
unreg = opts.AccentReg(function()
track.BackgroundColor3 = theme.Colors.surface
trackStroke.Color = theme.Colors.border
if not opts.Color then fill.BackgroundColor3 = theme.Colors.primary end
end)
end

local function durationFor(delta)
return theme.Motion.base + math.abs(delta) * (theme.Motion.slow - theme.Motion.base)
end



local ind = theme.Effect and theme.Effect.indeterminate or IND
local sweepW, sweepRest = ind.width or IND.width, ind.rest or IND.rest
local sweepPeriod = ind.period or IND.period
local indet, sweep = false, nil


local function stopSweep()
if not indet then return end
indet = false
if sweep then sweep.Cancel(); sweep = nil end



track.ClipsDescendants = false
fill.Position = UDim2.new(0, 0, 0, 0)
end

local function Set(p)
local prev = value
value = clamp01(p)
local done = value >= 1 and prev < 1
Safe.mutate(function()
stopSweep()
fill.Visible = value > 0
Animate.to(fill, durationFor(value - prev), { Size = UDim2.new(value, 0, 1, 0) },
Animate.EASING.smooth, Animate.DIR.Out)



if done then
fill.BackgroundTransparency = theme.Opacity.flash
Animate.to(fill, "base", { BackgroundTransparency = 0 })
end
end)
end

local function SetIndeterminate(b)
local on = b and true or false
Safe.mutate(function()
if not on then
stopSweep()
fill.Visible = value > 0
Animate.to(fill, "base", { Size = UDim2.new(value, 0, 1, 0) },
Animate.EASING.smooth, Animate.DIR.Out)
return
end
if indet then return end
indet = true
fill.Visible = true
fill.BackgroundTransparency = 0
if not Animate.isEnabled() then

fill.Position = UDim2.new(0, 0, 0, 0)
fill.Size = UDim2.new(sweepRest, 0, 1, 0)
return
end
track.ClipsDescendants = true
fill.Size = UDim2.new(sweepW, 0, 1, 0)
fill.Position = UDim2.new(-sweepW, 0, 0, 0)
sweep = Animate.loop(fill, sweepPeriod, { Position = UDim2.new(1, 0, 0, 0) }, Animate.EASING.smooth)
end)
end
if opts.Indeterminate then SetIndeterminate(true) end

return {
Frame = root,
Get = function() return value end,
Set = Set,
SetIndeterminate = SetIndeterminate,
Destroy = function() stopSweep(); if unreg then unreg() end; root:Destroy() end,
}
end
return ProgressBar

end


EmbeddedModules["components/notification"] = function()





local Notification = {}
local Create, DefaultTheme, Maid, Overlay, Animate, Icons, Safe, Effects, Recipes
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local container
local stackShadow
local order = {}
local seq = 0
local expanded = false
local stepConn
local pinnedScale



local FALLBACK_H = 60


local BADGE = 20

function Notification.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Animate = R.Animate; Icons = R.Icons
Safe = R.Safe; Effects = R.Effects; Recipes = R.Recipes
container = nil
stackShadow = nil


if stepConn then stepConn:Disconnect() end
stepConn = nil
expanded = false
pinnedScale = nil
end

local enabled = true
function Notification.setEnabled(b) enabled = b ~= false end

local TYPE_COLOR = { info = "info", success = "success", warning = "warning", error = "destructive", loading = "info" }
local TYPE_ICON = { info = "info", success = "circle-check", warning = "triangle-alert", error = "circle-alert", loading = "loader" }

local position = "bottom-right"
local POS = {
["top-left"]      = { ax = 0,   ay = 0 },
["top-center"]    = { ax = 0.5, ay = 0 },
["top-right"]     = { ax = 1,   ay = 0 },
["bottom-left"]   = { ax = 0,   ay = 1 },
["bottom-center"] = { ax = 0.5, ay = 1 },
["bottom-right"]  = { ax = 1,   ay = 1 },
}



local function frontTheme()
local e = order[#order]
return (e and e.theme) or DefaultTheme
end

local function mix(theme, a, b, t) return (theme.mix or DefaultTheme.mix)(a, b, t) end

local function edgeColor(theme, accent) return mix(theme, theme.Colors.border, accent, theme.Toast.typeTint) end

local function containerPosition(cfg, TK)
local cx = (cfg.ax == 0 and UDim.new(0, TK.inset)) or (cfg.ax == 1 and UDim.new(1, -TK.inset)) or UDim.new(0.5, 0)
local cy = (cfg.ay == 0) and UDim.new(0, TK.inset) or UDim.new(1, -TK.inset)
return UDim2.new(cx.Scale, cx.Offset, cy.Scale, cy.Offset)
end



local function currentScale()
if pinnedScale then return pinnedScale end
local s = Overlay.scale and Overlay.scale()
return (type(s) == "number" and s > 0) and s or 1
end





local function stopTicker()
if stepConn then stepConn:Disconnect(); stepConn = nil end
end



local function tick(dt)
for i = #order, 1, -1 do
local e = order[i]
if e.frame and e.total and not e.paused then
e.remaining = e.remaining - dt
if e.remaining <= 0 then Notification.dismiss(e.id) end
end
end
if #order == 0 then stopTicker() end
end




local function faded(rest, a) return rest + (1 - rest) * a end



local function addPart(entry, inst, prop, rest)
entry.parts[#entry.parts + 1] = { inst = inst, prop = prop, rest = rest }
inst[prop] = faded(rest, entry.alpha or 1)
end
local function dropParts(entry, inst)
for i = #entry.parts, 1, -1 do if entry.parts[i].inst == inst then table.remove(entry.parts, i) end end
end




local function fadeTo(entry, a, dur, style, dir, delay, frameExtra, onDone)
entry.alpha = a
local goals, insts = {}, {}
for _, p in ipairs(entry.parts) do
local g = goals[p.inst]
if not g then g = {}; goals[p.inst] = g; insts[#insts + 1] = p.inst end
g[p.prop] = faded(p.rest, a)
end
local frame = entry.frame
if frameExtra then
local g = goals[frame]
if not g then g = {}; goals[frame] = g; insts[#insts + 1] = frame end
for k, v in pairs(frameExtra) do g[k] = v end
end

for _, inst in ipairs(insts) do
if inst ~= frame then Animate.to(inst, dur, goals[inst], style, dir, delay) end
end
if goals[frame] then
if onDone then Animate.toThen(frame, dur, goals[frame], onDone, style, dir)
else Animate.to(frame, dur, goals[frame], style, dir, delay) end
elseif onDone then
onDone()
end
end





local function freezeBar(e)
if e.barTween then e.barTween:Cancel(); e.barTween = nil end
end

local function holdBar(e)
freezeBar(e)
if not (e.bar and e.total and e.remaining) then return end
e.bar.Size = UDim2.new(math.max(0, e.remaining / e.total), 0, 0, (e.theme or DefaultTheme).Toast.barHeight)
end
local function runBar(e)
freezeBar(e)
if not (e.bar and e.total and e.remaining) then return end
local bh = (e.theme or DefaultTheme).Toast.barHeight
e.bar.Size = UDim2.new(math.max(0, e.remaining / e.total), 0, 0, bh)
if not Animate.isEnabled() or e.remaining <= 0 then return end
e.barTween = TweenService:Create(e.bar, TweenInfo.new(e.remaining, Enum.EasingStyle.Linear),
{ Size = UDim2.new(0, 0, 0, bh) })
e.barTween:Play()
end

local function ensureTicker()
if not stepConn then stepConn = RunService.Heartbeat:Connect(tick) end
end


local function ensureContainer(theme)
if container and container.Parent ~= nil then return container end
local TK = theme.Toast
stackShadow = nil
local cfg = POS[position] or POS["bottom-right"]
container = Create("Frame", {




Name = "ToastContainer", BackgroundTransparency = 1, ZIndex = Overlay.Z.toast,
AnchorPoint = Vector2.new(cfg.ax, cfg.ay), Position = containerPosition(cfg, TK),
Size = UDim2.new(0, TK.width, 0, 0),
})


Create("UIScale", { Name = "ContainerScale", Scale = currentScale(), Parent = container })
container.MouseEnter:Connect(function()
expanded = true
for _, e in ipairs(order) do
e.paused = true
if e.bar then Safe.mutate(function() holdBar(e) end) end
end
Notification.relayout("expand")
end)
container.MouseLeave:Connect(function()
expanded = false
for _, e in ipairs(order) do
e.paused = false
if e.bar then Safe.mutate(function() runBar(e) end) end
end
Notification.relayout()
end)
Overlay.mount(container)
return container
end



local function ensureStackShadow(theme)
if stackShadow and stackShadow.Parent ~= nil then return stackShadow end
stackShadow = Effects.shadow(container, theme, { name = "StackShadow", level = "toast", zIndex = 0 })
if stackShadow then stackShadow.Visible = false end
return stackShadow
end




local function syncStackShadow(theme)
if not stackShadow then return end
local e = order[#order]
local f = e and e.frame
local ap, as = f and f.AbsolutePosition, f and f.AbsoluteSize
local cp = container and container.AbsolutePosition
if not (ap and as and cp and (as.Y or 0) > 0) then stackShadow.Visible = false; return end
stackShadow.Visible = true



local s = currentScale()
Effects.place(stackShadow, (ap.X - cp.X) / s, (ap.Y - cp.Y) / s, as.X / s, as.Y / s, "toast", theme)
Effects.reskin(stackShadow, theme, "shadow")
end




local function toastHeight(e)
local lay = e.frame:FindFirstChildOfClass("UIListLayout")
local acs = lay and lay.AbsoluteContentSize
local pad = 0
if e.padding then pad = e.padding.PaddingTop.Offset + e.padding.PaddingBottom.Offset end
if acs and acs.Y and acs.Y > 0 then return acs.Y + pad end
return (e.frame.AbsoluteSize and e.frame.AbsoluteSize.Y) or FALLBACK_H
end








function Notification.relayout(reason)
local theme = frontTheme()
local TK, M = theme.Toast, theme.Motion
local n = #order
local cfg = POS[position] or POS["bottom-right"]
local vdir = (cfg.ay == 0) and 1 or -1
local y = 0
for idx = n, 1, -1 do
local e = order[idx]
if not e.frame then

else
local i = n - idx
local scale, transp, visible, yoff
if expanded then
visible, scale, transp, yoff = true, 1, 0, y
y = y + toastHeight(e) + TK.gap
else
visible = i < TK.maxVisible
scale = 1 - i * TK.peekScale
transp = i * TK.peekFade
yoff = i * TK.peek
end
e.frame.Visible = visible
e.frame.AnchorPoint = Vector2.new(cfg.ax, cfg.ay)
local target = UDim2.new(cfg.ax, 0, cfg.ay, vdir * yoff)




local last = e.laid
local moved = not last or last.yoff ~= yoff or last.scale ~= scale or last.transp ~= transp
or last.ax ~= cfg.ax or last.ay ~= cfg.ay
e.laid = { yoff = yoff, scale = scale, transp = transp, ax = cfg.ax, ay = cfg.ay }
if e.entering then



e.entering = false
Animate.springTo(e.frame, "enter", { Position = target })
fadeTo(e, transp, "base", Animate.EASING.enter)
Animate.springTo(e.scale, "enter", { Scale = scale })
elseif moved or reason ~= "measure" then




local d = (expanded and reason == "expand") and math.min(i, TK.staggerCap) * M.stagger or 0

if e.alpha ~= transp then
fadeTo(e, transp, "base", Animate.EASING.smooth, nil, d, { Position = target })
else
Animate.to(e.frame, "base", { Position = target }, Animate.EASING.smooth, nil, d)
end
Animate.to(e.scale, "base", { Scale = scale }, Animate.EASING.smooth, nil, d)
end
end
end



if container then
local h = 0
if n > 0 then
if expanded then
h = math.max(0, y - TK.gap)
else
local front = order[n]
local fh = front and front.frame and front.frame.AbsoluteSize and front.frame.AbsoluteSize.Y or 0
if fh <= 0 then fh = FALLBACK_H end
h = fh + math.min(n - 1, TK.maxVisible - 1) * TK.peek
end
end
container.Size = UDim2.new(0, TK.width, 0, h)
end
syncStackShadow(theme)
end

local function indexOf(id) for i, e in ipairs(order) do if e.id == id then return i end end end



local function accentFor(theme, ty) return theme.Colors[TYPE_COLOR[ty]] or theme.Colors.info end



local function setProgressPad(entry, hasBar)
if not entry.padding then return end
local TK = (entry.theme or DefaultTheme).Toast
entry.padding.PaddingBottom = UDim.new(0, hasBar and TK.progressInset or TK.padY)
end

local function startCountdown(entry, total, accent, theme)


local bar = Create("Frame", { Name = "Progress", BackgroundColor3 = accent, BorderSizePixel = 0,
Size = UDim2.new(1, 0, 0, theme.Toast.barHeight), LayoutOrder = 99, Parent = entry.frame,
Create.corner(theme.Radius.xs) })
addPart(entry, bar, "BackgroundTransparency", 0)
entry.total = total; entry.remaining = total; entry.paused = false; entry.bar = bar
setProgressPad(entry, true)
runBar(entry)
end

local function dropBar(entry)
freezeBar(entry)
if entry.bar then dropParts(entry, entry.bar); entry.bar:Destroy(); entry.bar = nil end
end

local function createMsgLabel(text, theme, entry)
local lbl = Create("TextLabel", { Name = "Message", BackgroundTransparency = 1, Text = text,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = entry.frame })
addPart(entry, lbl, "TextTransparency", 0)
return Create.text(lbl, theme, "muted")
end


local function stopSpin(entry)
if entry.spin then entry.spin.Cancel(); entry.spin = nil end
end




local function typeFeedback(entry)
local theme = entry.theme
if entry.type == "success" then
if entry.icon then Animate.pop(entry.icon, "enter") end
elseif entry.type == "error" and entry.frame and Animate.isEnabled() then
local sh = theme.Motion.shake
Animate.chain({
{ entry.frame, sh.step, { Rotation = -sh.amp }, Enum.EasingStyle.Sine },
{ entry.frame, sh.step, { Rotation = sh.amp }, Enum.EasingStyle.Sine },
{ entry.frame, sh.step, { Rotation = 0 }, Enum.EasingStyle.Sine },
})
end
end



local function reskin(entry)
local theme = entry.theme
local accent = accentFor(theme, entry.type)
entry.accent = accent
entry.frame.BackgroundColor3 = theme.Colors.card
if entry.stroke then entry.stroke.Color = edgeColor(theme, accent) end
if entry.badge then entry.badge.BackgroundColor3 = accent end
entry.titleLabel.TextColor3 = theme.Colors.foreground
if entry.msgLabel then entry.msgLabel.TextColor3 = theme.Colors.mutedForeground end

if entry.closeHandle then entry.closeHandle.reskin() end
if entry.actionHover then entry.actionHover.reskin() end
if entry.actionBtn then
entry.actionBtn.BackgroundColor3 = theme.Colors.surface
entry.actionBtn.TextColor3 = theme.Colors.foreground
end
if entry.bar then entry.bar.BackgroundColor3 = accent end


if entry.icon then Icons.apply(entry.icon, TYPE_ICON[entry.type] or "info", accent) end
end



local function releaseEntry(entry)
if entry.unreg then entry.unreg(); entry.unreg = nil end
local rel = entry.releases
if not rel then return end
for i = #rel, 1, -1 do local fn = rel[i]; rel[i] = nil; pcall(fn) end
end

local function msgText(v, arg)
if type(v) == "function" then local ok, r = pcall(v, arg); return ok and r or nil end
if type(v) == "string" then return v end
return nil
end

local applyUpdate

function Notification.show(opts)
if not enabled then return nil end
opts = opts or {}
local theme = opts.Theme or DefaultTheme
seq = seq + 1
local id = seq
local entry = { id = id, onDismiss = opts.OnDismiss, releases = {}, parts = {}, alpha = 1 }
order[#order + 1] = entry
Safe.mutate(function()
local TK = theme.Toast
local ty = opts.Type or "info"
local accent = accentFor(theme, ty)
ensureContainer(theme)
ensureStackShadow(theme)
ensureTicker()
local pcfg = POS[position] or POS["bottom-right"]

local sx = (pcfg.ax == 1 and UDim.new(1, TK.slide)) or (pcfg.ax == 0 and UDim.new(0, -TK.slide)) or UDim.new(0.5, 0)

local sy = (pcfg.ax == 0.5) and UDim.new(pcfg.ay, ((pcfg.ay == 0) and -1 or 1) * TK.slide) or UDim.new(pcfg.ay, 0)
local hasBar = (ty ~= "loading") and ((opts.Duration or 4000) > 0)
local padding = Create.padding({ left = TK.padX, right = TK.padX, top = TK.padY,
bottom = hasBar and TK.progressInset or TK.padY })
local toast = Create("Frame", {
Name = "Toast", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0,
AnchorPoint = Vector2.new(pcfg.ax, pcfg.ay), Position = UDim2.new(sx.Scale, sx.Offset, sy.Scale, sy.Offset),
Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = container,
Create.corner(theme.Radius.md), padding,
Create.listLayout({ Padding = 4 }),
})

local stroke = Create.stroke(edgeColor(theme, accent), 1, theme.Stroke.floating)
stroke.Parent = toast

entry.frame = toast
addPart(entry, toast, "BackgroundTransparency", 0)
addPart(entry, stroke, "Transparency", theme.Stroke.floating)

local scale = Create("UIScale", { Scale = theme.Motion.enterScale, Parent = toast })
entry.entering = true
local sizeConn = toast:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()






Safe.mutate(function() Notification.relayout("measure") end)
end)
entry.releases[#entry.releases + 1] = function() sizeConn:Disconnect() end
local titleRow = Create("Frame", { Name = "TitleRow", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = toast })


local badge = Create("Frame", { Name = "IconBadge", BackgroundColor3 = accent,
BackgroundTransparency = TK.badgeAlpha, BorderSizePixel = 0, ZIndex = 0, Active = false,
Size = UDim2.new(0, BADGE, 0, BADGE), Position = UDim2.new(0, -2, 0.5, -BADGE / 2),
Parent = titleRow, Create.corner(theme.Radius.sm) })
local tIcon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon),
Position = UDim2.new(0, 0, 0.5, -theme.Sizes.icon / 2), Parent = titleRow })
Icons.apply(tIcon, TYPE_ICON[ty] or "info", accent)
addPart(entry, badge, "BackgroundTransparency", TK.badgeAlpha)
addPart(entry, tIcon, "ImageTransparency", 0)
local titleX = BADGE + theme.Spacing.icon
local titleLabel = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Title or "",
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, -(titleX + theme.Sizes.icon), 1, 0), Position = UDim2.new(0, titleX, 0, 0), Parent = titleRow })
Create.text(titleLabel, theme, "label")
addPart(entry, titleLabel, "TextTransparency", 0)
local closeBtn = Create("ImageButton", { Name = "Close", AutoButtonColor = false, BackgroundTransparency = 1,
Size = UDim2.new(0, theme.Sizes.iconSm, 0, theme.Sizes.iconSm),
Position = UDim2.new(1, -theme.Sizes.iconSm, 0, 0), Parent = titleRow })


local closeHandle = Recipes.iconButton(closeBtn, { theme = theme, icon = "x", rest = "primary",
hover = "foreground", parent = titleRow, onClick = function() Notification.dismiss(id) end })
entry.releases[#entry.releases + 1] = closeHandle.disconnect
addPart(entry, closeBtn, "ImageTransparency", 0)
local msgLabel
if opts.Message then
msgLabel = createMsgLabel(opts.Message, theme, entry)
end
local aBtn, actionHover
if opts.Action then
local act = opts.Action
aBtn = Create("TextButton", { Name = "Action", AutoButtonColor = false,
BackgroundColor3 = theme.Colors.surface, Text = act.Text or act.Label or "Action",
TextColor3 = theme.Colors.foreground,
Size = UDim2.new(0, 96, 0, 24), LayoutOrder = 3, Parent = toast, Create.corner(theme.Radius.sm) })
Create.text(aBtn, theme, "muted")
addPart(entry, aBtn, "BackgroundTransparency", 0)
addPart(entry, aBtn, "TextTransparency", 0)

actionHover = Recipes.hover(aBtn, { theme = theme, corner = theme.Radius.sm, kind = "wash" })
entry.releases[#entry.releases + 1] = actionHover.disconnect
aBtn.MouseButton1Click:Connect(function() if act.Callback then pcall(act.Callback) end; Notification.dismiss(id) end)
end
entry.frame = toast; entry.scale = scale; entry.stroke = stroke; entry.padding = padding
entry.icon = tIcon; entry.badge = badge; entry.titleLabel = titleLabel
entry.closeBtn = closeBtn; entry.closeHandle = closeHandle
entry.actionBtn = aBtn; entry.actionHover = actionHover
entry.theme = theme
entry.type = ty; entry.accent = accent
entry.msgLabel = msgLabel
if entry.type == "loading" then entry.spin = Animate.spin(tIcon) end
if hasBar then startCountdown(entry, (opts.Duration or 4000) / 1000, accent, theme) end


if opts.AccentReg then entry.unreg = opts.AccentReg(function() reskin(entry) end) end
Notification.relayout()
typeFeedback(entry)
if entry.pendingUpdate then applyUpdate(entry, entry.pendingUpdate); entry.pendingUpdate = nil end
end)
return id
end

function Notification.loading(opts)
opts = opts or {}
opts.Type = "loading"; opts.Duration = 0
return Notification.show(opts)
end

applyUpdate = function(entry, opts)
local theme = entry.theme
local newType = opts.Type or entry.type
local accent = accentFor(theme, newType)
local morphed = newType ~= entry.type
entry.type = newType; entry.accent = accent


stopSpin(entry)
if entry.stroke then entry.stroke.Color = edgeColor(theme, accent) end
if entry.badge then entry.badge.BackgroundColor3 = accent end
if entry.icon then
Icons.apply(entry.icon, TYPE_ICON[newType] or "info", accent)
if newType == "loading" then entry.spin = Animate.spin(entry.icon) end
end
if opts.Title ~= nil and entry.titleLabel then entry.titleLabel.Text = opts.Title end
if opts.Message ~= nil then
if entry.msgLabel then
entry.msgLabel.Text = opts.Message
else
entry.msgLabel = createMsgLabel(opts.Message, theme, entry)
end
end
if opts.Duration and opts.Duration > 0 then
dropBar(entry)
startCountdown(entry, opts.Duration / 1000, accent, theme)
elseif opts.Duration == 0 then
dropBar(entry)
entry.total = nil; entry.remaining = nil
setProgressPad(entry, false)
end
if morphed then typeFeedback(entry) end
Notification.relayout()
end

function Notification.update(id, opts)
local i = indexOf(id); if not i then return end
local entry = order[i]
opts = opts or {}
Safe.mutate(function()
if not entry.frame then entry.pendingUpdate = opts; return end
applyUpdate(entry, opts)
end)
end

function Notification.promise(runner, opts)
opts = opts or {}





local pendingId
RunService.Heartbeat:Once(function()
local ok, res = pcall(runner)
local dur = opts.Duration or 4000
if ok then
Notification.update(pendingId, { Type = "success", Title = msgText(opts.Success, res) or "Success", Duration = dur })
else
Notification.update(pendingId, { Type = "error", Title = msgText(opts.Error, res) or "Error", Duration = dur })
end
if opts.Finally then pcall(opts.Finally) end
end)
local words = (opts.Theme and opts.Theme.Strings) or DefaultTheme.Strings
local id = Notification.loading({
Title = msgText(opts.Loading) or words.Loading, Message = opts.Message, Theme = opts.Theme, AccentReg = opts.AccentReg })
pendingId = id
return id
end



local function exitOffset(cfg, TK)
if cfg.ax == 1 then return TK.exitSlide, 0 end
if cfg.ax == 0 then return -TK.exitSlide, 0 end
return 0, (cfg.ay == 0) and -TK.exitSlide or TK.exitSlide
end

function Notification.dismiss(id)
local i = indexOf(id)
if not i then return end


local entry = table.remove(order, i)
if #order == 0 then stopTicker() end
if entry.onDismiss then pcall(entry.onDismiss) end


Safe.mutate(function()
stopSpin(entry)
freezeBar(entry)
releaseEntry(entry)
local frame = entry.frame
if not frame then Notification.relayout(); return end
local TK = (entry.theme or DefaultTheme).Toast
local cfg = POS[position] or POS["bottom-right"]
local dx, dy = exitOffset(cfg, TK)
local p = frame.Position
local slide = p and { Position = UDim2.new(p.X.Scale, p.X.Offset + dx, p.Y.Scale, p.Y.Offset + dy) } or nil


if entry.scale then
Animate.to(entry.scale, "exit", { Scale = TK.exitScale }, Animate.EASING.exit, Animate.DIR.In)
end
fadeTo(entry, 1, "exit", Animate.EASING.exit, Animate.DIR.In, nil, slide, function()
frame:Destroy()
Notification.relayout()
end)
end)
end

function Notification.clearAll()
for i = #order, 1, -1 do Notification.dismiss(order[i].id) end



pinnedScale = nil
end

function Notification.count() return #order end



function Notification.setScale(n)
if type(n) ~= "number" or n ~= n or n <= 0 then return currentScale() end
pinnedScale = n
if container and container.Parent ~= nil then
Safe.mutate(function()
local us = container:FindFirstChild("ContainerScale")
if us then us.Scale = n end
end)
end
return n
end

function Notification.setPosition(p)
local key = tostring(p):lower():gsub("%s+", "-")
if not POS[key] then return position end
position = key
if container and container.Parent ~= nil then
Safe.mutate(function()
local cfg = POS[position]
container.AnchorPoint = Vector2.new(cfg.ax, cfg.ay)
container.Position = containerPosition(cfg, frontTheme().Toast)
Notification.relayout()
end)
end
return position
end

return Notification

end


EmbeddedModules["components/card"] = function()


local Card = {}
local Create, DefaultTheme, Maid, Asset, Button, Safe

function Card.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Asset = R.Asset; Button = R.Button; Safe = R.Safe
end

function Card.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()

local card = Create("Frame", { Name = "Card", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0,
AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent, Create.corner(theme.Radius.md),
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX, top = theme.Spacing.inputY, bottom = theme.Spacing.inputY }),
Create.listLayout({ Padding = theme.Spacing.gap }) })
Create.stroke(theme.Colors.border, 1).Parent = card

local lo = 0
local banner
local function makeBanner(image)
lo = lo + 1
banner = Create("ImageLabel", { Name = "Banner", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
Image = image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = lo,
Parent = card, Create.corner(theme.Radius.sm) })
end
if Asset.resolvable(opts.Banner) then



makeBanner("")
Asset.imageAsync(opts.Banner, function(id) Safe.mutate(function() banner.Image = id end) end)
else
local resolved = Asset.image(opts.Banner)
if resolved then makeBanner(resolved) end
end
if opts.Title then
lo = lo + 1
Create.text(Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Title,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = lo, Parent = card }),
theme, "label")
end
if opts.Body then
lo = lo + 1
Create.text(Create("TextLabel", { Name = "Body", BackgroundTransparency = 1, Text = opts.Body,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y,
Size = UDim2.new(1, 0, 0, 0), LayoutOrder = lo, Parent = card }), theme, "muted")
end
if opts.Buttons and #opts.Buttons > 0 then
lo = lo + 1
local row = Create("Frame", { Name = "Actions", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34),
LayoutOrder = lo, Parent = card,
Create.listLayout({ Padding = theme.Spacing.gap, FillDirection = Enum.FillDirection.Horizontal }) })
for i, b in ipairs(opts.Buttons) do



local control = Button.new({ Parent = row, Text = b.Text, Variant = b.Variant, Callback = b.Callback,
Theme = theme, AccentReg = opts.AccentReg, AutoWidth = true, LayoutOrder = i })
maid:Give(control)
end
end

if opts.AccentReg then maid:Give(opts.AccentReg(function()
card.BackgroundColor3 = theme.Colors.card
local st = card:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
if banner then banner.BackgroundColor3 = theme.Colors.surface end
local ti = card:FindFirstChild("Title"); if ti then ti.TextColor3 = theme.Colors.foreground end
local bo = card:FindFirstChild("Body"); if bo then bo.TextColor3 = theme.Colors.mutedForeground end
end)) end

maid:Give(card)
return { Frame = card, Destroy = function() maid:DoCleanup() end }
end

return Card

end


EmbeddedModules["components/dialog"] = function()




local Dialog = {}
local Create, DefaultTheme, Maid, Overlay, Button, Acrylic, Animate, Icons, Device, Effects, Theme
local UserInputService = game:GetService("UserInputService")
local KC = Enum.KeyCode


local stack = {}



local handledInput = nil

function Dialog.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Button = R.Button; Acrylic = R.Acrylic
Animate = R.Animate; Icons = R.Icons; Device = R.Device; Effects = R.Effects; Theme = R.Theme
for i = #stack, 1, -1 do stack[i] = nil end
handledInput = nil
end

local MARGIN = 24
local CLOSE_SCALE = 0.92
local BADGE_TINT = 0.15


local function zOf(n) return Overlay.Z.modal + n end
local function mix(theme, a, b, t) return (theme.mix or Theme.mix)(a, b, t) end
local function modeVal(theme, tok) return (theme.modeVal or Theme.modeVal)(theme, tok) end


local function badgeColor(theme, icon) return mix(theme, theme.Colors.surface, icon, BADGE_TINT) end


local function resolveWidth(opts)
local want = opts.Width or 320
local avail
if opts.Window and opts.Window.Main then
local s = opts.Window.Main.AbsoluteSize; avail = s and s.X
else
local vp = Overlay.viewport(); avail = vp and vp.X
end
if avail and avail > 0 then
local max = avail - MARGIN * 2
if max > 0 and want > max then want = max end
end
return want
end



local function cardSkin(theme) return { solid = true, strokeAlpha = theme.Stroke.floating } end


local function titleLabel(parent, theme, opts, xAlign, props)
local lbl = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Title or "Dialog",
TextColor3 = theme.Colors.foreground, TextXAlignment = xAlign, ZIndex = zOf(2), Parent = parent })
for k, v in pairs(props) do lbl[k] = v end
return Create.text(lbl, theme, "title")
end




local function buildHeader(card, theme, opts)

local function iconColor() return opts.IconColor or theme.Colors.foreground end
local parts = { iconColor = iconColor }
if opts.Icon and opts.IconBadge then
local header = Create("Frame", { Name = "Header", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = zOf(2), Parent = card })
Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, theme.Spacing.gap),
HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = header })
parts.badge = Create("Frame", { Name = "IconBadge", BackgroundColor3 = badgeColor(theme, iconColor()),
Size = UDim2.new(0, 40, 0, 40), LayoutOrder = 1, ZIndex = zOf(2), Parent = header, Create.corner(theme.Radius.md) })
parts.icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 20, 0, 20), ZIndex = zOf(3), Parent = parts.badge })
Icons.apply(parts.icon, opts.Icon, iconColor())
parts.title = titleLabel(header, theme, opts, Enum.TextXAlignment.Center,
{ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2 })
return true, parts
elseif opts.Icon then
local gap = theme.Spacing.icon
local header = Create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22),
LayoutOrder = 1, ZIndex = zOf(2), Parent = card })
parts.icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), ZIndex = zOf(2), Parent = header })
Icons.apply(parts.icon, opts.Icon, iconColor())
parts.title = titleLabel(header, theme, opts, Enum.TextXAlignment.Left,
{ Position = UDim2.new(0, 16 + gap, 0, 0), Size = UDim2.new(1, -(16 + gap), 1, 0) })
return false, parts
else
parts.title = titleLabel(card, theme, opts, Enum.TextXAlignment.Left,
{ Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 })
return false, parts
end
end




local function buildFooter(card, theme, buttons, touch, fire, maid, accentReg)
local n = #buttons
local row = Create("Frame", { Name = "Buttons", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, touch and 0 or 34),
AutomaticSize = touch and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
LayoutOrder = 4, ZIndex = zOf(2), Parent = card })
Create("UIListLayout", {
FillDirection = touch and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
HorizontalAlignment = touch and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right,
SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, theme.Spacing.gap), Parent = row })
for i, b in ipairs(buttons) do
local order = touch and (n - i + 1) or i
local btn = Button.new({ Parent = row, LayoutOrder = order, Theme = theme, Text = b.Text or "OK",
Variant = b.Variant, Icon = b.Icon, AutoWidth = not touch, AccentReg = accentReg,
Callback = function() fire(b) end })
maid:Give(btn)
end
end

function Dialog.open(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local buttons = opts.Buttons or { { Text = "OK" } }
local handle = {}
local touch = Device and Device.IsTouch() or false
local width = resolveWidth(opts)
local modal = opts.Modal ~= false

Overlay.closeAll()


local depth = Overlay.pushDialog()
local function scrimAlpha() return modeVal(theme, theme.Opacity.dialogScrim) end
local scrimGoal = (modal and depth == 1) and scrimAlpha() or 1

local dim = Create("TextButton", { Name = "Dialog", AutoButtonColor = false, Text = "",
BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 1, 0), ZIndex = Overlay.Z.modal, Modal = modal })


local card = Create("CanvasGroup", { Name = "Card", Size = UDim2.new(0, width, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1,
AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), ZIndex = zOf(1), Parent = dim,
Create.corner(theme.Radius.lg), Create.padding({ all = theme.Spacing.pad }),
Create.listLayout({ Padding = theme.Spacing.gap }) })


local base = opts.Window and 1 or Overlay.scale()
local us = Create("UIScale", { Scale = base * theme.Motion.enterScale, Parent = card })
Acrylic.decorate(card, theme, cardSkin(theme))
local stroke = card:FindFirstChildOfClass("UIStroke")
Effects.rim(stroke, theme)


local shadow = Effects.shadow(dim, theme, { name = "DialogShadow", level = "dialog", zIndex = Overlay.Z.modal })
if shadow then shadow.ImageTransparency = 1 end

local centered, parts = buildHeader(card, theme, opts)
local message
if opts.Message then
message = Create("TextLabel", { Name = "Message", BackgroundTransparency = 1, Text = opts.Message,
TextColor3 = theme.Colors.mutedForeground,
TextXAlignment = centered and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = zOf(2), Parent = card })
Create.text(message, theme, "body")
end



local rule
if not touch then
rule = Create("Frame", { Name = "FooterRule", BackgroundColor3 = theme.Colors.border,
BackgroundTransparency = theme.Stroke.divider, BorderSizePixel = 0,
Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 3, ZIndex = zOf(2), Parent = card })
end

local closing = false


if opts.AccentReg then maid:Give(opts.AccentReg(function()
Acrylic.reskin(card, theme, cardSkin(theme))
Effects.rim(stroke, theme)
Effects.reskin(shadow, theme, "shadow")
if modal and depth == 1 and not closing then dim.BackgroundTransparency = scrimAlpha() end
if rule then rule.BackgroundColor3 = theme.Colors.border end
parts.title.TextColor3 = theme.Colors.foreground
if message then message.TextColor3 = theme.Colors.mutedForeground end
if parts.badge then parts.badge.BackgroundColor3 = badgeColor(theme, parts.iconColor()) end
if parts.icon then Icons.apply(parts.icon, opts.Icon, parts.iconColor()) end
end)) end

local function popSelf()
for i = #stack, 1, -1 do if stack[i] == handle then table.remove(stack, i); break end end
end

function handle.Close()
if closing then return end
closing = true
popSelf()
Overlay.popDialog()
dim.Modal = false
dim.Active = false

Animate.to(us, "exit", { Scale = base * CLOSE_SCALE }, Animate.EASING.exit, Animate.DIR.In)
Animate.to(card, "exit", { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, theme.Motion.dialogDrop) },
Animate.EASING.exit, Animate.DIR.In)
if shadow then Animate.to(shadow, "exit", { ImageTransparency = 1 }, Animate.EASING.exit, Animate.DIR.In) end
Animate.toThen(dim, "exit", { BackgroundTransparency = 1 }, function() maid:DoCleanup(); dim:Destroy() end,
Animate.EASING.exit, Animate.DIR.In)
end


local function fire(b)
if b and b.Callback then b.Callback() end
handle.Close()
end
buildFooter(card, theme, buttons, touch, fire, maid, opts.AccentReg)

maid:Give(dim)



local winFrame = opts.Window and opts.Window.Main
if winFrame then
Create.corner(theme.Radius.window).Parent = dim
dim.Parent = winFrame
else
Overlay.mount(dim)
end
if shadow then Effects.follow(shadow, card, "dialog", theme, maid) end



stack[#stack + 1] = handle
maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
if gameProcessed or closing then return end
if handledInput ~= nil and handledInput == input then return end



if dim.Parent == nil then handle.Close(); return end




if stack[#stack] ~= handle then return end
local k = input and input.KeyCode
if k == nil then return end
if k == KC.Escape or k == KC.ButtonB then
handledInput = input; handle.Close()
elseif k == KC.Return or k == KC.ButtonA then
handledInput = input; fire(buttons[#buttons])
end
end))


card.Position = UDim2.new(0.5, 0, 0.5, theme.Motion.dialogRise)
Animate.to(dim, "base", { BackgroundTransparency = scrimGoal })
Animate.to(card, "base", { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) }, Animate.EASING.smooth)
Animate.springTo(us, "enter", { Scale = base })
if shadow then Animate.to(shadow, "base", { ImageTransparency = (theme.fx or Theme.fx)(theme).shadow }) end
return handle
end

return Dialog

end


EmbeddedModules["components/resizable"] = function()

local Resizable = {}
local Create, DefaultTheme, Maid, Icons, Host, REG, Drag, Device, Animate, Recipes

function Resizable.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Icons = R.Icons; Host = R.Host; REG = R
Drag = R.Drag; Device = R.Device; Animate = R.Animate; Recipes = R.Recipes
end

function Resizable.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local horizontal = (opts.Direction or "Horizontal") == "Horizontal"
local defs = opts.Panes or { {}, {} }
local n = #defs
local fr, total = {}, 0
for i = 1, n do fr[i] = defs[i].Default or (1 / n); total = total + fr[i] end
for i = 1, n do fr[i] = fr[i] / total end

local container = Create("Frame", { Name = "Resizable", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, opts.Height or (horizontal and 160 or 200)),
LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent })




local GAP = theme.Sizes.splitGap
local handleW = Device.IsTouch() and theme.Sizes.touchHit or GAP

local paneFrames, panes, handles, gripPaint = {}, {}, {}, {}

local function applyLayout()
local cum = 0
for i = 1, n do
local f = paneFrames[i]
if horizontal then
f.Position = UDim2.new(cum, (i > 1) and GAP / 2 or 0, 0, 0)
f.Size = UDim2.new(fr[i], (n > 1) and -GAP or 0, 1, 0)
else
f.Position = UDim2.new(0, 0, cum, (i > 1) and GAP / 2 or 0)
f.Size = UDim2.new(1, 0, fr[i], (n > 1) and -GAP or 0)
end
cum = cum + fr[i]
if i < n and handles[i] then
if horizontal then
handles[i].Position = UDim2.new(cum, -handleW / 2, 0, 0); handles[i].Size = UDim2.new(0, handleW, 1, 0)
else
handles[i].Position = UDim2.new(0, 0, cum, -handleW / 2); handles[i].Size = UDim2.new(1, 0, 0, handleW)
end
end
end
end

for i = 1, n do
local pane = Create("Frame", { Name = "Pane", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0,
ClipsDescendants = true, Parent = container, Create.corner(theme.Radius.md), Create.padding({ all = 8 }),
Create.listLayout({ Padding = theme.Spacing.gap }) })


Create.stroke(theme.Colors.border, 1, theme.Stroke.control).Parent = pane
paneFrames[i] = pane
local order = 0
local paneApi = { Frame = pane }


Host.attach(paneApi, { R = REG, content = pane, theme = theme, config = opts.Config, window = opts.Window,
registerSearchable = opts.RegisterSearchable, accentThemer = opts.AccentThemer,
registerControl = opts.RegisterControl,
nextOrder = function() order = order + 1; return order end })
panes[i] = paneApi
end

for k = 1, n - 1 do
local handle = Create("ImageButton", { Name = "Handle", AutoButtonColor = false,
BackgroundTransparency = 1, ZIndex = 5, Parent = container })
Create("Frame", { Name = "Line", BackgroundColor3 = theme.Colors.border, BorderSizePixel = 0, ZIndex = 5,
Parent = handle,
Size = horizontal and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1),
Position = horizontal and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0.5, 0),
AnchorPoint = horizontal and Vector2.new(0.5, 0) or Vector2.new(0, 0.5) })
local grip = Create("Frame", { Name = "Grip", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
ZIndex = 6, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
Size = horizontal and UDim2.new(0, 8, 0, 16) or UDim2.new(0, 16, 0, 8),
Parent = handle, Create.corner(theme.Radius.sm) })
Create.stroke(theme.Colors.border, 1).Parent = grip


local gripScale = Create("UIScale", { Scale = 1, Parent = grip })
local gi = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 8, 0, 8),
Position = UDim2.new(0.5, -4, 0.5, -4), Parent = grip })
local glyph = horizontal and "grip-vertical" or "grip-horizontal"
Icons.apply(gi, glyph, theme.Colors[theme.Icon.structural])



local hover = Recipes.hover(handle, { theme = theme, kind = "text", icon = gi,
rest = theme.Icon.structural, hover = theme.Icon.structuralActive })
maid:Give(hover.disconnect)
local function paintGrip()
Icons.apply(gi, glyph, theme.Colors[theme.Icon.structural])
hover.reskin()
end
gripPaint[k] = paintGrip
handles[k] = handle





local fr0L, fr0R
Drag.bind(handle, {
onBegin = function()
fr0L, fr0R = fr[k], fr[k + 1]
Animate.to(gripScale, "fast", { Scale = theme.Motion.handleGrow })
end,
onChange = function(dx, dy)
if not fr0L then return end
local sz = container.AbsoluteSize
local span = (sz and (horizontal and sz.X or sz.Y)) or 1
if span <= 0 then span = 1 end
local d = (horizontal and dx or dy) / span
local minL, minR = (defs[k].Min or 0.1), (defs[k + 1].Min or 0.1)
local nl, nr = fr0L + d, fr0R - d
if nl >= minL and nr >= minR then fr[k] = nl; fr[k + 1] = nr; applyLayout() end
end,
onEnd = function()
fr0L, fr0R = nil, nil
Animate.springTo(gripScale, "release", { Scale = 1 })
end,
}, maid)
end

applyLayout()

if opts.AccentThemer then maid:Give(opts.AccentThemer.register(function()
for _, f in ipairs(paneFrames) do
f.BackgroundColor3 = theme.Colors.card
local ps = f:FindFirstChildOfClass("UIStroke"); if ps then ps.Color = theme.Colors.border end
end
for k, hd in ipairs(handles) do
local line = hd:FindFirstChild("Line"); if line then line.BackgroundColor3 = theme.Colors.border end
local grip = hd:FindFirstChild("Grip")
if grip then
grip.BackgroundColor3 = theme.Colors.surface
local st = grip:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
end
if gripPaint[k] then gripPaint[k]() end
end
end)) end

maid:Give(container)
return { Frame = container, Panes = panes, Destroy = function() maid:DoCleanup() end }
end

return Resizable

end


EmbeddedModules["core/theme"] = function()
local Theme = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end





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

Motion = {
fast = 0.12, base = 0.18, slow = 0.28,
enter = 0.28, exit = 0.14, hover = 0.12, press = 0.08, release = 0.22, stagger = 0.035,
enterScale = 0.94, exitScale = 0.96, pressScale = 0.97, hoverScale = 1.06, popFrom = 0.9,
knobStretch = 1.2, handleGrow = 1.3, handleHover = 1.15, spin = 0.8, snap = 0.3, hideDrift = 12,
popSlide = 6, dialogRise = 12, dialogDrop = 8, bumpPx = 2, copyRevert = 1.2, pulse = 0.4,
shake = { amp = 3, steps = 4, step = 0.04 },
cascade = { x = 6, y = 8 },
},



Effect = {
shadowId = "rbxassetid://91077512535886", slice = { x0 = 49, y0 = 49, x1 = 450, y1 = 450 },
window = { spread = 28, offsetY = 6 }, dialog = { spread = 32, offsetY = 10 }, popover = { spread = 18, offsetY = 4 },
toast = { spread = 16, offsetY = 4 }, tooltip = { spread = 10, offsetY = 2 }, control = { spread = 6, offsetY = 0 },
lift = { spreadDelta = 8, alphaDelta = -0.12 }, controlGlow = "auto",
skeleton = { period = 1.1, rotation = 15 },
},

Stroke = {
window = 0.3, floating = 0, control = 0, divider = 0.4, focusThickness = 2,
panel = { dark = 0.6, light = 0 }, search = { dark = 0.8, light = 0.5 },


track = 0.5, knob = 0.7, pulse = { low = 0.2, high = 0.7 },
},
Opacity = {
hoverWash = 0.94, pressWash = 0.9, hoverFill = 0.12, pressFill = 0.2, ghostHover = 0.4, ghostPress = 0.25,
tabHover = 0.92, tabPress = 0.88, optionHover = 0.6, rowHover = 0.94, disabled = 0.5, scrim = 0.45,
dialogScrim = { dark = 0.5, light = 0.6 }, glowHover = 0.7,
flash = 0.35,
},


Acrylic = { noiseId = "rbxassetid://9968344105", tileSize = 128, strokeAlpha = 0.3, highlightBand = 0.45, frost = 0.12, glintFade = 0.25, popoverFrost = 0.04 },
Scrollbar = { imageId = "", alpha = 0.35 },
Sizes = {
icon = 16, iconSm = 14, iconButton = 26, touchHit = 44, scrollbar = 4, progress = 8, sliderHit = 24, chip = 22,
knob = 20, tagMeasureFudge = 1.08, dragKeep = 40, dragThreshold = 6,
titleBar = 40, titleBarTall = 56,
resizeGrip = 12, resizeGripInset = 4, splitGap = 12,
indicator = { w = 3, h = 18, stretch = 26, radius = 2, haloW = 9, haloH = 26, haloAlpha = 0.85 },
grip = { w = 2, h = 24 },
fab = { size = 44, simple = 50, peek = 15, hoverPeek = 7, margin = 16, radius = 12, popFrom = 0.6 },
},

Icon = { structural = "mutedForeground", structuralActive = "foreground", accent = "primary" },
Tooltip = { delay = 0.35, gap = 6, padX = 8, height = 24 },
Toast = {
width = 300, inset = 16, gap = 8, peek = 10, maxVisible = 3, peekScale = 0.05, peekFade = 0.18, barHeight = 3,
padX = 12, padY = 8, progressInset = 0, slide = 48, exitSlide = 32, exitScale = 0.95, typeTint = 0.35,
badgeAlpha = 0.85, staggerCap = 5,
},


Strings = {
Search = "Search…", None = "None", Select = "Select", Loading = "Loading…",
NoResults = "No results", NoMatches = "No matches", NoRows = "No rows",
CloseTitle = "Close window?",
CloseMessage = "This closes it for good; run the script again to get it back. To just hide it, minimize it with the – button next to the X.",
Cancel = "Cancel", Close = "Close",
ResetTitle = "Reset settings?", ResetMessage = "This restores all options to their defaults.",
Reset = "Reset", ResetDone = "Settings restored to defaults.",
},
}

Theme.PALETTES = {
dark = DEFAULT.Colors,


light = {
background = rgb(240, 240, 243), card = rgb(255, 255, 255), surface = rgb(244, 244, 245),
border = rgb(228, 228, 231), input = rgb(250, 250, 250), ring = rgb(24, 24, 27),
mutedForeground = rgb(113, 113, 122), foreground = rgb(24, 24, 27),
primary = rgb(24, 24, 27), primaryForeground = rgb(250, 250, 250),
destructive = rgb(239, 68, 68), success = rgb(34, 197, 94), warning = rgb(234, 179, 8),
info = rgb(59, 130, 246), switchTrackOff = rgb(212, 212, 216),
},
}





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


function Theme.applyMode(theme, mode)
local p = Theme.PALETTES[mode] or Theme.PALETTES.dark
for k, v in pairs(p) do
if k ~= "primary" and k ~= "primaryForeground" then theme.Colors[k] = v end
end
theme.Mode = mode
return theme
end


function Theme.fx(theme)
local mode = type(theme) == "table" and theme.Mode or nil
return Theme.MODE_EFFECTS[mode] or Theme.MODE_EFFECTS.dark
end




function Theme.modeVal(theme, tok)
if type(tok) ~= "table" or (tok.dark == nil and tok.light == nil) then return tok end
local mode = type(theme) == "table" and theme.Mode or nil
local v = mode and tok[mode]
if v == nil then v = tok.dark end
return v
end



function Theme.mix(a, b, t)

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


for k, v in pairs(DEFAULT) do Theme[k] = v end









local faceCache = {}

function Theme.FontFace(weight)
if not (Font and Font.fromName) then return nil end
if weight == nil then weight = Enum.FontWeight.Regular end
if weight == Enum.FontWeight.SemiBold then weight = Enum.FontWeight.Bold end


local hit = faceCache[weight]
if hit ~= nil then return hit end
local face = Font.fromName("BuilderSans", weight)
faceCache[weight] = face
return face
end

function Theme.new(overrides)
overrides = overrides or {}
local t = deepMerge(DEFAULT, overrides)

t.FontFace = Theme.FontFace
t.fx = Theme.fx
t.modeVal = Theme.modeVal
t.mix = Theme.mix
t.new = Theme.new
return t
end

return Theme

end


EmbeddedModules["components/label"] = function()

local Label = {}
local Create, DefaultTheme, Safe
local RunService = game:GetService("RunService")
local warn = warn or function() end


local spawn = (type(task) == "table" and task.spawn) or function(fn) return fn() end

function Label.Init(R) Create = R.Create; DefaultTheme = R.Theme; Safe = R.Safe end










local entries = {}
local conn = nil

local function stepAll(dt)
dt = dt or 0
local alive, n = {}, 0
for _, e in ipairs(entries) do
e.acc = e.acc + dt
local keep = true
if e.acc >= e.interval then e.acc = 0; keep = e.tick() end
if keep then n = n + 1; alive[n] = e end
end
entries = alive
if n == 0 and conn then conn:Disconnect(); conn = nil end
end

local function register(entry)
entries[#entries + 1] = entry
if not conn then conn = RunService.Heartbeat:Connect(stepAll) end
end

local function unregister(entry)
for i = #entries, 1, -1 do if entries[i] == entry then table.remove(entries, i) end end
if #entries == 0 and conn then conn:Disconnect(); conn = nil end
end

function Label.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local variant = opts.Variant or "default"
local source = opts.Text or ""
local interval = opts.Interval or 1

local color = (variant == "default") and theme.Colors.foreground or theme.Colors.mutedForeground

local role = (variant == "section") and "overline" or "body"
local size = theme.Font[role].Size

local frame = Create.text(Create("TextLabel", {
Name = "Label",
BackgroundTransparency = 1,
Text = "",
TextColor3 = color,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = variant == "paragraph",
Size = UDim2.new(1, 0, 0, size + 6),
AutomaticSize = (variant == "paragraph") and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent,
}), theme, role)


local unreg = opts.AccentReg and opts.AccentReg(function()
frame.TextColor3 = (variant == "default") and theme.Colors.foreground or theme.Colors.mutedForeground
end)

local lastText, erroring, entry = nil, false, nil






local function applyText(s, direct)
s = (variant == "section") and string.upper(tostring(s)) or tostring(s)
if s == lastText then return end
lastText = s
if direct then frame.Text = s else Safe.mutate(function() frame.Text = s end) end
end








local function evaluate()
if type(source) ~= "function" then return end
local fn = source
spawn(function()
local ok, res = pcall(fn)
if fn ~= source then return end
if ok then
erroring = false
applyText(res, false)
elseif not erroring then
erroring = true
warn("[EzUI] Label dynamic text error: " .. tostring(res))
end
end)
end

local function startReactive()
if entry then return end
entry = { acc = 0, interval = interval, tick = function()




local ok, parent = pcall(function() return frame.Parent end)
if ok and parent == nil then return false end
evaluate()
return true
end }
register(entry)
end

local function stopReactive()
if entry then unregister(entry); entry = nil end
end



local function setSource(v, direct)
source = v
if type(v) == "function" then
startReactive()
evaluate()
else
stopReactive()
applyText(v, direct)
end
end

setSource(source, true)

return {
Frame = frame,
SetText = function(v) setSource(v, false) end,
Destroy = function() stopReactive(); if unreg then unreg() end; frame:Destroy() end,
}
end

return Label

end


EmbeddedModules["components/colorpicker"] = function()


local ColorPicker = {}
local Create, DefaultTheme, Maid, Overlay, Flag, Animate, Safe, Recipes, Effects, Acrylic
local UserInputService = game:GetService("UserInputService")
function ColorPicker.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Flag = R.Flag
Animate = R.Animate; Safe = R.Safe; Recipes = R.Recipes; Effects = R.Effects; Acrylic = R.Acrylic
end



local POP_W, POP_H = 180, 152

local function frostAlpha(theme) return theme.Acrylic.popoverFrost end




local function popOpen(frame, theme, edge, scale)
if scale == 1 then return Animate.popIn(frame, edge) end
local us = frame:FindFirstChildOfClass("UIScale")
if not us then return nil end
if not Animate.isEnabled() then us.Scale = scale; return nil end
local target = frame.Position
us.Scale = scale * theme.Motion.exitScale
local dy = (edge == "up") and theme.Motion.popSlide or -theme.Motion.popSlide
frame.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + dy)
Animate.to(frame, "fast", { Position = target }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
return Animate.springTo(us, "base", { Scale = scale })
end

local function popShut(frame, theme, scale, onDone)
if scale == 1 then return Animate.popOut(frame, onDone) end
local us = frame:FindFirstChildOfClass("UIScale")
if not us then if onDone then onDone() end; return nil end
return Animate.toThen(us, "exit", { Scale = scale * theme.Motion.exitScale }, onDone,
Animate.EASING.exit, Animate.DIR.In)
end


local function toArr(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end
local function toColor(v)
if type(v) == "table" and v[1] then return Color3.fromRGB(v[1], v[2], v[3]) end
return v
end
local function rgbToHsv(c)
local r, g, b = c.R, c.G, c.B
local mx, mn = math.max(r, g, b), math.min(r, g, b)
local d = mx - mn
local hh = 0
if d > 0 then
if mx == r then hh = ((g - b) / d) % 6
elseif mx == g then hh = (b - r) / d + 2
else hh = (r - g) / d + 4 end
hh = hh / 6
end
return hh, (mx == 0) and 0 or d / mx, mx
end
local function clamp01(n) if n < 0 then return 0 elseif n > 1 then return 1 end return n end

function ColorPicker.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local pad = theme.Spacing.gap
local color = opts.Default or Color3.fromRGB(255, 255, 255)
local hsvH, hsvS, hsvV = rgbToHsv(color)
local popover
local shadow
local popScale = 1
local openMaid

local stopDrag
local posConn
local onChanged = opts.Callback

local hasDesc = opts.Description ~= nil and opts.Description ~= ""
local btn = Create("TextButton", { Name = "ColorPicker", AutoButtonColor = false, Text = "",
BackgroundColor3 = theme.Colors.surface, Size = UDim2.new(1, 0, 0, hasDesc and 50 or 34), LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent, Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }) })

local label = Create("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = opts.Text or "Color",
TextColor3 = theme.Colors.foreground, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
Position = UDim2.new(0, 0, 0, hasDesc and 8 or 0), Size = UDim2.new(1, -40, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn })
Create.text(label, theme, "label")
if hasDesc then
Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -40, 0, 18), Parent = btn }), theme, "muted")
end
local swatch = Create("Frame", { Name = "Swatch", BackgroundColor3 = color, BackgroundTransparency = 0, BorderSizePixel = 0,
Size = UDim2.new(0, 28, 0, 18), Position = UDim2.new(1, -28, 0.5, -9), Parent = btn, Create.corner(theme.Radius.sm) })
Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = swatch })



local DIM = { { swatch, "BackgroundTransparency", 0 }, { label, "TextTransparency", 0 } }
local disabled = false


local function paintDisabled(animated)
if animated then
Recipes.disabled(DIM, disabled, theme)
else
local a = disabled and theme.Opacity.disabled or 0
for _, p in ipairs(DIM) do p[1][p[2]] = a end
end
end

local function apply(v) color = toColor(v); Safe.mutate(function() swatch.BackgroundColor3 = color end) end
local commit = Flag.bind(opts, toArr(color), apply)

local api = { Frame = btn }
function api.GetColor() return color end
function api.SetColor(c) commit(toArr(c)); if onChanged then onChanged(color) end end

function api.Open()
if disabled or popover then return end
local om = Maid.new()
openMaid = om




local scale = Overlay.scale()
popScale = scale
local x, y, openUp = Overlay.placePopover(btn.AbsolutePosition, btn.AbsoluteSize, POP_W * scale, POP_H * scale)
popover = Create("Frame", { Name = "ColorPopover", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0,
Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, POP_W, 0, POP_H),
ZIndex = Overlay.Z.popover, Create.corner(theme.Radius.md), Create.padding({ all = pad }),
Create("UIScale", { Scale = scale }) })
Create.stroke(theme.Colors.border, 1, theme.Stroke.floating).Parent = popover


Acrylic.decorate(popover, theme, { transparency = frostAlpha(theme), edge = true,
radius = theme.Radius.md, padInset = pad, strokeAlpha = theme.Stroke.floating })



local overlayRoot = Overlay.peek()
shadow = overlayRoot and Effects.shadow(overlayRoot, theme,
{ name = "ColorPopoverShadow", level = "popover", zIndex = Overlay.Z.catcher }) or nil
Effects.place(shadow, x, y, POP_W * scale, POP_H * scale, "popover", theme)


local sv = Create("ImageButton", { Name = "SV", AutoButtonColor = false,
BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1), ZIndex = 1002, Size = UDim2.new(1, 0, 0, 110),
Parent = popover, Create.corner(theme.Radius.sm), ClipsDescendants = true })
local satOverlay = Create("Frame", { Name = "Sat", BackgroundColor3 = Color3.fromRGB(255, 255, 255),
Size = UDim2.new(1, 0, 1, 0), ZIndex = 1003, Parent = sv,
Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
local valOverlay = Create("Frame", { Name = "Val", BackgroundColor3 = Color3.fromRGB(0, 0, 0),
Size = UDim2.new(1, 0, 1, 0), ZIndex = 1004, Parent = sv,
Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }) })
local svDot = Create("Frame", { Name = "Dot", BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 1005,
Size = UDim2.new(0, 8, 0, 8), AnchorPoint = Vector2.new(0.5, 0.5), Parent = sv, Create.corner(4) })


local svRing = Create.stroke(theme.Colors.background, 1, theme.Acrylic.strokeAlpha); svRing.Parent = svDot


local hue = Create("ImageButton", { Name = "Hue", AutoButtonColor = false, ZIndex = 1002,
BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, 0, 0, 16),
Position = UDim2.new(0, 0, 0, 120), Parent = popover, Create.corner(theme.Radius.sm) })
Create("UIGradient", { Parent = hue, Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
}) })
local hueDot = Create("Frame", { Name = "HueDot", BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 1003,
Size = UDim2.new(0, 4, 1, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(hsvH, 0, 0.5, 0), Parent = hue, Create.corner(2) })
local hueRing = Create.stroke(theme.Colors.background, 1, theme.Acrylic.strokeAlpha); hueRing.Parent = hueDot

local function refreshUI()
sv.BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1)
svDot.Position = UDim2.new(hsvS, 0, 1 - hsvV, 0)
hueDot.Position = UDim2.new(hsvH, 0, 0.5, 0)
api.SetColor(Color3.fromHSV(hsvH, hsvS, hsvV))
end
refreshUI()

local dragTarget
stopDrag = function() dragTarget = nil end
local function updateFromSV(px, py)
local p, sz = sv.AbsolutePosition, sv.AbsoluteSize
hsvS = clamp01(((px - (p and p.X or 0)) / ((sz and sz.X) or 1)))
hsvV = 1 - clamp01(((py - (p and p.Y or 0)) / ((sz and sz.Y) or 1)))
refreshUI()
end
local function updateFromHue(px)
local p, sz = hue.AbsolutePosition, hue.AbsoluteSize
hsvH = clamp01(((px - (p and p.X or 0)) / ((sz and sz.X) or 1)))
refreshUI()
end


om:Give(sv.InputBegan:Connect(function(input)
if disabled then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragTarget = "sv"; updateFromSV(input.Position.X, input.Position.Y)
end
end))
om:Give(hue.InputBegan:Connect(function(input)
if disabled then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragTarget = "hue"; updateFromHue(input.Position.X)
end
end))
om:Give(UserInputService.InputChanged:Connect(function(input)
if not dragTarget or disabled then return end
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
if dragTarget == "sv" then updateFromSV(input.Position.X, input.Position.Y) else updateFromHue(input.Position.X) end
end
end))
om:Give(UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragTarget = nil end
end))
om:Give(function() stopDrag = nil end)



posConn = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() Safe.mutate(api.Close) end)
Overlay.mount(popover)
Overlay.trackPopover(api.Close)






local popFrame, popShadow = popover, shadow
local unreg = opts.AccentReg and opts.AccentReg(function()
Acrylic.reskin(popFrame, theme, { transparency = frostAlpha(theme), edge = true,
radius = theme.Radius.md, padInset = pad, strokeAlpha = theme.Stroke.floating })
Effects.reskin(popShadow, theme, "shadow")
svRing.Color = theme.Colors.background
hueRing.Color = theme.Colors.background
end)
if unreg then om:Give(unreg) end


popOpen(popover, theme, openUp and "up" or "down", scale)
end




function api.Close()
local pv, sh, om = popover, shadow, openMaid
popover, shadow, openMaid = nil, nil, nil
if posConn then posConn:Disconnect(); posConn = nil end
if om then om:DoCleanup() end
Overlay.untrackPopover(api.Close)
if not pv then return end
popShut(pv, theme, popScale, function() pv:Destroy(); if sh then sh:Destroy() end end)
end
function api.Destroy() api.Close(); maid:DoCleanup() end



local function setDisabled(b)
disabled = b and true or false
Safe.mutate(function()
if disabled and stopDrag then stopDrag() end
paintDisabled(true)
end)
end
function api.SetDisabled(b) setDisabled(b) end

maid:Give(btn.MouseButton1Click:Connect(function()
if disabled then return end
if popover then api.Close() else api.Open() end
end))
maid:Give(btn)
maid:Give(function() api.Close() end)
if opts.Disabled then setDisabled(true) end

if opts.AccentReg then maid:Give(opts.AccentReg(function()
btn.BackgroundColor3 = theme.Colors.surface
local lab = btn:FindFirstChild("Label"); if lab then lab.TextColor3 = theme.Colors.foreground end
local de = btn:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
local st = swatch:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
paintDisabled()
end)) end

return api
end

return ColorPicker

end


EmbeddedModules["core/safe"] = function()





local Safe = {}
local Overlay
local RunService = game:GetService("RunService")

local unpack = table.unpack or unpack

local queue = {}
local flushConn = nil

function Safe.Init(R) Overlay = R.Overlay end



















local function defaultHasCapability()
local probed = false
local ok = pcall(function()
local root = Overlay and Overlay.peek and Overlay.peek()
if root then probed = true; root.BackgroundTransparency = root.BackgroundTransparency end
end)
if not ok then return false, true end
return true, probed
end

local custom = nil

local function hasCapability()
if custom then return custom() and true or false, true end
return defaultHasCapability()
end
function Safe._setCapabilityCheck(fn) custom = fn end

local function flush()
flushConn = nil


local i = 1
while i <= #queue do local job = queue[i]; i = i + 1; pcall(job) end
for k = #queue, 1, -1 do queue[k] = nil end
end

local function enqueue(fn)
queue[#queue + 1] = fn
if not flushConn then flushConn = RunService.Heartbeat:Once(flush) end
end









function Safe.mutate(fn)
local ok, certain = hasCapability()
if ok and certain then return fn() end
if ok then
local res = { pcall(fn) }
if res[1] then return unpack(res, 2, #res) end
end
enqueue(fn)
end

return Safe

end


EmbeddedModules["core/numfmt"] = function()

local Numfmt = {}

local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "k" } }


local function trim(n, dec)
dec = dec or 0
local s = string.format("%." .. dec .. "f", n)
if dec > 0 then
s = s:gsub("0+$", "")
s = s:gsub("%.$", "")
end
if s == "-0" then s = "0" end
return s
end

local function compact(n, dec)
local a = math.abs(n)
if a < 1e3 then return trim(n, dec) end
for _, u in ipairs(UNITS) do
if a >= u[1] then return trim(n / u[1], dec) .. u[2] end
end
return trim(n, dec)
end

local function comma(n, dec)
local neg = n < 0
local a = math.abs(n)
local intpart = math.floor(a)
local frac = ""
if dec > 0 then
local f = trim(a - intpart, dec)
local dot = f:find("%.")
if dot then frac = f:sub(dot) end
end
local s = tostring(intpart)
s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
s = s:gsub("^,", "")
return (neg and "-" or "") .. s .. frac
end

function Numfmt.format(n, opts)
opts = opts or {}
n = tonumber(n) or 0
local body
if opts.Format == "compact" then body = compact(n, opts.Decimals or 1)
elseif opts.Format == "comma" then body = comma(n, opts.Decimals or 1)
elseif opts.Decimals ~= nil then body = trim(n, opts.Decimals)
else body = tostring(n) end
return (opts.Prefix or "") .. body .. (opts.Suffix or "")
end

local MULT = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }

function Numfmt.parse(s, opts)
opts = opts or {}
s = tostring(s or "")
if opts.Prefix and opts.Prefix ~= "" and s:sub(1, #opts.Prefix) == opts.Prefix then
s = s:sub(#opts.Prefix + 1)
end
if opts.Suffix and opts.Suffix ~= "" and s:sub(-#opts.Suffix) == opts.Suffix then
s = s:sub(1, #s - #opts.Suffix)
end
s = s:gsub(",", "")
s = s:gsub("%s", "")
s = s:gsub("^%+", "")
local mult = 1
local low = s:sub(-1):lower()
if MULT[low] then mult = MULT[low]; s = s:sub(1, #s - 1) end
local num = tonumber(s)
if num == nil then return nil end
return num * mult
end

return Numfmt

end


EmbeddedModules["core/recipes"] = function()





local Recipes = {}
local Create, Theme, Animate, Icons, Safe, Device

function Recipes.Init(R)
Create = R.Create; Theme = R.Theme; Animate = R.Animate; Icons = R.Icons; Safe = R.Safe; Device = R.Device
end

local function noop() end
local NOOP_HANDLE = { reskin = noop, disconnect = noop }


local function themeOf(opts) return (opts and opts.theme) or Theme end

local function disconnectAll(conns)
return function()
for i = #conns, 1, -1 do
local c = conns[i]
if c and c.Disconnect then c:Disconnect() end
conns[i] = nil
end
end
end



local function colorOf(theme, c, default)
if type(c) == "string" then return theme.Colors[c] or theme.Colors[default] end
if c ~= nil then return c end
return theme.Colors[default]
end



local function isButton(inst)
local cls = inst.ClassName
return cls == "TextButton" or cls == "ImageButton"
end
local function isPress(input)
local t = input and input.UserInputType
return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end
local function onPress(conns, src, down, up)
if isButton(src) then
conns[#conns + 1] = src.MouseButton1Down:Connect(down)
conns[#conns + 1] = src.MouseButton1Up:Connect(up)
else
conns[#conns + 1] = src.InputBegan:Connect(function(i) if isPress(i) then down() end end)
conns[#conns + 1] = src.InputEnded:Connect(function(i) if isPress(i) then up() end end)
end
end



local function pointerHover() return Device.SupportsHover() and Device.GetInput() ~= "Touch" end


local function pick(state, rest, hover, press)
if state == "press" then return press elseif state == "hover" then return hover end
return rest
end




local function hoverParts(kind, host, opts, theme)
if kind == "fill" then



local restA = host.BackgroundTransparency or 1
local hoverA = opts.hoverAlpha or theme.Opacity.rowHover
local pressA = opts.pressAlpha or hoverA
return { { host, "BackgroundTransparency", function(s) return pick(s, restA, hoverA, pressA) end } },
function(a) restA = a end
elseif kind == "text" then
local function tint(s)
if s == "rest" then return colorOf(theme, opts.rest, "mutedForeground") end
return colorOf(theme, opts.hover, "foreground")
end
local parts = {}
if opts.label then parts[#parts + 1] = { opts.label, "TextColor3", tint } end
if opts.icon then parts[#parts + 1] = { opts.icon, "ImageColor3", tint } end
return parts
end
error("Recipes.hover: kind must be 'wash' | 'text' | 'fill', got " .. tostring(kind), 3)
end








local function washBuilder(host, opts, theme)
local inset = opts.inset or {}
local ix, iy = inset.x or inset[1] or 0, inset.y or inset[2] or 0
local corner = opts.corner
local hoverA, pressA = opts.hoverAlpha or theme.Opacity.hoverWash, opts.pressAlpha or theme.Opacity.pressWash
return function()


local wash = Create("Frame", {
Name = "Hover", BackgroundColor3 = theme.Colors.foreground, BackgroundTransparency = 1, BorderSizePixel = 0,
Size = UDim2.new(1, 2 * ix, 1, 2 * iy), Position = UDim2.new(0, -ix, 0, -iy),
ZIndex = 0, Active = false, Parent = host,
})
if corner then Create.corner(corner).Parent = wash end
return wash, { wash, "BackgroundTransparency", function(s) return pick(s, 1, hoverA, pressA) end }
end
end



local function bindHover(sources, opts)
opts = opts or {}
local theme = themeOf(opts)
if not Device.SupportsHover() then return NOOP_HANDLE end
local kind = opts.kind or "wash"
local host = opts.host or sources[1]
local parts, buildWash, setRestA = {}, nil, nil
if kind == "wash" then buildWash = washBuilder(host, opts, theme)
else parts, setRestA = hoverParts(kind, host, opts, theme) end

local handle, wash



local function ensureWash()
if wash or not buildWash then return end
local part
wash, part = buildWash()
parts[#parts + 1] = part
handle.Frame = wash
end

local state, hovering, pressed = "rest", false, false
local function paint(next, instant)
if next ~= "rest" then ensureWash() end
state = next
local dur = (next == "press") and "press" or "hover"
for _, p in ipairs(parts) do
local inst, prop, v = p[1], p[2], p[3](next)
if instant then inst[prop] = v else Animate.to(inst, dur, { [prop] = v }) end
end
end
local function enter() hovering = true; paint(pressed and "press" or "hover") end
local function leave() hovering = false; pressed = false; paint("rest") end
local function down() pressed = true; paint("press") end
local function up()
pressed = false
if hovering and pointerHover() then paint("hover") else hovering = false; paint("rest") end
end


local conns = {}
local dropConns = disconnectAll(conns)
handle = {



reskin = function()
if wash then wash.BackgroundColor3 = theme.Colors.foreground end
if kind == "text" then paint(state, true) end
end,


disconnect = function() buildWash = nil; dropConns() end,

settle = function() hovering = false; pressed = false; paint("rest", true) end,
}


if setRestA then handle.setRest = function(a) setRestA(a); paint(state) end end
for _, src in ipairs(sources) do
conns[#conns + 1] = src.MouseEnter:Connect(enter)
conns[#conns + 1] = src.MouseLeave:Connect(leave)
onPress(conns, src, down, up)
end
return handle
end






function Recipes.hover(hit, opts) return bindHover({ hit }, opts) end





function Recipes.press(hit, scaleHost, opts)
if scaleHost == nil then return { disconnect = noop } end
local theme = themeOf(opts)
local us = scaleHost:FindFirstChildOfClass("UIScale") or Create("UIScale", { Scale = 1, Parent = scaleHost })
local pressed = false
local function down() pressed = true; Animate.to(us, "press", { Scale = theme.Motion.pressScale }) end

local function up() if pressed then pressed = false; Animate.springTo(us, "release", { Scale = 1 }) end end
local conns = {}
onPress(conns, hit, down, up)
conns[#conns + 1] = hit.MouseLeave:Connect(up)
return { Scale = us, disconnect = disconnectAll(conns) }
end



local function centreOf(inst)
local p, s, a = inst.Position, inst.Size, inst.AnchorPoint
if not p or not s then return UDim2.new(0.5, 0, 0.5, 0) end
local ax, ay = a and a.X or 0, a and a.Y or 0
return UDim2.new(p.X.Scale + s.X.Scale * (0.5 - ax), p.X.Offset + s.X.Offset * (0.5 - ax),
p.Y.Scale + s.Y.Scale * (0.5 - ay), p.Y.Offset + s.Y.Offset * (0.5 - ay))
end






function Recipes.iconButton(btn, opts)
opts = opts or {}
local theme = themeOf(opts)
local size = opts.hitSize or (Device.IsTouch() and theme.Sizes.touchHit or theme.Sizes.iconButton)
local hit = Create("ImageButton", {
Name = (btn.Name or btn.ClassName) .. "Hit", BackgroundTransparency = 1, ImageTransparency = 1, BorderSizePixel = 0,
AutoButtonColor = false, Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = centreOf(btn),
Size = UDim2.new(0, size, 0, size), ZIndex = (btn.ZIndex or 1) + 1, Parent = opts.parent or btn.Parent,
})
local sources = { btn, hit }
local function restC() return colorOf(theme, opts.rest, "mutedForeground") end
local function hoverC() return colorOf(theme, opts.hover, "foreground") end
if opts.icon then Icons.apply(btn, opts.icon, restC()) end

local wash = bindHover(sources, { theme = theme, host = hit, corner = theme.Radius.sm, kind = "wash" })
local conns, hovering = {}, false
if Device.SupportsHover() then
local function enter() hovering = true; Icons.tint(btn, hoverC()) end
local function leave() hovering = false; Icons.tint(btn, restC()) end
local function up() if not pointerHover() then leave() end end
for _, src in ipairs(sources) do
conns[#conns + 1] = src.MouseEnter:Connect(enter)
conns[#conns + 1] = src.MouseLeave:Connect(leave)
conns[#conns + 1] = src.MouseButton1Up:Connect(up)
end
end
if opts.onClick then
for _, src in ipairs(sources) do conns[#conns + 1] = src.MouseButton1Click:Connect(opts.onClick) end
end
local disconnectOwn = disconnectAll(conns)
return {
Hit = hit,
reskin = function()
local c = hovering and hoverC() or restC()
if opts.icon then Icons.apply(btn, opts.icon, c) else btn.ImageColor3 = c end
wash.reskin()
end,
disconnect = function() disconnectOwn(); wash.disconnect() end,
}
end








function Recipes.focus(stroke, host, getColor, opts)
opts = opts or {}
local theme = themeOf(opts)
local restThickness = stroke.Thickness or 1





local restAlphaOpt = opts.restAlpha
local capturedAlpha = stroke.Transparency or 0
local function restAlpha()
if type(restAlphaOpt) == "function" then return restAlphaOpt() or 0 end
if type(restAlphaOpt) == "number" then return restAlphaOpt end
return capturedAlpha
end
local function apply(focused)
focused = focused and true or false
local goal = { Thickness = focused and theme.Stroke.focusThickness or restThickness }
local rest = restAlpha()
if rest > 0 then goal.Transparency = focused and theme.Stroke.control or rest end
if getColor then goal.Color = getColor(focused) end
Animate.to(stroke, "fast", goal)
end
local function on() apply(true) end
local function off() apply(false) end
local conns = {}
local function bind(name, fn)
local ok, sig = pcall(function() return host[name] end)
if ok and sig ~= nil then conns[#conns + 1] = sig:Connect(fn) end
end
bind("Focused", on); bind("FocusLost", off)
bind("SelectionGained", on); bind("SelectionLost", off)



pcall(function()
host.SelectionImageObject = Create("Frame", { Name = "SelectionImage", BackgroundTransparency = 1, BorderSizePixel = 0 })
end)
return { set = apply, disconnect = disconnectAll(conns) }
end





function Recipes.disabled(parts, on, theme)
theme = theme or Theme
local alpha = theme.Opacity.disabled
for _, p in ipairs(parts or {}) do
local inst, prop, rest = p[1], p[2], p[3]
if inst and prop then
if rest == nil then rest = 0 end
Animate.to(inst, "fast", { [prop] = on and alpha or rest })
end
end
end





function Recipes.empty(parent, opts)
opts = opts or {}
local theme = themeOf(opts)
local z = opts.zIndex
local frame = Create("Frame", {
Name = "Empty", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
Visible = false, Active = false, ZIndex = z, Parent = parent,
Create("UIListLayout", {
FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,
HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
Padding = UDim.new(0, theme.Spacing.gap),
}),
})
local icon
if opts.icon then
icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = z,
Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), Parent = frame })
Icons.apply(icon, opts.icon, theme.Colors.mutedForeground)
end
local label = Create("TextLabel", { Name = "Text", BackgroundTransparency = 1, Text = opts.text or "",
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, ZIndex = z, Parent = frame })
Create.text(label, theme, "muted")
return {
Frame = frame,
SetVisible = function(b) frame.Visible = b and true or false end,
reskin = function()
label.TextColor3 = theme.Colors.mutedForeground
if icon then Icons.apply(icon, opts.icon, theme.Colors.mutedForeground) end
end,
}
end




function Recipes.scrollbar(sf, theme)
theme = theme or Theme
sf.ScrollBarThickness = theme.Sizes.scrollbar
sf.ScrollBarImageColor3 = theme.Colors.border
sf.ScrollBarImageTransparency = theme.Scrollbar.alpha
local id = theme.Scrollbar.imageId
if id and id ~= "" then sf.TopImage = id; sf.MidImage = id; sf.BottomImage = id end
return sf
end

return Recipes

end


EmbeddedModules["components/slider"] = function()

local Slider = {}
local Create, DefaultTheme, Animate, Maid, Flag, Safe, Effects, Recipes, Device
local UserInputService = game:GetService("UserInputService")
function Slider.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Flag = R.Flag; Safe = R.Safe
Effects = R.Effects; Recipes = R.Recipes; Device = R.Device
end



local TRACK_H, TRACK_Y, HANDLE = 6, -16, 12

function Slider.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local minV = opts.Min or 0
local maxV = opts.Max or 100
local step = opts.Step or 1
local value = minV
local onChanged

local function snap(n)
n = tonumber(n) or value
if step and step > 0 then n = math.floor((n - minV) / step + 0.5) * step + minV end
if n < minV then n = minV elseif n > maxV then n = maxV end
return n
end

local hasDesc = opts.Description ~= nil and opts.Description ~= ""



local padY = theme.Spacing.inputY
local root = Create("Frame", { Name = "SliderRow", BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
Size = UDim2.new(1, 0, 0, (opts.Text and (hasDesc and 62 or 46) or 28) + padY * 2), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX, top = padY, bottom = padY }) })
local valueLabel, titleLabel, descLabel
if opts.Text then


titleLabel = Create.text(Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Text,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, -40, 0, 16), Parent = root }), theme, "label")
valueLabel = Create.text(Create("TextLabel", { Name = "Value", BackgroundTransparency = 1, Text = "0",
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Right,
Size = UDim2.new(0, 40, 0, 16), Position = UDim2.new(1, -40, 0, 0), Parent = root }), theme, "muted")
if hasDesc then
descLabel = Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, -40, 0, 18), Parent = root }), theme, "muted")
end
end


local track = Create("Frame", { Name = "Track", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0,
Size = UDim2.new(1, 0, 0, TRACK_H), Position = UDim2.new(0, 0, 1, TRACK_Y), Parent = root, Create.corner(TRACK_H / 2) })
local trackStroke = Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = track })
local fill = Create("Frame", { Name = "Fill", BackgroundColor3 = theme.Colors.primary, BorderSizePixel = 0,
Size = UDim2.new(0, 0, 1, 0), Parent = track, Create.corner(TRACK_H / 2) })


local handle = Create("Frame", { Name = "Handle", BackgroundColor3 = theme.Colors.foreground, BorderSizePixel = 0, ZIndex = 2,
AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, HANDLE, 0, HANDLE),
Position = UDim2.new(0, 0, 0.5, 0), Parent = track, Create.corner(HANDLE / 2) })
local handleScale = Create("UIScale", { Scale = 1, Parent = handle })






local halo = Effects.lazyGlow(track, theme, theme.Colors.primary, "control", 0, "Halo",
function(layer) Effects.mirror(layer, handle, "control", theme) end)



if halo then maid:Give(halo.Release) end




local hitH = theme.Sizes.sliderHit
local hit = Create("Frame", { Name = "Hit", BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 3,
Size = UDim2.new(1, 0, 0, hitH), Position = UDim2.new(0, 0, 1, TRACK_Y + TRACK_H / 2 - hitH / 2), Parent = root })

local dragging = false
local built = false

local function valuePos(scale) return UDim2.new(scale, 0, 0.5, 0) end

local function apply(v)
value = snap(v)
local scale = (maxV > minV) and (value - minV) / (maxV - minV) or 0
local direct = dragging or not built
Safe.mutate(function()
if valueLabel then valueLabel.Text = tostring(value) end



local lit = halo and halo.Peek()
if direct then

fill.Size = UDim2.new(scale, 0, 1, 0)
handle.Position = valuePos(scale)
if lit then lit.Position = valuePos(scale) end
return
end

local E, D = Animate.EASING.smooth, Animate.DIR.Out
Animate.to(fill, "base", { Size = UDim2.new(scale, 0, 1, 0) }, E, D)
Animate.to(handle, "base", { Position = valuePos(scale) }, E, D)
if lit then Animate.to(lit, "base", { Position = valuePos(scale) }, E, D) end
end)
end
local commit = Flag.bind(opts, snap(opts.Default or minV), apply)
built = true

local api = { Frame = root }
function api.GetValue() return value end
function api.SetValue(v) commit(snap(v)); if opts.Callback then opts.Callback(value) end; if onChanged then onChanged(value) end end
function api.OnChanged(fn) onChanged = fn end
function api.Destroy() maid:DoCleanup() end


local hovering = false
local function handleGrow()
local s = dragging and theme.Motion.handleGrow or (hovering and theme.Motion.handleHover or 1)
Animate.springTo(handleScale, "release", { Scale = s })

if halo then halo.Fade(dragging and theme.fx(theme).glow or 1) end
end

local enabled = true
local stopListening
local function setEnabled(b)
local was = enabled
enabled = b ~= false
Safe.mutate(function()
local parts = { { fill, "BackgroundTransparency", 0 }, { handle, "BackgroundTransparency", 0 } }
if valueLabel then parts[#parts + 1] = { valueLabel, "TextTransparency", 0 } end
Recipes.disabled(parts, not enabled, theme)
end)

if was and not enabled and dragging then
dragging = false; handleGrow()
if stopListening then stopListening() end
end
end

if opts.AccentReg then maid:Give(opts.AccentReg(function()
root.BackgroundColor3 = theme.Colors.surface
track.BackgroundColor3 = theme.Colors.background
trackStroke.Color = theme.Colors.border
fill.BackgroundColor3 = theme.Colors.primary
handle.BackgroundColor3 = theme.Colors.foreground
Effects.reskin(halo, theme, "glow", theme.Colors.primary)
if titleLabel then titleLabel.TextColor3 = theme.Colors.foreground end
if descLabel then descLabel.TextColor3 = theme.Colors.mutedForeground end
if valueLabel then valueLabel.TextColor3 = theme.Colors.mutedForeground end
end)) end

local function fromX(px)
local ap, sz = track.AbsolutePosition, track.AbsoluteSize
local x0 = ap and ap.X or 0
local w = (sz and sz.X) or 1
local t = (px - x0) / (w > 0 and w or 1)
if t < 0 then t = 0 elseif t > 1 then t = 1 end
api.SetValue(minV + t * (maxV - minV))
end


local moveConn, endConn
function stopListening()
if moveConn then moveConn:Disconnect(); moveConn = nil end
if endConn then endConn:Disconnect(); endConn = nil end
end
maid:Give(stopListening)
maid:Give(hit.InputBegan:Connect(function(input)
if not enabled then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true; handleGrow(); fromX(input.Position.X)
if moveConn then return end
moveConn = UserInputService.InputChanged:Connect(function(io)
if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
fromX(io.Position.X)
end
end)
endConn = UserInputService.InputEnded:Connect(function(io)
if not dragging then return end
if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
dragging = false; handleGrow(); stopListening()
end
end)
end
end))
if Device.SupportsHover() then
maid:Give(hit.MouseEnter:Connect(function() hovering = true; if enabled then handleGrow() end end))
maid:Give(hit.MouseLeave:Connect(function() hovering = false; handleGrow() end))
end


function api.SetEnabled(b) setEnabled(b) end
if opts.Disabled then setEnabled(false) end
maid:Give(root)
return api
end
return Slider

end


EmbeddedModules["components/host"] = function()


local Host = {}

local SIMPLE = {
AddLabel = { mod = "Label" },
AddParagraph = { mod = "Label", preset = { Variant = "paragraph" } },
AddSection = { mod = "Label", preset = { Variant = "section" } },
AddSeparator = { mod = "Separator" },
AddButton = { mod = "Button" },
AddToggle = { mod = "Toggle" },
AddTextBox = { mod = "TextBox" },
AddNumberBox = { mod = "NumberBox" },
AddSelectBox = { mod = "SelectBox" },
AddSlider = { mod = "Slider" },
AddKeybind = { mod = "Keybind" },
AddColorPicker = { mod = "ColorPicker" },
AddImage = { mod = "Image" },
AddTable = { mod = "Table" },
AddProgressBar = { mod = "ProgressBar" },
AddResizable = { mod = "Resizable" },
AddCard = { mod = "Card" },
}






function Host.own(control, fn)
if type(fn) ~= "function" then error("Host.own(control, fn): fn must be a function", 2) end
if control.Maid then control.Maid:Give(fn); return control end
local d = control.Destroy
control.Destroy = function(...)
fn()
if d then return d(...) end
end
return control
end


function Host.attach(api, ctx)
for method, spec in pairs(SIMPLE) do
api[method] = function(_, arg)
local opts = {}
if type(arg) == "string" then
opts.Text = arg
elseif type(arg) == "function" then
opts.Text = arg
elseif type(arg) == "table" then
for k, v in pairs(arg) do opts[k] = v end
end
if spec.preset then
for k, v in pairs(spec.preset) do if opts[k] == nil then opts[k] = v end end
end
opts.Parent = ctx.content
opts.LayoutOrder = ctx.nextOrder()
opts.Theme = ctx.theme
opts.Config = ctx.config
opts.Window = ctx.window
opts.AccentReg = ctx.accentThemer and ctx.accentThemer.register
opts.AccentThemer = ctx.accentThemer



opts.RegisterSearchable = ctx.registerSearchable
opts.RegisterControl = ctx.registerControl
local control = ctx.R[spec.mod].new(opts)
if opts.Tooltip and ctx.R.Tooltip and control and control.Frame then


local tip = ctx.R.Tooltip.attach(control.Frame, opts.Tooltip, ctx.theme)
if tip and tip.Destroy then Host.own(control, tip.Destroy) end
end
if ctx.registerSearchable and control and control.Frame then

local searchText = (type(opts.Text) == "string" and opts.Text) or opts.Title or opts.Name or ""

local unreg = ctx.registerSearchable(control.Frame, searchText)
if type(unreg) == "function" then Host.own(control, unreg) end
end
if control and control.Frame then
local C = ctx.R.Create




local scrim, shield
local function ensureLock()
if scrim then return end
scrim = C("Frame", { Name = "LockScrim", BackgroundColor3 = ctx.theme.Colors.background,
BackgroundTransparency = ctx.theme.Opacity.scrim, BorderSizePixel = 0, Visible = false, ZIndex = 50,
Size = UDim2.new(1, 0, 1, 0), Parent = control.Frame, C.corner(ctx.theme.Radius.md) })
shield = C("ImageButton", { Name = "LockShield", AutoButtonColor = false, BackgroundTransparency = 1,
Active = true, Visible = false, ZIndex = 51, Size = UDim2.new(1, 0, 1, 0), Parent = control.Frame })



if ctx.accentThemer then
Host.own(control, ctx.accentThemer.register(function() scrim.BackgroundColor3 = ctx.theme.Colors.background end))
end
end
control.SetLocked = function(b)
local v = b and true or false
if not scrim and not v then return end
ensureLock()
ctx.R.Safe.mutate(function() scrim.Visible = v; shield.Visible = v end)
end
if opts.Locked then control.SetLocked(true) end
if ctx.registerControl then
local unreg = ctx.registerControl(control)
if type(unreg) == "function" then Host.own(control, unreg) end
end
end
return control
end
end
end

return Host

end


EmbeddedModules["core/config"] = function()
local HttpService = game:GetService("HttpService")

local Config = {}
Config.__index = Config

local function hasFS()
return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Config.new(opts)
opts = opts or {}
local self = setmetatable({
folder = opts.FolderName or "EzUI",
file = opts.FileName or "Settings",
autoSave = opts.AutoSave ~= false,
autoLoad = opts.AutoLoad ~= false,
profile = "Default",
values = {},
defaults = {},
setters = {},
}, Config)


if self.autoLoad then self:Load() end
return self
end

function Config:_dir() return self.folder .. "/" .. self.file end


function Config:_pathFor(name)
if name == "Default" then return self.folder .. "/" .. self.file .. ".json" end
return self:_dir() .. "/" .. name .. ".json"
end
function Config:_path() return self:_pathFor(self.profile) end

function Config:ActiveProfile() return self.profile end

function Config:SwitchProfile(name)
self.profile = name or "Default"
self:Load()
return self.profile
end

function Config:ListProfiles()
local names = { Default = true }
if type(listfiles) == "function" then
local ok, files = pcall(listfiles, self:_dir())
if ok and type(files) == "table" then
for _, f in ipairs(files) do
local n = tostring(f):match("([^/\\]+)%.json$")
if n then names[n] = true end
end
end
end
local out = {}
for n in pairs(names) do out[#out + 1] = n end
return out
end

function Config:DeleteProfile(name)
if type(delfile) == "function" and type(isfile) == "function" then
local p = self:_pathFor(name)
if isfile(p) then pcall(delfile, p) end
end
end

function Config:Register(flag, default, setValue)
self.defaults[flag] = default
self.setters[flag] = setValue
if self.values[flag] == nil then self.values[flag] = default end
end

function Config:Get(flag) return self.values[flag] end

function Config:Set(flag, value)
self.values[flag] = value
if self.autoSave then self:Save() end
end

function Config:GetAllKeys()
local keys = {}
for k in pairs(self.values) do keys[#keys + 1] = k end
return keys
end

function Config:Save()
if not hasFS() then return false end
local ok, encoded = pcall(function() return HttpService:JSONEncode(self.values) end)
if not ok then return false end
if type(makefolder) == "function" then
pcall(makefolder, self.folder)


if self.profile ~= "Default" then pcall(makefolder, self:_dir()) end
end
return pcall(writefile, self:_path(), encoded)
end

function Config:Load()
if not hasFS() then return false end
local path = self:_path()


if not isfile(path) and self.profile == "Default" then
local nested = self:_dir() .. "/Default.json"
if isfile(nested) then path = nested end
end
if not isfile(path) then return false end
local ok, content = pcall(readfile, path)
if not ok then return false end
local ok2, decoded = pcall(function() return HttpService:JSONDecode(content) end)
if not ok2 or type(decoded) ~= "table" then return false end
for flag, value in pairs(decoded) do
self.values[flag] = value
if self.setters[flag] then pcall(self.setters[flag], value) end
end
return true
end

function Config:ResetFlag(flag)
local d = self.defaults[flag]
self.values[flag] = d
if self.setters[flag] then pcall(self.setters[flag], d) end
if self.autoSave then self:Save() end
end

function Config:Reset(opts)
opts = opts or {}
for flag, d in pairs(self.defaults) do
self.values[flag] = d
if self.setters[flag] then pcall(self.setters[flag], d) end
end
if opts.ClearFile and type(delfile) == "function" and hasFS() and isfile(self:_path()) then
pcall(delfile, self:_path())
else
self:Save()
end
end

return Config

end


EmbeddedModules["core/acrylic"] = function()

local Acrylic = {}
local Create, Theme, Effects

function Acrylic.Init(R) Create = R.Create; Theme = R.Theme; Effects = R.Effects end






















local FROST = 0.12
local GLINT_FADE = 0.25
local HAIRLINE = 1





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




local function highlightStops(theme, fx, transparency)
local top = 1 - (1 - fx.highlight) * (1 - transparency)
return { { 0, top }, { tokens(theme).highlightBand, 1 }, { 1, 1 } }
end

local function glintStops(theme)
local fade = tokens(theme).glintFade or GLINT_FADE
return { { 0, 1 }, { fade, 0 }, { 1 - fade, 0 }, { 1, 1 } }
end


local function layerGeometry(inst, p)
inst.Position = UDim2.new(0, -p, 0, -p)
inst.Size = UDim2.new(1, 2 * p, 1, 2 * p)
end



local function glintGeometry(inst, r, p)
inst.Position = UDim2.new(0, r - p, 0, -p)
inst.Size = UDim2.new(1, 2 * p - 2 * r, 0, HAIRLINE)
end


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


local function paintStroke(frame, theme, o)
local stroke = frame:FindFirstChildOfClass("UIStroke")
if not stroke then return end
stroke.Color = theme.Colors.border
stroke.Transparency = o.strokeAlpha


if Effects and not theme.Lite and (o.edge or stroke:FindFirstChildOfClass("UIGradient")) then Effects.rim(stroke, theme) end
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



local function paint(frame, theme, o)
local fx = Theme.fx(theme)
frame.BackgroundColor3 = o.base
if o.solid then frame.BackgroundTransparency = 0
elseif o.transparency ~= nil then frame.BackgroundTransparency = o.transparency end
paintStroke(frame, theme, o)
if o.edge and not o.solid and not theme.Lite and frame:FindFirstChildOfClass("UIGradient") then ensureGlint(frame, theme, o, fx) end
paintFrost(frame, theme, fx, frame.BackgroundTransparency or 0)
return frame
end

function Acrylic.decorate(frame, theme, opts)
local o = resolve(frame, theme, opts)
if o.transparency == nil then o.transparency = tokens(theme).frost or FROST end
ensureStroke(frame, theme, o)

if not o.solid and not theme.Lite then
local fx = Theme.fx(theme)
ensureNoise(frame, theme, o, fx)
ensureGradient(frame, theme, fx)
ensureSheen(frame, theme, o, fx, o.transparency)
end
return paint(frame, theme, o)
end




function Acrylic.reskin(frame, theme, opts)
return paint(frame, theme, resolve(frame, theme, opts))
end

return Acrylic

end


EmbeddedModules["core/themer"] = function()





local Themer = {}
function Themer.Init(_) end

Themer.ACCENTS = {
{ Name = "Adaptive", Primary = Color3.fromRGB(250, 250, 250), Foreground = Color3.fromRGB(24, 24, 27) },
{ Name = "Indigo",  Primary = Color3.fromRGB(99, 102, 241),  Foreground = Color3.fromRGB(250, 250, 250) },
{ Name = "Violet",  Primary = Color3.fromRGB(139, 92, 246),  Foreground = Color3.fromRGB(250, 250, 250) },
{ Name = "Emerald", Primary = Color3.fromRGB(16, 185, 129),  Foreground = Color3.fromRGB(250, 250, 250) },
{ Name = "Sky",     Primary = Color3.fromRGB(56, 189, 248),  Foreground = Color3.fromRGB(24, 24, 27) },
{ Name = "Rose",    Primary = Color3.fromRGB(244, 63, 94),   Foreground = Color3.fromRGB(250, 250, 250) },
}

function Themer.accent(name)
for _, a in ipairs(Themer.ACCENTS) do if a.Name == name then return a end end
return nil
end

function Themer.names()
local out = {}
for _, a in ipairs(Themer.ACCENTS) do out[#out + 1] = a.Name end
return out
end

function Themer.new()
local fns = {}
local self = {}
function self.register(fn)
fns[fn] = true
return function() fns[fn] = nil end
end


function self.reskin(reason)
for fn in pairs(fns) do pcall(fn, reason) end
end
function self.setAccent(primary, foreground)
self.reskin("accent")
end
return self
end

return Themer

end


EmbeddedModules["components/textbox"] = function()

local TextBox = {}
local Create, DefaultTheme, Maid, Icons, Flag, Animate, Safe, Recipes

function TextBox.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Icons = R.Icons; Flag = R.Flag; Animate = R.Animate; Safe = R.Safe
Recipes = R.Recipes
end


local function btnPalette(theme, variant)
if variant == "destructive" then return theme.Colors.destructive, theme.Colors.primaryForeground end
if variant == "secondary" then return theme.Colors.surface, theme.Colors.foreground end
if variant == "outline" then return theme.Colors.card, theme.Colors.foreground, theme.Colors.border end
if variant == "ghost" then return theme.Colors.card, theme.Colors.foreground end
return theme.Colors.primary, theme.Colors.primaryForeground
end




local function roleColor(theme, role)
if role == "muted" then return theme.Colors[theme.Icon.structural] end
if role == "success" then return theme.Colors.success end
return theme.Colors[theme.Icon.accent]
end


local ERROR_H = 18

function TextBox.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local hasLabel = opts.Text ~= nil and opts.Text ~= ""
local hasDesc = opts.Description ~= nil and opts.Description ~= ""
local fullWidth = (opts.FullWidth and hasLabel) and true or false




local boxH = fullWidth and 36 or 30
local boxX, boxW, boxTop, baseH, titleTop, descTop
if not hasLabel then
boxX, boxW, boxTop, baseH = UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, boxH), 0, boxH
elseif fullWidth then

titleTop = 12
descTop = titleTop + 22
boxTop = titleTop + (hasDesc and 44 or 26)
boxX, boxW, baseH = UDim2.new(0, 0, 0, boxTop), UDim2.new(1, 0, 0, boxH), boxTop + boxH + 12
else
baseH = hasDesc and 56 or 46
boxTop = math.floor((baseH - boxH) / 2)
boxX, boxW = UDim2.new(0.5, 4, 0, boxTop), UDim2.new(0.5, -4, 0, boxH)
end


local real = opts.Default or ""
local masked = opts.Password and true or false
local revealed = false
local suppress = false
local state = { focused = false, invalid = false }


local enabled = true
local dimParts, dimRest = {}, {}
local themed = {}
local function reTheme() for _, fn in ipairs(themed) do fn() end end
local api = {}


local root = Create("Frame", {
Name = "TextBoxRow", BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
Size = UDim2.new(1, 0, 0, baseH), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
Create.corner(theme.Radius.md),
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }),
})
themed[#themed + 1] = function() root.BackgroundColor3 = theme.Colors.surface end

if hasLabel then
local title = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Text,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = (hasDesc or fullWidth) and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
Position = fullWidth and UDim2.new(0, 0, 0, titleTop) or UDim2.new(0, 0, 0, hasDesc and 6 or 0),
Size = fullWidth and UDim2.new(1, 0, 0, 18)
or UDim2.new(0.5, -8, hasDesc and 0 or 1, hasDesc and 18 or 0),
Parent = root })
Create.text(title, theme, "label")
themed[#themed + 1] = function() title.TextColor3 = theme.Colors.foreground end
if hasDesc then
local desc = Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = fullWidth and UDim2.new(0, 0, 0, descTop) or UDim2.new(0, 0, 0, 26),
Size = fullWidth and UDim2.new(1, 0, 0, 18) or UDim2.new(0.5, -8, 0, 26), Parent = root })
Create.text(desc, theme, "muted")
themed[#themed + 1] = function() desc.TextColor3 = theme.Colors.mutedForeground end
end
end


local box = Create("Frame", {
Name = "Box", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0,


ClipsDescendants = true,
Position = boxX, Size = boxW, Parent = root, Create.corner(theme.Radius.input),
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }),
Create.listLayout({ FillDirection = Enum.FillDirection.Horizontal, Padding = 6 }),
})
themed[#themed + 1] = function() box.BackgroundColor3 = theme.Colors.background end
box:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center

local stroke = Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = box })
local function strokeColor()
if state.invalid then return theme.Colors.destructive end
if state.focused then return theme.Colors.ring end
return theme.Colors.border
end
themed[#themed + 1] = function() stroke.Color = strokeColor() end


local input = Create("TextBox", {
Name = "Input", BackgroundTransparency = 1, Text = real,
PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = theme.Colors.mutedForeground,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center, ClearTextOnFocus = false,



TextEditable = not opts.Copyable, LayoutOrder = 3, Size = UDim2.new(0, 0, 1, 0), Parent = box,
Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
})
Create.text(input, theme, "body")
themed[#themed + 1] = function()

input.TextColor3 = enabled and theme.Colors.foreground or theme.Colors.mutedForeground
input.PlaceholderColor3 = theme.Colors.mutedForeground
end


local function display() return (masked and not revealed) and string.rep("*", #real) or real end



local function render()
local d = display()
if input.Text == d then return end
Safe.mutate(function()
suppress = true
input.Text = d
if masked and not revealed then input.CursorPosition = #d + 1 end
suppress = false
end)
end
local function apply(v)
real = tostring(v or "")
if opts.MaxLength and #real > opts.MaxLength then real = real:sub(1, opts.MaxLength) end
render()
end
local commit = Flag.bind(opts, opts.Default or "", apply)

maid:Give(input:GetPropertyChangedSignal("Text"):Connect(function()
if suppress then return end
local vis = input.Text
if masked and not revealed then
if #vis > #real then real = real .. vis:sub(#real + 1)
elseif #vis < #real then real = real:sub(1, #vis) end
else
real = vis
end
if opts.MaxLength and #real > opts.MaxLength then real = real:sub(1, opts.MaxLength) end
render()
end))

maid:Give(input.FocusLost:Connect(function()
commit(real)
if opts.Callback then opts.Callback(real, api) end
end))







local function mkIconButton(name, icon, colorRole, order, onClick)
local glyph, role = icon, colorRole
local btn = Create("ImageButton", { Name = name, BackgroundTransparency = 1,
Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), LayoutOrder = order, Parent = box })
Icons.apply(btn, glyph, roleColor(theme, role))
dimParts[#dimParts + 1] = btn


local hover
if colorRole == "muted" then
hover = Recipes.hover(btn, { theme = theme, kind = "text", icon = btn,
rest = theme.Icon.structural, hover = theme.Icon.structuralActive })
maid:Give(hover.disconnect)
end
maid:Give(Recipes.press(btn, btn, { theme = theme }).disconnect)
themed[#themed + 1] = function()
Icons.apply(btn, glyph, roleColor(theme, role))
if hover then hover.reskin() end
end
if onClick then maid:Give(btn.MouseButton1Click:Connect(function() if enabled then onClick() end end)) end
return btn, function(g, r)
glyph, role = g or glyph, r or role
Icons.apply(btn, glyph, roleColor(theme, role))
end
end


local function mkAffix(name, text, order)
local lbl = Create("TextLabel", { Name = name, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
Text = text, TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Center,
Size = UDim2.new(0, 0, 1, 0), LayoutOrder = order, Parent = box })
Create.text(lbl, theme, "body")
themed[#themed + 1] = function() lbl.TextColor3 = theme.Colors.mutedForeground end
return lbl
end
local function mkDecorIcon(name, icon, order)
local img = Create("ImageLabel", { Name = name, BackgroundTransparency = 1,
Size = UDim2.new(0, 16, 0, 16), LayoutOrder = order, Parent = box })
Icons.apply(img, icon, theme.Colors.mutedForeground)
themed[#themed + 1] = function() Icons.apply(img, icon, theme.Colors.mutedForeground) end
return img
end
if opts.LeadingIcon then mkDecorIcon("LeadingIcon", opts.LeadingIcon, 1) end
if opts.Prefix then mkAffix("Prefix", opts.Prefix, 2) end
if opts.Suffix then mkAffix("Suffix", opts.Suffix, 4) end
if opts.TrailingIcon then mkDecorIcon("TrailingIcon", opts.TrailingIcon, 5) end

local function mkTextButton(spec, order)
local bg, fg, line = btnPalette(theme, spec.Variant or "default")
local btn = Create("TextButton", { Name = "Button" .. order, AutoButtonColor = false,
BackgroundColor3 = bg, BackgroundTransparency = 0,
AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, theme.Sizes.chip),
Text = spec.Text, TextColor3 = fg,
LayoutOrder = order, Parent = box, Create.corner(theme.Radius.sm),
Create.padding({ left = theme.Spacing.gap, right = theme.Spacing.gap }) })
Create.text(btn, theme, "muted")
if line then Create("UIStroke", { Color = line, Thickness = 1, Parent = btn }) end



maid:Give(Recipes.hover(btn, { theme = theme, host = btn, kind = "fill",
hoverAlpha = theme.Opacity.hoverFill, pressAlpha = theme.Opacity.pressFill }).disconnect)



maid:Give(Recipes.press(btn, nil, { theme = theme }).disconnect)
themed[#themed + 1] = function()
local b2, f2, l2 = btnPalette(theme, spec.Variant or "default")
btn.BackgroundColor3 = b2; btn.TextColor3 = f2
local s = btn:FindFirstChildOfClass("UIStroke"); if s and l2 then s.Color = l2 end
end
return btn
end
if opts.Buttons then
for i, spec in ipairs(opts.Buttons) do
local order = 5 + i
if spec.Icon then
mkIconButton("Button" .. i, spec.Icon, "primary", order,
spec.Callback and function() spec.Callback(real, api) end or nil)
else
local btn = mkTextButton(spec, order)
btn.Name = "Button" .. i
if spec.Callback then
maid:Give(btn.MouseButton1Click:Connect(function() if enabled then spec.Callback(real, api) end end))
end
end
end
end
if opts.Clearable then
local clear
clear = mkIconButton("Clear", "x", "muted", 29, function()
commit(""); if opts.Callback then opts.Callback(real, api) end
Animate.pop(clear, "fast")
if input.CaptureFocus then input:CaptureFocus() end
end)




local shown
local function sync()
local show = #real > 0
if shown == show then return end
local first = shown == nil
shown = show
Safe.mutate(function()
if first then
clear.Visible = show; clear.ImageTransparency = show and 0 or 1
elseif show then
clear.Visible = true
Animate.to(clear, "fast", { ImageTransparency = 0 })
else
Animate.toThen(clear, "fast", { ImageTransparency = 1 },
function() Safe.mutate(function() clear.Visible = false end) end)
end
end)
end
sync()
maid:Give(input:GetPropertyChangedSignal("Text"):Connect(sync))
end

local spinner, spin
local function stopSpin() if spin then spin.Cancel(); spin = nil end end
local function mkSpinner()
if spinner then return spinner end
spinner = Create("ImageLabel", { Name = "Spinner", BackgroundTransparency = 1, Visible = false,
Size = UDim2.new(0, 16, 0, 16), LayoutOrder = 40, Parent = box })
Icons.apply(spinner, "loader", theme.Colors.mutedForeground)
themed[#themed + 1] = function() Icons.apply(spinner, "loader", theme.Colors.mutedForeground) end
return spinner
end
local function setLoading(b)
Safe.mutate(function()
local s = mkSpinner()
s.Visible = b and true or false
stopSpin()
if b then spin = Animate.spin(s) end
end)
end
if opts.Loading then setLoading(true) end

if opts.Password then
local eye, setEyeGlyph
eye, setEyeGlyph = mkIconButton("Eye", "eye", "muted", 28, function()
revealed = not revealed
setEyeGlyph(revealed and "eye-off" or "eye")
Animate.pop(eye, "fast")
render()
end)
end

if opts.Copyable then




local setCopyGlyph
local copyGen = 0
local _, setter = mkIconButton("Copy", "copy", "primary", 30, function()
if setclipboard then pcall(setclipboard, real) end
copyGen = copyGen + 1
local gen = copyGen
Safe.mutate(function() setCopyGlyph("check", "success") end)
task.delay(theme.Motion.copyRevert, function()
if gen ~= copyGen then return end
Safe.mutate(function() setCopyGlyph("copy", "primary") end)
end)
end)
setCopyGlyph = setter
end






local focus = Recipes.focus(stroke, input, function(focused)
state.focused = focused
return strokeColor()
end, { theme = theme })
maid:Give(focus.disconnect)




local function setEnabled(b)
b = b and true or false
if enabled == b then return end
enabled = b
Safe.mutate(function()
input.TextEditable = b and not opts.Copyable
input.TextColor3 = b and theme.Colors.foreground or theme.Colors.mutedForeground
local parts = { { box, "BackgroundTransparency", 0 } }
for _, inst in ipairs(dimParts) do
if not b then dimRest[inst] = inst.ImageTransparency or 0 end
parts[#parts + 1] = { inst, "ImageTransparency", dimRest[inst] or 0 }
end
Recipes.disabled(parts, not b, theme)
end)
end
if opts.Disabled then setEnabled(false) end

local message
local function mkMessage()
if message then return message end
message = Create("TextLabel", { Name = "Error", BackgroundTransparency = 1, Visible = false,
Text = "", TextColor3 = theme.Colors.destructive, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
Position = UDim2.new(boxX.X.Scale, boxX.X.Offset, 0, boxTop + boxH + 2),
Size = UDim2.new(boxW.X.Scale, boxW.X.Offset, 0, 16), Parent = root })
Create.text(message, theme, "muted")
themed[#themed + 1] = function() message.TextColor3 = theme.Colors.destructive end
return message
end





local shaking = false
local function shake()
if shaking or not Animate.isEnabled() then return end
local sh = theme.Motion.shake
local rest = box.Position
local steps = {}
for i = 1, sh.steps do
local dx = (i % 2 == 1) and sh.amp or -sh.amp
steps[i] = { box, sh.step,
{ Position = UDim2.new(rest.X.Scale, rest.X.Offset + dx, rest.Y.Scale, rest.Y.Offset) },
Enum.EasingStyle.Sine, Animate.DIR.InOut }
end
steps[#steps + 1] = { box, sh.step, { Position = rest }, Enum.EasingStyle.Sine, Animate.DIR.Out }
shaking = true
Animate.chain(steps, function() shaking = false end)
end
local function setInvalid(msg)
state.invalid = true
Safe.mutate(function()


local m = mkMessage(); m.Text = msg or ""
if not m.Visible then m.Visible = true; m.TextTransparency = 1 end
stroke.Color = strokeColor()
Animate.to(root, "base", { Size = UDim2.new(1, 0, 0, baseH + ERROR_H) })
Animate.to(m, "base", { TextTransparency = 0 })
shake()
end)
end
local function setValid()
state.invalid = false
Safe.mutate(function()
stroke.Color = strokeColor()
Animate.to(root, "base", { Size = UDim2.new(1, 0, 0, baseH) })



if message and message.Visible then
Animate.toThen(message, "fast", { TextTransparency = 1 },
function() Safe.mutate(function() message.Visible = false end) end)
end
end)
end
local function runValidate()
if not opts.Validate then return end
local ok, msg = opts.Validate(real)
if ok then setValid() else setInvalid(msg) end
end
maid:Give(input.FocusLost:Connect(runValidate))

if opts.AccentReg then maid:Give(opts.AccentReg(reTheme)) end
maid:Give(stopSpin)
maid:Give(root)


api.Frame = root
api.GetText = function() return real end
api.SetText = function(s) commit(tostring(s)); runValidate(); if opts.Callback then opts.Callback(real, api) end end
api.Focus = function() input:CaptureFocus() end
api.Clear = function() commit("") end

api.SetDisabled = function(b) setEnabled(not b) end
api.SetEnabled = function(b) setEnabled(b) end
api.SetInvalid = function(msg) setInvalid(msg) end
api.SetValid = function() setValid() end
api.SetLoading = function(b) setLoading(b) end
api.Destroy = function() maid:DoCleanup() end
return api
end

return TextBox

end


EmbeddedModules["components/numberbox"] = function()

local RunService = game:GetService("RunService")
local NumberBox = {}
local Create, DefaultTheme, Maid, Icons, Flag, Numfmt, Safe, Animate, Recipes

function NumberBox.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Icons = R.Icons; Flag = R.Flag; Numfmt = R.Numfmt; Safe = R.Safe
Animate = R.Animate; Recipes = R.Recipes
end

function NumberBox.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local minV, maxV, step = opts.Min, opts.Max, opts.Step or 1
local value = opts.Default or 0
local hasLabel = opts.Text ~= nil and opts.Text ~= ""
local hasDesc = opts.Description ~= nil and opts.Description ~= ""
local rowH = (not hasLabel) and 30 or (hasDesc and 56 or 46)


local enabled = true
local hovering = false

local function clamp(n)
n = tonumber(n) or value
if minV then n = math.max(minV, n) end
if maxV then n = math.min(maxV, n) end
return n
end

local root = Create("Frame", { Name = "NumberBoxRow", BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }) })
if hasLabel then
Create.text(Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Text,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
Position = UDim2.new(0, 0, 0, hasDesc and 6 or 0),
Size = UDim2.new(0.5, -8, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = root }), theme, "label")
if hasDesc then
Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(0.5, -8, 0, 26), Parent = root }), theme, "muted")
end
end
local box = Create("Frame", { Name = "Box", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0,
Position = hasLabel and UDim2.new(0.5, 4, 0.5, -15) or UDim2.new(0, 0, 0, 0),
Size = hasLabel and UDim2.new(0.5, -4, 0, 30) or UDim2.new(1, 0, 0, 30),
Parent = root, Create.corner(theme.Radius.input) })

local boxStroke = Create.stroke(theme.Colors.border, 1); boxStroke.Parent = box

local function structural() return theme.Colors[theme.Icon.structural] end
local function stepBtn(name, icon, x)
local b = Create("ImageButton", { Name = name, AutoButtonColor = false, BackgroundColor3 = theme.Colors.surface,
Size = UDim2.new(0, 26, 1, -6), Position = x, Parent = box, Create.corner(theme.Radius.sm) })
local img = Create("ImageLabel", { BackgroundTransparency = 1, ImageTransparency = 0, Size = UDim2.new(0, 14, 0, 14),
Position = UDim2.new(0.5, -7, 0.5, -7), Parent = b })
Icons.apply(img, icon, structural())


local hover = Recipes.hover(b, { theme = theme, host = b, corner = theme.Radius.sm, kind = "wash" })
maid:Give(hover.disconnect)


maid:Give(Recipes.press(b, img, { theme = theme }).disconnect)
return b, img, hover
end
local minus, minusImg, minusHover = stepBtn("Minus", "minus", UDim2.new(0, 3, 0.5, -12))
local plus, plusImg, plusHover = stepBtn("Plus", "plus", UDim2.new(1, -29, 0.5, -12))
local input = Create.text(Create("TextBox", { Name = "Input", BackgroundTransparency = 1, Text = tostring(value),
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false,
Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -64, 1, 0), Parent = box }), theme, "body")

local atMin, atMax = false, false



local dimmed = { [minusImg] = false, [plusImg] = false }


local function glyphAlpha(img) return (dimmed[img] or not enabled) and theme.Opacity.disabled or 0 end
local function dim(img, off)
if dimmed[img] == off then return end
dimmed[img] = off
Animate.to(img, "fast", { ImageTransparency = glyphAlpha(img) })
end
local function updateBounds()
atMin = minV ~= nil and value <= minV
atMax = maxV ~= nil and value >= maxV
Safe.mutate(function()
dim(minusImg, atMin); minus.Active = not atMin
dim(plusImg, atMax); plus.Active = not atMax
end)
end

local function fmt(n)
return Numfmt.format(n, { Format = opts.Format, Decimals = opts.Decimals, Prefix = opts.Prefix, Suffix = opts.Suffix })
end
local focused = false

local function strokeColor(f) return f and theme.Colors.ring or theme.Colors.border end
local function render() Safe.mutate(function() input.Text = focused and tostring(value) or fmt(value) end) end
local function apply(n) value = clamp(n); render(); updateBounds() end
local commit = Flag.bind(opts, clamp(opts.Default or 0), apply)
local function set(n) commit(clamp(n)); if opts.Callback then opts.Callback(value) end end




local bumping = false
local function bump(dir)
if bumping or dir == nil or not Animate.isEnabled() then return end
local rest = box.Position
bumping = true
Animate.chain({
{ box, "press", { Position = UDim2.new(rest.X.Scale, rest.X.Offset + dir * theme.Motion.bumpPx,
rest.Y.Scale, rest.Y.Offset) }, Animate.EASING.snap, Animate.DIR.Out },
{ box, "press", { Position = rest }, Animate.EASING.snap, Animate.DIR.Out },
}, function() bumping = false end)
end




local function setEnabled(b)
b = b and true or false
if enabled == b then return end
enabled = b
Safe.mutate(function()
input.TextEditable = b
Recipes.disabled({
{ box, "BackgroundTransparency", 0 },
{ minusImg, "ImageTransparency", dimmed[minusImg] and theme.Opacity.disabled or 0 },
{ plusImg, "ImageTransparency", dimmed[plusImg] and theme.Opacity.disabled or 0 },
}, not b, theme)
end)
end

local function holdRepeat(btn, stepFn, atBoundFn, dir)
local conn, held
local function stop()
held = false
if conn then conn:Disconnect(); conn = nil end
end
maid:Give(btn.MouseButton1Down:Connect(function()
if not enabled then return end
if atBoundFn() then bump(dir); return end
held = true
stepFn()
local elapsed, since = 0, 0
conn = RunService.Heartbeat:Connect(function(dt)
if not held then return end
elapsed = elapsed + dt
if elapsed < 0.35 then return end
since = since + dt
local interval = math.max(0.03, 0.12 - (elapsed - 0.35) * 0.06)
if since >= interval then
since = 0
if atBoundFn() then stop(); return end
stepFn()
end
end)
end))
maid:Give(btn.MouseButton1Up:Connect(stop))
maid:Give(btn.MouseLeave:Connect(stop))
maid:Give(stop)
end
holdRepeat(minus, function() set(value - step) end, function() return atMin end, -1)
holdRepeat(plus, function() set(value + step) end, function() return atMax end, 1)
maid:Give(input.Focused:Connect(function() focused = true; input.Text = tostring(value) end))
maid:Give(input.FocusLost:Connect(function()
focused = false
local parsed = Numfmt.parse(input.Text, { Prefix = opts.Prefix, Suffix = opts.Suffix })
if parsed ~= nil then set(parsed) else render() end
end))
maid:Give(Recipes.focus(boxStroke, input, strokeColor, { theme = theme }).disconnect)



maid:Give(box.MouseEnter:Connect(function() hovering = true end))
maid:Give(box.MouseLeave:Connect(function() hovering = false end))
maid:Give(box.InputChanged:Connect(function(io)
if io.UserInputType == Enum.UserInputType.MouseWheel and enabled and (hovering or focused) then
local dir = (io.Position.Z >= 0) and 1 or -1
set(value + step * dir)
end
end))
maid:Give(root)
if opts.Disabled then setEnabled(false) end

if opts.AccentReg then maid:Give(opts.AccentReg(function()
root.BackgroundColor3 = theme.Colors.surface
box.BackgroundColor3 = theme.Colors.background
boxStroke.Color = strokeColor(focused)
input.TextColor3 = theme.Colors.foreground
local ti = root:FindFirstChild("Title"); if ti then ti.TextColor3 = theme.Colors.foreground end
local de = root:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
minus.BackgroundColor3 = theme.Colors.surface; plus.BackgroundColor3 = theme.Colors.surface
Icons.apply(minusImg, "minus", structural()); Icons.apply(plusImg, "plus", structural())
minusHover.reskin(); plusHover.reskin()
updateBounds()
end)) end

return {
Frame = root,
GetValue = function() return value end,
SetValue = function(n) set(n) end,
SetMin = function(n) minV = n; set(value) end,
SetMax = function(n) maxV = n; set(value) end,
SetEnabled = function(b) setEnabled(b) end,
Destroy = function() maid:DoCleanup() end,
}
end

return NumberBox

end


EmbeddedModules["components/table"] = function()

local Table = {}
local Create, DefaultTheme, Maid, Safe, Recipes
function Table.Init(R) Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Safe = R.Safe; Recipes = R.Recipes end



local ROW_H, BODY_Y, CELL_INSET = 24, 26, 4


local EDIT_INSET_Y, EDIT_PAD = 2, 6




local function normColumns(raw)
local cols = {}
for i, c in ipairs(raw or {}) do
if type(c) == "table" then
local w = c.Width
if w ~= nil and (type(w) ~= "number" or w <= 0) then
error(("AddTable: Columns[%d].Width must be a positive number, got %s"):format(i, tostring(w)), 3)
end
cols[i] = { Text = tostring(c.Text or ""), Editable = c.Editable == true, Placeholder = c.Placeholder, Width = w }
else
cols[i] = { Text = tostring(c) }
end
end
return cols
end



local function rowShape(r, key)
if type(r) == "table" and r.Cells ~= nil then
if r.Key ~= nil then return r.Cells, r.Key end
return r.Cells, key
end
return r or {}, key
end




local function flexItem(col, parent)
if col and col.Width then
return Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Custom, GrowRatio = col.Width,
ShrinkRatio = col.Width, Parent = parent })
end
return Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = parent })
end

function Table.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local cols = normColumns(opts.Columns)

local minCells = 0
for i, col in ipairs(cols) do if col.Editable then minCells = i end end
local enabled = not opts.Disabled

local root = Create("Frame", { Name = "Table", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, (opts.Height or 120) + BODY_Y), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent })








local rows, byKey = {}, {}


local function releaseFocused(record)
for _, c in ipairs(record.cells) do
if c.focused and c.inst and c.inst.ReleaseFocus then c.inst:ReleaseFocus() end
end
end

local function dropRecord(record)
record.dead = true
for i = #record.drops, 1, -1 do record.drops[i](); record.drops[i] = nil end
releaseFocused(record)
if record.frame then record.frame:Destroy(); record.frame = nil end
end

local function makeRowFrame(parent, header, order)
return Create("Frame", { Name = header and "Header" or "Row",
BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = header and 1 or 0,
Size = UDim2.new(1, 0, 0, ROW_H), LayoutOrder = order, Parent = parent,
Create.corner(header and 0 or theme.Radius.xs),
Create.listLayout({ Padding = CELL_INSET, FillDirection = Enum.FillDirection.Horizontal }) })
end

local function makeLabelCell(row, text, i, col, header)
local cell = Create.text(Create("TextLabel", { Name = "Cell", BackgroundTransparency = 1, Text = text,
TextColor3 = header and theme.Colors.mutedForeground or theme.Colors.foreground,
TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = row }), theme, "muted")

local face = header and theme.FontFace and theme.FontFace(Enum.FontWeight.Medium)
if face then cell.FontFace = face end
flexItem(col, cell)
return cell
end



local function commit(record, col, c)
local typed, old = c.inst.Text, c.value
if typed == old then return end

if not enabled then
Safe.mutate(function() c.inst.Text = old end)
return
end
local final = typed
if opts.OnEdit then
local ok, res = pcall(opts.OnEdit, record.key, col, typed, old)
if not ok then
if warn then warn("[EzUI] Table OnEdit error: " .. tostring(res)) end
final = old
elseif res == false then
final = old
elseif type(res) == "string" or type(res) == "number" then
final = tostring(res)
end
end
c.value = final
if c.inst.Text ~= final then Safe.mutate(function() c.inst.Text = final end) end
end






local function makeEditCell(row, record, i, col, c)
local frame = Create("Frame", { Name = "EditCell", BackgroundColor3 = theme.Colors.background,
BackgroundTransparency = enabled and 0 or theme.Opacity.disabled, BorderSizePixel = 0, ClipsDescendants = true,
Size = UDim2.new(0, 0, 1, -2 * EDIT_INSET_Y), LayoutOrder = i, Parent = row,
Create.corner(theme.Radius.xs), Create.padding({ left = EDIT_PAD, right = EDIT_PAD }) })
flexItem(col, frame).ItemLineAlignment = Enum.ItemLineAlignment.Center
local stroke = Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = frame })
local input = Create.text(Create("TextBox", { Name = "Input", BackgroundTransparency = 1, Text = c.value,
PlaceholderText = col.Placeholder and tostring(col.Placeholder) or "",
PlaceholderColor3 = theme.Colors.mutedForeground,
TextColor3 = enabled and theme.Colors.foreground or theme.Colors.mutedForeground,
TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
ClearTextOnFocus = false, TextEditable = enabled, Size = UDim2.new(1, 0, 1, 0), Parent = frame }), theme, "muted")

local hit = Create("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
Size = UDim2.new(1, 2 * EDIT_PAD, 1, 0), Position = UDim2.new(0, -EDIT_PAD, 0, 0), ZIndex = 2,
Visible = true, Parent = frame })
c.inst, c.frame = input, frame

local function strokeColor() return c.focused and theme.Colors.ring or theme.Colors.border end


local focus = Recipes.focus(stroke, input, function(f) c.focused = f; return strokeColor() end, { theme = theme })

local hover = Recipes.hover(frame, { theme = theme, host = frame, corner = theme.Radius.xs,
inset = { x = EDIT_PAD, y = 0 } })
local conns = {
hit.MouseButton1Click:Connect(function()
if enabled and input.CaptureFocus then input:CaptureFocus() end
end),
input.Focused:Connect(function() Safe.mutate(function() hit.Visible = false end) end),
input.FocusLost:Connect(function()
Safe.mutate(function() hit.Visible = true end)
commit(record, i, c)
end),
}
record.drops[#record.drops + 1] = function()
for k = #conns, 1, -1 do conns[k]:Disconnect(); conns[k] = nil end
focus.disconnect(); hover.disconnect()
end
c.paint = function()
frame.BackgroundColor3 = theme.Colors.background
stroke.Color = strokeColor()
input.TextColor3 = enabled and theme.Colors.foreground or theme.Colors.mutedForeground
input.PlaceholderColor3 = theme.Colors.mutedForeground
hover.reskin()
end
end

local header = makeRowFrame(root, true, 0)

Create.padding({ left = CELL_INSET, right = CELL_INSET }).Parent = header
for i, col in ipairs(cols) do
local cell = makeLabelCell(header, col.Text, i, col, true)

if col.Editable then Create.padding({ left = EDIT_PAD, right = EDIT_PAD }).Parent = cell end
end
local rule = Create("Frame", { Name = "HeaderRule", BackgroundColor3 = theme.Colors.border,
BackgroundTransparency = theme.Stroke.divider, BorderSizePixel = 0,
Position = UDim2.new(0, 0, 0, BODY_Y - 1), Size = UDim2.new(1, 0, 0, 1), Parent = root })
local body = Create("ScrollingFrame", { Name = "Body", BackgroundColor3 = theme.Colors.surface,
BackgroundTransparency = 0.5, BorderSizePixel = 0,
Position = UDim2.new(0, 0, 0, BODY_Y), Size = UDim2.new(1, 0, 1, -BODY_Y),
AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = root,
Create.corner(theme.Radius.sm), Create.padding({ all = CELL_INSET }), Create.listLayout({ Padding = 2 }) })
Recipes.scrollbar(body, theme)







local emptyArea = Create("Frame", { Name = "EmptyArea", BackgroundTransparency = 1, Active = false,
Position = UDim2.new(0, 0, 0, BODY_Y), Size = UDim2.new(1, 0, 1, -BODY_Y), ZIndex = 2, Parent = root })
local words = theme.Strings or DefaultTheme.Strings
local empty = Recipes.empty(emptyArea, { theme = theme, text = words.NoRows, icon = "inbox", zIndex = 2 })





local function buildRow(record, o)
if record.dead then return nil end
local row = makeRowFrame(body, false, o)
record.frame = row
record.drops[#record.drops + 1] = Recipes.hover(row, { theme = theme, kind = "fill" }).disconnect
for i, c in ipairs(record.cells) do
if c.editable then makeEditCell(row, record, i, cols[i], c)
else c.inst = makeLabelCell(row, c.value, i, cols[i], false) end
end
return row
end

local order = 0
local api = { Frame = root, Body = body }


function api.AddRow(cells, key)
local list, k = rowShape(cells, key)
order = order + 1
local o = order
if k == nil then k = o end
local record = { key = k, cells = {}, drops = {}, dead = false }
for i = 1, math.max(#list, minCells) do
local v = list[i]
local col = cols[i]
record.cells[i] = { value = v == nil and "" or tostring(v), editable = (col and col.Editable) or false }
end
rows[#rows + 1] = record
byKey[k] = record
local row

Safe.mutate(function()
row = buildRow(record, o)
if row then empty.SetVisible(false) end
end)
return row
end
function api.Clear()
order = 0
local old = rows
rows, byKey = {}, {}
for _, record in ipairs(old) do record.dead = true end
Safe.mutate(function()
for _, record in ipairs(old) do dropRecord(record) end

if #rows == 0 then empty.SetVisible(true) end
end)
end
function api.SetData(data) api.Clear(); for _, r in ipairs(data or {}) do api.AddRow(r) end end

function api.SetCell(key, col, text)
local record = byKey[key]
local c = record and record.cells[col]
if not c then return false end
c.value = text == nil and "" or tostring(text)
Safe.mutate(function() if c.inst then c.inst.Text = c.value end end)
return true
end

function api.GetCell(key, col)
local record = byKey[key]
local c = record and record.cells[col]
return c and c.value
end

function api.SetEnabled(b)
b = b and true or false
if enabled == b then return end
enabled = b
Safe.mutate(function()
for _, record in ipairs(rows) do

if not enabled then releaseFocused(record) end
for _, c in ipairs(record.cells) do
if c.editable and c.inst then
c.inst.TextEditable = enabled
c.inst.TextColor3 = enabled and theme.Colors.foreground or theme.Colors.mutedForeground
Recipes.disabled({ { c.frame, "BackgroundTransparency", 0 } }, not enabled, theme)
end
end
end
end)
end
function api.SetDisabled(b) api.SetEnabled(not b) end
function api.Destroy() maid:DoCleanup(); root:Destroy() end

api.SetData(opts.Rows)
maid:Give(root)
maid:Give(function()
local old = rows
rows, byKey = {}, {}
for _, record in ipairs(old) do dropRecord(record) end
end)

if opts.AccentReg then maid:Give(opts.AccentReg(function()
body.BackgroundColor3 = theme.Colors.surface
Recipes.scrollbar(body, theme)
rule.BackgroundColor3 = theme.Colors.border
empty.reskin()
for _, c in ipairs(header:GetChildren()) do if c.Name == "Cell" then c.TextColor3 = theme.Colors.mutedForeground end end
for _, record in ipairs(rows) do
if record.frame then record.frame.BackgroundColor3 = theme.Colors.surface end
for _, c in ipairs(record.cells) do
if c.paint then c.paint() elseif c.inst then c.inst.TextColor3 = theme.Colors.foreground end
end
end
end)) end

return api
end

return Table

end


EmbeddedModules["core/signal"] = function()
local Signal = {}
Signal.__index = Signal

function Signal.new()
return setmetatable({ _handlers = {}, _order = {} }, Signal)
end

function Signal:Connect(fn)
self._order[#self._order + 1] = fn
self._handlers[fn] = true
return { Disconnect = function()
self._handlers[fn] = nil
for i, f in ipairs(self._order) do if f == fn then table.remove(self._order, i) break end end
end }
end

function Signal:Once(fn)
local conn
conn = self:Connect(function(...) conn.Disconnect(); fn(...) end)
return conn
end

function Signal:Fire(...)
local snapshot = {}
for i, fn in ipairs(self._order) do snapshot[i] = fn end
for _, fn in ipairs(snapshot) do if self._handlers[fn] then fn(...) end end
end

function Signal:DisconnectAll()
self._handlers = {}; self._order = {}
end

return Signal

end


EmbeddedModules["core/mount"] = function()



local Mount = {}

function Mount.Init(R) end


function Mount.service(name)
local ok, s = pcall(function() return game:GetService(name) end)
if not ok or not s then return nil end
local okcr, cr = pcall(function() return cloneref or clonereference end)
if okcr and type(cr) == "function" then
local ok2, ref = pcall(cr, s)
if ok2 and ref then return ref end
end
return s
end


function Mount.resolve(config)
config = config or {}
if config.Parent ~= nil then return { parent = config.Parent } end

local studio = false
local rs = Mount.service("RunService")
if rs then local ok, v = pcall(function() return rs:IsStudio() end); studio = ok and v or false end


local ok, hui = pcall(function() return gethui and gethui() end)
if ok and hui then return { parent = hui, studio = studio } end


local protect = nil
if type(protectgui) == "function" then
protect = protectgui
elseif type(syn) == "table" and type(syn.protect_gui) == "function" then
protect = syn.protect_gui
end
local cg = Mount.service("CoreGui")
if cg then return { parent = cg, protect = protect, studio = studio } end


local players = Mount.service("Players")
local lp = players and players.LocalPlayer
if lp then
local pg = lp:FindFirstChildOfClass("PlayerGui")
if not pg then
local ok3, w = pcall(function() return lp:WaitForChild("PlayerGui", 5) end)
pg = ok3 and w or nil
end
if pg then return { parent = pg, studio = studio } end
end

return { parent = nil, studio = studio }
end


function Mount.guiName(config, studio)
config = config or {}
if type(config.GuiName) == "string" and config.GuiName ~= "" then return config.GuiName end
if config.Stealth == false or studio then return "EzUI" end
local hs = Mount.service("HttpService")
if hs then
local ok, guid = pcall(function() return hs:GenerateGUID(false) end)
if ok and guid then return guid end
end
return "_" .. tostring(math.random(100000, 999999999))
end




function Mount.finalize(gui, ctx)
ctx = ctx or {}
gui:SetAttribute("__ezui", true)
local parent = gui.Parent
if parent then
for _, inst in ipairs(parent:GetChildren()) do
if inst ~= gui and inst:GetAttribute("__ezui") then inst:Destroy() end
end
end
if ctx.protect and not ctx.studio then pcall(ctx.protect, gui) end
return gui
end




function Mount.anonName(readable)
local rs = Mount.service("RunService")
local studio = false
if rs then local ok, v = pcall(function() return rs:IsStudio() end); studio = ok and v or false end
if studio then return readable end
local hs = Mount.service("HttpService")
if hs then local ok, g = pcall(function() return hs:GenerateGUID(false) end); if ok and g then return g end end
return "_" .. tostring(math.random(100000, 999999999))
end

return Mount

end


EmbeddedModules["components/button"] = function()

local Button = {}
local Create, DefaultTheme, Animate, Maid, Icons, Safe, Recipes, Device

function Button.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Icons = R.Icons; Safe = R.Safe
Recipes = R.Recipes; Device = R.Device
end

local function palette(theme, variant)
if variant == "destructive" then return theme.Colors.destructive, theme.Colors.primaryForeground, nil end
if variant == "secondary" then return theme.Colors.surface, theme.Colors.foreground, nil end
if variant == "outline" then return theme.Colors.card, theme.Colors.foreground, theme.Colors.border end
if variant == "ghost" then return theme.Colors.surface, theme.Colors.foreground, nil end
return theme.Colors.primary, theme.Colors.primaryForeground, nil
end



local function pointerHover() return Device.SupportsHover() and Device.GetInput() ~= "Touch" end

function Button.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local variant = opts.Variant or "default"
local maid = Maid.new()
local bg, fg, stroke = palette(theme, variant)
local transparent = (variant == "ghost")
local auto = opts.AutoWidth and true or false




local btn = Create("TextButton", {
Name = "Button", AutoButtonColor = false, Text = "",
BackgroundTransparency = 1,
Size = auto and UDim2.new(0, 0, 0, 34) or UDim2.new(1, 0, 0, 34),
AutomaticSize = auto and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent,
})
if auto then Create("UISizeConstraint", { MinSize = Vector2.new(72, 0), Parent = btn }) end


local surface = Create("Frame", {
Name = "Surface", BackgroundColor3 = bg, BackgroundTransparency = transparent and 1 or 0,
AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
Size = auto and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 1, 0),
AutomaticSize = auto and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
Active = false, Parent = btn,
Create.corner(theme.Radius.md),
})
local scale = Create("UIScale", { Scale = 1, Parent = surface })


local line = stroke and Create("UIStroke", { Color = stroke, Thickness = 1, Parent = surface }) or nil

local hovering = false
local bgNormal = transparent and 1 or 0



local bgHover = transparent and theme.Opacity.ghostHover or theme.Opacity.hoverFill
local bgPressed = transparent and theme.Opacity.ghostPress or theme.Opacity.pressFill






local hasIcon = opts.Icon ~= nil
local label, iconImg
Create.padding({ left = 14, right = 14 }).Parent = surface
Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, theme.Spacing.icon), Parent = surface })
if hasIcon then
iconImg = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), LayoutOrder = 1, Parent = surface })
Icons.apply(iconImg, opts.Icon, fg)
end
label = Create.text(Create("TextLabel", { Name = "Label", BackgroundTransparency = 1,
Text = opts.Text or "Button", TextColor3 = fg,
AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 2, Parent = surface }), theme, "label")
if not auto then Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink, Parent = label }) end


local enabled, loading, pressed = true, false, false
local function blocked() return (not enabled) or loading end


local function lineColor() return (variant == "outline" and hovering) and theme.Colors.ring or stroke end
local function paintSurface(alpha) Animate.to(surface, "hover", { BackgroundTransparency = alpha }) end

local function enter()
if blocked() then return end
hovering = true
paintSurface(bgHover)
if line and variant == "outline" then Animate.to(line, "hover", { Color = lineColor() }) end
end
local function leave()
hovering = false
if blocked() then return end
paintSurface(bgNormal)

if pressed then pressed = false; Animate.springTo(scale, "release", { Scale = 1 }) end
if line and variant == "outline" then Animate.to(line, "hover", { Color = lineColor() }) end
end
maid:Give(btn.MouseEnter:Connect(enter))
maid:Give(btn.MouseLeave:Connect(leave))
maid:Give(btn.MouseButton1Down:Connect(function()
if blocked() then return end
pressed = true
Animate.to(scale, "press", { Scale = theme.Motion.pressScale })
Animate.to(surface, "press", { BackgroundTransparency = bgPressed })
end))
maid:Give(btn.MouseButton1Up:Connect(function()
if blocked() then return end
pressed = false
Animate.springTo(scale, "release", { Scale = 1 })

if not pointerHover() then hovering = false end
paintSurface(hovering and bgHover or bgNormal)
if line and variant == "outline" then Animate.to(line, "hover", { Color = lineColor() }) end
end))
maid:Give(btn.MouseButton1Click:Connect(function()
if blocked() then return end
if opts.Action == "ResetConfig" and opts.Window and opts.Window.ResetConfiguration then opts.Window:ResetConfiguration() end
if opts.Callback then opts.Callback() end
end))
maid:Give(btn)

local function dimParts()
local parts = { { label, "TextTransparency", 0 } }
if not transparent then parts[#parts + 1] = { surface, "BackgroundTransparency", bgNormal } end
if line then parts[#parts + 1] = { line, "Transparency", theme.Stroke.control } end
if iconImg then parts[#parts + 1] = { iconImg, "ImageTransparency", 0 } end
return parts
end
local function setEnabled(en)

enabled = en ~= false
btn.Active = enabled
if enabled then hovering = false; pressed = false end
Safe.mutate(function()
if enabled then scale.Scale = 1 end
Recipes.disabled(dimParts(), not enabled, theme)
end)
end


local spinner, spin
local function stopSpin() if spin then spin.Cancel(); spin = nil end end
local function mkSpinner()
if spinner then return spinner end


spinner = Create("ImageLabel", { Name = "Spinner", BackgroundTransparency = 1, Visible = false,
Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), LayoutOrder = 2, Parent = surface })
Icons.apply(spinner, "loader", fg)
return spinner
end
local function setLoading(b)
loading = b and true or false
if loading then pressed = false; hovering = false end
Safe.mutate(function()
local s = mkSpinner()
stopSpin()
if loading then
scale.Scale = 1
paintSurface(bgNormal)



Animate.toThen(label, "fast", { TextTransparency = 1 }, function()
if not loading then return end
label.Visible = false
s.Visible = true
stopSpin()
spin = Animate.spin(s)
end)
else
s.Visible = false
label.Visible = true
Animate.to(label, "fast", { TextTransparency = 0 })
end
end)
end
maid:Give(stopSpin)

if opts.AccentReg then maid:Give(opts.AccentReg(function()
local nbg, nfg, nstroke = palette(theme, variant)
bg, fg, stroke = nbg, nfg, nstroke
if not transparent then surface.BackgroundColor3 = nbg end
label.TextColor3 = nfg
if iconImg then Icons.apply(iconImg, opts.Icon, nfg) end
if spinner then Icons.apply(spinner, "loader", nfg) end
if line then line.Color = lineColor() end
end)) end

if opts.Disabled then setEnabled(false) end
if opts.Loading then setLoading(true) end

local shownText = opts.Text or "Button"
return {
Frame = btn,


SetText = function(s)
if s == shownText then return end
Safe.mutate(function() label.Text = s; shownText = s end)
end,

SetEnabled = setEnabled,
SetLoading = setLoading,
Destroy = function() maid:DoCleanup() end,
}
end

return Button

end


EmbeddedModules["components/selectbox"] = function()

local RunService = game:GetService("RunService")
local SelectBox = {}
local Create, DefaultTheme, Animate, Maid, Icons, Overlay, Flag, Safe, Recipes, Effects, Acrylic, SelectRows

function SelectBox.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid
Icons = R.Icons; Overlay = R.Overlay; Flag = R.Flag; Safe = R.Safe; Recipes = R.Recipes
Effects = R.Effects; Acrylic = R.Acrylic; SelectRows = R.SelectRows
end

local CARET_OPEN = 180


local REANCHOR = 24




local SKELETON_ROWS = { 0.6, 0.8, 0.45 }
local SKELETON_H, SKELETON_GAP = 10, 8
local LOADING_H = #SKELETON_ROWS * SKELETON_H + (#SKELETON_ROWS - 1) * SKELETON_GAP


local EMPTY_ICON = "search"




local function emptyH(t) return t.Sizes.icon + t.Spacing.gap * 2 + t.Font.muted.Size end

local function frostAlpha(theme) return theme.Acrylic.popoverFrost end





local function popOpen(frame, theme, edge, scale)
local us = frame:FindFirstChildOfClass("UIScale")
if not us then return nil end
if not Animate.isEnabled() then us.Scale = scale; return nil end
local target = frame.Position
us.Scale = scale * theme.Motion.exitScale
local dy = (edge == "up") and theme.Motion.popSlide or -theme.Motion.popSlide
frame.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + dy)
local slide = Animate.to(frame, "fast", { Position = target }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Animate.springTo(us, "base", { Scale = scale })
return slide
end

local function popShut(frame, theme, scale, onDone)
if scale == 1 then return Animate.popOut(frame, onDone) end
local us = frame:FindFirstChildOfClass("UIScale")
if not us then if onDone then onDone() end; return nil end
return Animate.toThen(us, "exit", { Scale = scale * theme.Motion.exitScale }, onDone,
Animate.EASING.exit, Animate.DIR.In)
end

local function contains(arr, v) for _, x in ipairs(arr) do if x == v then return true end end return false end

local function normOpt(o)


if type(o) == "table" then
return {
value = o.Value ~= nil and o.Value or o.value,
label = o.Text or o.Label or o.text or o.label,
icon = o.Icon or o.icon,
desc = o.Desc or o.desc,
divider = o.Divider == true or o.divider == true,
}
end
return { value = o }
end

function SelectBox.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()


local normed = {}
local function setOptionList(o)
normed = {}
for i, raw in ipairs(o or {}) do normed[i] = normOpt(raw) end
end
setOptionList(opts.Options)
local multi = opts.Multi == true



local function firstValue() return normed[1] ~= nil and normed[1].value or nil end
local value = multi and (opts.Default or {}) or (opts.Default ~= nil and opts.Default or firstValue())
local dropdown
local shadow
local ddScale = 1
local posConn
local searchFocus
local ddUnreg


local ddRows
local skeletons = {}
local emptyState


local ddSearchable, ddHeight, ddLoading = false, 0, false
local ddSlide

local ddAt, ddAnchor
local lastQuery = ""
local buildDropdown, rebuild, computePos, refresh, syncSelection, syncRows, followControl
local onChanged = opts.Callback

local function labelFor(v)
for _, e in ipairs(normed) do
if not e.divider and e.value == v then return e.label or tostring(e.value) end
end
return tostring(v)
end


local words = theme.Strings or DefaultTheme.Strings
local function display()
if multi then
if #value == 0 then return words.None end
local shown = {}
for i = 1, math.min(2, #value) do shown[i] = labelFor(value[i]) end
local s = table.concat(shown, ", ")
if #value > 2 then s = s .. " +" .. (#value - 2) end
return s
end
if value == nil then return words.Select end
return labelFor(value)
end

local hasDesc = opts.Description ~= nil and opts.Description ~= ""
local btn = Create("TextButton", {
Name = "SelectBox", AutoButtonColor = false, Text = "",
BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 0,
Size = UDim2.new(1, 0, 0, hasDesc and 52 or 38), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent,
Create.corner(theme.Radius.md),
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }),
})
if opts.Text then
local title = Create("TextLabel", { Name = "Title", BackgroundTransparency = 1, Text = opts.Text,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
Position = UDim2.new(0, 0, 0, hasDesc and 8 or 0),
Size = UDim2.new(0.5, -8, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn })
Create.text(title, theme, "label")
if hasDesc then
local desc = Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
TextYAlignment = Enum.TextYAlignment.Top,
Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(0.5, -8, 0, 18), Parent = btn })
Create.text(desc, theme, "muted")
end
end



function computePos(width, ddH, scale)
local sz = btn.AbsoluteSize or { X = 140, Y = 38 }
return Overlay.placePopover(btn.AbsolutePosition, sz, width * (scale or 1), ddH * (scale or 1))
end



local field = Create("Frame", { Name = "Field", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0, Active = false,
BackgroundTransparency = 0,
Size = opts.Text and UDim2.new(0.5, -4, 0, 26) or UDim2.new(1, 0, 0, 26),
Position = opts.Text and UDim2.new(0.5, 4, 0.5, -13) or UDim2.new(0, 0, 0.5, -13),
Parent = btn, Create.corner(theme.Radius.sm) })
local fieldStroke = Create.stroke(theme.Colors.border, 1); fieldStroke.Parent = field
local valueLabel = Create("TextLabel", { Name = "Value", BackgroundTransparency = 1, Text = display(),
TextColor3 = theme.Colors.foreground, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,


TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 8, 0, 0), Parent = field })
Create.text(valueLabel, theme, "body")




local disabled, open = false, false
local function caretColor()
if disabled then return theme.Colors.mutedForeground end
return theme.Colors[open and theme.Icon.structuralActive or theme.Icon.structural]
end
local caret = Create("ImageLabel", { Name = "Caret", BackgroundTransparency = 1,
Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -20, 0.5, -7), Parent = field })
Icons.apply(caret, "chevron-down", caretColor())



local function fieldStrokeColor() return open and theme.Colors.ring or theme.Colors.border end
local fieldFocus = Recipes.focus(fieldStroke, field, fieldStrokeColor, { theme = theme })
maid:Give(fieldFocus.disconnect)
local function setOpen(b)
b = b and true or false
if open == b then return end
open = b
Icons.tint(caret, caretColor())


Animate.rotateTo(caret, "base", open and CARET_OPEN or 0, Animate.EASING.smooth, Animate.DIR.Out)
fieldFocus.set(open)
end

local fieldIcon = Create("ImageLabel", { Name = "FieldIcon", BackgroundTransparency = 1, Visible = false,
Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 8, 0.5, -7), Parent = field })
local clearBtn = Create("ImageButton", { Name = "Clear", BackgroundTransparency = 1, Visible = false,
Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -38, 0.5, -7), Parent = field })
Icons.apply(clearBtn, "x", theme.Colors.mutedForeground)
local spinner = Create("ImageLabel", { Name = "Spinner", BackgroundTransparency = 1, Visible = false,
Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -20, 0.5, -7), Parent = field })
Icons.apply(spinner, "loader", theme.Colors.mutedForeground)

local function selectedIcon()
if multi then return nil end
for _, e in ipairs(normed) do if e.value == value then return e.icon end end
return nil
end
local function relayout()
local left = fieldIcon.Visible and 26 or 8
local right = clearBtn.Visible and 38 or 24
valueLabel.Position = UDim2.new(0, left, 0, 0)
valueLabel.Size = UDim2.new(1, -(left + right), 1, 0)
end



local DIM = { { field, "BackgroundTransparency", 0 }, { valueLabel, "TextTransparency", 0 } }


local function paintDisabled(animated)
valueLabel.TextColor3 = disabled and theme.Colors.mutedForeground or theme.Colors.foreground
if animated then
Recipes.disabled(DIM, disabled, theme)
else
local a = disabled and theme.Opacity.disabled or 0
for _, p in ipairs(DIM) do p[1][p[2]] = a end
end
end
local function setDisabled(b)
disabled = b and true or false
Safe.mutate(function() paintDisabled(true); Icons.tint(caret, caretColor()) end)
end

local loading = false
local spin
local function stopSpin() if spin then spin.Cancel(); spin = nil end end
local function setLoading(b)
loading = b and true or false
Safe.mutate(function()
caret.Visible = not loading
spinner.Visible = loading
stopSpin()
if loading then spin = Animate.spin(spinner) end
refresh()
if dropdown then rebuild() end
end)
end

function refresh()
if loading then

fieldIcon.Visible = false
clearBtn.Visible = false
relayout()
valueLabel.Text = words.Loading
return
end
local ic = selectedIcon()
if ic then Icons.apply(fieldIcon, ic, theme.Colors.foreground); fieldIcon.Visible = true
else fieldIcon.Visible = false end
clearBtn.Visible = multi and #value > 0
relayout()
valueLabel.Text = display()
end


local function apply(v)
value = v
Safe.mutate(function()
refresh()
if dropdown and not loading then syncSelection() end
end)
end
local commit = Flag.bind(opts, value, apply)

local api = { Frame = btn }
function api.GetValue() return value end
function api.SetValue(v) commit(v); if onChanged then onChanged(value) end end
function api.SetOptions(o)
setOptionList(o)


local offered = {}
for _, e in ipairs(normed) do
if not e.divider and SelectRows.keyOf(e.value) ~= SelectRows.NOKEY then offered[e.value] = true end
end
local function present(v) return v ~= nil and offered[v] == true end
if multi then
local nv = {}
for _, v in ipairs(value) do if present(v) then nv[#nv + 1] = v end end
value = nv
elseif value ~= nil and not present(value) then
value = opts.AllowNone and nil or firstValue()
end


Safe.mutate(function()
refresh()
if dropdown then

if loading or ddLoading then rebuild() else syncRows() end
end
end)
end
function api.SetDisabled(b) setDisabled(b) end
function api.SetLoading(b) setLoading(b) end


local function pickedSet()
local set = {}
local function add(v) if SelectRows.keyOf(v) ~= SelectRows.NOKEY then set[v] = true end end
if multi then for _, v in ipairs(value) do add(v) end else add(value) end
return set
end


local function rowPicked(v, set)
if v == nil then return not multi and value == nil end
return set[v] == true
end



local function pickedTest()
local set = pickedSet()
return function(v) return rowPicked(v, set) end
end
local function retintRows() if ddRows then ddRows:repaint() end end

local function pick(opt)
if multi then
local nv = {}
for _, x in ipairs(value) do nv[#nv + 1] = x end
if contains(nv, opt) then
for i, x in ipairs(nv) do if x == opt then table.remove(nv, i) break end end
else
nv[#nv + 1] = opt
end
api.SetValue(nv)
if dropdown then syncSelection() end
else
if opts.AllowNone and value == opt then
api.SetValue(nil)
else
api.SetValue(opt)
end
api.Close()
end
end




local function syncEmpty()
if not emptyState then return end
emptyState.SetVisible(not (ddRows and ddRows.rowsShown > 0))
end


function api.Filter(query)
query = (query or ""):lower()
lastQuery = query
if ddRows then ddRows:filter(query) end
syncEmpty()
end


local rowCtx = { theme = theme, onPick = pick, picked = pickedTest, viewH = 0 }



function syncSelection() if ddRows then ddRows:syncSelection() end end




local function popoverShape()
local searchable = false
if not loading then
if opts.Searchable ~= nil then searchable = opts.Searchable == true
else
local n = 0
for _, e in ipairs(normed) do if not e.divider then n = n + 1 end end
searchable = n > 5
end
end




local bodyH = loading and LOADING_H or math.max(#normed * 28, emptyH(theme))
return searchable, math.min(bodyH + (searchable and 44 or 8), 240)
end




function syncRows()
local searchable, ddH = popoverShape()
if searchable ~= ddSearchable then rebuild(); return end
if ddH ~= ddHeight then


ddHeight = ddH
if ddSlide and ddSlide.Cancel then ddSlide:Cancel() end
ddSlide = nil
local width = dropdown.Size.X.Offset
local x, y = computePos(width, ddH, ddScale)
dropdown.Size = UDim2.new(0, width, 0, ddH)
dropdown.Position = UDim2.new(0, x, 0, y)
Effects.place(shadow, x, y, width * ddScale, ddH * ddScale, "popover", theme)
ddAt, ddAnchor = { x, y }, btn.AbsolutePosition
rowCtx.viewH = ddH - (ddSearchable and 34 or 4) - 4
end
if ddRows then ddRows:setOptions(normed) end
syncEmpty()
end


function buildDropdown(query)
ddRows = nil
skeletons = {}
lastQuery = ""
local searchable, ddH = popoverShape()
ddSearchable, ddHeight, ddLoading = searchable, ddH, loading
local sz = btn.AbsoluteSize or { X = 140, Y = 38 }
local width = math.max(140, sz.X or 140)


local scale = Overlay.scale()
ddScale = scale
local x, y, openUp = computePos(width, ddH, scale)
ddAt, ddAnchor = { x, y }, btn.AbsolutePosition



dropdown = Create("Frame", {
Name = "SelectDropdown", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0, Active = true,
Position = UDim2.new(0, x, 0, y),
Size = UDim2.new(0, width, 0, ddH),
ClipsDescendants = true, ZIndex = Overlay.Z.popover,
Create.corner(theme.Radius.md),
Create("UIScale", { Scale = scale }),
})
local ddStroke = Create.stroke(theme.Colors.border, 1, theme.Stroke.floating); ddStroke.Parent = dropdown



Acrylic.decorate(dropdown, theme, {
transparency = frostAlpha(theme), edge = true, radius = theme.Radius.md, strokeAlpha = theme.Stroke.floating,
})



local overlayRoot = Overlay.peek()
shadow = overlayRoot and Effects.shadow(overlayRoot, theme,
{ name = "SelectDropdownShadow", level = "popover", zIndex = Overlay.Z.catcher }) or nil
Effects.place(shadow, x, y, width * scale, ddH * scale, "popover", theme)



local searchBox, searchInput, searchStroke, searchRest
local searchFocused = false
local loadingRow = nil
local listTop = 4
if searchable then
listTop = 34
searchBox = Create("Frame", { Name = "Search", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0, 26), ZIndex = 1003, Parent = dropdown,
Create.corner(theme.Radius.sm), Create.padding({ left = 8, right = 8 }) })
searchInput = Create("TextBox", { Name = "Input", BackgroundTransparency = 1, Text = "",
PlaceholderText = words.Search, PlaceholderColor3 = theme.Colors.mutedForeground, TextColor3 = theme.Colors.foreground,
TextXAlignment = Enum.TextXAlignment.Left,
ClearTextOnFocus = false, ZIndex = 1003, Size = UDim2.new(1, 0, 1, 0), Parent = searchBox })
Create.text(searchInput, theme, "muted")





searchRest = function() return theme.modeVal(theme, theme.Stroke.search) end
searchStroke = Create.stroke(theme.Colors.border, 1, searchRest()); searchStroke.Parent = searchBox
searchFocus = Recipes.focus(searchStroke, searchInput, function(focused)
searchFocused = focused
return focused and theme.Colors.ring or theme.Colors.border
end, { theme = theme, restAlpha = searchRest })
searchInput:GetPropertyChangedSignal("Text"):Connect(function() Safe.mutate(function() api.Filter(searchInput.Text) end) end)
end



local list = Create("ScrollingFrame", {
Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0,
Position = UDim2.new(0, 4, 0, listTop),
Size = UDim2.new(1, -8, 1, -(listTop + 4)),
ClipsDescendants = true, ZIndex = 1001,
AutomaticCanvasSize = Enum.AutomaticSize.None, CanvasSize = UDim2.new(0, 0, 0, 0),
Parent = dropdown,
})
Recipes.scrollbar(list, theme)

if loading then




loadingRow = Create("Frame", { Name = "Loading", BackgroundTransparency = 1, Active = false,
Size = UDim2.new(1, 0, 0, LOADING_H), ZIndex = 1002, LayoutOrder = 1, Parent = list })
for i, w in ipairs(SKELETON_ROWS) do
skeletons[i] = Effects.skeleton(loadingRow, theme, {
name = "Line" .. i, zIndex = 1003, radius = theme.Radius.xs,
size = UDim2.new(w, 0, 0, SKELETON_H),
position = UDim2.new(0, 0, 0, (i - 1) * (SKELETON_H + SKELETON_GAP)),
})
end
else
rowCtx.viewH = ddH - listTop - 4
ddRows = SelectRows.new(list, rowCtx)
ddRows:setOptions(normed)



emptyState = Recipes.empty(dropdown, { theme = theme, text = words.NoResults, icon = EMPTY_ICON, zIndex = 1003 })



emptyState.Frame.Position = UDim2.new(0, 4, 0, listTop)
emptyState.Frame.Size = UDim2.new(1, -8, 1, -(listTop + 4))
syncEmpty()
end




posConn = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() Safe.mutate(followControl) end)
Overlay.mount(dropdown)
Overlay.trackPopover(api.Close)




local ddFrame, ddShadow = dropdown, shadow
ddUnreg = opts.AccentReg and opts.AccentReg(function()
Acrylic.reskin(ddFrame, theme, { transparency = frostAlpha(theme), edge = true,
radius = theme.Radius.md, strokeAlpha = theme.Stroke.floating })
Effects.reskin(ddShadow, theme, "shadow")
Recipes.scrollbar(list, theme)
if searchBox then
searchBox.BackgroundColor3 = theme.Colors.surface
searchInput.TextColor3 = theme.Colors.foreground
searchInput.PlaceholderColor3 = theme.Colors.mutedForeground
searchStroke.Color = searchFocused and theme.Colors.ring or theme.Colors.border
searchStroke.Transparency = searchFocused and theme.Stroke.control or searchRest()
end



for _, sk in ipairs(skeletons) do sk.Frame.BackgroundColor3 = theme.Colors.surface end
if emptyState then emptyState.reskin() end
retintRows()
end) or nil

if searchInput and query and query ~= "" then
searchInput.Text = query
api.Filter(query)
end
setOpen(true)


ddSlide = popOpen(dropdown, theme, openUp and "up" or "down", scale)
end

function api.Open()
if disabled or dropdown then return end
if opts.OnOpen then opts.OnOpen(api) end
buildDropdown()
end








local function teardown(instant)
local dd, sh = dropdown, shadow



local sks = skeletons
dropdown, shadow, skeletons, emptyState = nil, nil, {}, nil
if posConn then posConn:Disconnect(); posConn = nil end


if ddUnreg then ddUnreg(); ddUnreg = nil end
if searchFocus then searchFocus.disconnect(); searchFocus = nil end
if ddRows then ddRows:destroy() end
ddRows, lastQuery, ddSlide, ddAt, ddAnchor = nil, "", nil, nil, nil
Overlay.untrackPopover(api.Close)
local function stopSkeletons() for _, sk in ipairs(sks) do sk.Stop() end end
if not dd then stopSkeletons(); return end
local function drop() dd:Destroy(); if sh then sh:Destroy() end end



if instant then drop(); stopSkeletons() else stopSkeletons(); popShut(dd, theme, ddScale, drop) end
end
function rebuild()
local query = lastQuery
if dropdown then teardown(true) end
buildDropdown(query)
end
function api.Close() teardown(); setOpen(false) end




function followControl()
if not dropdown then return end
local p = btn.AbsolutePosition
if not (p and ddAnchor and ddAt) then api.Close(); return end
local dx, dy = p.X - ddAnchor.X, p.Y - ddAnchor.Y
if math.abs(dx) > REANCHOR or math.abs(dy) > REANCHOR then api.Close(); return end
if ddSlide and ddSlide.Cancel then ddSlide:Cancel() end
ddSlide = nil

local sz = dropdown.Size
local x, y = computePos(sz.X.Offset, sz.Y.Offset, ddScale)
dropdown.Position = UDim2.new(0, x, 0, y)
Effects.place(shadow, x, y, sz.X.Offset * ddScale, sz.Y.Offset * ddScale, "popover", theme)
end

function api.Destroy() api.Close(); maid:DoCleanup() end

maid:Give(btn.MouseButton1Click:Connect(function()
if disabled then return end
if dropdown then api.Close() else api.Open() end
end))
maid:Give(clearBtn.MouseButton1Click:Connect(function() if multi then api.SetValue({}) end end))
maid:Give(btn)
maid:Give(stopSpin)
maid:Give(function() api.Close() end)
if opts.Disabled then setDisabled(true) end
if opts.Loading then setLoading(true) end

if opts.AccentReg then maid:Give(opts.AccentReg(function()
btn.BackgroundColor3 = theme.Colors.surface
field.BackgroundColor3 = theme.Colors.background
fieldStroke.Color = fieldStrokeColor()
local ti = btn:FindFirstChild("Title"); if ti then ti.TextColor3 = theme.Colors.foreground end
local de = btn:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
paintDisabled()
Icons.apply(caret, "chevron-down", caretColor())
Icons.apply(clearBtn, "x", theme.Colors.mutedForeground)
if fieldIcon.Visible then local ic = selectedIcon(); if ic then Icons.apply(fieldIcon, ic, theme.Colors.foreground) end end
Icons.apply(spinner, "loader", theme.Colors.mutedForeground)
end)) end


















local loadToken = 0
local function runLoader()
if type(opts.LoadOptions) ~= "function" then return end
loadToken = loadToken + 1
local token = loadToken
setLoading(true)
local conn
conn = RunService.Heartbeat:Once(function()
if token ~= loadToken then return end
local ok, result = pcall(opts.LoadOptions)
if token ~= loadToken then return end
if ok and type(result) == "table" then api.SetOptions(result) end
setLoading(false)
end)
if conn then maid:Give(conn) end


local timeout = type(opts.Timeout) == "number" and opts.Timeout or 60
task.delay(timeout, function()
if token ~= loadToken then return end
if loading then setLoading(false) end
end)
end
function api.Reload() runLoader() end
maid:Give(function() loadToken = loadToken + 1 end)
if opts.LoadOptions then runLoader() end

return api
end

return SelectBox

end


EmbeddedModules["components/tooltip"] = function()



local Tooltip = {}
local Create, DefaultTheme, Maid, Overlay, Animate, Device, Safe, Effects
local TextService = game:GetService("TextService")

function Tooltip.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Overlay = R.Overlay; Animate = R.Animate
Device = R.Device; Safe = R.Safe; Effects = R.Effects
end



local GLYPH_W = 0.55

local function measure(text, size)
local ok, v = pcall(function()
return TextService:GetTextSize(text, size, Enum.Font.BuilderSans, Vector2.new(10000, 10000))
end)
if ok and v and v.X then return v.X end
return #tostring(text) * size * GLYPH_W
end

function Tooltip.attach(target, text, themeArg)
local theme = themeArg or DefaultTheme
local maid = Maid.new()
local handle = { Destroy = function() maid:DoCleanup() end }


if Device and Device.IsTouch() then return handle end

local tip, shadow, armed




local function geometry(scale)
local T = theme.Tooltip
local ap, as = target.AbsolutePosition, target.AbsoluteSize
local tx, ty = (ap and ap.X or 0), (ap and ap.Y or 0)
local tw, th = (as and as.X or 0), (as and as.Y or 0)
local gap, hgt = T.gap * scale, T.height * scale
local w = (measure(text, theme.Font.muted.Size) + 2 * T.padX) * scale
local vp = Overlay.viewport()
local y = ty - gap
if y - hgt < 0 then y = ty + th + gap + hgt end
if y > vp.Y then y = vp.Y end
local half = w / 2
local x = math.max(half, math.min(tx + tw / 2, vp.X - half))
return x, y, w, hgt
end

local function build()
if tip then return end
local T = theme.Tooltip
local scale = Overlay.scale()
local x, y, w, hgt = geometry(scale)


tip = Create("TextLabel", {
Name = "Tooltip", BackgroundColor3 = theme.Colors.foreground, BackgroundTransparency = 1,
BorderSizePixel = 0, Text = text, TextColor3 = theme.Colors.background, TextTransparency = 1,
AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, x, 0, y),
Size = UDim2.new(0, 0, 0, T.height), AutomaticSize = Enum.AutomaticSize.X,
ZIndex = Overlay.Z.tooltip,
Create.corner(theme.Radius.sm), Create.padding({ left = T.padX, right = T.padX }),
})
Create.text(tip, theme, "muted")

local us = Create("UIScale", { Scale = scale * theme.Motion.popFrom, Parent = tip })
Overlay.mount(tip)

shadow = Effects.shadow(tip.Parent, theme, { name = "TooltipShadow", level = "tooltip",
zIndex = Overlay.Z.tooltip - 1 })
if shadow then
shadow.ImageTransparency = 1
Effects.place(shadow, x - w / 2, y - hgt, w, hgt, "tooltip", theme)
Animate.to(shadow, "fast", { ImageTransparency = (theme.fx or DefaultTheme.fx)(theme).shadow })
end
Animate.springTo(us, "fast", { Scale = scale })
Animate.to(tip, "fast", { BackgroundTransparency = 0, TextTransparency = 0 })
end



local function hide()
local t, s = tip, shadow
tip, shadow = nil, nil
if not t then return end
if s then Animate.to(s, "exit", { ImageTransparency = 1 }, Animate.EASING.exit, Animate.DIR.In) end
Animate.toThen(t, "exit", { BackgroundTransparency = 1, TextTransparency = 1 }, function()
t:Destroy()
if s then s:Destroy() end
end, Animate.EASING.exit, Animate.DIR.In)
end




local function onEnter()
if tip then return end
local token = {}
armed = token
local function fire()
if armed == token and not tip then Safe.mutate(build) end
end
if type(task) == "table" and task.delay then task.delay(theme.Tooltip.delay, fire) else fire() end
end

local function onLeave()
armed = nil
hide()
end

maid:Give(target.MouseEnter:Connect(onEnter))
maid:Give(target.MouseLeave:Connect(onLeave))
maid:Give(function() onLeave() end)
return handle
end

return Tooltip

end


EmbeddedModules["components/accordion"] = function()

local Accordion = {}
local Create, DefaultTheme, Animate, Maid, Icons, Host, REG, Safe, Recipes

function Accordion.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid; Icons = R.Icons
Host = R.Host; REG = R; Safe = R.Safe; Recipes = R.Recipes
end

local HEADER_H = 34

function Accordion.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local expanded = opts.Expanded == true
local order = 0

local container = Create("Frame", {
Name = "Accordion",
BackgroundColor3 = theme.Colors.card,
BackgroundTransparency = 0,
ClipsDescendants = true,
AutomaticSize = Enum.AutomaticSize.None,
Size = UDim2.new(1, 0, 0, HEADER_H),
LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.Parent,
})
Create("UIStroke", { Color = theme.Colors.border, Thickness = 1, Parent = container })
Create("UICorner", { CornerRadius = UDim.new(0, theme.Radius.md), Parent = container })

local header = Create("TextButton", {
Name = "Header",
Text = "",
AutoButtonColor = false,
BackgroundColor3 = theme.Colors.card,
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, HEADER_H),
Parent = container,
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }),
})


Create.corner(theme.Radius.md).Parent = header

local caret = Create("ImageLabel", {
Name = "Caret",
BackgroundTransparency = 1,
Size = UDim2.new(0, 16, 0, 16),
Position = UDim2.new(0, 0, 0.5, -8),
Parent = header,
})


local function caretColor() return theme.Colors[expanded and theme.Icon.structuralActive or theme.Icon.structural] end
Icons.apply(caret, "chevron-right", caretColor())
caret.Rotation = expanded and 90 or 0


local caretScale = Create("UIScale", { Scale = 1, Parent = caret })

local leadIcon
if opts.Icon then
leadIcon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 24, 0.5, -8), Parent = header })
Icons.apply(leadIcon, opts.Icon, theme.Colors[theme.Icon.accent])
end
local titleX = opts.Icon and 46 or 24
local title = Create("TextLabel", {
Name = "Title",
BackgroundTransparency = 1,
Text = opts.Title or "Section",
TextColor3 = theme.Colors.foreground,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, -titleX, 1, 0),
Position = UDim2.new(0, titleX, 0, 0),
Parent = header,
})
Create.text(title, theme, "label")

local content = Create("Frame", {
Name = "Content",
BackgroundTransparency = 1,
AutomaticSize = Enum.AutomaticSize.Y,
Size = UDim2.new(1, 0, 0, 0),
Position = UDim2.new(0, 0, 0, HEADER_H + theme.Spacing.gap),
Visible = expanded,
Parent = container,
Create.listLayout({ Padding = theme.Spacing.gap }),
Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX, bottom = theme.Spacing.inputY }),
})
local layout = content:FindFirstChildOfClass("UIListLayout")

local divider = Create("Frame", {
Name = "Divider", BackgroundColor3 = theme.Colors.border, BorderSizePixel = 0,
Size = UDim2.new(1, -theme.Spacing.inputX * 2, 0, 1), Position = UDim2.new(0, theme.Spacing.inputX, 0, HEADER_H),
Visible = expanded, ZIndex = 2, Parent = container,
})

local api = { Container = container, Header = header, Content = content, Maid = maid }

local GAP = theme.Spacing.gap
local REST_Y = HEADER_H + GAP




local function hasContent()
local acs = layout.AbsoluteContentSize
return acs ~= nil and (acs.Y or 0) > 0
end




local function contentHeight()

local acs = layout.AbsoluteContentSize
local y = (acs and acs.Y) or 0
return y + theme.Spacing.inputY
end














local motion = 0
local function settle(gen, want, fn)

return function() Safe.mutate(function() if gen == motion and expanded == want then fn() end end) end
end
local function applyHeight(animated)
motion = motion + 1
local gen = motion
if animated then



Animate.rotateTo(caret, "base", expanded and 90 or 0, Animate.EASING.smooth, Animate.DIR.Out)
Icons.tint(caret, caretColor(), "fast")
caretScale.Scale = theme.Motion.popFrom
Animate.springTo(caretScale, "release", { Scale = 1 })
if expanded then




content.Visible = true
divider.Visible = true; divider.BackgroundTransparency = 1
Animate.to(divider, "fast", { BackgroundTransparency = 0 })
content.Position = UDim2.new(0, 0, 0, REST_Y + GAP)
Animate.to(content, "base", { Position = UDim2.new(0, 0, 0, REST_Y) })
if hasContent() then
container.AutomaticSize = Enum.AutomaticSize.None
local target = REST_Y + contentHeight()
container.Size = UDim2.new(1, 0, 0, HEADER_H)
Animate.toThen(container, "base", { Size = UDim2.new(1, 0, 0, target) }, settle(gen, true, function()
container.AutomaticSize = Enum.AutomaticSize.Y
container.Size = UDim2.new(1, 0, 0, HEADER_H)
end))
else



container.AutomaticSize = Enum.AutomaticSize.Y
container.Size = UDim2.new(1, 0, 0, HEADER_H)
end
else


Animate.to(divider, "fast", { BackgroundTransparency = 1 })
Animate.to(content, "exit", { Position = UDim2.new(0, 0, 0, REST_Y + GAP) },
Animate.EASING.exit, Animate.DIR.In)

local sz = container.AbsoluteSize
local from = (sz and sz.Y and sz.Y > HEADER_H) and sz.Y or (REST_Y + contentHeight())
container.AutomaticSize = Enum.AutomaticSize.None
container.Size = UDim2.new(1, 0, 0, from)
Animate.toThen(container, "base", { Size = UDim2.new(1, 0, 0, HEADER_H) }, settle(gen, false, function()
content.Visible = false; divider.Visible = false
end))
end
else
content.Position = UDim2.new(0, 0, 0, REST_Y)
divider.BackgroundTransparency = 0
if expanded then
content.Visible = true; divider.Visible = true
container.AutomaticSize = Enum.AutomaticSize.Y
container.Size = UDim2.new(1, 0, 0, HEADER_H)
else
content.Visible = false; divider.Visible = false
container.AutomaticSize = Enum.AutomaticSize.None
container.Size = UDim2.new(1, 0, 0, HEADER_H)
end
caret.Rotation = expanded and 90 or 0
caret.ImageColor3 = caretColor()
caretScale.Scale = 1
end
end

function api:Toggle() expanded = not expanded; applyHeight(true); return expanded end
function api:Expand() if not expanded then expanded = true; applyHeight(true) end end
function api:Collapse() if expanded then expanded = false; applyHeight(true) end end
function api:IsExpanded() return expanded end

local shownTitle = opts.Title or "Section"
function api:SetTitle(s)
if s == shownTitle then return end
Safe.mutate(function() title.Text = s; shownTitle = s end)
end
function api:SetIcon(name) if leadIcon then Safe.mutate(function() Icons.apply(leadIcon, name, theme.Colors[theme.Icon.accent]) end) end end

function api.MountRow(child)
order = order + 1
child.LayoutOrder = order
child.Parent = content
return order
end


Host.attach(api, {
R = REG, content = content, theme = theme, config = opts.Config, window = opts.Window,
registerSearchable = opts.RegisterSearchable, accentThemer = opts.AccentThemer,
registerControl = opts.RegisterControl,
nextOrder = function() order = order + 1; return order end,
})




local hover = Recipes.hover(header, { theme = theme, host = header, kind = "wash",
corner = theme.Radius.md, inset = { x = theme.Spacing.inputX, y = 0 } })
maid:Give(hover.disconnect)

if opts.AccentThemer then maid:Give(opts.AccentThemer.register(function()
container.BackgroundColor3 = theme.Colors.card
local st = container:FindFirstChildOfClass("UIStroke"); if st then st.Color = theme.Colors.border end
title.TextColor3 = theme.Colors.foreground
Icons.apply(caret, "chevron-right", caretColor())
caret.Rotation = expanded and 90 or 0
if leadIcon then Icons.apply(leadIcon, opts.Icon, theme.Colors[theme.Icon.accent]) end
divider.BackgroundColor3 = theme.Colors.border
hover.reskin()
end)) end

maid:Give(header.MouseButton1Click:Connect(function() api:Toggle() end))
maid:Give(container)

function api.Destroy() maid:DoCleanup() end

applyHeight(false)
return api
end

return Accordion

end


EmbeddedModules["components/tab"] = function()

local Tab = {}
local Create, DefaultTheme, Animate, Maid, Icons, Accordion, Host, REG, Safe, Recipes, Device

function Tab.Init(R)
Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate
Maid = R.Maid; Icons = R.Icons; Accordion = R.Accordion; Host = R.Host; REG = R; Safe = R.Safe
Recipes = R.Recipes; Device = R.Device
end

function Tab.new(opts)
opts = opts or {}
local theme = opts.Theme or DefaultTheme
local maid = Maid.new()
local order = 0
local selected = false



local function tintRole() return selected and theme.Icon.structuralActive or theme.Icon.structural end
local function tint() return theme.Colors[tintRole()] end


local button = Create("TextButton", {
Name = "TabButton",
Text = "",
AutoButtonColor = false,
BackgroundColor3 = theme.Colors.surface,
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 34),
LayoutOrder = opts.LayoutOrder or 0,
Parent = opts.SidebarParent,
Create.corner(theme.Radius.md),
Create.padding({ left = 10, right = 10 }),
})
local icon = Create("ImageLabel", {
Name = "Icon",
BackgroundTransparency = 1,
Size = UDim2.new(0, 16, 0, 16),
Position = UDim2.new(0, 4, 0.5, -8),
Parent = button,
})
if opts.Icon then Icons.apply(icon, opts.Icon, tint()) else icon.Visible = false end
local label = Create("TextLabel", {
Name = "Label",
BackgroundTransparency = 1,
Text = opts.Name or "Tab",
TextColor3 = tint(),
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, opts.Icon and -30 or -6, 1, 0),
Position = UDim2.new(0, opts.Icon and 30 or 6, 0, 0),
Parent = button,
})
Create.text(label, theme, "label")




local hoverOpts = { theme = theme, kind = "text", label = label, icon = icon,
rest = tintRole(), hover = theme.Icon.structuralActive }
local hover = Recipes.hover(button, hoverOpts)
maid:Give(hover.disconnect)




local function paintState(animated)
hoverOpts.rest = tintRole()
local c = tint()
if animated then
Animate.to(button, "fast", { BackgroundTransparency = selected and 0 or 1 })
Animate.to(label, "hover", { TextColor3 = c })
if opts.Icon then Icons.tint(icon, c, "hover") end
else
button.BackgroundColor3 = theme.Colors.surface
label.TextColor3 = c
if opts.Icon then Icons.apply(icon, opts.Icon, c) end
hover.reskin()
end
end




local content = Create("Frame", {
Name = "TabContent",
BackgroundTransparency = 1,
Visible = false,
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
Parent = opts.ContentParent,
Create.listLayout({ Padding = theme.Spacing.gap }),
Create.padding({ all = theme.Spacing.pad }),
})



local contentLayout = content:FindFirstChildOfClass("UIListLayout")
local contentPad = theme.Spacing.pad


local function panelH()
local sf = content.Parent
local s = sf and sf.AbsoluteSize
return (s and s.Y and s.Y > 0 and s.Y) or 360
end
local function syncCanvas()



Safe.mutate(function()
local sf = content.Parent
if selected and sf then
local acs = contentLayout.AbsoluteContentSize
sf.CanvasSize = UDim2.new(0, 0, 0, ((acs and acs.Y) or 0) + contentPad * 2)
end
end)
end
maid:Give(contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncCanvas))

local api = { Button = button, Content = content, Maid = maid }

function api:IsSelected() return selected end







local function slides() return opts.Transition ~= "none" and Animate.isEnabled() end

function api:Select(dir)
selected = true
if not slides() then
content.Position = UDim2.new(0, 0, 0, 0)
content.Visible = true
if content.Parent then content.Parent.CanvasPosition = Vector2.new(0, 0) end
syncCanvas()
paintState(true)
return
end
local sign = (dir == -1) and -1 or 1
content.Position = UDim2.new(0, 0, 0, sign * panelH())
content.Visible = true
if content.Parent then content.Parent.CanvasPosition = Vector2.new(0, 0) end
syncCanvas()
Animate.to(content, "slow", { Position = UDim2.new(0, 0, 0, 0) }, Animate.EASING.smooth)
paintState(true)
end

function api:Deselect(dir)
if not selected then content.Visible = false; return end
selected = false
if not slides() then
content.Visible = false
paintState(true)
return
end
local sign = (dir == -1) and -1 or 1
Animate.toThen(content, "slow", { Position = UDim2.new(0, 0, 0, -sign * panelH()) }, function()
if not selected then content.Visible = false; content.Position = UDim2.new(0, 0, 0, 0) end
end, Animate.EASING.smooth)
paintState(true)
end

function api.MountRow(child)
order = order + 1
child.LayoutOrder = order
child.Parent = content
return order
end



Host.attach(api, {
R = REG, content = content, theme = theme, config = opts.Config, window = opts.Window,
registerSearchable = opts.RegisterSearchable, accentThemer = opts.AccentThemer,
registerControl = opts.RegisterControl,
nextOrder = function() order = order + 1; return order end,
})

if opts.AccentThemer then maid:Give(opts.AccentThemer.register(function() paintState(false) end)) end

function api:AddAccordion(accOpts)
accOpts = accOpts or {}
order = order + 1
accOpts.Parent = content
accOpts.LayoutOrder = order
accOpts.Theme = theme
accOpts.Config = opts.Config
accOpts.Window = opts.Window
accOpts.RegisterSearchable = opts.RegisterSearchable
accOpts.AccentThemer = opts.AccentThemer
accOpts.RegisterControl = opts.RegisterControl
return Accordion.new(accOpts)
end

function api:SetIcon(name) opts.Icon = name; Safe.mutate(function() Icons.apply(icon, name, tint()); icon.Visible = true end) end
local shownTitle = opts.Name or "Tab"
function api:SetTitle(s)
if s == shownTitle then return end
Safe.mutate(function() label.Text = s; shownTitle = s end)
end





if Device.SupportsHover() then
local function wash(on)
if not selected then Animate.to(button, "hover", { BackgroundTransparency = on and theme.Opacity.tabHover or 1 }) end
end
maid:Give(button.MouseEnter:Connect(function() wash(true) end))
maid:Give(button.MouseLeave:Connect(function() wash(false) end))
maid:Give(button.MouseButton1Up:Connect(function() if Device.GetInput() == "Touch" then wash(false) end end))
end
maid:Give(button.MouseButton1Click:Connect(function() if opts.OnActivate then opts.OnActivate(api) end end))
maid:Give(button)
maid:Give(content)
function api.Destroy() maid:DoCleanup() end

return api
end

return Tab

end


EmbeddedModules["core/asset"] = function()




local RunService = game:GetService("RunService")

local Asset = {}
local cache = {}





local DECODE_BUDGET = 3

function Asset.Init(_) end

local function customAssetFn()





local fn = getcustomasset or getsynasset or get_custom_asset
or rawget(_G, "getcustomasset") or rawget(_G, "getsynasset") or rawget(_G, "get_custom_asset")
if type(fn) == "function" then return fn end
return nil
end

local function getCustomAsset(path)
local fn = customAssetFn()
if not fn then return nil end
local ok, res = pcall(fn, path)
if ok and type(res) == "string" then return res end
return nil
end

local function djb2(s)
local h = 5381
for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 2147483647 end
return h
end

local function fetchUrl(url)
if cache[url] ~= nil then return cache[url] or nil end
local hasFS = type(writefile) == "function" and type(isfile) == "function"
if not hasFS then cache[url] = false; return nil end
local ext = url:match("%.(%w%w%w%w?)$") or "png"
local path = "EzUI/assets/" .. djb2(url) .. "." .. ext
if type(makefolder) == "function" then pcall(makefolder, "EzUI"); pcall(makefolder, "EzUI/assets") end
if not isfile(path) then
local body
if type(game.HttpGet) == "function" then
local ok, data = pcall(function() return game:HttpGet(url) end)
if ok then body = data end
end
if not body and type(request) == "function" then
local ok, resp = pcall(request, { Url = url, Method = "GET" })
if ok and type(resp) == "table" then body = resp.Body end
end
if not body then cache[url] = false; return nil end
local okw = pcall(writefile, path, body)
if not okw then cache[url] = false; return nil end
end
local content = getCustomAsset(path)
cache[url] = content or false
return content
end

function Asset.image(value)
if type(value) ~= "string" or value == "" then return nil end
if value:match("^rbxassetid://") or value:match("^rbxasset://") or value:match("^rbxthumb://") then return value end
if value:match("^https?://") then return fetchUrl(value) end
if value:match("^%d+$") then return "rbxassetid://" .. value end
return nil
end




function Asset.resolvable(value)
if type(value) ~= "string" or value == "" then return false end
if value:match("^rbxassetid://") or value:match("^rbxasset://")
or value:match("^rbxthumb://") or value:match("^%d+$") then return true end
if value:match("^https?://") then
if cache[value] then return true end
if cache[value] == false then return false end
return type(writefile) == "function" and type(isfile) == "function" and customAssetFn() ~= nil
end
return false
end










function Asset.imageAsync(value, cb, onFail)
local function fail() if onFail then onFail() end end
if type(value) ~= "string" or value == "" then fail(); return end
if value:match("^rbxassetid://") or value:match("^rbxasset://") or value:match("^rbxthumb://") then
cb(value); return
end
if value:match("^%d+$") then cb("rbxassetid://" .. value); return end
if value:match("^https?://") then
if cache[value] ~= nil then
if cache[value] then cb(cache[value]) else fail() end
return
end
local spawn = (type(task) == "table" and task.spawn) or function(fn) fn() end
spawn(function() local id = fetchUrl(value); if id then cb(id) else fail() end end)
return
end
fail()
end



















function Asset.awaitLoaded(imageLabel, cb, budget)
local limit = tonumber(budget) or DECODE_BUDGET
local done, conn, hb, elapsed = false, nil, nil, 0
local handle = {}
function handle.Disconnect()
done = true
if conn then conn:Disconnect(); conn = nil end
if hb then hb:Disconnect(); hb = nil end
end
local function finish(loaded)
if done then return end
handle.Disconnect()
cb(loaded and true or false)
end


if imageLabel == nil then finish(false); return handle end
if imageLabel.IsLoaded ~= false then finish(true); return handle end

pcall(function()
conn = imageLabel:GetPropertyChangedSignal("IsLoaded"):Connect(function()
if imageLabel.IsLoaded ~= false then finish(true) end
end)
end)
hb = RunService.Heartbeat:Connect(function(dt)
elapsed = elapsed + (tonumber(dt) or 0)
if imageLabel.Parent == nil then handle.Disconnect(); return end
if imageLabel.IsLoaded ~= false then finish(true)
elseif elapsed >= limit then finish(false) end
end)
return handle
end

return Asset

end


EmbeddedModules["core/maid"] = function()
local Maid = {}
Maid.__index = Maid

function Maid.new()
return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
self._tasks[#self._tasks + 1] = task
return task
end

local function cleanupTask(t)



local kind = (typeof and typeof(t)) or type(t)
if kind == "function" then
t()
elseif kind == "Instance" then
t:Destroy()
elseif kind == "RBXScriptConnection" then
t:Disconnect()
elseif kind == "table" then
if type(t.Disconnect) == "function" then t:Disconnect()
elseif type(t.Destroy) == "function" then t:Destroy()
end
end
end

function Maid:DoCleanup()
local tasks = self._tasks
self._tasks = {}
for i = #tasks, 1, -1 do
local ok, err = pcall(cleanupTask, tasks[i])
if not ok and warn then warn("Maid task error: " .. tostring(err)) end
end
end

Maid.Destroy = Maid.DoCleanup

return Maid

end


EmbeddedModules["core/animate"] = function()

local TweenService = game:GetService("TweenService")

local Animate = {}
local Theme
local motionTbl


local enabled, explicit = true, false

local DEFAULT_DUR = 0.18


local FALLBACK = { spin = 0.8, exit = 0.14, exitScale = 0.96, popSlide = 6 }

function Animate.Init(R)
Theme = R.Theme
Animate.Motion = motionTbl or Theme.Motion
end

Animate.EASING = {
pop = Enum.EasingStyle.Back, smooth = Enum.EasingStyle.Quint,
enter = Enum.EasingStyle.Quint, exit = Enum.EasingStyle.Quart,
snap = Enum.EasingStyle.Quad or Enum.EasingStyle.Quart,
}
Animate.DIR = { In = Enum.EasingDirection.In, Out = Enum.EasingDirection.Out, InOut = Enum.EasingDirection.InOut }



local function token(name)
local v = motionTbl and motionTbl[name]
if type(v) ~= "number" and Theme and Theme.Motion then v = Theme.Motion[name] end
if type(v) == "number" then return v end
return FALLBACK[name]
end

local function resolve(duration)
if type(duration) == "number" then return duration end
if type(duration) == "string" then return token(duration) or DEFAULT_DUR end
return DEFAULT_DUR
end



local function resolveDelay(delay)
if type(delay) == "number" then return delay end
if type(delay) == "string" then return token(delay) or 0 end
return 0
end



function Animate.useMotion(tbl)
motionTbl = type(tbl) == "table" and tbl or nil
Animate.Motion = motionTbl or (Theme and Theme.Motion)
end

function Animate.info(duration, style, dir, delay)
return TweenInfo.new(duration, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out, 0, false, delay or 0)
end


function Animate.setEnabled(b) enabled = b and true or false; explicit = true end

function Animate.applyDefault(b)
if not explicit then enabled = b and true or false end
return enabled
end
function Animate.isEnabled() return enabled end
function Animate.isExplicit() return explicit end



local function instantTween()
return { Completed = { Connect = function(_, fn) if fn then fn() end; return { Disconnect = function() end } end } }
end

local function applyNow(instance, goalProps)
for k, v in pairs(goalProps) do instance[k] = v end
end

function Animate.to(instance, duration, goalProps, style, dir, delay)
if not enabled then
applyNow(instance, goalProps)
return instantTween()
end
local tween = TweenService:Create(instance, Animate.info(resolve(duration), style, dir, resolveDelay(delay)), goalProps)
tween:Play()
return tween
end



function Animate.toThen(instance, duration, goalProps, onComplete, style, dir, delay)
if not enabled then
applyNow(instance, goalProps)
if onComplete then onComplete() end
return instantTween()
end
local tween = TweenService:Create(instance, Animate.info(resolve(duration), style, dir, resolveDelay(delay)), goalProps)
if onComplete then tween.Completed:Connect(onComplete) end
tween:Play()
return tween
end


function Animate.springTo(instance, duration, goalProps)
return Animate.to(instance, duration, goalProps, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end


function Animate.rotateTo(instance, duration, deg, style, dir)
return Animate.to(instance, duration, { Rotation = deg },
style or Enum.EasingStyle.Back, dir or Enum.EasingDirection.Out)
end


function Animate.exitTo(instance, duration, goalProps, onDone)
return Animate.toThen(instance, duration, goalProps, onDone, Animate.EASING.exit, Animate.DIR.In)
end



function Animate.chain(steps, onDone)
local i = 0
local function step()
i = i + 1
local s = steps and steps[i]
if not s then if onDone then onDone() end; return end
Animate.toThen(s[1], s[2], s[3], step, s[4], s[5], s[6])
end
step()
end




function Animate.loop(instance, duration, goalProps, style, reverses, repeatCount)
reverses = reverses == true
if not enabled then


if not reverses then applyNow(instance, goalProps) end
return { Cancel = function() end }
end
local info = TweenInfo.new(resolve(duration), style or Enum.EasingStyle.Linear, Enum.EasingDirection.InOut,
repeatCount or -1, reverses, 0)
local tween = TweenService:Create(instance, info, goalProps)
tween:Play()
return { Cancel = function() tween:Cancel() end }
end



function Animate.spin(img, duration)
img.Rotation = 0
if not enabled then return { Cancel = function() img.Rotation = 0 end } end
local handle = Animate.loop(img, duration or token("spin"), { Rotation = 360 }, Enum.EasingStyle.Linear, false, -1)
return { Cancel = function() handle.Cancel(); img.Rotation = 0 end }
end


function Animate.pulse(instance, duration, goalProps, style, cycles)
return Animate.loop(instance, duration, goalProps, style, true, cycles or -1)
end

local function uiScaleOf(inst)
local us = inst:FindFirstChildOfClass("UIScale")
if not us then us = Instance.new("UIScale"); us.Parent = inst end
return us
end


function Animate.pop(inst, duration)
local us = uiScaleOf(inst)
us.Scale = 0.9
return Animate.to(us, duration or "base", { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end





function Animate.popIn(frame, edge)
local us = uiScaleOf(frame)
if not enabled then us.Scale = 1; return instantTween() end
local target = frame.Position
us.Scale = token("exitScale")
if target then
local dy = (edge == "up") and token("popSlide") or -token("popSlide")
frame.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + dy)
Animate.to(frame, "fast", { Position = target }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end
return Animate.springTo(us, "base", { Scale = 1 })
end


function Animate.popOut(frame, onDone)
local us = uiScaleOf(frame)
return Animate.toThen(us, token("exit"), { Scale = token("exitScale") }, onDone, Animate.EASING.exit, Animate.DIR.In)
end

return Animate

end


EmbeddedModules["core/overlay"] = function()

local Overlay = {}
local Create, Mount
local root = nil
local layer = nil
local owner = nil
local catcher = nil
local popovers = {}





local DEFAULT_SCALE = 1
local uiScale = DEFAULT_SCALE
local dialogDepth = 0



Overlay.Z = { catcher = 1000, popover = 1001, modal = 1500, fab = 1700, toast = 1800, tooltip = 2000 }



local DEFAULT_GAP = 4

local FALLBACK_VIEWPORT = { X = 1920, Y = 1080 }

function Overlay.Init(R) Create = R.Create; Mount = R.Mount end



local function anon(readable)
if Mount and Mount.anonName then return Mount.anonName(readable) end
return readable
end



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



function Overlay.peek()
if root and root.Parent ~= nil then return root end
return nil
end












local function ownLayer(parentGui, ctx)
local ok, host, order = pcall(function() return parentGui.Parent, parentGui.DisplayOrder end)
if not ok or host == nil then return nil end
order = tonumber(order) or 0
local gui = Create("ScreenGui", {
Name = anon("OverlayLayer"),
ResetOnSpawn = false,
ZIndexBehavior = Enum.ZIndexBehavior and Enum.ZIndexBehavior.Sibling or nil,
DisplayOrder = order + 1,
})

pcall(function() gui.IgnoreGuiInset = parentGui.IgnoreGuiInset end)

pcall(function() gui:SetAttribute("__ezui", true) end)
gui.Parent = host
if ctx and ctx.protect and not ctx.studio then pcall(ctx.protect, gui) end




pcall(function()
parentGui.Destroying:Connect(function() if layer == gui then Overlay.reset() end end)
end)
return gui
end

function Overlay.get(parentGui, ctx)


if root and root.Parent ~= nil then return root end
layer = ownLayer(parentGui, ctx)
owner = layer and parentGui or nil
root = Create("Frame", {
Name = anon("OverlayRoot"),
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 1, 0),
ZIndex = Overlay.Z.catcher,
ClipsDescendants = false,
Parent = layer or parentGui,
})
return root
end

function Overlay.mount(element)
assert(root, "Overlay.get(parentGui) must be called before mount")
element.Parent = root
return element
end



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


function Overlay.viewport()
if root then
local s = root.AbsoluteSize
if s and (s.X or 0) > 0 and (s.Y or 0) > 0 then return s end
end
return { X = FALLBACK_VIEWPORT.X, Y = FALLBACK_VIEWPORT.Y }
end





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



function Overlay.setScale(n)
if type(n) ~= "number" or n ~= n or n <= 0 then
error("Overlay.setScale(n): positive number expected, got " .. tostring(n), 2)
end
uiScale = n
return n
end
function Overlay.scale() return uiScale end



function Overlay.pushDialog() dialogDepth = dialogDepth + 1; return dialogDepth end
function Overlay.popDialog() dialogDepth = math.max(0, dialogDepth - 1); return dialogDepth end
function Overlay.dialogDepth() return dialogDepth end






function Overlay.release(windowGui)
if layer and owner ~= windowGui then return end
Overlay.reset()
end

function Overlay.reset()
if layer then pcall(function() layer:Destroy() end) end
layer = nil; owner = nil; root = nil; catcher = nil; popovers = {}
uiScale = DEFAULT_SCALE; dialogDepth = 0
end

return Overlay

end


EmbeddedModules["core/device"] = function()




local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Device = {}
local Signal
local DEFAULTS = { TabletMaxAspect = 1.55, TabletMinDiagonal = math.huge }
local cfg = { TabletMaxAspect = DEFAULTS.TabletMaxAspect, TabletMinDiagonal = DEFAULTS.TabletMinDiagonal }

local function viewport()
local cam = workspace and workspace.CurrentCamera
local vp = cam and cam.ViewportSize
if vp and vp.X and vp.X > 0 then return vp end
return { X = 1280, Y = 720 }
end

function Device.GetType()
if GuiService and GuiService.IsTenFootInterface and GuiService:IsTenFootInterface() then
return "Console"
end
local touch = UserInputService.TouchEnabled
local mouse = UserInputService.MouseEnabled
if touch and not mouse then
local vp = viewport()
local a, b = math.max(vp.X, vp.Y), math.min(vp.X, vp.Y)
local aspect = (b > 0) and (a / b) or 1
local diag = math.sqrt(vp.X * vp.X + vp.Y * vp.Y)
if aspect <= cfg.TabletMaxAspect or diag >= cfg.TabletMinDiagonal then return "Tablet" end
return "Mobile"
end
return "Desktop"
end

function Device.IsMobile() return Device.GetType() == "Mobile" end
function Device.IsTablet() return Device.GetType() == "Tablet" end
function Device.IsDesktop() return Device.GetType() == "Desktop" end
function Device.IsConsole() return Device.GetType() == "Console" end
function Device.IsTouch() return UserInputService.TouchEnabled == true end




local function readService(name, prop)
local ok, v = pcall(function() return game:GetService(name)[prop] end)
if ok then return v end
return nil
end



function Device.SupportsHover() return readService("UserInputService", "MouseEnabled") == true end

function Device.PrefersReducedMotion() return readService("GuiService", "ReducedMotionEnabled") == true end

function Device.GetInput()
local t = UserInputService.GetLastInputType and UserInputService:GetLastInputType()
local name = (t and t.Name) or ""
if name == "Touch" then return "Touch" end
if name:find("Gamepad") then return "Gamepad" end
return "KeyboardMouse"
end

local lastType, lastInput
function Device._recompute()
local t, i = Device.GetType(), Device.GetInput()
if t ~= lastType or i ~= lastInput then
lastType, lastInput = t, i
if Device.Changed then Device.Changed:Fire({ Type = t, Input = i, Viewport = viewport() }) end
end
end

function Device.Configure(opts)
if type(opts) == "table" then
if tonumber(opts.TabletMaxAspect) then cfg.TabletMaxAspect = tonumber(opts.TabletMaxAspect) end
if tonumber(opts.TabletMinDiagonal) then cfg.TabletMinDiagonal = tonumber(opts.TabletMinDiagonal) end
end
Device._recompute()
end

local connected = false
function Device.Init(R)
Signal = R.Signal
cfg.TabletMaxAspect = DEFAULTS.TabletMaxAspect
cfg.TabletMinDiagonal = DEFAULTS.TabletMinDiagonal
if not Device.Changed then Device.Changed = Signal.new() end
lastType, lastInput = Device.GetType(), Device.GetInput()
if connected then return end
connected = true
local function hook(sig) if sig and sig.Connect then sig:Connect(function() Device._recompute() end) end end
hook(UserInputService.LastInputTypeChanged)
if UserInputService.GetPropertyChangedSignal then
hook(UserInputService:GetPropertyChangedSignal("TouchEnabled"))
hook(UserInputService:GetPropertyChangedSignal("MouseEnabled"))
hook(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"))
end
local cam = workspace and workspace.CurrentCamera
if cam and cam.GetPropertyChangedSignal then hook(cam:GetPropertyChangedSignal("ViewportSize")) end
end

return Device

end


EmbeddedModules["components/selectrows"] = function()












local SelectRows = {}
local Create, Icons, Recipes, Safe

function SelectRows.Init(R) Create = R.Create; Icons = R.Icons; Recipes = R.Recipes; Safe = R.Safe end

local ROW_H, DESC_H, DIV_H, GAP = 26, 38, 1, 2
local BUFFER = 120


local NOKEY = {}
local function keyOf(v) if v == nil or v ~= v then return NOKEY end return v end
SelectRows.keyOf = keyOf
SelectRows.NOKEY = NOKEY


local function searchText(e)
return (tostring(e.value) .. " " .. tostring(e.label or "") .. " " .. tostring(e.desc or "")):lower()
end




local function bindHover(o, theme)
return Recipes.hover(o, { theme = theme, kind = "fill", hoverAlpha = theme.Opacity.optionHover })
end



function SelectRows.tick(slot, sel, theme, force)
if sel == slot.sel and not force then return end



local rest = sel and 0 or 1
if slot.hover and slot.hover.setRest then slot.hover.setRest(rest) else slot.btn.BackgroundTransparency = rest end
slot.sel = sel
if sel then Icons.apply(slot.check, "check", theme.Colors.foreground) end
slot.check.Visible = sel
end



local function attrOf(v)
local t = type(v)
if t == "string" or t == "number" or t == "boolean" then return v end
return nil
end

local List = {}
List.__index = List


function SelectRows.new(list, ctx)
local self = setmetatable({ list = list, ctx = ctx, theme = ctx.theme, items = {}, shown = {},
slots = {}, divs = {}, query = "", canvasH = -1, rowsShown = 0, conns = {} }, List)

local function onView() Safe.mutate(function() if not self.dead then self:render() end end) end
self.conns[1] = list:GetPropertyChangedSignal("CanvasPosition"):Connect(onView)
return self
end

function List:newSlot()
local theme, list = self.theme, self.list
local o = Create("TextButton", { Name = "Opt", AutoButtonColor = false, Text = "", Visible = true,
BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = 1, ZIndex = 1002,
Size = UDim2.new(1, 0, 0, ROW_H), Parent = list, Create.corner(theme.Radius.sm),
Create.padding({ left = 6, right = 6 }) })
local check = Create("ImageLabel", { Name = "Check", BackgroundTransparency = 1, ZIndex = 1003, Visible = false,
Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 0, 0.5, -7), Parent = o })
local label = Create("TextLabel", { Name = "OptLabel", BackgroundTransparency = 1, Text = "", ZIndex = 1003,
TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 20, 0, 0), Parent = o })
Create.text(label, theme, "body")
local slot = { btn = o, check = check, label = label, sel = false, on = true, h = ROW_H, textX = 20, text = "" }
slot.hover = bindHover(o, theme)



o.MouseButton1Down:Connect(function() slot.pressed = slot.item end)
o.MouseButton1Click:Connect(function()
local it, pressed = slot.item, slot.pressed
slot.pressed = nil
if self.dead or not it or pressed == false then return end
self.ctx.onPick(it.e.value)
end)
self.slots[#self.slots + 1] = slot
return slot
end


function List:bind(slot, it, isPicked)
local theme, e, o = self.theme, it.e, slot.btn
if slot.pressed and slot.pressed ~= it then slot.pressed = false end
slot.item = it; it.slot = slot
if slot.y ~= it.y then o.Position = UDim2.new(0, 0, 0, it.y); slot.y = it.y end
if slot.h ~= it.h then o.Size = UDim2.new(1, 0, 0, it.h); slot.h = it.h end


if slot.order ~= it.index then o.LayoutOrder = it.index; slot.order = it.index end
local textX = e.icon and 40 or 20
if e.icon then
if not slot.lead then
slot.lead = Create("ImageLabel", { Name = "Lead", BackgroundTransparency = 1, ZIndex = 1003,
Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 20, 0.5, -7), Parent = o })
slot.leadOn = true
elseif not slot.leadOn then
slot.lead.Visible = true; slot.leadOn = true
end
if slot.icon ~= e.icon then Icons.apply(slot.lead, e.icon, theme.Colors.foreground); slot.icon = e.icon end
elseif slot.lead and slot.leadOn then
slot.lead.Visible = false; slot.leadOn = false
end
local desc = e.desc
local hasDesc = desc ~= nil

if slot.textX ~= textX or (slot.hasDesc or false) ~= hasDesc then
slot.label.Size = UDim2.new(1, -textX - 4, hasDesc and 0 or 1, hasDesc and 16 or 0)
slot.label.Position = UDim2.new(0, textX, 0, hasDesc and 4 or 0)
if slot.desc then
slot.desc.Size = UDim2.new(1, -textX - 4, 0, 14); slot.desc.Position = UDim2.new(0, textX, 0, 20)
end
slot.textX, slot.hasDesc = textX, hasDesc
end
local text = e.label or tostring(e.value)
if slot.text ~= text then slot.label.Text = text; slot.text = text end
if desc then
if not slot.desc then
slot.desc = Create("TextLabel", { Name = "Desc", BackgroundTransparency = 1, Text = desc, ZIndex = 1003,
TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, -textX - 4, 0, 14), Position = UDim2.new(0, textX, 0, 20), Parent = o })
Create.text(slot.desc, theme, "muted")
slot.descText, slot.descOn = desc, true
else
if not slot.descOn then slot.desc.Visible = true; slot.descOn = true end
if slot.descText ~= desc then slot.desc.Text = desc; slot.descText = desc end
end
elseif slot.desc and slot.descOn then
slot.desc.Visible = false; slot.descOn = false
end
SelectRows.tick(slot, isPicked(e.value), theme)
if not slot.on then o.Visible = true; slot.on = true end

local attr = attrOf(e.value)
if not slot.bound or slot.attr ~= attr then o:SetAttribute("OptValue", attr); slot.attr = attr end
slot.bound = true
end

function List:bindDivider(d, it)
d.item = it; it.slot = d
local f = d.frame
if d.y ~= it.y then f.Position = UDim2.new(0, 0, 0, it.y); d.y = it.y end
if d.order ~= it.index then f.LayoutOrder = it.index; d.order = it.index end
if not d.on then f.Visible = true; d.on = true end
end

function List:newDivider()
local f = Create("Frame", { Name = "Divider", BackgroundColor3 = self.theme.Colors.border, BorderSizePixel = 0,
Size = UDim2.new(1, -8, 0, DIV_H), ZIndex = 1002, Parent = self.list })
local d = { frame = f, on = true }
self.divs[#self.divs + 1] = d
return d
end



function List:setOptions(normed)
local items = {}
for i, e in ipairs(normed) do
items[i] = { e = e, index = i, divider = e.divider, find = (not e.divider) and searchText(e) or nil }
end
self.items = items
for _, s in ipairs(self.slots) do s.item = nil end
for _, d in ipairs(self.divs) do d.item = nil end
self:layout()
self:render()
end


function List:filter(query)
self.query = query or ""
self:layout()
self:render()
end

function List:layout()
local q = self.query
local shown, y, rows = {}, 0, 0
for _, it in ipairs(self.items) do
if it.divider or q == "" or it.find:find(q, 1, true) then
it.y = y
it.h = it.divider and DIV_H or (it.e.desc and DESC_H or ROW_H)
y = y + it.h + GAP
shown[#shown + 1] = it
if not it.divider then rows = rows + 1 end
else
it.y = nil
end
end
self.shown, self.rowsShown = shown, rows
local h = (#shown > 0) and (y - GAP) or 0
if h ~= self.canvasH then self.list.CanvasSize = UDim2.new(0, 0, 0, h); self.canvasH = h end
end




function List:viewHeight()
local vh = self.ctx.viewH
return (type(vh) == "number" and vh > 0) and vh or 240
end


function List:render()
local list = self.list
local vh = self:viewHeight()
local cp = list.CanvasPosition
local top = (cp and cp.Y) or 0



local maxTop = math.max(0, self.canvasH - vh)
if top > maxTop then top = maxTop; list.CanvasPosition = Vector2.new(cp and cp.X or 0, top) end
local lo, hi = top - BUFFER, top + vh + BUFFER
local band = {}
for _, it in ipairs(self.shown) do
if it.y + it.h >= lo and it.y <= hi then band[it] = true end
end

local free, freeDivs = {}, {}
for _, s in ipairs(self.slots) do
if s.item and not band[s.item] then s.item.slot = nil; s.item = nil end
if not s.item then free[#free + 1] = s end
end
for _, d in ipairs(self.divs) do
if d.item and not band[d.item] then d.item.slot = nil; d.item = nil end
if not d.item then freeDivs[#freeDivs + 1] = d end
end

local function byY(a, b) return (a.y or math.huge) < (b.y or math.huge) end
table.sort(free, byY); table.sort(freeDivs, byY)
local isPicked = self.ctx.picked()
local nf, nd = 1, 1
for _, it in ipairs(self.shown) do
if band[it] and it.slot == nil then
if it.divider then
local d = freeDivs[nd] or self:newDivider(); nd = nd + 1
self:bindDivider(d, it)
else
local s = free[nf] or self:newSlot(); nf = nf + 1
self:bind(s, it, isPicked)
end
end
end
for i = nf, #free do
local s = free[i]
if s.on then
s.btn.Visible = false; s.on = false
if s.hover and s.hover.settle then s.hover.settle() end
end
end
for i = nd, #freeDivs do local d = freeDivs[i]; if d.on then d.frame.Visible = false; d.on = false end end
end


function List:syncSelection()
local isPicked = self.ctx.picked()
for _, s in ipairs(self.slots) do
if s.item then SelectRows.tick(s, isPicked(s.item.e.value), self.theme) end
end
end


function List:repaint()
local theme, isPicked = self.theme, self.ctx.picked()
for _, s in ipairs(self.slots) do
s.btn.BackgroundColor3 = theme.Colors.surface
if s.item then SelectRows.tick(s, isPicked(s.item.e.value), theme, true) end
if s.lead and s.icon then Icons.apply(s.lead, s.icon, theme.Colors.foreground) end
s.label.TextColor3 = theme.Colors.foreground
if s.desc then s.desc.TextColor3 = theme.Colors.mutedForeground end
end
for _, d in ipairs(self.divs) do d.frame.BackgroundColor3 = theme.Colors.border end
end

function List:destroy()
self.dead = true
for _, c in ipairs(self.conns) do c:Disconnect() end
for _, s in ipairs(self.slots) do if s.hover then s.hover.disconnect() end end
self.conns, self.slots, self.divs = {}, {}, {}
end

return SelectRows

end


local function loadModule(url)

if EmbeddedModules[url] then
return EmbeddedModules[url]()
end


return require(url)
end



local EzUI = {}




local R = {}
R.Theme = loadModule("core/theme")
R.Create = loadModule("core/create")
R.Safe = loadModule("core/safe")
R.Signal = loadModule("core/signal")
R.Maid = loadModule("core/maid")
R.Icons = loadModule("core/icons")
R.Config = loadModule("core/config")
R.Flag = loadModule("core/flag")
R.Animate = loadModule("core/animate")
R.Overlay = loadModule("core/overlay")
R.Mount = loadModule("core/mount")
R.Acrylic = loadModule("core/acrylic")
R.Asset = loadModule("core/asset")
R.Numfmt = loadModule("core/numfmt")
R.Themer = loadModule("core/themer")
R.Device = loadModule("core/device")
R.Drag = loadModule("core/drag")
R.Effects = loadModule("core/effects")
R.Recipes = loadModule("core/recipes")
R.Separator = loadModule("components/separator")
R.Label = loadModule("components/label")
R.Button = loadModule("components/button")
R.Card = loadModule("components/card")
R.Toggle = loadModule("components/toggle")
R.TextBox = loadModule("components/textbox")
R.NumberBox = loadModule("components/numberbox")
R.SelectRows = loadModule("components/selectrows")
R.SelectBox = loadModule("components/selectbox")
R.Image = loadModule("components/image")
R.ProgressBar = loadModule("components/progressbar")
R.Slider = loadModule("components/slider")
R.Keybind = loadModule("components/keybind")
R.Tooltip = loadModule("components/tooltip")
R.Dialog = loadModule("components/dialog")
R.Notification = loadModule("components/notification")
R.Table = loadModule("components/table")
R.ColorPicker = loadModule("components/colorpicker")
R.Host = loadModule("components/host")
R.Resizable = loadModule("components/resizable")
R.Accordion = loadModule("components/accordion")
R.Tab = loadModule("components/tab")
R.Window = loadModule("components/window")

for _, m in pairs(R) do
if type(m) == "table" and type(m.Init) == "function" then m.Init(R) end
end

EzUI.Theme = R.Theme
EzUI.Icons = R.Icons
EzUI.Device = R.Device
EzUI._internal = R

function EzUI:NewConfig(opts) return R.Config.new(opts) end

function EzUI:CreateWindow(config)
config = config or {}
local ctx = R.Mount.resolve(config)
config.Parent = ctx.parent
config._mountCtx = ctx
return R.Window.new(config)
end

EzUI.Version = "2.0.0-alpha.1"
EzUI.Author = "alfin-efendy"

return EzUI

end


EmbeddedModules["showcase/look"] = function()


return function(window)
local tab = window:AddTab({ Name = "Look", Icon = "palette" })

tab:AddSection("Look at the shell, not this text")
tab:AddParagraph(
"The glass behind this panel is zinc, not black — the dark acrylic used to crush to pure " ..
"black and swallow every layer. Three tonal steps separate the shell now: window glass, " ..
"content panel, row surface. A field drops back BELOW all three, to the glass tone, so it " ..
"reads as a well sunk into its row — there is one on the Motion tab. The title above is " ..
"BuilderSans Bold, this body is Regular and the heading above it is the small uppercase " ..
"overline — three real font weights where there used " ..
"to be one. The panel's top border is lit: a gradient stroke that fades toward the bottom, " ..
"plus a 1px white glint tucked inside the top radius. The whole window rests on a soft " ..
"9-slice drop shadow, which is what separates it from the game behind it.")

tab:AddSection("The sidebar")
tab:AddParagraph(
"Three things live in the strip on the left. The field at the top filters BOTH halves of it: " ..
"a tab survives if its own name matches, and it also survives if any control inside it " ..
"matches, while every control row that does NOT match is hidden — so searching thins the page " ..
"you are standing on as well as the tab list. The overline headers (THE SHELL, THE CONTENTS) " ..
"come from grouping the tabs, and one disappears once every tab under it has been filtered " ..
"away. The seam between the sidebar and this panel is draggable: rest the pointer on it and a " ..
"grip pill fades up out of the hairline, then pull — the panel reflows as you go. And the 3px " ..
"pill marking the active tab does not merely move: it stretches tall as it leaves, springs " ..
"across on a duration scaled to the distance, and settles back to its rest height on arrival.")




local searchBtn, filtered = nil, false
searchBtn = tab:AddButton({ Text = "Filter the sidebar for \"toggle\"", Icon = "search", Variant = "secondary",
Callback = function()
filtered = not filtered
window:SearchTabs(filtered and "toggle" or "")
searchBtn.SetText(filtered and "Clear the filter" or "Filter the sidebar for \"toggle\"")
end })

tab:AddSection("Repaint the shell live")


local modeBtn
local function modeText() return "Switch to " .. (window:GetMode() == "dark" and "light" or "dark") .. " mode" end
modeBtn = tab:AddButton({ Text = modeText(), Icon = "sun", Variant = "secondary", Callback = function()
window:SetMode(window:GetMode() == "dark" and "light" or "dark")
modeBtn.SetText(modeText())
end })


local ACCENTS = { "Adaptive", "Indigo", "Violet", "Emerald", "Sky", "Rose" }
local accentAt, accentBtn = 1, nil
accentBtn = tab:AddButton({ Text = "Accent: Adaptive (tap to cycle)", Icon = "sparkles", Variant = "secondary",
Callback = function()
accentAt = accentAt % #ACCENTS + 1
local name = ACCENTS[accentAt]
window:SetAccent(name)
accentBtn.SetText("Accent: " .. name .. " (tap to cycle)")
end })




tab:AddParagraph(
"Accent is the primary token. The one spot you can watch from here is the sidebar " ..
"indicator on the left: the 3px pill and the soft halo blooming around it both repaint on " ..
"every tap, and so does the icon in the title-bar tag. The rest is a tab away — on Motion, " ..
"the pill and glow behind an ON toggle, the slider fill and the halo under its handle, and " ..
"the progress fill. A default-variant button — the solid ones, like Success on Overlays or " ..
"Step +25% on Motion — is the only place the accent lands as a whole fill. Focus rings are " ..
"NOT accent: a focused field takes the " ..
"separate neutral ring token, so it stays the same however you tint the rest.")

tab:AddSection("Scale")



tab:AddButton({ Text = "UI scale 0.9", Variant = "outline", Callback = function() window:SetUIScale(0.9) end })
tab:AddButton({ Text = "UI scale 1.0", Variant = "outline", Callback = function() window:SetUIScale(1.0) end })
tab:AddButton({ Text = "UI scale 1.2", Variant = "outline", Callback = function() window:SetUIScale(1.2) end })

tab:AddSection("Transparency")



tab:AddButton({ Text = "Transparency 0.02 — almost solid", Variant = "ghost",
Callback = function() window:SetTransparency(0.02) end })
tab:AddButton({ Text = "Transparency 0.12 — the default", Variant = "ghost",
Callback = function() window:SetTransparency(0.12) end })
tab:AddButton({ Text = "Transparency 0.35 — properly glassy", Variant = "ghost",
Callback = function() window:SetTransparency(0.35) end })

tab:AddSection("Two gestures worth trying")
tab:AddParagraph(
"Grab the title bar and drag. While you hold it the drop shadow spreads about 8px wider and " ..
"darkens, and the hairline goes opaque — the window lifts off the page — then settles back " ..
"when you release. The bottom-right resize grip does the same lift.")
tab:AddParagraph(
"Press the minimize button (the dash left of the x). The window folds to 96%, drifts toward " ..
"the floating toggle on the left edge and hands off to it as it lands: the window literally " ..
"turns into the button. RightControl runs the same fold and unfold. The x is a different " ..
"gesture — it asks to confirm first (that dialog is its own motion demo) and then dissolves " ..
"the window in place rather than drifting. As the dialog says, that is for good: Close " ..
"destroys the GUI, the floating toggle and RightControl with it. Use minimize while you " ..
"are still touring.")

tab:AddSection("The floating toggle")
tab:AddParagraph(
"The button that brings the window back has three shapes. Simple is a chevron tab that docks " ..
"flush to the screen edge with a few pixels peeking out; circle is a round accent button and " ..
"square a rounded surface tile — those two wear the same brand glyph as the title bar, tinted " ..
"to the foreground token so the logo follows dark and light instead of shipping twice. The " ..
"button auto-hides, so switching type changes nothing you can see while the window is up: " ..
"press RightControl (or minimize) FIRST, then drag it. Only the simple tab magnets — drop it " ..
"anywhere and it slides to whichever side of the screen its centre was nearest, docking with " ..
"a few pixels peeking out and its chevron spun round to face outward; rest a pointer on it " ..
"and it leans a little further out. Circle and square are free-floating and stay where you " ..
"drop them.")
local fabLabel = tab:AddLabel("Floating toggle: simple")


local function setFab(kind)
window:SetFloatingToggle({ Type = kind })
fabLabel.SetText("Floating toggle: " .. window:GetFloatingToggleType())
end
tab:AddButton({ Text = "Simple — chevron tab", Variant = "outline", Callback = function() setFab("simple") end })
tab:AddButton({ Text = "Circle — accent button", Variant = "outline", Callback = function() setFab("circle") end })
tab:AddButton({ Text = "Square — logo tile", Variant = "outline", Callback = function() setFab("square") end })
end

end


EmbeddedModules["showcase/motion"] = function()


return function(window)
local tab = window:AddTab({ Name = "Motion", Icon = "activity" })

tab:AddSection("Toggle")
tab:AddParagraph(
"Hold the switch down before you release it: the knob stretches toward where it is going " ..
"(20px wide to 24px) and snaps back on release. The travel itself is a spring with a 1px " ..
"overshoot, not a linear slide. When it lands ON, the grey track hairline dissolves so the " ..
"accent pill is clean, and an accent glow fades in behind the track. The OFF track is its " ..
"own tone now — it used to be the same colour as the row, which made it invisible.")
local demoToggle = tab:AddToggle({
Text = "Knob spring + accent glow",
Description = "Press and hold, then release.",
Default = true,
})

tab:AddSection("Slider")
tab:AddParagraph(
"The grab strip is 24px tall now, not 6 — you no longer have to hit the rail exactly. Hover " ..
"the handle and it grows to 1.15; start dragging and it goes to 1.3 with an accent halo " ..
"behind it, then springs back when you let go. The empty part of the rail has a hairline so " ..
"it reads as a groove rather than a gap.")
local demoSlider = tab:AddSlider({
Text = "Handle grow + halo",
Min = 0, Max = 100, Default = 40,
Description = "Hover the handle, then drag it.",
})


tab:AddButton({ Text = "Glide the slider to 10", Variant = "outline",
Callback = function() demoSlider.SetValue(10) end })
tab:AddButton({ Text = "Glide the slider to 90", Variant = "outline",
Callback = function() demoSlider.SetValue(90) end })

tab:AddSection("Progress")
tab:AddParagraph(
"The fill flows to its new value with a distance-aware duration — a nudge lands quickly, a " ..
"long sweep takes its time. Step this to 100% and watch the completion flash: the fill " ..
"lifts to 35% transparent the instant it arrives and fades back to solid.")
local bar = tab:AddProgressBar({ Default = 0 })
local stepBtn
stepBtn = tab:AddButton({ Text = "Step +25%", Icon = "chevron-right", Callback = function()
local v = bar.Get()

bar.Set(v >= 1 and 0 or math.min(1, v + 0.25))
stepBtn.SetText(bar.Get() >= 1 and "Reset to 0%" or "Step +25%")
end })

tab:AddSection("Text field")
tab:AddParagraph(
"Click into the box. Its hairline tweens from 1px border to 2px in the ring colour rather " ..
"than snapping, and clicking away tweens it back. The box itself sits at the window-glass " ..
"tone — a step BELOW the row it lives in — which is the inset the Look tab talks about. " ..
"Type something and the clear button fades in at the right edge. It also judges you on the " ..
"way out: put a SPACE in the name and click away. The box shakes on its own X offset and " ..
"lands back on the exact pixel it started from, the hairline turns destructive red, and an " ..
"error line fades in underneath while the row grows for it. Remove the space, click away, " ..
"and all three reverse.")
tab:AddTextBox({
Text = "Nickname",
Placeholder = "click here",
Description = "The ring is its own neutral token, so it does not follow the accent.",
Clearable = true,
MaxLength = 24,


Validate = function(text)
if text == "" or not text:find("%s") then return true end
return false, "No spaces — that is the rule this field rejects."
end,
})
tab:AddParagraph(
"The field below is the read-only half of the same kit. Press the copy glyph: it becomes a " ..
"green check for just over a second, then falls back on its own. Press it again mid-check " ..
"and the second press takes the window over — a generation counter owns the revert, so the " ..
"first one cannot cut the second one short.")
tab:AddTextBox({
Text = "Share code",
Description = "Copyable makes it non-editable; the glyph is the only control.",
Default = "EZUI-7F3A-22",
Copyable = true,
})

tab:AddSection("Number field")
tab:AddParagraph(
"The same focus ring, plus four movements of its own. HOLD − or + instead of tapping: the " ..
"first step lands at once, then after a third of a second it repeats, accelerating while " ..
"you hold. Push a box against its Min or Max and the refusal is visible — it bumps 2px " ..
"toward the side you pushed and returns to the exact position it left, while the glyph at " ..
"that end fades to the disabled alpha rather than changing colour. Type a shorthand into " ..
"the first one — 1k, 4.4m — and it expands on the way in; the $ is stripped for you, and " ..
"while the caret is in the field you see the raw number, not the compact one. Last, roll " ..
"the wheel over a box: the value only follows it while the pointer is really over the box, " ..
"which is why the panel behind still scrolls everywhere else.")
tab:AddNumberBox({
Text = "Budget",
Description = "Compact display with a $ prefix. Try typing 4.4m.",



Default = 1500000, Min = 0, Max = 10000000, Step = 250000,
Format = "compact", Prefix = "$",
})
tab:AddNumberBox({
Text = "Retries",
Description = "Plain, 0–5. It starts AT Min, so − is already dimmed.",
Default = 0, Min = 0, Max = 5, Step = 1,
})

tab:AddSection("Button states")
tab:AddParagraph(
"Hover any button for the wash, press for the 0.97 scale and the deeper fill, release for " ..
"the spring back. The two below are the states you cannot reach by hovering.")



local busy = false
local loadBtn
loadBtn = tab:AddButton({ Text = "Run a task (loading state)", Icon = "refresh-cw", Variant = "secondary",
Callback = function()
if busy then return end
busy = true
loadBtn.SetLoading(true)
task.delay(1.8, function()
loadBtn.SetLoading(false)
busy = false
window:ShowSuccess({ Title = "Done", Message = "The spinner was one repeating tween." })
end)
end })




local off = false
local dimBtn
dimBtn = tab:AddButton({ Text = "Disable the toggle and slider", Icon = "lock", Variant = "outline",
Callback = function()
off = not off
demoToggle.SetEnabled(not off)
demoSlider.SetEnabled(not off)
dimBtn.SetText(off and "Enable the toggle and slider" or "Disable the toggle and slider")
if off then

demoToggle.Set(false)
demoSlider.SetValue(65)
window:ShowInfo({ Title = "Dimmed, not frozen",
Message = "Both are disabled, yet code just moved them. Only YOUR input is blocked." })
end
end })

tab:AddButton({ Text = "Born disabled (nothing happens)", Variant = "destructive", Disabled = true,
Callback = function() window:ShowError({ Title = "This should never fire" }) end })

tab:AddSection("Reduced motion")
tab:AddParagraph(
"Every movement on this tab is one switch away from being instant. Turn it on, then come " ..
"back up and click the same controls: the knob teleports, the slider fill jumps to its new " ..
"width, the completion flash never appears, and the two REFUSALS — the number box bump and " ..
"the field shake — do not run at all, because a pure there-and-back has no end state worth " ..
"snapping to. Turn it off and the tab animates again.")



tab:AddToggle({
Text = "Reduce motion",
Description = "The same switch the OS reduce-motion setting drives by default.",
Default = false,
Callback = function(on) window:SetAnimationsEnabled(not on) end,
})
end

end


EmbeddedModules["showcase/overlays"] = function()


return function(window)
local tab = window:AddTab({ Name = "Overlays", Icon = "bell" })

tab:AddSection("Toasts")
tab:AddParagraph(
"Raise three or four in a row, then put the cursor over the stack. They fan out on a " ..
"stagger — each row further back waits a beat longer — and the countdown pauses while you " ..
"hover. Move away and they collapse back to a stack with the newest in front. Each toast is " ..
"one canvas group, so it fades and exits as a single piece instead of part by part.")
tab:AddButton({ Text = "Success", Icon = "circle-check",
Callback = function() window:ShowSuccess({ Title = "Saved", Message = "Everything landed." }) end })
tab:AddButton({ Text = "Warning", Icon = "triangle-alert", Variant = "secondary",
Callback = function() window:ShowWarning({ Title = "Careful", Message = "That one is close to the limit." }) end })
tab:AddButton({ Text = "Error", Icon = "circle-x", Variant = "destructive",
Callback = function() window:ShowError({ Title = "Failed", Message = "The request came back empty." }) end })
tab:AddButton({ Text = "Info", Icon = "info", Variant = "outline",
Callback = function() window:ShowInfo({ Title = "Heads up", Message = "Nothing is on fire." }) end })
tab:AddButton({ Text = "With an action button", Variant = "ghost", Callback = function()
window:Notify({ Title = "Item deleted", Message = "Removed from your inventory.", Type = "warning",
Action = { Text = "Undo", Callback = function() window:ShowSuccess({ Title = "Restored" }) end } })
end })


local promising = false
tab:AddButton({ Text = "Loading toast that resolves", Icon = "loader", Variant = "secondary", Callback = function()
if promising then return end
promising = true
window:Promise(function() task.wait(1.6); return 42 end, {
Loading = "Fetching…", Error = "Could not fetch",
Success = function(n) return "Fetched " .. tostring(n) .. " rows" end,
Finally = function() promising = false end })
end })



local loadingId
tab:AddButton({ Text = "Spinner toast, dismissed by hand", Icon = "loader", Variant = "outline", Callback = function()
if loadingId then window:DismissNotification(loadingId); loadingId = nil; return end
loadingId = window:ShowLoading({ Title = "Working…", Message = "Click the button again to dismiss it.",
OnDismiss = function() loadingId = nil end })
end })


tab:AddSelectBox({ Text = "Toast corner", Default = "bottom-right", Searchable = false,
Description = "Move the stack, raise a toast, and watch which way it leaves.",
Options = { "top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right" },
Callback = function(v)
window:SetNotificationPosition(v)
window:ShowInfo({ Title = "Stack moved", Message = tostring(v), Duration = 2500 })
end })

tab:AddSection("Dialog")
tab:AddParagraph(
"The card fades in from 94%, rises about 12px and settles with a spring; the scrim behind it " ..
"fades rather than cutting in, and the card has its own drop shadow on top of the scrim. " ..
"The keyboard answers in two different ways. Escape (or gamepad B) is a DISMISSAL: the card " ..
"folds back down — shrink, fade, drop, scrim last — and no footer callback runs at all, so " ..
"nothing below is a safe way to say yes. Return (or gamepad A) is the answer: it fires the " ..
"LAST button, the primary one on the right, callback and all.")
tab:AddButton({ Text = "Open a dialog", Icon = "message-square", Callback = function()
window:Dialog({ Title = "Delete this loadout?", Message = "This cannot be undone.", Icon = "trash-2",
Buttons = {
{ Text = "Cancel", Variant = "secondary" },
{ Text = "Delete", Variant = "destructive", Icon = "trash-2",
Callback = function() window:ShowSuccess({ Title = "Deleted" }) end } } })
end })


local DESTRUCTIVE = Color3.fromRGB(239, 68, 68)
tab:AddButton({ Text = "Badge header", Icon = "triangle-alert", Variant = "destructive", Callback = function()


window:Dialog({ Title = "Ban this player?", Message = "They lose access the moment you confirm.",
Icon = "ban", IconBadge = true, IconColor = DESTRUCTIVE, Buttons = {
{ Text = "Cancel", Variant = "secondary" },
{ Text = "Ban", Variant = "destructive", Icon = "ban" } } })
end })
tab:AddButton({ Text = "A wider card", Icon = "expand", Variant = "outline", Callback = function()


window:Dialog({ Title = "Release notes", Width = 460, Icon = "expand",
Message = "460 wide instead of the default 320. Still one canvas group, so the whole sheet — " ..
"header, rule and footer — zooms and fades as a single piece at any width.",
Buttons = { { Text = "Close" } } })
end })
tab:AddButton({ Text = "Stack two dialogs", Icon = "layers", Variant = "secondary", Callback = function()



window:Dialog({ Title = "Underneath", Message = "This one painted the scrim and holds it.",
Buttons = { { Text = "Close", Variant = "secondary" } } })
window:Dialog({ Title = "On top", Icon = "layers",
Message = "The room is no darker than it was for one card — a stacked dialog skips the scrim " ..
"instead of laying a second over the first. Escape and Return answer here only.",
Buttons = { { Text = "Close", Variant = "secondary" },


{ Text = "One more on top", Callback = function()
window:Dialog({ Title = "Third", Buttons = { { Text = "Done" } },
Message = "Its opener closed beneath it; the bottom card still holds the scrim." })
end } } })
end })

tab:AddSection("Popovers")
tab:AddParagraph(
"Open the dropdown and watch where it comes FROM: it grows out of its own field, scaling up " ..
"with a slide, and the caret rotates 180 degrees while it does. It gets the same frosted " ..
"glass and drop shadow as the window, so it floats instead of sitting flat. Close it and it " ..
"shrinks back down rather than blinking out. Near the bottom of the screen it flips upward " ..
"and grows from the other edge.")


tab:AddSelectBox({ Text = "Region", Default = "eu-west",
Description = "More than five options, so the search field appears on its own.",
Options = {
{ Value = "eu-west", Text = "Europe West", Icon = "globe" },
{ Value = "eu-north", Text = "Europe North", Icon = "globe" },
{ Value = "us-east", Text = "US East", Icon = "map-pin" },
{ Value = "us-west", Text = "US West", Icon = "map-pin" },
{ Divider = true },
{ Value = "ap-south", Text = "Asia Pacific South", Icon = "navigation" },
{ Value = "ap-north", Text = "Asia Pacific North", Icon = "navigation" },
{ Value = "sa-east", Text = "South America East", Icon = "compass" },
{ Value = "af-south", Text = "Africa South", Icon = "compass" },
},
Callback = function(v) window:ShowInfo({ Title = "Region", Message = tostring(v), Duration = 2000 }) end })



tab:AddSelectBox({ Text = "Modules", Multi = true,
Description = "Multi-select: the field summarises, and a clear button appears once something is picked.",
Options = { "Aim", "ESP", "Movement", "Render", "Audio", "Network" },

Callback = function(list) window:ShowInfo({ Title = "Modules", Message = #list .. " selected", Duration = 2000 }) end })

tab:AddParagraph(
"The colour picker is the same popover machinery. The SV square and the hue strip each have " ..
"a dot with a 1px rim so it stays visible over a bright patch, and the swatch on the row " ..
"follows live as you drag.")
tab:AddColorPicker({ Text = "Highlight colour", Default = Color3.fromRGB(120, 160, 255) })

tab:AddSection("Keybind")


tab:AddParagraph(
"Click the chip: it goes into listening state — its hairline thickens to 2px, lifts to the " ..
"neutral ring colour and breathes in and out, and the label reads 'Press a key'. The next " ..
"key you press is captured with an accent flash on that same hairline as the ring leaves. " ..
"Escape cancels and keeps the old binding.")
tab:AddKeybind({ Text = "Flash a toast", Default = Enum.KeyCode.G,
Callback = function() window:ShowInfo({ Title = "Keybind fired", Duration = 1500 }) end })

tab:AddSection("Locked")
tab:AddParagraph(
"Lock the window and every control it registered — on this tab and the other three — drops " ..
"under a scrim with an invisible shield above it: the row still reads, it just stops " ..
"answering the mouse. That scrim is its own flag, separate from a disabled control — Disabled " ..
"dims one control and blocks its input while its value still updates, and clearing either one " ..
"does not clear the other.")
local locked, lockBtn = false, nil
lockBtn = tab:AddButton({ Text = "Lock every control", Icon = "lock", Variant = "outline", Callback = function()
locked = not locked


if locked then window:LockAll(); lockBtn.SetLocked(false) else window:UnlockAll() end
lockBtn.SetText(locked and "Unlock every control" or "Lock every control")
end })
end

end


EmbeddedModules["showcase/surfaces"] = function()



return function(window, logo)


logo = logo or "https://alfin-efendy.github.io/ez-rbx-ui/brand/ezui-blade-zu-icon.png"


local tab = window:AddTab({ Name = "Surfaces, tables and cards", Icon = "layers" })

tab:AddSection("Type hierarchy")
tab:AddParagraph(
"Three weights, three roles. The section heading above is the overline: 11px Medium, " ..
"uppercase, muted — it groups without shouting. This paragraph is body Regular in the muted " ..
"foreground with a 1.25 line height, so a block of it does not clot together. A label is the " ..
"same size in the full foreground, which is why it reads as a value and this reads as prose.")
tab:AddLabel({ Text = "A plain label — full foreground, one line.",
Tooltip = "Tooltips fade in after a ~0.35s hover intent, and are inverted against the panel." })
tab:AddLabel({ Variant = "paragraph",
Text = "A paragraph label honours explicit line breaks too:\nthis is the second line,\nand this is the third." })

tab:AddSection("Hairlines")
tab:AddParagraph(
"A separator is a 1px rule in the border colour — the same token as the panel edge, the " ..
"dialog footer rule and the table header underline, so every divider in the library sits on " ..
"one value. Two of them around this row:")
tab:AddSeparator()
tab:AddLabel("Between two separators.")
tab:AddSeparator()

tab:AddSection("Card")
tab:AddParagraph(
"A card is the row surface one step up from the panel, with its own hairline and radius. Its " ..
"action buttons size to their own text instead of stretching edge to edge.")
tab:AddCard({
Title = "Depth, honestly",
Body = "Shadow and glow are siblings rendered UNDER their host; the rim light and the sheen " ..
"are clipped children on top. That ordering is what keeps a glow behind a toggle " ..
"instead of washing over it.",
Tooltip = "Cards accept a Tooltip as well — it attaches to the whole card frame.",
Buttons = {
{ Text = "Nice", Callback = function() window:ShowSuccess({ Title = "Agreed", Duration = 1500 }) end },
{ Text = "Show me a toast", Variant = "secondary",
Callback = function() window:ShowInfo({ Title = "Here you go", Duration = 1500 }) end },
{ Text = "Dismiss", Variant = "ghost" },
},
})
tab:AddCard({
Banner = logo,
Title = "A second card, with a banner and a title far too long to fit on one line of it",
Body = "The banner is an 80px slot at the top of the card, filled with whatever Asset can " ..
"resolve — an asset id, or a URL like this one. The slot is reserved first and the " ..
"picture lands when the download finishes, so a card never blocks on the network; " ..
"where the executor cannot download at all the slot is never built and the card just " ..
"starts at its title. That title is the other thing to look at: one line with " ..
"TextTruncate.AtEnd, so it stops in an ellipsis instead of wrapping or widening.",
Buttons = {
{ Text = "Where did it come from?", Variant = "secondary", Callback = function()
window:ShowInfo({ Title = "Same mark as the title bar", Duration = 2000,
Message = "One white-on-transparent PNG, tinted per mode up there, full colour here." })
end },
},
})

tab:AddSection("Table")
tab:AddParagraph(
"The header row is pinned and the body scrolls under it. Rows answer hover with a fill wash " ..
"only — the row colour itself stays a pure token, so a theme switch cannot drift it. The " ..
"first row's middle cell is longer than its column on purpose: a cell is one line with " ..
"TextTruncate.AtEnd, so it ends in an ellipsis rather than wrapping or widening the column.")
tab:AddTable({
Columns = { "Layer", "Rendered as", "Sits" },
Rows = {
{ "Drop shadow", "a 9-slice image sibling that spreads wider and darkens while you drag", "under" },
{ "Accent glow", "9-slice image", "under" },
{ "Rim light", "gradient on stroke", "on top" },
{ "Sheen", "gradient frame", "on top" },
{ "Grain", "tiled noise", "clipped" },
},
Height = 110,
Tooltip = "Scroll the body — the header stays put.",
})

tab:AddSection("Accordion")
tab:AddParagraph(
"Open and close it a couple of times: the collapse is the mirror of the expand, not a faster " ..
"cut, and the caret turns at the same pace rather than snapping. The header answers hover " ..
"with its own wash while the card body keeps its colour.")
local acc = tab:AddAccordion({ Title = "Nested controls", Icon = "rows-3", Expanded = false })
acc:AddToggle({ Text = "A toggle in here", Default = true, Description = "Same spring as on the Motion tab." })
acc:AddSlider({ Text = "And a slider", Min = 0, Max = 10, Default = 6 })
acc:AddButton({ Text = "And a button", Variant = "secondary",
Tooltip = "Controls inside an accordion get the full host API, tooltips included.",
Callback = function() window:ShowInfo({ Title = "From inside the accordion", Duration = 1500 }) end })

tab:AddSection("Split pane")
tab:AddParagraph(
"Two panes sharing one seam, and the seam is draggable: grab the small grip pill in the middle " ..
"and pull. Its glyph is muted at rest and lifts to the foreground while the pointer is on the " ..
"handle, and the pill itself scales up for as long as you hold it, then springs back on " ..
"release. Each pane is a full control host — the two below are live controls, not a picture of " ..
"a layout — so they reflow as the fractions move.")
local split = tab:AddResizable({ Direction = "Horizontal",
Panes = { { Default = 0.45 }, { Default = 0.55 } }, Height = 116 })
split.Panes[1]:AddLabel("Left pane")
split.Panes[1]:AddToggle({ Text = "A toggle", Default = true })
split.Panes[2]:AddLabel("Right pane")
split.Panes[2]:AddProgressBar({ Default = 0.6 })

tab:AddSection("Image")
tab:AddParagraph(
"The image control takes a Lucide name as well as an asset id. Rendered as a glyph it is " ..
"tinted to the theme foreground, so it re-tints itself when you switch mode on the Look tab " ..
"— no second asset for light mode.")
tab:AddImage({ Lucide = "layers", Height = 72,
Tooltip = "Switch to light mode on the Look tab and come back — this glyph follows." })
end

end


local function loadModule(url)

if EmbeddedModules[url] then
return EmbeddedModules[url]()
end


return require(url)
end










local EzUI = loadModule("../output/bundle")






local LOGO = "https://alfin-efendy.github.io/ez-rbx-ui/brand/ezui-blade-zu-icon.png"

local window = EzUI:CreateWindow({
Title = "EzUI Showcase",
Subtitle = "A tour of the visual polish",
Image = LOGO,
ImageAdaptive = true,


Ratio = { Width = 0.46, Height = 0.62 },
Transparency = 0.12,
ToggleKey = Enum.KeyCode.RightControl,



FloatingToggle = { Type = "simple", Image = LOGO, Adaptive = true, AutoHide = true },



})





local function category(name)
local group = window:AddTabGroup(name)
return setmetatable({ AddTab = function(_, o) return group:AddTab(o) end }, {
__index = function(_, k)
local v = window[k]
if type(v) ~= "function" then return v end
return function(_, ...) return v(window, ...) end
end,
})
end


local shell = category("The shell")
loadModule("showcase/look")(shell)
local contents = category("The contents")
loadModule("showcase/motion")(contents)
loadModule("showcase/overlays")(contents)
loadModule("showcase/surfaces")(contents, LOGO)

window:Tag({ Text = "polish", Icon = "sparkles" })
window:ShowInfo({
Title = "EzUI Showcase",
Message = "Four tabs under two sidebar headers. Start on Look — it explains the window itself.",
Duration = 6000,
})
