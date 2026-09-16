# Theming

EzUI ships with a zinc dark palette and a monochrome white primary color. All visual tokens live in `EzUI.Theme` and can be overridden per window.

## Per-Window Override

Pass a `Theme` table to `EzUI:CreateWindow`. Only the keys you specify are applied — the rest keep their defaults (deep-merge behavior).

```lua
EzUI:CreateWindow({ Theme = { Colors = { primary = Color3.fromRGB(59, 130, 246) } } })
```

## Token Groups

### Colors

The `Colors` group contains every semantic color token:

| Token | Default role |
|---|---|
| `background` | Window/panel background |
| `card` | Card and surface backdrop |
| `surface` | Control surface (inputs, buttons) |
| `border` | Dividers and outlines |
| `input` | Input field border |
| `ring` | Focus ring |
| `foreground` | Primary text |
| `mutedForeground` | Secondary / hint text |
| `primary` | Accent color (buttons, toggles) |
| `primaryForeground` | Text on primary-colored surfaces |
| `destructive` | Danger actions and error state |
| `success` | Success state |
| `warning` | Warning state |
| `info` | Informational state |
| `switchTrackOff` | Toggle track color when off |

Override any subset:

```lua
EzUI:CreateWindow({
    Theme = {
        Colors = {
            primary = Color3.fromRGB(59, 130, 246),
            destructive = Color3.fromRGB(220, 38, 38),
        }
    }
})
```

### Radius

Controls the corner rounding (in pixels) applied to panels, cards, inputs, and buttons.

| Key | Default | Used on |
|---|---|---|
| `sm` | `6` | Search box, tags, small chips |
| `md` | `8` | Floating toggle image, medium chips |
| `lg` | `10` | Content panel, buttons, cards |
| `xl` | `14` | Large panels |
| `window` | `12` | Window frame corners |
| `input` | `6` | Text / number input boxes |
| `xs` | `2` | Table cells, tiny chips |

```lua
Theme = { Radius = { lg = 6, window = 8 } }
```

### Spacing

Controls padding and gap values (in pixels) used throughout the layout engine.

| Key | Default | Used for |
|---|---|---|
| `pad` | `16` | Standard horizontal padding |
| `padLg` | `24` | Large padding sections |
| `inputX` | `12` | Input horizontal padding |
| `inputY` | `8` | Input vertical padding |
| `gap` | `8` | Spacing between sidebar and content panel |
| `section` | `16` | Vertical section spacing |
| `major` | `24` | Major vertical sections |
| `icon` | `8` | Icon gutter |

```lua
Theme = { Spacing = { pad = 12, gap = 6 } }
```

### Font

Controls the text size and weight for each text role. Each entry is a `{ Weight = Enum.FontWeight, Size = <px> }` table; `body` also carries a `LineHeight`.

| Key | Weight | Size (px) | Used for |
|---|---|---|---|
| `title` | `Bold` | `18` | Window title bar |
| `header` | `Medium` | `16` | Large headings (available to custom text; no built-in control uses it) |
| `label` | `Medium` | `14` | Control labels |
| `body` | `Regular` | `14` | Body / description text (`LineHeight = 1.25`) |
| `muted` | `Regular` | `12` | Hint text, tags, search |
| `overline` | `Medium` | `11` | `AddSection` headers and sidebar tab-group headers (uppercased) |

```lua
Theme = { Font = { title = { Weight = Enum.FontWeight.Bold, Size = 20 } } }
```

Weights now actually render. Every text role is applied through `Theme.FontFace(weight)`, which resolves a **BuilderSans** face with `Font.fromName("BuilderSans", weight)` — so the title is Bold, control labels are Medium and section headers are the 11 px Medium overline. BuilderSans ships no 600 weight: a `SemiBold` request resolves to `Bold`, and `nil` resolves to `Regular`. Where the `Font` global is unavailable the label keeps `Font = BuilderSans` at the engine's regular weight.

### Motion

Controls tween durations (in seconds) for transitions such as tabs, accordions, and toasts, plus the scale factors and pixel offsets the motion recipes use.

| Key | Default | Speed |
|---|---|---|
| `fast` | `0.12` | Snappy micro-interactions |
| `base` | `0.18` | Standard transitions |
| `slow` | `0.28` | Deliberate, large animations |

