-- Deps injected via Init(R).
local Keybind = {}
local Create, DefaultTheme, Maid, Flag, Safe, Recipes, Animate
local UserInputService = game:GetService("UserInputService")
function Keybind.Init(R)
  Create = R.Create; DefaultTheme = R.Theme; Maid = R.Maid; Flag = R.Flag; Safe = R.Safe; Recipes = R.Recipes
  Animate = R.Animate
end

-- Prompt shown on the chip while it waits for a key (a kbd chip has no placeholder of its own).
local LISTEN_TEXT = "Press a key"

-- Listening pulse alphas + period. theme.Stroke.pulse = { low, high } and theme.Motion.pulse are
-- the tokens these belong in (reported as a deviation); until core/theme.lua carries them this
-- The listening chip breathes between Stroke.pulse.low and .high over Motion.pulse.
local function pulseTok(theme, k)
  if k == "period" then return theme.Motion.pulse end
  return theme.Stroke.pulse[k]
end

-- Escape cancels listening. Resolved ONCE through a pcall (indexing an absent member throws in
-- Roblox) so an exotic client degrades to nil instead of erroring on every keypress; the nil
-- guard at the comparison is what stops an InputBegan with no KeyCode from reading as Escape.
local ESCAPE = (function()
  local ok, kc = pcall(function() return Enum.KeyCode.Escape end)
  if ok then return kc end
  return nil
end)()

