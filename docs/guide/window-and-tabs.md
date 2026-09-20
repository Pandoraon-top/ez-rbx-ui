# Window & Tabs

## Creating a Window

Call `EzUI:CreateWindow(config)` once to create the main window frame. All controls live inside tabs, which are added to the window.

```lua
local Window = EzUI:CreateWindow({
    Title = "My Hub",
    Ratio = { Width = 0.4, Height = 0.55 },
    Subtitle = "v3.0",
    Transparency = 0.12,
    ToggleKey = Enum.KeyCode.RightControl,
    FloatingToggle = { Type = "simple", AutoHide = true },
    Theme = { Colors = { primary = Color3.fromRGB(59, 130, 246) } },
    Config = { Enabled = true, FileName = "MyHub", AutoSave = true, AutoLoad = true },
})
```

### Config Keys

| Key | Type | Notes |
|---|---|---|
| `Title` | `string` | Title-bar text |
| `Subtitle` | `string` | Secondary line under the title (grows the title bar) |
| `Image` | `string` \| `{ dark, light }` | Title-bar logo — `rbxassetid://` / `rbxthumb://` or an `http(s)://` URL. A `{ dark = ..., light = ... }` table swaps per color mode on `SetMode` |
| `Ratio` | `{ Width, Height }` \| `number` | Window size as a fraction of the viewport — `{ Width = 0.4, Height = 0.55 }` = 40% × 55% (a single number = same fraction both axes); capped at 92% per axis; auto-fits and stays responsive. Default `{ Width = 0.45, Height = 0.6 }` |
| `Transparency` | `number` | Window background transparency `0..1` (default `0.12`) |
| `ToggleKey` | `Enum.KeyCode` | Show/hide key (default `RightControl`) |
| `Animations` | `bool` | Explicitly enable or disable all library motion. Omitted, the player's OS reduce-motion setting decides — see [Motion](#motion) |
| `FloatingToggle` | `table` | `{ Type, Position, Image, Adaptive, Size, Draggable, AutoHide, Pulse }` (or `false` to disable) |
| `StartHidden` | `bool` | Start collapsed to just the floating toggle (window loads hidden; open via the FAB or `ToggleKey`). Default `false` |
| `Mode` | `"dark"` \| `"light"` | Initial color mode; default `"dark"`. See [Color mode](/guide/theming#color-mode-dark-light) |
| `ConfirmClose` | `bool` | Show a confirm dialog before closing; default `true`. Pass `false` to close immediately |
| `OnClose` | `function` | Called (pcall-wrapped) when the window closes |
| `Parent` | `Instance` | Optional parent for the GUI; useful for custom mount points |
| `Theme` | `table` | Override design tokens (see [Theming](/guide/theming)) |
| `Config` | `{ Enabled, FileName, FolderName, AutoSave, AutoLoad }` | Flag persistence (see [Config & Flags](/guide/config-and-flags)) |

## Window Methods

| Method | Description |
|---|---|
| `AddTab(opts)` | Add a tab to the sidebar |
| `AddTabGroup(name)` | Add a named sidebar category group |
| `SearchTabs(query)` | Programmatically filter tabs and their controls |
| `Show()` | Make the window visible |
| `Hide()` | Hide the window |
| `Toggle()` | Toggle visibility |
| `IsVisible()` | Returns `true` if the window is visible |
| `Minimize()` | Collapse the window |
| `SetTitle(s)` | Update the title-bar text |
| `SetSubtitle(s)` | Update the subtitle text |
| `SetImage(v)` | Update the title-bar image (`rbxassetid://` or URL) |
| `SetTransparency(n)` | Set the window background transparency `0..1` (the content panel and the drop shadow follow it) |
| `SetUIScale(n)` | Scale the whole UI by `n`, overlay surfaces included — see [Scaling the UI](#scaling-the-ui) |
| `AdaptToViewport()` | Re-fit to the current viewport (also runs automatically on viewport changes) |
| `GetMode()` | Returns the current color mode (`"dark"` or `"light"`) |
| `SetMode(mode)` | Switch the color palette live (`"dark"` / `"light"`) |
| `SetFloatingToggle(opts)` | Rebuild the floating toggle button with new options |
| `SetFloatingToggleVisible(b)` | Show or hide the floating toggle button |
| `GetFloatingToggleType()` | Returns the toggle's current type — `"simple"`, `"circle"` or `"square"` |
| `LockAll()` / `UnlockAll()` | Put every control built so far behind a lock scrim, or take it away — see [Locking every control](#locking) |
| `Close()` | Dissolve the window and tear it down — **permanent**, see [Hiding vs. closing](#hiding-vs-closing) |
| `Destroy()` | Tear down the window and all its children (the same call as `Close()`) |

For notification and dialog methods, see [Notifications & Dialog](/guide/notifications-dialog).  
For config/flag reset methods, see [Config & Flags](/guide/config-and-flags).

## Locking every control {#locking}

`Window:LockAll()` puts every control the window has built so far out of reach at once, and
`Window:UnlockAll()` gives them back. It is the blunt instrument for "the script is busy" — one
call instead of walking your own list of handles.

```lua
Window:LockAll()      -- every control it reaches is scrimmed and unreachable
doSomethingSlow()
Window:UnlockAll()
```

A locked control gains two layers of its own: a wash in the `background` colour at
`Opacity.scrim`, and above it an invisible shield that absorbs every click, drag and hover before
the control sees it. The control keeps its value and stays legible underneath — it is covered, not
reset.

Two things are worth knowing before you reach for it:

- **The lock is not the same as a control's disabled state.** `SetEnabled(false)` and
  `SetDisabled(true)` dim the control and guard its own handlers; the lock sits on top of it. They
  are independent flags, so `UnlockAll()` will not re-enable a control that was disabled
  separately — see [Enabled and disabled](/controls/#enabled-and-disabled).
- **It locks what exists when you call it.** Controls added to a tab afterwards start unlocked.
  Build those with `Locked = true`, or call `LockAll()` again once they are in place.

Nesting does not exempt anything: controls on a tab, inside an
[Accordion](/controls/accordion) and inside a [Resizable](/controls/resizable) pane are all
covered. A single control can still be locked on its own with `SetLocked(b)`.

## Floating toggle button

The floating toggle button (FAB) lets players reopen the window after it's hidden — essential on touch devices, where there's no keyboard `ToggleKey`. It's enabled by default. Pass a `FloatingToggle` table to customize it, or `FloatingToggle = false` to remove it entirely.

```lua
local Window = EzUI:CreateWindow({
    FloatingToggle = {
        Type = "circle",                -- "simple" (default) | "circle" | "square"
        Image = "rbxassetid://123",     -- logo for circle/square (rbxassetid:// or http(s)://)
        Position = "BottomRight",       -- TopLeft/MidLeft/BottomLeft/TopRight/MidRight/BottomRight, or a UDim2
        Size = { Width = 56, Height = 56 },
        Draggable = true,               -- drag it; only "simple" magnets back to a screen edge
        AutoHide = true,                -- true: visible only while hidden; false: always visible
        Pulse = false,                  -- true: breathe an accent ring a few times on appearing
    },
})
```

### Options

| Key | Type | Description |
|---|---|---|
| `Type` | `string` | `"simple"` (default) — a chevron tab that docks at the screen edge; `"circle"` — an accent-colored round button; `"square"` — a rounded surface tile |
| `Image` | `string` \| `{ dark, light }` | Icon for the `circle`/`square` button — `rbxassetid://` / `rbxthumb://` or an `http(s)://` URL. Falls back to a controller icon if omitted. A `{ dark, light }` table swaps per color mode |
| `Adaptive` | `bool` | `false` (default): the image renders full-color. `true` treats a single-string `Image` as a monochrome glyph and tints it to the `foreground` token, so it follows dark/light and re-tints on `SetMode`. Use a white-on-transparent PNG. Ignored for a `{ dark, light }` table |
| `Position` | `string` \| `UDim2` | Anchor — `"TopLeft"`, `"MidLeft"`, `"BottomLeft"`, `"TopRight"`, `"MidRight"`, `"BottomRight"`, or a raw `UDim2`. For `simple` it sets which edge the tab docks to (and its height); for `circle`/`square` it places the button fully visible at that anchor. Default: `simple` → `MidLeft`, others → `TopLeft` |
| `Size` | `{ Width, Height }` \| `UDim2` | Button size in pixels |
| `Draggable` | `bool` | When `true` (default), the player can drag the button. On release **only `simple` magnets** back to whichever screen edge its centre is nearer; a `circle` or `square` button stays where it was dropped |
| `AutoHide` | `bool` | `true` (default) shows the button only while the window is hidden (it disappears when the window is open); `false` keeps it on screen at all times, acting as a persistent open/close toggle |
| `Pulse` | `bool` | `false` (default). `true` breathes an accent ring around the button when it appears — see [Attention pulse](#attention-pulse) |

Set `FloatingToggle = false` to disable the button. With it disabled, players can only reopen the window with the `ToggleKey`, so avoid this on touch-only experiences.

### Docking, hover and drag {#fab-docking}

The `simple` tab spends most of its life partly off screen: it rests against an edge with
`Sizes.fab.peek` px (`15`) of itself hanging past it. Everything below follows from that.

**The chevron turns rather than swapping sprites.** There is one `chevron-right` glyph, anchored
at its own centre. Docked on the left it points right, into the screen; magnet the tab to the
right edge and the same glyph rotates 180° to point left. The turn rides along with the slide to
the edge, so the tab is already facing the right way when it lands.

**It leans out when you point at it.** A pointer on the docked tab slides it
`Sizes.fab.hoverPeek` px (`7`) further onto the screen, and moving away slides it back. That is
`simple` only — a `circle` or `square` button is fully visible already and has nothing to lean out
of. Starting a drag or snapping to an edge cancels the lean.

**An accent glow lights underneath.** Every type gets one: a soft `primary`-coloured halo under
the button that fades up while the pointer is on it, alongside a small lift, a squash while you
hold it, and a spring back on release. Phones do not get the glow by default (there is no pointer
to reveal it), and turning the library's [depth layers](/guide/theming#depth-layers) off removes
it along with the button's shadow.

**A drag has to travel before it stops being a tap.** The button follows your pointer from the
first pixel, but the release only counts as a drag once the gesture has moved more than
`Sizes.dragThreshold` px (`6`) on either axis; past that the window is not toggled. A small wobble
is still a tap. On a `simple` tab the release re-magnets it to an edge, so the wobble leaves no
trace; a `circle` or `square` button has no magnet, so it keeps those few pixels — and still
toggles.

### Changing it at runtime

```lua
Window:SetFloatingToggle({ Type = "square", Image = "rbxassetid://123" })  -- rebuild with new options
Window:SetFloatingToggleVisible(true)                                       -- force show / hide
Window:GetFloatingToggleType()                                              -- "simple" | "circle" | "square"
```

`SetFloatingToggle` merges what you pass over the options already in force, so changing only the
`Image` keeps the `Type`, `Position` and `Size` the button had. `GetFloatingToggleType` reports
that merged type — handy for a settings selector that has to show the current choice. A window
built without a `FloatingToggle` table, or with `FloatingToggle = false`, reports the default
`"simple"` even though no button exists.

### Attention pulse {#attention-pulse}

A hidden window is easy to lose track of, so the floating button can ask for attention once.
`Pulse = true` rings it with a thin accent stroke that sits just outside the button and breathes
in and out **five times**, then rests. It is off by default, and with `Pulse` omitted no ring is
built at all.

```lua
EzUI:CreateWindow({
    FloatingToggle = { Type = "circle", Pulse = true },
})
```

The ring breathes each time the button appears, and stops the moment it has done its job: the
pointer touching the button ends the loop and settles it lit, moving away settles it back down
without starting another, and showing the window stops it outright — including with
`AutoHide = false`, where the button stays on screen after the window is back.

The count is fixed on purpose. An animation that loops forever on a floating button is a battery
cost for a hint nobody needs after the first few breaths. With [motion off](#motion) the ring is
drawn but never breathes.

## Tabs

Add a tab by calling `Window:AddTab(opts)`. The returned tab object exposes every `AddX` control method.

```lua
local tab = Window:AddTab({ Name = "Home", Icon = "home" })

tab:AddLabel("Welcome to My Hub")
tab:AddButton({ Text = "Run", Callback = function() print("clicked") end })
```

`Icon` accepts any Lucide icon name (see [Icons](/guide/icons)).

## Tab Groups

Group related tabs under a named sidebar category with `Window:AddTabGroup(name)`. The group object exposes the same `AddTab` method.

```lua
local group = Window:AddTabGroup("Main")

local homeTab = group:AddTab({ Name = "Home", Icon = "house" })
local settingsTab = group:AddTab({ Name = "Settings", Icon = "settings-2" })
```

## Sidebar Search

The window includes built-in full-text sidebar search that filters both tab names and their controls. Users activate it by typing in the search box at the top of the sidebar.

To trigger a search programmatically:

```lua
Window:SearchTabs("walk speed")
```

This narrows the sidebar to only tabs that contain controls matching the query. Matching happens
at two levels: control rows disappear unless their own text matches, and a tab survives in the
sidebar if its name matches or any of its controls still do. A group header hides once every tab
underneath it has.

When a query matches nothing at all, the rail shows a muted **"No matches"** block with an icon
rather than going blank, so a search that went too far reads as a result instead of a bug. It
appears only once the window has tabs (a window that has not had `AddTab` called yet is not "no
matches"), and clears as soon as one tab matches again or the query is emptied.

## The active tab indicator

One accent pill marks the selected tab, and it travels rather than teleporting: switching tabs
stretches it, springs it to the new tab's centre, then settles it back to its resting height. The
spring is distance-aware — a hop between neighbours is quick, a jump across the whole sidebar
takes longer, capped at `Motion.slow` — so how far the selection moved is legible from the motion
alone.

The pill stays glued to its button through sidebar scrolling, sidebar resizing and list reflows.
When its tab scrolls out of the visible band it fades out instead of drifting over the search box
or off the window edge, and fades back in when the tab returns.

## Resizing

The window edge and the sidebar divider are both draggable. On touch devices the resize grip and the sidebar divider use finger-sized hit targets and track the originating touch, so dragging to shrink shrinks reliably. A manually-resized window keeps its size across viewport changes (rotation, on-screen UI).

Dragging the grip resizes from the bottom-right corner alone: the opposite corner stays put,
because half of every size change goes into the window's position. The window will not go below
380 × 260 px, and will not grow past the viewport.

The **sidebar divider** is its own drag handle: a band centred on the divider, so a finger-sized
target does not reach over the first column of content. A small pill marks it: invisible at rest under a mouse, a hint on hover, solid while dragging, and
permanently half-lit on touch where there is no hover to reveal it. The rail can be dragged between
110 px and 260 px wide (it starts at 150 px), and everything pinned to it — the search field, the
"No matches" block, the content panel — moves with it.

## Moving the window

Drag the title bar to move the window. The drag is clamped so the window cannot be thrown off
screen: at least 40 px of it stays inside the viewport horizontally, and the top edge is held
between the top of the screen and *viewport height − title-bar height*. Whichever way it is
flung, there is always a strip of title bar left to grab it by.

Grabbing the title bar or the resize grip also lifts the window: its drop shadow spreads and
darkens and the shell hairline goes fully opaque, both settling back when you let go. The window
reads as picked up while you hold it.

Once the window has been moved or resized by hand, `AdaptToViewport()` respects that: a moved
window is clamped back on screen rather than re-centered, and a resized one keeps its size, shrunk
only far enough to fit a smaller viewport.

## Scaling the UI {#scaling-the-ui}

`Window:SetUIScale(n)` scales everything by a factor — `1` is the default size, `1.25` a quarter
larger, `0.9` a tenth smaller. A useful settings row on small phones:

```lua
tab:AddSlider({ Text = "UI scale", Min = 0.8, Max = 1.4, Default = 1, Step = 0.05,
    Flag = "ui_scale", Callback = function(n) Window:SetUIScale(n) end })
```

The window scales about its own centre, so it grows and shrinks in place instead of walking its
top-left corner across the screen, and its drop shadow follows.

The same factor reaches surfaces that live outside the window frame and would otherwise stay at
their old size: **toasts** rescale immediately (open ones included), and **tooltips** and
**select-box / color-picker dropdowns** pick it up the next time they appear. Dialogs opened with
`Window:Dialog` are parented inside the window and already inherit its scale, so they are never
scaled twice. That forwarded value is process-wide: with more than one window on screen, the last
`SetUIScale` call wins.

## Hiding vs. closing {#hiding-vs-closing}

These are different endings, and only one of them is reversible.

**Hiding** (`Hide()`, `Minimize()`, the minimize glyph, the toggle key, the floating button) folds
the window down and drifts it a few pixels *toward* the floating button before handing off, so it
reads as the window turning into the button. Everything is kept; `Show()` unfolds it again exactly
as it was.

**Closing** (`Close()`, `Destroy()`, the close glyph) dissolves the window in place and tears it
down: `OnClose` runs, the config is saved, toasts and overlays are cleared, every connection is
disconnected and the `ScreenGui` is destroyed.

A closed window cannot be reopened. The built-in confirm dialog says *"You can reopen it with the
toggle key or the floating button"* — that is not true of closing: the toggle-key connection and
the floating button are destroyed with everything else. To get a window back, call
`EzUI:CreateWindow` again. If you want the player to be able to bring the window back, wire your UI
to `Minimize()` and leave `Close()` for shutting the script down.

```lua
EzUI:CreateWindow({
    ConfirmClose = false,                       -- skip the dialog; the X closes straight away
    OnClose = function() print("hub closed") end,
})
```

## Motion {#motion}

The window opens in beats. The shell unfolds first, then its contents arrive behind it: the title
(with its subtitle) fades in sliding from the left, and one beat later the content panel fades in
rising from below. Tab rows are not staggered.

That entrance cascade is skipped in two situations — on **touch** devices, where the window is
opened and closed all day and a cascade every time is in the way, and whenever **motion is off**.
`StartHidden = true` skips the entrance too, and pre-paints the window so the first `Show()`
reveals it correctly.

Motion is one process-wide switch, resolved in a fixed order:

1. **An explicit choice always wins.** `Animations = true/false` at creation, or
   `Window:SetAnimationsEnabled(b)` at runtime. Last explicit writer wins, and nothing overrides
   it afterwards.
2. **Otherwise the platform decides.** A window created without `Animations` follows the player's
   reduce-motion setting (`GuiService.ReducedMotionEnabled`). Because that is only a default, a
   second window created without `Animations` cannot re-enable motion the player switched off.

```lua
tab:AddToggle({ Text = "Reduce motion", Flag = "reduce_motion",
    Callback = function(on) Window:SetAnimationsEnabled(not on) end })
```

With motion off, tweens apply their goal instantly and loops become no-ops. The durations
themselves are a separate knob: a per-window `Theme = { Motion = { ... } }` override retunes every
duration the library tweens with, and — like the on/off switch — applies process-wide, so the last
window created wins. See [Theming — Motion](/guide/theming#motion).
