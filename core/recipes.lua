-- Deps injected via Init(R). State kit: one recipe per interaction state (hover wash, press
-- scale, focus ring, disabled dim, empty state, scrollbar) so every control answers input the
-- same way. Stateless per call (the module is cached across tests): each recipe returns a handle
-- whose disconnect() drops every connection it made, so callers maid:Give(handle.disconnect).
-- Handlers run inside signal callbacks (capability present), so they write GUI state directly.
local Recipes = {}
local Create, Theme, Animate, Icons, Safe, Device

function Recipes.Init(R)
  Create = R.Create; Theme = R.Theme; Animate = R.Animate; Icons = R.Icons; Safe = R.Safe; Device = R.Device
end

local function noop() end
local NOOP_HANDLE = { reskin = noop, disconnect = noop }

-- Module defaults stand in when a caller has no window theme yet (Theme exposes DEFAULT groups).
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

-- A colour option is a Colors token NAME (resolved live so SetMode/SetAccent reskin by name) or
-- a Color3 the caller owns; `default` is the token name used when the option is absent.
local function colorOf(theme, c, default)
  if type(c) == "string" then return theme.Colors[c] or theme.Colors[default] end
  if c ~= nil then return c end
  return theme.Colors[default]
end

-- MouseButton1Down/Up exist on GuiButton only; a plain Frame (table Row, kind='fill') presses
-- through InputBegan/InputEnded instead, filtered to primary click and touch.
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

-- Pointer hover persists after a click, but a touch tap fires Enter/Down/Up with no Leave, so a
-- release under touch must fall back to rest or the wash sticks (device.lua rationale).
local function pointerHover() return Device.SupportsHover() and Device.GetInput() ~= "Touch" end

-- ---- hover ------------------------------------------------------------------------------------
local function pick(state, rest, hover, press)
  if state == "press" then return press elseif state == "hover" then return hover end
  return rest
end

-- The visual parts one hover kind drives: { {inst, prop, valueOf}, ... } where valueOf(state)
-- resolves the goal for "rest" | "hover" | "press" at paint time. The 'wash' kind is not built
-- here: it is the only kind that owns instances, so washBuilder defers it instead.
local function hoverParts(kind, host, opts, theme)
  if kind == "fill" then
    -- No new Frame (host has a UIListLayout): the host's own transparency carries the state and
    -- returns to whatever it rested at; BackgroundColor3 is never touched (identity tests).
    local restA = host.BackgroundTransparency or 1
    local hoverA = opts.hoverAlpha or theme.Opacity.rowHover
    local pressA = opts.pressAlpha or hoverA
    return { { host, "BackgroundTransparency", function(s) return pick(s, restA, hoverA, pressA) end } }
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

-- The wash is the one hover part that owns instances (a Frame plus its UICorner) and it is
-- invisible at rest, so a control that is never pointed at -- every control on a touch device,
-- most controls in a large hub -- used to pay for two it would never show. Bind time now only
-- measures it: the geometry, the corner and the alphas are captured exactly as before, and the
-- returned builder makes the Frame on the first paint that could reveal it. The colour is read
-- inside the builder rather than here, so a SetMode/SetAccent between bind and the first hover
-- washes with the CURRENT palette instead of the one that happened to be live at construction.
local function washBuilder(host, opts, theme)
  local inset = opts.inset or {}
  local ix, iy = inset.x or inset[1] or 0, inset.y or inset[2] or 0
  local corner = opts.corner
  local hoverA, pressA = opts.hoverAlpha or theme.Opacity.hoverWash, opts.pressAlpha or theme.Opacity.pressWash
  return function()
    -- ZIndex 0: above the host fill, below its content (Sibling behaviour); the negative inset
    -- cancels the row's UIPadding so the wash covers the whole row.
    local wash = Create("Frame", {
      Name = "Hover", BackgroundColor3 = theme.Colors.foreground, BackgroundTransparency = 1, BorderSizePixel = 0,
      Size = UDim2.new(1, 2 * ix, 1, 2 * iy), Position = UDim2.new(0, -ix, 0, -iy),
      ZIndex = 0, Active = false, Parent = host,
    })
    if corner then Create.corner(corner).Parent = wash end
    return wash, { wash, "BackgroundTransparency", function(s) return pick(s, 1, hoverA, pressA) end }
  end
