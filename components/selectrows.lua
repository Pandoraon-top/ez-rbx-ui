-- Deps injected via Init(R).
-- The option rows of an OPEN SelectBox popover. Each row has an entry that keeps the row's parts
-- and the values they show, so an update compares against the entry instead of reading Instance
-- properties back:
--   { btn, value, opt (normalised option), order, labelText, sel, vis, hover, icon,
--     check, lead, label, desc, find (lower-cased search text) }
-- SelectRows.sync is what SetOptions on an open popover runs: rows are keyed by option Value, so a
-- 300-row list whose labels change writes 300 labels instead of building 300 rows again, and the
-- list (scroll position, search box) is never touched.
local SelectRows = {}
local Create, Icons, Recipes

function SelectRows.Init(R) Create = R.Create; Icons = R.Icons; Recipes = R.Recipes end

-- Options without a usable key (nil, NaN) share this one and are matched in list order, so an
-- "Any" sentinel row is kept like any other.
local NOKEY = {}
local function keyOf(v) if v == nil or v ~= v then return NOKEY end return v end
SelectRows.keyOf = keyOf
SelectRows.NOKEY = NOKEY

-- Search text of a row: value, label and description, lower-cased once.
local function searchText(e)
  return (tostring(e.value) .. " " .. tostring(e.label or "") .. " " .. tostring(e.desc or "")):lower()
end

-- What decides a row's layout: a description (taller row) and a leading icon (label offset).
-- A row whose shape changes is built again; anything else is updated where it stands.
local function sameShape(a, b) return (a.desc ~= nil) == (b.desc ~= nil) and (a.icon ~= nil) == (b.icon ~= nil) end

-- Row hover answers on transparency ONLY: the row keeps the pure surface token as its
-- BackgroundColor3 (identity assertions) and the recipe captures its current transparency as
-- the rest it returns to — 0 for a selected row, 1 for an unselected one.
local function bindHover(o, theme)
  return Recipes.hover(o, { theme = theme, kind = "fill", hoverAlpha = theme.Opacity.optionHover })
end

-- One option row. ctx = { theme, onPick(value) }.
function SelectRows.make(list, e, order, sel, ctx)
  local theme = ctx.theme
  local rowH = e.desc and 38 or 26
  local o = Create("TextButton", { Name = "Opt", AutoButtonColor = false, Text = "", Visible = true,
    BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = sel and 0 or 1, ZIndex = 1002,
    Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = order, Parent = list, Create.corner(theme.Radius.sm),
    Create.padding({ left = 6, right = 6 }) })
  o:SetAttribute("OptValue", e.value)
  local check = Create("ImageLabel", { Name = "Check", BackgroundTransparency = 1, ZIndex = 1003, Visible = sel,
    Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 0, 0.5, -7), Parent = o })
  if sel then Icons.apply(check, "check", theme.Colors.foreground) end
  local textX, lead = 20, nil
  if e.icon then
    lead = Create("ImageLabel", { Name = "Lead", BackgroundTransparency = 1, ZIndex = 1003,
      Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 20, 0.5, -7), Parent = o })
    Icons.apply(lead, e.icon, theme.Colors.foreground)
    textX = 40
  end
  local labelText = e.label or tostring(e.value)
  local optLabel = Create("TextLabel", { Name = "OptLabel", BackgroundTransparency = 1, Text = labelText, ZIndex = 1003,
    TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
    Size = UDim2.new(1, -textX - 4, e.desc and 0 or 1, e.desc and 16 or 0),
    Position = UDim2.new(0, textX, 0, e.desc and 4 or 0), Parent = o })
  Create.text(optLabel, theme, "body")
  local desc
  if e.desc then
    desc = Create("TextLabel", { Name = "Desc", BackgroundTransparency = 1, Text = e.desc, ZIndex = 1003,
      TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left,
      Size = UDim2.new(1, -textX - 4, 0, 14), Position = UDim2.new(0, textX, 0, 20), Parent = o })
    Create.text(desc, theme, "muted")
  end
  local rowValue = e.value
  o.MouseButton1Click:Connect(function() ctx.onPick(rowValue) end)
  return { btn = o, value = rowValue, opt = e, order = order, labelText = labelText, sel = sel, vis = true,
    hover = bindHover(o, theme), icon = e.icon, check = check, lead = lead, label = optLabel, desc = desc,
    find = searchText(e) }