-- A real Enum.KeyCode is an EnumItem (userdata), NOT a table — so type(k)=="table"
-- is false in Roblox and the key would always read as "Unknown". Read .Name directly
-- (works for EnumItem userdata, the mock's enum tables, and plain strings).
local function keyName(k)
  if type(k) == "string" then return k end
  if k ~= nil then
    local ok, name = pcall(function() return k.Name end)
    if ok and type(name) == "string" then return name end
  end
  return "Unknown"
end

-- Indexing Enum.KeyCode with an invalid/free-form string THROWS in real Roblox
-- ("X is not a valid member of Enum.KeyCode") — and this runs on every keypress.
-- Resolve once through a pcall so a bad name degrades to Unknown instead of erroring.
local function toKeyCode(name)
  local ok, kc = pcall(function() return Enum.KeyCode[name] end)
  if ok and kc then return kc end
  return Enum.KeyCode.Unknown
end

function Keybind.new(opts)
  opts = opts or {}
  local theme = opts.Theme or DefaultTheme
  local maid = Maid.new()
  local listening = false
  local enabled = true                 -- SetEnabled: blocks the click that arms listening
  local keyCode = "Unknown"
  local onPressed

  local hasDesc = opts.Description ~= nil and opts.Description ~= ""
  local btn = Create("TextButton", { Name = "Keybind", AutoButtonColor = false, Text = "",
    BackgroundColor3 = theme.Colors.surface, Size = UDim2.new(1, 0, 0, hasDesc and 50 or 34), LayoutOrder = opts.LayoutOrder or 0,
    Parent = opts.Parent, Create.corner(theme.Radius.md), Create.padding({ left = theme.Spacing.inputX, right = theme.Spacing.inputX }) })
  Create.text(Create("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = opts.Text or "Keybind",
    TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = hasDesc and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    Position = UDim2.new(0, 0, 0, hasDesc and 8 or 0), Size = UDim2.new(1, -80, hasDesc and 0 or 1, hasDesc and 18 or 0), Parent = btn }),
    theme, "label")
  if hasDesc then
    Create.text(Create("TextLabel", { Name = "Description", BackgroundTransparency = 1, Text = opts.Description,
      TextColor3 = theme.Colors.mutedForeground, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
      TextYAlignment = Enum.TextYAlignment.Top,
      Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -80, 0, 18), Parent = btn }), theme, "muted")
  end
  -- kbd-style chip: a recessed `background` fill with a border stroke, sized to its own text
  -- (AutomaticSize.X + padding) but never narrower than a comfortable target. AnchorPoint (1,0.5)
  -- pins its RIGHT edge to the row, so a long key name grows leftwards instead of overflowing.
  local keyBox = Create.text(Create("TextLabel", { Name = "Key", BackgroundColor3 = theme.Colors.background,
    Text = "...", TextColor3 = theme.Colors.foreground, TextXAlignment = Enum.TextXAlignment.Center,
    AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5),
    Size = UDim2.new(0, 0, 0, theme.Sizes.chip), Position = UDim2.new(1, 0, 0.5, 0), Parent = btn,
    Create.corner(theme.Radius.sm),
    Create.padding({ left = theme.Spacing.gap, right = theme.Spacing.gap }),
    Create("UISizeConstraint", { MinSize = Vector2.new(theme.Sizes.touchHit, theme.Sizes.chip) }) }),
    theme, "muted")
  -- The chip's only UIStroke doubles as its focus ring (1.7): border/1 at rest, ring at
  -- Stroke.focusThickness while listening. A TextLabel has no Focused event, so the recipe is
  -- driven through set(); chipColor() is the single source of the colour for the themer too.
  local chipStroke = Create.stroke(theme.Colors.border, 1); chipStroke.Parent = keyBox
  local function chipColor(on) return on and theme.Colors.ring or theme.Colors.border end
  local ring = Recipes.focus(chipStroke, keyBox, chipColor, { theme = theme })
  maid:Give(ring.disconnect)
  -- Row hover + press (2.7): the wash cancels the row's UIPadding so it covers the whole row, and
  -- the press scale lives on the CHIP -- a UIScale on the row itself would reflow its siblings.
  local hover = Recipes.hover(btn, { theme = theme, host = btn, corner = theme.Radius.md,
    inset = { x = theme.Spacing.inputX, y = 0 } })
  maid:Give(hover.disconnect)
  maid:Give(Recipes.press(btn, keyBox, { theme = theme }).disconnect)

  -- One source for the chip's text and tint, re-derived from `listening` (so the themer closure
  -- and a mid-listen SetMode both paint the state that is actually current).
  local function chipText() return listening and LISTEN_TEXT or keyCode end
  local function chipTint() return listening and theme.Colors.mutedForeground or theme.Colors.foreground end
  local function paintChip() keyBox.Text = chipText(); keyBox.TextColor3 = chipTint() end

  -- While listening the stroke breathes between two alphas; the handle is { Cancel }, so it
  -- reaches the maid wrapped in a function. Reduced motion skips the loop entirely (the ring
  -- thickness alone says "listening") rather than parking the stroke at the low alpha.
  local pulse
  local function stopPulse()
    if pulse then pulse.Cancel(); pulse = nil end
    chipStroke.Transparency = theme.Stroke.control
  end
  local function startPulse()
    stopPulse()
    if not Animate.isEnabled() then return end
    chipStroke.Transparency = pulseTok(theme, "low")
    pulse = Animate.pulse(chipStroke, pulseTok(theme, "period"),
      { Transparency = pulseTok(theme, "high") }, Enum.EasingStyle.Sine)
  end
  maid:Give(stopPulse)

  -- InputBegan arrives from UserInputService, so the stroke write rides Safe.mutate like the text.
  -- ring.set() runs LAST so the focus tween is the one a caller reads back as the latest.
  local function setListening(on)
    listening = on and true or false
    Safe.mutate(function()
      paintChip()
      if listening then startPulse() else stopPulse() end
      ring.set(listening)
    end)
  end

  -- Capture: the chip pops and the stroke flashes accent -> border, so a rebind registers even
  -- though the ring is leaving at the same moment.
  -- MUST run BEFORE setListening(false): two tweens on one UIStroke that share a property make
  -- Roblox cancel the older one WHOLE, so if this played last it would kill the focus recipe's
  -- {Thickness, Color} tween and strand the chip at Stroke.focusThickness forever. Played first,
  -- it writes the accent synchronously and the ring's own tween cancels IT instead -- picking the
  -- live accent Color up as its start value, so the flash is still seen and Thickness lands at 1.
  local function flashCapture()
    Safe.mutate(function()
      Animate.pop(keyBox, "fast")
      chipStroke.Color = theme.Colors.primary
      Animate.to(chipStroke, "base", { Color = chipColor(false), Transparency = theme.Stroke.control })
    end)
  end

  local function apply(name)
    keyCode = keyName(name)
    Safe.mutate(paintChip)
  end
  local commit = Flag.bind(opts, keyName(opts.Default or "Unknown"), apply)

  -- Rebind the key and notify via OnChanged. Use this (not opts.Callback) to react to
  -- the user *choosing a different key* — e.g. driving Window:SetToggleKey so the window's
  -- built-in toggle handler stays the single source of truth instead of adding a second one.
  local function setKey(k)
    commit(keyName(k))
    if opts.OnChanged then opts.OnChanged(toKeyCode(keyCode)) end
  end

  -- SetEnabled dims the chip and blocks the click that starts listening; SetLocked (the host's
  -- scrim) stays independent. Disabling mid-listen disarms it instead of leaving the row armed.
  local function setEnabled(b)
    b = b and true or false
    if enabled == b then return end
    enabled = b
    if not b and listening then setListening(false) end
    Safe.mutate(function()
      Recipes.disabled({ { keyBox, "BackgroundTransparency", 0 }, { keyBox, "TextTransparency", 0 } }, not b, theme)
    end)
  end
  if opts.Disabled then setEnabled(false) end

  local api = { Frame = btn }
  function api.GetKey() return toKeyCode(keyCode) end
  function api.SetKey(k) setKey(k) end
  function api.OnPressed(fn) onPressed = fn end
  function api.SetEnabled(b) setEnabled(b) end
  function api.Destroy() maid:DoCleanup() end

  maid:Give(btn.MouseButton1Click:Connect(function()
    if not enabled then return end
    setListening(true)
  end))
  maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if listening then
      -- Escape cancels and keeps the current binding. ESCAPE may be nil on a client without the
      -- member, and an InputBegan can arrive with no KeyCode at all, so both sides are guarded --
      -- otherwise nil == nil would swallow a real capture.
      if ESCAPE ~= nil and input.KeyCode == ESCAPE then setListening(false); return end
      flashCapture()                                -- first: see the comment on flashCapture
      setListening(false)                           -- last: its ring tween must outlive the flash
      setKey(input.KeyCode)
    elseif not gameProcessed and input.KeyCode == toKeyCode(keyCode) then
      if opts.Callback then opts.Callback() end
      if onPressed then onPressed() end
    end
  end))
  maid:Give(btn)

  if opts.AccentReg then maid:Give(opts.AccentReg(function()
    btn.BackgroundColor3 = theme.Colors.surface
    local lab = btn:FindFirstChild("Label"); if lab then lab.TextColor3 = theme.Colors.foreground end
    local de = btn:FindFirstChild("Description"); if de then de.TextColor3 = theme.Colors.mutedForeground end
    keyBox.BackgroundColor3 = theme.Colors.background
    paintChip()                                   -- re-derives text + tint from `listening`
    chipStroke.Color = chipColor(listening)
    hover.reskin()
  end)) end

  return api
end
return Keybind