Additional motion tokens (the "unfold in, fold out" grammar):

| Key | Default | Meaning |
|---|---|---|
| `enter` / `exit` | `0.28` / `0.14` | Entrance and exit durations (popovers, toasts, dialogs) |
| `hover` / `press` / `release` | `0.12` / `0.08` / `0.22` | Hover wash, press and release durations |
| `stagger` | `0.035` | Delay between staggered siblings (toast expand, entrance cascade) |
| `enterScale` / `exitScale` | `0.94` / `0.96` | Start scale on entrance / end scale on exit |
| `pressScale` / `hoverScale` | `0.97` / `1.06` | Press-down and hover-grow scale |
| `popFrom` | `0.9` | Start scale for `Animate.pop` |
| `knobStretch` / `handleGrow` / `handleHover` | `1.2` / `1.3` / `1.15` | Toggle knob and slider handle scale factors |
| `spin` | `0.8` | Loader spin period, seconds per turn |
| `snap` | `0.3` | Snap-back duration |
| `hideDrift` / `popSlide` | `12` / `6` | Pixel drift on window hide / popover slide-in |
| `dialogRise` / `dialogDrop` | `12` / `8` | Dialog entrance rise / exit drop, in px |
| `bumpPx` | `2` | Step-feedback nudge, in px |
| `shake` | `{ amp = 3, steps = 4, step = 0.04 }` | Invalid-input shake: amplitude (px), step count, step duration |
| `cascade` | `{ x = 6, y = 8 }` | Entrance cascade offsets, in px |

```lua
Theme = { Motion = { fast = 0.08, base = 0.15, slow = 0.25 } }
```

A per-window `Motion` override is now honoured: `CreateWindow` hands the merged table to `Animate.useMotion`, so every duration name the library tweens with (`"fast"`, `"enter"`, `"spin"`, …) resolves against your values. Like `SetAnimationsEnabled`, this is **process-wide** — with several windows the last one created wins.

The groups below hold every number a component used to hard-code (durations, alphas, sizes, offsets), seeded with today's values so adding a token never moves a pixel on its own. Components adopt them incrementally as the visual-polish work lands: a key such as `Stroke.window` or `Toast.slide` describes the role it is reserved for, and overriding it only has an effect once the owning component reads it.

### Effect

Drop-shadow and glow geometry. `shadowId` is `""` by default, which keeps shadows **off** until you point it at a 9-slice shadow asset.

| Key | Default | Meaning |
|---|---|---|
| `shadowId` | `""` | 9-slice shadow image; `""` disables every shadow |
| `slice` | `{ x0 = 49, y0 = 49, x1 = 450, y1 = 450 }` | `SliceCenter` of the shadow asset |
| `window` | `{ spread = 28, offsetY = 6 }` | Window shadow spread and vertical offset, in px |
| `dialog` | `{ spread = 32, offsetY = 10 }` | Dialog shadow |
| `popover` | `{ spread = 18, offsetY = 4 }` | Popover shadow |
| `toast` | `{ spread = 16, offsetY = 4 }` | Toast shadow |
| `tooltip` | `{ spread = 10, offsetY = 2 }` | Tooltip shadow |
| `control` | `{ spread = 6, offsetY = 0 }` | Control shadow |
| `lift` | `{ spreadDelta = 8, alphaDelta = -0.12 }` | Extra spread / opacity while a window is dragged or resized |
| `controlGlow` | `"auto"` | Accent glow on controls; `"auto"` = off on phones |
| `skeleton` | `{ period = 1.1, rotation = 15 }` | Skeleton shimmer sweep period (s) and band angle (deg) |

### Stroke

