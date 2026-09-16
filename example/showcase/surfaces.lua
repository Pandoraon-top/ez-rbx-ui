-- Tab 4 — the display controls that carry the type hierarchy and the hairlines, plus the two
-- containers. Tooltips are attached here too: Tooltip is a host-level option, so it works on any
-- Add* control (it does NOT work on AddAccordion, which is built outside the host mixin).
return function(window, logo)
  -- The same brand PNG the title bar downloads (example/showcase.lua passes it in) — a URL, not an
  -- asset id. Kept as a default so this page stands on its own if it is required bare.
  logo = logo or "https://alfin-efendy.github.io/ez-rbx-ui/brand/ezui-blade-zu-icon.png"
  -- A deliberately over-long tab name: the sidebar button is ~100px of text, and a tab label is one
  -- line with TextTruncate.AtEnd, so the name you see in the sidebar ends in an ellipsis.
  local tab = window:AddTab({ Name = "Surfaces, tables and cards", Icon = "layers" })

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
  tab:AddCard({
    Banner = logo,
    Title = "A second card, with a banner and a title far too long to fit on one line of it",
    Body = "The banner is an 80px slot at the top of the card, filled with whatever Asset can " ..
           "resolve — an asset id, or a URL like this one. The slot is reserved first and the " ..
           "picture lands when the download finishes, so a card never blocks on the network; " ..
           "where the executor cannot download at all the slot is never built and the card just " ..
           "starts at its title. That title is the other thing to look at: one line with " ..
           "TextTruncate.AtEnd, so it stops in an ellipsis instead of wrapping or widening.",
    Buttons = {
      { Text = "Where did it come from?", Variant = "secondary", Callback = function()
        window:ShowInfo({ Title = "Same mark as the title bar", Duration = 2000,
          Message = "One white-on-transparent PNG, tinted per mode up there, full colour here." })
      end },
    },
  })

  tab:AddSection("Table")
  tab:AddParagraph(
    "The header row is pinned and the body scrolls under it. Rows answer hover with a fill wash " ..
    "only — the row colour itself stays a pure token, so a theme switch cannot drift it. The " ..
    "first row's middle cell is longer than its column on purpose: a cell is one line with " ..
    "TextTruncate.AtEnd, so it ends in an ellipsis rather than wrapping or widening the column.")
  tab:AddTable({
    Columns = { "Layer", "Rendered as", "Sits" },
    Rows = {
      { "Drop shadow", "a 9-slice image sibling that spreads wider and darkens while you drag", "under" },
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

  tab:AddSection("Split pane")
  tab:AddParagraph(
    "Two panes sharing one seam, and the seam is draggable: grab the small grip pill in the middle " ..
    "and pull. Its glyph is muted at rest and lifts to the foreground while the pointer is on the " ..
    "handle, and the pill itself scales up for as long as you hold it, then springs back on " ..
    "release. Each pane is a full control host — the two below are live controls, not a picture of " ..
    "a layout — so they reflow as the fractions move.")
  local split = tab:AddResizable({ Direction = "Horizontal",
    Panes = { { Default = 0.45 }, { Default = 0.55 } }, Height = 116 })
  split.Panes[1]:AddLabel("Left pane")
  split.Panes[1]:AddToggle({ Text = "A toggle", Default = true })
  split.Panes[2]:AddLabel("Right pane")
  split.Panes[2]:AddProgressBar({ Default = 0.6 })

  tab:AddSection("Image")
  tab:AddParagraph(
    "The image control takes a Lucide name as well as an asset id. Rendered as a glyph it is " ..
    "tinted to the theme foreground, so it re-tints itself when you switch mode on the Look tab " ..
    "— no second asset for light mode.")
  tab:AddImage({ Lucide = "layers", Height = 72,
    Tooltip = "Switch to light mode on the Look tab and come back — this glyph follows." })
end
