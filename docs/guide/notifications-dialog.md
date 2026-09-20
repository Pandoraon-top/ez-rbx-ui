# Notifications & Dialog

EzUI provides toast notifications and a modal dialog — both are methods on the window object.

## Notifications

### Shorthand Methods

Use the typed helpers for common notification states:

```lua
window:ShowSuccess({ Title = "Saved", Message = "All good." })
window:ShowWarning({ Title = "Careful" })
window:ShowError({ Title = "Failed" })
window:ShowInfo({ Title = "Heads up" })
```

### `Notify(opts)`

For full control, use `Notify` directly:

```lua
window:Notify({
    Title = "Item deleted",
    Type = "warning",
    Duration = 5000,
    Action = {
        Text = "Undo",
        Callback = function()
            window:ShowSuccess({ Title = "Restored" })
        end
    },
    OnDismiss = function()
        print("notification dismissed")
    end
})
```

### Notification Options

| Key | Type | Default | Description |
|---|---|---|---|
| `Title` | `string` | required | Notification heading |
| `Message` | `string` | `nil` | Optional body text |
| `Type` | `string` | `"info"` | One of `"success"`, `"warning"`, `"error"`, `"info"`; also `"loading"`, which is what [`ShowLoading`](#loading-promise-toasts) passes. An unknown value is tinted and iconed as `"info"` |
| `Duration` | `number` | `4000` | Auto-dismiss delay in milliseconds |
| `Action` | `{ Text, Callback }` | `nil` | Optional action button shown in the toast |
| `OnDismiss` | `function` | `nil` | Called when the toast is dismissed |

Toasts that are on screen follow `Window:SetMode` and `Window:SetAccent` live: the toast re-skins in place instead of keeping the old palette until it expires. There is nothing to opt into — `Notify`, the `Show*` helpers, `ShowLoading` and `Promise` register an internal re-skin hook (`AccentReg`) with the window for the toast's lifetime and release it on dismiss.

### The Stack

Toasts collect at the anchored corner, newest in front. A new one slides in from that edge (`Toast.slide` px), fading in and springing up from `Motion.enterScale`.

Collapsed, the front `Toast.maxVisible` toasts (3) are on screen and the ones behind peek out from under the front card — each step back is scaled down by `Toast.peekScale`, faded by `Toast.peekFade` and offset `Toast.peek` px. Anything past the third is hidden outright, so a burst of toasts never turns into a wall.

Point at the stack and it **fans out into the full list**: every toast gets its own row, each one further back waiting an extra `Motion.stagger` before it moves, capped at `Toast.staggerCap` steps so a tall stack still opens promptly. While the pointer is over the stack, **every countdown in it pauses** — not only the toast under the cursor — so one cannot expire while you are reading the one above it. Moving away collapses the stack and resumes all of them.

The hover target is only as tall as the stack itself, not the full-height column it sits in, so the empty screen above (or below) the toasts never triggers the fan-out.

Dismissal is animated rather than instant: the toast fades, shrinks to `Toast.exitScale` and slides `Toast.exitSlide` px back out through the edge it came in from, and is destroyed once that finishes. Every route takes the same exit — the countdown reaching zero, the close glyph, the action button, `DismissNotification` and `ClearNotifications`.

The stack follows `Window:SetUIScale` as well. Toasts are not children of the window frame, so the scale is forwarded to them and rides a `UIScale` on the toast container; `Toast.width` stays a logical pixel value either way.

### Dismissing Notifications

`Notify` returns an id. Use it to dismiss a specific notification programmatically:

```lua
local id = window:ShowLoading({ Title = "Loading…" })
-- later, when the work is done:
window:DismissNotification(id)
```

To clear all active notifications at once:

```lua
window:ClearNotifications()
```

### Loading & Promise Toasts

`ShowLoading` shows a persistent toast with a spinner and **no countdown** — it stays until you dismiss it, and a `Duration` you pass is ignored. It returns an id for `DismissNotification`, and the pair is the manual version of what `Promise` does for you:

```lua
local id = window:ShowLoading({ Title = "Saving…" })
-- later, when your work finishes:
window:DismissNotification(id)
```

For async work, `Promise` does this for you: it shows a loading toast, runs a function that may **yield** (HTTP, datastore, `task.wait`), then morphs the toast into success or error when the function returns or errors.

```lua
window:Promise(function()
    local res = game:HttpGet(url)            -- yields
    return game:GetService("HttpService"):JSONDecode(res)
end, {
    Loading = "Loading data…",
    Success = function(data) return "Loaded " .. #data .. " items" end,
    Error   = function(err) return "Failed: " .. tostring(err) end,
    Finally = function() print("done") end,   -- optional, runs either way
})
```

`Success` and `Error` may each be a plain string or a function that receives the resolved value / error and returns the message. `Promise` returns the toast id.

#### Promise Options

| Key | Type | Default | Description |
|---|---|---|---|
| `Loading` | `string` | `"Loading…"` | Title shown while the function runs |
| `Success` | `string` \| `function(result)` | `"Success"` | Title after the function returns; a function receives the returned value |
| `Error` | `string` \| `function(err)` | `"Error"` | Title after the function errors; a function receives the error |
| `Finally` | `function` | `nil` | Called after the promise settles, on success or error |
| `Duration` | `number` | `4000` | Auto-dismiss delay (ms) for the success/error state |
| `Message` | `string` | `nil` | Optional body text on the loading toast |

### Notification Position

Toasts stack in the bottom-right corner by default. Change the corner globally with `SetNotificationPosition`, or set it once at creation with the `NotificationPosition` config key:

```lua
-- at creation
local window = EzUI:CreateWindow({ NotificationPosition = "top-right" })

-- or live at runtime
window:SetNotificationPosition("Top Center")
```

`pos` is one of `"top-left"`, `"top-center"`, `"top-right"`, `"bottom-left"`, `"bottom-center"`, `"bottom-right"` — case- and space-insensitive, so `"Top Center"` also works. Top positions stack downward, bottom positions stack upward; the default is `"bottom-right"`.

The corner is not fixed at startup. `SetNotificationPosition` re-anchors the container that is already on screen, so live toasts move across with it, and from then on they enter and exit through the new edge: a stack moved to `"top-left"` slides in from the left and leaves the same way, while one at `"top-center"` drops in from the top edge and lifts back out through it. A value that does not match any of the six is ignored and the current corner is kept.

### Demo from the Example

```lua
-- From example/menu/components/notification.lua
local tab = window:AddTab({ Name = "Notification", Icon = "bell" })
tab:AddSection("Toasts")
tab:AddButton({ Text = "Success", Callback = function()
    window:ShowSuccess({ Title = "Saved", Message = "All good." })
end })
tab:AddButton({ Text = "Warning", Variant = "secondary", Callback = function()
    window:ShowWarning({ Title = "Careful" })
end })
tab:AddButton({ Text = "Error", Variant = "destructive", Callback = function()
    window:ShowError({ Title = "Failed" })
end })
tab:AddButton({ Text = "Info", Variant = "outline", Callback = function()
    window:ShowInfo({ Title = "Heads up" })
end })
tab:AddButton({ Text = "With action", Variant = "ghost", Callback = function()
    window:Notify({
        Title = "Item deleted",
        Type = "warning",
        Action = { Text = "Undo", Callback = function()
            window:ShowSuccess({ Title = "Restored" })
        end }
    })
end })
tab:AddButton({ Text = "Promise", Callback = function()
    window:Promise(function() task.wait(1.5); return true end,
        { Loading = "Saving…", Success = "Saved!", Error = "Failed to save" })
end })
```

---

## Dialog

`window:Dialog(opts)` opens a dimmed modal overlay with a title, optional message, and one or more buttons.

```lua
window:Dialog({
    Title = "Delete item?",
    Message = "This cannot be undone.",
    Buttons = {
        { Text = "Cancel", Variant = "secondary" },
        { Text = "Delete", Variant = "destructive", Callback = function()
            window:ShowSuccess({ Title = "Deleted" })
        end }
    }
})
```

### Dialog Options

| Key | Type | Default | Description |
|---|---|---|---|
| `Title` | `string` | `"Dialog"` | Dialog heading |
| `Message` | `string` | `nil` | Optional body text |
| `Buttons` | `array` | `{ { Text = "OK" } }` | One or more button descriptors |
| `Modal` | `bool` | `true` | Dim the background while the dialog is open |
| `Icon` | `string` | `nil` | Optional Lucide icon in the header |
| `IconColor` | `Color3` | `Colors.foreground` | Override the header-icon tint |
| `IconBadge` | `bool` | `false` | With an `Icon`, `true` renders it in a tinted badge above a centered header; `false` shows it inline before the title |
| `Width` | `number` | `320` | Card width in px, clamped to the viewport/window minus margins |

The footer right-aligns its buttons on desktop and stacks them full-width (primary action on top) on touch devices.

An open dialog follows `Window:SetMode` / `Window:SetAccent` too: the card (fill and stroke), title, message, icon badge and buttons re-skin in place through the same internal `AccentReg` hook, which is released when the dialog closes.

### Button Descriptor

| Key | Type | Notes |
|---|---|---|
| `Text` | `string` | Button label |
| `Variant` | `string` | `"default"`, `"secondary"`, `"outline"`, `"ghost"`, `"destructive"` |
| `Icon` | `string` | Optional Lucide icon shown on the button |
| `Callback` | `function` | Called when the button is clicked; the dialog closes automatically |

### Keyboard and Gamepad

A dialog can be answered without the pointer:

| Input | Effect |
|---|---|
| `Escape`, gamepad `B` | Cancels: the dialog closes and **no** button callback runs |
| `Return`, gamepad `A` | Confirms: fires the **last** entry in `Buttons` — its `Callback` runs, then the dialog closes |

So put the confirming action last in the array. That is also where the footer draws it — rightmost with a pointer, top of the stack on touch — which is why `{ Cancel, Delete }` is the right order in the example above: reversed, Return would fire Cancel.

Input the game has already consumed is ignored, so pressing Return in a focused text box, or Escape to leave the chat, never answers a dialog sitting behind it.

### Stacking

Opening a dialog first closes any popover left open underneath it. A dropdown or color picker floats above the scrim otherwise, over a window it can no longer be used through.

A dialog opened on top of another does **not** darken the scrim twice — only the first one paints a backdrop and the second sits on it fully transparent, because two `Opacity.dialogScrim` layers compound (0.5 over 0.5 reads as 0.75) and the window behind would disappear. Only the innermost dialog answers the keyboard, and a single key press is consumed by exactly one dialog: Escape over a stack of two closes the inner one and leaves the outer one open. Closing out of order is handled too — whichever dialog is left on top takes over the keyboard, including the common case of a footer button that opens a confirm and then closes its own dialog.

### Opening and Closing

The card unfolds: it fades in, zooms up from `Motion.enterScale` and rises `Motion.dialogRise` px into place. Closing reverses it — the card shrinks, fades and drops `Motion.dialogDrop` px, with the scrim fading last so the card is gone before the room lights back up.

`window:Dialog(opts)` returns a handle carrying a single method, `Close()`. It runs that same fold-out and fires no callback, making it the programmatic equivalent of Escape:

```lua
local dlg = window:Dialog({
    Title = "Applying…",
    Message = "This will only take a moment.",
    Buttons = { { Text = "Cancel", Variant = "secondary" } },
})

task.delay(3, function()
    dlg.Close()
    window:ShowSuccess({ Title = "Applied" })
end)
```

### Demo from the Example

```lua
-- From example/menu/components/dialog.lua
local tab = window:AddTab({ Name = "Dialog", Icon = "message-square" })
tab:AddSection("Modal dialog")
tab:AddButton({ Text = "Open dialog", Callback = function()
    window:Dialog({
        Title = "Delete item?",
        Message = "This cannot be undone.",
        Buttons = {
            { Text = "Cancel", Variant = "secondary" },
            { Text = "Delete", Variant = "destructive", Callback = function()
                window:ShowSuccess({ Title = "Deleted" })
            end }
        }
    })
end })
```