`UIStroke` transparencies (`0` = solid, `1` = invisible). `panel` and `search` are per-mode tables — see [Per-mode tokens](#per-mode-tokens).

| Key | Default | Used on |
|---|---|---|
| `window` | `0.3` | Window frame rim |
| `floating` | `0` | Popovers, toasts, tooltips |
| `control` | `0` | Input and button outlines |
| `divider` | `0.4` | Separators and footer rules |
| `focusThickness` | `2` | Focus-ring thickness, in px |
| `panel` | `{ dark = 0.6, light = 0 }` | Content-panel hairline |
| `search` | `{ dark = 0.8, light = 0.5 }` | Sidebar search-box hairline |

### Opacity

Transparency levels for interaction states and scrims.

| Key | Default | Used for |
|---|---|---|
| `hoverWash` / `pressWash` | `0.94` / `0.9` | Hover and press wash on rows and clickable surfaces |
| `hoverFill` / `pressFill` | `0.12` / `0.2` | Filled (primary) button hover / press |
| `ghostHover` / `ghostPress` | `0.4` / `0.25` | Ghost and outline button hover / press |
| `tabHover` / `tabPress` | `0.92` / `0.88` | Sidebar tab hover / press |
| `optionHover` | `0.6` | Select-box option hover |
| `rowHover` | `0.94` | Table row hover |
| `disabled` | `0.5` | Disabled controls |
| `scrim` | `0.45` | Overlay scrim behind popovers |
| `dialogScrim` | `{ dark = 0.5, light = 0.6 }` | Dialog backdrop (per-mode) |
| `glowHover` | `0.7` | Accent glow at hover |

### Acrylic

The frosted window shell.

| Key | Default | Meaning |
|---|---|---|
| `noiseId` | `"rbxassetid://9968344105"` | Grain texture tiled over the shell |
| `tileSize` | `128` | Grain tile size, in px |
| `strokeAlpha` | `0.3` | Rim stroke transparency |
| `highlightBand` | `0.45` | Height of the top sheen band, as a fraction of the window |
| `frost` | `0.12` | Default window `Transparency` when the config key is omitted |
| `glintFade` | `0.25` | Fade band at each end of the top glint line |

### Scrollbar

| Key | Default | Meaning |
|---|---|---|
| `imageId` | `""` | Flat scrollbar image; `""` keeps the engine default |
| `alpha` | `0.35` | Scrollbar transparency |

### Sizes

Pixel geometry that used to be hard-coded per component.

| Key | Default | Used for |
|---|---|---|
| `icon` / `iconSm` | `16` / `14` | Standard and small glyph size |
| `iconButton` | `26` | Icon-button hit size with a pointer |
| `touchHit` | `44` | Icon-button hit size on touch |
| `scrollbar` | `4` | Scrollbar thickness |
| `progress` | `8` | Progress-bar track height |
| `sliderHit` | `24` | Slider hit-strip height |
| `chip` | `22` | Keybind chip / tag height |
| `knob` | `20` | Toggle knob diameter |
| `tagMeasureFudge` | `1.08` | Width multiplier for measured Medium-weight tag text |
| `dragKeep` | `40` | Pixels of the window that must stay on-screen when dragged |
| `titleBar` / `titleBarTall` | `40` / `56` | Title-bar height without / with a subtitle or image |
| `resizeGrip` / `resizeGripInset` | `12` / `4` | Resize-grip glyph size and inset |
| `splitGap` | `12` | Resizable split gap |
| `indicator` | `{ w = 3, h = 18, stretch = 26, radius = 2, haloW = 9, haloH = 26, haloAlpha = 0.85 }` | Sidebar active-tab indicator and its halo |
| `grip` | `{ w = 2, h = 24 }` | Resizable grip pill |
| `fab` | `{ size = 44, simple = 50, peek = 15, hoverPeek = 7, margin = 16, radius = 12, popFrom = 0.6 }` | Floating toggle geometry |

### Icon

Tint roles for glyphs, given as **names of `Colors` tokens**. They are resolved at paint time, so `SetMode` / `SetAccent` re-tint every icon.

| Key | Default | Used for |
|---|---|---|
| `structural` | `"mutedForeground"` | Chrome glyphs at rest (close, minimize, grip, carets) |
| `structuralActive` | `"foreground"` | The same glyphs when active or hovered |
| `accent` | `"primary"` | Accent-coloured glyphs |

### Tooltip

| Key | Default | Meaning |
|---|---|---|
| `delay` | `0.35` | Hover-intent delay before the tip shows, in seconds |
| `gap` | `6` | Distance from the anchor, in px |
| `padX` | `8` | Horizontal padding |
| `height` | `24` | Tip height |

### Toast

| Key | Default | Meaning |
|---|---|---|
| `width` / `inset` / `gap` | `300` / `16` / `8` | Toast width, screen inset and stack gap, in px |
| `peek` / `maxVisible` | `10` / `3` | Collapsed-stack peek offset and how many toasts stay fully visible |
| `peekScale` / `peekFade` | `0.05` / `0.18` | Scale and fade step per collapsed toast |
| `barHeight` / `progressInset` | `3` / `0` | Countdown bar height and inset |
| `padX` / `padY` | `12` / `8` | Content padding |
| `slide` / `exitSlide` | `48` / `32` | Entrance and exit slide distance, in px |
| `exitScale` | `0.95` | Exit scale |
| `typeTint` | `0.35` | Strength of the success / warning / error / info tint |
| `badgeAlpha` | `0.85` | Type-badge transparency |
| `staggerCap` | `5` | Maximum number of toasts that receive a stagger delay |

## Per-mode tokens {#per-mode-tokens}

Two kinds of values flip with the colour mode:

- **Per-mode leaves inside a group** are `{ dark = ..., light = ... }` tables (`Stroke.panel`, `Stroke.search`, `Opacity.dialogScrim`). Components read them through `Theme.modeVal`, so you can override one side only — a missing side falls back to `dark`.
- **`EzUI.Theme.MODE_EFFECTS`** holds the effect values that are not ordinary tokens — sheen, grain, edge lighting, shadow and glow strength per mode. It lives **outside** the per-window `Theme` override (`SetMode` only swaps `Colors`); components look it up through `Theme.fx(theme)` at paint time. Edit `EzUI.Theme.MODE_EFFECTS.dark` / `.light` globally if you need to retune it.

| Key | `dark` | `light` |
|---|---|---|
| `sheenTop` | `rgb(255,255,255)` | `nil` (falls back to `Colors.card`) |
| `sheenBottom` | `rgb(214,214,222)` | `rgb(240,240,243)` |
| `highlight` | `0.93` | `1` |
| `grain` / `grainTint` | `0.92` / `rgb(255,255,255)` | `0.97` / `rgb(0,0,0)` |
| `edgeTop` / `edgeBottom` | `0.0` / `0.65` | `0.2` / `0.7` |
| `glint` | `0.86` | `1` |
| `inset` | `rgb(196,196,206)` | `rgb(236,236,240)` |
| `shadow` | `0.5` | `0.8` |
| `glow` | `0.72` | `0.8` |

### Helpers

`EzUI.Theme` exposes four helpers; every window's merged theme instance carries the same functions (`theme.fx`, `theme.modeVal`, `theme.mix`, `theme.FontFace`).

| Helper | Returns |
|---|---|
| `Theme.mix(a, b, t)` | A new `Color3` interpolated between `a` and `b` on `.R/.G/.B`; `t` is clamped to `0..1`. Errors if either colour is `nil` |
| `Theme.fx(theme)` | `MODE_EFFECTS[theme.Mode]`; an unset or unknown mode reads as `dark` |
| `Theme.modeVal(theme, tok)` | `tok[theme.Mode]` when `tok` is a `{ dark, light }` table (missing side → `dark`); any other value is returned untouched |
| `Theme.FontFace(weight)` | `Font.fromName("BuilderSans", weight)`; `nil` → Regular, `SemiBold` → Bold (BuilderSans has no 600 face); `nil` when the `Font` global is unavailable |

```lua
local theme = EzUI.Theme
local tint = theme.mix(theme.Colors.card, theme.Colors.primary, 0.35)
local scrim = theme.modeVal(theme, theme.Opacity.dialogScrim)   -- 0.5 in dark, 0.6 in light
```

## Deep-Merge Behavior

A partial `Theme` table is deep-merged onto the built-in defaults. You only need to specify the tokens you want to change — all other tokens remain at their defaults. There is no need to copy the entire theme table.

```lua
-- Only the primary color changes; everything else uses the zinc dark defaults.
EzUI:CreateWindow({
    Theme = { Colors = { primary = Color3.fromRGB(99, 102, 241) } }
})
```

Nested groups merge leaf by leaf, so `{ Sizes = { fab = { size = 48 } } }` changes one value and inherits the rest of `Sizes.fab`, and `{ Stroke = { panel = { light = 0.2 } } }` retunes the light hairline while `panel.dark` keeps its default. `EzUI.Theme.PALETTES` and `EzUI.Theme.MODE_EFFECTS` are module-level tables and are not part of the per-window merge.

## Color mode (dark / light) {#color-mode-dark-light}

EzUI ships two complete palettes: `dark` (default, zinc-based) and `light` (white-based). Choose at window creation time with the `Mode` config key, or switch the live window with `SetMode`:

```lua
-- Light mode from the start
local Window = EzUI:CreateWindow({ Mode = "light" })

-- Switch live at runtime
Window:SetMode("light")
Window:SetMode("dark")

-- Read the current mode
print(Window:GetMode()) -- "dark" or "light"
```

The `Colors` tokens above describe the dark palette. In light mode the same token names map to lighter equivalents — your per-window `Theme.Colors` overrides apply on top of whichever palette is active. See the [Window API](/api/window#color-mode) for `GetMode` / `SetMode` reference.

The light palette is a four-step tonal ladder — chrome `background` 240 → `surface` 244 → `input` 250 → `card` 255 (with `border` 228 and `switchTrackOff` 212) — so the window shell, rows, fields and panels separate without leaning on strokes. Where an edge is still needed in light mode, the per-mode `Stroke.panel` / `Stroke.search` hairlines firm up (`0` / `0.5`) while staying faint in dark (`0.6` / `0.8`).

`SetMode` re-skins everything that is alive, not only the controls inside tabs: the acrylic shell (fill, sheen, rim, grain), the content-panel and search-box hairlines, every icon tint, and any toast or dialog that is open at the time.

### Accent

`primary` / `primaryForeground` can be swapped live without touching the rest of the palette:

```lua
Window:SetAccent("Indigo")                      -- "Adaptive" (default), "Indigo", "Violet", "Emerald", "Sky", "Rose"
Window:SetAccent(Color3.fromRGB(99, 102, 241))  -- any Color3; the foreground is picked for contrast
```

`"Adaptive"` follows the mode (near-white primary in dark, near-black in light). A named or custom accent survives `SetMode`. Accent-coloured parts re-tint immediately, including open toasts and dialogs. See [`SetAccent`](/api/window#setaccent-nameorcolor).

### Theme-adaptive logo

A brand logo that is a **single-color glyph** (e.g. an SVG exported with `fill="currentColor"`) can follow the mode automatically. Export it as a **white-on-transparent PNG** and opt in with `ImageAdaptive` (title bar) or the floating toggle's `Adaptive`:

```lua
EzUI:CreateWindow({
    Image = "rbxassetid://0",          -- a white-on-transparent glyph
    ImageAdaptive = true,              -- tints to `foreground`: near-white in dark, near-black in light
    FloatingToggle = { Type = "square", Image = "rbxassetid://0", Adaptive = true },
})
```

EzUI sets `ImageColor3` to the `foreground` token and re-tints it whenever `SetMode` flips the palette. Because `ImageColor3` multiplies, a white source tints cleanly to any color. Leave these `false` (the default) for full-color logos, which render untouched.

### Per-mode logo tiles

For a **full-color** logo that bakes in its own background (e.g. a rounded app-icon tile with a light card in light mode and a dark card in dark mode), tinting won't work — supply a `{ dark, light }` table instead. EzUI shows the variant for the active mode and swaps automatically on `SetMode`:

```lua
local TILE = {
    dark  = "https://alfin-efendy.github.io/ez-rbx-ui/brand/ezui-logo-rounded-dark.png",   -- shown in dark mode
    light = "https://alfin-efendy.github.io/ez-rbx-ui/brand/ezui-logo-rounded-light.png",  -- shown in light mode
}
EzUI:CreateWindow({
    Image = TILE,
    FloatingToggle = { Type = "square", Image = TILE },
})
```

`ImageAdaptive` / `Adaptive` are ignored for a `{ dark, light }` table (the tiles already carry their own colors). Use the single-string + adaptive form for a one-color glyph; use the table form for full-color per-mode artwork.
