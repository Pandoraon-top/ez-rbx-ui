-- Tab 2 — the controls whose MOVEMENT changed. Each block is a paragraph that names the thing to
-- watch, then the one control that does it. The last section turns all of it off.
return function(window)
  local tab = window:AddTab({ Name = "Motion", Icon = "activity" })

  tab:AddSection("Toggle")
  tab:AddParagraph(
    "Hold the switch down before you release it: the knob stretches toward where it is going " ..
    "(20px wide to 24px) and snaps back on release. The travel itself is a spring with a 1px " ..
    "overshoot, not a linear slide. When it lands ON, the grey track hairline dissolves so the " ..
    "accent pill is clean, and an accent glow fades in behind the track. The OFF track is its " ..
    "own tone now — it used to be the same colour as the row, which made it invisible.")
  local demoToggle = tab:AddToggle({
    Text = "Knob spring + accent glow",
    Description = "Press and hold, then release.",
    Default = true,
  })

  tab:AddSection("Slider")
  tab:AddParagraph(
    "The grab strip is 24px tall now, not 6 — you no longer have to hit the rail exactly. Hover " ..
    "the handle and it grows to 1.15; start dragging and it goes to 1.3 with an accent halo " ..
    "behind it, then springs back when you let go. The empty part of the rail has a hairline so " ..
    "it reads as a groove rather than a gap.")
  local demoSlider = tab:AddSlider({
    Text = "Handle grow + halo",
    Min = 0, Max = 100, Default = 40,
    Description = "Hover the handle, then drag it.",
  })
  -- SetValue is eased (Quint over `base`) rather than a jump, which is the same path a config
  -- restore takes. Two buttons make that visible without a drag.
  tab:AddButton({ Text = "Glide the slider to 10", Variant = "outline",
    Callback = function() demoSlider.SetValue(10) end })
  tab:AddButton({ Text = "Glide the slider to 90", Variant = "outline",
    Callback = function() demoSlider.SetValue(90) end })

  tab:AddSection("Progress")
  tab:AddParagraph(
    "The fill flows to its new value with a distance-aware duration — a nudge lands quickly, a " ..
    "long sweep takes its time. Step this to 100% and watch the completion flash: the fill " ..
    "lifts to 35% transparent the instant it arrives and fades back to solid.")
  local bar = tab:AddProgressBar({ Default = 0 })
  local stepBtn
  stepBtn = tab:AddButton({ Text = "Step +25%", Icon = "chevron-right", Callback = function()
    local v = bar.Get()
    -- wraps back to empty once full, so the button is safe to hammer and the flash is repeatable
    bar.Set(v >= 1 and 0 or math.min(1, v + 0.25))
    stepBtn.SetText(bar.Get() >= 1 and "Reset to 0%" or "Step +25%")
  end })

  tab:AddSection("Text field")
  tab:AddParagraph(
    "Click into the box. Its hairline tweens from 1px border to 2px in the ring colour rather " ..
    "than snapping, and clicking away tweens it back. The box itself sits at the window-glass " ..
    "tone — a step BELOW the row it lives in — which is the inset the Look tab talks about. " ..
    "Type something and the clear button fades in at the right edge. It also judges you on the " ..
    "way out: put a SPACE in the name and click away. The box shakes on its own X offset and " ..
    "lands back on the exact pixel it started from, the hairline turns destructive red, and an " ..
    "error line fades in underneath while the row grows for it. Remove the space, click away, " ..
    "and all three reverse.")
  tab:AddTextBox({
    Text = "Nickname",
    Placeholder = "click here",
    Description = "The ring is its own neutral token, so it does not follow the accent.",
    Clearable = true,
    MaxLength = 24,
    -- Validate runs on focus-loss and returns (ok, message). An empty field stays valid on
    -- purpose: an untouched box should not nag, so only a typed-in space is ever rejected.
    Validate = function(text)
      if text == "" or not text:find("%s") then return true end
      return false, "No spaces — that is the rule this field rejects."
    end,
  })
  tab:AddParagraph(
    "The field below is the read-only half of the same kit. Press the copy glyph: it becomes a " ..
    "green check for just over a second, then falls back on its own. Press it again mid-check " ..
    "and the second press takes the window over — a generation counter owns the revert, so the " ..
    "first one cannot cut the second one short.")
  tab:AddTextBox({
    Text = "Share code",
    Description = "Copyable makes it non-editable; the glyph is the only control.",
    Default = "EZUI-7F3A-22",
    Copyable = true,
  })

  tab:AddSection("Number field")
  tab:AddParagraph(
    "The same focus ring, plus four movements of its own. HOLD − or + instead of tapping: the " ..
    "first step lands at once, then after a third of a second it repeats, accelerating while " ..
    "you hold. Push a box against its Min or Max and the refusal is visible — it bumps 2px " ..
    "toward the side you pushed and returns to the exact position it left, while the glyph at " ..
    "that end fades to the disabled alpha rather than changing colour. Type a shorthand into " ..
    "the first one — 1k, 4.4m — and it expands on the way in; the $ is stripped for you, and " ..
    "while the caret is in the field you see the raw number, not the compact one. Last, roll " ..
    "the wheel over a box: the value only follows it while the pointer is really over the box, " ..
    "which is why the panel behind still scrolls everywhere else.")
  tab:AddNumberBox({
    Text = "Budget",
    Description = "Compact display with a $ prefix. Try typing 4.4m.",
    -- 1.5M, not 1.25M: compact carries ONE decimal, and 1.25 formats as "1.2" (%.1f rounds an
    -- exactly-representable half to even). A tour about polish should not open on a number that
    -- reads like a rounding bug, so the default sits on a step that survives the round trip.
    Default = 1500000, Min = 0, Max = 10000000, Step = 250000,
    Format = "compact", Prefix = "$",
  })
  tab:AddNumberBox({
    Text = "Retries",
    Description = "Plain, 0–5. It starts AT Min, so − is already dimmed.",
    Default = 0, Min = 0, Max = 5, Step = 1,
  })

  tab:AddSection("Button states")
  tab:AddParagraph(
    "Hover any button for the wash, press for the 0.97 scale and the deeper fill, release for " ..
    "the spring back. The two below are the states you cannot reach by hovering.")
  -- Loading: the label fades out, a spinner fades in and spins on ONE repeating tween (not a
  -- Heartbeat loop). The busy flag is the important bit — without it a second click would stack
  -- another timer and the first one would clear the loading state early.
  local busy = false
  local loadBtn
  loadBtn = tab:AddButton({ Text = "Run a task (loading state)", Icon = "refresh-cw", Variant = "secondary",
    Callback = function()
      if busy then return end
      busy = true
      loadBtn.SetLoading(true)
      task.delay(1.8, function()
        loadBtn.SetLoading(false)
        busy = false
        window:ShowSuccess({ Title = "Done", Message = "The spinner was one repeating tween." })
      end)
    end })

  -- Disabled: dims the surface, the label and the description, and blocks input — but SetEnabled
  -- blocks USER input only, so .Set/.SetValue still move the control while it is dimmed. The
  -- second half of this callback proves that.
  local off = false
  local dimBtn
  dimBtn = tab:AddButton({ Text = "Disable the toggle and slider", Icon = "lock", Variant = "outline",
    Callback = function()
      off = not off
      demoToggle.SetEnabled(not off)
      demoSlider.SetEnabled(not off)
      dimBtn.SetText(off and "Enable the toggle and slider" or "Disable the toggle and slider")
      if off then
        -- still moves while disabled: dimmed is not frozen, it is just not clickable
        demoToggle.Set(false)
        demoSlider.SetValue(65)
        window:ShowInfo({ Title = "Dimmed, not frozen",
          Message = "Both are disabled, yet code just moved them. Only YOUR input is blocked." })
      end
    end })

  tab:AddButton({ Text = "Born disabled (nothing happens)", Variant = "destructive", Disabled = true,
    Callback = function() window:ShowError({ Title = "This should never fire" }) end })

  tab:AddSection("Reduced motion")
  tab:AddParagraph(
    "Every movement on this tab is one switch away from being instant. Turn it on, then come " ..
    "back up and click the same controls: the knob teleports, the slider fill jumps to its new " ..
    "width, the completion flash never appears, and the two REFUSALS — the number box bump and " ..
    "the field shake — do not run at all, because a pure there-and-back has no end state worth " ..
    "snapping to. Turn it off and the tab animates again.")
  -- SetAnimationsEnabled is process-wide and explicit: last writer wins, so this toggle also
  -- overrides the OS default the window booted with. Inverted on purpose — the switch reads
  -- "reduce", the library flag reads "animate".
  tab:AddToggle({
    Text = "Reduce motion",
    Description = "The same switch the OS reduce-motion setting drives by default.",
    Default = false,
    Callback = function(on) window:SetAnimationsEnabled(not on) end,
  })
end
