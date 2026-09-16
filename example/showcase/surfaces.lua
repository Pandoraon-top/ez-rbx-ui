-- Tab 4 — the display controls that carry the type hierarchy and the hairlines. Tooltips are
-- attached here too: Tooltip is a host-level option, so it works on any Add* control (it does
-- NOT work on AddAccordion, which is built outside the host mixin).
return function(window)
  local tab = window:AddTab({ Name = "Surfaces", Icon = "layers" })

  tab:AddSection("Type hierarchy")
  tab:AddParagraph(
    "Three weights, three roles. The section heading above is the overline: 11px Medium, " ..
    "uppercase, muted — it groups without shouting. This paragraph is body Regular in the muted " ..
    "foreground with a 1.25 line height, so a block of it does not clot together. A label is the " ..
    "same size in the full foreground, which is why it reads as a value and this reads as prose.")
  tab:AddLabel({ Text = "A plain label — full foreground, one line.",
    Tooltip = "Tooltips fade in after a ~0.35s hover intent, and are inverted against the panel." })
  tab:AddLabel({ Variant = "paragraph",
    Text = "A paragraph label honours explicit line breaks too:\nthis is the second line,\nand this is the third." })

  tab:AddSection("Hairlines")
  tab:AddParagraph(
    "A separator is a 1px rule in the border colour — the same token as the panel edge, the " ..
    "dialog footer rule and the table header underline, so every divider in the library sits on " ..
    "one value. Two of them around this row:")
  tab:AddSeparator()
  tab:AddLabel("Between two separators.")
  tab:AddSeparator()

  tab:AddSection("Card")
  tab:AddParagraph(
    "A card is the row surface one step up from the panel, with its own hairline and radius. Its " ..
    "action buttons size to their own text instead of stretching edge to edge.")
  tab:AddCard({
    Title = "Depth, honestly",
    Body = "Shadow and glow are siblings rendered UNDER their host; the rim light and the sheen " ..
           "are clipped children on top. That ordering is what keeps a glow behind a toggle " ..
           "instead of washing over it.",
    Tooltip = "Cards accept a Tooltip as well — it attaches to the whole card frame.",
    Buttons = {
      { Text = "Nice", Callback = function() window:ShowSuccess({ Title = "Agreed", Duration = 1500 }) end },
      { Text = "Show me a toast", Variant = "secondary",
        Callback = function() window:ShowInfo({ Title = "Here you go", Duration = 1500 }) end },
      { Text = "Dismiss", Variant = "ghost" },
    },
  })

  tab:AddSection("Table")
  tab:AddParagraph(
    "The header row is pinned and the body scrolls under it. Rows answer hover with a fill wash " ..
    "only — the row colour itself stays a pure token, so a theme switch cannot drift it.")
  tab:AddTable({
    Columns = { "Layer", "Rendered as", "Sits" },
    Rows = {
      { "Drop shadow", "9-slice image", "under" },
      { "Accent glow", "9-slice image", "under" },
      { "Rim light", "gradient on stroke", "on top" },
      { "Sheen", "gradient frame", "on top" },
      { "Grain", "tiled noise", "clipped" },
    },
    Height = 110,
    Tooltip = "Scroll the body — the header stays put.",
  })

  tab:AddSection("Accordion")
  tab:AddParagraph(
    "Open and close it a couple of times: the collapse is the mirror of the expand, not a faster " ..
    "cut, and the caret turns at the same pace rather than snapping. The header answers hover " ..
    "with its own wash while the card body keeps its colour.")
  local acc = tab:AddAccordion({ Title = "Nested controls", Icon = "rows-3", Expanded = false })
  acc:AddToggle({ Text = "A toggle in here", Default = true, Description = "Same spring as on the Motion tab." })
  acc:AddSlider({ Text = "And a slider", Min = 0, Max = 10, Default = 6 })
  acc:AddButton({ Text = "And a button", Variant = "secondary",
    Tooltip = "Controls inside an accordion get the full host API, tooltips included.",
    Callback = function() window:ShowInfo({ Title = "From inside the accordion", Duration = 1500 }) end })

  tab:AddSection("Image")
  tab:AddParagraph(
    "The image control takes a Lucide name as well as an asset id. Rendered as a glyph it is " ..
    "tinted to the theme foreground, so it re-tints itself when you switch mode on the Look tab " ..
    "— no second asset for light mode.")
  tab:AddImage({ Lucide = "layers", Height = 72,
    Tooltip = "Switch to light mode on the Look tab and come back — this glyph follows." })
end
