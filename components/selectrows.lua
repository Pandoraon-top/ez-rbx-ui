-- Deps injected via Init(R).
-- The option list of an OPEN SelectBox popover, virtualised. Building every row on open cost about
-- five instances, a click connection and a hover recipe per option -- some 1,500 instances for a
-- 300-pet picker. Only the rows in view, plus BUFFER px above and below, exist now; scrolling binds
-- those slots to the options coming into view.
--
-- Model: one item per option (dividers too), in list order. A filter keeps the dividers and the
-- matching rows ("shown"). Each shown item gets the y the old UIListLayout gave it (row 26 px, 38
-- with a description, divider 1 px, 2 px apart) and the list's CanvasSize is the whole stack, so
-- the scrollbar still reads the full list.
-- Slots: recycled row buttons. A slot remembers what it shows (text, icon, description, place,
-- tick), so binding it to another option writes only what differs; a slot with no option is hidden.
local SelectRows = {}
local Create, Icons, Recipes, Safe

function SelectRows.Init(R) Create = R.Create; Icons = R.Icons; Recipes = R.Recipes; Safe = R.Safe end

local ROW_H, DESC_H, DIV_H, GAP = 26, 38, 1, 2
local BUFFER = 120   -- px of rows kept built past each edge of the view, so a flick shows no gap

-- Options without a usable key (nil, NaN) share this one.
local NOKEY = {}
local function keyOf(v) if v == nil or v ~= v then return NOKEY end return v end
SelectRows.keyOf = keyOf
SelectRows.NOKEY = NOKEY

-- Search text of a row: value, label and description, lower-cased once.
local function searchText(e)
  return (tostring(e.value) .. " " .. tostring(e.label or "") .. " " .. tostring(e.desc or "")):lower()
end

-- Row hover answers on transparency ONLY: the row keeps the pure surface token as its
-- BackgroundColor3 (identity assertions) and the recipe captures its current transparency as
-- the rest it returns to — 0 for a selected row, 1 for an unselected one.
local function bindHover(o, theme)
  return Recipes.hover(o, { theme = theme, kind = "fill", hoverAlpha = theme.Opacity.optionHover })
end

-- Fill, check and hover rest for a slot's selection. Writes nothing when the slot already shows
-- that selection, unless `force` (a re-skin replays everything).
function SelectRows.tick(slot, sel, theme, force)
  if sel == slot.sel and not force then return end
  -- The hover recipe moves its rest in place (a slot is re-ticked on every scroll that brings a
  -- picked option into it, so it is never rebuilt); a pointer device-less recipe has no rest to
  -- move, and the fill is written directly.
  local rest = sel and 0 or 1
  if slot.hover and slot.hover.setRest then slot.hover.setRest(rest) else slot.btn.BackgroundTransparency = rest end
  slot.sel = sel
  if sel then Icons.apply(slot.check, "check", theme.Colors.foreground) end
  slot.check.Visible = sel
end

-- Attributes take strings, numbers and booleans here; a table value (an option keyed by an
-- object) is shown and picked like any other but carries no attribute.
local function attrOf(v)
  local t = type(v)
  if t == "string" or t == "number" or t == "boolean" then return v end
  return nil
end

local List = {}
List.__index = List

-- ctx = { theme, onPick(value), picked() -> function(value) -> bool, viewH (px, until measured) }
function SelectRows.new(list, ctx)
  local self = setmetatable({ list = list, ctx = ctx, theme = ctx.theme, items = {}, shown = {},
    slots = {}, divs = {}, query = "", canvasH = -1, rowsShown = 0, conns = {} }, List)
  -- engine threads (no GUI capability on strict executors) -> Safe.mutate
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
  -- The click fires on the release. A slot rebound between the press and the release (a wheel or
  -- a drag scrolled it to another option) picks nothing: `pressed` is the option under the press,
  -- and bind voids it. A click with no press seen (a script, a gamepad) picks what the slot shows.
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

-- Show item `it` in `slot`, writing only what the slot does not already show.
function List:bind(slot, it, isPicked)
  local theme, e, o = self.theme, it.e, slot.btn
  if slot.pressed and slot.pressed ~= it then slot.pressed = false end   -- a press in flight: void it
  slot.item = it; it.slot = slot
  if slot.y ~= it.y then o.Position = UDim2.new(0, 0, 0, it.y); slot.y = it.y end
  if slot.h ~= it.h then o.Size = UDim2.new(1, 0, 0, it.h); slot.h = it.h end
  -- No layout reads LayoutOrder any more; it stays the option's index so code outside can still
  -- recover the list order of the rows it finds.
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
  -- label / description geometry depends on the icon offset and on whether a description shows
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
  -- last: everything above already shows the option even if the engine refuses the attribute
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

-- The options (normalised) the list holds. Keeps the query and the scroll position; the slots
-- keep what they show and are bound again in view order, so an unchanged list writes nothing.
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

-- `query` lower-cased: dividers stay, rows whose value, label or description contain it show.
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

-- The height of the view in the list's own (unscaled) px: the popover knows it exactly, and the
-- engine's AbsoluteWindowSize is in screen px, scaled by the popover's UIScale -- mixing the two
-- cut the bottom rows off a scaled list.
function List:viewHeight()
  local vh = self.ctx.viewH
  return (type(vh) == "number" and vh > 0) and vh or 240
end

-- Bind slots to the shown items inside the band [top - BUFFER, top + view + BUFFER].
function List:render()
  local list = self.list
  local vh = self:viewHeight()
  local cp = list.CanvasPosition
  local top = (cp and cp.Y) or 0
  -- A list that got shorter (a filter, fewer options) keeps its scroll inside the new canvas. The
  -- write re-fires CanvasPosition; that render finds top == maxTop and binds nothing new. It must
  -- stay BEFORE the band is built, which reads the clamped top.
  local maxTop = math.max(0, self.canvasH - vh)
  if top > maxTop then top = maxTop; list.CanvasPosition = Vector2.new(cp and cp.X or 0, top) end
  local lo, hi = top - BUFFER, top + vh + BUFFER
  local band = {}
  for _, it in ipairs(self.shown) do
    if it.y + it.h >= lo and it.y <= hi then band[it] = true end
  end
  -- slots whose option left the band (or the list) are free; reuse them in on-screen order
  local free, freeDivs = {}, {}
  for _, s in ipairs(self.slots) do
    if s.item and not band[s.item] then s.item.slot = nil; s.item = nil end
    if not s.item then free[#free + 1] = s end
  end
  for _, d in ipairs(self.divs) do
    if d.item and not band[d.item] then d.item.slot = nil; d.item = nil end
    if not d.item then freeDivs[#freeDivs + 1] = d end
  end
  -- in on-screen order, so an unchanged list re-binds each slot to the row it already shows
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
      if s.hover and s.hover.settle then s.hover.settle() end   -- never parked carrying a hover tint
    end
  end
  for i = nd, #freeDivs do local d = freeDivs[i]; if d.on then d.frame.Visible = false; d.on = false end end
end

-- Tick exactly the shown slots whose selection changed (a pick, a SetValue, a SetOptions).
function List:syncSelection()
  local isPicked = self.ctx.picked()
  for _, s in ipairs(self.slots) do
    if s.item then SelectRows.tick(s, isPicked(s.item.e.value), self.theme) end
  end
end

-- Every colour from the live palette, plus the selection (the themer replay).
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
