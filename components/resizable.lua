-- Deps injected via Init(R). shadcn-style resizable split panes with draggable handles.
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

  -- The GAP between panes is fixed (panes must not drift apart on a phone), but the HANDLE that
  -- sits in it is finger-sized on touch: it overhangs the gap symmetrically, so the Line and Grip
  -- (AnchorPoint 0.5) stay centred on the seam whatever the hit width is.
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
    -- a pane is a card surface like Accordion/Card, so it gets the same 1px border rather than
    -- floating as an unbounded slab of `card` against the panel
    Create.stroke(theme.Colors.border, 1, theme.Stroke.control).Parent = pane
    paneFrames[i] = pane
    local order = 0
    local paneApi = { Frame = pane }
    -- The full host context (not just the theme): controls nested in a pane get Flag persistence,
    -- tab search and LockAll exactly like controls mounted straight on a Tab or an Accordion.
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
    -- the grip grows while the seam is being dragged; a UIScale keeps the pill's corner radius
    -- and its glyph in proportion, which a Size tween on the frame alone would not
    local gripScale = Create("UIScale", { Scale = 1, Parent = grip })
    local gi = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 8, 0, 8),
      Position = UDim2.new(0.5, -4, 0.5, -4), Parent = grip })
    local glyph = horizontal and "grip-vertical" or "grip-horizontal"
    Icons.apply(gi, glyph, theme.Colors[theme.Icon.structural])
    -- structural glyph: rests muted, lifts to foreground while the pointer is on the handle (and
    -- while it is held, which is what a drag looks like to the recipe). The recipe owns
    -- ImageColor3 from here on; reskin() re-derives the current state after SetMode/SetAccent.
    local hover = Recipes.hover(handle, { theme = theme, kind = "text", icon = gi,
      rest = theme.Icon.structural, hover = theme.Icon.structuralActive })
    maid:Give(hover.disconnect)
    local function paintGrip()
      Icons.apply(gi, glyph, theme.Colors[theme.Icon.structural])
      hover.reskin()
    end
    gripPaint[k] = paintGrip
    handles[k] = handle

    -- Drag.bind, not a hand-rolled InputBegan/InputChanged pair: the old handler reacted to EVERY
    -- Touch InputChanged, so a second finger anywhere on screen dragged this seam. Deltas come
    -- from the fractions captured at onBegin (dx/dy are measured from the drag start), so a
    -- dropped frame or a clamped step never accumulates drift.
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
