-- Tab 3 — everything that leaves the panel: toasts, the dialog, the two popovers, and the scrim
-- that locks the whole window.
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
  tab:AddButton({ Text = "Loading toast that resolves", Icon = "loader", Variant = "secondary", Callback = function()
    if promising then return end
    promising = true
    window:Promise(function() task.wait(1.6); return 42 end, {
      Loading = "Fetching…", Error = "Could not fetch",
      Success = function(n) return "Fetched " .. tostring(n) .. " rows" end,
      Finally = function() promising = false end })
  end })
  -- The same spinner with no Promise around it: ShowLoading pins Duration to 0, so the toast waits
  -- for DismissNotification(id). The id doubles as the busy guard, and OnDismiss clears it so
  -- closing the toast by its own X cannot leave a stale one behind.
  local loadingId
  tab:AddButton({ Text = "Spinner toast, dismissed by hand", Icon = "loader", Variant = "outline", Callback = function()
    if loadingId then window:DismissNotification(loadingId); loadingId = nil; return end
    loadingId = window:ShowLoading({ Title = "Working…", Message = "Click the button again to dismiss it.",
      OnDismiss = function() loadingId = nil end })
  end })
  -- Moving the stack is the clearest look at the exit: a toast leaves toward the edge its corner is
  -- anchored to, so the same dismissal slides right, left, up or down.
  tab:AddSelectBox({ Text = "Toast corner", Default = "bottom-right", Searchable = false,
    Description = "Move the stack, raise a toast, and watch which way it leaves.",
    Options = { "top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right" },
    Callback = function(v)
      window:SetNotificationPosition(v)
      window:ShowInfo({ Title = "Stack moved", Message = tostring(v), Duration = 2500 })
    end })

  tab:AddSection("Dialog")
  tab:AddParagraph(
    "The card fades in from 94%, rises about 12px and settles with a spring; the scrim behind it " ..
    "fades rather than cutting in, and the card has its own drop shadow on top of the scrim. " ..
    "The keyboard answers in two different ways. Escape (or gamepad B) is a DISMISSAL: the card " ..
    "folds back down — shrink, fade, drop, scrim last — and no footer callback runs at all, so " ..
    "nothing below is a safe way to say yes. Return (or gamepad A) is the answer: it fires the " ..
    "LAST button, the primary one on the right, callback and all.")
  tab:AddButton({ Text = "Open a dialog", Icon = "message-square", Callback = function()
    window:Dialog({ Title = "Delete this loadout?", Message = "This cannot be undone.", Icon = "trash-2",
      Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Delete", Variant = "destructive", Icon = "trash-2",
          Callback = function() window:ShowSuccess({ Title = "Deleted" }) end } } })
  end })
  -- theme.Colors.destructive is rgb(239, 68, 68) in BOTH palettes (core/theme.lua:21 and :104), so
  -- the literal survives SetMode. A page is handed only `window`, which exposes no theme.
  local DESTRUCTIVE = Color3.fromRGB(239, 68, 68)
  tab:AddButton({ Text = "Badge header", Icon = "triangle-alert", Variant = "destructive", Callback = function()
    -- IconBadge centres the header and sets the glyph in a rounded square tinted 15% toward
    -- IconColor — the destructive red is what makes so shallow a mix read as a colour at all.
    window:Dialog({ Title = "Ban this player?", Message = "They lose access the moment you confirm.",
      Icon = "ban", IconBadge = true, IconColor = DESTRUCTIVE, Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Ban", Variant = "destructive", Icon = "ban" } } })
  end })
  tab:AddButton({ Text = "A wider card", Icon = "expand", Variant = "outline", Callback = function()
    -- Width is px, clamped to the window minus a 24px margin each side: an over-wide number fills
    -- the frame instead of spilling out of it.
    window:Dialog({ Title = "Release notes", Width = 460, Icon = "expand",
      Message = "460 wide instead of the default 320. Still one canvas group, so the whole sheet — " ..
        "header, rule and footer — zooms and fades as a single piece at any width.",
      Buttons = { { Text = "Close" } } })
  end })
  tab:AddButton({ Text = "Stack two dialogs", Icon = "layers", Variant = "secondary", Callback = function()
    -- Both open from HERE rather than from the first card's footer: a footer button runs its
    -- callback and then closes its own dialog, so a second opened that way would be left alone
    -- with the scrim fading out from under it. This way the first card holds the scrim for the pair.
    window:Dialog({ Title = "Underneath", Message = "This one painted the scrim and holds it.",
      Buttons = { { Text = "Close", Variant = "secondary" } } })
    window:Dialog({ Title = "On top", Icon = "layers",
      Message = "The room is no darker than it was for one card — a stacked dialog skips the scrim " ..
        "instead of laying a second over the first. Escape and Return answer here only.",
      Buttons = { { Text = "Close", Variant = "secondary" },
        -- A footer button that opens another dialog: this card closes under the new one, and the
        -- keyboard follows the top of the stack, not the card that did the opening.
        { Text = "One more on top", Callback = function()
          window:Dialog({ Title = "Third", Buttons = { { Text = "Done" } },
            Message = "Its opener closed beneath it; the bottom card still holds the scrim." })
        end } } })
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

  tab:AddSection("Locked")
  tab:AddParagraph(
    "Lock the window and every control it registered — on this tab and the other three — drops " ..
    "under a scrim with an invisible shield above it: the row still reads, it just stops " ..
    "answering the mouse. That scrim is its own flag, separate from a disabled control — Disabled " ..
    "dims one control and blocks its input while its value still updates, and clearing either one " ..
    "does not clear the other.")
  local locked, lockBtn = false, nil
  lockBtn = tab:AddButton({ Text = "Lock every control", Icon = "lock", Variant = "outline", Callback = function()
    locked = not locked
    -- LockAll reaches every registered control, this button included, so its own shield has to come
    -- straight back off or the click that undoes the lock would never land.
    if locked then window:LockAll(); lockBtn.SetLocked(false) else window:UnlockAll() end
    lockBtn.SetText(locked and "Unlock every control" or "Lock every control")
  end })
end
