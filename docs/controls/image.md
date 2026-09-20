# Image

Displays a Roblox asset image or a Lucide icon glyph at a fixed height. The image scales with `ScaleType.Fit` so it never distorts.

## Basic usage

```lua
-- Lucide glyph
tab:AddImage({ Lucide = "gamepad-2", Height = 64 })

-- Raw Roblox asset
tab:AddImage({ Image = "rbxassetid://0", Height = 80 })
```

## Options

| Key | Type | Default | Notes |
|---|---|---|---|
| `Image` | `string` | `""` | Image source. Accepts `rbxassetid://…`, `rbxasset://…`, `rbxthumb://…`, a bare numeric id (`"12345678"`), or an `http(s)://` URL. Mutually exclusive with `Lucide` — if both are given, `Lucide` wins. |
| `Lucide` | `string` | — | Name of a Lucide icon (e.g. `"gamepad-2"`). Renders the glyph using the icon sheet. |
| `Height` | `number` | `80` | Height in pixels. Width is always 100%. |
| `Color` | `Color3` | varies | Tint color. Defaults to the theme foreground color for `Lucide` glyphs, or white (`Color3.fromRGB(255, 255, 255)`) for raw `Image` assets. |

## API

| Method | Returns | Notes |
|---|---|---|
| `SetImage(v)` | `nil` | Swaps the displayed image at runtime. Pass an `rbxassetid://…` string. Takes the slot from any fetch still in flight: the placeholder is dropped and the earlier image, if it eventually arrives, no longer replaces yours. |
| `Destroy()` | `nil` | Removes the image from the UI. |

## While the image loads

An image that is ready — which is the normal case for an `rbxassetid://` sprite the client already
has — is drawn straight away and pays nothing for any of this.

When the source still has to be resolved, though, the slot does not sit blank. It holds a
shimmering placeholder block at the control's own size while the content id is fetched and its
pixels decode, and the image fades in over it once the pixels land. That covers both an
`http(s)://` URL being downloaded and cached, and an asset id whose texture has not decoded yet.
With animation disabled (reduced motion) the placeholder is a still block and the image appears
without a fade.

Two things can go wrong, and both end with an ordinary empty slot rather than an endless shimmer:

- **A download that fails** ends the wait on the loader's own report rather than on the deadline:
  the placeholder is dropped as soon as the fetch says it failed. A failure that needs no network
  round-trip — a source that cannot be resolved at all, or a URL already cached as failed — is
  reported before the wait is even armed, so nothing is flashed up in that case.
- **A source that resolves but never settles** — a moderated sprite, a dead asset id — cannot report
  anything. The wait is given up on after 60 seconds and the slot is left blank.

URL sources need the executor's file API (`writefile` / `isfile` / `getcustomasset`) to be
downloadable at all. Without it the URL is not treated as resolvable and the slot stays empty.

## Examples

```lua
-- Lucide icon as a decorative glyph
tab:AddImage({ Lucide = "gamepad-2", Height = 64 })

-- Asset image (replace 0 with a real asset ID)
tab:AddImage({ Image = "rbxassetid://0", Height = 80 })

-- Swap the image at runtime
local img = tab:AddImage({ Image = "rbxassetid://0", Height = 80 })
img.SetImage("rbxassetid://12345678")

-- Inside an accordion
local acc = tab:AddAccordion({ Title = "Preview", Icon = "rows-3" })
acc:AddImage({ Lucide = "gamepad-2", Height = 48 })
```
