-- Deps injected via Init(R). Runs GUI mutations in a capability-bearing context: inline when the
-- current thread already holds the GUI ("Plugin") capability, otherwise deferred to the next
-- RunService.Heartbeat (whose callback holds the capability). This is the Roblox-executor analogue
-- of runOnUiThread/Dispatcher.Invoke -- it marshals work to a privileged context; it is NOT state
-- management. See components/selectbox.lua runLoader for the original Heartbeat:Once pattern.
local Safe = {}
local Overlay
local RunService = game:GetService("RunService")

local unpack = table.unpack or unpack   -- Luau keeps both; 5.1/LuaJIT only the global

local queue = {}          -- FIFO of deferred jobs
local flushConn = nil

function Safe.Init(R) Overlay = R.Overlay end

-- Does the CURRENT thread hold the GUI capability? Probe with a harmless, signature-free,
-- idempotent same-value write to the protected overlay root. The write is capability-gated: it
-- succeeds on the main thread / a signal handler and throws on a task.spawn/coroutine thread.
-- No attribute/name is added, so no EzUI signature leaks.
--
-- Returns `hasIt, certain`. The whole probe runs inside ONE pcall: Overlay.peek() reads
-- root.Parent, and READING a protected Instance property ALSO throws "lacking capability" on a
-- thread without it (not just writes). So peek() must be inside the pcall too -- previously it ran
-- outside, so its throw escaped the probe and Safe.mutate never reached the Heartbeat fallback.
--   root + capability    -> read+write succeed          -> true,  certain
--   root + no capability -> the read throws             -> false, certain
--   no root yet          -> nothing was actually probed -> true,  UNCERTAIN
-- That last row is the one that bit us: before a protected root exists the probe is a guess, and
-- Safe.mutate used to act on it as if it were an answer -- running the job inline on a thread that
-- did not hold the capability, where the GUI write throws and the job is lost for good (the title
-- logo that never arrived when its asset was already cached, so the fetch never yielded and the
-- callback landed mid-construction, before the overlay root existed). `certain` lets mutate treat
-- a guess as a guess.
local function defaultHasCapability()
  local probed = false
  local ok = pcall(function()
    local root = Overlay and Overlay.peek and Overlay.peek()
    if root then probed = true; root.BackgroundTransparency = root.BackgroundTransparency end
  end)
  if not ok then return false, true end   -- the protected read threw: that IS an answer
  return true, probed
end

local custom = nil
-- A test-installed check speaks for itself: whatever it says is taken as certain.
local function hasCapability()
  if custom then return custom() and true or false, true end
  return defaultHasCapability()
end
function Safe._setCapabilityCheck(fn) custom = fn end

local function flush()
  flushConn = nil
  -- Runs inside a Heartbeat callback => capability present. Drain FIFO; isolate each job so one
  -- failure does not abort the drain.
  local i = 1
  while i <= #queue do local job = queue[i]; i = i + 1; pcall(job) end
  for k = #queue, 1, -1 do queue[k] = nil end
end

local function enqueue(fn)
  queue[#queue + 1] = fn
  if not flushConn then flushConn = RunService.Heartbeat:Once(flush) end
end

-- Run fn in a capability-bearing context. Inline (synchronous) if the current thread has the
-- capability; otherwise enqueue and flush on the next Heartbeat (FIFO preserved).
--
-- When the probe was only a GUESS (no protected root to test against, see above) the job still
-- runs inline -- but under pcall, so a refusal falls back to the Heartbeat instead of throwing on
-- a background thread where nobody catches it and the write is simply lost. The retry re-runs
-- `fn`; every caller here is a property write or an idempotent teardown, so running the prefix of
-- one twice is a no-op, and losing it entirely is not.
function Safe.mutate(fn)
  local ok, certain = hasCapability()
  if ok and certain then return fn() end
  if ok then
    local res = { pcall(fn) }
    if res[1] then return unpack(res, 2, #res) end
  end
  enqueue(fn)
end

return Safe
