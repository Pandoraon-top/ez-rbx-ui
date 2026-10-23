return function(window, host)
  host = host or window
  local tab = host:AddTab({ Name = "Table", Icon = "table" })
  tab:AddSection("Data table")
  local t = tab:AddTable({ Columns = { "Player", "Kills", "Deaths" }, Rows = {
    { "Alpha", "12", "3" }, { "Bravo", "8", "5" } } })
  local n = 2
  tab:AddButton({ Text = "Add row", Callback = function() n = n + 1; t.AddRow({ "P" .. n, tostring(n), "0" }) end })
  tab:AddParagraph("Columns + rows with AddRow/SetData/Clear; scrolls when tall.")

  tab:AddSection("Editable cells")
  -- Keyed rows + OnEdit: a decimal comma is accepted and normalised, anything that is not a
  -- number >= 0 is rejected and the cell shows its previous value again.
  local waits = tab:AddTable({
    Columns = {
      { Text = "Pet", Width = 2 },
      { Text = "Before pickup (s)", Editable = true, Placeholder = "0" },
      { Text = "Before placing back (s)", Editable = true, Placeholder = "0" },
    },
    Rows = {
      { Key = "pet-1", Cells = { "Peacock with a very long name", "0.6", "0" } },
      { Key = "pet-2", Cells = { "Owl", "1", "2" } },
    },
    OnEdit = function(key, col, text, old)
      local v = tonumber((text:gsub(",", ".")))
      if not v or v < 0 then
        window:ShowWarning({ Title = "Not saved", Message = "Use a number of 0 or more (was " .. old .. ")." })
        return false
      end
      return tostring(v)
    end,
  })
  tab:AddButton({ Text = "Reset waits", Callback = function()
    for _, key in ipairs({ "pet-1", "pet-2" }) do waits.SetCell(key, 2, "0"); waits.SetCell(key, 3, "0") end
  end })
  tab:AddToggle({ Text = "Lock editing", Callback = function(on) waits.SetEnabled(not on) end })

  local acc = tab:AddAccordion({ Title = "Inside an accordion", Icon = "rows-3", Expanded = false })
  acc:AddTable({ Columns = { "A", "B" }, Rows = { { "1", "2" } } })
  local acc2 = tab:AddAccordion({ Title = "Expanded by default", Icon = "rows-3", Expanded = true })
  acc2:AddTable({ Columns = { "A", "B" }, Rows = { { "1", "2" } } })
end
