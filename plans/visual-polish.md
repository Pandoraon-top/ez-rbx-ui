# Rencana Polish Visual & Efek — EzUI

Spine yang dipilih: **Quiet System** (skor tertinggi gabungan 3 juri: 24.5), digabung dengan **Motion grammar** (24) sebagai lapisan gerak, dan graft depth dari **Lit Glass** + **Layered Light** (acrylic fix, shadow, edge light, glow) serta beberapa ide Signature Light (Theme.mix/useMotion, FAB halo finite, keybind chip). Semua ide yang masuk daftar `infeasible` atau ditolak ≥2 juri dibuang (lihat bagian 6). Revisi ini menambah defect audit yang sebelumnya luput (Resizable, UI-scale overlay, drag clamp, resize grip, dialog keyboard, Card, NumberBox wheel), membetulkan item yang tidak jalan di bawah `ZIndexBehavior.Sibling`/mock, dan memindahkan prasyarat (mock, palet light, sidebar handle) ke depan.

---

## 1. Arah visual

EzUI tetap zinc/shadcn, tapi berhenti terlihat "flat dan sama semua". Yang berubah: **hierarki tipografi asli** (BuilderSans Medium/Bold akhirnya benar-benar dirender), **tangga tonal 4 langkah** (chrome acrylic → content panel → row surface → field inset) yang konsisten di dark dan light, **satu vocabulary state** (hover / press / focus / disabled / loading) yang dipakai semua control dengan timing yang sama, dan **depth yang jujur**: acrylic dark yang hari ini ter-crush jadi hitam pekat diperbaiki, window dan popover dapat drop shadow 9-slice, border atas "lit" lewat gradient stroke. Accent muncul sebagai *cahaya* (ring focus, glow toggle ON, halo indicator) bukan sebagai flood warna. Motion pakai dua kata kerja saja: **unfold** (masuk pelan, overshoot) dan **fold** (keluar cepat, fade), dari window sampai tooltip, dan semuanya kolaps ke frame terakhir secara sinkron kalau reduced motion aktif.

**5 prinsip:**

1. **Token dulu, literal tidak boleh ada.** Semua alpha, spread, durasi, radius, tinggi row, jarak slide/shake/bump, dan role warna icon jadi token di `core/theme.lua` dengan nilai hari ini sebagai default. Nilai per-mode hidup di `Theme.MODE_EFFECTS[mode]` (tabel terpisah, karena `applyMode` cuma copy `Colors`). Angka yang muncul di plan ini adalah *nilai default token yang disebut namanya*; angka tanpa nama token di plan = bug plan, bukan izin hardcode. Satu-satunya pengecualian: konstanta geometri test yang memang di-pin (Track 44×24, Position pin FAB).
2. **Satu resep per state, bukan per komponen.** Hover wash, press scale, focus ring, disabled dim, empty state, scrollbar — semuanya dari `core/recipes.lua`; komponen cuma memanggil.
3. **Shadow & glow = sibling di bawah, highlight = child.** Dengan `ZIndexBehavior.Sibling` child selalu render di atas parent dan sibling dibandingkan lewat ZIndex, jadi layer gelap/glow harus **sibling dengan ZIndex lebih rendah dari host** (bukan child, bukan sibling dengan ZIndex tinggi); rim/sheen/noise adalah UI* atau child yang di-clip. Tidak pernah menambah UIStroke/UIGradient/UIScale kedua langsung di frame yang dicari test via `FindFirstChildOfClass` (Main, FAB, Surface).
4. **Semua gerak lewat Animate.** Loop (spinner, shimmer, pulse) = satu repeat tween dengan handle `Cancel`, tidak ada Heartbeat baru; stagger pakai `TweenInfo.delayTime` lewat argumen `delay` di `Animate.to/toThen/chain` (engine-side), bukan `task.delay`. `Animate.setEnabled(false)` → goal langsung diterapkan, loop jadi no-op.
5. **Parity itu fitur.** Setiap efek punya nilai light mode, rest state untuk reduced motion, dan perilaku touch yang tidak bergantung hover. Setiap part berwarna baru wajib masuk closure `AccentReg`/`themer.register` pemiliknya, dan penulisan GUI dari engine thread (property signal, `task.delay`, `IsLoaded`) wajib lewat `Safe.mutate`.

---

## 2. Fondasi dulu

Semua ini nol perubahan visual (default = literal hari ini) dan harus hijau di `make check` sebelum fase 1. **F11 (mock) mendarat paling dulu** karena 1.9/1.11/2.19/3.1 hanya bisa diuji setelah mock menangkap repeat/cancel/reduced-motion.

### F1. Token groups — `core/theme.lua` (S)

Tambahkan ke `DEFAULT` (deepMerge sudah handle nested table; semua group = named fields, **jangan** array — termasuk `Effect.slice`):

```lua
Motion = { fast=0.12, base=0.18, slow=0.28,              -- pinned oleh animate_test, jangan ubah
  enter=0.28, exit=0.14, hover=0.12, press=0.08, release=0.22, stagger=0.035,
  enterScale=0.94, exitScale=0.96, pressScale=0.97, hoverScale=1.06, popFrom=0.9,
  knobStretch=1.2, handleGrow=1.3, handleHover=1.15, spin=0.8, snap=0.3, hideDrift=12,
  popSlide=6, dialogRise=12, dialogDrop=8, bumpPx=2,
  shake={ amp=3, steps=4, step=0.04 }, cascade={ x=6, y=8 } }
Effect = { shadowId='', slice={ x0=49, y0=49, x1=450, y1=450 },   -- '' = shadow off sampai asset diverifikasi di Studio
  window={spread=28,offsetY=6}, dialog={spread=32,offsetY=10}, popover={spread=18,offsetY=4},
  toast={spread=16,offsetY=4}, tooltip={spread=10,offsetY=2}, control={spread=6,offsetY=0},
  lift={spreadDelta=8,alphaDelta=-0.12}, controlGlow='auto' }   -- 'auto' = off di Device.IsMobile()
Stroke = { window=0.3, floating=0, control=0, divider=0.4, focusThickness=2,
  panel={dark=0.6,light=0}, search={dark=0.8,light=0.5} }
Opacity = { hoverWash=0.94, pressWash=0.9, hoverFill=0.12, pressFill=0.2, ghostHover=0.4, ghostPress=0.25,
  tabHover=0.92, tabPress=0.88, optionHover=0.6, rowHover=0.94, disabled=0.5, scrim=0.45,
  dialogScrim={dark=0.5,light=0.6}, glowHover=0.7 }
Acrylic = { noiseId='rbxassetid://9968344105', tileSize=128, strokeAlpha=0.3, highlightBand=0.45 }
Scrollbar = { imageId='', alpha=0.35 }
Sizes = { icon=16, iconSm=14, iconButton=26, touchHit=44, scrollbar=4, progress=8, sliderHit=24, chip=22,
  knob=20, tagMeasureFudge=1.08, dragKeep=40, titleBar=36 --[[= nilai hari ini]],
  resizeGrip=12, resizeGripInset=4, splitGap=12,
  indicator={w=3,h=18,stretch=26,radius=2,haloW=9,haloH=26,haloAlpha=0.85}, grip={w=2,h=24},
  fab={size=44,simple=50,peek=15,hoverPeek=7,margin=16,radius=12,popFrom=0.6} }
Icon = { structural='mutedForeground', structuralActive='foreground', accent='primary' }
Font.overline = { Weight=Enum.FontWeight.Medium, Size=11 };  Font.body.LineHeight = 1.25
Tooltip = { delay=0.35, gap=6, padX=8, height=24 }
Toast = { width=300, inset=16, gap=8, peek=10, maxVisible=3, peekScale=0.05, peekFade=0.18, barHeight=3,
  padX=12, padY=8, progressInset=0, slide=48, exitSlide=32, exitScale=0.95, typeTint=0.35, badgeAlpha=0.85,
  staggerCap=5 }
Radius.input = 6;  Radius.xs = 2
```

Tabel per-mode terpisah + helper:

```lua
Theme.MODE_EFFECTS = {
  dark  = { sheenTop=rgb(255,255,255), sheenBottom=rgb(214,214,222), highlight=0.93, grain=0.92, grainTint=rgb(255,255,255),
            edgeTop=0.0, edgeBottom=0.65, glint=0.86, inset=rgb(196,196,206), shadow=0.5, glow=0.72 },
  light = { sheenTop=nil --[[→ theme.Colors.card, identity multiplier & test 121-123 tetap hijau]], sheenBottom=rgb(240,240,243),
            highlight=1, grain=0.97, grainTint=rgb(0,0,0), edgeTop=0.2, edgeBottom=0.7, glint=1, inset=rgb(236,236,240), shadow=0.8, glow=0.8 } }
Theme.fx(theme)            -- MODE_EFFECTS[theme.Mode or 'dark']
Theme.modeVal(theme, tok)  -- tok[theme.Mode] kalau tok tabel per-mode, else tok
Theme.mix(a, b, t)         -- Color3.new lerp manual pakai .R/.G/.B saja (verify_bundle Color3 throw kalau baca R8/Lerp)
Theme.FontFace(weight)     -- `if Font and Font.fromName then return Font.fromName('BuilderSans', weight) end; return nil`
```

> Catatan: **bukan** `Font.fromEnum(Enum.Font.BuilderSans, weight)` — `fromEnum` cuma terima satu argumen, weight-nya dibuang (ketiga juri menandai ini). Jangan pernah minta `SemiBold` (BuilderSans tidak punya 600). Nilai `MODE_EFFECTS.light` di atas adalah tebakan awal terhadap palet light **baru** (1.13); tuning final dilakukan sekali di sesi Studio 2.3/2.4/2.5, setelah 1.13 masuk.

### F2. Create helpers — `core/create.lua` (S)

- `Create.stroke(color, thickness, transparency)` — arg ke-3 opsional, hanya ditulis kalau non-nil (create_test default tetap).
- `Create.gradient({ rotation, stops = { {t, Color3}, ... } })` → UIGradient dengan `ColorSequence.new({ ColorSequenceKeypoint... })` (selalu bentuk array; window_test 121-123 baca `grad.Color.color[1].Value`).
- `Create.shade({ rotation, stops = { {t, alpha}, ... } })` → UIGradient dengan `NumberSequence` keypoint array.
- `Create.text(label, theme, role)` — set `Font = Enum.Font.BuilderSans`, `TextSize = theme.Font[role].Size`, `LineHeight` kalau role punya, dan `FontFace = Theme.FontFace(theme.Font[role].Weight)` hanya kalau non-nil. Hanya dipanggil pada TextLabel/TextButton/TextBox (strict mock: FontFace ada di TEXT_PROPS).

### F3. Animate helper pack — `core/animate.lua` (S)

Default `info` (0.18/Quart/Out), `pop`, `springTo`, `rotateTo` tidak diubah (animate_test). **Harus masuk sebelum 2.6, 2.13 dan 3.6** — ketiganya memanggil argumen `delay`.

- `Animate.info(dur, style, dir, delay)` — arg ke-4 → `TweenInfo.new(t, style, dir, 0, false, delay or 0)`. **`delay or 0`, bukan nil**: `TweenInfo.new` dengan `delayTime = nil` tidak terverifikasi aman di Roblox, dan mock tidak memvalidasi tipe sehingga error hanya muncul di Studio.
- `Animate.to(inst, dur, goal, style, dir, delay)` / `Animate.toThen(inst, dur, goal, onDone, style, dir, delay)` / entri `Animate.chain` `{inst,dur,goal,style,dir,delay}` — argumen `delay` trailing diteruskan ke `info`. Semua call site lama tidak berubah (arg opsional di ekor).
- `Animate.EASING += { enter=Quint, exit=Quart, snap = Enum.EasingStyle.Quad or Enum.EasingStyle.Quart }`, `Animate.DIR = { In, Out, InOut }`.
- `Animate.useMotion(tbl)` — tabel yang dibaca `resolve()`; `Window.new` panggil `Animate.useMotion(theme.Motion)` setelah `Theme.new` supaya `CreateWindow{ Theme = { Motion = {...} } }` akhirnya berlaku (hari ini diabaikan, animate.lua:18 baca module Theme). Process-wide, sama seperti `setEnabled` (dokumentasikan).
- **Flag eksplisit reduced motion:** `Animate.setEnabled(b)` (public, dipakai `SetAnimationsEnabled` dan `config.Animations`) set `explicit = true`; `Animate.applyDefault(b)` hanya menulis `enabled` kalau `explicit == false`; `Animate.isExplicit()`. Semantik "last writer wins" yang terdokumentasi (window.lua:47-49) tetap: `Animations = nil` tidak pernah menimpa pilihan eksplisit sebelumnya (lihat 1.11).
- `Animate.loop(inst, dur, goal, style, reverses)` → `TweenInfo.new(dur, style or Linear, InOut, -1, reverses == true, 0)`; return `{ Cancel = fn }`; kalau `not enabled` → tulis goal rest, return handle no-op. **Jangan** pernah restart dari `Completed` (mock fire Completed sinkron → rekursi).
- `Animate.spin(img)` = loop Linear `Rotation 360` dari 0, periode `Motion.spin`; `Cancel` reset `Rotation = 0`.
- `Animate.pulse(inst, dur, goal, style, cycles)` = loop dengan `reverses=true`, `repeatCount = cycles or -1`.
- `Animate.exitTo(inst, dur, goal, onDone)` = `toThen` dengan `EASING.exit / DIR.In`.
- `Animate.chain({ {inst,dur,goal,style,dir,delay}, ... }, onDone)` = toThen berantai (sinkron di mock).
- `Animate.popIn(frame, edge)` / `Animate.popOut(frame, onDone)` — resep popover: pre-set UIScale `1 - (1 - Motion.exitScale)`→ pakai token `Motion.popFrom`? **Tidak** — popover pakai `Motion.exitScale` (0.96→0.97 dibulatkan ke token yang ada: `exitScale`) + Position `±Motion.popSlide` ke arah anchor, springTo 1 Back/Out `base` + Position Quart `fast`; out: scale → `exitScale` Quart/In `exit` lalu `onDone`.
- Handle `{ Cancel }` **wajib** dibungkus fungsi sebelum `maid:Give` (`maid:Give(function() h.Cancel() end)`) — maid.lua cuma kenal Disconnect/Destroy.

### F4. Icons — `core/icons.lua` (S)

