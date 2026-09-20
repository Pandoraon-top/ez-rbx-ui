-- Mixin: adds AddX control methods to any container (Tab/Accordion) via the registry R.
-- No Init (mixin only); Host.attach(api, ctx) wires the methods.
local Host = {}

local SIMPLE = {
  AddLabel = { mod = "Label" },
  AddParagraph = { mod = "Label", preset = { Variant = "paragraph" } },
  AddSection = { mod = "Label", preset = { Variant = "section" } },
  AddSeparator = { mod = "Separator" },
  AddButton = { mod = "Button" },
  AddToggle = { mod = "Toggle" },
  AddTextBox = { mod = "TextBox" },
  AddNumberBox = { mod = "NumberBox" },
  AddSelectBox = { mod = "SelectBox" },
  AddSlider = { mod = "Slider" },
  AddKeybind = { mod = "Keybind" },
  AddColorPicker = { mod = "ColorPicker" },
  AddImage = { mod = "Image" },
  AddTable = { mod = "Table" },
  AddProgressBar = { mod = "ProgressBar" },
  AddResizable = { mod = "Resizable" },
  AddCard = { mod = "Card" },
}

-- Tie a cleanup fn to a control's lifetime. Controls that expose a Maid (Tab/Accordion/Window)
-- take it directly; the rest (Button/Label/Image/ProgressBar/Separator/Card...) only have Destroy,
-- so it is wrapped to run fn FIRST and then the original. Used for per-control reskin
-- unregisters (LockScrim here; tooltip / disabled in later items) so a destroyed control never
-- leaves a closure behind in the window's themer.
function Host.own(control, fn)
  if type(fn) ~= "function" then error("Host.own(control, fn): fn must be a function", 2) end
  if control.Maid then control.Maid:Give(fn); return control end
  local d = control.Destroy
  control.Destroy = function(...)
    fn()
    if d then return d(...) end
  end
  return control
end

-- ctx = { R, content, theme, config, window, nextOrder }
function Host.attach(api, ctx)
  for method, spec in pairs(SIMPLE) do
    api[method] = function(_, arg)
      local opts = {}
      if type(arg) == "string" then
        opts.Text = arg
      elseif type(arg) == "function" then
        opts.Text = arg                  -- reactive shorthand: AddLabel(function() return ... end)
      elseif type(arg) == "table" then
        for k, v in pairs(arg) do opts[k] = v end
      end
      if spec.preset then
        for k, v in pairs(spec.preset) do if opts[k] == nil then opts[k] = v end end
      end
      opts.Parent = ctx.content
      opts.LayoutOrder = ctx.nextOrder()
      opts.Theme = ctx.theme
      opts.Config = ctx.config
      opts.Window = ctx.window
      opts.AccentReg = ctx.accentThemer and ctx.accentThemer.register
      opts.AccentThemer = ctx.accentThemer
      -- A control may itself be a host (Resizable mounts its own panes). Without these two it
      -- attaches its panes with a nil registry, and every control nested inside one is invisible
      -- to the sidebar search and to Window:LockAll -- the pane's own comment claimed otherwise.
      opts.RegisterSearchable = ctx.registerSearchable
      opts.RegisterControl = ctx.registerControl
      local control = ctx.R[spec.mod].new(opts)
      if opts.Tooltip and ctx.R.Tooltip and control and control.Frame then
        -- Button/Label/Image/ProgressBar/Separator/Card expose no .Maid, so without Host.own the
        -- tip's hover connections (and a chip still on screen) outlive the destroyed control.
        local tip = ctx.R.Tooltip.attach(control.Frame, opts.Tooltip, ctx.theme)
        if tip and tip.Destroy then Host.own(control, tip.Destroy) end
      end
      if ctx.registerSearchable and control and control.Frame then
        -- opts.Text may be a function (reactive label); index a stable string only.
        local searchText = (type(opts.Text) == "string" and opts.Text) or opts.Title or opts.Name or ""
        ctx.registerSearchable(control.Frame, searchText)
      end
      if control and control.Frame then
        local C = ctx.R.Create
        -- The lock overlay is built on FIRST use, not up front. It costs three instances per
        -- control (scrim, its corner, shield) and most windows never lock anything: a nine-tab
        -- hub with ~330 controls was paying ~500 instances for a feature it never called, all
        -- created synchronously while the window builds, which is exactly what makes execute hang.
        local scrim, shield
        local function ensureLock()
          if scrim then return end
          scrim = C("Frame", { Name = "LockScrim", BackgroundColor3 = ctx.theme.Colors.background,
            BackgroundTransparency = ctx.theme.Opacity.scrim, BorderSizePixel = 0, Visible = false, ZIndex = 50,
            Size = UDim2.new(1, 0, 1, 0), Parent = control.Frame, C.corner(ctx.theme.Radius.md) })
          shield = C("ImageButton", { Name = "LockShield", AutoButtonColor = false, BackgroundTransparency = 1,
            Active = true, Visible = false, ZIndex = 51, Size = UDim2.new(1, 0, 1, 0), Parent = control.Frame })
          -- the scrim is chrome-coloured, so it must follow SetMode; registered only now, so an
          -- unlocked control also costs no themer closure. Owned by the control, so destroying it
          -- takes the closure with it.
          if ctx.accentThemer then
            Host.own(control, ctx.accentThemer.register(function() scrim.BackgroundColor3 = ctx.theme.Colors.background end))
          end
        end
        control.SetLocked = function(b)
          local v = b and true or false
          if not scrim and not v then return end   -- unlocking something never locked: nothing to build
          ensureLock()
          ctx.R.Safe.mutate(function() scrim.Visible = v; shield.Visible = v end)
        end
        if opts.Locked then control.SetLocked(true) end
        if ctx.registerControl then ctx.registerControl(control) end
      end
      return control
    end
  end
end

return Host
