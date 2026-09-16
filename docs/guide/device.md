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

- `SupportsHover()` gates every hover affordance in the library (hover wash, tooltip intent, halos): touch-only devices skip them instead of keeping a hover state stuck after the first tap.
- `PrefersReducedMotion()` is the **default** for library motion: a window created without an `Animations` config starts with instant transitions when the flag is on. It is only a default — an explicit `Animations = true/false` or `Window:SetAnimationsEnabled(b)` always wins and is never overridden afterwards. See [Reduced motion](/api/window#reduced-motion).

## Reacting to changes

```lua
EzUI.Device.Changed:Connect(function(info)
  -- info = { Type = "...", Input = "...", Viewport = Vector2 }
  print("device is now", info.Type, "via", info.Input)
end)
```
