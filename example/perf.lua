-- In-game benchmark: what a hub actually costs on THIS client, in numbers you can paste back.
--
-- Builds a hub shaped like a real one (10 tabs; one page of about 200 controls with 15 accordions
-- and status paragraphs), sized the way phone hubs ship it (620x400 fitted with SetUIScale), then
-- measures download, compile and build time and the frame cost of everyday moments: idle, the
-- window minimized, the acrylic layers switched off, status text changing every second, toasts,
-- tab switches and accordions. Frame times come from RenderStepped, so they include the game
-- itself: read every scenario against the "no window" and "open idle" lines.
--
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Pandoraon-top/ez-rbx-ui/main/example/perf.lua"))()
--
-- Optional knobs, set before running:
--   getgenv().EZUI_BENCH_URL   = "<bundle url>"  -- compare another release on the same client
--   getgenv().EZUI_BENCH_SCALE = 0.78            -- force a UI scale (default: fit 620x400 to the screen)
--   getgenv().EZUI_BENCH_SECS  = 4               -- seconds per scenario (default 3)
--
-- Run it ON ITS OWN: EzUI keeps one window per client, so the bench replaces any hub window that is
-- already open. Rejoin (or re-execute the hub) afterwards.
--
-- Next to the frame times, every line reports what the engine says about rendering when the client
-- lets a script read it (Stats): GPU and render-CPU time per frame and the 2D UI draw calls. Those
-- separate a UI that is expensive to DRAW (fill rate, layers) from one that is expensive to UPDATE.
-- The report is printed to the console (F9) and copied to the clipboard when the executor can.
-- Nothing here is shipped with the library; it only reads the bundle at the URL.

local DEFAULT_URL = "https://raw.githubusercontent.com/Pandoraon-top/ez-rbx-ui/main/dist/ez-rbx-ui.lua"
local env = (type(getgenv) == "function" and getgenv()) or _G
local URL = env.EZUI_BENCH_URL or DEFAULT_URL
local SECS = tonumber(env.EZUI_BENCH_SECS) or 3
local FIXED_W, FIXED_H = 620, 400   -- the fixed size phone hubs ship

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local frameSignal = RunService.RenderStepped or RunService.Heartbeat
local lines = {}

