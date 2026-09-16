-- Deps injected via Init(R). A rich content card: optional banner image, title,
-- body paragraph, and an optional row of action buttons. Built from primitives.
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
    -- Reserve the 80px slot now and let the image land when it resolves: asset ids call back
    -- synchronously, URLs download off-thread (game:HttpGet yields) so construction never blocks.
    -- The callback may run on a non-privileged thread, hence Safe.mutate.
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
      -- AutoWidth: the label sizes the button (a forced 96px used to clip longer captions). The
      -- button owns its own reskin closure through AccentReg, so the whole control (not just its
      -- Frame) goes to the maid to unregister it on Destroy.
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
