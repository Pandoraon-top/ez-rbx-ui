local h = require("tests.helper")

h.describe("safe", function()
  local function fresh()
    local R = h.loadLib()
    R.Safe._setCapabilityCheck(nil)  -- default probe (mock has no protected root -> inline)
    return R.Safe
  end

  h.it("runs inline and returns the value when capability is present", function()
    local Safe = fresh()
    local ran = false
    local ret = Safe.mutate(function() ran = true; return 42 end)
    h.expect(ran).toBe(true)        -- synchronous, no Heartbeat needed
    h.expect(ret).toBe(42)
  end)

  h.it("defers to Heartbeat when capability is absent, preserving FIFO order", function()
    local Safe = fresh()
    Safe._setCapabilityCheck(function() return false end)
    local log = {}
    Safe.mutate(function() log[#log + 1] = "a" end)
    Safe.mutate(function() log[#log + 1] = "b" end)
    Safe.mutate(function() log[#log + 1] = "c" end)
    h.expect(#log).toBe(0)                 -- nothing ran yet
    h.mock.stepHeartbeat(0)                -- flush
    h.expect(table.concat(log)).toBe("abc")
    Safe._setCapabilityCheck(nil)
  end)

  h.it("drains fully: a second Heartbeat is a no-op", function()
    local Safe = fresh()
    Safe._setCapabilityCheck(function() return false end)
    local n = 0
    Safe.mutate(function() n = n + 1 end)
    h.mock.stepHeartbeat(0)
    h.mock.stepHeartbeat(0)               -- queue already drained
    h.expect(n).toBe(1)
    Safe._setCapabilityCheck(nil)
  end)

  h.it("default probe treats a throwing peek (protected read without capability) as no-capability, deferring not erroring", function()
    -- On a thread without the "Plugin" capability, the probe READS the protected overlay root
    -- (Overlay.peek -> root.Parent), which itself throws "lacking capability". The whole probe
    -- must swallow that and report "no capability" so Safe.mutate falls back to the Heartbeat --
    -- it must NOT let the throw escape (the original bug: peek() was called outside the pcall).
    local R = h.loadLib()
    R.Safe._setCapabilityCheck(nil)                    -- real default probe
    local realPeek = R.Overlay.peek
    R.Overlay.peek = function()
      error("The current thread cannot access 'Instance' (lacking capability Plugin)")
    end
    local ran = false
    local ok = pcall(function() R.Safe.mutate(function() ran = true end) end)
    R.Overlay.peek = realPeek                          -- restore shared singleton before asserting
    h.expect(ok).toBe(true)                            -- probe swallowed the throw; mutate did not error
    h.expect(ran).toBe(false)                          -- deferred, not run inline
    h.mock.stepHeartbeat(0)                            -- flush in a capability-bearing context
    h.expect(ran).toBe(true)
    R.Safe._setCapabilityCheck(nil)
  end)

  -- FIELD BUG. Before any protected root exists the probe has nothing to test against, so it
  -- ASSUMES capability -- and Safe.mutate used to act on that guess as if it were an answer,
  -- running the job inline on whatever thread called it. On a real executor that thread is often
  -- a task.spawn/task.delay one (an Asset.imageAsync callback for an already-cached logo comes
  -- back mid-construction, before the window has built its overlay root), the GUI write throws
  -- "lacking capability", the spawned thread dies with it -- and the write is gone for good. That
  -- is the title logo that never arrived, as opposed to the one that arrived late.
  --
  -- What this test DOES prove: with no root to probe, a job that is refused still runs, on the
  -- next Heartbeat, and the refusal never escapes Safe.mutate. What it does NOT prove: that a
  -- real Roblox capability refusal looks like this. The mock has no capability model, so the
  -- refusal is a thrown error with the engine's own message -- which is exactly the shape the
  -- engine raises, but it is a stand-in, not the real thing.
  h.it("a GUESSED capability that turns out wrong defers the job instead of losing it", function()
    local R = h.loadLib()
    R.Safe._setCapabilityCheck(nil)          -- real default probe
    R.Overlay.reset()                        -- ...and nothing for it to probe: the guess path
    h.expect(R.Overlay.peek()).toBeNil()
    local tries, ran = 0, false
    local ok = pcall(function()
      R.Safe.mutate(function()
        tries = tries + 1
        if tries == 1 then                   -- first attempt: the thread did not hold it after all
          error("The current thread cannot access 'Instance' (lacking capability Plugin)")
        end
        ran = true
      end)
    end)
    h.expect(ok).toBe(true)                  -- the refusal did not escape onto the caller's thread
    h.expect(ran).toBe(false)                -- nothing landed yet...
    h.mock.stepHeartbeat(0)                  -- ...until a context that really does hold it
    h.expect(ran).toBe(true)
    h.expect(tries).toBe(2)
  end)

  h.it("still returns the value inline on the guess path when the job is not refused", function()
    local R = h.loadLib()
    R.Safe._setCapabilityCheck(nil)
    R.Overlay.reset()
    local ret = R.Safe.mutate(function() return 7, "seven" end)
    h.expect(ret).toBe(7)                    -- the guess path must not swallow the return value
  end)
end)

h.run()
