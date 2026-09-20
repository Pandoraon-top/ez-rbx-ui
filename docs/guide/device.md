# Device detection (`EzUI.Device`)

`EzUI.Device` reports the player's device class and active input so you can adapt your UI.

## Form factor

```lua
EzUI.Device.GetType()   -- "Mobile" | "Tablet" | "Desktop" | "Console"
EzUI.Device.IsMobile()  EzUI.Device.IsTablet()
EzUI.Device.IsDesktop() EzUI.Device.IsConsole()
EzUI.Device.IsTouch()   -- true when the device has a touchscreen
```

Console (ten-foot interface) and Desktop are detected reliably. **Mobile vs Tablet is a
best-effort heuristic** based on the viewport aspect ratio — Roblox exposes no physical
screen size or DPI. Tune it with `Configure`:

```lua
EzUI.Device.Configure({ TabletMaxAspect = 1.55, TabletMinDiagonal = math.huge })
```

Those are the defaults. A touch-only viewport counts as a **Tablet** when its long/short aspect ratio is at or below `TabletMaxAspect`, *or* when its pixel diagonal is at or above `TabletMinDiagonal` — the diagonal rule is off out of the box (`math.huge`), so aspect alone decides. `Configure` recomputes immediately (and fires `Changed` if the answer moved); a key you leave out, or one that is not a number, keeps its current value.

`GetType` resolves in a fixed order: ten-foot interface → `"Console"`, otherwise touch **and no mouse** → `"Mobile"` / `"Tablet"`, otherwise `"Desktop"`. A device that reports both touch and a mouse — a Windows laptop with a touchscreen, an emulator — therefore reads as `"Desktop"`. `IsTouch()` is separate from all of this: it only asks whether a touchscreen exists, so such a machine is `IsDesktop()` **and** `IsTouch()` at once.

## Active input modality

```lua
EzUI.Device.GetInput()  -- "Touch" | "KeyboardMouse" | "Gamepad" (the most recent input)
```

## Capability probes {#capability-probes}

```lua
EzUI.Device.SupportsHover()         -- true when a mouse is present (UserInputService.MouseEnabled)
EzUI.Device.PrefersReducedMotion()  -- true when the OS reduce-motion flag is on (GuiService.ReducedMotionEnabled)
```

Both read their service lazily under `pcall` and return `false` when the service or property is missing (older clients, exotic executors), so they never throw inside an input handler.

- `SupportsHover()` gates most of the library's hover affordances — the wash on control rows and on icon buttons, the glyph lift on an icon button, the slider handle growing under the pointer, the sidebar tab wash and the sidebar resize grip. Without a pointer those handlers are never connected at all, rather than leaving a hover state stuck after the first tap (touch fires Enter/Down/Up with no Leave). A [Button](/controls/button) is the exception: it connects its hover fill either way and instead checks the probe on release, so a tap falls back to rest rather than holding the hover fill. Tooltips reach the same conclusion by a different route: `Tooltip.attach` is a complete no-op when `IsTouch()` is true, since a tap would strand the chip on screen with nothing to dismiss it.
- `PrefersReducedMotion()` is the **default** for library motion: a window created without an `Animations` config starts with instant transitions when the flag is on. It is only a default — an explicit `Animations = true/false` or `Window:SetAnimationsEnabled(b)` always wins and is never overridden afterwards. See [Reduced motion](/api/window#reduced-motion).

## Reacting to changes

```lua
EzUI.Device.Changed:Connect(function(info)
  -- info = { Type = "...", Input = "...", Viewport = <something with .X / .Y> }
  print("device is now", info.Type, "via", info.Input)
end)
```

`Changed` fires only when `Type` or `Input` actually differs from the last reading, so it is safe to do real work in the handler — a burst of viewport resizes inside one form factor produces no events. It is re-evaluated when the last input type changes, when `TouchEnabled` / `MouseEnabled` / `KeyboardEnabled` flip, when the camera's `ViewportSize` changes, and on every `Configure` call.

`info.Viewport` is the camera's `ViewportSize`. Before a camera exists it falls back to a plain `{ X = 1280, Y = 720 }` table, so read `.X` / `.Y` rather than treating it as a `Vector2`.