Tambahkan **di bawah** tabel DATA (generator `make icons` menimpa di atas marker): `Icons.Init(R)` (capture `R.Animate`), `Icons.tint(img, color3, dur)` = `Animate.to(img, dur or 'fast', { ImageColor3 = color3 })`, dan fast-path di `Icons.apply`: kalau `Image` + rect sudah sama, hanya tulis `ImageColor3`. `apply()` tetap sinkron (icons_test).

### F5. `core/effects.lua` — layer kit (M, modul baru)

Registrasi di **`main.lua` R table DAN `tests/helper.lua` loadLib** (kalau lupa salah satu → nil headless). `Effects.Init(R)` hanya simpan referensi (`Create, Theme, Animate, Safe, Device`) — urutan Init `pairs()`-undefined.

- `Effects.shadow(parent, { name, level, zIndex })` → ImageLabel *terisi* (bukan hollow): `Image = Effect.shadowId`, `ScaleType = Slice`, `SliceCenter = Rect.new(slice.x0, slice.y0, slice.x1, slice.y1)` **hanya kalau** `Rect and Rect.new`, `ImageColor3 = Color3.new(0,0,0)`, `ImageTransparency = fx.shadow`, `AnchorPoint (0.5,0.5)`, `Active = false`, `BackgroundTransparency 1`, `ZIndex = zIndex` (caller wajib memberi nilai **lebih rendah dari host** — lihat prinsip 3). Return `nil` kalau `shadowId == ''` — semua caller toleran nil.
- `Effects.place(shadow, x, y, w, h, level)` — geometri one-shot (popover, tooltip: `Size = w+2*spread, h+2*spread`, `Position = centre + offsetY`).
- `Effects.mirror(shadow, host, level)` — set Position/Size dari `host.Position/host.Size` (+2*spread, +offsetY). Dipakai window setelah setiap penulisan Position/Size (lihat 2.3), dan FAB (2.18).
- `Effects.follow(shadow, host, level, maid)` — connect `host:GetPropertyChangedSignal('AbsoluteSize'|'AbsolutePosition')` → `Safe.mutate(sync)`; nil-guard (mock Absolute* nil → skip). Hanya untuk dialog card (AutomaticSize).
- `Effects.glow(parent, colorToken, level, zIndex)` → asset yang sama, `ImageColor3 = colorToken` (**tabel token langsung**, supaya identity-compare & reskin jalan), `ImageTransparency 1`, `ZIndex = zIndex`; return nil kalau `controlGlow == 'auto' and Device.IsMobile()`. Parent selalu **sibling host** (Track/overlay root), tidak pernah child host.
- `Effects.rim(stroke, theme)` — child UIGradient di UIStroke: `Rotation 90`, `Transparency = NumberSequence{(0, fx.edgeTop), (1, fx.edgeBottom)}`; `stroke.Color` tidak disentuh (test bandingkan Color by reference).
- `Effects.lift(shadow, theme, on)` — `Animate.to(shadow, 'fast', { Size = ±2*lift.spreadDelta, ImageTransparency = fx.shadow + lift.alphaDelta })`.
- `Effects.reskin(layer, theme, kind, colorToken)` — re-apply alpha/tint per mode.
- `Effects.skeleton(parent, { size, radius })` → `{ Frame, Stop }` (detail di 3.1).

### F6. `core/recipes.lua` — state kit (M, modul baru)

Registrasi ganda seperti F5. Stateless (helper cache modul antar test).

- `Recipes.hover(hit, { theme, host, corner, inset = {x,y}, kind = 'wash'|'text'|'fill', label, icon })` → `{ reskin, disconnect }`. `wash`: child Frame `'Hover'` di `host` (**bukan** `'Active'`, tab_test 63), `Size = UDim2.new(1, 2*inset.x, 1, 2*inset.y)`, `Position = (0,-inset.x,0,-inset.y)` (kompensasi UIPadding row), UICorner = corner, `ZIndex 0`, `Active false`, `BackgroundColor3 = theme.Colors.foreground`, `BackgroundTransparency 1` → `Opacity.hoverWash` on MouseEnter (`Motion.hover`), `Opacity.pressWash` on Down, kembali 1 on Leave dan (touch) on Up. `text`: tween `label.TextColor3` muted→foreground + `Icons.tint(icon)`. **`fill`**: tanpa Frame baru — tween `host.BackgroundTransparency` sendiri ke `Opacity.rowHover` (untuk host yang punya UIListLayout horizontal/vertikal seperti table Row, tab button; BackgroundColor3 tidak disentuh → identity test aman). Skip kalau `not Device.SupportsHover()`. Jangan pernah parent wash (`kind='wash'`) ke host yang punya UIListLayout (TabContent, accordion Content, table Row) — pakai `fill`.
- `Recipes.press(hit, scaleHost, { theme })` — UIScale di `scaleHost` (bukan di row; UIListLayout reflow): Down → `Motion.pressScale` over `press`; Up/Leave → `springTo 1` over `release`. Kalau `scaleHost == nil` → press = wash/fill saja tanpa scale (dipakai tab button, 2.7).
- `Recipes.iconButton(btn, { theme, icon, rest, hover, hitSize, parent })` — **button tetap ukuran glyph-nya (18px; ImageButton merender Image sepenuh Size, jadi glyph = button)**; hit target = sibling ImageButton transparan `'<Name>Hit'` berukuran `hitSize` (`Sizes.iconButton`, `Sizes.touchHit` di touch) centred di posisi button, ZIndex button+1, `AutoButtonColor=false`; handler MouseEnter/MouseLeave/MouseButton1Click/Down/Up **dipasang ke keduanya** (`for _, src in ipairs({btn, hit})`) sehingga window_test 437-448/201-211 yang fire event di `Close` dan membaca `close.ImageColor3` tetap jalan. Wash `Radius.sm` di hit, `Icons.tint` rest→hover pada btn.
- `Recipes.focus(stroke, host, getColor, { theme })` — `host.Focused/FocusLost` (+ `SelectionGained/Lost` hanya kalau `host.SelectionGained ~= nil`) → `Animate.to(stroke,'fast',{ Color = getColor(), Thickness = focused and Stroke.focusThickness or 1 })`. `SelectionImageObject`: **jangan deteksi lewat baca** (nil di Roblox maupun mock karena nil memang default) — tulis via `pcall(function() host.SelectionImageObject = invisible end)`.
- `Recipes.disabled(parts, on, theme)` — `parts = { {inst, prop, rest}, ... }` (prop = BackgroundTransparency/ImageTransparency/TextTransparency, `rest` = nilai saat enabled) → tween ke `Opacity.disabled` atau `rest`. Tabel per-control ada di 2.8.
- `Recipes.empty(parent, { theme, text, icon, zIndex })` → Frame `'Empty'` (ImageLabel 16px muted + TextLabel muted), `{ Frame, SetVisible }`.
- `Recipes.scrollbar(sf, theme)` — `ScrollBarThickness = Sizes.scrollbar`, `ScrollBarImageColor3 = theme.Colors.border`, `ScrollBarImageTransparency = Scrollbar.alpha`; Top/Mid/BottomImage hanya kalau `Scrollbar.imageId ~= ''`.

### F7. `core/overlay.lua` (S)

- `Overlay.Z = { catcher=1000, popover=1001, modal=1500, fab=1700, toast=1800, tooltip=2000 }` (komponen baca dari sini).
- `Overlay.placePopover(anchorPos, anchorSize, w, h, gap)` → `x, y, openUp` (flip + clamp pakai `Overlay.viewport()`); dipakai `selectbox.computePos` dan colorpicker. `w, h` yang dilempar caller sudah dikali `Overlay.scale()` (2.22).
- `Overlay.setScale(n)` / `Overlay.scale()` — angka UI scale terakhir yang diset window (process-wide, last-writer-wins seperti `Animate.setEnabled`; dokumentasikan). **Tidak pernah** memasang UIScale di overlay root: catcher `(1,0,1,0)` akan berhenti menutup layar.
- `Overlay.pushDialog()` / `Overlay.popDialog()` → depth integer; `Overlay.reset()` juga reset depth ke 0. Dipakai 2.12 untuk dialog bertumpuk.

### F8. `core/themer.lua` (S)

`self.reskin(reason)` → `pcall(fn, reason)`; `Window.SetMode/SetAccent` kirim `'mode'|'accent'`. Closure lama abaikan arg ekstra.

### F9. `core/device.lua` (S)

`Device.SupportsHover()` = `UserInputService.MouseEnabled == true`; `Device.PrefersReducedMotion()` = pcall-read `GuiService.ReducedMotionEnabled` (default false). Additive ke `EzUI.Device`. Prasyarat 1.11 (bersama mock `GuiService.ReducedMotionEnabled` di F11).

### F10. `core/acrylic.lua` — `Acrylic.reskin` + token read + signature opts (S)

`decorate(frame, theme, opts)` baca `theme.Acrylic.*` (default identik → acrylic_test tetap). **F10 memiliki signature opts** yang dipakai 1.1/1.5/2.4/2.11/2.12:

```lua
opts = { solid = false, transparency = nil, base = nil,
         strokeAlpha = theme.Acrylic.strokeAlpha,   -- default 0.3 (acrylic_test 6-13 tetap)
         radius = theme.Radius.window,               -- UICorner untuk noise/sheen/glint
         edge = false,                               -- Effects.rim + 'AcrylicGlint' (2.4)
         padInset = 0 }                              -- host ber-UIPadding: layer di-size (1,2p,1,2p) @ (0,-p,0,-p)
```

`Acrylic.reskin(frame, theme, opts)` re-apply fill, sheen keypoints, stroke colour + alpha, grain alpha + tint, rim/glint. `Acrylic.Init(R)` juga capture `R.Theme` (untuk `Theme.fx`) dan `R.Effects`. Sheen fix-nya sendiri ada di 1.1.

### F11. Mock & harness — lihat bagian 7 (M)

Mendarat **sebelum semua item lain**: capture tween (repeat/cancel/delay), `Font.fromName`, `Rect`, `GuiService.ReducedMotionEnabled`, KeyCode tambahan (Escape/Return/ButtonA/ButtonB), `TextService` stub, `mock.imagesLoaded`, `mock.timerMode='queued'` + `mock.advance`, Destroy rekursif, signal `GetPropertyChangedSignal` yang di-cache per (instance, prop), strict allowlist per-class, `R.Effects/R.Recipes` di helper.

---

## 3. Fase 1 — Quick wins (impact tinggi, effort rendah, risiko kecil)

Tujuan: screenshot berubah drastis tanpa motion baru; semua hasil verifikasi juri tentang defect nyata dibereskan.

### 1.1 Acrylic un-crush + noise clipped + Acrylic.reskin — **M**
- **Visual:** Dark window sekarang render ~hitam murni karena `UIGradient.Color` *mengalikan* `BackgroundColor3`: `background(9,9,11) × card(24,24,27)/255 ≈ 1`. Setelah fix, zinc-950 utuh dengan sheen ~15% top→bottom, plus lift putih tipis di tepi atas (9 → ~26). Noise tile tidak lagi nongol di luar sudut 12px; grain dark = speckle putih, light = speckle hitam @0.97.
- **Mekanisme:** `core/acrylic.lua`: gradient `Color = {(0, fx.sheenTop or theme.Colors.card), (1, fx.sheenBottom)}`; `AcrylicNoise` dapat `Create.corner(opts.radius)`, `ImageColor3 = fx.grainTint`, `ImageTransparency = fx.grain`; child Frame baru `'AcrylicSheen'` (putih, `ZIndex 0`, `Active false`, UICorner sama, `Create.shade{ rotation=90, stops={{0,fx.highlight},{Acrylic.highlightBand,1},{1,1}} }`, `Visible = fx.highlight < 1`; skala alpha-nya dengan `(1 - transparency)` supaya window Transparency 0.6 tidak over-bright). Noise & sheen memakai `opts.padInset` (F10): host ber-UIPadding seperti ColorPopover (`Create.padding{all=8}`, colorpicker.lua:71) mem-offset **semua** child, jadi layer `(1,0,1,0)` tidak pernah menyentuh tepi bulat — dengan `padInset=8` layer di-size `(1,16,1,16)` di `(0,-8,0,-8)`. UIGradient sheen overlay adalah *grandchild* Main → `Main:FindFirstChildOfClass('UIGradient')` tetap gradient acrylic. Hanya untuk host **tanpa UIListLayout** (Main, SelectDropdown, ColorPopover); dialog card & toast tetap `solid`/tanpa sheen frame. `window.lua:616-641` baris 630-640 → `Acrylic.reskin(main, theme, { base = theme.Colors.background })`.
- **File:** `core/acrylic.lua`, `components/window.lua`, `tests/acrylic_test.lua`, `tests/window_test.lua`.
- **Risiko:** angka sheen/highlight harus di-tune di Studio (interaksi dengan `config.Transparency`) — sesi tuning dilakukan **setelah 1.13** supaya light hanya di-tune sekali. Mitigasi: token semua; window_test 121-123 tetap hijau karena light `sheenTop` resolve ke `theme.Colors.card` by reference; tambah test dark: `keypoint[1].Value` putih, `[2]` == `MODE_EFFECTS.dark.sheenBottom`. Assertion headless bersifat **structure-only** (keypoint, nama child, UICorner ada); rendering diverifikasi Studio.

### 1.2 Font weight asli + overline + truncate + LineHeight — **M**
- **Visual:** Window title Bold 18, dialog title Bold; row Title (Toggle/SelectBox/TextBox/NumberBox/Keybind/ColorPicker), tab Label, accordion Title, card Title, button Label, toast Title, table header Medium; section/group header jadi `Font.overline` (Medium 11, uppercase, `Spacing.sectionTop` 8 di atas via UIPadding child); paragraph/message/body LineHeight 1.25; Title/Subtitle/card Title/toast Title/tab Label/table cell `TextTruncate.AtEnd`. Tag pill lebar diukur.
- **Mekanisme:** ganti 47 call site `Font = Enum.Font.BuilderSans` dengan `Create.text(label, theme, role)` (mekanis). `label.lua:55` size 11 → `Font.overline.Size`; `window.lua:408-414` GroupHeader 24px `TextYAlignment Bottom`, `PaddingLeft 10` (sejajar tab label); `table.lua` header Medium 12 + UIPadding 4 kiri/kanan agar sejajar body cell + Frame `'HeaderRule'` 1px border @ `Stroke.divider` sebagai child **root** di y=25 (bukan di Body — table_test hitung `'Row'` di Body). **Tag width:** `TextService:GetTextSize(text, size, Enum.Font.BuilderSans, Vector2.new(1e4, size))` menerima legacy Enum.Font tanpa weight, jadi Medium terukur lebih sempit dari render; `GetTextBoundsAsync` yield dan tidak boleh di build thread → pakai `width = math.ceil(measured.X * Sizes.tagMeasureFudge) + 2*padX`; pcall, kalau TextService nil (mock lama) fallback `#text*7`. Fudge 1.08 disetujui sebagai *toleransi klip ringan* untuk label Tag yang ekstrem.
- **File:** `core/theme.lua`, `core/create.lua`, `components/window.lua, label.lua, tab.lua, button.lua, dialog.lua, notification.lua, card.lua, table.lua, accordion.lua, toggle.lua, selectbox.lua, textbox.lua, numberbox.lua, keybind.lua, colorpicker.lua`.
- **Risiko:** teks Medium sedikit lebih lebar → AutoWidth button/Tag bisa clip. Mitigasi: tag width terukur (di atas), AutoWidth pakai UISizeConstraint yang sudah ada. Test: label_test pin `'GENERAL'` + warna saja; tidak ada pin TextSize header. Jalur terukur diuji headless lewat stub TextService (F11).

