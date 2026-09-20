-- Deps injected via Init(R) (none needed). Resolves an Image value to a usable
-- content id. URLs are downloaded once to the executor workspace and exposed via
-- getcustomasset; every executor call is feature-detected + pcall-guarded so this
-- is a safe no-op (nil) under Studio / headless / restricted executors.
local RunService = game:GetService("RunService")

local Asset = {}
local cache = {}

-- How long a decode may be waited on once the content id is already written. Nothing left to
-- fetch at that point -- only the engine turning bytes into pixels -- so the budget is a blink,
-- not the minute a download is allowed. No theme token holds a fetch budget (reported as a
-- deviation), so a module-local fallback in the style core/animate.lua uses for FALLBACK.
local DECODE_BUDGET = 3

function Asset.Init(_) end

local function customAssetFn()
  -- Executors expose getcustomasset/getsynasset as a BARE global (the script environment), and some
  -- ALSO mirror it on _G. Read the bare global FIRST -- it matches how writefile/isfile/game are read
  -- below and is what executor docs use; many sandboxes never populate the raw _G table, so the old
  -- rawget(_G,...)-only probe returned nil and silently disabled every URL image. Fall back to
  -- rawget(_G,...) for the executors that only mirror their API there.
  local fn = getcustomasset or getsynasset or get_custom_asset
    or rawget(_G, "getcustomasset") or rawget(_G, "getsynasset") or rawget(_G, "get_custom_asset")
  if type(fn) == "function" then return fn end
  return nil
end

local function getCustomAsset(path)
  local fn = customAssetFn()
  if not fn then return nil end
  local ok, res = pcall(fn, path)
  if ok and type(res) == "string" then return res end
  return nil
end

