# Window API

The `Window` object is returned by `EzUI:CreateWindow(config)`. All tab management, visibility control, notifications, and dialogs are methods on this object.

## `EzUI:CreateWindow(config)`

Creates and displays a new window. Returns a `Window` object.

```lua
local Window = EzUI:CreateWindow({
    Title = "My Hub",
    Subtitle = "v3.0",
    Image = "rbxassetid://0",
    ImageAdaptive = true,
    Ratio = { Width = 0.4, Height = 0.55 },
    Transparency = 0.12,
    Animations = true,
    ToggleKey = Enum.KeyCode.RightControl,
    FloatingToggle = { Type = "simple", AutoHide = true },
    Config = { Enabled = true, FileName = "MyHub", AutoSave = true, AutoLoad = true },
})
```

### Config Table

| Key | Type | Description |
|---|---|---|
| `Title` | `string` | Title-bar text |
| `Subtitle` | `string` | Secondary line shown under the title (grows the title bar) |
| `Image` | `string` \| `{ dark, light }` | Title-bar logo — `rbxassetid://` / `rbxthumb://` or an `http(s)://` URL. Pass a `{ dark = ..., light = ... }` table to swap **per color mode** automatically on `SetMode` (for full-color logo tiles that bake in their own background). See [Color mode](#color-mode) |
| `ImageAdaptive` | `bool` | Treat `Image` as a **monochrome glyph** and tint it to the `foreground` token so it follows dark/light and re-tints on `SetMode`. Default `false` (the image renders full-color). Supply a **white-on-transparent** PNG — `ImageColor3` multiplies, so white tints cleanly to any color |
| `Ratio` | `{ Width, Height }` \| `number` | Window size as a **fraction of the viewport**: `{ Width = 0.4, Height = 0.55 }` = 40% wide × 55% tall. A single number applies the same fraction to both axes. Capped at 92% per axis; stays responsive. Default `{ Width = 0.45, Height = 0.6 }` |
| `Transparency` | `number` | Window background transparency `0..1`; `0` = opaque, higher = more see-through. Default `0.12` (the `Acrylic.frost` token) |
| `Animations` | `bool` | Enable entrance/transition motion (FAB pop, window open/close, accordion + tab transitions). When **omitted**, the default follows the player's OS reduce-motion setting (`GuiService.ReducedMotionEnabled` → instant transitions) — unless motion was already chosen explicitly via an earlier `Animations` or `SetAnimationsEnabled`, in which case that choice stands. Pass `true` / `false` to choose explicitly (low-end devices, accessibility). See [Reduced motion](#reduced-motion) |
| `ToggleKey` | `Enum.KeyCode` | Show/hide key (default `RightControl`) |
| `FloatingToggle` | `table` | Floating toggle button config — see [FloatingToggle config](#floatingtoggle-config). Pass `false` to disable |
| `StartHidden` | `bool` | Start collapsed to just the floating toggle: the window loads hidden and the FAB is shown so the player can open it (also openable via `ToggleKey`). Default `false` |
| `Mode` | `"dark"` \| `"light"` | Initial color mode; default `"dark"`. See [Color mode](#color-mode) |
| `NotificationPosition` | `string` | Corner toasts appear in: `"top-left"`, `"top-center"`, `"top-right"`, `"bottom-left"`, `"bottom-center"`, `"bottom-right"`. Default `"bottom-right"`. See [Notification Position](/guide/notifications-dialog#notification-position) |
| `ConfirmClose` | `bool` | Show a confirm dialog before closing; default `true`. Pass `false` to close immediately |
| `OnClose` | `function` | Called (pcall-wrapped) when the window closes |
| `Parent` | `Instance` | Optional parent for the GUI; useful for custom mount points |
| `Theme` | `table` | Override design tokens (see [Theming](/guide/theming)) |
| `Config` | `{ Enabled, FileName, FolderName, AutoSave, AutoLoad }` | Flag persistence options (see [Config & Flags](/guide/config-and-flags)) |

---

## Tab Methods

### `AddTab(opts)`

Adds a tab to the sidebar and returns a tab object. The tab object supports all [Controls](/controls/) methods.

```lua
local tab = Window:AddTab({ Name = "Home", Icon = "home" })
```

| Key | Type | Description |
|---|---|---|
| `Name` | `string` | Tab label shown in the sidebar |
| `Icon` | `string` | Lucide icon name (see [Icons](/guide/icons)) |

### `AddTabGroup(name)`

Adds a named sidebar category group and returns a group object. Call `group:AddTab(opts)` to add tabs inside the group.

```lua
local group = Window:AddTabGroup("Main")
group:AddTab({ Name = "Home", Icon = "home" })
```

### `SearchTabs(query)`

Filters the sidebar tabs and their controls by the given text string. An empty string clears the filter. The built-in sidebar search field calls this method automatically.

```lua
Window:SearchTabs("farm")
```

Matching runs at two levels: individual control rows are hidden unless their text matches, and a
tab button stays in the sidebar if its own name matches **or** any of its controls still match. A
group header is hidden once every tab inside it is.

When a query filters *every* tab away, the sidebar rail shows a muted "No matches" block instead
of going blank. It only appears when the window actually has tabs — a window between creation and
its first `AddTab` is not "no matches" — and it disappears again as soon as one tab matches or the
query is cleared.

---

## Visibility Methods

### `Show()`

Makes the window visible. The shell unfolds from `Motion.exitScale` back to full size over
`Motion.release`, growing from its centre, while the hairline and the drop shadow fade back in.
With `AutoHide` on, the floating toggle fades out; its [attention pulse](#attention-pulse) stops
either way.

### `Hide()` {#hide}

Hides the window without destroying it, and hands off to the floating toggle button.

The shell folds — shrinking to `Motion.exitScale` while the hairline and shadow fade out — and at
the same time drifts `Motion.hideDrift` px (`12`) **toward the floating button**, so hiding reads
as the window turning into it. With no floating button (or one sitting under the window centre)
the drift is straight down instead. When the fold finishes the window is hidden, its resting
position is put back, and the button pops in.

The drift is skipped while the title bar is being dragged: that gesture owns the position.

### `Toggle()`

Toggles visibility: shows if hidden, hides if visible.

### `IsVisible()`

Returns `true` if the window is currently visible, `false` otherwise.

### `Minimize()` {#minimize}

Closes any open popover, then does exactly what `Hide()` does — the same fold and hand-off to the
floating toggle. This is what the title-bar minimize glyph calls.

### `Close()` {#close}

Closes the window **permanently**. It dissolves in place: the same fold as `Hide`, one beat slower
(`Motion.base`) and all the way to fully transparent, with no drift. When the fold lands the window
tears itself down — `OnClose` fires, the config is saved, open overlays and toasts are cleared,
every connection (title-bar drag, resize, toggle key) is disconnected, and the `ScreenGui` is
destroyed.

**A closed window cannot be reopened.** The built-in confirm dialog says *"You can reopen it with
the toggle key or the floating button"*, but that is not what happens: the toggle-key connection
and the floating button are destroyed along with the rest. After `Close`, `Show`, `Hide`, `Toggle`
and `AddTab` are no-ops on that object; call `EzUI:CreateWindow` again for a new window. If you
want a window the player can bring back, use [`Hide()`](#hide) or [`Minimize()`](#minimize).

`Destroy()` is the same call under another name.

---

## Window Control Methods

### `SetTitle(s)`

Sets the window title-bar text to `s`.

### `SetSubtitle(s)`

Sets the subtitle line shown under the title. Requires the window to have been created with a `Subtitle` (the slot is built at creation).

### `SetImage(v)`

Updates the title-bar image. Accepts an `rbxassetid://` id, an `http(s)://` URL, or a `{ dark, light }` table (which keeps swapping on `SetMode`). Requires the window to have been created with an `Image`.

### `SetTransparency(n)`

Sets the window background transparency, `n` in `0..1` (`0` = opaque). The acrylic shell is re-painted (`Acrylic.reskin`), so the sheen band, rim and grain rescale with the new value rather than only the fill changing.

The value also propagates outward, so a frosted shell stays consistent with itself:

- **the content panel** — and the scroll edge fades cut from the same colour — takes **60%** of it.
  A see-through shell must not contain an opaque slab, but the panel still has to read as a tonal
  step above the chrome.
- **the drop shadow** lightens by **half** of it: a see-through shell cannot cast a solid shadow.
  In light mode a half-frosted window saturates to no shadow at all.

Both are re-derived from whatever you last set, so they survive a `SetMode`.

### `SetUIScale(n)`

Scales the whole UI by the factor `n` (`1` = default size): `1.25` makes everything a quarter
larger, `0.9` a tenth smaller.

The window scales about its centre, so it grows and shrinks in place instead of dragging its
top-left corner around, and the drop shadow carries its own scale so it tracks the frame.

The same factor is then forwarded to **overlay-hosted surfaces**, which are not children of the
window frame and would otherwise be left at their old size:

| Surface | Behaviour |
|---|---|
| Toasts | The toast container rescales immediately — open toasts included |
| Tooltips | Read the scale when they are built, so the next tip to appear is scaled |
| Select-box and color-picker dropdowns | Read the scale when they open |

Dialogs opened with `Window:Dialog` are parented to the window frame and already inherit its
scale — they are never scaled twice.

That forwarded value is a single **process-wide** number, so with more than one window the last
call wins (the window's own scale stays its own). The forward is guarded: a value that is not a
positive number is not passed on.

```lua
Window:SetUIScale(1.25)
```

### `SetAnimationsEnabled(b)`

Toggles all library motion at runtime (`true` = animated, `false` = instant). The setting is process-wide; with multiple windows the last call wins.

This is an **explicit** choice: it marks motion as user-chosen, so a later window created without `Animations` — and the OS reduce-motion default — never flips it back. The example menu wires it to a *Reduce motion* toggle:

```lua
tab:AddToggle({ Text = "Reduce motion", Description = "Disable UI animations", Flag = "reduce_motion",
    Callback = function(on) Window:SetAnimationsEnabled(not on) end })
```

See [Reduced motion](#reduced-motion) for the full resolution order.

### `AdaptToViewport()` {#adapttoviewport}

Re-fits the window to the current viewport, preserving the configured `Ratio`. A window the user hasn't moved is re-centered; once the user drags or resizes it, its position is kept (clamped on-screen) instead. Called automatically on creation and whenever the viewport size changes — the window is always responsive.

### `GetMode()`

Returns the current color mode: `"dark"` or `"light"`.

### `SetMode(mode)` {#setmode}

Switches the color palette live. Pass `"dark"` or `"light"`. Controls re-skin immediately without recreating the window.

Beyond the controls inside tabs, a mode switch re-skins the acrylic shell (fill, sheen, rim, grain), the content-panel and search-box hairlines (`Stroke.panel` / `Stroke.search` are per-mode tokens), every icon tint (`Icon` roles resolve at paint time), and any toast or dialog that is open at the time. Overlays that outlive the call register a temporary re-skin closure with the window internally (the `AccentReg` hook passed to `Notify` / `Dialog`) and release it when they dismiss or close — nothing to opt into. An `"Adaptive"` accent follows the new mode; a named or custom accent is kept.

### `SetAccent(nameOrColor)`

Swaps the accent (`Colors.primary` / `Colors.primaryForeground`) live without touching the rest of the palette. Pass a preset name — `"Adaptive"` (the default: near-white in dark, near-black in light), `"Indigo"`, `"Violet"`, `"Emerald"`, `"Sky"`, `"Rose"` — or any `Color3`, in which case the foreground is chosen for contrast. Unknown names are ignored.

```lua
Window:SetAccent("Indigo")
Window:SetAccent(Color3.fromRGB(99, 102, 241))
```

Everything accent-coloured re-tints at once — controls, the sidebar indicator, icons using the `Icon.accent` role, and open toasts and dialogs (same `AccentReg` hook as `SetMode`). A named or custom accent survives a later `SetMode`.

### `LockAll()` {#lockall}

Locks every control the window has built so far. A locked control is covered by two full-size
layers of its own: a **scrim** — a `background`-coloured wash at `Opacity.scrim`, rounded to
`Radius.md` — and above it an invisible **shield**, a transparent button that swallows every
click, drag and hover before it reaches the control. The control keeps its value and its
appearance underneath; it simply cannot be reached.

```lua
Window:LockAll()     -- everything built so far is scrimmed and unreachable
```

Two things follow from *where* the lock lives:

- **It is independent of a control's own disabled state.** `SetEnabled(false)` / `SetDisabled(true)`
  dim the control itself and guard its input handlers; the lock is a pair of layers on top.
  Both can be on at once, and `UnlockAll()` never re-enables a control that was disabled
  separately — see [Enabled and disabled](/controls/#enabled-and-disabled).
- **It is a snapshot, not a mode.** The window locks the controls that exist when you call it.
  A control added to a tab afterwards starts unlocked, whatever the last `LockAll()` did; build
  it with `Locked = true`, or call `LockAll()` again.

It reaches every control the window knows about: mounted straight on a tab, inside an
[Accordion](/controls/accordion), or inside a [Resizable](/controls/resizable) pane. A single
control can still be locked on its own through `SetLocked(b)`, which every control carries, or
built with `Locked = true`.

The scrim is chrome-coloured, so it follows [`SetMode`](#setmode) while it is showing.

### `UnlockAll()` {#unlockall}

Hides the scrim and shield on every control `LockAll()` can reach, undoing both it and any
per-control `SetLocked(true)` on those controls.

```lua
Window:UnlockAll()
```

### `SetFloatingToggleVisible(b)`

Shows (`b = true`) or hides (`b = false`) the floating toggle button.

### `SetFloatingToggle(opts)` {#setfloatingtoggle}

Rebuilds the floating toggle button at runtime with a new options table (the same shape as the [FloatingToggle config](#floatingtoggle-config)). Re-enables the button if it was disabled, and shows it immediately when `AutoHide = false`.

```lua
Window:SetFloatingToggle({ Type = "circle", Image = "rbxassetid://123" })
```

### `GetFloatingToggleType()`

Returns the floating toggle's current type as a string — `"simple"`, `"circle"` or `"square"`.

```lua
if Window:GetFloatingToggleType() == "simple" then ... end
```

It reports the *configured* type, so it answers correctly after a
[`SetFloatingToggle`](#setfloatingtoggle) that omitted `Type`: the new options are merged over
the current ones, so changing only the `Image` keeps the type the button already had. A window
created without a `FloatingToggle` table — or with `FloatingToggle = false`, where no button is
built at all — reports the default `"simple"`.

### FloatingToggle config

The `FloatingToggle` config key accepts a table (or `false` to disable the button entirely):

| Key | Type | Description |
|---|---|---|
| `Type` | `string` | `"simple"` (default) docks a chevron tab at the screen edge; `"circle"` is an accent-colored round button; `"square"` is a rounded surface tile |
| `Image` | `string` \| `{ dark, light }` | Icon for the `circle`/`square` button — `rbxassetid://` / `rbxthumb://` or an `http(s)://` URL (falls back to a controller icon). A `{ dark, light }` table swaps per color mode, same as the window `Image` |
| `Adaptive` | `bool` | Treat `Image` as a monochrome glyph and tint it to the `foreground` token, following dark/light and re-tinting on `SetMode`. Default `false` (full-color white fill). Use a white-on-transparent PNG. Ignored when `Image` is a `{ dark, light }` table |
| `Position` | `string` \| `UDim2` | Anchor — `"TopLeft"`, `"MidLeft"`, `"BottomLeft"`, `"TopRight"`, `"MidRight"`, `"BottomRight"`, or a raw `UDim2`. For `simple` it sets which edge the tab docks to (and its height); for `circle`/`square` it places the button fully visible at that anchor. Default: `simple` → `MidLeft`, others → `TopLeft` |
| `Size` | `{ Width, Height }` \| `UDim2` | Button size in pixels. Default `50 × 50` for `simple` (`Sizes.fab.simple`), `44 × 44` for `circle`/`square` (`Sizes.fab.size`). A `{ Width }` given without a `Height` falls back to `44` |
| `Draggable` | `bool` | When `true` (default), the player can drag the button. On release **only `simple` magnets** — it docks to whichever screen edge its centre is nearer, peeking `Sizes.fab.peek` px. A `circle` or `square` button stays exactly where it was dropped |
| `AutoHide` | `bool` | `true` (default) shows the button only while the window is hidden; `false` keeps it visible at all times (a persistent open/close toggle) |
| `Pulse` | `bool` | `false` (default). `true` breathes an accent ring around the button to draw the eye to it once — see [Attention pulse](#attention-pulse) |

```lua
EzUI:CreateWindow({
    FloatingToggle = {
        Type = "circle",
        Image = "rbxassetid://123",
        Position = "BottomRight",
        Size = { Width = 56, Height = 56 },
        AutoHide = false,
    },
})
```

With `FloatingToggle = false` the button is not created, and players can reopen the window only via the `ToggleKey` — avoid this on touch-only experiences.

#### Docking, hover and drag {#docking-hover-drag}

**The chevron turns; it is never swapped.** A `simple` tab carries one `chevron-right` sprite,
anchored at its own centre so `Rotation` pivots there. Docked at the left edge it sits at `0` and
points right, into the screen; magnet it to the right edge and the same sprite rotates to `180`
and points left. The turn is a `Motion.base` tween and runs alongside the `Motion.snap` slide to
the edge, so the tab arrives already facing the right way.

**The docked tab leans out under a pointer.** Only `simple` hides part of itself behind the screen
edge — it rests with `Sizes.fab.peek` px (`15`) hanging off — so only `simple` leans: entering it
slides the tab `Sizes.fab.hoverPeek` px (`7`) further onto the screen over `Motion.hover`, and
leaving it slides back. The lean is relative to whatever rest position the magnet last chose, and
it is latched, so a second `MouseEnter` cannot stack a second lean. Starting a drag, or landing a
magnet snap, spends it outright.

**An accent glow lights underneath.** Every type gets one: a `primary`-tinted layer at the
`Effect.control` level, sitting one `ZIndex` below the button, resting fully invisible and tweening
up to `Opacity.glowHover` over `Motion.fast` while the pointer is on the button. The button itself
lifts to `Motion.hoverScale` at the same moment, squashes to `0.92` while held, and springs back on
release. The glow is subject to the usual [depth-layer](/guide/theming#depth-layers) switches —
`Effect.controlGlow = "auto"` (the default) drops it on phones, and `Effect.shadowId = ""` removes
it, and the button's shadow, entirely.

**A few pixels of travel separate a drag from a click.** The button follows the pointer from the
first pixel, but it only stops counting as a click once the gesture has travelled more than
`Sizes.dragThreshold` px (`6`) on either axis; past that, the release is swallowed and the window
is not toggled. Below it the press is still a tap. What is left behind differs by type: a `simple`
tab re-magnets to an edge on every release, so a sub-threshold wobble is erased, while a `circle`
or `square` button has no magnet and keeps those few pixels of displacement — and still toggles.

#### Attention pulse {#attention-pulse}

`Pulse = true` builds a ring *outside* the button — a `Halo` frame 12 px wider and taller than the
FAB, so it stands 6 px clear of every edge, carrying an accent `UIStroke` at `Stroke.focusThickness`.
It is opt-in: without `Pulse` no halo and no stroke are created at all, so nothing changes for an
existing caller.

The ring rests at `Stroke.pulse.high` and breathes to `Stroke.pulse.low` and back **five times**,
then stops. The count is deliberately finite — an endless tween on a floating button is a battery
cost for a hint nobody needs after the first few breaths.

It starts whenever the button pops in — `Hide()`, `Minimize()`, `SetFloatingToggleVisible(true)`,
`SetFloatingToggle(opts)`, or at creation with `AutoHide = false` or `StartHidden = true` — and
stops as soon as it has done its job:

- **the pointer enters the button** — the loop is cancelled and the ring settles on its lit alpha
  (`Stroke.pulse.low`, over `Motion.hover`), where it stays;
- **the pointer leaves** — it settles back to its rest alpha, it never starts breathing again;
- **`Show()`** — the window is on screen, so there is nothing left to point at. This happens even
  with `AutoHide = false`, where the button itself stays put;
- **`Hide()`'s counterpart, hiding the button** — a button that is gone asks for nothing.

With motion off the ring is still built and tinted, it simply never tweens: it sits at its rest
alpha. Its colour follows `SetAccent` and `SetMode` like everything else accent-coloured.

```lua
EzUI:CreateWindow({
    FloatingToggle = { Type = "circle", Pulse = true, AutoHide = false },
})
```

### `Destroy()`

Closes the window, disconnects all connections, and destroys the UI. Equivalent to
[`Window:Close()`](#close) — including the part where the window cannot be brought back.

---

## Notification Methods

See [Notifications & Dialog](/guide/notifications-dialog) for full option details and examples.

### `Notify(opts)`

Shows a toast notification with full control over all options. Returns an `id` that can be passed to `DismissNotification`.

```lua
local id = Window:Notify({
    Title = "Item deleted",
    Type = "warning",
    Duration = 5000,
    Action = { Text = "Undo", Callback = function() end },
    OnDismiss = function() end,
})
```

| Key | Type | Default | Description |
|---|---|---|---|
| `Title` | `string` | required | Notification heading |
| `Message` | `string` | `nil` | Optional body text |
| `Type` | `string` | `"default"` | One of `"success"`, `"warning"`, `"error"`, `"info"` |
| `Duration` | `number` | `4000` | Auto-dismiss delay in milliseconds |
| `Action` | `{ Text, Callback }` | `nil` | Optional action button shown in the toast |
| `OnDismiss` | `function` | `nil` | Called when the toast is dismissed |

### `ShowSuccess(opts)`

Shorthand for `Notify` with `Type = "success"`.

### `ShowWarning(opts)`

Shorthand for `Notify` with `Type = "warning"`.

### `ShowError(opts)`

Shorthand for `Notify` with `Type = "error"`.

### `ShowInfo(opts)`

Shorthand for `Notify` with `Type = "info"`.

### `ShowLoading(opts)`

Shows a persistent toast with a spinner and no countdown — it stays until dismissed. Accepts the same `opts` as `Notify` (`Duration` is ignored). Returns an `id` for `DismissNotification`.

```lua
local id = Window:ShowLoading({ Title = "Saving…" })
-- later:
Window:DismissNotification(id)
```

### `Promise(fn, opts)`

Runs `fn` (which may yield — HTTP, datastore, `task.wait`) behind a loading toast, then morphs the toast into success or error when `fn` returns or errors. `Success`/`Error` may be a string or a function of the result/error. Returns the toast `id`. See [Loading & Promise Toasts](/guide/notifications-dialog#loading-promise-toasts) for the full options table.

```lua
Window:Promise(function() task.wait(1.5); return true end, {
    Loading = "Saving…",
    Success = function(ok) return "Saved!" end,
    Error   = function(err) return "Failed: " .. tostring(err) end,
    Finally = function() end,   -- optional
})
```

### `DismissNotification(id)`

Dismisses the notification identified by `id` (the value returned by `Notify`, `ShowLoading`, or `Promise`).

### `ClearNotifications()`

Dismisses all active notifications immediately.

### `SetNotificationPosition(pos)`

Sets the corner toasts stack in (global, affects all windows). `pos` is one of `"top-left"`, `"top-center"`, `"top-right"`, `"bottom-left"`, `"bottom-center"`, `"bottom-right"` — case- and space-insensitive (`"Top Center"` works). Default is `"bottom-right"`. Also settable at creation via the [`NotificationPosition`](#config-table) config key.

```lua
Window:SetNotificationPosition("top-right")
```

---

## Dialog Method

See [Notifications & Dialog](/guide/notifications-dialog) for full option details and examples.

### `Dialog(opts)`

Opens a dimmed modal overlay with a title, optional message, and one or more buttons.

```lua
Window:Dialog({
    Title = "Delete item?",
    Message = "This cannot be undone.",
    Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Delete", Variant = "destructive", Callback = function()
            Window:ShowSuccess({ Title = "Deleted" })
        end },
    },
})
```

| Key | Type | Default | Description |
|---|---|---|---|
| `Title` | `string` | required | Dialog heading |
| `Message` | `string` | `nil` | Optional body text |
| `Buttons` | `array` | required | One or more button descriptors (`{ Text, Variant?, Callback? }`) |
| `Modal` | `bool` | `true` | Dim the background while the dialog is open |

---

## Config Methods

See [Config & Flags](/guide/config-and-flags) for full details.

### `ResetConfiguration(opts)`

Restores all flagged controls to their default values. With `Confirm = true` (the default) it shows a confirmation dialog first, then toasts success.

| Option | Default | Description |
|---|---|---|
| `Confirm` | `true` | Show a confirmation dialog before resetting |
| `ClearFile` | `false` | Also delete the saved file from disk |

### `ResetFlag(flag)`

Resets a single flag to its default value without confirmation.

### `.Config`

The config object attached to this window (`EzUI:NewConfig` instance). Use it to call `cfg:Get(k)`, `cfg:Set(k, v)`, or other [Config API](/api/core#config) methods directly.

---

## Color mode

EzUI ships `dark` (default) and `light` palettes. Choose at creation time with the `Mode` config key, or switch the running window with `SetMode`:

```lua
-- Light mode from the start
local Window = EzUI:CreateWindow({ Mode = "light" })

-- Switch live at runtime
Window:SetMode("light")

-- Read the current mode
print(Window:GetMode()) -- "light"
```

See [Theming — Color mode](/guide/theming#color-mode-dark-light) for the full palette reference.

## Reduced motion

Library motion is a single process-wide switch (`Animate`), resolved in this order:

1. **Explicit choice wins and is never overridden** — `Animations = true/false` in `CreateWindow`, or `Window:SetAnimationsEnabled(b)`. Each explicit call is "last writer wins".
2. **Otherwise the OS preference is the default** — a window created without `Animations` reads `EzUI.Device.PrefersReducedMotion()` (`GuiService.ReducedMotionEnabled`) and starts with instant transitions when the flag is on. Because it is only a default, a second window created without `Animations` cannot re-enable motion after the player switched it off.

```lua
-- Follows the OS reduce-motion setting (default)
local Window = EzUI:CreateWindow({ Title = "Hub" })

-- Explicit: always animated, whatever the OS says
local Window = EzUI:CreateWindow({ Title = "Hub", Animations = true })

-- Explicit at runtime (e.g. from a settings toggle)
Window:SetAnimationsEnabled(false)
```

With motion off every tween applies its goal instantly and loops (spinners, pulses) are no-ops. Hover affordances are gated separately, and not all by the same probe: washes and halos check `EzUI.Device.SupportsHover()`, while a [Tooltip](/controls/tooltip) checks `EzUI.Device.IsTouch()`. Either way a touch-only device never gets a stuck hover state — see [Device detection](/guide/device#capability-probes).

A few things go further than "instant" and are skipped outright when motion is off: the
[entrance cascade](#entrance) is never started (nothing is parked invisible waiting for a tween
that will not run), and the floating toggle's [attention ring](#attention-pulse) is built but
never breathes.

## Motion durations

Separate from the on/off switch, a per-window `Theme = { Motion = { ... } }` override retunes the
durations themselves: `CreateWindow` hands the merged table to `Animate.useMotion`, so every
duration name the library tweens with (`"fast"`, `"enter"`, `"release"`, `"spin"`, …) resolves
against your values. Like the on/off switch this is **process-wide** — with several windows the
last one created wins. See [Theming — Motion](/guide/theming#motion).

```lua
EzUI:CreateWindow({ Theme = { Motion = { fast = 0.08, base = 0.15, slow = 0.25 } } })
```

## Moving, resizing and scaling

The window frame is anchored at its centre (`AnchorPoint (0.5, 0.5)`), and every scale animation —
the entrance, `Show`, `Hide`, `Close` and `SetUIScale` — pivots there. A scale change therefore
grows and shrinks the window in place instead of dragging its top-left corner across the screen.

**Dragging the title bar** cannot throw the window off screen. The drag clamps the window's centre
so that:

- horizontally, at least `Sizes.dragKeep` px (`40`) of the window stays inside the viewport;
- vertically, the top edge stays between `0` and *viewport height − title-bar height*.

Together those keep a grabbable strip of title bar on screen at all times, whichever direction the
window was flung. A drag in the middle of the screen is plain start + delta, untouched by the
clamp.

**Dragging the resize grip** (bottom-right) resizes from that corner only: half of every size
delta goes into the position, so the opposite corner stays still rather than walking up and to the
left. The window is floored at 380 × 260 px and capped at the viewport.

**Grabbing either one** lifts the window off the page — the drop shadow spreads by
`Effect.lift.spreadDelta` and darkens by `Effect.lift.alphaDelta`, and the shell hairline goes
fully opaque (`Stroke.floating`). Both settle back on release, and closing the window mid-drag
resets the lift too.

Once the window has been moved or resized by hand, [`AdaptToViewport()`](#adapttoviewport) stops
re-centering and re-fitting it: a moved window is only clamped back on screen, and a resized one
keeps its manual size (shrunk only far enough to fit a smaller viewport, never below the minimum).

## Entrance {#entrance}

A freshly created window unfolds exactly the way `Show` does, one beat slower (`Motion.enter`):
the shell scales up from `Motion.exitScale` and fades in to its configured `Transparency`.

Its contents then arrive behind it, in two beats one `Motion.stagger` apart:

1. the title — and the subtitle, on the same beat — fade in while sliding `Motion.cascade.x` px
   from the left;
2. the content panel fades in while rising `Motion.cascade.y` px.

Only those two beats cascade; tab rows are not staggered. The cascade is skipped entirely, with
nothing ever parked invisible, in two cases: on **touch** devices, where the window is opened and
closed all day, and with **motion off**.

`StartHidden = true` skips the entrance altogether and pre-sets every layer (scale, background,
hairline, shadow) at its rest value, so the first `Show()` reveals a correctly-painted window
rather than one still wearing its folded values.

## Parenting & stealth

`CreateWindow` resolves where to mount the UI automatically via a fallback chain:
`gethui()` → `protect_gui` + `CoreGui` → `CoreGui` → `PlayerGui`. It also applies
stealth at runtime (random `ScreenGui` name, `cloneref`, dedupe of prior EzUI roots).

| Field | Type | Default | Effect |
|---|---|---|---|
| `Parent` | `Instance` | auto | Manual override; bypasses the whole chain. |
| `Stealth` | `bool` | `true` at runtime | Controls naming only. `false` → readable name `"EzUI"`. Dedupe / `protect` / service `cloneref` are always feature-detected-on. |
| `GuiName` | `string` | random / `"EzUI"` | Force a specific `ScreenGui` name. |
| `DisplayOrder` | `number` | `1000000` | `ScreenGui` render order (higher renders above game UI). |

In Roblox Studio the name stays the readable `"EzUI"` for easy debugging.
