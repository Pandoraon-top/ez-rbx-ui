# EzUI Theming Reference

EzUI ships a zinc dark palette with a monochrome white primary. All visual design tokens live in `EzUI.Theme` and can be overridden per window.

## Per-Window Override

Pass a `Theme` table to `EzUI:CreateWindow`. The table is **deep-merged** onto the defaults — you only specify what you want to change.

```lua
EzUI:CreateWindow({ Theme = { Colors = { primary = Color3.fromRGB(59, 130, 246) } } })
```

## Token Groups

### Colors

Semantic color tokens used throughout every control and panel.

| Token | Default (dark) | Role |
|---|---|---|
| `background` | `rgb(9,9,11)` | Window/panel background |
| `card` | `rgb(24,24,27)` | Card and surface backdrop |
| `surface` | `rgb(39,39,42)` | Control surface (inputs, buttons) |
| `border` | `rgb(63,63,70)` | Dividers and outlines |
| `input` | `rgb(39,39,42)` | Input field border |
| `ring` | `rgb(212,212,216)` | Focus ring |
| `foreground` | `rgb(250,250,250)` | Primary text |
| `mutedForeground` | `rgb(161,161,170)` | Secondary / hint text |
| `primary` | `rgb(250,250,250)` | Accent color (buttons, toggles) |
| `primaryForeground` | `rgb(24,24,27)` | Text on primary-colored surfaces |
| `destructive` | `rgb(239,68,68)` | Danger actions and error state |
| `success` | `rgb(34,197,94)` | Success state |
| `warning` | `rgb(234,179,8)` | Warning state |
| `info` | `rgb(59,130,246)` | Informational state |
| `switchTrackOff` | `rgb(63,63,70)` | Toggle track color when off (one step above `surface`) |

Override any subset:

```lua
EzUI:CreateWindow({
    Theme = {
        Colors = {
            primary     = Color3.fromRGB(59, 130, 246),
            destructive = Color3.fromRGB(220, 38, 38),
        }
    }
})
```

### Radius

Corner rounding in pixels applied to panels, cards, inputs, and buttons.

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

Padding and gap values (pixels) used by the layout engine.

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

Text size and weight per role. Each entry is `{ Weight = Enum.FontWeight, Size = <px> }`; `body` also has `LineHeight = 1.25`.

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

Weights render for real: text goes through `Theme.FontFace(weight)` = `Font.fromName("BuilderSans", weight)` (title Bold, labels Medium, section headers 11 px Medium overline). BuilderSans has no 600 — `SemiBold` resolves to `Bold`, `nil` to `Regular`. Never use `Font.fromEnum` with a weight (it takes one argument).

### Motion

Tween durations (seconds) for tabs, accordions, toasts, and other transitions, plus the scale/offset tokens the motion recipes use.

| Key | Default | Speed |
|---|---|---|
| `fast` | `0.12` | Snappy micro-interactions |
| `base` | `0.18` | Standard transitions |
| `slow` | `0.28` | Deliberate, large animations |

Other `Motion` keys (defaults): `enter=0.28`, `exit=0.14`, `hover=0.12`, `press=0.08`, `release=0.22`, `stagger=0.035`, `enterScale=0.94`, `exitScale=0.96`, `pressScale=0.97`, `hoverScale=1.06`, `popFrom=0.9`, `knobStretch=1.2`, `handleGrow=1.3`, `handleHover=1.15`, `spin=0.8` (s per turn), `snap=0.3`, `hideDrift=12` (px), `popSlide=6`, `dialogRise=12`, `dialogDrop=8`, `bumpPx=2`, `shake={ amp=3, steps=4, step=0.04 }`, `cascade={ x=6, y=8 }`.

```lua
Theme = { Motion = { fast = 0.08, base = 0.15, slow = 0.25 } }
```

A per-window `Motion` override is honoured (`CreateWindow` calls `Animate.useMotion(theme.Motion)`), but it is **process-wide** like `SetAnimationsEnabled`: with several windows the last one created wins.

### Effect, Stroke, Opacity, Acrylic, Scrollbar, Sizes, Icon, Tooltip, Toast

