-- Tab 1 — the subject is the WINDOW CHROME, so the body stays short: a couple of paragraphs and
-- a strip of buttons that repaint the shell live. Nothing here is a control demo.
return function(window)
  local tab = window:AddTab({ Name = "Look", Icon = "palette" })

  tab:AddSection("Look at the shell, not this text")
  tab:AddParagraph(
    "The glass behind this panel is zinc, not black — the dark acrylic used to crush to pure " ..
    "black and swallow every layer. Three tonal steps separate the shell now: window glass, " ..
    "content panel, row surface. A field drops back BELOW all three, to the glass tone, so it " ..
    "reads as a well sunk into its row — there is one on the Motion tab. The title above is " ..
    "BuilderSans Bold, this body is Regular and the heading above it is the small uppercase " ..
    "overline — three real font weights where there used " ..
    "to be one. The panel's top border is lit: a gradient stroke that fades toward the bottom, " ..
    "plus a 1px white glint tucked inside the top radius. The whole window rests on a soft " ..
    "9-slice drop shadow, which is what separates it from the game behind it.")

  tab:AddSection("The sidebar")
  tab:AddParagraph(
    "Three things live in the strip on the left. The field at the top filters BOTH halves of it: " ..
    "a tab survives if its own name matches, and it also survives if any control inside it " ..
    "matches, while every control row that does NOT match is hidden — so searching thins the page " ..
    "you are standing on as well as the tab list. The overline headers (THE SHELL, THE CONTENTS) " ..
    "come from grouping the tabs, and one disappears once every tab under it has been filtered " ..
    "away. The seam between the sidebar and this panel is draggable: rest the pointer on it and a " ..
    "grip pill fades up out of the hairline, then pull — the panel reflows as you go. And the 3px " ..
    "pill marking the active tab does not merely move: it stretches tall as it leaves, springs " ..
    "across on a duration scaled to the distance, and settles back to its rest height on arrival.")
  -- SearchTabs is the exact entry point the field uses, so a button proves the filter with no
  -- typing. The query is a word from this button's OWN caption on purpose: the index stores the
  -- text a control was BUILT with (components/host.lua, registerSearchable), so this row survives
  -- its own filter and can be clicked again to clear it.
  local searchBtn, filtered = nil, false
  searchBtn = tab:AddButton({ Text = "Filter the sidebar for \"toggle\"", Icon = "search", Variant = "secondary",
    Callback = function()
      filtered = not filtered
      window:SearchTabs(filtered and "toggle" or "")
      searchBtn.SetText(filtered and "Clear the filter" or "Filter the sidebar for \"toggle\"")
    end })

  tab:AddSection("Repaint the shell live")
  -- Mode and accent are separate axes on purpose: a NAMED accent survives a mode switch, while
  -- "Adaptive" follows the mode. Flip both to see that.
  local modeBtn
  local function modeText() return "Switch to " .. (window:GetMode() == "dark" and "light" or "dark") .. " mode" end
  modeBtn = tab:AddButton({ Text = modeText(), Icon = "sun", Variant = "secondary", Callback = function()
    window:SetMode(window:GetMode() == "dark" and "light" or "dark")
    modeBtn.SetText(modeText())   -- re-read, so repeated clicks keep the label truthful
  end })

  -- The six built-in accent names, in the order core/themer.lua declares them.
  local ACCENTS = { "Adaptive", "Indigo", "Violet", "Emerald", "Sky", "Rose" }
  local accentAt, accentBtn = 1, nil
  accentBtn = tab:AddButton({ Text = "Accent: Adaptive (tap to cycle)", Icon = "sparkles", Variant = "secondary",
    Callback = function()
      accentAt = accentAt % #ACCENTS + 1   -- wraps, so clicking forever is safe
      local name = ACCENTS[accentAt]
      window:SetAccent(name)
      accentBtn.SetText("Accent: " .. name .. " (tap to cycle)")
    end })
  -- What SetAccent actually repaints is Colors.primary / primaryForeground and nothing else
  -- (components/window.lua api:SetAccent), so only parts painted FROM primary follow it. The
  -- focus ring is deliberately not one of them: it reads Colors.ring, which the accent never
  -- touches — the paragraph says so rather than promising a ring that will not move.
  tab:AddParagraph(
    "Accent is the primary token. The one spot you can watch from here is the sidebar " ..
    "indicator on the left: the 3px pill and the soft halo blooming around it both repaint on " ..
    "every tap, and so does the icon in the title-bar tag. The rest is a tab away — on Motion, " ..
    "the pill and glow behind an ON toggle, the slider fill and the halo under its handle, and " ..
    "the progress fill. A default-variant button — the solid ones, like Success on Overlays or " ..
    "Step +25% on Motion — is the only place the accent lands as a whole fill. Focus rings are " ..
    "NOT accent: a focused field takes the " ..
    "separate neutral ring token, so it stays the same however you tint the rest.")

  tab:AddSection("Scale")
  -- SetUIScale drives a UIScale whose pivot is the window centre (AnchorPoint 0.5), so the
  -- window grows about its middle instead of crawling out of the top-left corner. The overlay
  -- layer (toasts, dropdowns, dialogs) is forwarded the same scale.
  tab:AddButton({ Text = "UI scale 0.9", Variant = "outline", Callback = function() window:SetUIScale(0.9) end })
  tab:AddButton({ Text = "UI scale 1.0", Variant = "outline", Callback = function() window:SetUIScale(1.0) end })
  tab:AddButton({ Text = "UI scale 1.2", Variant = "outline", Callback = function() window:SetUIScale(1.2) end })

  tab:AddSection("Transparency")
  -- SetTransparency repaints the acrylic: the sheen, rim and grain all rescale with it, and 60%
  -- of the value is propagated down to the content panel so a frosted window is not holding a
  -- solid slab of panel.
  tab:AddButton({ Text = "Transparency 0.02 — almost solid", Variant = "ghost",
    Callback = function() window:SetTransparency(0.02) end })
  tab:AddButton({ Text = "Transparency 0.12 — the default", Variant = "ghost",
    Callback = function() window:SetTransparency(0.12) end })
  tab:AddButton({ Text = "Transparency 0.35 — properly glassy", Variant = "ghost",
    Callback = function() window:SetTransparency(0.35) end })

  tab:AddSection("Two gestures worth trying")
  tab:AddParagraph(
    "Grab the title bar and drag. While you hold it the drop shadow spreads about 8px wider and " ..
    "darkens, and the hairline goes opaque — the window lifts off the page — then settles back " ..
    "when you release. The bottom-right resize grip does the same lift.")
  tab:AddParagraph(
    "Press the minimize button (the dash left of the x). The window folds to 96%, drifts toward " ..
    "the floating toggle on the left edge and hands off to it as it lands: the window literally " ..
    "turns into the button. RightControl runs the same fold and unfold. The x is a different " ..
    "gesture — it asks to confirm first (that dialog is its own motion demo) and then dissolves " ..
    "the window in place rather than drifting. Read that confirm dialog with suspicion: it " ..
    "offers to reopen the window with the toggle key or the floating button, and it cannot — " ..
    "Close destroys the GUI and every handler with it. Use minimize while you are still touring.")

  tab:AddSection("The floating toggle")
  tab:AddParagraph(
    "The button that brings the window back has three shapes. Simple is a chevron tab that docks " ..
    "flush to the screen edge with a few pixels peeking out; circle is a round accent button and " ..
    "square a rounded surface tile — those two wear the same brand glyph as the title bar, tinted " ..
    "to the foreground token so the logo follows dark and light instead of shipping twice. The " ..
    "button auto-hides, so switching type changes nothing you can see while the window is up: " ..
    "press RightControl (or minimize) FIRST, then drag it. Only the simple tab magnets — drop it " ..
    "anywhere and it slides to whichever side of the screen its centre was nearest, docking with " ..
    "a few pixels peeking out and its chevron spun round to face outward; rest a pointer on it " ..
    "and it leans a little further out. Circle and square are free-floating and stay where you " ..
    "drop them.")
  local fabLabel = tab:AddLabel("Floating toggle: simple")
  -- SetFloatingToggle merges over the current options (components/window.lua), so changing Type
  -- keeps the Image/Adaptive/AutoHide set in example/showcase.lua. Rebuilding is idempotent.
  local function setFab(kind)
    window:SetFloatingToggle({ Type = kind })
    fabLabel.SetText("Floating toggle: " .. window:GetFloatingToggleType())
  end
  tab:AddButton({ Text = "Simple — chevron tab", Variant = "outline", Callback = function() setFab("simple") end })
  tab:AddButton({ Text = "Circle — accent button", Variant = "outline", Callback = function() setFab("circle") end })
  tab:AddButton({ Text = "Square — logo tile", Variant = "outline", Callback = function() setFab("square") end })
end
