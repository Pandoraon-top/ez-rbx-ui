local h = require("tests.helper")
local R = h.loadLib(); local Card = R.Card
h.describe("card", function()
  h.it("builds a card with banner, title, body, and an action button", function()
    local c = Card.new({ Parent = R.Create("Frame", {}), Title = "News", Body = "Body text",
      Banner = "rbxassetid://1", Buttons = { { Text = "OK" } }, Theme = R.Theme })
    local banner = c.Frame:FindFirstChild("Banner")
    h.expect(banner.Image).toBe("rbxassetid://1")
    h.expect(c.Frame:FindFirstChild("Title").Text).toBe("News")
    h.expect(c.Frame:FindFirstChild("Body").Text).toBe("Body text")
    local row = c.Frame:FindFirstChild("Actions")
    h.expect(row ~= nil).toBeTruthy()
    h.expect(row:FindFirstChildOfClass("TextButton") ~= nil).toBeTruthy()
  end)
  h.it("action buttons are AutoWidth (no forced 96px width) and share the card's AccentReg", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local c = Card.new({ Parent = R.Create("Frame", {}), Title = "T", Buttons = { { Text = "A long label" }, { Text = "B" } },
      Theme = R.Theme, AccentReg = reg })
    local row = c.Frame:FindFirstChild("Actions")
    local n = 0
    for _, b in ipairs(row:GetChildren()) do
      if b.ClassName == "TextButton" then
        n = n + 1
        h.expect(b.AutomaticSize).toBe(h.roblox.Enum.AutomaticSize.X)
        h.expect(b.Size.X.Offset ~= 96).toBeTruthy()
      end
    end
    h.expect(n).toBe(2)
    h.expect(#fns).toBe(3)   -- card closure + one per button
  end)
  h.it("Title/Body use theme font roles (label / muted) and the title truncates", function()
    local c = Card.new({ Title = "T", Body = "b", Theme = R.Theme })
    local ti, bo = c.Frame:FindFirstChild("Title"), c.Frame:FindFirstChild("Body")
    h.expect(ti.TextSize).toBe(R.Theme.Font.label.Size)
    h.expect(ti.FontFace.Weight).toBe(h.roblox.Enum.FontWeight.Medium)
    h.expect(ti.TextTruncate).toBe(h.roblox.Enum.TextTruncate.AtEnd)
    h.expect(bo.TextSize).toBe(R.Theme.Font.muted.Size)
  end)
  h.it("reskin closure recolours the banner background", function()
    local fns = {}
    local reg = function(fn) fns[#fns + 1] = fn; return function() end end
    local c = Card.new({ Banner = "rbxassetid://1", Theme = R.Theme, AccentReg = reg })
    local banner = c.Frame:FindFirstChild("Banner")
    banner.BackgroundColor3 = h.roblox.Color3.fromRGB(1, 2, 3)
    for _, fn in ipairs(fns) do fn("mode") end
    h.expect(banner.BackgroundColor3).toBe(R.Theme.Colors.surface)
  end)
  h.it("a resolvable banner reserves its slot synchronously and fills when the async resolve lands", function()
    local Asset = R.Asset
    local oResolvable, oAsync = Asset.resolvable, Asset.imageAsync
    local pending
    Asset.resolvable = function(v) return v == "https://x/y.png" end
    Asset.imageAsync = function(v, cb) pending = cb end     -- URL path: cb runs later on another thread
    local ok, err = pcall(function()
      local c = Card.new({ Banner = "https://x/y.png", Title = "T", Theme = R.Theme })
      local banner = c.Frame:FindFirstChild("Banner")
      h.expect(banner ~= nil).toBeTruthy()
      h.expect(banner.Image).toBe("")
      h.expect(banner.BackgroundColor3).toBe(R.Theme.Colors.surface)
      h.expect(c.Frame:FindFirstChild("Title").LayoutOrder > banner.LayoutOrder).toBeTruthy()
      pending("rbxassetid://9")
      h.expect(banner.Image).toBe("rbxassetid://9")
    end)
    Asset.resolvable, Asset.imageAsync = oResolvable, oAsync
    if not ok then error(err, 0) end
  end)
  h.it("Destroy tears the action buttons down through their own Destroy", function()
    -- Parent == nil alone proves nothing: the mock's Destroy is recursive, so the card frame
    -- unparents its buttons whatever the maid holds. Counting the AccentReg unregisters is the
    -- real probe -- one per button control plus the card's own closure -- and it only reaches
    -- zero-leak if Card gave the control (not control.Frame) to its maid.
    local unregs = 0
    local reg = function(_) return function() unregs = unregs + 1 end end
    local c = Card.new({ Title = "T", Buttons = { { Text = "OK" }, { Text = "Cancel" } },
      Theme = R.Theme, AccentReg = reg })
    local btn = c.Frame:FindFirstChild("Actions"):FindFirstChildOfClass("TextButton")
    h.expect(unregs).toBe(0)
    c.Destroy()
    h.expect(unregs).toBe(3)          -- card + 2 action buttons
    h.expect(btn.Parent).toBe(nil)
    h.expect(c.Frame.Parent).toBe(nil)
  end)
end)
h.run()