### 1.3 Reskin completeness + leak fix — **M**
- **Visual:** Setelah `SetMode('light')` tidak ada lagi part nyangkut warna dark: GroupHeader, ResizeGrip icon, Resizable grip UIStroke, Host LockScrim (radius ikut UICorner control), Image Lucide glyph, Card action Buttons (hari ini dibangun tanpa AccentReg), Card Banner bg, Table scrollbar, FAB placeholder (`window.lua:684`: circle FAB pakai `primaryForeground` — hari ini primary-on-primary, tidak kelihatan), toast/dialog/tooltip/dropdown/popover yang sedang hidup (register closure sementara, unregister saat dismiss/close).
- **Mekanisme:** tambah baris di closure masing-masing: `window.lua:616-641` (loop `groups` → `_header.TextColor3`, `Icons.apply(grip, ..., mutedForeground)`), `fab closure 778-788` (placeholder), `resizable.lua:104-112` (`grip:FindFirstChildOfClass('UIStroke').Color`; stroke pane ditambah di 2.21), `host.lua:56-63` (register closure `scrim.BackgroundColor3 = ctx.theme.Colors.background`), `image.lua` (closure baru + unregister di Destroy), `card.lua:49-52` (pass `AccentReg = opts.AccentReg` ke `Button.new`, `maid:Give(control)` bukan `control.Frame`; recolor Banner bg), `table.lua:59-69` (`Recipes.scrollbar(body, theme)` → warna border + `Scrollbar.alpha` — alpha **diset di fase ini**, 3.7 hanya menambah imageId), `label.lua:73-75` & `separator.lua:18` (simpan unreg, panggil di Destroy — hari ini bocor satu closure per Destroy). **Helper `Host.own(control, fn)`** di `host.lua`: `if control.Maid then control.Maid:Give(fn) else local d = control.Destroy; control.Destroy = function(...) fn(); if d then return d(...) end end end` — dipakai untuk unreg LockScrim, tooltip (2.14) dan disabled (2.8) karena Button/Label/Image/ProgressBar/Separator/Card tidak punya `.Maid`. Notification/Dialog/Tooltip terima `opts.AccentReg` opsional yang diteruskan `window.lua api:Notify/Dialog` (opts.Theme sudah di-set di :506-507). Closure window pakai `reason` untuk skip re-download title image saat `'accent'`.
- **File:** 12 file di atas + `core/themer.lua`.
- **Risiko:** rendah — semua di dalam pcall closure yang baca `theme.Colors` live. verify_bundle sudah round-trip SetAccent/SetMode dengan toast + dialog hidup.

### 1.4 Icon tint roles (rest/active) — **S** (deliberate test change)
- **Visual:** glyph struktural (accordion Caret, SelectBox Caret, NumberBox +/-, notification Close, TextBox Copy/Eye/Clear, resizable grip, window Close/Minimize/ResizeGrip) rest di `mutedForeground`, naik ke `foreground` saat **state** berubah (expanded/open/bound) — tween `Motion.fast`, bukan snap. Primary hanya untuk state semantik (indicator, check, toggle ON, tab selected icon, type icon, FAB chevron — pinned).
- **Mekanisme:** **hanya role + state, tanpa menyentuh handler hover** — hover wiring (MouseEnter/Leave di `window.lua:230-233/865-866`, `resizable.lua:79-80`, `textbox.lua:224-275`, `notification.lua:199-213`) dimiliki 2.7/2.21 supaya handler yang sama tidak ditulis dua kali. Yang diubah di sini: `theme.Icon` roles diresolve `theme.Colors[theme.Icon.role]` di closure; `Icons.apply` → `Icons.tint` untuk perubahan state di `accordion.lua:43-51/169-177` (caret muted collapsed, foreground expanded; lead Icon tetap primary — verify_bundle 181), `selectbox.lua:119-121/147-151/397-409` (open/closed), `numberbox.lua:49-58` (bound = `ImageTransparency 0.5`), rest colour resizable grip icon `primary` → `structural` (resizable.lua:78, closure :110).
- **Risiko:** `theme_test.lua:59-60` pin caret collapsed == `PALETTES.light.primary` → **ubah sengaja** ke `mutedForeground`. Close/Minimize/Chevron pin tidak berubah.

### 1.5 Stroke & radius roles — **S**
- **Visual:** satu warna border, tiga alpha: window acrylic 0.3, floating (toast/tooltip/dropdown/popover/dialog card) **opaque** ala shadcn, control 0, divider 0.4 (Separator, accordion Divider, HeaderRule, dialog footer). `Radius.input = 6` untuk semua field (TextBox/NumberBox Box hari ini 8), table row `Radius.xs = 2` (inset 4 di body radius 6).
- **Mekanisme:** `Create.stroke(color, 1, alpha)` di `notification.lua:182`, `tooltip.lua:18`, selectbox dropdown, colorpicker popover; `dialog.lua:106` → `Acrylic.decorate(card, theme, { solid = true, strokeAlpha = Stroke.floating })` (opt dari F10, default `Acrylic.strokeAlpha` 0.3 → acrylic_test aman); `separator.lua` `BackgroundTransparency = Stroke.divider` (test pin R8 63 + tinggi 1 saja).
- **Risiko:** nihil untuk test.

### 1.6 Pemisahan light mode: panel & search hairline — **S**
- **Visual:** ContentPanel dapat 1px border stroke (`Stroke.panel`: dark 0.6, light 0) — di light mode card 255 vs background 250 akhirnya terpisah; Search box dapat stroke (`Stroke.search`) + focus ring (1.7).
- **Mekanisme:** `window.lua:271-276` `Create.stroke(border, 1, modeVal(Stroke.panel))`, `:244-249` sama; recolor + re-alpha di closure shell. window_test 403-414 hanya pin warna ContentPanel.
- **Risiko:** nihil.

### 1.7 Focus ring 2px di semua field — **S**
- **Visual:** TextBox, NumberBox, sidebar Search, dropdown Search, SelectBox Field (saat open), Keybind chip (listening) → stroke `Color = ring`, `Thickness 1→2` over `Motion.fast`; blur balik. TextBox precedence tetap `invalid > focused > border`.
- **Mekanisme:** `Recipes.focus(...)`: `textbox.lua:278-283` (ganti dua `Animate.to`; `strokeColor()` tetap satu-satunya sumber Color → textbox_test R8 ring/border/destructive tetap sinkron), `numberbox.lua:117-122` (+ `strokeColor()` helper yang dipakai closure), `selectbox.lua` Open/Close set flag `open` → `fieldStrokeColor()`, `window.lua` searchInput Focused/FocusLost, `keybind.lua` listening (lihat 2.16).
- **Risiko:** Thickness tidak dipin; UIStroke thickness tidak mempengaruhi layout.

### 1.8 Tab: filmstrip easing + select simetris + hover text tint — **S**
- **Visual:** dua halaman carousel bergerak sebagai satu strip (hari ini incoming Quint, outgoing Quart); deselect di-tween seperti select (bukan snap); hover terlihat (label + icon → foreground; wash 0.92 saja ≤2 RGB unit). Press feedback tab button ditambah di 2.7.
- **Mekanisme:** `tab.lua:115` tambah `Animate.EASING.smooth` sebagai arg ke-5; `:105-108/:118-120` → `Animate.to(button,'fast',{BackgroundTransparency=0|1})`, `Animate.to(label,'hover',{TextColor3})`, `Icons.tint(icon)`; hapus tween BackgroundColor3 no-op (`:106`, `:142`); hover handler `:167-172` → `Recipes.hover(kind='text')`; closure `:139-148` re-derive dari `selected`/`hovering`. Tab.Init ambil `R.Device` untuk reset di touch.
- **Risiko:** tab_test pin 0/1/0.92/1 & Position.Y 0 — semua goal sinkron.

### 1.9 Animate.spin gantikan tiga spinner mentah — **S**
- **Visual:** spinner SelectBox/TextBox/Toast berhenti saat `Animations=false` (hari ini terus muter — pelanggaran constraint 3); glyph statis `'loader'` rotation 0.
- **Mekanisme:** `selectbox.lua:163-164`, `textbox.lua:251-254`, `notification.lua:220` → `entry.spin = Animate.spin(icon)`; cancel via maid (dibungkus fungsi) dan saat `setLoading(false)`/`applyUpdate`/`dismiss`. Mock (F11): `TweenInfo` simpan `RepeatCount`, tween apply `Rotation 360` sekali → notification_test 68 tetap; `Cancel` reset 0 → test 109 tetap; assert `mock.tweensFor(icon)[1].Info.RepeatCount == -1` dan `cancelled == true` setelah `setLoading(false)`. **Butuh F11 sudah masuk.**
- **Risiko:** nihil.

### 1.10 Alignment kecil: accordion inset & slider title — **S**
- **Visual:** nested row di accordion sejajar dengan header title (Content padding kiri/kanan `Spacing.inputX` 12, bukan `inputY` 8); Slider Title 14 seperti row lain.
- **Mekanisme:** `accordion.lua:82`, `slider.lua:35` (`Font.label.Size`; geometri row 62 / Track -16 tetap — theme_test 65-72).
- **Risiko:** nihil.

### 1.11 Reduced-motion default + hover gating + demo toggle — **S**
- **Visual:** user Roblox dengan "reduce motion" OS langsung dapat versi statis; hover wash tidak nyangkut di touch.
- **Mekanisme:** `window.lua:49`: `if config.Animations ~= nil then Animate.setEnabled(config.Animations) else Animate.applyDefault(not Device.PrefersReducedMotion()) end` — `applyDefault` hanya menulis kalau belum ada yang set eksplisit (F3), jadi `CreateWindow` kedua tanpa `Animations` (mis. stress window demo) **tidak** menyalakan lagi motion setelah `SetAnimationsEnabled(false)`; semantik "last writer wins" untuk writer eksplisit tetap. Semua hover recipe cek `Device.SupportsHover()`; `example/menu/settings.lua` Appearance: `AddToggle{ Text='Reduce motion', Callback=function(on) window:SetAnimationsEnabled(not on) end }`.
- **Risiko:** window_test 644-654 tetap (config eksplisit menang; mock GuiService default false). Tambah test: `SetAnimationsEnabled(false)` lalu `Window.new{}` tanpa Animations → `Animate.isEnabled() == false`; `withReducedMotion` + window tanpa config → false. Bergantung F9 + mock `GuiService.ReducedMotionEnabled` (F11).

### 1.12 Card: action AutoWidth + banner async + doc fix — **S**
- **Visual:** label tombol card tidak lagi terpotong di 96px; banner dari URL tidak memblok konstruksi card (slot 80px langsung terpesan, gambar masuk saat resolve); `docs/controls/image.md:42` benar (`img.SetImage(...)`, bukan `img:SetImage(...)` — API-nya `SetImage = function(v)`).
- **Mekanisme:** `card.lua:49-52` → `Button.new({ AutoWidth = true, Theme = theme, AccentReg = opts.AccentReg, ... })`, hapus `control.Frame.Size = UDim2.new(0, 96, 1, 0)`; `card.lua:23` → `if Asset.resolvable(opts.Banner) then` buat Banner (`Image=''`, bg surface) **sinkron**, lalu `Asset.imageAsync(opts.Banner, function(id) Safe.mutate(function() banner.Image = id end) end)`; kalau bukan resolvable → `Asset.image` seperti sekarang. Banner bg + Buttons recolor di closure AccentReg (1.3).
- **Risiko:** card_test (kalau ada pin Size 96) → cek dulu; Banner `Image` raw id tetap ditulis sinkron untuk asset id lokal (mock `imageAsync` sinkron).

### 1.13 Light palette retune — **S**, deliberate test change (dipindah dari fase 3)
- **Visual:** `PALETTES.light`: background (240,240,243), border (228,228,231), input (250,250,250); card 255, surface (244,244,245). Chrome/panel/row terpisah 11-15 level.
- **Mekanisme:** `core/theme.lua PALETTES.light`; **theme_test.lua:34 pin `background.R8 == 250`** → ubah ke compare by reference `PALETTES.light.background`. verify_bundle `R > 0.9` tetap (240/255 = 0.94). `MODE_EFFECTS.light` (F1) sudah ditulis terhadap palet ini.
- **Risiko:** harus mendarat **sebelum sesi tuning Studio** 1.1/2.3/2.4/2.5 supaya inset/edge/shadow light hanya di-tune sekali terhadap palet final.

---

## 4. Fase 2 — Motion & depth besar

Tujuan: window/popover/toast/dialog punya bobot; setiap control menjawab press; semuanya lewat dua verb unfold/fold.

### 2.1 Window pivot ke tengah — **S**
- **Visual:** semua pop window (entrance/Show/Hide/Close/SetUIScale) mengembang dari **tengah**, bukan dari sudut kiri-atas (UIScale pivot di AnchorPoint; Main hari ini (0,0)).
- **Mekanisme:** `window.lua:124-131` `AnchorPoint (0.5,0.5)`, `Position (0.5,0,0.5,0)`. Drag onChange (:845) tetap `start + delta` (+ clamp 2.23). Resize onChange (:876) tambah `Position += (dw/2, dh/2)` supaya sudut kiri-atas diam. `AdaptToViewport` (:913-919) branch userMoved: `left = clamp(cx - w/2, 0, vp.X - w)`, tulis `UDim2.new(0, left + w/2, 0, top + h/2)` → `Position.X.Scale` tetap 0 (533-534), untouched tetap 0.5 (537). Dialog scrim window-scoped (child, Size 1,1) tidak terpengaruh.
- **Risiko:** grep window_test dulu untuk pin `Position.Offset == -w/2`; tambah test `AnchorPoint == (0.5,0.5)` dan resize menjaga left edge. Cek di Studio: drag + resize + `SetUIScale(1.3)` pada window yang sudah dipindah.

