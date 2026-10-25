local h = require("tests.helper")
local R = h.loadLib()
local Window = R.Window

local function newWin(extra)
  local screen = h.roblox.Instance.new("ScreenGui")
  local o = { Title = "Hub", Parent = screen, TabTransition = "none" }
  for k, v in pairs(extra or {}) do o[k] = v end
  return Window.new(o), screen
end
-- control rows a tab's content holds (its layout + padding are not rows)
local function rows(tab)
  local n = 0
  for _, c in ipairs(tab.Content:GetChildren()) do
    if c.ClassName ~= "UIListLayout" and c.ClassName ~= "UIPadding" then n = n + 1 end
  end
  return n
end

h.describe("lazy tabs: AddTab({ Build = fn }) builds the page on its first visit", function()
  h.it("a non-first tab with Build has no rows and is not built until visited", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:AddToggle({ Text = "a" }) end })
    h.expect(calls).toBe(0)
    h.expect(lazy:IsBuilt()).toBe(false)
    h.expect(rows(lazy)).toBe(0)
  end)

  h.it("the first tab is auto-selected, so its Build runs at once", function()
    local w = newWin()
    local calls = 0
    local t = w:AddTab({ Name = "Home", Build = function(tab) calls = calls + 1; tab:AddToggle({ Text = "a" }) end })
    h.expect(calls).toBe(1)
    h.expect(t:IsBuilt()).toBe(true)
    h.expect(t:IsSelected()).toBe(true)
    h.expect(rows(t)).toBe(1)
  end)

  h.it("clicking the tab builds it once; later visits reuse the page", function()
    local w = newWin()
    local home = w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab)
      calls = calls + 1
      for i = 1, 3 do tab:AddToggle({ Text = "t" .. i }) end
    end })
    lazy.Button.MouseButton1Click:Fire()
    h.expect(calls).toBe(1)
    h.expect(lazy:IsSelected()).toBe(true)
    h.expect(lazy.Content.Visible).toBe(true)
    h.expect(rows(lazy)).toBe(3)
    home.Button.MouseButton1Click:Fire()
    lazy.Button.MouseButton1Click:Fire()
    h.expect(calls).toBe(1)        -- built once, kept: a tab switch costs no rebuild
    h.expect(rows(lazy)).toBe(3)
  end)

  h.it("a direct Select() builds too", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:AddButton({ Text = "b" }) end })
    lazy:Select()
    h.expect(calls).toBe(1)
    h.expect(rows(lazy)).toBe(1)
  end)

  h.it("EnsureBuilt() builds without selecting and returns the tab", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:AddToggle({ Text = "a" }) end })
    h.expect(lazy:EnsureBuilt()).toBe(lazy)
    h.expect(calls).toBe(1)
    h.expect(lazy:IsBuilt()).toBe(true)
    h.expect(lazy:IsSelected()).toBe(false)
    h.expect(lazy.Content.Visible).toBe(false)
    lazy:Select()
    h.expect(calls).toBe(1)
  end)

  h.it("Build receives the very tab object AddTab returned", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local got
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) got = tab end })
    lazy:Select()
    h.expect(got).toBe(lazy)
  end)

  h.it("a tab without Build is built up front, as before", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local eager = w:AddTab({ Name = "Pets" })
    eager:AddToggle({ Text = "a" })
    h.expect(eager:IsBuilt()).toBe(true)
    h.expect(rows(eager)).toBe(1)
  end)

  h.it("a Build that throws is reported in the page and never retried", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab)
      calls = calls + 1
      tab:AddToggle({ Text = "before the error" })
      error("boom")
    end })
    lazy:Select()
    h.expect(calls).toBe(1)
    h.expect(lazy:IsBuilt()).toBe(true)
    local found = false
    for _, c in ipairs(lazy.Content:GetChildren()) do
      if c.ClassName == "TextLabel" and tostring(c.Text):find("boom", 1, true) then found = true end
    end
    h.expect(found).toBeTruthy()
    lazy:Deselect(); lazy:Select()
    h.expect(calls).toBe(1)
  end)

  h.it("a lazy page's controls read the saved config when they are built", function()
    local w = newWin({ Config = { FileName = "LZ", AutoSave = false } })
    w.Config:Set("lz_toggle", true)
    w:AddTab({ Name = "Home" })
    local tg
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab)
      tg = tab:AddToggle({ Text = "a", Flag = "lz_toggle", Default = false })
    end })
    lazy:Select()
    h.expect(tg.Get()).toBe(true)
  end)

  h.it("sidebar search sees a lazy page only once it has been built", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) tab:AddToggle({ Text = "Auto Feed" }) end })
    w:SearchTabs("auto feed")
    h.expect(lazy.Button.Visible).toBe(false)    -- nothing indexed yet, and the name does not match
    w:SearchTabs("")
    lazy:EnsureBuilt()
    w:SearchTabs("auto feed")
    h.expect(lazy.Button.Visible).toBe(true)
    w:SearchTabs("")
  end)

  h.it("EnsureBuilt twice builds once", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:AddToggle({ Text = "a" }) end })
    lazy:EnsureBuilt(); lazy:EnsureBuilt()
    h.expect(calls).toBe(1)
    h.expect(rows(lazy)).toBe(1)
  end)

  h.it("a Build that selects its own tab does not recurse", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy
    lazy = w:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:Select(); tab:AddToggle({ Text = "a" }) end })
    lazy.Button.MouseButton1Click:Fire()
    h.expect(calls).toBe(1)
    h.expect(lazy:IsSelected()).toBe(true)
    h.expect(lazy.Content.Visible).toBe(true)
    h.expect(rows(lazy)).toBe(1)
  end)

  h.it("the error paragraph carries the documented prefix", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local lazy = w:AddTab({ Name = "Pets", Build = function() error("boom") end })
    lazy:Select()
    local text
    for _, c in ipairs(lazy.Content:GetChildren()) do if c.ClassName == "TextLabel" then text = c.Text end end
    h.expect(tostring(text):find("Tab failed to build: ", 1, true)).toBe(1)
  end)

  h.it("LockAll before the first visit locks the page it later builds", function()
    local w = newWin()
    local home = w:AddTab({ Name = "Home" })
    local eager = home:AddToggle({ Text = "e" })
    local lazyTg
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) lazyTg = tab:AddToggle({ Text = "a" }) end })
    w:LockAll()
    h.expect(eager.Frame:FindFirstChild("LockScrim").Visible).toBe(true)
    lazy:Select()
    h.expect(lazyTg.Frame:FindFirstChild("LockScrim") ~= nil).toBeTruthy()
    h.expect(lazyTg.Frame:FindFirstChild("LockScrim").Visible).toBe(true)
    w:UnlockAll()
    h.expect(lazyTg.Frame:FindFirstChild("LockScrim").Visible).toBe(false)
    local late = w:AddTab({ Name = "Late", Build = function(tab) lazyTg = tab:AddToggle({ Text = "l" }) end })
    late:Select()
    h.expect(lazyTg.Frame:FindFirstChild("LockScrim")).toBeNil()   -- unlocked windows build no scrim
  end)

  h.it("ResetConfiguration before the first visit resets the flags the page registers later", function()
    local w = newWin({ Config = { FileName = "LZR", AutoSave = false } })
    w.Config:Set("lz_reset", true)
    w:AddTab({ Name = "Home" })
    local tg
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab)
      tg = tab:AddToggle({ Text = "a", Flag = "lz_reset", Default = false })
    end })
    w:ResetConfiguration({ Confirm = false })
    lazy:Select()
    h.expect(tg.Get()).toBe(false)
    h.expect(w.Config:Get("lz_reset")).toBe(false)
  end)

  h.it("a search in force is applied to a page built while it is active", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local feed, food
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab)
      feed = tab:AddToggle({ Text = "Auto Feed" })
      food = tab:AddToggle({ Text = "Pets food" })
    end })
    w:SearchTabs("pets")                      -- the NAME matches: the button stays clickable
    h.expect(lazy.Button.Visible).toBe(true)
    lazy.Button.MouseButton1Click:Fire()
    h.expect(feed.Frame.Visible).toBe(false)  -- filtered like the rows that already existed
    h.expect(food.Frame.Visible).toBe(true)
    w:SearchTabs("")
    h.expect(feed.Frame.Visible).toBe(true)
  end)

  h.it("a Select after the window closed builds nothing", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local calls = 0
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:AddKeybind({ Text = "k" }) end })
    w:Close()
    lazy:Select()
    h.expect(calls).toBe(0)
    h.expect(lazy:IsBuilt()).toBe(false)
  end)

  h.it("a first grouped tab whose Build adds another tab keeps the group's entry straight", function()
    local w = newWin()
    local g = w:AddTabGroup("Farm")
    local pets = g:AddTab({ Name = "Pets", Build = function(tab)
      tab:AddToggle({ Text = "a" })
      w:AddTab({ Name = "Outside" })          -- ungrouped, added from inside the first tab's Build
    end })
    h.expect(pets:IsBuilt()).toBe(true)
    w:SearchTabs("outside")
    h.expect(g._header.Visible).toBe(false)   -- the group holds Pets, not Outside
    w:SearchTabs("pets")
    h.expect(g._header.Visible).toBe(true)
    w:SearchTabs("")
  end)

  h.it("a Build that yields delays the switch; a click meanwhile wins and the stale switch gives up", function()
    local w = newWin()
    local home = w:AddTab({ Name = "Home" })
    local shop = w:AddTab({ Name = "Shop" })
    local lazy = w:AddTab({ Name = "Pets", Build = function(tab)
      tab:AddToggle({ Text = "a" })
      coroutine.yield()                       -- stands in for task.wait / HttpGet inside Build
    end })
    local co = coroutine.create(function() lazy.Button.MouseButton1Click:Fire() end)
    assert(coroutine.resume(co))
    h.expect(coroutine.status(co)).toBe("suspended")
    h.expect(home.Content.Visible).toBe(true)   -- the current page stays up while Build waits
    h.expect(lazy.Content.Visible).toBe(false)
    shop.Button.MouseButton1Click:Fire()        -- the player moves on
    assert(coroutine.resume(co))                -- Pets' Build finishes: its switch is stale
    h.expect(shop:IsSelected()).toBe(true)
    h.expect(shop.Content.Visible).toBe(true)
    h.expect(lazy:IsSelected()).toBe(false)
    h.expect(lazy.Content.Visible).toBe(false)
    h.expect(lazy:IsBuilt()).toBe(true)
  end)

  h.it("tabs inside a group are lazy the same way", function()
    local w = newWin()
    w:AddTab({ Name = "Home" })
    local g = w:AddTabGroup("Farm")
    local calls = 0
    local lazy = g:AddTab({ Name = "Pets", Build = function(tab) calls = calls + 1; tab:AddToggle({ Text = "a" }) end })
    h.expect(calls).toBe(0)
    lazy.Button.MouseButton1Click:Fire()
    h.expect(calls).toBe(1)
    h.expect(rows(lazy)).toBe(1)
  end)
end)

h.run()