local function say(fmt, ...)
  local line = string.format(fmt, ...)
  lines[#lines + 1] = line
  print("[EzUI bench] " .. line)
end

local function ms(seconds) return seconds * 1000 end

-- Engine render counters, when this client exposes them to scripts. Each key is probed once: a
-- client that refuses a read refuses it every frame, and the bench must not pay a failing pcall
-- per frame. Printed as the engine reports them (the units are the engine's).
local STATS = {
  { key = "RenderGPUFrameTime", tag = "gpu" }, { key = "RenderCPUFrameTime", tag = "rcpu" },
  { key = "UI2DDrawcallCount", tag = "ui-draws" }, { key = "UI2DTriangleCount", tag = "ui-tris" },
}
local readable, unreadable = {}, {}
for _, st in ipairs(STATS) do
  if pcall(function() return Stats[st.key] end) then readable[#readable + 1] = st
  else unreadable[#unreadable + 1] = st.key end
end

-- Frame times over `seconds` from the moment `action` starts: mean FPS, the 95th percentile and
-- the single worst frame (the hitch you feel; the mean hides it), plus the averaged engine stats.
-- `action` runs on its own thread, so every line covers the same window however long it takes.
local function sample(label, seconds, action)
  local times, sums, n = {}, {}, 0
  for i = 1, #readable do sums[i] = 0 end
  local conn = frameSignal:Connect(function(dt)
    times[#times + 1] = dt
    n = n + 1
    for i, st in ipairs(readable) do sums[i] = sums[i] + (tonumber(Stats[st.key]) or 0) end
  end)
  local ok, err = true, nil
  if action then
    task.spawn(function()
      local okA, errA = pcall(action)
      if not okA then ok, err = false, errA end
    end)
  end
  task.wait(seconds)
  conn:Disconnect()
  if not ok then say("%-24s n/a (%s)", label, tostring(err)); return end
  if #times == 0 then say("%-24s no frames sampled", label); return end
  table.sort(times)
  local sum = 0
  for _, dt in ipairs(times) do sum = sum + dt end
  local p95 = times[math.max(1, math.ceil(#times * 0.95))]
  local stats = {}
  for i, st in ipairs(readable) do
    stats[#stats + 1] = string.format("%s %.2f", st.tag, sums[i] / math.max(1, n))
  end
  say("%-24s %5.1f fps   p95 %5.1f ms   worst %5.1f ms   %s", label, #times / sum, ms(p95), ms(times[#times]),
    table.concat(stats, "  "))
end

local function timed(fn)
  local t0 = os.clock()
  local result = fn()
  return result, os.clock() - t0
end

say("library: %s", URL)
say("engine stats: %s%s", #readable > 0 and "gpu = Stats.RenderGPUFrameTime, rcpu = RenderCPUFrameTime, ui-draws/ui-tris = UI2D counts" or "none readable",
  #unreadable > 0 and ("   (not readable here: " .. table.concat(unreadable, ", ") .. ")") or "")

-- the game alone, before anything is built: the floor every other line sits on
sample("no window", SECS)

local src, tDownload = timed(function() return game:HttpGet(URL) end)
local chunk, tCompile = timed(function() return loadstring(src) end)
assert(chunk, "the bundle at EZUI_BENCH_URL does not compile")
local EzUI, tInit = timed(chunk)
say("download %.0f ms (%d KB)   compile %.0f ms   init %.0f ms", ms(tDownload), math.floor(#src / 1024), ms(tCompile), ms(tInit))

-- Three sets of 15 status paragraphs, one per place a hub keeps them: at the top of the open page
-- (on screen), inside a collapsed accordion further down, and on a tab that is not selected. Only
-- one set ticks at a time.
local STATUS_N = 15
local status = { page = {}, collapsed = {}, otherTab = {} }

-- the build: one synchronous burst, the way most hubs do it (the worst execute case)
local window, tabs, accordions, closedAcc = nil, {}, {}, nil
local _, tBuild = timed(function()
  window = EzUI:CreateWindow({ Title = "EzUI bench", Subtitle = "measuring", FloatingToggle = true })
  for i = 1, 10 do tabs[i] = window:AddTab({ Name = "Tab " .. i, Icon = "home" }) end
  local page = tabs[1]
  -- first on the page, so they are inside the visible part of a 400 px window
  for i = 1, STATUS_N do status.page[i] = page:AddParagraph("Status " .. i .. ": idle") end
  for i = 1, 15 do accordions[i] = page:AddAccordion({ Title = "Section " .. i, Expanded = i <= 3 }) end
  -- about 200 controls on the first page; every other one lands in an accordion
  local function slot(i) if i % 2 == 0 then return accordions[(i % 15) + 1] end return page end
  for i = 1, 50 do slot(i):AddToggle({ Text = "Toggle " .. i }) end
  for i = 1, 30 do slot(i):AddSelectBox({ Text = "Select " .. i, Options = { "One", "Two", "Three", "Four" } }) end
  for i = 1, 20 do slot(i):AddNumberBox({ Text = "Number " .. i }) end
  for i = 1, 10 do slot(i):AddTextBox({ Text = "Text " .. i }) end
  for i = 1, 15 do slot(i):AddButton({ Text = "Button " .. i }) end
  for i = 1, 30 do slot(i):AddParagraph("Note " .. i .. ": a longer line of body text that wraps onto a second line.") end
  closedAcc = page:AddAccordion({ Title = "Status (collapsed)" })
  for i = 1, STATUS_N do
    status.collapsed[i] = closedAcc:AddParagraph("Status " .. i .. ": idle")
    status.otherTab[i] = tabs[2]:AddParagraph("Status " .. i .. ": idle")
  end
  -- the other tabs carry a modest page each, like a real hub
  for t = 2, 10 do
    for i = 1, 12 do tabs[t]:AddToggle({ Text = "Option " .. t .. "." .. i }) end
    for i = 1, 4 do tabs[t]:AddSelectBox({ Text = "Pick " .. t .. "." .. i, Options = { "A", "B", "C" } }) end
  end
end)
local count = "?"
pcall(function() count = tostring(#window.Gui:GetDescendants()) end)
say("build %.0f ms   %s instances in the window", ms(tBuild), count)

-- Phone-shaped window: the fixed 620x400 hubs ship, fitted to this screen by SetUIScale.
local scale = tonumber(env.EZUI_BENCH_SCALE)
pcall(function()
  local vp = workspace.CurrentCamera.ViewportSize
  scale = scale or math.min(1, vp.X * 0.9 / FIXED_W, vp.Y * 0.9 / FIXED_H)
  window.Main.Size = UDim2.new(0, FIXED_W, 0, FIXED_H)
  window:SetUIScale(scale)
  say("window %dx%d at UI scale %.2f on a %dx%d viewport", FIXED_W, FIXED_H, scale, vp.X, vp.Y)
end)

task.wait(1) -- let the entrance finish before measuring anything
sample("open idle", SECS)

-- ---- the acrylic stack ----------------------------------------------------------------------
-- Switched off layer by layer on the live window and put back afterwards. The noise is the one
-- tiled image; "flat" also drops the sheen, the glint, both gradients and the drop shadow.
local function frost(on, noiseOnly)
  local main = window.Main
  local noise = main:FindFirstChild("AcrylicNoise")
  if noise then noise.Visible = on end
  if noiseOnly then return end
  for _, name in ipairs({ "AcrylicSheen", "AcrylicGlint" }) do
    local layer = main:FindFirstChild(name)
    if layer then layer.Visible = on end
  end
  local grad = main:FindFirstChildOfClass("UIGradient")
  if grad then grad.Enabled = on end
  local stroke = main:FindFirstChildOfClass("UIStroke")
  local rim = stroke and stroke:FindFirstChildOfClass("UIGradient")
  if rim then rim.Enabled = on end
  local shadow = window.Gui:FindFirstChild("WindowShadow")
  if shadow then shadow.Visible = on end
end
sample("open, no noise", SECS, function() frost(false, true) end)
sample("open, flat (no frost)", SECS, function() frost(false) end)
frost(true)
task.wait(0.5)

-- the minimize button hides the whole window; measured once the fold has finished
window:Hide()
task.wait(0.6)
sample("minimized", SECS)
window:Show()
task.wait(1)

-- ---- status paragraphs ----------------------------------------------------------------------
-- 15 independent loops, each writing NEW text about once a second, like a hub's status lines.
local function runStatus(set, seconds)
  local stop = false
  for i, p in ipairs(set) do
    task.spawn(function()
      local n = 0
      while not stop do
        n = n + 1
        p.SetText(string.format("Status %d: hatched %d eggs, %d pets in bag, last %s", i, n * 3, n % 40, os.date("%H:%M:%S")))
        task.wait(1 + i * 0.03)
      end
    end)
  end
  task.wait(seconds)
  stop = true
end
sample("status 15/s on screen", SECS, function() runStatus(status.page, SECS) end)
sample("status 15/s collapsed", SECS, function() runStatus(status.collapsed, SECS) end)
sample("status 15/s other tab", SECS, function() runStatus(status.otherTab, SECS) end)
window:Hide()
task.wait(0.6)
sample("status 15/s minimized", SECS, function() runStatus(status.page, SECS) end)
window:Show()
task.wait(1)

-- ---- everyday moments -----------------------------------------------------------------------
sample("hide + show", SECS, function()
  window:Hide(); task.wait(0.5); window:Show()
end)
-- a burst like a hub announcing every hatch (2 s of toasts inside the window)
sample("toasts (burst)", SECS, function()
  for i = 1, 5 do
    window:Notify({ Title = "Hatched", Message = "Pet " .. i .. " joined the backpack", Duration = 3 })
    task.wait(0.4)
  end
end)
task.wait(3.5)
-- A tab switch the way a click does it. firesignal (most executors) goes through the window's own
-- handler; without it, deselect the old page and select the new one by hand.
local current = 1
local function openTab(i)
  local tab = tabs[i]
  if type(firesignal) == "function" and tab.Button then
    firesignal(tab.Button.MouseButton1Click)
  else
    local dir = (i >= current) and 1 or -1
    tabs[current]:Deselect(dir); tab:Select(dir)
  end
  current = i
end
sample("switch tabs", SECS, function()
  for i = 2, 10 do openTab(i); task.wait(0.15) end
  openTab(1)
end)
sample("accordions", SECS, function()
  for i = 4, 12, 4 do accordions[i]:Toggle(); task.wait(0.3) end
end)

local report = table.concat(lines, "\n")
if type(setclipboard) == "function" then pcall(setclipboard, report); say("report copied to the clipboard") end
pcall(function()
  window:Notify({ Title = "Bench done", Message = "Results are in the console (F9) and the clipboard.", Duration = 6 })
end)
return report