### 2.2 Satu resep Show/Hide/Entrance/Close + hand-off ke FAB — **M** (satu PR dengan 2.3 + 2.4)
- **Visual:** Show = Visible, scale `exitScale*u → u` Back/Out `release` + stroke 1→`Stroke.window` + shadow 1→`fx.shadow` (Quart `base`); Hide = stroke/shadow → 1 `fast`, scale → `exitScale*u` Quart/In `exit`, drift `Motion.hideDrift` ke sisi FAB, lalu Visible=false + Position restore; Entrance = Show pada `enter` (0.28); Close = Hide dengan Back/In `base` (bukan `fast` 0.12 yang "cegukan") + BackgroundTransparency → 1. FAB pop-in dipanggil dari `onComplete` Hide (window "menjadi" tombol), bukan paralel.
- **Mekanisme:** local `materialise(on, dur, style)` di window.lua yang dipakai `:458-467`, `:468-477`, `:945-949`, `:955-970`; `hideGen` counter guard race Hide→Show→Hide; `SetTransparency` (:509) juga update upvalue `transp` (bug nyata: Show restore nilai lama). `showFab` di onComplete tetap dalam kontrak Safe: safe.lua:41 drain `while i <= #queue` sehingga job yang ditambahkan mid-flush ikut → window_test 655-665 tetap. **Drift:** tween `main.Position` dan `shadow.Position` (goal `+ offsetY`, TweenInfo sama) **paralel**, dan setelah restore Position di onComplete panggil `Effects.mirror(shadow, main, 'window')`; kalau `shadow == nil` drift jalan tanpa shadow. Drift skip saat `dragging`. StartHidden tetap tanpa animasi, pre-set nilai rest semua layer.
- **Dependensi:** langkah stroke/scale bisa mendarat sendiri; langkah shadow (`shadowScale`, drift shadow, alpha shadow) **ditambahkan oleh 2.3** dan dissolve stroke memakai `UIStroke.Transparency` yang gradient-nya diatur 2.4. Urutan implementasi dalam PR: 2.3 → 2.4 → 2.2.
- **File:** `components/window.lua`, `tests/window_test.lua`.
- **Risiko:** 582-588 tetap (semua langkah `Animate.to/toThen`, sinkron di mock); 79-89 Minimize sinkron; urutan teardown Close (95-108) tidak berubah. Stress: ≤ 8 `TweenService:Create` per Hide/Show (main scale, shadow scale, stroke, shadow alpha, drift ×2, bg, FAB pop).

### 2.3 Window drop shadow + drag/resize lift — **M**
- **Visual:** shadow lembut 28px offset 6px (0.5 dark / 0.8 light — di light mode ini satu-satunya yang memisahkan panel 250 dari dunia terang). Grab title bar / resize grip: shadow melebar 8px & gelap 0.12, stroke → opaque; lepas → balik (0.12s).
- **Mekanisme:** `shadow = Effects.shadow(gui, { name='WindowShadow', level='window', zIndex=0 })` sebagai **sibling Main di bawah gui** (Main ZIndex 1, overlay 1000), `AnchorPoint (0.5,0.5)`, plus UIScale sendiri `'shadowScale'`. Sinkronisasi **mirror eksplisit**, nol signal: `Effects.mirror(shadow, main, 'window')` dipanggil setelah setiap tulis `main.Position/Size` (drag onChange :845, resize :876, AdaptToViewport, SetUIScale :512-516), dan setiap tween `winScale` di `materialise` juga men-tween `shadowScale` dengan goal + TweenInfo sama (keduanya AnchorPoint 0.5 di Position yang sama → skala tentang titik yang sama). Drag.bind onBegin (:843) `Effects.lift(shadow, theme, true)` + `Animate.to(mainStroke,'fast',{Transparency=0})`; onEnd (:848) balik; sama di resize (:871/:882); `maid:Give(reset)` supaya Close mid-drag tidak meninggalkan state lifted. `SetTransparency(t)` → shadow alpha `fx.shadow + t*0.5`. Closure shell: `Effects.reskin(shadow, theme, 'shadow')`. `mainStroke` disimpan sebagai local (bukan FindFirstChildOfClass saat tween).
- **Risiko:** window_test 406-407 hanya larang `'HeaderSeparator'/'HeaderShadow'` **di bawah Main**; `'WindowShadow'` di gui. Bergantung `Effect.shadowId` — sampai diverifikasi di Studio, `Effects.shadow` return nil dan semua call site `if shadow then`. Kandidat id: `6015897843` (SliceCenter 49,49,450,450), `6014261993`, `5554236805` — PR wajib sertakan screenshot Studio sebelum default diisi. Headless: geometri mirror/lift structure-only; 9-slice tidak punya semantik di mock.

### 2.4 Edge lighting: gradient stroke + glint — **S**
- **Visual:** border 1px lebih terang di atas, memudar ke bawah (dark 0.3→0.75; light 0.44→0.79); garis glint putih 1px di tepi atas dalam radius, fade di kedua ujung (dark saja).
- **Mekanisme:** `acrylic.lua decorate(opts.edge=true)`: `Effects.rim(stroke, theme)` (UIGradient child di UIStroke — Transparency-nya mengalikan stroke; Color tidak disentuh → window_test 124 tetap) + Frame `'AcrylicGlint'` (`Size (1,-2r,0,1)`, `Position (0,r,0,0)`, putih, `BackgroundTransparency fx.glint`, `ZIndex 0`, `Active false`, `Create.shade{rotation=0, stops={{0,1},{0.25,0},{0.75,0},{1,1}}}`, `Visible = fx.glint < 1`). Window pass `edge=true`; dissolve Hide men-tween `UIStroke.Transparency` (bukan gradient). Reskin di `Acrylic.reskin`.
- **Risiko:** acrylic_test hitung UIStroke by ClassName di direct children → gradient child tidak mengubah count. Verifikasi di Studio gradient di stroke child benar-benar render (structure-only headless). Tuning alpha light dilakukan terhadap palet 1.13.

### 2.5 Content panel recessed: inset shade + scroll edge fade + transparency propagation — **M**
- **Visual:** panel terlihat "dipahat ke dalam" kaca: shade gelap tipis 6% teratas (dark 24→18, light 255→236); fade 14px atas/bawah muncul hanya kalau ada konten di luar tepi; `Window:SetTransparency(t)` menurunkan 60% nilainya ke panel supaya window frosted tidak berisi slab opaque.
- **Mekanisme:** `window.lua:271-276` `Create.gradient{ rotation=90, stops={{0,fx.inset},{0.06,white},{1,white}} }` (UIGradient di Frame hanya mengalikan background frame itu). Dua Frame `'ScrollFadeTop'/'ScrollFadeBottom'` parent **ContentPanel** (bukan Content — canvas math & MountRow order tak tersentuh), `Size (1,0,0,14)`, card colour, `Active false`, `ZIndex 2`, `Create.shade` 0→1 / 1→0, `Visible false`. **Aturan** (`updateFades`, pure, nil-guard → keduanya hidden): `top = cp.Y > 0`; `bottom = cp.Y + aws.Y < cs.Y.Offset` dengan `cp = CanvasPosition`, `aws = AbsoluteWindowSize`, `cs = CanvasSize`. **Visible toggle, bukan tween** — event scroll di touch bisa ratusan per detik, dua tween per event tidak diterima; ditulis hanya kalau nilainya berubah. Signal: `contentScroll:GetPropertyChangedSignal('CanvasPosition'|'CanvasSize'|'AbsoluteWindowSize')` → `Safe.mutate(updateFades)`. `SetTransparency`: `contentPanel.BackgroundTransparency = t*0.6`, fade ikut. Closure: stroke colour, keypoints dari `Theme.fx`, warna fade.
- **Risiko:** 434-435 CanvasSize math tetap; fade pakai Scale sizing sehingga `applySidebarWidth` tak perlu diubah. Test: set `CanvasPosition/CanvasSize/AbsoluteWindowSize` manual lalu **`:Fire()` signal secara eksplisit** (mock tidak auto-fire), assert Visible. Tune nilai inset per mode di Studio (setelah 1.13).

### 2.6 Sidebar: indicator stretch/travel/fade + halo + grip pill + handle re-centre — **M** (deliberate test change)
- **Visual:** bar 3×18 jadi pill hidup: melar ke 26px saat berangkat, spring ke tab baru dengan durasi sadar jarak, settle ke 18; fade (bukan blink) saat tab ter-scroll keluar; halo accent 9×26 @0.85 ikut gratis. Divider sidebar akhirnya punya grip 2×24 (border colour) yang muncul 0.3 saat hover, 0 saat drag, 0.5 permanen di touch — **dan hit target handle dipusatkan ke divider** di item yang sama supaya grip tidak tampil miring 4px selama satu fase.
- **Mekanisme:** `window.lua:317-339`: `AnchorPoint (0,0.5)`, Position y = pusat button; `Animate.chain({ {ind,'fast',{Size=(0,3,0,26)},EASING.smooth}, {ind,dur,{Position=target},EASING.pop} })` + `Animate.to(ind,'release',{Size=(0,3,0,18)}, nil, nil, Motion.fast)` (arg `delay` F3); `dur = clamp(base + |dy|/900, base, slow)`. Clip path (:329-335) → `Animate.toThen(ind,'fast',{BackgroundTransparency=1}, Visible=false)`; reappear set `Visible=true` + Transparency 0 **sinkron** sebelum tween (window_test 596-621 baca Visible). Halo = Frame `'Halo'` **child** ActiveIndicator (`Size (0,haloW,0,haloH)`, `Position (0,-3,0,-4)`, primary, `Transparency Sizes.indicator.haloAlpha`, corner 4) → ikut spring tanpa tween tambahan; reanchor instant path (:347-353) tak berubah. Grip: Frame `'SidebarGrip'` child `SidebarHandle`, centred; hover/drag tween di MouseEnter + Drag.bind callbacks (:306-313). **Re-centre handle** (ex-3.10): `Position x = sidebarW + gap/2 - hitW/2` (juga di `applySidebarWidth :302`) supaya band 44px touch mengangkangi divider, bukan menutup baris pertama content panel; drag math (:310) dikurangi offset yang sama. Recolor bar+halo+grip di closure `:629`.
- **Risiko:** tab_test 63 (`'Active'` bukan child tab button) aman — semua di Body/handle. window_test 126-156 (sidebar +40 dengan body.AbsolutePosition (0,0)) **di-recheck dan ditambah assert offset handle** (deliberate).

### 2.7 Recipes wiring: hover wash + press di semua clickable — **L**
- **Visual:** Toggle/Keybind/ColorPicker/SelectBox row, accordion Header, table row (opt-in), **tab sidebar button**, NumberBox +/-, TextBox inline buttons, Close/Minimize/ResizeHit, toast Close/Action — semua menjawab hover dengan wash `foreground @0.94` (+10 level dark / −9 light, mode-agnostic) dan press dengan wash 0.9 + UIScale 0.97 pada konten dalam. Button tetap resep fill sendiri tapi baca `Opacity.*`/`Motion.pressScale` (button_test pin 0.4/0.97/1 = default). Resizable grip dipindah ke 2.21.
- **Mekanisme:** `Recipes.hover/press/iconButton` di `toggle.lua:19-27`, `keybind.lua:37-39`, `colorpicker.lua:42-44`, `selectbox.lua:74-80`, `accordion.lua:32-41` (Header dapat `Create.corner(Radius.md)` sendiri karena `Container.ClipsDescendants` clip kotak), `numberbox.lua` stepBtn, `textbox.lua:164-210`, `window.lua:217-233` & `:865-866`, `notification.lua:199-213`. Wash frame inset = row UIPadding (12,8/0). Handler = MouseEnter/Leave/Down/Up (capability ada, tulis langsung). Setiap komponen panggil `hover.reskin()` di closure-nya. **Table row:** `Recipes.hover(row, { kind='fill' })` — Row punya UIListLayout horizontal (table.lua:20), child Frame akan jadi kolom; `fill` men-tween `Row.BackgroundTransparency` saja (theme_test 100 pin BackgroundColor3 identity row pertama, transparency bebas). **Tab button:** `Recipes.press(button, nil)` — tanpa UIScale (UIScale di button → UIListLayout reflow; wrapper Label+Icon **ditolak** karena tab_test 64 membaca `t.Button:FindFirstChild("Icon")` non-rekursif dan pin `Position.X.Offset == 4`); press = `BackgroundTransparency → Opacity.tabPress` over `press`, lepas → nilai rest (`tabHover`/1) + `Icons.tint(icon, structuralActive)`. **Close/Minimize:** `Recipes.iconButton` dengan hit sibling (`'CloseHit'/'MinimizeHit'`, `Sizes.iconButton` / `touchHit`) — glyph button tetap 18px; tests fire event di `Close` yang masih punya handler. ResizeHit sudah sibling hit (2.24 mengatur geometrinya).
- **Risiko:** 14 file, +1 Frame per row (stress: ~400 Frame statis, 0 tween saat build). accordion_test 34-38 pin Container colour tak berubah saat Header hover (wash di Header). Row `BackgroundColor3` tetap token murni (identity test). Tidak ada ripple (lihat bagian 6).

### 2.8 Disabled/locked yang kelihatan disabled — **M**
- **Visual:** control disabled render surface @`Opacity.disabled` 0.5, hover/press diabaikan, callback di-guard. LockScrim fade `Motion.fast` tapi `Visible` tetap sinkron dalam satu `Safe.mutate` (host_test 5-17).
- **Kontrak `SetEnabled(b)`** (additive, semua control): (a) hanya memblok **input pengguna** (klik, drag, wheel, fokus, keybind capture) — `apply()`/`Flag.bind` restore config **tetap** memperbarui state & visual saat disabled; (b) drag yang sedang berlangsung (Slider, ColorPicker) dipaksa selesai di `SetEnabled(false)` (panggil handler InputEnded internal, nilai terakhir dipertahankan); (c) `SetLocked` (LockScrim, milik host) dan `SetEnabled` (dim, milik control) adalah dua flag independen yang boleh tumpang tindih: scrim + dim; melepas salah satu tidak melepas yang lain; (d) `Recipes.disabled` menyimpan `rest` sehingga enable kembali ke nilai semula.
- **Tabel part yang di-dim:**

