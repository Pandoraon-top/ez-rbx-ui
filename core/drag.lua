-- Deps injected via Init(R) (bundler cannot rewrite require() inside embedded modules).
-- A single mouse+touch drag helper. The fix vs. the old copy-pasted pattern: it captures
-- the SPECIFIC InputObject that started a touch drag and only reacts to that object's
-- movement, so stray/secondary touches and other drag handlers can't cross-fire — the
-- root cause of the mobile "drag to shrink grows it instead" bug.
local UserInputService = game:GetService("UserInputService")

local Drag = {}

-- Drag.bind(target, opts, maid)
--   target  : a GuiObject that receives InputBegan
--   opts.onBegin(input)             optional; drag started
--   opts.onChange(dx, dy, position) optional; delta from the start point + current position
--   opts.onEnd()                    optional; drag released
--   opts.isActive() -> boolean      optional; return false to ignore a begin
--   maid    : a Maid that owns the connections
-- The global InputChanged / InputEnded listeners exist only while a drag is held: connected on
-- the press, dropped on the release. A window binds four of these, and permanent listeners ran on
-- every mouse movement event of the whole session, drag or not.
function Drag.bind(target, opts, maid)
  local mouseDown = false
  local activeTouch = nil
  local startPos = nil
  local changeConn, endConn, blurConn
  local change, finish
  local function stopListening()
    if changeConn then changeConn:Disconnect(); changeConn = nil end
    if endConn then endConn:Disconnect(); endConn = nil end
    if blurConn then blurConn:Disconnect(); blurConn = nil end
  end
  -- Alt-tab mid-drag: Roblox sends no InputEnded for the held button, so the focus loss ends the
  -- drag (and drops the listeners) itself.
  local function abandon()
    if not startPos then return end
    mouseDown = false; activeTouch = nil; startPos = nil
    stopListening()
    if opts.onEnd then opts.onEnd() end
  end
  local function listen()
    if changeConn then return end
    changeConn = UserInputService.InputChanged:Connect(change)
    endConn = UserInputService.InputEnded:Connect(finish)
    local blur = UserInputService.WindowFocusReleased
    if blur then blurConn = blur:Connect(abandon) end
  end

  local function begin(input)
    if opts.isActive and not opts.isActive() then return end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 then
      mouseDown = true; startPos = input.Position
    elseif t == Enum.UserInputType.Touch then
      activeTouch = input; startPos = input.Position
    else
      return
    end
    listen()
    if opts.onBegin then opts.onBegin(input) end
  end

  function change(input)
    if not startPos then return end
    local isMouse = mouseDown and input.UserInputType == Enum.UserInputType.MouseMovement
    local isTouch = activeTouch ~= nil and input == activeTouch
    if not (isMouse or isTouch) then return end
    local p = input.Position
    if opts.onChange then opts.onChange(p.X - startPos.X, p.Y - startPos.Y, p) end
  end

  function finish(input)
    local t = input.UserInputType
    local relevant = (mouseDown and t == Enum.UserInputType.MouseButton1)
      or (activeTouch ~= nil and input == activeTouch)
    if not relevant then return end
    mouseDown = false; activeTouch = nil; startPos = nil
    stopListening()
    if opts.onEnd then opts.onEnd() end
  end

  maid:Give(target.InputBegan:Connect(begin))
  maid:Give(target.InputEnded:Connect(finish))
  maid:Give(stopListening)
end

return Drag