end

-- Shared core: `sources` are the instances whose Enter/Leave/Down/Up drive one visual state
-- (iconButton feeds the glyph button AND its hit target).
local function bindHover(sources, opts)
  opts = opts or {}
  local theme = themeOf(opts)
  if not Device.SupportsHover() then return NOOP_HANDLE end
  local kind = opts.kind or "wash"
  local host = opts.host or sources[1]
  local parts, buildWash = {}, nil
  if kind == "wash" then buildWash = washBuilder(host, opts, theme)
  else parts = hoverParts(kind, host, opts, theme) end

  local handle, wash
  -- A "rest" paint has nothing to say to a wash that does not exist yet (a fresh one rests fully
  -- transparent), so the first paint that is NOT rest -- a hover, or a press that never saw an
  -- Enter -- is the moment the Frame has to be real. Every later paint reuses it.
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

  -- The handle is built before the first connection so ensureWash can publish .Frame onto it.
  local conns = {}
  local dropConns = disconnectAll(conns)
  handle = {
    -- .Frame stays nil for fill/text, and for wash until the first hover builds one.
    -- re-read tokens by name after SetMode/SetAccent; the wash colour is the only owned colour,
    -- text parts repaint their current state instantly (no tween inside a themer closure)
    reskin = function()
      if wash then wash.BackgroundColor3 = theme.Colors.foreground end
      if kind == "text" then paint(state, true) end
    end,
    -- releases whatever exists: the connections, and the pending builder, so a handle that has
    -- been let go can never add a Frame to its host afterwards
    disconnect = function() buildWash = nil; dropConns() end,
  }
  for _, src in ipairs(sources) do
    conns[#conns + 1] = src.MouseEnter:Connect(enter)
    conns[#conns + 1] = src.MouseLeave:Connect(leave)
    onPress(conns, src, down, up)
  end
  return handle
end

-- Recipes.hover(hit, { theme, host, corner, inset = {x,y}, kind = 'wash'|'text'|'fill', label, icon,
--   rest, hover, hoverAlpha, pressAlpha }) -> { Frame, reskin, disconnect }
-- wash: child Frame 'Hover' in host (never 'Active'), built on the FIRST hover rather than at bind
-- time, so .Frame is nil until a pointer has actually arrived; fill: host transparency only; text:
-- label / icon tint. Skipped entirely (no Frame, no handlers) when the device has no pointer.
function Recipes.hover(hit, opts) return bindHover({ hit }, opts) end

-- ---- press ------------------------------------------------------------------------------------
-- UIScale lives in scaleHost (the inner content), never the row itself: a UIScale on a
-- UIListLayout item reflows its siblings. scaleHost nil = no scale at all; the press feedback is
-- then just the wash/fill dip the hover recipe already applies on Down.
function Recipes.press(hit, scaleHost, opts)
  if scaleHost == nil then return { disconnect = noop } end
  local theme = themeOf(opts)
  local us = scaleHost:FindFirstChildOfClass("UIScale") or Create("UIScale", { Scale = 1, Parent = scaleHost })
  local pressed = false
  local function down() pressed = true; Animate.to(us, "press", { Scale = theme.Motion.pressScale }) end
  -- release only from a pressed state so a plain mouse-out does not spend a tween going 1 -> 1
  local function up() if pressed then pressed = false; Animate.springTo(us, "release", { Scale = 1 }) end end
  local conns = {}
  onPress(conns, hit, down, up)
  conns[#conns + 1] = hit.MouseLeave:Connect(up)
  return { Scale = us, disconnect = disconnectAll(conns) }
end

-- ---- iconButton -------------------------------------------------------------------------------
-- Centre of a GuiObject in its parent's UDim2 space, honouring AnchorPoint (default 0,0).
local function centreOf(inst)
  local p, s, a = inst.Position, inst.Size, inst.AnchorPoint
  if not p or not s then return UDim2.new(0.5, 0, 0.5, 0) end
  local ax, ay = a and a.X or 0, a and a.Y or 0
  return UDim2.new(p.X.Scale + s.X.Scale * (0.5 - ax), p.X.Offset + s.X.Offset * (0.5 - ax),
    p.Y.Scale + s.Y.Scale * (0.5 - ay), p.Y.Offset + s.Y.Offset * (0.5 - ay))
end

-- Recipes.iconButton(btn, { theme, icon, rest, hover, hitSize, parent, onClick }) -> { Hit, reskin, disconnect }
-- The glyph button keeps its own size (an ImageButton renders its Image at full Size, so the
-- glyph IS the button); a transparent sibling '<Name>Hit' supplies the comfortable target
-- (Sizes.iconButton, Sizes.touchHit on touch). Handlers are bound to BOTH so existing tests that
-- fire on the button keep working and pointer input landing on the hit behaves the same.
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

-- ---- focus ------------------------------------------------------------------------------------
-- Recipes.focus(stroke, host, getColor, { theme }) -> { set, disconnect }
-- getColor(focused) stays the caller's single source of stroke colour (precedence such as
-- invalid > focused > border lives there); the recipe only owns Thickness. Focused/FocusLost are
-- TextBox-only and SelectionGained/Lost are gamepad selection, so each is bound only when the
-- host exposes it (read under pcall: Roblox throws on a missing member). set(focused) covers
-- hosts with no focus event of their own (SelectBox field open, Keybind chip listening).
function Recipes.focus(stroke, host, getColor, opts)
  opts = opts or {}
  local theme = themeOf(opts)
  local restThickness = stroke.Thickness or 1
  -- A hairline host (the sidebar/dropdown search rest at Stroke.search: 0.8 dark, 0.5 light) would
  -- draw its ring at that same alpha and read as almost nothing, so a translucent rest fades to
  -- opaque while focused and back on blur. opts.restAlpha (number or function) is re-read on every
  -- paint so a SetMode mid-focus still restores the right hairline; a stroke that already rests
  -- opaque (TextBox/NumberBox/Keybind) gets no Transparency goal at all.
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
  -- Gamepad selection: the stroke IS the ring, so the engine's default adornment is replaced by
  -- an invisible, unparented Frame. Written blind under pcall: nil is the default in Roblox and
  -- in the mock alike, so reading it back could never tell "unset" from "unsupported".
  pcall(function()
    host.SelectionImageObject = Create("Frame", { Name = "SelectionImage", BackgroundTransparency = 1, BorderSizePixel = 0 })
  end)
  return { set = apply, disconnect = disconnectAll(conns) }
end

-- ---- disabled ---------------------------------------------------------------------------------
-- Recipes.disabled(parts, on, theme) with parts = { {inst, prop, rest}, ... }: every part tweens
-- to Opacity.disabled when on, back to its own rest (the value it had while enabled) when off.
-- rest omitted = the engine default 0 for *Transparency; a nil inst (optional stroke) is skipped.
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

-- ---- empty ------------------------------------------------------------------------------------
-- Recipes.empty(parent, { theme, text, icon, zIndex }) -> { Frame, SetVisible, reskin }
-- Hidden until the owner says the list is empty (its SetVisible already runs inside the owner's
-- Safe.mutate toggle). Parent must be layout-free: the frame fills it and centres its stack.
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

-- ---- scrollbar --------------------------------------------------------------------------------
-- Idempotent, so a themer closure simply calls it again to re-tint. Top/Mid/BottomImage stay at
-- the engine default until Scrollbar.imageId names a verified flat asset.
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