| Control | Part → prop | Guard |
|---|---|---|
| Button | Surface.BackgroundTransparency (fill/secondary), Label.TextTransparency, outline stroke Transparency | Callback tidak fire (hari ini masih) |
| Toggle | Track.BackgroundTransparency, Knob.BackgroundTransparency, Title/Description TextTransparency | click |
| Slider | Fill/Handle BackgroundTransparency, Value TextTransparency | InputBegan pada Hit |
| NumberBox | Box.BackgroundTransparency, Plus/Minus ImageTransparency, Input.TextEditable=false | hold-repeat, wheel, fokus |
| TextBox | Box.BackgroundTransparency, Input.TextEditable=false, Clear/Copy/Eye ImageTransparency | inline buttons |
| SelectBox | Field.BackgroundTransparency, Value.TextTransparency (warna tetap token `Opacity.disabled` lama → token) | Open |
| Keybind | Chip.BackgroundTransparency, chip Text | click → listening |
| ColorPicker | Swatch.BackgroundTransparency, Value TextTransparency | Open |

- **Mekanisme:** `Recipes.disabled(parts, on, theme)` + upvalue `enabled` dicek di awal setiap handler input; `host.lua:56-63` radius dari `control.Frame:FindFirstChildOfClass('UICorner')`. Dokumentasikan `SetEnabled` baru di `skills/ezui/reference/controls.md` (check-skill).
- **Risiko:** rendah; selectbox_test bandingkan disabled `Value.TextColor3` by identity → tetap assign tabel token.

### 2.9 Toggle: knob spring/stretch, stroke dissolve, glow ON, off-track retune — **M**
- **Visual:** knob geser dengan Back/Out spring (`release` 0.22) dan overshoot 1px; saat ditekan knob melar `Sizes.knob → knob*Motion.knobStretch` (20→24) ke arah tujuan, snap balik saat lepas; track ON: stroke abu-abu memudar (Transparency→1) supaya pill accent bersih, glow accent lembut di belakang track (1→`fx.glow` over `base`); track OFF di dark pakai (63,63,70) — hari ini `switchTrackOff == surface` jadi tak kelihatan; knob dapat rim 1px `background @0.7` supaya knob putih di track putih (Adaptive) tetap terbaca.
- **Mekanisme:** `toggle.lua apply()` (:53-62, tetap dalam Safe.mutate): `Animate.springTo(knob,'release',{Position, Size=knob×knob})` untuk **geometri saja**; **warna knob di tween terpisah** `Animate.to(knob,'base',{BackgroundColor3})` Quart — Back/Out pada Color3 overshoot melewati target (clamp → flash terlihat di knob putih/zinc Adaptive); `Animate.to(track,'base',{BackgroundColor3})`, `Animate.to(trackStroke,'fast',{Transparency = value and 1 or 0})`, `Animate.to(glow,'base',{ImageTransparency = value and fx.glow or 1})`; param `instant` untuk initial Flag.bind. Glow = `Effects.glow(btn, theme.Colors.primary, 'control', 1)` **sibling** di bawah Track (Track ZIndex 2), `Size (0,44+2s,0,24+2s)`, `Position (1,-44-s,0.5,-12-s)`. MouseButton1Down: `Animate.to(knob,'press',{Size=(0,knob*knobStretch,0,knob), Position = value and (0,18,0.5,-10) or (0,2,0.5,-10)})` (Position pinned toggle_test); MouseLeave/InputEnded reset. `Colors.switchTrackOff` dark → rgb(63,63,70), light → rgb(212,212,216). AccentReg: `glow.ImageColor3 = primary`, `knobStroke.Color = background`, lalu `apply(value)`.
- **Risiko:** toggle_test pin Track 44×24, Description, row 50, deferral Safe — glow sibling tak mengubah geometri Track; knob goal tepat di UDim2 pinned. Glow nil di mobile (`controlGlow='auto'`) → guard.

### 2.10 Slider: hit strip, handle grow + halo, SetValue eased — **M**
- **Visual:** area grab 24px (hari ini 6px); handle tumbuh 1.15 saat hover, 1.3 + halo accent saat drag, spring balik; `SetValue` programatik (restore config) mengalir `base` Quint bukan lompat; track pakai `Colors.background` + stroke supaya rail kosong kelihatan.
- **Mekanisme:** Frame `'Hit'` transparan `(1,0,0,sliderHit)` mengambil alih `InputBegan` (:94); UIScale child di Handle; **Halo = `Effects.glow(track, primary, 'control', 0)` parent `Track` dengan ZIndex 0** (Handle child Track, Track tanpa ClipsDescendants) — `halo.Position.X.Scale = handle.Position.X.Scale` ditulis di `apply()` yang sama tanpa konversi koordinat; `apply()` (:57-65): `if dragging then tulis langsung else Animate.to(fill/handle/halo,'base',...,EASING.smooth)`; grab/release hook di InputBegan (:94-98) / InputEnded (:104-106). Closure: halo tint, track bg.
- **Risiko:** slider_test values only; satu Slider dibangun tanpa Parent → tidak boleh baca AbsoluteSize saat build. 0 tween per InputChanged.

### 2.11 Popover: open/close motion, caret rotate, option hover, shadow + frost — **M**
- **Visual:** SelectDropdown & ColorPopover tumbuh dari field (scale `exitScale`→1 Back/Out + slide `Motion.popSlide`), keluar dengan shrink+fade cepat; caret SelectBox putar 0→180; Opt row hover 1→`Opacity.optionHover`; keduanya dapat shadow 18px + acrylic tipis (transparency 0.04, rim) supaya terlihat mengambang; Dot/HueDot colorpicker dapat stroke `background @0.35` biar tak hilang di area terang; `Overlay.placePopover` dipakai keduanya (colorpicker hari ini tak flip/clamp).
- **Mekanisme:** `selectbox.lua buildDropdown` (:263-365): `Acrylic.decorate(dropdown, theme, {transparency=0.04, edge=true, radius=Radius.md})` (stroke idempotent), `shadow = Effects.shadow(overlayRoot, {name='SelectDropdownShadow', level='popover', zIndex=Overlay.Z.catcher})` + `Effects.place(...)` **sebelum** `Overlay.mount(dropdown)`, lalu `Animate.popIn(dropdown, openUp and 'up' or 'down')` — Position akhir == computePos (selectbox_test 142 baca sinkron). `api.Close` (:377-382): `local dd, sh = dropdown, shadow; dropdown = nil; posConn:Disconnect(); untrack` sinkron, lalu `Animate.popOut(dd, function() dd:Destroy(); if sh then sh:Destroy() end end)`; `rebuild()` pass `instant=true`. Caret: `Animate.rotateTo(caret,'base', 180, EASING.smooth, DIR.Out)` (Icons.apply di closure tak sentuh Rotation). Opt hover MouseEnter/Leave di samping click handler (:353); `retintRows` tetap sumber kebenaran untuk selected. Register closure themer sementara saat open (unregister di Close). `colorpicker.lua`: Maid per-Open untuk koneksi UIS (hari ini menumpuk), `Animate.popIn/popOut`, shadow **sibling di overlay** seperti dropdown, `Acrylic.decorate(popover, theme, { transparency=0.04, edge=true, radius=Radius.md, padInset=8 })` — `padInset` wajib karena `Create.padding{all=8}` (colorpicker.lua:71), atau lewati frost di ColorPopover kalau hasil Studio tidak sepadan (tidak ada test yang membacanya).
- **Risiko:** selectbox_test: dropdown hilang sinkron setelah Close/catcher/AbsolutePosition (popOut = toThen), multi pick tak rebuild (tak disentuh), `Opt.BackgroundColor3` identity surface (hover hanya Transparency). Shadow sibling tak ikut scroll — posConn sudah menutup dropdown saat bergerak.

### 2.12 Dialog: fade+zoom+rise, shadow, scrim per-mode, footer rule, badge tinted, keyboard/gamepad, stacking — **M**
- **Visual:** card muncul GroupTransparency 1→0 + scale `enterScale`→1 + naik `Motion.dialogRise` (shadcn fade-zoom-95); keluar fade + 0.92 turun `Motion.dialogDrop` (bukan cut); shadow 32px di scrim; scrim 0.5 dark / 0.6 light; hairline di atas tombol (non-touch); IconBadge surface dicampur 15% ke IconColor supaya dialog destructive terbaca sebelum baris tombol; re-skin live saat open. **Escape / gamepad B** = tombol pertama non-destructive (Cancel) → `handle.Close()`; **Return / gamepad A** = tombol terakhir (primary) → Callback-nya; dialog kedua di atas dialog pertama tidak menumpuk scrim (0.5+0.5 = 0.75).
- **Mekanisme:** `dialog.lua:102-106` `Create('CanvasGroup', {Name='Card', GroupTransparency=1, ...})` — **tetap** `Acrylic.decorate(card, theme, {solid=true, strokeAlpha=Stroke.floating})` (Card punya UIListLayout: noise/sheen frame akan ikut ter-layout, dan UIGradient di CanvasGroup mewarnai teks) + `Effects.rim(stroke)`. `shadow = Effects.shadow(dim, {name='DialogShadow', level='dialog', zIndex=Overlay.Z.modal})` (Card 1501) + `Effects.follow(shadow, card, 'dialog', maid)` (card AutomaticSize). Open: `depth = Overlay.pushDialog()`; `Animate.to(dim,'base',{BackgroundTransparency = (modal and depth == 1) and modeVal(Opacity.dialogScrim) or 1})` (nested → scrim transparan, tanpa fade), `card.Position=(0.5,0,0.5,dialogRise)`, `us.Scale=Motion.enterScale`, `Animate.to(card,'base',{GroupTransparency=0, Position=centre}, EASING.smooth)`, `Animate.springTo(us,'enter',{Scale=1})`, shadow 1→`fx.shadow`. Close: `Overlay.popDialog()`, `Animate.to(us,'exit',{Scale=0.92},EASING.exit,DIR.In)`, `Animate.to(card,'exit',{GroupTransparency=1, Position=+dialogDrop})`, `Animate.toThen(dim,'exit',{BackgroundTransparency=1}, cleanup)`. **Keyboard:** `maid:Give(UserInputService.InputBegan:Connect(function(input, gp) if gp then return end; local k = input.KeyCode; if k == KC.Escape or k == KC.ButtonB then handle.Close() elseif k == KC.Return or k == KC.ButtonA then fire(buttons[#buttons]) end end))` dengan `KC = Enum.KeyCode`, guard `k ~= nil` (mock: KeyCode yang tidak ada = nil; F11 menambah Escape/Return/ButtonA/ButtonB supaya jalur ini diuji). Hanya dialog **teratas** (depth tertinggi) yang merespons — cek `depth == Overlay.dialogDepth()`. `'FooterRule'` Frame 1px `LayoutOrder 3` (Buttons → 4). Badge: `Theme.mix(surface, iconColor, 0.15)`. `Overlay.closeAll()` (popover) di awal `Dialog.open`. Kalau `opts.Window`: register closure lewat themer window + pass `AccentReg` ke `Button.new`. Dialog standalone (tanpa `opts.Window`) dapat UIScale `Overlay.scale()` di Card (2.22).
- **Risiko:** dialog_test 98 (0.5 sinkron, dark default, depth 1), 101 (0.92), 103 (scrim hilang sinkron via toThen), nama Header/Message/Buttons tetap; footer FillDirection/HorizontalAlignment tak berubah. Strict mock: tidak ada Text*/Image* di CanvasGroup. CanvasGroup kedua hanya saat dialog hidup — dalam budget. **UIStroke di CanvasGroup bisa ter-clip rasterisasi** (caveat yang sama dengan toast 2.13): cek Studio; fallback = stroke di Frame `'CardStroke'` child inset `(1,-2,1,-2)@(0,1,0,1)` dengan UICorner sama. Test baru: Escape → dialog hilang; Return → Callback tombol terakhir; dua dialog → scrim dialog kedua transparency 1; `Overlay.reset()` → depth 0.

### 2.13 Toast: exit asli, entrance ownership, stagger expand, morph pulse, Heartbeat stop, type tint, StackShadow — **L**
- **Visual:** toast keluar (fade + slide `Toast.exitSlide` keluar + `exitScale`) bukan hilang mid-frame; overshoot Back/Out saat masuk akhirnya kelihatan (relayout tak lagi berebut UIScale dengan pop); hover-expand membuka seperti kipas (delay `i*stagger`, cap `Toast.staggerCap`); success = icon pop + pulse 1.03; error = head-shake Rotation −2/+2/0 (token `Motion.shake.amp` dalam derajat untuk Rotation); border 35% ke warna type, icon dalam badge 20px berwarna type @0.85, Close rest muted; satu shadow di bawah toast depan; countdown Heartbeat **berhenti** saat stack kosong (hari ini jalan selamanya, bahkan setelah Overlay.reset).
- **Mekanisme:** `notification.lua show()` (:160-232): `entry.entering=true`, pre-set Position +`Toast.slide` sepanjang sumbu anchor, GroupTransparency 1, UIScale `enterScale`, hapus `Animate.pop` (:227); `relayout` (:84-135) branch entering (Position springTo Back/Out `enter`, GroupTransparency Quint `base`, scale spring) vs steady (2 tween + `delay = math.min(i, staggerCap)*Motion.stagger` lewat arg `delay` F3 saat expanded). `dismiss` (:302-312): `table.remove(order,i)` **dulu** (count() turun sinkron, relayout tak sentuh frame ini), lalu dalam Safe.mutate: `spin.Cancel()`, `Animate.to(entry.scale,'exit',{Scale=exitScale},EASING.exit,DIR.In)`, `Animate.toThen(frame,'exit',{GroupTransparency=1, Position=outward}, function() frame:Destroy(); relayout() end, EASING.exit, DIR.In)` → toastCount()==0 sinkron (test 17-18/43/111). Heartbeat: `if #order==0 and stepConn then stepConn:Disconnect(); stepConn=nil end`, reconnect lazily di show; **`Notification.Init`: `if stepConn then stepConn:Disconnect() end; stepConn = nil; expanded = false`** (hari ini cuma reset `container`; `helper.loadLib` menjalankan Init berulang → tanpa Disconnect handler lama tetap menempel ke `order` bersama dan countdown jalan 2× — notification_test 37 mengharapkan ~0.5 setelah `stepHeartbeat(0.5)`). Stroke `Create.stroke(Theme.mix(border, accent, Toast.typeTint), 1, Stroke.floating)`; badge Frame `'IconBadge'` di **TitleRow** (child absolute, aman) di belakang `'Icon'` (Title x 24→28). **StackShadow:** `Effects.shadow(container, {name='StackShadow', level='toast', zIndex=0})` — Toast CanvasGroup memakai ZIndex default 1 (notification.lua:175-181 tidak menyetel), jadi shadow **harus ZIndex 0** agar tidak menutupi toast; dipindah di relayout ke `order[1]` (AbsoluteSize nil → `Visible=false`). Action → `Button.new({Variant='secondary', AutoWidth=true, Theme=theme, AccentReg})` (maid per entry, cleanup di dismiss). **Progress: tetap child langsung `'Progress'` Toast, accent-coloured, Heartbeat-driven, TANPA track** — semua assertion (`toast:FindFirstChild('Progress')` → `Size.X.Scale` ~0.5 di L37, `BackgroundColor3.G8` success/destructive di L35/107/147) membaca child langsung; track sebagai parent akan mengembalikan track, sebagai sibling jadi baris kedua di UIListLayout, sebagai child render di atas bar. Supaya bar menempel tepi: `Create.padding({ left=padX, right=padX, top=padY, bottom = hasProgress and Toast.progressInset or padY })`; `+20` di relayout (:104) → `padY + bottom`.
- **Risiko:** nama `'ToastContainer'/'Toast'/'Progress'/'TitleRow'/'Icon'/'Title'` tetap; Progress G8 + Size ~0.5 setelah `stepHeartbeat(0.5)` tetap (Heartbeat); Icon.Rotation 360/0 tetap; deferred build tetap satu Safe.mutate. Verifikasi di Studio UIStroke di CanvasGroup render penuh (Border stroke bisa ter-clip rasterisasi; fallback inset stroke seperti 2.12). Colour math via `Theme.mix` (.R/.G/.B saja). Stress: ≤ 3 tween per dismiss.

