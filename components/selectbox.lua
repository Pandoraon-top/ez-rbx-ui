-- Deps injected via Init(R).
local RunService = game:GetService("RunService")
local SelectBox = {}
local Create, DefaultTheme, Animate, Maid, Icons, Overlay, Flag, Safe, Recipes, Effects, Acrylic, SelectRows

function SelectBox.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Animate = R.Animate; Maid = R.Maid
  Icons = R.Icons; Overlay = R.Overlay; Flag = R.Flag; Safe = R.Safe; Recipes = R.Recipes
  Effects = R.Effects; Acrylic = R.Acrylic; SelectRows = R.SelectRows
end

local CARET_OPEN = 180 -- chevron-down reads as chevron-up while the list is open

-- 3.1 loading skeleton geometry. Uneven widths on purpose: three equal bars read as a progress
-- meter, three ragged ones read as text that has not arrived yet. Kept module-local because
-- theme.Sizes has no skeleton line group yet (reported as a deviation).
local SKELETON_ROWS = { 0.6, 0.8, 0.45 }
local SKELETON_H, SKELETON_GAP = 10, 8
local LOADING_H = #SKELETON_ROWS * SKELETON_H + (#SKELETON_ROWS - 1) * SKELETON_GAP
-- 3.4 dropdown empty state. `search-x` is NOT in core/icons.lua (the atlas builder skips names
-- missing upstream), so the block uses the glyph that actually resolves.
local EMPTY_ICON, EMPTY_TEXT = "search", "No results"
-- ...and the height it needs: one Sizes.icon glyph, a Spacing.gap and one muted line, with a
-- second gap of air so it is not flush against the popover edge. The popover must be at least
-- this tall or ClipsDescendants does not trim the message, it removes it — the same hazard
-- LOADING_H answers for the shimmer.
local function emptyH(t) return t.Sizes.icon + t.Spacing.gap * 2 + t.Font.muted.Size end

local function frostAlpha(theme) return theme.Acrylic.popoverFrost end

