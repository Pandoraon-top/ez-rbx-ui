-- Deps injected via Init(R).
local TextBox = {}
local Create, DefaultTheme, Maid, Icons, Flag, Animate, Safe, Recipes

function TextBox.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Icons = R.Icons; Flag = R.Flag; Animate = R.Animate; Safe = R.Safe
  Recipes = R.Recipes
end

-- compact inline-button palette (mirrors components/button.lua)
local function btnPalette(theme, variant)
  if variant == "destructive" then return theme.Colors.destructive, theme.Colors.primaryForeground end
  if variant == "secondary" then return theme.Colors.surface, theme.Colors.foreground end
  if variant == "outline" then return theme.Colors.card, theme.Colors.foreground, theme.Colors.border end
  if variant == "ghost" then return theme.Colors.card, theme.Colors.foreground end
  return theme.Colors.primary, theme.Colors.primaryForeground -- default
end

-- Inline glyph tints by ROLE, resolved through theme.Icon at paint time so SetMode/SetAccent
-- re-tint by name: structural (muted) for the affordances, accent for the actions, success for
-- the copy confirmation.
local function roleColor(theme, role)
  if role == "muted" then return theme.Colors[theme.Icon.structural] end
  if role == "success" then return theme.Colors.success end
  return theme.Colors[theme.Icon.accent]
end