### 2.14 Tooltip: inverted, hover-intent, anchored, fade, touch no-op — **S**
- **Visual:** chip `foreground` bg / `background` text (auto-invert), 24px, pad 8, tanpa stroke, shadow 10px, muncul setelah `Tooltip.delay` 0.35s (tak strobe saat cursor menyapu kolom), tumbuh dari bawah-tengah ke arah target, clamp viewport + flip ke bawah kalau mepet atas, fade out lalu Destroy; touch → handle no-op (bug tooltip nyangkut hilang).
- **Mekanisme:** `tooltip.lua`: MouseEnter arm `token`, `(type(task)=='table' and task.delay or immediate)(Tooltip.delay, function() if armed==token and not tip then Safe.mutate(build) end end)` — **build dibungkus Safe.mutate** (thread task.delay tak punya GUI capability di executor strict). `AnchorPoint (0.5,1)`, Position dari `AbsolutePosition/AbsoluteSize` nil-guard + `Overlay.viewport()`; UIScale `Overlay.scale()` di tip; `Animate.pop(tip,'fast')` + `Animate.to(tip,'fast',{BackgroundTransparency=0, TextTransparency=0})`; hide: `local t = tip; tip = nil; armed = nil; Animate.toThen(t,'exit',{...=1}, function() t:Destroy() end, EASING.exit, DIR.In)`. `Tooltip.Init` ambil `R.Device, R.Safe, R.Effects, R.Overlay`; `host.lua:48-50` simpan handle lewat **`Host.own(control, fn)`** (1.3) — Button/Label/Image/ProgressBar/Separator/Card tidak punya `.Maid`, tanpa fallback Destroy-wrap tooltip bocor; guard `if target.Destroying then` (mock nil).
- **Risiko:** tooltip_test: mode `immediate` (default mock) → ada sinkron setelah MouseEnter, hilang sinkron setelah MouseLeave — keduanya tetap. Test baru dengan `mock.timerMode='queued'`: MouseEnter → MouseLeave → `mock.advance(0.4)` → tidak ada tip.

### 2.15 TextBox: invalid shake, error fade, copy check — **S**
- **Visual:** SetInvalid: Box goyang `±Motion.shake.amp` px (`shake.steps` langkah × `shake.step` s, Sine), Error label fade in, row height eased `base`; SetValid fade out lalu hide; Copy → glyph `'check'` success 1.2s (token `Motion.copyRevert = 1.2`) lalu balik; Clear fade ImageTransparency (Visible tetap untuk kasus kosong); Eye toggle pop.
- **Mekanisme:** `setInvalid` (:305-312, dalam Safe.mutate): tulis `m.Visible=true` + stroke destructive **sinkron**, lalu `Animate.to(root,'base',{Size})`, `Animate.to(m,'base',{TextTransparency=0})`, dan hanya jika `Animate.isEnabled()` `Animate.chain` di `box.Position.X.Offset` yang berakhir tepat di offset semula. `setValid`: `Animate.toThen(m,'fast',{TextTransparency=1}, function() m.Visible=false end)` → Visible false sinkron (textbox_test 135/144). Copy revert: `task.delay(Motion.copyRevert, function() Safe.mutate(restore) end)` (mock immediate → glyph akhir `'copy'`; test queued: glyph `'check'` sebelum `advance`, `'copy'` sesudah).
- **Risiko:** jangan sentuh `render()`/masking. Stroke Color tetap dari `strokeColor()`.

### 2.16 NumberBox step feedback + wheel gating + Keybind chip listening — **S** (deliberate test change)
- **Visual:** NumberBox +/-: hover tint, glyph squash 0.8 → spring 1, bound dim via `Icons.tint`, "bump" Box `±Motion.bumpPx` saat press ditolak di Min/Max; **wheel hanya mengubah nilai saat pointer benar-benar di atas Box atau field sedang fokus** — hari ini (numberbox.lua:123-128) handler jalan tiap `Box.InputChanged` MouseWheel dan membajak scroll konten. Keybind: chip jadi kbd-style (`background` fill, stroke border, `AutomaticSize.X` + pad 8 + min 44, **AnchorPoint (1,0.5)** supaya tumbuh ke kiri), listening = teks `'Press a key'` muted + stroke primary pulse 0.2↔0.7 (Sine, 0.8s, repeat) sampai capture; capture = `Animate.pop(chip,'fast')` + flash stroke primary→border `base`; Escape cancel.
- **Mekanisme:** `numberbox.lua` stepBtn (:49-58) UIScale di ImageLabel dalam; hook di holdRepeat Down/Up (:87-114); `dim()` → `Icons.tint`. Wheel: upvalue `hovering` dari `box.MouseEnter/MouseLeave`; handler `if io.UserInputType == MouseWheel and (hovering or focused) then`. `keybind.lua` click (:74) `pulse = Animate.pulse(chipStroke, 0.4, {Transparency=0.7}, Sine)`; InputBegan (:75-84) `pulse.Cancel()`; `local esc = Enum.KeyCode.Escape; if esc and input.KeyCode == esc then` (guard wajib: tanpa Escape di enum, `nil == nil` true untuk InputBegan tanpa KeyCode; F11 menambah Escape supaya cabang ini benar-benar diuji). Cancel pulse via maid (wrap fungsi). Closure re-derive dari `listening`.
- **Risiko:** numberbox_test pin `.Active` flips, formatting, hold-repeat stop — tak tersentuh; **numberbox_test 52-59 (wheel) fire `box.InputChanged` langsung → tambah `box.MouseEnter:Fire()` sebelum wheel (deliberate)** + kasus baru: tanpa MouseEnter nilai tidak berubah. keybind_test tak pin nama child; tambah kasus Escape → listening false.

### 2.17 Accordion: collapse simetris, caret kalem, header wash — **S**
- **Visual:** collapse menggeser content naik 8px (mirror expand; token `Spacing.gap`) dan divider fade sebelum hide; caret putar Quint/Out (bukan Back yang jitter di 16px) + pop UIScale `popFrom`→1 saat klik; header hover wash (dari 2.7). Expand-height pop: kalau content benar-benar kosong, skip tween Size dan langsung `AutomaticSize.Y`.
- **Mekanisme:** `accordion.lua applyHeight` (:107-132): `:109` → `Animate.rotateTo(caret,'base',deg,EASING.smooth,DIR.Out)`; expand + `Animate.to(divider,'fast',{BackgroundTransparency=0})` setelah `Visible=true`; collapse + `Animate.to(content,'exit',{Position=(0,0,0,HEADER_H+gap+gap)},EASING.exit,DIR.In)` dan `Animate.toThen(divider,'fast',{BackgroundTransparency=1},...)`, `Visible=false` tetap di onComplete Size tween. **Guard kosong:** `contentHeight()` (:94-99) mengembalikan `acs.Y + Spacing.inputY` = 8 di mock dan tidak pernah 0 → tes `local acs = content.AbsoluteContentSize; if acs == nil or (acs.Y or 0) == 0 then` langsung `AutomaticSize.Y`.
- **Risiko:** accordion_test pin Rotation 0/90, Divider Visible, Size 34, AutomaticSize None/Y — semua final state sinkron.

### 2.18 FAB: chevron rotate, hover peek, Drag.bind, glow hover, shadow, tokens — **S** (deliberate test change)
- **Visual:** chevron flip 0↔180 rotasi (bukan swap sprite); simple tab menyembul `hoverPeek` lebih saat hover; glow accent lembut saat hover (1→`Opacity.glowHover`); shadow 14px di semua kind (FAB melayang di atas dunia seperti window); snap `Motion.snap` + `EASING.snap`; drag pakai `Drag.bind` (fix stray-touch cross-fire yang diperkenalkan ulang oleh drag hand-rolled `:749-772`).
- **Mekanisme:** `fabSnap` (:731-746) `Animate.rotateTo(chev,'base', dockedLeft and 0 or 180)`; MouseEnter/Leave (:790-791) + `Animate.to(fab,'hover',{Position=±hoverPeek})` (simple, non-drag) + `Animate.to(glow,'fast',{ImageTransparency=glowHover|1})`. **Glow & shadow = sibling FAB di overlay root, bukan child**: child FAB selalu render di atas fill FAB dan (ZIndex default 1, urutan sibling lebih akhir) di atas `Img`/`Chevron` — 9-slice primary @0.7 akan mencuci seluruh muka + ikon. `shadow = Effects.shadow(overlayRoot, {name='FabShadow', level='popover', zIndex=Overlay.Z.fab-2})`, `glow = Effects.glow(overlayRoot, primary, 'control', Overlay.Z.fab-1)`, keduanya `Effects.mirror`-ed di fabSnap/drag onChange/hover peek (mirror dipanggil setelah setiap tulis `fab.Position`); showFab/hideFab chain shadow/glow ImageTransparency dengan scale. `Drag.bind(fab, {onBegin, onChange (6px threshold → token `Sizes.dragThreshold = 6`), onEnd=fabSnap}, fabMaid)`. Semua di dalam `ensureFab` (SetFloatingToggle rebuild; glow/shadow lama di-Destroy via fabMaid), closure `:778-788` re-tint glow + shadow. Test 272-281 (ImageLabel pertama di FAB = Img) aman karena tidak ada ImageLabel baru di dalam FAB.
- **Risiko:** Position pin (−15 / vp.X−50+15 / (16,16) / (−60,−60)) & UIScale 1/1.06/0.92/1.06/1 tetap; square tanpa UIStroke tetap. **Deliberate:** window_test 44-46 & verify_bundle 156 (`no 'FloatingToggleShadow'`) → ganti jadi assert `'FabShadow'` ada di overlay root kalau `shadowId ~= ''`, else nil.

### 2.19 Button: token press/release, disabled, loading, outline hover, touch reset — **S**
- **Visual:** press 0.97 `press` (0.08) → release spring `release` (0.22), MouseLeave-while-pressed spring sama; outline variant stroke border→ring saat hover; `SetLoading(b)` additive (label fade, spinner 16px `Animate.spin`, click guard); hover reset di MouseButton1Up saat touch.
- **Mekanisme:** `button.lua:94-114`; SetEnabled (:128-131) dalam Safe.mutate + guard Callback; Spinner ImageLabel `'Spinner'` di Surface (Surface AutoWidth punya UIListLayout → spinner harus `LayoutOrder` di posisi label, dan label `Visible=false` saat loading agar layout tak dobel). Tidak ada lift 1px, tidak ada bloom (ditolak). Test loop memakai capture F11 (`RepeatCount == -1`, `cancelled` setelah `SetLoading(false)`).
- **Risiko:** button_test 0.97/1, ghost 1→0.4→1 tetap.

### 2.20 ProgressBar: Set mengalir, completion pulse, track stroke, anti-blob — **S**
- **Visual:** `Set` durasi sadar jarak (`base + |Δ|*(slow-base)`, Quint/Out); value mencapai 1 dari <1 → Fill flash Transparency 0.35→0 `base`; track dapat stroke border @0.5 (seperti slider); nilai kecil tak jadi gumpalan tapi **nilai 0 tetap kosong**.
- **Mekanisme:** `progressbar.lua Set` (:26): `value` update sebelum Safe.mutate (concurrency_test), tween di dalam. Anti-blob: `UISizeConstraint` `MinSize (Sizes.progress, 0)` di Fill **hanya aktif saat `value > 0`** — di 0 constraint tetap memaksa pill 8px (titik), jadi `fill.Visible = value > 0` ditulis sinkron sebelum tween (Size tween tetap ke 0 supaya `Set(0)` lalu `Set(0.5)` mengalir dari 0). Fill `BackgroundColor3` tetap token primary by identity (themer_test 35).
- **Risiko:** nihil; tambah test `Set(0)` → `Fill.Visible == false`, `Set(0.01)` → true.

