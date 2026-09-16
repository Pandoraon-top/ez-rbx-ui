-- Deps injected via Init(R).
local Table = {}
local Create, DefaultTheme, Maid, Safe, Recipes
function Table.Init(R) Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Safe = R.Safe; Recipes = R.Recipes end

-- Row geometry (today's literals): 24px rows, Body starts 2px under the header so the 1px
-- HeaderRule sits in that gap; cells inset 4px so header text lines up with body cells.
local ROW_H, BODY_Y, CELL_INSET = 24, 26, 4

function Table.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local cols = opts.Columns or {}

  local root = Create("Frame", { Name = "Table", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, (opts.Height or 120) + BODY_Y), LayoutOrder = opts.LayoutOrder or 0, Parent = opts.Parent })

  -- Body rows answer hover through the FILL kind of the hover recipe: the Row lays its cells out
  -- with a horizontal UIListLayout, so a wash Frame would be laid out as an extra column. `fill`
  -- tweens the Row's own BackgroundTransparency and never writes BackgroundColor3 (theme_test
  -- pins the first row's colour by identity). Handles are dropped with the rows on Clear().
  local rowHovers = {}
  local function dropRowHovers()
    for i = #rowHovers, 1, -1 do rowHovers[i](); rowHovers[i] = nil end
  end

  local function makeRow(parent, cells, header, order)
    local row = Create("Frame", { Name = header and "Header" or "Row",
      BackgroundColor3 = theme.Colors.surface, BackgroundTransparency = header and 1 or 0,
      Size = UDim2.new(1, 0, 0, ROW_H), LayoutOrder = order or 0, Parent = parent,
      Create.corner(header and 0 or theme.Radius.xs),
      Create.listLayout({ Padding = CELL_INSET, FillDirection = Enum.FillDirection.Horizontal }) })
    -- the header sits on the root while body rows sit inside Body's padding: inset it the same
    if header then Create.padding({ left = CELL_INSET, right = CELL_INSET }).Parent = row end
    if not header then
      local hv = Recipes.hover(row, { theme = theme, kind = "fill" })
      rowHovers[#rowHovers + 1] = hv.disconnect
    end
    for i, text in ipairs(cells) do
      local cell = Create.text(Create("TextLabel", { Name = "Cell", BackgroundTransparency = 1, Text = tostring(text),
        TextColor3 = header and theme.Colors.mutedForeground or theme.Colors.foreground,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = row }), theme, "muted")
      -- header keeps the muted size but reads Medium (plan 1.2); nil-safe where Font.fromName is absent
      local face = header and theme.FontFace and theme.FontFace(Enum.FontWeight.Medium)
      if face then cell.FontFace = face end
      Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = cell })
    end
    return row
  end

  makeRow(root, cols, true, 0)
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
  local empty = Recipes.empty(emptyArea, { theme = theme, text = "No rows", icon = "inbox", zIndex = 2 })

  local order = 0
  local api = { Frame = root, Body = body }
  function api.AddRow(cells)
    order = order + 1
    local o = order
    local row
    -- the toggle rides the existing mutate so the row and the block never disagree on screen
    Safe.mutate(function() row = makeRow(body, cells, false, o); empty.SetVisible(false) end)
    return row
  end
  function api.Clear()
    order = 0
    Safe.mutate(function()
      dropRowHovers()
      for _, c in ipairs(body:GetChildren()) do if c.Name == "Row" then c:Destroy() end end
      empty.SetVisible(true)
    end)
  end
  function api.SetData(rows) api.Clear(); for _, r in ipairs(rows or {}) do api.AddRow(r) end end
  function api.Destroy() maid:DoCleanup(); root:Destroy() end

  api.SetData(opts.Rows)
  maid:Give(root)
  maid:Give(dropRowHovers)

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    body.BackgroundColor3 = theme.Colors.surface
    Recipes.scrollbar(body, theme)                 -- scrollbar tint follows the border token
    rule.BackgroundColor3 = theme.Colors.border
    empty.reskin()                                 -- muted icon + label follow the mode
    local header = root:FindFirstChild("Header")
    if header then for _, c in ipairs(header:GetChildren()) do if c.Name == "Cell" then c.TextColor3 = theme.Colors.mutedForeground end end end
    for _, row in ipairs(body:GetChildren()) do
      if row.Name == "Row" then
        row.BackgroundColor3 = theme.Colors.surface
        for _, c in ipairs(row:GetChildren()) do if c.Name == "Cell" then c.TextColor3 = theme.Colors.foreground end end
      end
    end
  end)) end

  return api
end

return Table
