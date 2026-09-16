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
end