### 2.21 Resizable: Drag.bind, touch handle, pane stroke, grip active, Host context — **M**
- **Visual:** drag pane tidak lagi tersambar sentuhan nyasar (handler hari ini L82-99 bereaksi ke **setiap** Touch `InputChanged`, bug yang `Drag.bind` sudah selesaikan untuk window); handle bisa diraba di HP (44px, hari ini 12); pane punya border 1px seperti Accordion/Card; grip membesar `handleGrow` saat drag + tint hover/aktif; control di dalam pane dapat Flag persistence, search dan LockAll (hari ini `Host.attach` L58-59 tidak meneruskan `config/window/registerSearchable/registerControl`).
- **Mekanisme:** `Resizable.Init(R)` capture `R.Drag, R.Device` (registrasi sudah ada di main.lua:43). Ganti L82-99 dengan `Drag.bind(handle, { onBegin = function() fr0 = {fr[k], fr[k+1]}; Animate.to(gripScale,'fast',{Scale=Motion.handleGrow}); Icons.tint(gi, structuralActive) end, onChange = function(dx, dy) local d = (horizontal and dx or dy) / span(); local nl, nr = fr0[1] + d, fr0[2] - d; if nl >= minL and nr >= minR then fr[k], fr[k+1] = nl, nr; applyLayout() end end, onEnd = function() springTo 1; tint rest end }, maid)` — dx/dy dari titik awal, bukan inkremental. Layout gap tetap `Sizes.splitGap` (12) supaya pane tidak menjauh; **Handle di touch** `Size` = `touchHit` pada sumbu silang dan `Position` digeser `-(touchHit-splitGap)/2` sehingga tetap centred di gap; `Line`/`Grip` AnchorPoint 0.5 tidak berubah (`applyLayout :43-45` membaca `handleW` dari Device). Per Pane: `Create.stroke(theme.Colors.border, 1, Stroke.control)`, recolor di closure L104-112. Grip: UIScale child + `Recipes.hover(kind='text')` untuk tint (menggantikan MouseEnter/Leave L79-80 — hover wiring resizable dimiliki item ini, bukan 2.7). `Host.attach(paneApi, { R=REG, content=pane, theme=theme, config=opts.Config, window=opts.Window, registerSearchable=opts.RegisterSearchable, accentThemer=opts.AccentThemer, registerControl=opts.RegisterControl, nextOrder=... })` — pola persis accordion.lua:162-165; `tab.lua AddResizable` meneruskan opts yang sama seperti ke Accordion.
- **Risiko:** resizable_test L8-10/17-20/22-30 tetap lulus — `Drag.bind` mendengar `InputBegan` + `UIS.InputChanged` yang sama yang di-fire test. Tambah test: pane punya UIStroke; Touch InputChanged tanpa InputBegan tidak mengubah fraksi; control di pane muncul di `registerControl`.

### 2.22 UI-scale forwarding ke overlay (toast, tooltip, dialog standalone, popover) — **S**
- **Visual:** `Window:SetUIScale(1.3)` membesarkan toast, tooltip, dropdown, color popover dan dialog standalone bersama window (hari ini `window.lua:512-516` hanya menulis `winScale` di Main → overlay tetap 1.0).
- **Mekanisme:** `SetUIScale(n)` → `Overlay.setScale(n)` + `Notif.setScale(n)` + `Effects.mirror(shadow, ...)`. `Notification.setScale(n)`: UIScale `'ContainerScale'` di **ToastContainer** (bukan overlay root), dibuat di `ensureContainer`, ditulis via Safe.mutate; `Toast.width` di relayout tetap px logis. Tooltip: UIScale di tiap tip = `Overlay.scale()` saat build; posisi anchor pakai `AbsoluteSize` target (sudah ter-scale winScale) + tinggi `Tooltip.height * scale`. SelectBox/ColorPicker: UIScale di dropdown/popover root, dan `computePos`/`placePopover` diberi `w*scale, h*scale` supaya flip/clamp benar. Dialog standalone (tanpa `opts.Window`): UIScale di Card; dialog window-scoped sudah child Main → sudah ter-scale, jangan dobel. **Tidak pernah UIScale di overlay root** — catcher `(1,0,1,0)` berhenti menutup layar.
- **Risiko:** window_test SetUIScale pin `winScale.Scale` saja; tambah test: `SetUIScale(1.3)` lalu `Notify` → `ToastContainer:FindFirstChildOfClass('UIScale').Scale == 1.3`; dropdown UIScale 1.3; overlay root tanpa UIScale.

### 2.23 Title-bar drag clamp — **S**
- **Visual:** window tidak bisa lagi diseret sepenuhnya keluar layar; minimal strip `Sizes.dragKeep` (40px) TitleBar selalu tersisa di dalam viewport, dan tepi atas tidak pernah di atas y=0 atau di bawah `vp.Y - Sizes.titleBar` (audit core/drag.lua: `AdaptToViewport` hanya clamp saat viewport berubah).
- **Mekanisme:** murni matematika di `titleBar Drag.bind onChange` (window.lua:844-847), setelah 2.1 (AnchorPoint 0.5): `local vp = viewportSize(); local cx = clamp(startX + dx, dragKeep - w/2, vp.X - dragKeep + w/2); local cy = clamp(startY + dy, h/2, vp.Y - titleBar + h/2)`; tulis Position dari `cx, cy`; `Effects.mirror` sesudahnya. Tidak menyentuh `AdaptToViewport` (early-return L901 saat `dragging` tetap; clamp hidup hanya di onChange, jadi tidak saling melawan). Mock-safe: `viewportSize()` sudah punya fallback.
- **Risiko:** window_test drag (533-549) memakai delta kecil di viewport mock → tidak terkena clamp; tambah test: drag `dx = -5000` → `Position.X.Offset` == `dragKeep - w/2`.

### 2.24 Resize grip: geometri glyph + hit target touch — **S**
- **Visual:** glyph 16px tidak lagi menimpa sudut ContentPanel (panel inset 8, glyph hari ini membentang −18..−2); di touch, ResizeHit 44px tidak lagi mencuri tap dari control di pojok kanan-bawah panel.
- **Mekanisme:** `window.lua:853-864`: grip `Size = Sizes.resizeGrip` (12), `Position = (1,-resizeGripInset,1,-resizeGripInset)` → glyph hidup di gutter sudut 12px (area yang dibulatkan radius window, di luar panel). ResizeHit: ukuran tetap `touchHit` di touch (window_test 366-373 pin `Size.X.Offset >= 44`), tetapi `AnchorPoint (0.5,0.5)` dan `Position (1,0,1,0)` — hit **dipusatkan di sudut**, jadi hanya kuadran 22×22 yang berada di dalam window (= gutter + ujung panel ≤ 14px), tiga kuadran lain di luar window tidak menutupi apa pun. Desktop: hit 22 centred juga (11px di dalam), hover/tint tetap. Prasyarat: Main tanpa `ClipsDescendants` (ClipsDescendants di window.lua ada di ContentPanel :275/:287, bukan Main) — kalau ternyata di-clip, fallback: dua Frame L-shape `'ResizeHitX'/'ResizeHitY'` sepanjang tepi kanan & bawah dengan handler yang sama.
- **Risiko:** window_test 366-373 tetap; resize onChange tidak berubah. Cek Studio: tap di pojok panel pada HP tidak lagi memulai resize.

---

## 5. Fase 3 — Delight / opsional

### 3.1 Skeleton shimmer untuk async (SelectBox LoadOptions, Image/TitleImage loading) — **M**
- **Visual:** slot kosong jadi blok surface dengan pita cahaya diagonal menyapu sampai data/gambar datang, lalu fade.
- **Mekanisme:** `Effects.skeleton(parent, {size, radius})`: Frame surface + UIGradient `{Rotation=15, Color={(0,white),(0.5,band),(1,white)}, Offset=Vector2(-1,0)}` + `Animate.loop(gradient, 1.1, {Offset=Vector2(1,0)}, Linear)`; `Stop()` cancel + fade + destroy; reduced motion → blok statis. `selectbox.lua` loading branch: child `'Loading'` (nama dipertahankan) berisi 3 baris skeleton 60/80/45%. `image.lua` & TitleImage window: **gate = `pending = (Asset.resolvable(src) and id == nil) or img.IsLoaded == false`** — selama URL masih diunduh `Image` masih `''` (window.lua:174) dan `IsLoaded` untuk `''` bernilai true, jadi gate `IsLoaded == false` saja tidak pernah menampilkan skeleton saat fetch; stop saat id ditulis **dan** (`IsLoaded ~= false`) — signal `GetPropertyChangedSignal('IsLoaded')` via `Safe.mutate`; mock `IsLoaded` nil → dianggap loaded begitu id masuk.
- **Risiko:** image_test Frame tetap ImageLabel & Image raw id (skeleton child). Satu loop per skeleton, dicancel saat stop. Test headless pakai `mock.imagesLoaded=false` (F11) lalu set `IsLoaded=true` + Fire signal → skeleton hilang.

### 3.2 FAB attention pulse opt-in — **S**
- **Visual:** `FloatingToggle.Pulse = true`: ring accent 2px 6px di luar FAB bernapas 0.55↔0.9 selama **5 siklus** lalu diam di 0.7 (hemat baterai), hover snap 0.35, cancel di Show.
- **Mekanisme:** Frame `'Halo'` child FAB (AnchorPoint 0.5, `Size (1,12,1,12)`, corner radius+6) dengan UIStroke **di child** (fab:FindFirstChildOfClass('UIStroke') tetap seperti hari ini — test 270 & verify_bundle R9); `Animate.pulse(haloStroke, 0.8, {Transparency=0.9}, Sine, 5)` di showFab; cancel di hideFab/MouseEnter/fabMaid.
- **Risiko:** default off; mock simpan repeat → test cek existence, warna, `RepeatCount == 5`.

### 3.3 ProgressBar indeterminate sweep — **S**
- `Set(nil)` / `opts.Indeterminate=true`: Fill lebar 0.3 sapu `Position.X.Scale -0.3→1` via `Animate.loop(fill, 1.1, ..., Quint)`, Track `ClipsDescendants` (di sini boleh, tepi rail tetap di dalam pill); cancel di `Set(number)`/Destroy; reduced motion → fill statis 50%. Additive `SetIndeterminate(b)` + doc header di skill reference.

### 3.4 Empty states — **S**
- Table Body `'Empty'` "No rows" (icon `inbox` — sudah ada di `core/icons.lua:153`), dropdown "No results", sidebar "No matches" saat SearchTabs kosong. `Recipes.empty`; toggle di Safe.mutate yang sudah ada (`table.lua:44-53`, `selectbox.lua:298`, `window.lua:444-455`); parent dropdown root ZIndex 1003 — bukan di List yang ber-layout. **Ikon dropdown:** `search-x` **tidak** ada di atlas dan `scripts/build-icons.mjs` hanya WARNING lalu skip nama yang tidak ada di upstream `latte-soft/lucide-roblox` → tambahkan ke `scripts/icons.manifest.txt`, jalankan `make icons`, dan **cek log**: kalau WARNING, pakai `search` (ada di :21) — jangan ship nama glyph yang resolve ke nil.

### 3.5 Row/field rhythm unification (DS-04 heights) — **M**, deliberate layout change
- `Sizes.row 34 / rowField 38 / rowDesc 50 / field 28 / fieldTall 36`: TextBox/NumberBox row 46→38, field 30→28 (SelectBox tetap 38 — selectbox_test 118 bergantung fallback 38). Setiap tepi kiri teks dan tepi atas/bawah field sejajar sepanjang halaman. Wajib changelog; cek di Studio caret 14px muat di 28px, fallback `field=30`.

### 3.6 Entrance cascade (beat 1-3 saja) — **S**
- Setelah 2.2: Title/Subtitle TextTransparency 1→0 + x `−Motion.cascade.x`→0 pada `delay = 1*stagger`; ContentPanel BackgroundTransparency 1→0 + y `+Motion.cascade.y`→0 pada `2*stagger` (arg `delay` F3 → `TweenInfo.delayTime`). Skip di touch/reduced motion. Tanpa beat 4 (cascade row tab — ditolak).

### 3.7 Scrollbar recipe pill — **S**
- `Recipes.scrollbar` diterapkan ke sidebar/content/list (table sudah di 1.3: warna border + `Scrollbar.alpha`); Top/Mid/BottomImage aset 1px flat via token `Scrollbar.imageId` (default `''` = engine default) setelah verifikasi Studio. window_test 622-628 (thickness > 0, warna border) tetap.

### 3.8 Image fade-in saat IsLoaded — **S**
- `ImageTransparency 1→0` over `base` saat `IsLoaded` flip (Safe.mutate); mock IsLoaded nil → dianggap loaded, tanpa tween; `mock.imagesLoaded=false` + Fire signal untuk menguji jalur fade. Placeholder surface bg + corner hanya untuk non-Lucide (opt `Placeholder`).

---

## 6. Yang sengaja TIDAK dilakukan

