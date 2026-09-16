-- Deps injected via Init(R) (the bundler cannot rewrite require() inside embedded modules).
local TweenService = game:GetService("TweenService")

local Animate = {}
local Theme
local motionTbl -- Animate.useMotion override (a window's merged theme.Motion); nil = Theme.Motion
-- Reduced motion is process-wide (single-window norm). `explicit` remembers that a user/config
-- choice was made so a later applyDefault (OS preference) never overrides it.
local enabled, explicit = true, false
-- Last-resort duration when a token is unknown everywhere (keeps a typo from throwing in Studio).
local DEFAULT_DUR = 0.18
-- Today's values for tokens that core/theme.lua may not define yet (F1 lands them in parallel);
-- theme tokens win whenever present, these only cover the gap.
local FALLBACK = { spin = 0.8, exit = 0.14, exitScale = 0.96, popSlide = 6 }

function Animate.Init(R)
  Theme = R.Theme
  Animate.Motion = motionTbl or Theme.Motion
end

Animate.EASING = {
  pop = Enum.EasingStyle.Back, smooth = Enum.EasingStyle.Quint,
  enter = Enum.EasingStyle.Quint, exit = Enum.EasingStyle.Quart,
  snap = Enum.EasingStyle.Quad or Enum.EasingStyle.Quart, -- Quad guard: older enum tables lack it
}
Animate.DIR = { In = Enum.EasingDirection.In, Out = Enum.EasingDirection.Out, InOut = Enum.EasingDirection.InOut }

-- Motion token lookup: useMotion table -> Theme.Motion -> FALLBACK. Only numbers count (a nested
-- token group like Motion.shake must never reach TweenInfo); returns nil when unknown.
local function token(name)
  local v = motionTbl and motionTbl[name]
  if type(v) ~= "number" and Theme and Theme.Motion then v = Theme.Motion[name] end
  if type(v) == "number" then return v end
  return FALLBACK[name]
end

local function resolve(duration)
  if type(duration) == "number" then return duration end
  if type(duration) == "string" then return token(duration) or DEFAULT_DUR end
  return DEFAULT_DUR
end

-- Delay is optional everywhere and must reach TweenInfo.new as a number (nil delayTime is not
-- verified safe in Roblox): nil/unknown token -> 0.
local function resolveDelay(delay)
  if type(delay) == "number" then return delay end
  if type(delay) == "string" then return token(delay) or 0 end
  return 0
end

-- Point resolve() at a window's merged theme.Motion so CreateWindow{ Theme = { Motion = {...} } }
-- applies. Process-wide like setEnabled; nil restores the Theme defaults.
function Animate.useMotion(tbl)
  motionTbl = type(tbl) == "table" and tbl or nil
  Animate.Motion = motionTbl or (Theme and Theme.Motion)
end

function Animate.info(duration, style, dir, delay)
  return TweenInfo.new(duration, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out, 0, false, delay or 0)
end

-- Explicit choice (SetAnimationsEnabled / config.Animations): last writer wins.
function Animate.setEnabled(b) enabled = b and true or false; explicit = true end
-- Environment default (OS reduce-motion): only applies while nobody chose explicitly.
function Animate.applyDefault(b)
  if not explicit then enabled = b and true or false end
  return enabled
end
function Animate.isEnabled() return enabled end
function Animate.isExplicit() return explicit end

-- Stub returned when motion is disabled: the goal is already applied and any
-- Completed handler runs immediately (mirrors the synchronous test mock).
local function instantTween()
  return { Completed = { Connect = function(_, fn) if fn then fn() end; return { Disconnect = function() end } end } }
end

local function applyNow(instance, goalProps)
  for k, v in pairs(goalProps) do instance[k] = v end
end

function Animate.to(instance, duration, goalProps, style, dir, delay)
  if not enabled then
    applyNow(instance, goalProps)
    return instantTween()
  end
  local tween = TweenService:Create(instance, Animate.info(resolve(duration), style, dir, resolveDelay(delay)), goalProps)
  tween:Play()
  return tween
end

-- Tween, then run onComplete. Connects Completed BEFORE Play so the handler still
-- fires under the synchronous test mock (and runs immediately when motion is off).
function Animate.toThen(instance, duration, goalProps, onComplete, style, dir, delay)
  if not enabled then
    applyNow(instance, goalProps)
    if onComplete then onComplete() end
    return instantTween()
  end
  local tween = TweenService:Create(instance, Animate.info(resolve(duration), style, dir, resolveDelay(delay)), goalProps)
  if onComplete then tween.Completed:Connect(onComplete) end
  tween:Play()
  return tween
end

-- spring: a tween with a Back/Out overshoot (the library's "expressive" feel).
function Animate.springTo(instance, duration, goalProps)
  return Animate.to(instance, duration, goalProps, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- rotate convenience (defaults to a Back/Out overshoot).
function Animate.rotateTo(instance, duration, deg, style, dir)
  return Animate.to(instance, duration, { Rotation = deg },
    style or Enum.EasingStyle.Back, dir or Enum.EasingDirection.Out)
end

-- exit: Quart/In (accelerating away) — the shared "leave" curve for popovers/toasts/dialogs.
function Animate.exitTo(instance, duration, goalProps, onDone)
  return Animate.toThen(instance, duration, goalProps, onDone, Animate.EASING.exit, Animate.DIR.In)
end

-- Sequential toThen: each step { inst, dur, goal, style, dir, delay } starts from the previous
-- Completed (so the whole chain is synchronous under the mock); onDone after the last one.
function Animate.chain(steps, onDone)
  local i = 0
  local function step()
    i = i + 1
    local s = steps and steps[i]
    if not s then if onDone then onDone() end; return end
    Animate.toThen(s[1], s[2], s[3], step, s[4], s[5], s[6])
  end
  step()
end

-- Looping tween; repeatCount -1 (default) runs until Cancel. Returns { Cancel } — wrap it in a
-- function before maid:Give (maid only knows Disconnect/Destroy/functions). Never restart a
-- loop from Completed: the mock fires Completed synchronously inside Play, which would recurse.
function Animate.loop(instance, duration, goalProps, style, reverses, repeatCount)
  reverses = reverses == true
  if not enabled then
    -- Rest pose without motion: a one-way loop rests at its goal; a ping-pong loop rests where
    -- it started, so the instance is left untouched.
    if not reverses then applyNow(instance, goalProps) end
    return { Cancel = function() end }
  end
  local info = TweenInfo.new(resolve(duration), style or Enum.EasingStyle.Linear, Enum.EasingDirection.InOut,
    repeatCount or -1, reverses, 0)
  local tween = TweenService:Create(instance, info, goalProps)
  tween:Play()
  return { Cancel = function() tween:Cancel() end }
end

-- Endless Linear rotation for loader glyphs, period Motion.spin. Rest pose is Rotation 0: set
-- on start, on Cancel, and when motion is off (a static 'loader' glyph, never a frozen mid-spin one).
function Animate.spin(img, duration)
  img.Rotation = 0
  if not enabled then return { Cancel = function() img.Rotation = 0 end } end
  local handle = Animate.loop(img, duration or token("spin"), { Rotation = 360 }, Enum.EasingStyle.Linear, false, -1)
  return { Cancel = function() handle.Cancel(); img.Rotation = 0 end }
end

-- Ping-pong loop (attention pulse, completion pulse); cycles nil = endless.
function Animate.pulse(instance, duration, goalProps, style, cycles)
  return Animate.loop(instance, duration, goalProps, style, true, cycles or -1)
end

local function uiScaleOf(inst)
  local us = inst:FindFirstChildOfClass("UIScale")
  if not us then us = Instance.new("UIScale"); us.Parent = inst end
  return us
end

-- pop-in: scale a UIScale child from 0.9 -> 1 with a Back/Out overshoot.
function Animate.pop(inst, duration)
  local us = uiScaleOf(inst)
  us.Scale = 0.9
  return Animate.to(us, duration or "base", { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- Popover open: grow from Motion.exitScale with a Back/Out overshoot (base) while sliding
-- Motion.popSlide px into place from the anchor side (Quart/Out, fast). edge 'down' = opens
-- below its anchor, so it starts popSlide px ABOVE its final Position; 'up' starts below.
-- The final Position is the caller's own, so layout code reading it synchronously still holds.
function Animate.popIn(frame, edge)
  local us = uiScaleOf(frame)
  if not enabled then us.Scale = 1; return instantTween() end
  local target = frame.Position
  us.Scale = token("exitScale")
  if target then
    local dy = (edge == "up") and token("popSlide") or -token("popSlide")
    frame.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + dy)
    Animate.to(frame, "fast", { Position = target }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
  end
  return Animate.springTo(us, "base", { Scale = 1 })
end

-- Popover close: shrink to Motion.exitScale (Quart/In over Motion.exit), then onDone (destroy).
function Animate.popOut(frame, onDone)
  local us = uiScaleOf(frame)
  return Animate.toThen(us, token("exit"), { Scale = token("exitScale") }, onDone, Animate.EASING.exit, Animate.DIR.In)
end

return Animate