-- Popover open/close motion: Animate.popIn's curves and Motion tokens, run against the UI scale
-- the popover rests at (Overlay.scale(), 2.22 -- popIn itself rests at 1). Returns the slide's
-- Position tween, so a resize while the popover is still arriving can stop it (the slide would
-- otherwise land the frame on the spot computed for the old height).
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
  -- Accept both PascalCase (EzUI convention) and lowercase keys, since LoadOptions often
  -- returns data decoded from JSON/HTTP where keys are lowercase.
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
  -- The options, normalised once per SetOptions: every pass below (labels, icon, search shape,
  -- rows) reads this instead of normalising the raw list again.
  local normed = {}
  local function setOptionList(o)
    normed = {}
    for i, raw in ipairs(o or {}) do normed[i] = normOpt(raw) end
  end
  setOptionList(opts.Options)
  local multi = opts.Multi == true
  -- For per-item options the entries are tables ({ Value, Icon, ... }); the stored
  -- value must be the option's value, not the raw option table (else display() would
  -- tostring a table address and selection/Flag would never match).
  local function firstValue() return normed[1] ~= nil and normed[1].value or nil end
  local value = multi and (opts.Default or {}) or (opts.Default ~= nil and opts.Default or firstValue())
  local dropdown
  local shadow -- overlay sibling under the open dropdown; nil while Effect.shadowId is ''
  local ddScale = 1 -- UI scale the open popover was built with (Close must fold back to IT, not to 1)
  local posConn -- repositions the open dropdown when the control scrolls
  local searchFocus -- focus ring of the dropdown search; torn down with the dropdown
  local ddUnreg -- 2.11: themer registration the OPEN popover holds; released in teardown
  -- One entry per option row of the OPEN popover, in list order (components/selectrows.lua).
  local optButtons = {}
  local skeletons = {}  -- 3.1: Effects.skeleton handles of the OPEN loading body; Stop()ped in teardown
  local emptyState      -- 3.4: Recipes.empty block on the OPEN dropdown root; dies with it
  -- The open popover's list, its dividers and the shape it was built for (search box or not, and
  -- height), so SetOptions can update the rows in place instead of building the popover again.
  local ddList, ddDividers, ddSearchable, ddHeight, ddLoading = nil, {}, false, 0, false
  local ddSlide  -- the open popover's entrance slide (a Position tween), while it may still run
  local lastQuery = ""  -- the filter in force on the open popover, lower-cased
  local buildDropdown, rebuild, computePos, refresh, syncSelection, syncRows
  local onChanged = opts.Callback

  local function labelFor(v)
    for _, e in ipairs(normed) do
      if not e.divider and e.value == v then return e.label or tostring(e.value) end
    end
    return tostring(v)
  end

  local function display()
    if multi then
      if #value == 0 then return "None" end
      local shown = {}
      for i = 1, math.min(2, #value) do shown[i] = labelFor(value[i]) end
      local s = table.concat(shown, ", ")
      if #value > 2 then s = s .. " +" .. (#value - 2) end
      return s
    end
    if value == nil then return "Select" end
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
  -- Flip-aware, viewport-clamped dropdown position for the current control bounds. The popover
  -- carries the window UI scale on its own root (2.22), so placePopover is asked about the
  -- ON-SCREEN size (w*scale, h*scale) — otherwise a scaled popover flips and clamps too late.
  function computePos(width, ddH, scale)
    local sz = btn.AbsoluteSize or { X = 140, Y = 38 }
    return Overlay.placePopover(btn.AbsolutePosition, sz, width * (scale or 1), ddH * (scale or 1))
  end

  -- BackgroundTransparency/TextTransparency are written explicitly: they are the rest values the
  -- disabled recipe returns to (DIM below), so the enabled state is stated, not inherited.
  local field = Create("Frame", { Name = "Field", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0, Active = false,
    BackgroundTransparency = 0,
    Size = opts.Text and UDim2.new(0.5, -4, 0, 26) or UDim2.new(1, 0, 0, 26),
    Position = opts.Text and UDim2.new(0.5, 4, 0.5, -13) or UDim2.new(0, 0, 0.5, -13),
    Parent = btn, Create.corner(theme.Radius.sm) })
  local fieldStroke = Create.stroke(theme.Colors.border, 1); fieldStroke.Parent = field
  local valueLabel = Create("TextLabel", { Name = "Value", BackgroundTransparency = 1, Text = display(),
    TextColor3 = theme.Colors.foreground, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,
    -- a long value must end with "…" inside the label, not overflow under the caret (a TextLabel does
    -- NOT clip its own text to its bounds; relayout() keeps the label's width clear of the caret).
    TextTruncate = Enum.TextTruncate.AtEnd,
    Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 8, 0, 0), Parent = field })
  Create.text(valueLabel, theme, "body")

  -- The caret is a structural glyph: it rests at Icon.structural and lifts to structuralActive
  -- while the dropdown is open; disabled always mutes it. Both flags live here so caretColor()
  -- and fieldStrokeColor() re-derive from state alone (the themer closure calls them by name).
  local disabled, open = false, false
  local function caretColor()
    if disabled then return theme.Colors.mutedForeground end
    return theme.Colors[open and theme.Icon.structuralActive or theme.Icon.structural]
  end
  local caret = Create("ImageLabel", { Name = "Caret", BackgroundTransparency = 1,
    Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -20, 0.5, -7), Parent = field })
  Icons.apply(caret, "chevron-down", caretColor())
  -- Field ring while open: the one source of the stroke colour, shared with the themer closure;
  -- the focus recipe owns Thickness (1 <-> Stroke.focusThickness) and is driven by set() since a
  -- Frame has no focus event of its own.
  local function fieldStrokeColor() return open and theme.Colors.ring or theme.Colors.border end
  local fieldFocus = Recipes.focus(fieldStroke, field, fieldStrokeColor, { theme = theme })
  maid:Give(fieldFocus.disconnect)
  local function setOpen(b)
    b = b and true or false
    if open == b then return end
    open = b
    Icons.tint(caret, caretColor())
    -- The glyph turns over instead of swapping to chevron-up: Icons.apply (themer closure,
    -- SetLoading) never writes Rotation, so a re-skin while open keeps the caret turned.
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

  -- Parts the disabled state dims to Opacity.disabled, each with the value it rests at while
  -- enabled (2.8d: Recipes.disabled restores exactly that rest, so re-enabling is lossless).
  local DIM = { { field, "BackgroundTransparency", 0 }, { valueLabel, "TextTransparency", 0 } }
  -- Colours + dim derived from the disabled flag. `animated` = the state change (tweened through
  -- the recipe); instant = the themer closure replay, which must not tween inside a re-skin.
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
  local spin -- Animate.spin handle while loading; Cancel rests the glyph at Rotation 0
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
      -- while loading, hide the (possibly stale) value and show a placeholder instead
      fieldIcon.Visible = false
      clearBtn.Visible = false
      relayout()
      valueLabel.Text = "Loading…"
      return
    end
    local ic = selectedIcon()
    if ic then Icons.apply(fieldIcon, ic, theme.Colors.foreground); fieldIcon.Visible = true
    else fieldIcon.Visible = false end
    clearBtn.Visible = multi and #value > 0
    relayout()
    valueLabel.Text = display()
  end
  -- An open popover ticks its rows too, so a SetValue from the hub (or a config load) never
  -- leaves a stale check on screen.
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
    -- one pass over the options, not one per picked value: a 300-option list with 40 picks
    -- used to normalise 12,000 option tables on every call
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
    -- An open popover keeps its rows, scroll position and search query: only what changed is
    -- written (see syncRows). A loading popover shows the skeleton, which the rebuild redraws.
    Safe.mutate(function()
      refresh()
      if dropdown then
        -- a skeleton popover (built while loading) is rebuilt, never synced: it has no rows
        if loading or ddLoading then rebuild() else syncRows() end
      end
    end)
  end
  function api.SetDisabled(b) setDisabled(b) end
  function api.SetLoading(b) setLoading(b) end

  -- The picked values as a set (one lookup per row instead of a scan of the picks).
  local function pickedSet()
    local set = {}
    local function add(v) if SelectRows.keyOf(v) ~= SelectRows.NOKEY then set[v] = true end end
    if multi then for _, v in ipairs(value) do add(v) end else add(value) end
    return set
  end
  -- Is the row for option value `v` picked? The one rule every painter uses. A valueless option
  -- (an "Any" sentinel) reads as picked while a single select holds nothing.
  local function rowPicked(v, set)
    if v == nil then return not multi and value == nil end
    return set[v] == true
  end

  -- Re-paint every open row from the live palette and the current selection: the open popover's
  -- themer closure (2.11) replays this one loop.
  local function retintRows()
    local set = pickedSet()
    for _, e in ipairs(optButtons) do SelectRows.repaint(e, rowPicked(e.value, set), theme) end
  end

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
      if dropdown then syncSelection() end -- re-tick in place (keeps scroll + search; no OnOpen)
    else
      if opts.AllowNone and value == opt then
        api.SetValue(nil)
      else
        api.SetValue(opt)
      end
      api.Close()
    end
  end

  -- 3.4: the "no results" block answers on row VISIBILITY, not on the option count — a query that
  -- hides every row is exactly what it exists for, and the first row coming back into view hides
  -- it again on the same pass. nil while the dropdown is closed or still loading.
  local function syncEmpty()
    if not emptyState then return end
    for _, e in ipairs(optButtons) do
      if e.vis then emptyState.SetVisible(false); return end
    end
    emptyState.SetVisible(true)
  end

  -- Writes Visible only on rows whose visibility changes: a keystroke, or a SetOptions on a long
  -- list, must not touch every row.
  function api.Filter(query)
    query = (query or ""):lower()
    lastQuery = query
    for _, e in ipairs(optButtons) do
      local vis = query == "" or e.find:find(query, 1, true) ~= nil
      if e.vis ~= vis then e.btn.Visible = vis; e.vis = vis end
    end
    syncEmpty()
  end

  local rowCtx = { theme = theme, onPick = pick }

  -- Tick exactly the rows whose selection changed: the cheap path for a pick, a SetValue and a
  -- SetOptions (retintRows is the full repaint).
  function syncSelection()
    local set = pickedSet()
    for _, e in ipairs(optButtons) do SelectRows.tick(e, rowPicked(e.value, set), theme) end
  end

  -- Search box or not, and height, for the current options. SetOptions on an open popover
  -- resizes it in place when only the height changes, and rebuilds it only when a short list
  -- crosses the search threshold (the search box has to come or go) -- too short to cost anything.
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
    -- 3.1: the loading body is three skeleton lines tall, not one text row — the popover must be
    -- sized for what it actually shows or the shimmer would be clipped by ClipsDescendants.
    -- 3.4: the same floor for the empty block, which the rows cannot pay for — with no options at
    -- all the body would be 0px and the "no results" message would never reach the screen.
    local bodyH = loading and LOADING_H or math.max(#normed * 28, emptyH(theme))
    return searchable, math.min(bodyH + (searchable and 44 or 8), 240)
  end

  -- SetOptions on an open popover: the rows are updated in place, keyed by Value (SelectRows.sync).
  -- The list, its scroll position and the search box are never touched, and the query in force is
  -- applied again so new rows obey it.
  function syncRows()
    local searchable, ddH = popoverShape()
    if searchable ~= ddSearchable then rebuild(); return end
    if ddH ~= ddHeight then
      -- same flip-aware, viewport-clamped placement buildDropdown computed, for the new height;
      -- the entrance slide is stopped first or it would carry the frame back to the old spot
      ddHeight = ddH
      if ddSlide and ddSlide.Cancel then ddSlide:Cancel() end
      ddSlide = nil
      local width = dropdown.Size.X.Offset
      local x, y = computePos(width, ddH, ddScale)
      dropdown.Size = UDim2.new(0, width, 0, ddH)
      dropdown.Position = UDim2.new(0, x, 0, y)
      Effects.place(shadow, x, y, width * ddScale, ddH * ddScale, "popover", theme)
    end
    local set = pickedSet()
    optButtons, ddDividers = SelectRows.sync(ddList, optButtons, ddDividers, normed,
      function(v) return rowPicked(v, set) end, rowCtx)
    syncSelection()
    api.Filter(lastQuery)
  end

  -- `query`: the search text to carry over when the popover is rebuilt (a fresh Open passes none).
  function buildDropdown(query)
    optButtons = {}
    skeletons = {}
    lastQuery = ""
    local searchable, ddH = popoverShape()
    ddSearchable, ddHeight, ddLoading = searchable, ddH, loading
    local sz = btn.AbsoluteSize or { X = 140, Y = 38 }
    local width = math.max(140, sz.X or 140)
    -- The window's UI scale reaches overlay children through Overlay.scale() (2.22): the UIScale
    -- goes on the popover's own root (never the overlay root, whose catcher must stay full-screen).
    local scale = Overlay.scale()
    ddScale = scale
    local x, y, openUp = computePos(width, ddH, scale)
    -- Outer popover container. Active so clicks on its chrome don't fall through to the
    -- overlay catcher (which would close it). The search bar is pinned here (sticky); the
    -- options live in a nested ScrollingFrame so the search stays put while the list scrolls.
    dropdown = Create("Frame", {
      Name = "SelectDropdown", BackgroundColor3 = theme.Colors.card, BorderSizePixel = 0, Active = true,
      Position = UDim2.new(0, x, 0, y),
      Size = UDim2.new(0, width, 0, ddH),
      ClipsDescendants = true, ZIndex = Overlay.Z.popover,
      Create.corner(theme.Radius.md),
      Create("UIScale", { Scale = scale }),
    })
    local ddStroke = Create.stroke(theme.Colors.border, 1, theme.Stroke.floating); ddStroke.Parent = dropdown -- floating surface: opaque hairline (1.5)
    -- Frost: the same material as the window shell, one step lighter. decorate is idempotent, so
    -- it adopts the hairline above (strokeAlpha keeps it opaque) and only adds the ZIndex-0
    -- noise/sheen/glint layers, which stay under the list (ZIndex 1001+).
    Acrylic.decorate(dropdown, theme, {
      transparency = frostAlpha(theme), edge = true, radius = theme.Radius.md, strokeAlpha = theme.Stroke.floating,
    })
    -- Depth: a SIBLING of the popover in the overlay root at the catcher layer (a child would
    -- render above the dropdown's own fill). The popover never moves while open — posConn closes
    -- it as soon as the control scrolls — so one Effects.place before mounting is enough.
    local overlayRoot = Overlay.peek()
    shadow = overlayRoot and Effects.shadow(overlayRoot, theme,
      { name = "SelectDropdownShadow", level = "popover", zIndex = Overlay.Z.catcher }) or nil
    Effects.place(shadow, x, y, width * scale, ddH * scale, "popover", theme)

    -- sticky search box (filters options live) — only for longer lists, or when forced
    -- Hoisted out of the branch so the popover's themer closure below can repaint them.
    local searchBox, searchInput, searchStroke, searchRest
    local searchFocused = false
    local loadingRow = nil
    ddDividers = {}
    local listTop = 4
    if searchable then
      listTop = 34 -- 4 top pad + 26 search + 4 gap
      searchBox = Create("Frame", { Name = "Search", BackgroundColor3 = theme.Colors.surface, BorderSizePixel = 0,
        Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0, 26), ZIndex = 1003, Parent = dropdown,
        Create.corner(theme.Radius.sm), Create.padding({ left = 8, right = 8 }) })
      searchInput = Create("TextBox", { Name = "Input", BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Search…", PlaceholderColor3 = theme.Colors.mutedForeground, TextColor3 = theme.Colors.foreground,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 1003, Size = UDim2.new(1, 0, 1, 0), Parent = searchBox })
      Create.text(searchInput, theme, "muted")
      -- Hairline at Stroke.search (as the sidebar search) that thickens into the ring while typing.
      -- A ring at the hairline's alpha would barely read, so the alpha follows focus as well.
      -- restAlpha is a FUNCTION so a SetMode mid-focus restores the new mode's hairline, and
      -- getColor doubles as the focus latch the themer closure reads back (there is no other
      -- source: the recipe owns the state, not the caller).
      searchRest = function() return theme.modeVal(theme, theme.Stroke.search) end
      searchStroke = Create.stroke(theme.Colors.border, 1, searchRest()); searchStroke.Parent = searchBox
      searchFocus = Recipes.focus(searchStroke, searchInput, function(focused)
        searchFocused = focused
        return focused and theme.Colors.ring or theme.Colors.border
      end, { theme = theme, restAlpha = searchRest })   -- the recipe fades the hairline to opaque while focused
      searchInput:GetPropertyChangedSignal("Text"):Connect(function() Safe.mutate(function() api.Filter(searchInput.Text) end) end)
    end

    -- scrolling list of options/dividers, below the pinned search
    local list = Create("ScrollingFrame", {
      Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0,
      Position = UDim2.new(0, 4, 0, listTop),
      Size = UDim2.new(1, -8, 1, -(listTop + 4)),
      ClipsDescendants = true, ZIndex = 1001,
      AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
      Parent = dropdown,
      Create.listLayout({ Padding = 2 }),
    })
    ddList = list
    Recipes.scrollbar(list, theme) -- 3.7: same pill (thickness, border tint, Scrollbar.alpha) as the table

    if loading then
      -- 3.1: an async LoadOptions reads as content arriving, not as a dead end — three shimmer
      -- lines where the labels will land. The container keeps the name the old text row had
      -- ('Loading'), so every caller that probes the loading state by name still finds it. The
      -- lines are positioned, not laid out: the container carries no UIListLayout of its own.
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
    local picked = pickedSet()
    for i, e in ipairs(normed) do
      if e.divider then
        ddDividers[#ddDividers + 1] = Create("Frame", { Name = "Divider", BackgroundColor3 = theme.Colors.border, BorderSizePixel = 0,
          Size = UDim2.new(1, -8, 0, 1), LayoutOrder = i, ZIndex = 1002, Parent = list })
      else
        optButtons[#optButtons + 1] = SelectRows.make(list, e, i, rowPicked(e.value, picked), rowCtx)
      end
    end
    -- 3.4: parented to the dropdown ROOT, never to the List — the List owns a UIListLayout, so an
    -- Empty child there would be laid out as one more option row. ZIndex above the rows (1002) so
    -- it reads over the (now hidden) list instead of under it.
    emptyState = Recipes.empty(dropdown, { theme = theme, text = EMPTY_TEXT, icon = EMPTY_ICON, zIndex = 1003 })
    -- Recipes.empty hardcodes (1,0,1,0) and carries no position, so on a searchable popover the
    -- centred icon/label stack would sit ON the pinned search field. Pin it over the LIST rect
    -- after the fact — the same placement window.lua gives its sidebar block.
    emptyState.Frame.Position = UDim2.new(0, 4, 0, listTop)
    emptyState.Frame.Size = UDim2.new(1, -8, 1, -(listTop + 4))
    syncEmpty()
    end
    -- close the dropdown when the control scrolls — otherwise the screen-space popover
    -- would either detach from the control or float outside the window once the control
    -- leaves the content viewport (standard <select> behavior). Scrolling inside the
    -- dropdown itself doesn't move the control's AbsolutePosition, so it stays open.
    posConn = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() Safe.mutate(api.Close) end)
    Overlay.mount(dropdown)
    Overlay.trackPopover(api.Close)
    -- 2.11: while it is open the popover holds a themer registration of its OWN. The control's
    -- closure only knows the field; everything built here (frost stack, rim, shadow alpha, search
    -- box, rows) would otherwise keep the palette it was born with until the next open. Paints
    -- instantly -- a re-skin replays the current state, it is not a transition.
    local ddFrame, ddShadow = dropdown, shadow
    ddUnreg = opts.AccentReg and opts.AccentReg(function()
      Acrylic.reskin(ddFrame, theme, { transparency = frostAlpha(theme), edge = true,
        radius = theme.Radius.md, strokeAlpha = theme.Stroke.floating })   -- fill + hairline + rim + frost
      Effects.reskin(ddShadow, theme, "shadow")        -- nil-tolerant: Effect.shadowId is '' by default
      Recipes.scrollbar(list, theme)                   -- 3.7: idempotent, so a re-skin just re-tints
      if searchBox then
        searchBox.BackgroundColor3 = theme.Colors.surface
        searchInput.TextColor3 = theme.Colors.foreground
        searchInput.PlaceholderColor3 = theme.Colors.mutedForeground
        searchStroke.Color = searchFocused and theme.Colors.ring or theme.Colors.border
        searchStroke.Transparency = searchFocused and theme.Stroke.control or searchRest()
      end
      for _, d in ipairs(ddDividers) do d.BackgroundColor3 = theme.Colors.border end
      -- 3.1 skeleton blocks follow the surface token; the shimmer band keeps the mode it was born
      -- with (core/effects.lua has no 'skeleton' kind for Effects.reskin — reported as a deviation),
      -- which is invisible in practice: the band is a 1.1s sweep over a placeholder.
      for _, sk in ipairs(skeletons) do sk.Frame.BackgroundColor3 = theme.Colors.surface end
      if emptyState then emptyState.reskin() end       -- 3.4 muted icon + label
      retintRows()                                     -- rows: fill, check, lead, label, description
    end) or nil
    -- a rebuilt popover keeps the query the player typed (and the filter it drives)
    if searchInput and query and query ~= "" then
      searchInput.Text = query
      api.Filter(query)
    end
    setOpen(true)
    -- Grows out of the field: the final Position is the one written above, so layout code
    -- reading dropdown.Position right after Open still sees the computed spot.
    ddSlide = popOpen(dropdown, theme, openUp and "up" or "down", scale)
  end

  function api.Open()
    if disabled or dropdown then return end
    if opts.OnOpen then opts.OnOpen(api) end
    buildDropdown()
  end

  -- Drop the popover and its connections; the open state (caret tint, field ring) is left to
  -- the caller so a rebuild swaps the list without flickering the field back to rest.
  --
  -- Synchronous for the CALLER: the reference is dropped, the reposition connection cut and the
  -- popover untracked before any motion starts, so a catcher click, a scroll or a second Close
  -- sees no dropdown while the DETACHED frame is still folding away. `instant` (rebuild) skips
  -- the exit entirely — animating a frame that is being replaced would show two popovers.
  local function teardown(instant)
    local dd, sh = dropdown, shadow
    -- 3.1/3.4: both belong to THIS popover. Snapshotting them here (and clearing the fields before
    -- anything can yield) means the themer closure and a second Close see an empty set, never the
    -- frames that are on their way out.
    local sks = skeletons
    dropdown, shadow, skeletons, emptyState = nil, nil, {}, nil
    if posConn then posConn:Disconnect(); posConn = nil end
    -- Released here, BEFORE the `not dd` early return and before any exit motion, so a re-skin
    -- landing mid-fold can never paint the frame that is being destroyed.
    if ddUnreg then ddUnreg(); ddUnreg = nil end
    if searchFocus then searchFocus.disconnect(); searchFocus = nil end
    for _, e in ipairs(optButtons) do if e.hover then e.hover.disconnect() end end
    optButtons, ddList, ddDividers, lastQuery, ddSlide = {}, nil, {}, "", nil
    Overlay.untrackPopover(api.Close)
    local function stopSkeletons() for _, sk in ipairs(sks) do sk.Stop() end end
    if not dd then stopSkeletons(); return end
    local function drop() dd:Destroy(); if sh then sh:Destroy() end end
    -- The shimmer loops must not outlive the popover. On a rebuild the frame is dropped FIRST, so
    -- Stop() finds an orphan and destroys at once instead of spending a fade on a dead branch; on a
    -- real close the fade runs alongside the fold.
    if instant then drop(); stopSkeletons() else stopSkeletons(); popShut(dd, theme, ddScale, drop) end
  end
  function rebuild()
    local query = lastQuery
    if dropdown then teardown(true) end
    buildDropdown(query)
  end
  function api.Close() teardown(); setOpen(false) end

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

  -- Options loader. opts.LoadOptions is a function that returns the options table; it may
  -- yield (HTTP, datastore, task.wait). The field shows its loading state on its own while
  -- the call is pending and clears it once the function returns — no manual SetLoading.
  --
  -- The fetch + GUI apply are deferred to the next RunService.Heartbeat. This gives BOTH
  -- properties we need:
  --   * Non-blocking: runLoader returns immediately, so a yielding LoadOptions never blocks
  --     window construction — the controls created AFTER this one still render right away.
  --   * Capability-safe: the work runs in a RunService signal-handler thread, which (like the
  --     MouseButton1Click/OnOpen handlers) retains the executor capability across the yield.
  --     api.SetOptions -> refresh() mutates GUI under a protected parent (gethui()/CoreGui),
  --     which needs that capability — a task.spawn'd thread loses it ("lacking capability
  --     Plugin"), and running synchronously keeps it but blocks construction.
  -- setLoading(true) runs synchronously (the caller — create/main or OnOpen handler — has
  -- capability) so the spinner shows immediately. A timeout (opts.Timeout, default 60) clears
  -- the spinner if the loader never returns. Call api.Reload() to run again; loadToken
  -- supersedes any earlier in-flight run.
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
    -- Best-effort timeout: clears the spinner if LoadOptions never returns. token-guarded so a
    -- newer load (Reload) or destroy supersedes it; only clears the spinner, never the result.
    local timeout = type(opts.Timeout) == "number" and opts.Timeout or 60
    task.delay(timeout, function()
      if token ~= loadToken then return end
      if loading then setLoading(false) end
    end)
  end
  function api.Reload() runLoader() end
  maid:Give(function() loadToken = loadToken + 1 end) -- drop pending loads on destroy
  if opts.LoadOptions then runLoader() end

  return api
end

return SelectBox