| Ide | Alasan |
|---|---|
| `Font.fromEnum(Enum.Font.BuilderSans, weight)` (DS-01/LL-P18 as written) | `fromEnum` satu argumen; weight dibuang → tetap Regular. Diganti `Font.fromName('BuilderSans', weight)`. |
| Hollow 9-slice **child** shadow (LG-P03 mekanisme) | SliceScale harus per-level, inner edge kotak meninggalkan notch tanpa shadow di sudut bulat host. Diganti sibling terisi + mirror/place. |
| Glow/shadow sebagai **child** host (FAB glow child, StackShadow ZIndex 1799) | Di `ZIndexBehavior.Sibling` child render di atas fill parent, dan sibling ber-ZIndex tinggi menutup toast. Semua layer gelap/glow = sibling dengan ZIndex < host (prinsip 3). |
| `ProgressTrack` di toast — sebagai sibling (LL-P14) **maupun** sebagai parent bar | Sibling = baris kedua di UIListLayout; parent = `toast:FindFirstChild('Progress')` mengembalikan track (notification_test 35/37/107/147 baca child langsung). Bar tetap child langsung tanpa track. |
| Wrapper UIScale untuk Label+Icon tab button | tab_test 64 baca `t.Button:FindFirstChild("Icon")` non-rekursif → wrapper memutus lookup. Press tab = dip transparency + tint. |
| Hit target Close/Minimize dengan "glyph tetap 18px di button yang sama" | ImageButton merender Image sepenuh Size; hit 26/44 = glyph 26/44. Diganti hit sibling transparan yang meneruskan handler. |
| Aturan strict mock global `Rotation → UIGradient saja` | `Rotation` valid di semua GuiObject dan ditulis spinner/caret/chevron/head-shake → verify_bundle akan throw. Diganti allowlist per-class. |
| Ripple press (MO-P08, LL-P07/P08) | `ClipsDescendants` clip kotak (bocor di sudut 8px), idiom Material bukan shadcn, dan menaruh builder Frame di `core/animate.lua`. Wash + press scale cukup. |
| Glossy primary button sheen / hover bloom / 1px hover lift (LG-P11, SL-B14, MO-P07 lift) | Skeuomorphic, imperceptible, atau bikin subpixel blur; glow child di Surface AutoWidth ikut ter-layout. |
| Hairline + field well di setiap row (LG-P09), knob shadow/glow via 9-slice (LG-P12), card sheen + separator end-fade (LG-P17) | Noise visual, +2 instance per row tanpa bukti perf mobile; ditolak 2 juri. Tangga tonal + stroke role sudah cukup. |
| Non-solid acrylic di dialog Card (LG-P14), Sheen/TypeGlint Frame di toast (LG-P15) | Host punya UIListLayout → GuiObject dekoratif ikut jadi baris. |
| Flat leading edge progress via `Track.ClipsDescendants` (LL-P17/DS-14) | Clip kotak → notch di ujung bulat. Diganti UISizeConstraint MinSize (aktif hanya saat value > 0). |
| Scroll edge fade via tween Transparency | Ratusan event scroll/detik di touch × 2 tween. Diganti Visible toggle. |
| Pivot compensation (SL-B2), theme wipe (SL-B16), presets + `SetPreset` (SL-B9), border light sweep | `restPos` bookkeeping rapuh di setiap writer Position; keypoint wipe tak pernah menutup penuh; preset = axis konfigurasi kedua yang bergantung semua closure stroke; sweep di stroke gradient belum terverifikasi dan gimmicky untuk hub. |
| Sound layer (LL-P20, SL-B10) | Off by default, butuh modul baru + public asset id terverifikasi; impact rendah. Nanti kalau diminta. |
| Value bubble slider (MO-P10), per-step text flash NumberBox (MO-P13), label tick & table row fade (MO-P19), cascade row tab (MO-P03 beat 4), halo indicator dengan spring kedua (SL-B4) | Framer-demo territory / duplikat label yang sudah ada / tween ekstra tanpa nilai. Halo = child gratis (2.6). |
| Sibling shadow popover via 2 property signal per popover (DS-12) | Popover sudah ditutup posConn saat bergerak; cukup `Effects.place` one-shot. |
| Shadow asset id sebagai default tanpa verifikasi Studio (LL-P01) | Id salah = gambar ngawur di semua surface. Default `''`. |
| GUI write dari thread `task.delay` tanpa `Safe.mutate` (tooltip intent, copy revert) | Thread tanpa capability di executor strict; semuanya dibungkus Safe.mutate di plan ini. |
| UIScale di overlay root untuk forwarding UI scale | Catcher `(1,0,1,0)` berhenti menutup layar. UIScale per floating root (2.22). |
| Tab pill sheen + hairline (LL-P07) | Tab hover cukup via tint teks; pill = surface bersih. |

---

## 7. Dampak ke test & mock

### `tests/mock_roblox.lua` (F11 — mendarat pertama)
- `TweenInfo.new` tangkap 6 arg: `{ Time, EasingStyle, EasingDirection, RepeatCount, Reverses, DelayTime }` (Play tetap sinkron). **Validasi tipe** di strict mode: `Time`/`DelayTime` wajib number (nil → error, meniru Roblox "number expected, got nil"), `EasingStyle`/`EasingDirection` wajib non-nil — guard `Quad or Quart` di plan menutup style, validasi ini menutup `delay`.
- `TweenService.Create` push ke `mock.tweens` + `mock.resetTweens()` / `mock.tweenCount()` / `mock.tweensFor(inst)`; `tw:Cancel()` → `tw.cancelled=true`, `tw:Pause()` → `tw.paused=true`. `mock.lastTween` tetap. Prasyarat 1.9/2.19/3.1/3.2.
- `Enum.EasingStyle` + Quad/Cubic/Exponential/Elastic/Bounce/Circular; `Enum.ApplyStrokeMode {Border, Contextual}`; `Enum.PlaybackState`.
- `Enum.KeyCode` + `Escape, Return, ButtonA, ButtonB` (L134) — tanpa ini 2.12/2.16 Escape/Enter diam-diam inert headless.
- `env.Rect = { new = function(x0,y0,x1,y1) return { Min={X=x0,Y=y0}, Max={X=x1,Y=y1} } end }`.
- `env.Font = { fromName = function(name, weight, style) return { Family=name, Weight=weight or Enum.FontWeight.Regular, Style=style } end }` — signature **sama dengan Roblox** supaya bug arity tak tertutup stub.
- **`TextService` stub** di `game:GetService`: `GetTextSize(text, size, font, bounds)` → `Vector2.new(#text * size * 0.55, size)` supaya jalur terukur 1.2 dieksekusi, bukan cuma fallback.
- **`mock.imagesLoaded`** (default nil = perilaku hari ini): kalau `false`, ImageLabel baru lahir dengan `IsLoaded=false`; test menulis `img.IsLoaded = true` lalu `img:GetPropertyChangedSignal('IsLoaded'):Fire()` (3.1/3.8).
- **`GetPropertyChangedSignal(prop)` di-cache per (instance, prop)** dan **tidak pernah auto-fire** — test untuk 2.5 (CanvasPosition/CanvasSize/AbsoluteWindowSize), 2.12 `Effects.follow`, 2.3 mirror, 3.1/3.8 IsLoaded harus set properti lalu `:Fire()` sendiri; setiap test baru menuliskan ini eksplisit.
- **Timer:** `mock.timerMode = 'immediate' | 'queued'` (default immediate = hari ini, L154). `queued`: `task.delay` push `{ due, fn }` dan return thread-stub; `mock.advance(dt)` menjalankan yang jatuh tempo berurutan; `task.cancel(stub)` tandai cancelled. Membuka test hover-intent tooltip (2.14) dan copy revert (2.15).
- **`Instance:Destroy()` rekursif** (L63-68 hari ini dangkal): tandai `_destroyed` dan `Parent = nil` untuk semua descendant sebelum melepas child list — tanpa ini assertion stress "heartbeatHandlers() kembali ke baseline setelah `w:Close()`" lulus/gagal karena alasan salah (Label tick memeriksa `frame.Parent == nil`; koneksi per-control yang terikat Destroying).
- Event whitelist (L73) + `SelectionGained, SelectionLost, Destroying, MouseMoved`.
- `GuiService.ReducedMotionEnabled = false` + `GetPropertyChangedSignal`; `mock.heartbeatHandlers()`.
- **Strict `validateProp` = allowlist per-class, bukan "properti → satu class"**: `Offset` → UIGradient saja; `Rotation` → GuiObject **dan** UIGradient; `Color`, `Transparency` → UIStroke **dan** UIGradient; `Thickness/ApplyStrokeMode/LineJoinMode` → UIStroke; `GroupTransparency/GroupColor3` → CanvasGroup; `Scale` → UIScale; `CanvasSize/ScrollBar*/CanvasPosition/AbsoluteWindowSize` → ScrollingFrame; `CornerRadius` → UICorner; `MinSize/MaxSize` → UISizeConstraint; `SelectionImageObject` → GuiObject. Pisah TEXTBOX_PROPS.
- Opsional: hapus `SemiBold` dari `Enum.FontWeight` supaya aturan "no 600" ditegakkan (cek mock_test dulu).

### `tests/helper.lua`
- `R.Effects = H.requireModule('core/effects')`, `R.Recipes = H.requireModule('core/recipes')` (mirror main.lua).
- `H.withReducedMotion(fn)`, `H.withQueuedTimers(fn)`, `expect.toBeCloseTo(x, eps)`.

### Assertion yang **structure-only** (kebenaran render hanya dari sesi Studio)
UIGradient child di UIStroke (2.4, 2.11, 2.12), rasterisasi CanvasGroup + stroke (2.12, 2.13), UIScale tentang AnchorPoint (2.1, 2.3 shadowScale), 9-slice ImageLabel shadow/glow (2.3, 2.9, 2.10, 2.18), sheen multiplier (1.1), highlight band (1.1). Test headless untuk item ini hanya memverifikasi keberadaan instance, nama, ZIndex relatif, token identity dan goal tween — setiap PR item tersebut wajib menyertakan screenshot Studio dark + light.

### Test baru
- `tests/effects_test.lua`: shadow nil saat `shadowId==''`; ImageLabel Slice + alpha per mode; `place/mirror` geometri (+2*spread); `follow` skip saat Absolute* nil dan sync setelah set + `:Fire()`; `rim` menambah 1 UIGradient di stroke tanpa menambah stroke; `glow` ImageColor3 == token by identity, `ZIndex` sesuai arg & nil di Mobile saat `'auto'`; `lift` goal di `mock.lastTween.Goal`; skeleton `Stop()` → `tw.cancelled` + frame hilang; semua instant di `withReducedMotion`.
- `tests/recipes_test.lua`: wash Frame `'Hover'` + transparency goal saat MouseEnter/Down/Leave; `fill` tanpa Frame baru; press UIScale 0.97/1 dan tanpa UIScale saat `scaleHost=nil`; iconButton membuat `'XHit'` sibling dan handler jalan dari button maupun hit; focus Thickness 2/1 + Color, `SelectionImageObject` ditulis via pcall; disabled alpha + restore `rest`; empty SetVisible; skip hover saat `MouseEnabled=false`.
- `tests/animate_test.lua` +: `loop` return handle & no-op saat disabled, `spin` Rotation 360 + Cancel reset 0, `useMotion` mengubah resolusi `'base'`, `info` delay → `Info.DelayTime` dan `0` saat tidak diberi; `to/toThen/chain` meneruskan delay; `applyDefault` tidak menimpa `setEnabled` eksplisit.
- `tests/overlay_test.lua` +: `placePopover` flip/clamp; `setScale/scale`; `pushDialog/popDialog/reset` depth.
- `tests/stress_test.lua` +: 0 `TweenService:Create` saat build dengan `Animations=false`; ≤ 8 tween per `Hide()/Show()`; ≤ 3 per toast dismiss; `heartbeatHandlers()` kembali ke baseline setelah `w:Close()` (**hanya setelah Destroy rekursif masuk**; angka final dari run terukur, ditulis di samping assert).

### Test yang **sengaja** diubah
| Test | Perubahan | Item |
|---|---|---|
| `theme_test.lua:59-60` | collapsed Caret == `PALETTES.light.mutedForeground` (bukan primary) | 1.4 |
| `theme_test.lua:34` | `background.R8 == 250` → compare by reference `PALETTES.light.background` | 1.13 |
| `window_test.lua:44-46`, `scripts/verify_bundle.lua:156` | dari "no `FloatingToggleShadow`" → assert `'FabShadow'` di overlay root kalau `shadowId ~= ''` | 2.18 |
| `window_test.lua:126-156` | recheck + tambah assert offset hit target sidebar handle | 2.6 |
| `numberbox_test.lua:52-59` | `box.MouseEnter:Fire()` sebelum wheel; kasus baru wheel tanpa hover → nilai tetap | 2.16 |
| `window_test.lua:121-123` | **tetap lulus**; tambah kasus dark: keypoint[1] putih, [2] == `MODE_EFFECTS.dark.sheenBottom` | 1.1 |
| `window_test.lua:533-549, 765-782` | recheck setelah AnchorPoint; tambah `AnchorPoint == (0.5,0.5)`, resize menjaga left edge, drag clamp | 2.1, 2.23 |
| `window_test.lua:366-373` | **tetap** (`Size.X.Offset >= 44`); tambah assert AnchorPoint/Position ResizeHit centred di sudut | 2.24 |
| `acrylic_test.lua` | 5 kasus lama tetap; tambah `edge=true` (Glint + gradient di stroke, tetap 1 UIStroke), `'AcrylicSheen'` ada saat non-solid, `AcrylicNoise` punya UICorner, `padInset` menggeser layer, `Acrylic.reskin` swap grain/keypoint | 1.1, 2.4, 2.11 |
| `resizable_test.lua` | 8-10/17-20/22-30 **tetap**; tambah stroke pane, stray-touch, registerControl | 2.21 |
| `dialog_test`, `tooltip_test`, `notification_test`, `selectbox_test`, `tab_test`, `button_test`, `toggle_test`, `textbox_test`, `accordion_test` | **tidak berubah** — semua exit/enter lewat `toThen`/goal sinkron; `'Progress'` tetap child langsung Toast | — |

### Dokumen yang ikut
`docs/guide/theming.md` + `skills/ezui/reference/theming.md` (token groups baru, `Animate.useMotion`/`Overlay.setScale` process-wide), `skills/ezui/reference/controls.md` (`SetEnabled`, `SetLoading`, `SetIndeterminate` headers — check-skill), `docs/api/window.md` (reduced-motion default + semantik `Animations = nil`, UI scale ke overlay, drag clamp), `docs/controls/image.md:42` (`img.SetImage`), `docs/controls/resizable.md` (touch handle, Host context), changelog untuk 1.13/3.5.

---

## 8. Perkiraan total

| Bagian | Item | Effort |
|---|---|---|
| Fondasi | 11 (F1-F11) | 8 S + 3 M (F5, F6, F11) ≈ **1 sprint kecil** |
| Fase 1 | 13 (1.1-1.13) | 9 S + 4 M |
| Fase 2 | 24 (2.1-2.24) | 12 S + 10 M + 2 L (2.7 recipes wiring, 2.13 toast) |
| Fase 3 | 8 (3.1-3.8) | 6 S + 2 M |
| **Total** | **56 item** | **35 S + 19 M + 2 L** — kira-kira 3 sprint dua-mingguan untuk 1 engineer, atau ~2 sprint dengan 2 engineer (fondasi + fase 1 sequential; fase 2 bisa paralel per komponen setelah 2.1-2.4 masuk) |

Urutan wajib: **F11 (mock) → F1-F10 → 1.1 → 1.13 (palet light) → 1.2/1.3 → sisa fase 1 (bebas; 1.9/1.11 butuh F11/F9) → 2.1 → 2.3 + 2.4 + 2.2 (satu PR, satu sesi Studio tuning dark+light untuk 1.1/2.3/2.4/2.5) → 2.23/2.24 → 2.5/2.6 → 2.7 (recipes) → 2.8-2.10/2.15-2.17/2.19-2.21 (paralel) → 2.11 → 2.12 → 2.13 (PR sendiri) → 2.14/2.18/2.22 → fase 3.** Setelah setiap fase: `make check` (strict verify_bundle + faithful Color3), jalankan `example/stress.lua` di HP setelah 2.7, 2.13 dan 2.21, dan walk checklist light mode (SetMode di demo) setelah 1.x, 2.13.