-- Deps injected via Init(R) (bundler cannot rewrite require() inside embedded modules).
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

  -- Label + icon share one tint role: structural (muted) at rest, structuralActive (foreground)
  -- once selected. Resolved by token NAME at paint time so SetMode/SetAccent re-tint by name.
  local function tintRole() return selected and theme.Icon.structuralActive or theme.Icon.structural end
  local function tint() return theme.Colors[tintRole()] end

  -- sidebar button
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

  -- Hover lifts label + icon to the active tint. The recipe resolves rest/hover by token name at
  -- paint time, so `rest` is re-pointed on Select/Deselect: a pointer leaving the SELECTED tab
  -- then paints it back to foreground, not muted. Skipped by the recipe on touch-only devices.
  local hoverOpts = { theme = theme, kind = "text", label = label, icon = icon,
    rest = tintRole(), hover = theme.Icon.structuralActive }
  local hover = Recipes.hover(button, hoverOpts)
  maid:Give(hover.disconnect)

  -- Fill + label + icon for the current `selected`. animated = Select/Deselect (handler thread:
  -- tweened, symmetric both ways); instant = themer closure (no tween inside a reskin), which
  -- also re-reads the fill colour for UNselected tabs so the hover wash never shows a stale mode.
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
      hover.reskin() -- a pointer currently over the tab keeps its lifted tint
    end
  end

  -- content (plain Frame + slide transition; NOT a CanvasGroup, so a focused TextBox's
  -- caret/selection renders — CanvasGroups composite children to a buffer that omits
  -- the caret overlay, which made text cursors invisible/non-blinking).
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

  -- Drive the parent ScrollingFrame's CanvasSize explicitly from this tab's content height.
  -- AutomaticCanvasSize is unreliable here because the CanvasGroup starts hidden (measured 0).
  local contentLayout = content:FindFirstChildOfClass("UIListLayout")
  local contentPad = theme.Spacing.pad
  -- carousel travel distance = the visible panel height (so a switch reads as a full page swap);
  -- fall back to a sensible constant before the scroll frame has an AbsoluteSize (first paint / headless)
  local function panelH()
    local sf = content.Parent
    local s = sf and sf.AbsoluteSize
    return (s and s.Y and s.Y > 0 and s.Y) or 360
  end
  local function syncCanvas()
    -- Driven by the AbsoluteContentSize property-changed signal below (engine thread, no GUI
    -- capability on strict executors) AND by Select() (capability). Reading AbsoluteContentSize and
    -- writing CanvasSize are both protected -> marshal through Safe.mutate (inline when capable).
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

  -- vertical carousel: the incoming page slides in from sign*panelH, the outgoing exits to
  -- -sign*panelH, both in sync and on the SAME curve (EASING.smooth) — so the two pages move as
  -- one filmstrip, never colliding or drifting apart mid-slide.
  -- dir +1 = navigating to a later tab (filmstrip scrolls up); -1 = earlier tab (scrolls down).
  function api:Select(dir)
    selected = true
    local sign = (dir == -1) and -1 or 1
    content.Position = UDim2.new(0, 0, 0, sign * panelH())
    content.Visible = true
    if content.Parent then content.Parent.CanvasPosition = Vector2.new(0, 0) end
    syncCanvas()
    Animate.to(content, "slow", { Position = UDim2.new(0, 0, 0, 0) }, Animate.EASING.smooth)
    paintState(true)
  end

  function api:Deselect(dir)
    if not selected then content.Visible = false; return end  -- already inactive: nothing to animate out
    selected = false
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

  -- AddLabel/AddParagraph/AddSection/AddSeparator/AddButton/AddToggle/AddTextBox/
  -- AddNumberBox/AddSelectBox are provided by the Host mixin (below).
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
  function api:SetTitle(s) Safe.mutate(function() label.Text = s end) end

  -- Wash: the button's own fill at Opacity.tabHover while the pointer is over an UNselected tab
  -- (the selected one is already solid). Bound only where a pointer exists — touch fires
  -- Enter/Down/Up with no Leave, so a tap would leave the wash stuck — and a touch release falls
  -- back to rest for the same reason (mirrors Recipes.hover).
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
