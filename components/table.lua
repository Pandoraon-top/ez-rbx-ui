-- Deps injected via Init(R).
local Table = {}
local Create, DefaultTheme, Maid, Safe, Recipes
function Table.Init(R) Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Safe = R.Safe; Recipes = R.Recipes end

-- Row geometry (today's literals): 24px rows, Body starts 2px under the header so the 1px
-- HeaderRule sits in that gap; cells inset 4px so header text lines up with body cells.
local ROW_H, BODY_Y, CELL_INSET = 24, 26, 4
-- An editable cell keeps 2px clear above and below inside its 24px row, so the focus ring
-- (Stroke.focusThickness, drawn outside the box) never touches the next row; text insets 6px.
local EDIT_INSET_Y, EDIT_PAD = 2, 6

-- Columns are plain header strings (the original shape) or { Text, Editable, Placeholder, Width }.
-- Width is a flex weight, so it has to be a positive number; anything else fails at build time
-- rather than as a silently squashed column.
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

-- A row is a plain array of cells (the original shape) or { Key = k, Cells = { ... } }; a key
-- passed beside a { Cells } table without its own Key still counts.
local function rowShape(r, key)
  if type(r) == "table" and r.Cells ~= nil then
    if r.Key ~= nil then return r.Cells, r.Key end
    return r.Cells, key
  end
  return r or {}, key
end

-- No Width keeps today's Fill (an effective 1:1 grow/shrink); a Width switches the item to Custom
-- with that weight both ways. Every cell starts from a zero-width basis, so the free space splits
-- in exactly these ratios and the header and the body columns stay aligned.
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
  -- a row shorter than the columns still gets every editable cell, so a missing value can be typed
  local minCells = 0
  for i, col in ipairs(cols) do if col.Editable then minCells = i end end
  local enabled = not opts.Disabled

  local root = Create("Frame", { Name = "Table", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, (opts.Height or 120) + BODY_Y), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent })

  -- Row records, the Lua side of what is on screen: { key, frame, drops, dead, cells = { [col] =
  -- cell } }. A cell's `value` is its committed text, kept outside Safe.mutate so GetCell answers
  -- even while the GUI write is still queued; the build and SetCell both read it when they run.
  -- Safe.mutate decides per call whether to run now or on the next Heartbeat, so a row queued from
  -- a spawned thread can still be pending when a click clears the table. Clear therefore marks
  -- the records it drops `dead` at once, a pending build of a dead row does nothing, and a queued
  -- Clear only ever tears down the records it was given -- never a row added after it.
  local rows, byKey = {}, {}
  -- Let go of a cell being edited: on a phone the keyboard would otherwise stay up over a box that
  -- is gone or locked. (ReleaseFocus is a member in Roblox; the headless mock only has it stubbed.)
  local function releaseFocused(record)
    for _, c in ipairs(record.cells) do
      if c.focused and c.inst and c.inst.ReleaseFocus then c.inst:ReleaseFocus() end
    end
  end
  -- Disconnect first, so the release cannot fire a commit, then release and destroy.
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
    -- header keeps the muted size but reads Medium (plan 1.2); nil-safe where Font.fromName is absent
    local face = header and theme.FontFace and theme.FontFace(Enum.FontWeight.Medium)
    if face then cell.FontFace = face end
    flexItem(col, cell)
    return cell
  end

  -- OnEdit decides what a commit leaves behind: false puts the old text back, a string (or a
  -- number) replaces the typed text, nil keeps it. An OnEdit that throws reverts too, and says why.
  local function commit(record, col, c)
    local typed, old = c.inst.Text, c.value
    if typed == old then return end
    -- an edit still open when the table was disabled is dropped: a lock means nothing lands
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

  -- An editable cell wears the TextBox field's look (background fill, border stroke, the focus
  -- ring) at the table's row scale. The TextBox sits under a transparent Hit button: a touch that
  -- starts on a TextBox can be taken by the box instead of the Body scroll, while a button inside
  -- a ScrollingFrame lets a drag scroll and only a tap click. The tap then focuses the box, and the
  -- Hit steps aside while editing so a click inside the text still places the caret.
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
    -- the negative inset cancels the cell's UIPadding so the Hit (and the wash) cover the whole box
    local hit = Create("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
      Size = UDim2.new(1, 2 * EDIT_PAD, 1, 0), Position = UDim2.new(0, -EDIT_PAD, 0, 0), ZIndex = 2,
      Visible = true, Parent = frame })
    c.inst, c.frame = input, frame

    local function strokeColor() return c.focused and theme.Colors.ring or theme.Colors.border end
    -- the flag is recorded in the colour callback (as the TextBox does), so it is current whatever
    -- order Roblox runs the Focused/FocusLost connections in
    local focus = Recipes.focus(stroke, input, function(f) c.focused = f; return strokeColor() end, { theme = theme })
    -- MouseEnter fires on the cell even under the Hit button, so the cell itself is the hover source
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
  -- the header sits on the root while body rows sit inside Body's padding: inset it the same
  Create.padding({ left = CELL_INSET, right = CELL_INSET }).Parent = header
  for i, col in ipairs(cols) do
    local cell = makeLabelCell(header, col.Text, i, col, true)
    -- an editable column's heading starts where its value text does, inside the field's padding
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

  -- Empty state (3.4): the block must NOT live inside Body. Body has a UIListLayout (a Frame
  -- parented there becomes a row) and AutomaticCanvasSize (a full-height child plus Body's own
  -- padding would grow the canvas past the window and raise a scrollbar over an empty table), and
  -- Recipes.empty needs a layout-free parent that already has the shape of the area to fill. So it
  -- gets its own hit-through holder on the root, laid exactly over the Body rect with a higher
  -- ZIndex -- under ZIndexBehavior.Sibling that puts it above Body and everything inside it.
  local emptyArea = Create("Frame", { Name = "EmptyArea", BackgroundTransparency = 1, Active = false,
    Position = UDim2.new(0, 0, 0, BODY_Y), Size = UDim2.new(1, 0, 1, -BODY_Y), ZIndex = 2, Parent = root })
  local words = theme.Strings or DefaultTheme.Strings   -- CreateWindow { Strings } (NoRows)
  local empty = Recipes.empty(emptyArea, { theme = theme, text = words.NoRows, icon = "inbox", zIndex = 2 })

  -- Body rows answer hover through the FILL kind of the hover recipe: the Row lays its cells out
  -- with a horizontal UIListLayout, so a wash Frame would be laid out as an extra column. `fill`
  -- tweens the Row's own BackgroundTransparency and never writes BackgroundColor3 (theme_test
  -- pins the first row's colour by identity).
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
  -- AddRow(cells, key) or AddRow({ Key = k, Cells = cells }). A row without a key is keyed by its
  -- 1-based position, which restarts after Clear()/SetData().
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
    -- the toggle rides the existing mutate so the row and the block never disagree on screen
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
      -- rows still in `rows` here were added after this Clear; a pending one hides the block itself
      if #rows == 0 then empty.SetVisible(true) end
    end)
  end
  function api.SetData(data) api.Clear(); for _, r in ipairs(data or {}) do api.AddRow(r) end end
  -- SetCell writes a cell's text from code; it never calls OnEdit. False when there is no such cell.
  function api.SetCell(key, col, text)
    local record = byKey[key]
    local c = record and record.cells[col]
    if not c then return false end
    c.value = text == nil and "" or tostring(text)
    Safe.mutate(function() if c.inst then c.inst.Text = c.value end end)
    return true
  end
  -- The committed text (what OnEdit last accepted, or what SetCell wrote); nil for no such cell.
  function api.GetCell(key, col)
    local record = byKey[key]
    local c = record and record.cells[col]
    return c and c.value
  end
  -- Blocks editing only: SetCell, SetData and a reskin still apply while disabled.
  function api.SetEnabled(b)
    b = b and true or false
    if enabled == b then return end
    enabled = b
    Safe.mutate(function()
      for _, record in ipairs(rows) do
        -- a late FocusLost from this release finds the table disabled and reverts (see commit)
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
    Recipes.scrollbar(body, theme)                 -- scrollbar tint follows the border token
    rule.BackgroundColor3 = theme.Colors.border
    empty.reskin()                                 -- muted icon + label follow the mode
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
