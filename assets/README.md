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

### Status

Uploaded and wired: `Theme.Effect.shadowId` is `rbxassetid://91077512535886`. The upload must stay
public (Creator Dashboard > Settings > Advanced > Asset Privacy off), because the library is
loaded into other people's experiences and a Restricted image renders nowhere but your own.

### Replacing it

1. Upload the PNG through Creator Dashboard > Development items > Images, or Studio's Asset
   Manager, and copy the asset id. Do not upload it as a Decal: that asset type yields an id that
   does not render through `Image`.
2. Set it in `core/theme.lua`, in the `Effect` group:
   ```lua
   shadowId = "rbxassetid://<your id>",
   ```
3. Check it in Studio in both dark and light mode. Moderation has to approve a new image first, so
   expect a window where the id simply resolves to nothing.

Setting `shadowId` to `""` switches every depth layer off: `Effects.shadow` and `Effects.glow`
return `nil` and each call site skips its layer, which is the behaviour the tests pin for a
project that supplies no asset.
