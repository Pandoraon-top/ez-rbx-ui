-- Tab 3 — everything that leaves the panel: toasts, the dialog, and the two popovers.
return function(window)
  local tab = window:AddTab({ Name = "Overlays", Icon = "bell" })

  tab:AddSection("Toasts")
  tab:AddParagraph(
    "Raise three or four in a row, then put the cursor over the stack. They fan out on a " ..
    "stagger — each row further back waits a beat longer — and the countdown pauses while you " ..
    "hover. Move away and they collapse back to a stack with the newest in front. Each toast is " ..
    "one canvas group, so it fades and exits as a single piece instead of part by part.")
  tab:AddButton({ Text = "Success", Icon = "circle-check",
    Callback = function() window:ShowSuccess({ Title = "Saved", Message = "Everything landed." }) end })
  tab:AddButton({ Text = "Warning", Icon = "triangle-alert", Variant = "secondary",
    Callback = function() window:ShowWarning({ Title = "Careful", Message = "That one is close to the limit." }) end })
  tab:AddButton({ Text = "Error", Icon = "circle-x", Variant = "destructive",
    Callback = function() window:ShowError({ Title = "Failed", Message = "The request came back empty." }) end })
  tab:AddButton({ Text = "Info", Icon = "info", Variant = "outline",
    Callback = function() window:ShowInfo({ Title = "Heads up", Message = "Nothing is on fire." }) end })
  tab:AddButton({ Text = "With an action button", Variant = "ghost", Callback = function()
    window:Notify({ Title = "Item deleted", Message = "Removed from your inventory.", Type = "warning",
      Action = { Text = "Undo", Callback = function() window:ShowSuccess({ Title = "Restored" }) end } })
  end })
  -- Promise morphs ONE toast: the spinner row becomes the success row in place, with a pulse.
  -- The busy guard keeps a second click from stacking a second 1.6s task.
  local promising = false
  tab:AddButton({ Text = "Loading toast that resolves", Icon = "loader", Variant = "secondary",
    Callback = function()
      if promising then return end
      promising = true
      window:Promise(function() task.wait(1.6); return 42 end, {
        Loading = "Fetching…",
        Success = function(n) return "Fetched " .. tostring(n) .. " rows" end,
        Error = "Could not fetch",
        Finally = function() promising = false end,
      })
    end })

  tab:AddSection("Dialog")
  tab:AddParagraph(
    "The card fades in from 94%, rises about 12px and settles with a spring; the scrim behind it " ..
    "fades rather than cutting in, and the card has its own drop shadow on top of the scrim. " ..
    "Press Escape (or gamepad B) and the first non-destructive button fires — the dialog closes " ..
    "with a fade down instead of vanishing. Return fires the primary button on the right.")
  tab:AddButton({ Text = "Open a dialog", Icon = "message-square", Callback = function()
    window:Dialog({ Title = "Delete this loadout?", Message = "This cannot be undone.", Icon = "trash-2",
      Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Delete", Variant = "destructive", Icon = "trash-2",
          Callback = function() window:ShowSuccess({ Title = "Deleted" }) end },
      } })
  end })

  tab:AddSection("Popovers")
  tab:AddParagraph(
    "Open the dropdown and watch where it comes FROM: it grows out of its own field, scaling up " ..
    "with a slide, and the caret rotates 180 degrees while it does. It gets the same frosted " ..
    "glass and drop shadow as the window, so it floats instead of sitting flat. Close it and it " ..
    "shrinks back down rather than blinking out. Near the bottom of the screen it flips upward " ..
    "and grows from the other edge.")
  -- Eight options: the search field auto-appears above five, so this shows the sticky search
  -- with its own focus ring without having to pass Searchable.
  tab:AddSelectBox({ Text = "Region", Default = "eu-west",
    Description = "More than five options, so the search field appears on its own.",
    Options = {
      { Value = "eu-west", Text = "Europe West", Icon = "globe" },
      { Value = "eu-north", Text = "Europe North", Icon = "globe" },
      { Value = "us-east", Text = "US East", Icon = "map-pin" },
      { Value = "us-west", Text = "US West", Icon = "map-pin" },
      { Divider = true },
      { Value = "ap-south", Text = "Asia Pacific South", Icon = "navigation" },
      { Value = "ap-north", Text = "Asia Pacific North", Icon = "navigation" },
      { Value = "sa-east", Text = "South America East", Icon = "compass" },
      { Value = "af-south", Text = "Africa South", Icon = "compass" },
    },
    Callback = function(v) window:ShowInfo({ Title = "Region", Message = tostring(v), Duration = 2000 }) end })

  -- No AllowNone here: components/selectbox.lua only consults it on the SINGLE-select path
  -- (a multi list may always be emptied), so passing it would imply a behaviour it does not have.
  tab:AddSelectBox({ Text = "Modules", Multi = true,
    Description = "Multi-select: the field summarises, and a clear button appears once something is picked.",
    Options = { "Aim", "ESP", "Movement", "Render", "Audio", "Network" },
    -- Multi hands the callback an ARRAY of values, so count it rather than tostring it.
    Callback = function(list) window:ShowInfo({ Title = "Modules", Message = #list .. " selected", Duration = 2000 }) end })

  tab:AddParagraph(
    "The colour picker is the same popover machinery. The SV square and the hue strip each have " ..
    "a dot with a 1px rim so it stays visible over a bright patch, and the swatch on the row " ..
    "follows live as you drag.")
  tab:AddColorPicker({ Text = "Highlight colour", Default = Color3.fromRGB(120, 160, 255) })

  tab:AddSection("Keybind")
  -- The listening state is the FOCUS ring recipe, not the accent: components/keybind.lua paints
  -- the chip stroke Colors.ring while listening and only flashes Colors.primary on capture.
  tab:AddParagraph(
    "Click the chip: it goes into listening state — its hairline thickens to 2px, lifts to the " ..
    "neutral ring colour and breathes in and out, and the label reads 'Press a key'. The next " ..
    "key you press is captured with an accent flash on that same hairline as the ring leaves. " ..
    "Escape cancels and keeps the old binding.")
  tab:AddKeybind({ Text = "Flash a toast", Default = Enum.KeyCode.G,
    Callback = function() window:ShowInfo({ Title = "Keybind fired", Duration = 1500 }) end })
end