-- Extra row height while an error line is shown (the Error label's own 16 + 2 gap).
local ERROR_H = 18

function TextBox.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local hasLabel = opts.Text ~= nil and opts.Text ~= ""
  local hasDesc = opts.Description ~= nil and opts.Description ~= ""
  local fullWidth = (opts.FullWidth and hasLabel) and true or false

  -- ---- geometry -------------------------------------------------------------
  -- FullWidth boxes are taller (36) with breathing room above and below the box;
  -- compact boxes stay 30 and vertically centered in their fixed row.
  local boxH = fullWidth and 36 or 30
  local boxX, boxW, boxTop, baseH, titleTop, descTop
  if not hasLabel then
    boxX, boxW, boxTop, baseH = UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, boxH), 0, boxH
  elseif fullWidth then
    -- top margin so the label doesn't hug the row's top edge
    titleTop = 12
    descTop = titleTop + 22
    boxTop = titleTop + (hasDesc and 44 or 26)
    boxX, boxW, baseH = UDim2.new(0, 0, 0, boxTop), UDim2.new(1, 0, 0, boxH), boxTop + boxH + 12
  else
    baseH = hasDesc and 56 or 46
    boxTop = math.floor((baseH - boxH) / 2)
    boxX, boxW = UDim2.new(0.5, 4, 0, boxTop), UDim2.new(0.5, -4, 0, boxH)
  end

  -- ---- shared state ---------------------------------------------------------
  local real = opts.Default or ""
  local masked = opts.Password and true or false
  local revealed = false
  local suppress = false
  local state = { focused = false, invalid = false }
  -- SetEnabled/SetDisabled block USER input only (clicks, editing): apply()/Flag.bind restores
  -- keep updating value and visuals while disabled (plan 2.8 contract a).
  local enabled = true
  local dimParts, dimRest = {}, {}     -- inline glyphs that dim while disabled + their rest alphas
  local themed = {}                    -- recolor closures, replayed on accent change
  local function reTheme() for _, fn in ipairs(themed) do fn() end end
  local api = {}                       -- returned control; buttons capture it for the ctl arg

  -- ---- root + label ---------------------------------------------------------
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

  -- ---- box (horizontal flex row) -------------------------------------------
  local box = Create("Frame", {
    Name = "Box", BackgroundColor3 = theme.Colors.background, BorderSizePixel = 0,
    -- clip so a long value doesn't overflow past the field edge (a TextBox doesn't clip its own text;
    -- while editing, Roblox scrolls the text to keep the caret visible inside the clipped box).
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

  -- ---- input (flex-fills) ---------------------------------------------------
  local input = Create("TextBox", {
    Name = "Input", BackgroundTransparency = 1, Text = real,
    PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = theme.Colors.mutedForeground,
    TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center, ClearTextOnFocus = false,
    -- LayoutOrder 3 sits between leading addons (icon=1, prefix=2) and all trailing
    -- addons (suffix=4, trailing icon=5, buttons=6+, eye/clear/copy, spinner). The
    -- UIFlexItem makes it grow to fill the gap, pushing trailing addons to the right.
    TextEditable = not opts.Copyable, LayoutOrder = 3, Size = UDim2.new(0, 0, 1, 0), Parent = box,
    Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
  })
  Create.text(input, theme, "body")
  themed[#themed + 1] = function()
    -- re-derived from `enabled` too, so a SetMode while disabled does not repaint the value as live
    input.TextColor3 = enabled and theme.Colors.foreground or theme.Colors.mutedForeground
    input.PlaceholderColor3 = theme.Colors.mutedForeground
  end

  -- ---- value machinery ------------------------------------------------------
  local function display() return (masked and not revealed) and string.rep("*", #real) or real end
  -- Only reassign Input.Text when the rendered value actually differs from what's
  -- already shown. Reassigning on every keystroke resets the caret and makes it
  -- flicker/jump; with this guard, ordinary (unmasked) typing never touches Text.
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

  -- ---- inline icon-button helper -------------------------------------------
  -- An ImageButton renders its Image across its whole Size, so the button IS the glyph: there is
  -- no room for a hover wash behind a 16px icon and no inner content to scale. Hover therefore
  -- lifts the tint (structural -> structuralActive, the tab's grammar) and press dips the
  -- button's own UIScale. Returns the button plus setGlyph(icon, role) so a transient swap
  -- (copy -> check) has ONE source the themer closure re-derives from.
  local function mkIconButton(name, icon, colorRole, order, onClick)
    local glyph, role = icon, colorRole
    local btn = Create("ImageButton", { Name = name, BackgroundTransparency = 1,
      Size = UDim2.new(0, theme.Sizes.icon, 0, theme.Sizes.icon), LayoutOrder = order, Parent = box })
    Icons.apply(btn, glyph, roleColor(theme, role))
    dimParts[#dimParts + 1] = btn
    -- Only a structural glyph has somewhere to lift TO; an accent one already rests at the
    -- brightest token, and the copy button owns its tint for the whole check window.
    local hover
    if colorRole == "muted" then
      hover = Recipes.hover(btn, { theme = theme, kind = "text", icon = btn,
        rest = theme.Icon.structural, hover = theme.Icon.structuralActive })
      maid:Give(hover.disconnect)
    end
    maid:Give(Recipes.press(btn, btn, { theme = theme }).disconnect)
    themed[#themed + 1] = function()
      Icons.apply(btn, glyph, roleColor(theme, role))
      if hover then hover.reskin() end   -- a pointer already over the button keeps its lifted tint
    end
    if onClick then maid:Give(btn.MouseButton1Click:Connect(function() if enabled then onClick() end end)) end
    return btn, function(g, r)
      glyph, role = g or glyph, r or role
      Icons.apply(btn, glyph, roleColor(theme, role))
    end
  end

  -- @addons (Tasks 2,3,6,7 insert addon builders + their option blocks here)
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
    -- shadcn's hover:bg-primary/90 in Roblox terms: the fill itself dips, because a wash Frame
    -- child would render above the button's own Text. Rest is the 0 written above, so the recipe
    -- captures the right value to return to.
    maid:Give(Recipes.hover(btn, { theme = theme, host = btn, kind = "fill",
      hoverAlpha = theme.Opacity.hoverFill, pressAlpha = theme.Opacity.pressFill }).disconnect)
    -- No scale host: the button IS an item of the Box's horizontal UIListLayout, so a UIScale on
    -- it changes its AbsoluteSize and reflows every sibling on each press. The fill dip above
    -- carries the press on its own (the toast Action answers the same way).
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
    -- Text-changed fires on an engine thread (no GUI capability on strict executors); clear.Visible
    -- is a protected write -> marshal through Safe.mutate (inline when capable, e.g. the sync() below).
    -- Visible still carries the empty case (a hidden flex item takes no width in the row); the
    -- glyph fades either way, and the first sync lands instantly so a fresh build spends no tween.
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

  local spinner, spin -- spin: Animate.spin handle while loading; Cancel rests the glyph at Rotation 0
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
      Animate.pop(eye, "fast")   -- the reveal is a state change, so the glyph pops as it swaps
      render()
    end)
  end

  if opts.Copyable then
    -- Copy confirms in place: the glyph becomes a success 'check' for Motion.copyRevert seconds.
    -- The revert runs on a task.delay thread (no GUI capability on strict executors) -> Safe.mutate.
    -- A generation counter, not task.cancel (which throws on an already finished thread), makes a
    -- second click simply own the window.
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

  -- @states (Tasks 4,5 insert focus-ring / validation wiring here)
  -- The focus recipe binds Focused/FocusLost and tweens Thickness 1 <-> Stroke.focusThickness;
  -- the colour still comes from strokeColor() so invalid > focused > border holds everywhere.
  -- The flag is recorded inside the colour callback rather than in a second handler on the
  -- same signals, so it is current whatever order Roblox runs the connections in.
  local focus = Recipes.focus(stroke, input, function(focused)
    state.focused = focused
    return strokeColor()
  end, { theme = theme })
  maid:Give(focus.disconnect)
  -- Plan 2.8: the surface reads disabled (Box + every inline glyph at Opacity.disabled, input
  -- non-editable) and user input is guarded, while SetLocked (the host's scrim) stays an
  -- independent flag that neither sets nor clears this one. Recipes.disabled keeps each part's
  -- rest, so re-enabling restores the value it had -- including a Clear glyph left faded out.
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
  -- Rejection shake: Motion.shake (amp / steps / step) alternating on the Box's OWN X offset,
  -- Sine both ways, with a closing step back to the exact starting Position table so the field
  -- can never drift off its grid. Motion off = no movement at all (an instant "end state" for a
  -- pure back-and-forth is simply staying put). Re-entrancy is refused so a second SetInvalid
  -- mid-shake cannot capture a displaced rest as the new home.
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
      -- Visible + stroke land synchronously (callers read them straight after); only the fade,
      -- the row height and the shake are animated.
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
      -- Visible flips inside Completed (an engine thread -> Safe.mutate). With motion off, and
      -- under the synchronous test mock, that lands in the same call, so a reader right after
      -- SetValid still sees false.
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

  -- ---- public api -----------------------------------------------------------
  api.Frame = root
  api.GetText = function() return real end
  api.SetText = function(s) commit(tostring(s)); runValidate(); if opts.Callback then opts.Callback(real, api) end end
  api.Focus = function() input:CaptureFocus() end
  api.Clear = function() commit("") end
  -- @api-extra (Tasks 4,5,6 add SetInvalid/SetValid/SetLoading/SetDisabled here)
  api.SetDisabled = function(b) setEnabled(not b) end
  api.SetEnabled = function(b) setEnabled(b) end
  api.SetInvalid = function(msg) setInvalid(msg) end
  api.SetValid = function() setValid() end
  api.SetLoading = function(b) setLoading(b) end
  api.Destroy = function() maid:DoCleanup() end
  return api
end

return TextBox
