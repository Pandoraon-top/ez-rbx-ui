# TextBox

A single-line text input with a rich set of addons. The input box can carry a leading icon, text prefix/suffix, inline action buttons, a password reveal toggle, a clear button, a copy button, a loading spinner, and live validation. When `FullWidth` is set, the label stacks above the input instead of sitting beside it, giving the addons more horizontal room.

## Basic usage

```lua
local tb = tab:AddTextBox({
  Text        = "Name",
  Placeholder = "Type your name…",
})
print(tb.GetText())
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` | — | Row label. Omit for a label-less input that spans the full width. |
| `Default` | `string` | `""` | Initial text value. |
| `Placeholder` | `string` | `""` | Ghost text shown when the input is empty. |
| `Description` | `string` | — | Muted secondary line rendered below the label. |
| `MaxLength` | `number` | — | Silently truncates input beyond this character count. |
| `Copyable` | `boolean` | `false` | Makes the field read-only and adds a copy icon button. See [Copyable](#copyable) below. |
| `LeadingIcon` | `string` | — | Lucide icon name rendered at the left edge of the input box (e.g. `"search"`, `"lock"`). |
| `Prefix` | `string` | — | Non-editable text rendered immediately before the caret (e.g. `"$"`, `"https://"`). |
| `Suffix` | `string` | — | Non-editable text rendered immediately after the editable area (e.g. `"USD"`, `".com"`). |
| `TrailingIcon` | `string` | — | Lucide icon name rendered at the trailing (right) edge of the input box, after any `Suffix`. Behaves like `LeadingIcon` on the opposite side. No dedicated built-in example; usage mirrors `LeadingIcon`. |
| `Loading` | `boolean` | `false` | When `true`, the field starts in the loading/spinner state at construction — identical to calling `SetLoading(true)` immediately after creation. |
| `FullWidth` | `boolean` | `false` | Stacks the label above the input box instead of placing them side-by-side. Recommended when `Prefix`/`Suffix`/`Buttons` need room. |
| `Password` | `boolean` | `false` | Masks the value with `•` characters and adds an eye/eye-off reveal button. `GetText()` always returns the real value. |
| `Clearable` | `boolean` | `false` | Adds a trailing `×` button. See [The clear button](#the-clear-button) below. |
| `Disabled` | `boolean` | `false` | Builds the field non-editable and dimmed. See [Enabled and disabled](/controls/#enabled-and-disabled). |
| `Buttons` | `{ { Icon?\|Text?, Tooltip?, Variant?, Callback? } }` | — | List of compact action buttons appended at the right of the input. See [Inline buttons](#inline-buttons) below. |
| `Validate` | `function(text) -> (ok, message)` | — | Validator run on focus-loss and on every `SetText`. See [Validation](#validation) below. |
| `Flag` | `string` | — | Config key used to persist the value across sessions. |
| `Callback` | `function(text, ctl)` | — | Called on focus-loss with the current text and the control API. |

## API

| Method | Returns | Notes |
|---|---|---|
| `GetText()` | `string` | Returns the current text value (unmasked even in password mode). |
| `SetText(s)` | `nil` | Sets the text, re-runs `Validate`, and fires `Callback`. |
| `Focus()` | `nil` | Programmatically focuses the input. |
| `Clear()` | `nil` | Clears the text without firing `Callback` and without re-running `Validate` (so an error already on screen stays there — call `SetValid()` to drop it). |
| `SetLoading(b)` | `nil` | Shows/hides the spinning loader icon at the right of the input. |
| `SetValid()` | `nil` | Clears any invalid state (removes the red border and message). |
| `SetInvalid(msg)` | `nil` | Marks the input as invalid: red border + message beneath the box. |
| `SetEnabled(b)` | `nil` | Dims the box and its inline glyphs and blocks typing and the inline buttons when `false`. `SetText` and flag restores still apply — see [Enabled and disabled](/controls/#enabled-and-disabled). |
| `SetDisabled(b)` | `nil` | The inverse of `SetEnabled` — `SetDisabled(true)` is `SetEnabled(false)`. |
| `Destroy()` | `nil` | Removes the control from the UI. |

## Validation

`Validate` is called with the current text and returns two values: whether the text is acceptable,
and the message to show when it is not.

```lua
Validate = function(text)
  return #text >= 3, "At least 3 characters"
end
```

It runs when the field loses focus and again on every `SetText`. When it returns `false` the field
enters the invalid state: the border turns the destructive color, the message appears on a line
beneath the box (the row grows to make room for it) and the box shakes once horizontally, ending
exactly where it started. Returning `true` clears all of that again.

The same two states are reachable without a validator, which is how you report the result of an
asynchronous check: `SetInvalid(msg)` puts the field into the invalid state (message, border and
shake included) and `SetValid()` takes it back out. The invalid border outranks the focus ring, so
a field that is both focused and invalid still reads red.

With animation disabled (reduced motion) the shake is skipped entirely — the border and the message
land in place.

## Copyable

`Copyable = true` does two things. The input becomes non-editable — and stays that way even after
`SetEnabled(true)` — and a copy button is added at the trailing edge. Clicking it writes the text
to the clipboard (via the executor's `setclipboard`, when there is one) and acknowledges in place:
the glyph swaps to a check in the theme's success color for `Motion.copyRevert` seconds (1.2 by
default), then reverts on its own. Clicking again during that window restarts it rather than
letting the earlier revert flip the glyph back early.

## The clear button

`Clearable = true` adds an `×` button that is only on screen while the field has something in it:
it fades in on the first character typed and fades back out when the field empties. Clicking it
clears the value, fires `Callback` with the now-empty text, and puts the caret back in the field so
the user can type straight away. It does not run `Validate`.

## Inline buttons

Each entry in `Buttons` becomes one compact button at the trailing edge of the input, in the order
given. An entry with `Icon` draws a Lucide glyph in the theme's accent tint; an entry with `Text`
draws a small labelled button whose fill comes from `Variant` — `"default"` (the accent fill, used
when `Variant` is omitted), `"secondary"`, `"destructive"`, `"outline"` or `"ghost"`.
`Callback(text, ctl)` receives the current text and the control API, so a button can read the field
and then act on it through [`ctl.Clear()`, `ctl.SetInvalid(msg)`, `ctl.SetLoading(b)`](#api) and the
rest. A disabled field turns its inline buttons away along with typing.

**`Tooltip` on an entry does nothing today.** The field is accepted in the options table, but
nothing reads it: hovering an inline button shows no chip. To label the field on hover, put
[`Tooltip`](/controls/tooltip) on the text box itself — it attaches to the whole row, inline buttons
included, and will show for a pointer resting anywhere on it.

## Examples

```lua
-- Basic inputs
tab:AddTextBox({ Text = "Name", Placeholder = "Type your name…" })

tab:AddTextBox({
  Text        = "With description",
  Description = "Helper text under the label.",
  Placeholder = "…",
})

-- Read-only with a built-in copy button
tab:AddTextBox({ Text = "Key", Default = "EZUI-DEMO", Copyable = true })

-- Input group: leading icon + prefix/suffix (FullWidth for more room)
tab:AddTextBox({
  Text        = "Website",
  FullWidth   = true,
  LeadingIcon = "link",
  Prefix      = "https://",
  Suffix      = ".com",
  Placeholder = "your-site",
})

tab:AddTextBox({ Text = "Price", Prefix = "$", Suffix = "USD", Placeholder = "0.00" })

-- Clearable + custom icon button
tab:AddTextBox({
  Text      = "Token",
  Default   = "sk-demo-123",
  Clearable = true,
  Buttons   = {
    {
      Icon     = "copy",
      Callback = function(text)
        if setclipboard then pcall(setclipboard, text) end
        window:ShowSuccess({ Title = "Copied", Message = text })
      end,
    },
  },
})

-- Text button that clears the field after use
tab:AddTextBox({
  Text        = "Message",
  FullWidth   = true,
  LeadingIcon = "mail",
  Placeholder = "Say something…",
  Buttons     = {
    {
      Text     = "Send",
      Variant  = "default",
      Callback = function(text, ctl)
        window:ShowSuccess({ Title = "Sent", Message = text ~= "" and text or "(empty)" })
        ctl.Clear()
      end,
    },
  },
})

-- Password field with reveal toggle
tab:AddTextBox({
  Text        = "Password",
  LeadingIcon = "lock",
  Password    = true,
  Placeholder = "••••••••",
})

-- Live validation on focus-loss
tab:AddTextBox({
  Text        = "Email",
  FullWidth   = true,
  LeadingIcon = "mail",
  Placeholder = "you@example.com",
  Validate    = function(t)
    return t:match("^[^@%s]+@[^@%s]+%.[^@%s]+$") ~= nil, "Enter a valid email address"
  end,
})

-- Async availability check driven from a button
tab:AddTextBox({
  Text        = "Username",
  LeadingIcon = "user",
  Placeholder = "pick a handle",
  Buttons     = {
    {
      Icon     = "check",
      Callback = function(text, ctl)
        ctl.SetLoading(true)
        task.delay(0.8, function()
          ctl.SetLoading(false)
          if #text > 2 then ctl.SetValid() else ctl.SetInvalid("Too short") end
        end)
      end,
    },
  },
})

-- Disabled (read-only + dimmed)
tab:AddTextBox({ Text = "Locked", Default = "read-only", Disabled = true })

-- Flag-bound — value persists across sessions
tab:AddTextBox({ Text = "Saved note", Flag = "ex_textbox", Default = "hello" })
```