local function djb2(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 2147483647 end
  return h
end

local function fetchUrl(url)
  if cache[url] ~= nil then return cache[url] or nil end
  local hasFS = type(writefile) == "function" and type(isfile) == "function"
  if not hasFS then cache[url] = false; return nil end
  local ext = url:match("%.(%w%w%w%w?)$") or "png"
  local path = "EzUI/assets/" .. djb2(url) .. "." .. ext
  if type(makefolder) == "function" then pcall(makefolder, "EzUI"); pcall(makefolder, "EzUI/assets") end
  if not isfile(path) then
    local body
    if type(game.HttpGet) == "function" then
      local ok, data = pcall(function() return game:HttpGet(url) end)
      if ok then body = data end
    end
    if not body and type(request) == "function" then
      local ok, resp = pcall(request, { Url = url, Method = "GET" })
      if ok and type(resp) == "table" then body = resp.Body end
    end
    if not body then cache[url] = false; return nil end
    local okw = pcall(writefile, path, body)
    if not okw then cache[url] = false; return nil end
  end
  local content = getCustomAsset(path)
  cache[url] = content or false
  return content
end

function Asset.image(value)
  if type(value) ~= "string" or value == "" then return nil end
  if value:match("^rbxassetid://") or value:match("^rbxasset://") or value:match("^rbxthumb://") then return value end
  if value:match("^https?://") then return fetchUrl(value) end
  if value:match("^%d+$") then return "rbxassetid://" .. value end
  return nil
end

-- True if `value` can become an image content id in THIS environment without guessing: a Roblox
-- asset/thumb/numeric id (always), or an http(s) URL when the executor exposes the download+cache
-- globals (writefile/isfile/getcustomasset). Lets callers reserve UI space before the fetch lands.
function Asset.resolvable(value)
  if type(value) ~= "string" or value == "" then return false end
  if value:match("^rbxassetid://") or value:match("^rbxasset://")
      or value:match("^rbxthumb://") or value:match("^%d+$") then return true end
  if value:match("^https?://") then
    if cache[value] then return true end
    if cache[value] == false then return false end   -- already tried and failed: do not promise it again
    return type(writefile) == "function" and type(isfile) == "function" and customAssetFn() ~= nil
  end
  return false
end

-- Resolve an image value WITHOUT blocking the caller. Instant ids invoke `cb` synchronously;
-- http(s) URLs download on a background thread (game:HttpGet yields) and `cb` runs once the content
-- id is ready -- so a title bar / FAB never stalls window construction on the network. `cb` is only
-- ever called with a non-nil id. For URL fetches `cb` runs on a non-privileged thread, so any GUI
-- write inside it must be marshalled through Safe.mutate by the caller.
-- cb(id) on success. onFail() is optional and fires on EVERY path that will never call cb: an
-- unusable value, a download that failed now, and a download that failed earlier and is cached as
-- such. Without it a caller cannot tell "still fetching" from "never arriving", which is why the
-- skeleton holders used to guess with a timer instead.
function Asset.imageAsync(value, cb, onFail)
  local function fail() if onFail then onFail() end end
  if type(value) ~= "string" or value == "" then fail(); return end
  if value:match("^rbxassetid://") or value:match("^rbxasset://") or value:match("^rbxthumb://") then
    cb(value); return
  end
  if value:match("^%d+$") then cb("rbxassetid://" .. value); return end
  if value:match("^https?://") then
    if cache[value] ~= nil then
      if cache[value] then cb(cache[value]) else fail() end
      return
    end
    local spawn = (type(task) == "table" and task.spawn) or function(fn) fn() end
    spawn(function() local id = fetchUrl(value); if id then cb(id) else fail() end end)
    return
  end
  fail()   -- a string we cannot resolve at all (a bare filename, a data URI, ...)
end

-- Wait for an ImageLabel/ImageButton's sprite to DECODE, for callers that hide the slot (a
-- skeleton block, ImageTransparency 1) until the pixels are on screen.
--
-- Why this is not just GetPropertyChangedSignal("IsLoaded"): IsLoaded is written from the engine
-- side when the sprite finishes decoding, and that write does not reliably raise the Lua change
-- signal. A placeholder that trusts the signal alone therefore outlives the image it stands in
-- for -- in the field, the title logo sat under an opaque block until the caller's own give-up
-- deadline (a full minute) rather than until it had loaded. So watch BOTH: the signal (instant
-- when it does fire) and a Heartbeat poll (the one that always works), whichever comes first.
--
-- `cb(loaded)` runs AT MOST ONCE, from the change signal or from a Heartbeat callback -- so the
-- caller must still marshal its own GUI writes through Safe.mutate (the signal path is an engine
-- thread that may lack the capability). `loaded` says HOW the wait ended: true when the sprite
-- decoded, false when `budget` seconds passed without it. Either way the wait is over and the
-- caller must reveal the slot -- holding a placeholder over a sprite that will never decode only
-- hides the blank it was standing in for. Already-decoded (IsLoaded true, or nil on older clients
-- and headless) calls back synchronously with true. A destroyed host just stops, with no callback.
-- Returns a handle with Disconnect() -- maid-compatible, and idempotent.
function Asset.awaitLoaded(imageLabel, cb, budget)
  local limit = tonumber(budget) or DECODE_BUDGET
  local done, conn, hb, elapsed = false, nil, nil, 0
  local handle = {}
  function handle.Disconnect()
    done = true
    if conn then conn:Disconnect(); conn = nil end
    if hb then hb:Disconnect(); hb = nil end
  end
  local function finish(loaded)
    if done then return end
    handle.Disconnect()
    cb(loaded and true or false)
  end
  -- No label to watch: report "not loaded" rather than never reporting at all, so a caller that
  -- hides its slot until the callback reveals it instead of hanging on a wait nothing can end.
  if imageLabel == nil then finish(false); return handle end
  if imageLabel.IsLoaded ~= false then finish(true); return handle end   -- nil (headless/older) counts as decoded
  -- pcall: an exotic client may not expose the property signal at all; the poll below still works
  pcall(function()
    conn = imageLabel:GetPropertyChangedSignal("IsLoaded"):Connect(function()
      if imageLabel.IsLoaded ~= false then finish(true) end
    end)
  end)
  hb = RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + (tonumber(dt) or 0)
    if imageLabel.Parent == nil then handle.Disconnect(); return end   -- host gone: nothing to reveal
    if imageLabel.IsLoaded ~= false then finish(true)
    elseif elapsed >= limit then finish(false) end
  end)
  return handle
end

return Asset
