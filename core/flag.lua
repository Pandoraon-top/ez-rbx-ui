-- Bind a control's value to a Config flag: register default, restore saved value,
-- initialize the control, and return commit(v) which applies + persists.
local Flag = {}

-- Same value: equal, or (multi-select picks, colour arrays) tables with the same keys and values.
local function same(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
-- A copy, so a caller changing its own table in place still reads as a change next time.
local function snapshot(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = x end
  return t
end

-- commit(v) with the value the control already shows repaints nothing (a hub mirroring its state
-- every few seconds paid six same-value writes per control per tick) -- but only for a control that
-- passes `current`, a function returning the value it holds right now. Both have to match: the
-- live value (a control may change its own value off this path: a select box pruning picks when
-- its options change) and the last value painted here (the live value may be the caller's own
-- table, changed in place). A control without `current` (its apply does more than paint: clamps,
-- bounds, validation) applies every commit, as before. Whatever the config applies itself (a
-- reset, a profile load) goes through the same bookkeeping.
function Flag.bind(opts, default, apply, current)
  opts = opts or {}
  local config, flag = opts.Config, opts.Flag
  local value = default
  local shown
  local function show(v) apply(v); shown = snapshot(v) end   -- recorded once painted
  if config and flag then
    config:Register(flag, default, show)
    local saved = config:Get(flag)
    if saved ~= nil then value = saved end
  end
  show(value)
  return function(v)
    if current and same(v, shown) and same(v, current()) then
      -- the config may hold something else (written around the control): keep it in step
      if config and flag and not same(config:Get(flag), v) then config:Set(flag, v) end
      return
    end
    show(v)
    if config and flag then config:Set(flag, v) end
  end
end

return Flag