end

function SelectRows.drop(entry)
  if entry.hover then entry.hover.disconnect() end
  entry.btn:Destroy()
end

-- A kept row: write only what differs from what it shows.
local function update(entry, e, order, theme)
  if entry.order ~= order then entry.btn.LayoutOrder = order; entry.order = order end
  local labelText = e.label or tostring(e.value)
  if entry.labelText ~= labelText then entry.label.Text = labelText; entry.labelText = labelText end
  if entry.desc and entry.opt.desc ~= e.desc then entry.desc.Text = e.desc end
  if entry.lead and entry.icon ~= e.icon then Icons.apply(entry.lead, e.icon, theme.Colors.foreground) end
  entry.icon = e.icon
  entry.opt = e
  entry.find = searchText(e)
end

-- Fill, check and hover rest for the row's selection. Writes nothing when the selection is what
-- the row already shows, unless `force` (a re-skin replays everything).
function SelectRows.tick(entry, sel, theme, force)
  if sel == entry.sel and not force then return end
  entry.btn.BackgroundTransparency = sel and 0 or 1
  -- The hover recipe captured the row's rest transparency when it bound, so a row whose
  -- selection just flipped is re-bound against its new rest (a pointer leaving it would
  -- otherwise clear a fresh selection, or re-tint a row that was just deselected).
  if sel ~= entry.sel then
    if entry.hover then entry.hover.disconnect() end
    entry.hover = bindHover(entry.btn, theme)
    entry.sel = sel
  end
  if sel then Icons.apply(entry.check, "check", theme.Colors.foreground) end
  entry.check.Visible = sel
end

-- Every colour of the row from the live palette, plus its selection (the themer replay).
function SelectRows.repaint(entry, sel, theme)
  entry.btn.BackgroundColor3 = theme.Colors.surface
  SelectRows.tick(entry, sel, theme, true)
  if entry.lead and entry.icon then Icons.apply(entry.lead, entry.icon, theme.Colors.foreground) end
  entry.label.TextColor3 = theme.Colors.foreground
  if entry.desc then entry.desc.TextColor3 = theme.Colors.mutedForeground end
end

-- Bring `rows` and `dividers` (what `list` shows) in line with `normed` (the normalised options).
-- A kept value keeps its row (label, description, icon and order updated), a new value gets a
-- row, a value that is gone loses its row; dividers are reused in order. New rows are ticked by
-- `picked(value)`; kept rows keep their tick for the caller to re-sync. Returns the new rows and
-- dividers, in list order.
function SelectRows.sync(list, rows, dividers, normed, picked, ctx)
  local theme = ctx.theme
  local pool = {}  -- key -> its rows, in list order (two options may share a value)
  for _, entry in ipairs(rows) do
    local k = keyOf(entry.value)
    local q = pool[k]
    if not q then q = {}; pool[k] = q end
    q[#q + 1] = entry
  end
  local outRows, outDivs = {}, {}
  for i, e in ipairs(normed) do
    if e.divider then
      local div = dividers[#outDivs + 1]
      if div then
        if div.LayoutOrder ~= i then div.LayoutOrder = i end
      else
        div = Create("Frame", { Name = "Divider", BackgroundColor3 = theme.Colors.border, BorderSizePixel = 0,
          Size = UDim2.new(1, -8, 0, 1), LayoutOrder = i, ZIndex = 1002, Parent = list })
      end
      outDivs[#outDivs + 1] = div
    else
      local q = pool[keyOf(e.value)]
      local entry = q and table.remove(q, 1)
      if entry and sameShape(entry.opt, e) then
        update(entry, e, i, theme)
      else
        if entry then SelectRows.drop(entry) end
        entry = SelectRows.make(list, e, i, picked(e.value), ctx)
      end
      outRows[#outRows + 1] = entry
    end
  end
  for _, q in pairs(pool) do for _, entry in ipairs(q) do SelectRows.drop(entry) end end
  for k = #outDivs + 1, #dividers do dividers[k]:Destroy() end
  return outRows, outDivs
end

return SelectRows