Every number a component used to hard-code is a token (today's value is the default). Nested keys are named-field tables, never arrays, so they deep-merge leaf by leaf. Components adopt these incrementally as the visual-polish phases land — a key names the role it is reserved for; overriding it only takes effect once the owning component reads it.

| Group | Keys (defaults) |
|---|---|
| `Effect` | `shadowId=""` (shadows off until set to a 9-slice asset), `slice={ x0=49, y0=49, x1=450, y1=450 }`, `window={ spread=28, offsetY=6 }`, `dialog={ spread=32, offsetY=10 }`, `popover={ spread=18, offsetY=4 }`, `toast={ spread=16, offsetY=4 }`, `tooltip={ spread=10, offsetY=2 }`, `control={ spread=6, offsetY=0 }`, `lift={ spreadDelta=8, alphaDelta=-0.12 }` (drag/resize), `controlGlow="auto"` (off on phones), `skeleton={ period=1.1, rotation=15 }` |
| `Stroke` (UIStroke transparency) | `window=0.3`, `floating=0`, `control=0`, `divider=0.4`, `focusThickness=2` (px), `panel={ dark=0.6, light=0 }`, `search={ dark=0.8, light=0.5 }` |
| `Opacity` | `hoverWash=0.94`, `pressWash=0.9`, `hoverFill=0.12`, `pressFill=0.2`, `ghostHover=0.4`, `ghostPress=0.25`, `tabHover=0.92`, `tabPress=0.88`, `optionHover=0.6`, `rowHover=0.94`, `disabled=0.5`, `scrim=0.45`, `dialogScrim={ dark=0.5, light=0.6 }`, `glowHover=0.7` |
| `Acrylic` | `noiseId="rbxassetid://9968344105"`, `tileSize=128`, `strokeAlpha=0.3`, `highlightBand=0.45`, `frost=0.12` (default window `Transparency`), `glintFade=0.25` |
| `Scrollbar` | `imageId=""` (engine default), `alpha=0.35` |
| `Sizes` (px) | `icon=16`, `iconSm=14`, `iconButton=26`, `touchHit=44`, `scrollbar=4`, `progress=8`, `sliderHit=24`, `chip=22`, `knob=20`, `tagMeasureFudge=1.08`, `dragKeep=40`, `titleBar=40`, `titleBarTall=56`, `resizeGrip=12`, `resizeGripInset=4`, `splitGap=12`, `indicator={ w=3, h=18, stretch=26, radius=2, haloW=9, haloH=26, haloAlpha=0.85 }`, `grip={ w=2, h=24 }`, `fab={ size=44, simple=50, peek=15, hoverPeek=7, margin=16, radius=12, popFrom=0.6 }` |
| `Icon` (names of `Colors` tokens, resolved at paint time so `SetMode`/`SetAccent` re-tint) | `structural="mutedForeground"`, `structuralActive="foreground"`, `accent="primary"` |
| `Tooltip` | `delay=0.35` (s), `gap=6`, `padX=8`, `height=24` |
| `Toast` | `width=300`, `inset=16`, `gap=8`, `peek=10`, `maxVisible=3`, `peekScale=0.05`, `peekFade=0.18`, `barHeight=3`, `padX=12`, `padY=8`, `progressInset=0`, `slide=48`, `exitSlide=32`, `exitScale=0.95`, `typeTint=0.35`, `badgeAlpha=0.85`, `staggerCap=5` |

### Per-mode values and helpers

- `{ dark=, light= }` leaves (`Stroke.panel`, `Stroke.search`, `Opacity.dialogScrim`) are read via `Theme.modeVal`; override one side and the other keeps its default (a missing side falls back to `dark`).
- `EzUI.Theme.MODE_EFFECTS.dark` / `.light` hold the per-mode effect values: `sheenTop`, `sheenBottom`, `highlight`, `grain`, `grainTint`, `edgeTop`, `edgeBottom`, `glint`, `inset`, `shadow`, `glow` (dark: sheen 255/214,214,222, highlight 0.93, grain 0.92, edge 0/0.65, glint 0.86, shadow 0.5, glow 0.72; light: `sheenTop=nil` → falls back to `Colors.card`, sheenBottom 240,240,243, highlight 1, grain 0.97 tinted black, edge 0.2/0.7, glint 1, shadow 0.8, glow 0.8). Module-level — **not** part of the per-window `Theme` merge; components read `Theme.fx(theme)` at paint time.

| Helper (also on every window theme instance) | Behaviour |
|---|---|
| `Theme.mix(a, b, t)` | New `Color3` lerped on `.R/.G/.B`; `t` clamped to `0..1`; errors on a `nil` colour |
| `Theme.fx(theme)` | `MODE_EFFECTS[theme.Mode]`; unset/unknown mode → `dark` |
| `Theme.modeVal(theme, tok)` | `tok[theme.Mode]` for a `{ dark, light }` table (missing side → `dark`); anything else passes through |
| `Theme.FontFace(weight)` | `Font.fromName("BuilderSans", weight)`; `nil` → Regular, `SemiBold` → Bold; `nil` if the `Font` global is missing |

## Deep-Merge Behavior

A partial `Theme` override is deep-merged onto the built-in defaults. Unspecified tokens retain their defaults. There is no need to copy the entire theme table.

```lua
-- Only primary changes; all other tokens stay at their zinc dark defaults.
EzUI:CreateWindow({
    Theme = { Colors = { primary = Color3.fromRGB(99, 102, 241) } }
})
```

Nested groups merge leaf by leaf: `{ Sizes = { fab = { size = 48 } } }` changes one value and inherits the rest of `Sizes.fab`. `Theme.PALETTES` and `Theme.MODE_EFFECTS` are module-level and are not part of the per-window merge.

## Color Mode (Dark / Light)

EzUI ships two complete palettes: `"dark"` (default, zinc-based) and `"light"` (white-based). Set the mode at window creation time or switch it live:

```lua
-- Light mode from the start
local Window = EzUI:CreateWindow({ Mode = "light" })

-- Switch at runtime
Window:SetMode("light")
Window:SetMode("dark")
print(Window:GetMode())  -- "dark" or "light"
```

Per-window `Theme.Colors` overrides apply on top of whichever palette is active. Switching mode does not reset a `primary` or `primaryForeground` override that is already set.

Light palette is a four-step tonal ladder: `background` 240 → `surface` 244 → `input` 250 → `card` 255 (`border` 228, `switchTrackOff` 212), so panels separate by tone; the per-mode `Stroke.panel` / `Stroke.search` hairlines firm up in light (`0` / `0.5`) and stay faint in dark.

`SetMode` re-skins everything alive — acrylic shell (fill, sheen, rim, grain), content-panel and search hairlines, icon tints, and any open toast or dialog — not only the controls inside tabs.

### Accent

```lua
Window:SetAccent("Indigo")                      -- "Adaptive" (default), "Indigo", "Violet", "Emerald", "Sky", "Rose"
Window:SetAccent(Color3.fromRGB(99, 102, 241))  -- any Color3; foreground picked for contrast
```

Swaps only `primary` / `primaryForeground`. `"Adaptive"` follows the mode (near-white in dark, near-black in light); a named or custom accent survives `SetMode`. Accent parts re-tint live, including open toasts and dialogs.
