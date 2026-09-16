# Assets

Source art that has to live on Roblox before the library can use it. Nothing here ships in the
bundle: the library only ever references an uploaded asset id.

## `shadow-9slice.png` — drop shadow / glow sprite

One sprite serves every floating surface (window, dialog, popover, toast, tooltip, control).
`core/effects.lua` stretches it as a 9-slice and tints it per layer, so the same file is a black
shadow under the window and an accent glow behind a toggle.

Regenerate with `python3 scripts/build-shadow.py` (requires Pillow + numpy). Geometry is derived
from `Theme.Effect.slice`, so the two can never drift:

| | |
|---|---|
| Size | 499 × 499 |
| SliceCenter | `(49, 49, 450, 450)` — equals `Theme.Effect.slice` |
| Centre alpha | 140/255, black; the per-mode value in `Theme.MODE_EFFECTS` composites on top |

### Using it

1. Upload the PNG to Roblox (Creator Dashboard, or right-click Import in Studio) and copy the
   resulting asset id.
2. Set it in `core/theme.lua`, in the `Effect` group:
   ```lua
   shadowId = "rbxassetid://<your id>",
   ```
3. Check it in Studio in both dark and light mode before committing the id. While `shadowId` is
   an empty string `Effects.shadow` and `Effects.glow` return `nil` and every call site skips the
   layer, so the library renders correctly with no shadows at all — that is the safe default, and
   a wrong id would instead paint a stray image under every surface.

Moderation has to approve an uploaded image before it renders, so expect a short delay where the
id resolves to nothing.
