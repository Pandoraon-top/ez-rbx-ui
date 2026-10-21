-- In-game benchmark: what a hub actually costs on THIS client, in numbers you can paste back.
--
-- Builds a hub shaped like a real one (9 tabs, 57 toggles, 49 dropdowns, 21 accordions, ...),
-- then measures download, compile and build time and the frame time of everyday moments: idle,
-- hiding and showing the window, a toast, switching tabs, opening accordions. Frame times come
-- from RenderStepped, so they include the game itself: read every scenario against the idle line.
--
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Pandoraon-top/ez-rbx-ui/main/example/perf.lua"))()
--
-- Compare libraries on the same client by naming another bundle first:
--   getgenv().EZUI_BENCH_URL = "https://github.com/alfin-efendy/ez-rbx-ui/releases/latest/download/ez-rbx-ui.lua"
--
-- Run it ON ITS OWN: EzUI keeps one window per client, so the bench replaces any hub window that is
-- already open. Rejoin (or re-execute the hub) afterwards.
--
-- The report is printed to the console (F9) and copied to the clipboard when the executor can.
-- Nothing here is shipped with the library; it only reads the bundle at the URL.

local DEFAULT_URL = "https://raw.githubusercontent.com/Pandoraon-top/ez-rbx-ui/main/dist/ez-rbx-ui.lua"
local env = (type(getgenv) == "function" and getgenv()) or _G
local URL = env.EZUI_BENCH_URL or DEFAULT_URL

local RunService = game:GetService("RunService")
local frameSignal = RunService.RenderStepped or RunService.Heartbeat
local lines = {}

local function say(fmt, ...)
  local line = string.format(fmt, ...)
  lines[#lines + 1] = line
  print("[EzUI bench] " .. line)
end

local function ms(seconds) return seconds * 1000 end

-- Frame times while `action` runs and for `seconds` after it: mean FPS, the 95th percentile and
-- the single worst frame. The worst frame is the hitch you feel; the mean hides it.
local function sample(label, seconds, action)
  local times = {}
  local conn = frameSignal:Connect(function(dt) times[#times + 1] = dt end)
  local ok, err = true, nil
  if action then ok, err = pcall(action) end
  task.wait(seconds)
  conn:Disconnect()
  if not ok then say("%-18s n/a (%s)", label, tostring(err)); return end
  if #times == 0 then say("%-18s no frames sampled", label); return end
  table.sort(times)
  local sum = 0
  for _, dt in ipairs(times) do sum = sum + dt end
  local p95 = times[math.max(1, math.ceil(#times * 0.95))]
  say("%-18s %5.1f fps   p95 %5.1f ms   worst %5.1f ms   (%d frames)",
    label, #times / sum, ms(p95), ms(times[#times]), #times)
end

local function timed(fn)
  local t0 = os.clock()
  local result = fn()
  return result, os.clock() - t0
end

say("library: %s", URL)

local src, tDownload = timed(function() return game:HttpGet(URL) end)
local chunk, tCompile = timed(function() return loadstring(src) end)
assert(chunk, "the bundle at EZUI_BENCH_URL does not compile")
local EzUI, tInit = timed(chunk)
say("download %.0f ms (%d KB)   compile %.0f ms   init %.0f ms", ms(tDownload), math.floor(#src / 1024), ms(tCompile), ms(tInit))

-- the build: one synchronous burst, the way most hubs do it (the worst execute case)
local window, tabs, accordions = nil, {}, {}
local _, tBuild = timed(function()
  window = EzUI:CreateWindow({ Title = "EzUI bench", Subtitle = "measuring", FloatingToggle = true })
  for i = 1, 9 do tabs[i] = window:AddTab({ Name = "Tab " .. i, Icon = "home" }) end
  for i = 1, 21 do accordions[i] = tabs[(i - 1) % 9 + 1]:AddAccordion({ Title = "Section " .. i }) end
  local function slot(i) if i % 2 == 0 then return accordions[(i % 21) + 1] end return tabs[(i - 1) % 9 + 1] end
  for i = 1, 57 do slot(i):AddToggle({ Text = "Toggle " .. i }) end
  for i = 1, 49 do slot(i):AddSelectBox({ Text = "Select " .. i, Options = { "One", "Two", "Three", "Four" } }) end
  for i = 1, 19 do slot(i):AddTextBox({ Text = "Text " .. i }) end
  for i = 1, 13 do slot(i):AddNumberBox({ Text = "Number " .. i }) end
  for i = 1, 19 do slot(i):AddButton({ Text = "Button " .. i }) end
  for i = 1, 14 do slot(i):AddParagraph("Paragraph " .. i .. ": a longer line of body text that wraps.") end
end)
local count = "?"
pcall(function() count = tostring(#window.Gui:GetDescendants()) end)
say("build %.0f ms   %s instances in the window", ms(tBuild), count)

task.wait(1) -- let the entrance finish before measuring anything
sample("idle", 2)
sample("hide + show", 1.5, function()
  window:Hide(); task.wait(0.5); window:Show()
end)
sample("toast", 3, function()
  window:Notify({ Title = "Bench", Content = "A toast counting down", Duration = 2.5 })
end)
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
sample("switch tabs", 3, function()
  for i = 2, 9 do openTab(i); task.wait(0.15) end
  openTab(1)
end)
sample("accordions", 3, function()
  for i = 1, 21, 9 do                         -- 1, 10 and 19 all live on the first tab
    accordions[i]:Toggle(); task.wait(0.3)
  end
end)

local report = table.concat(lines, "\n")
if type(setclipboard) == "function" then pcall(setclipboard, report); say("report copied to the clipboard") end
pcall(function()
  window:Notify({ Title = "Bench done", Content = "Results are in the console (F9) and the clipboard.", Duration = 6 })
end)
return report
