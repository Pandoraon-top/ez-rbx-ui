# Keybind

A keyboard shortcut recorder. Clicking the control puts it into listen mode — the key chip reads `Press a key` and its outline pulses — and the next key pressed is saved as the new binding. Pressing <kbd>Escape</kbd> while listening cancels instead: the previous binding is kept and `OnChanged` does not fire. The bound key fires `Callback` / `OnPressed` whenever it is pressed outside of game-processed input. Flag persistence is supported.

## Basic usage

```lua
local kb = tab:AddKeybind({
  Text    = "Action key",
  Default = Enum.KeyCode.E,
  Callback = function()
    print("keybind pressed")
  end,
})
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | `"Keybind"` | Label displayed to the left of the key badge. |
| `Default` | `Enum.KeyCode` | `Enum.KeyCode.Unknown` | Initial key binding. |
| `Description` | `string` | — | Muted secondary line rendered below the label. |
| `Disabled` | `boolean` | `false` | Builds the chip dimmed; the click that arms listening is refused. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Flag` | `string` | — | Config key used to persist the binding across sessions. |
| `Callback` | `function()` | — | Called (no arguments) whenever the bound key is pressed. |
| `OnChanged` | `function(key)` | — | Called with the new `Enum.KeyCode` when the binding changes (user rebind or `SetKey`). Use this to rebind something — e.g. `OnChanged = function(key) window:SetToggleKey(key) end` — instead of `Callback`, so you don't add a second handler on the same key. |

## API

| Method | Returns | Notes |
|---|---|---|
| `GetKey()` | `Enum.KeyCode` | Returns the current key binding. |
| `SetKey(k)` | `nil` | Sets the binding programmatically; accepts an `Enum.KeyCode`. |
| `OnPressed(fn)` | `nil` | Registers an additional listener called when the key fires. |
| `SetEnabled(b)` | `nil` | Dims the chip and refuses the click that starts listening. Disabling while the control is listening disarms it rather than leaving it armed; `SetKey` still applies — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Destroy()` | `nil` | Removes the control from the UI. |

## Examples

```lua
-- Basic bind with callback
tab:AddKeybind({
  Text     = "Action key",
  Default  = Enum.KeyCode.E,
  Callback = function() print("keybind pressed") end,
})

-- With a description line
tab:AddKeybind({
  Text        = "With description",
  Description = "Click then press a key.",
  Default     = Enum.KeyCode.Q,
})

-- Flag-bound — binding persists across sessions
tab:AddKeybind({ Text = "Saved bind", Flag = "ex_keybind", Default = Enum.KeyCode.F })

-- Reading and overriding at runtime
local kb = tab:AddKeybind({ Text = "Toggle UI", Default = Enum.KeyCode.RightShift })
kb.OnPressed(function()
  print("current key is", kb.GetKey().Name)
end)
kb.SetKey(Enum.KeyCode.P)  -- change binding programmatically

-- Disabled: the chip is dimmed and clicking it will not start listening,
-- but SetKey still rebinds it.
local locked = tab:AddKeybind({ Text = "Fixed bind", Default = Enum.KeyCode.G, Disabled = true })
locked.SetKey(Enum.KeyCode.H)

-- Rebinding the window's toggle key. The window ALREADY toggles on its ToggleKey, so use
-- OnChanged to repoint it — do NOT use Callback = window:Toggle (that adds a second handler
-- on the same key, firing alongside the built-in one and just making the window blink).
tab:AddKeybind({
  Text     = "Toggle UI key",
  Default  = Enum.KeyCode.RightControl,
  OnChanged = function(key) window:SetToggleKey(key) end,
})
```
