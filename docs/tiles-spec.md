# TilesDE visual spec (Foundation, as implemented)

Source of truth: `shell/qml/Theme.qml` (tokens), `MetroTile.qml`, `TileGlyph.qml`. Design screen: 540x1170 logical px. No third-party names, logos, icons or fonts; glyphs are own paths.

## Theme

- Theme name `Tiles`, default (`Theme.name`, `main.cpp` env defaults `FLOWDE_THEME=Tiles`, `FLOWDE_SCHEME=dark`). Other themes stay selectable: `Theme.select("minimalist")`.
- Dark: background `#000000` (`Theme.pageBg`), text `#ffffff`, dim text `#9a9a9a`, card `#1b1b1b`.
- Light: background `#ffffff`, text `#000000`, dim `#5f5f5f`, card `#f0f0f0`.
- Tile text/glyph always `Theme.tileText` = white, both schemes.
- Tile radius 0 (`Theme.tileRadius`), `Theme.radius` 0. Flat, no shadows, no blur, no gradients.
- Accent: `Theme.accent` (read-only, derived). In Tiles it equals `Theme.userAccent` (writable colour, default `#D97757`). `Theme.setAccent(i)` picks from `Theme.accents` (12) / `Theme.accentNames`:
  terracotta `#D97757`, red `#E5484D`, pink `#E8508C`, purple `#A855D6`, indigo `#6E56CF`, blue `#3E63DD`, cyan `#0F8BD6`, teal `#12A594`, green `#30A46C`, lime `#7D9A2E`, amber `#E5A100`, steel `#7A7A7A`.
- Font: `Theme.font` (Inter). Page titles lowercase, `Font.Light`, 40 px. Tile label 15 px Normal. Big numbers/clock Light.

## Grid and tile sizes

- 4 columns, `Theme.tileCols`. Gap `Theme.tileGap` = `Theme.gap` = 6 px. Page margin `Theme.pageMargin` = 12 px.
- `Theme.tileUnit(w) = floor((w - 2*12 - 3*6) / 4)`. At w=540: 124 px.
- `Theme.tileW(size, w)` / `Theme.tileH(size, w)`:
  - small 1x1: u x u (124x124)
  - medium 2x2: 2u+6 square (254x254)
  - wide 4x2: 4u+18 x 2u+6 (514x254)
  - large 4x4: 4u+18 square (514x514)
- Tiles may be laid out in a `Flow` with spacing `Theme.gap`; a wide tile takes a full row.

## MetroTile

Props: `size`, `label`, `glyph`, `accent` (transparent = `Theme.accent`), `live`, `index` (flip stagger), `screenW` (default 540), `flat` (disable press effect), `flipEnabled` (host pause), `tiltMax` (8). Default slot = back face content. Signals `clicked(rect r)` (rect in window coords), `pressAndHold()`.

- Front: solid fill, glyph centred (small: 52% of width; medium/wide: 42% of min side; large: 36%), 3 px white stroke, slightly above centre when labelled. Label bottom-left, 10 px inset, hidden on small.
- Back (live): same fill, content from the default slot, bottom-left aligned by the content itself.
- Press: scale 0.96 and rotation about X/Y up to 8 deg toward the touch point (touched edge recedes), spring (spring 5, damping 0.4), returns on release. Off with reduceMotion (no tilt, no scale animation).
- Flip: rotation about X, 0 to 180 to 360 (front, back, front). `Theme.flipMs` 450 ms InOutQuad, period `Theme.flipPeriodMs` 6000 ms (about 2.55 s hold between each flip), initial offset `(index * 3 * 140) % 6000` ms. `Theme.flipStaggerMs` 140. Disabled when `Theme.reduceMotion`, `live` false or tile invisible.

## TileGlyph

Canvas, 48x48 design grid, centred and scaled to `size`, `stroke` constant 3 px on screen (`Theme.glyphStroke`), round joins/caps, no fill. Props `name`, `color` (default white), `size`, `stroke`.
Names: phone message mail calendar clock photos music maps notes files weather terminal store camera settings people browser wallet noxal video; UI: search star back forward plus close grid. Unknown name draws a rounded square.

## Motion tokens (for later screens)

`Theme.turnstileMs` 320, `Theme.pressMs` 140, `Theme.flipMs` 450. All 0 under `Theme.reduceMotion`.

## Gallery

`shell/qml/TileGallery.qml`: all tile sizes, live flips and every glyph. Not yet in `QML_FILES`; the integrator registers `MetroTile`, `TileGlyph`, `TileGallery` and may expose it as `screen=gallery`.

## Research (Wave 2, 2026-11-14)

Rules for this section: every number carries a source link or is marked "derived" (arithmetic from sourced numbers) or "choice" (no source found, TilesDE design decision). No proprietary asset was copied; Microsoft font names are cited as facts only. Pages marked "archived" are Microsoft Learn archive pages (Windows Phone 8, WP 8.1 era). Tool caveat: several pages were read through a summarising fetch tool, so numbers from the WinJS source (section b) should be re-checked against the file before hard-coding.

### Summary table (numbers to implement)

All design values are for the 540x1170 screen. "s" = 540/480 = 1.125, the scale from the 480-wide Windows Phone logical-pixel base.

| Area | Value | Status |
| --- | --- | --- |
| Margin and gap, classic proportions | margin 5% of width (27 px), gap 2.5% (13.5 px) | derived, matches documented sizes (a) |
| Margin and gap, tight (current default) | margin 12, gap 6, unit 124 | existing, matches wp10 reference look |
| Gap slider range | 0 to 12 px | owner requirement |
| 4 column unit | u = (w - 2m - 3g) / 4; medium 2u+g; wide and large 4u+3g | derived |
| 6 column ("show more tiles") unit | u6 = (w - 2m - 5g) / 6 = 81 at m12 g6; medium 2 cols = 168 | derived formula; 6 cols is sourced (a) |
| Turnstile in | rotateY 80 deg to 0, 300 ms, perspective 600, hinge 40 px left of the screen edge | WinJS source (b) |
| Turnstile out | rotateY 0 to -50 deg (forward) or 0 to 80 deg (backward), 128 ms | WinJS source (b) |
| Press scale (generic) | 0.975, 167 ms in and out, cubic-bezier(0.1, 0.9, 0.2, 1) | WinJS source (b) |
| Press tilt (tiles) | max 17.2 deg (0.3 rad) at the touched extreme, depress 25 px toward the viewer, return delay 200 ms then 100 ms linear | WP7 sample (b) |
| Tile flip | 450 ms, random interval, no official numbers found | choice, keep current tokens |
| Stagger step | 33 ms per element (feather), 50 ms (turnstile, WinJS), 83 ms capped at 333 ms (enterPage) | secondary / WinJS (b) |
| Fast out slow in | cubic-bezier(0, 0, 0, 1); slow out fast in cubic-bezier(1, 0, 1, 1) | Fluent docs (b) |
| Standard durations | 83 / 167 / 250 ms | Fluent docs (b) |
| Pivot title | 72 px at 480 base = 81 px at 540, light weight | sourced base (c) |
| List item title | 25.333 px base = 28.5 px at 540 | sourced base (c) |
| Subtitle and caption | 18.667 px base (14 pt) = 21 px at 540, dim grey | sourced base (c) |
| Minimum body font | 15 pt (20 px base, 22.5 px at 540) | Microsoft guideline (e) |
| Touch target | 9 mm recommended, 7 mm minimum, 2 mm between targets | Microsoft guideline (e) |
| Contrast | text 4.5:1, large text 3:1, UI and glyphs 3:1 | W3C (e) |

### (a) Start metrics

Documented tile sizes (all archived or official):
- Windows Phone 8, WXGA 768x1280 screen, flip and cycle tiles: small 159x159, medium 336x336, wide 691x336 px. Iconic: small 110, medium 202. Three sizes only (small, medium, wide). Source: [Tiles for Windows Phone 8](https://learn.microsoft.com/en-us/previous-versions/windows/apps/hh202948(v=vs.105)). WVGA 480x800 and 720p are scaled from these.
- Windows Phone 7: 173x173 medium tile at WVGA. Source: [Windows Central forum thread](https://forums.windowscentral.com/threads/windows-phone-8-tile-sizes.197629) (secondary).
- Windows Phone 8.1 effective-pixel assets: small 71x71, medium 150x150, wide 310x150, no large tile on phone. Source: [Tile and toast visual assets](https://learn.microsoft.com/it-it/previous-versions/windows/apps/hh781198(v=win.10)) and [Stack Overflow thread on 8.1 tile sizes](https://stackoverflow.com/questions/28925310/windows-phone-8-1-tile-sizes). Reading: 2x71 + 8 = 150, 4x71 + 3x8 = 308 (about 310), so the 8.1 gap is about 8 effective px (derived).
- Design grid: 12 px and 24 px page margin, spacing a multiple or subdivision of 12 px, a 25x25 px red-square debug grid inside a 24 px padding with 12 px offsets. Source: [UX/UI Guidelines for Windows Phone 8](https://learn.microsoft.com/en-us/archive/blogs/africaapps/uxui-guidelines-for-windows-phone-8). Theme resources: PhoneMargin 12, PhoneBorderThickness 3, PhoneStrokeThickness 3, touch target overhang 12. Source: [Theme resources for Windows Phone](https://learn.microsoft.com/en-us/previous-versions/windows/apps/ff769552(v=vs.105)).
- Scrollable pages keep 95 px of bottom padding so content clears the bar (same UX/UI guidelines page).
- Rules: tiles have no rounded corners or 3D elements; avoid pure #000000 or #FFFFFF tile backgrounds (do not render well in dark and light themes); the whole tile is one click target; use absolute times, not "two hours ago". Sources: UX/UI guidelines above and [Tile design guidelines](https://learn.microsoft.com/en-us/previous-versions/windows/apps/jj662929(v=vs.105)).

Derived check (important). Margin 5% and gap 2.5% of screen width reproduce the documented WXGA numbers exactly: at 768, margin 38.4, gap 19.2, small (768 - 76.8 - 57.6) / 4 = 158.4 (documented 159), medium 336 (documented 336), wide 691.2 (documented 691). So the WP8 start layout is: 4 small columns, margin 5%, gap 2.5%.

Derived sizes (4 small columns, margin 5%, gap 2.5%):

| Screen width | margin | gap | small | medium | wide |
| --- | --- | --- | --- | --- | --- |
| 480 (WVGA) | 24 | 12 | 99 | 210 | 432 |
| 540 (TilesDE design) | 27 | 13.5 | 111.4 | 236.2 | 486 |
| 720 (720p) | 36 | 18 | 148.5 | 315 | 648 |
| 768 (WXGA) | 38.4 | 19.2 | 158.4 | 336 | 691.2 |

TilesDE tight layout at 540 (margin 12, gap 6): small 124.5, medium 255, wide 516 (current code floors small to 124 and leaves 1 px slack). Margin 24, gap 12: small 114, medium 240, wide 492. Gap 0 margin 0: small 135, medium 270, wide 540.

3 vs 6 columns ("show more tiles"):
- Windows 10 Mobile picks a layout from the physical screen width: under 62 mm gives the 4-column layout, 62 mm and over gives the 6-column layout; the UI is scaled to 93% (medium) or 78% (large) on bigger screens. Source: [UserPreferenceWidth](https://learn.microsoft.com/en-us/previous-versions/windows/hardware/previsioning-framework/mt168427(v=vs.85)). WVGA and WXGA 15:9 panels support only the small (4-column) size.
- "Show more tiles" scales tiles between two preset sizes; Off gives larger tiles, fewer visible. Sources: [Thurrott](https://www.thurrott.com/mobile/windows-phone/4722/windows-10-mobile-tip-customize-start), [OnMSFT](https://onmsft.com/news/top-5-tips-setting-windows-10-mobile-start-screen).
- WP 8.1 added the extra column to non-1080p devices (earlier it was 1080p only, a "third medium column"). Sources: [PhoneArena](https://www.phonearena.com/news/Microsoft-confirms-third-Live-Tile-column-for-1080p-handsets-only_id48307), [Hanselman](https://www.hanselman.com/blog/windows-phone-81-has-my-attention-now).
- Implementer rule (choice built on the above): `Theme.tileCols` 4 or 6 counted in small units. With 6 columns small = 81 px at m12 g6, medium (2 units) 168, wide full row (6 units); keep tile positions stored in unit coordinates so switching 4 to 6 reflows. Whether the original had a 4-unit wide tile in 6-column mode was not found; do not rely on it.
- Not found: official gap and margin for WP 8.1 and 10 Mobile (only the derived 8 px effective gap above); the Windows Central thread on the 6-tile width option gives no numbers.

### (b) Motion

Sources of numbers: the WinJS animation library (MIT licence, Copyright Microsoft Corporation; it implements the Windows turnstile, pointer-down and page-enter curves) at [Animations.js](https://raw.githubusercontent.com/winjs/winjs/master/src/js/WinJS/Animations.js), the WP7 tilt sample, and the Fluent motion page. Windows Phone Toolkit source (TurnstileTransition.cs, TiltEffect.cs) could not be fetched (404); an Ms-PL project, read-only reference at best.

Turnstile (page transition) from WinJS:

| Step | Transform | Duration | Easing |
| --- | --- | --- | --- |
| Forward in | perspective 600 px, rotateY 80 deg to 0 | 300 ms | cubic-bezier(0.01, 0.975, 0.4775, 0.9775) |
| Forward out | rotateY 0 to -50 deg | 128 ms | cubic-bezier(0.4925, 0.01, 0.7675, -0.01) |
| Backward in | rotateY -50 deg to 0 | 300 ms | same as forward in |
| Backward out | rotateY 0 to 80 deg | 128 ms | same as forward out |

- Opacity: in 0 to 1 over 300 ms; out 1 to 0 over 128 ms.
- Transform origin: the hinge is 40 px left of the screen's left edge (LTR), vertical centre of the screen. Stagger between elements 50 ms per element, capped at 1000 ms (corroborated by the [orca pull request](https://github.com/corepunch/orca/pull/399): 600 pt perspective, hinge 40 pt left, 80 / -50 deg, 300 ms; feather stagger 33 ms per element from WP 8.1).
- Qt mapping: `Easing.BezierSpline` with `easing.bezierCurve: [0.01, 0.975, 0.4775, 0.9775, 1, 1]`; for perspective use a `Matrix4x4` transform (Rotation alone is orthographic, the known defect in HANDOFF). Fallback if the spline looks wrong: `Easing.OutQuint` 300 ms in, `Easing.InCubic` 130 ms out. Current `Theme.turnstileMs` 320 is close; split into in 300 and out 130.

Press and tilt:
- WinJS pointer-down: scale 0.975, 167 ms, cubic-bezier(0.1, 0.9, 0.2, 1), release uses the same time and curve, no rotation.
- WP7 tilt sample (MaxAngle 0.3 rad = 17.2 deg, MaxDepression 25 px, TiltReturnAnimationDelay 200 ms, TiltReturnAnimationDuration 100 ms, linear return by default): [sample copy](https://gist.github.com/alfeg/4110340), original posts [Tilt effect for Windows Phone controls](https://learn.microsoft.com/en-nz/archive/blogs/ptorr/tilt-effect-for-windows-phone-controls) and [Updated tilt effect](https://learn.microsoft.com/en-us/archive/blogs/ptorr/updated-tilt-effect). Do not copy the code (Microsoft sample licence); the numbers and ideas are the reference.
- Direction: the angle follows the touch point: xAngle = asin((y - h/2) / (h/2)), yAngle = acos((x - w/2) / (w/2)) in degrees, so a touch near an edge pushes that edge away. The updated version also angles the item toward the screen centre via a shared camera, and the effect does not run while a list scrolls.
- Tilt is for buttons and list items; guidelines forbid colour or border changes as touch feedback ([UX/UI guidelines](https://learn.microsoft.com/en-us/archive/blogs/africaapps/uxui-guidelines-for-windows-phone-8)). Applies to Settings rows, All Apps rows and Action Centre tiles too.
- TilesDE implementation: current `tiltMax` 8 deg with scale 0.96. Raise to 12 deg as the default (sample maximum is 17 deg at the extreme edge, a finger rarely reaches it), keep scale 0.96 to 0.975, press-in 100 to 140 ms, and hold the pressed pose for at least 100 to 200 ms after release so a quick tap is still visible. Disable while the parent Flickable is moving, and under `Theme.reduceMotion`.

Live tile flip: Microsoft says only that the tile flips at a random interval ([Flip tile guidelines](https://learn.microsoft.com/en-us/previous-versions/windows/apps/jj662925(v=vs.105))), so put important info on the front. No period or duration was found in any official source (third-party control libraries use 5 to 10 s intervals, not authoritative). Choice: keep `flipMs` 450, `flipPeriodMs` 6000; add a per-tile random jitter of 0 to 1500 ms to the next flip instead of the fixed `(index * 3 * 140) % 6000` offset, and flip only a few tiles at a time (for example at most 3 simultaneous). Flip half-turn (0 to 90 degrees) then swap the face, then 90 to 180, equals the current 0 to 180 full flip.

Easing and durations for everything else (Fluent, [Timing and easing](https://learn.microsoft.com/en-us/windows/apps/design/motion/timing-and-easing)): 83, 167 and 250 ms standard durations; entering objects use fast out slow in cubic-bezier(0, 0, 0, 1); exiting objects use slow out fast in cubic-bezier(1, 0, 1, 1). Use these as `Theme.durFaster` 83, `Theme.durFast` 167, `Theme.durNormal` 250 and the two curves for lists, shade, switcher, toggles.

List and page entrance (WinJS): items enter from 28 px below (top offset 28 px) to rest over 550 ms (content) or 1000 ms (page) on cubic-bezier(0.1, 0.9, 0.2, 1), opacity 0 to 1 over 170 ms; page-enter stagger 83 ms per item capped at 333 ms. For TilesDE lists use: 28 px rise, 400 to 550 ms, 40 to 50 ms stagger per row (feather is 33 ms) capped at 8 rows, opacity 170 ms.

Pivot and panorama:
- Pivot: gestures are horizontal pan and flick; pages are cyclical (swiping past the last wraps to the first); at most four pages, header text one or two words so the next header peeks as a cue; the header has fixed height; no sliders, toggles, maps or horizontally scrolling controls inside a pivot (they would steal the swipe). Source: [Pivot control design guidelines](https://learn.microsoft.com/en-us/previous-versions/windows/apps/hh202919(v=vs.105)). Note the owner's Settings references put toggles in sub-pages, not in the pivot page itself, which is consistent.
- Panorama parallax: title moves slowly relative to the top content layer, and slower than the background art; background and title move at different speeds than content. Source: [UX/UI guidelines, panorama section](https://learn.microsoft.com/en-us/archive/blogs/africaapps/uxui-guidelines-for-windows-phone-8) and [Panorama guidelines](https://learn.microsoft.com/en-us/previous-versions/windows/apps/hh202912(v=vs.105)). No ratios published. Choice: content 1.0, background 0.5, title 0.3 of the content scroll distance.
- Choice for the Settings pivot header: header strip follows the finger at 1:1 times (headerStep / pageWidth) so the next title ends where the current one started; the next title shows dimmed at the right edge with about 100 to 130 px visible at 540; settle with 250 ms fast out slow in, velocity aware (a flick above about 0.4 px per ms commits the page). Title colour dims to 40% for inactive.
- Toggle: no source for the original timing. Choice: knob block slides in 167 ms on cubic-bezier(0, 0, 0, 1); label "On" or "Off" swaps at the mid-point; no colour change on press except the knob.

### (c) Typography

Original sizes (Windows Phone 8 theme resources, [source](https://learn.microsoft.com/en-us/previous-versions/windows/apps/ff769552(v=vs.105))). These are in 480-wide logical px; pt = px x 3/4.

| Style | px (480 base) | pt | At 540 (x1.125) | Weight and use |
| --- | --- | --- | --- | --- |
| Huge | 186.667 | 140 | 210 | Light, big clock or number |
| ExtraExtraLarge (Title1) | 72 | 54 | 81 | SemiLight; the huge pivot title |
| ExtraLarge | 42.667 | 32 | 48 | SemiLight |
| Large (Title2, group header) | 32 | 24 | 36 | SemiLight; group header in dim colour |
| MediumLarge | 25.333 | 19 | 28.5 | list item titles |
| Medium (Title3) | 22.667 | 17 | 25.5 | SemiLight; sub-titles |
| Normal | 20 | 15 | 22.5 | body, minimum body size |
| Small | 18.667 | 14 | 21 | dim grey subtitle and caption |

- The owner brief says about 64 pt for the pivot title; the sourced style is 72 px (54 pt), which on the 540 design screen is 81 px. Use 80 px, allow `fontSizeMode: Text.Fit` down to about 56 px for long titles. The brief's other numbers match: caption 14 pt = 18.667 px base (21 px at 540, uppercase), subtitle 15 pt grey, list title 25.333 px base (28 px at 540). The current 40 px page title in this spec is too small for the pivot pages; keep 40 px only for sub-page titles.
- Case: titles lowercase, section titles (app caption) uppercase ([UX/UI guidelines](https://learn.microsoft.com/en-us/archive/blogs/africaapps/uxui-guidelines-for-windows-phone-8)). Minimum font size 15 pt.
- Family used originally: Segoe WP / Light / SemiLight / SemiBold (Microsoft proprietary, never bundle or name in UI).

Open-licence font candidates:
- Inter (current). SIL OFL 1.1, "Copyright (c) 2016 The Inter Project Authors", no Reserved Font Name in the licence text ([LICENSE.txt](https://raw.githubusercontent.com/rsms/inter/master/LICENSE.txt)). Has a Light (300) weight (not re-verified in this pass). Wider and larger x-height than the humanist original; at titles use `font.weight: Font.Light` and `font.letterSpacing` about -1% to -2% (choice) so the 81 px title does not look loose.
- Selawik. CORRECTION to the brief: Selawik is licensed under SIL OFL 1.1, not MIT: "Copyright 2015, Microsoft Corporation, with Reserved Font Name Selawik", and "Selawik is a trademark of Microsoft Corporation" ([LICENSE.txt](https://raw.githubusercontent.com/microsoft/Selawik/master/LICENSE.txt)); the README calls it an open-source replacement for Segoe UI with missing kerning ([README](https://github.com/microsoft/Selawik)). OFL permits bundling with the licence text, but the owner rule is no Microsoft names or font files, so do not bundle it by default. It could be an opt-in user-installed font (the shell just reads `Theme.font`). Not verified: exact list of weights.
- Others (choice, licences not verified in this pass, check each font's licence file before bundling): Open Sans Light, Noto Sans Light, Source Sans 3 Light. These are humanist sans families closer to the original proportions than Inter; Open Sans Light is the closest widely used match.
- Implementation: `Theme.font` stays a single family property; add `Theme.fontWeightTitle` (default Light) and `Theme.titleCase` ("lower" default or "upper"); `Theme.fontScale` multiplies the table above.

### (d) Open-source reference projects (read only, check licences, copy nothing blindly)

| Project | What | Licence (as stated by the repo) | Use |
| --- | --- | --- | --- |
| [Retiled](https://github.com/DrewNaylor/Retiled) | QML Start screen, search, nav bar, Action Centre, status bar for Linux phones in Windows Phone 8.x style | Mixed: own files Apache-2.0 (relicensing to GPLv3+ announced), RetiledStyles mostly LGPLv3, RetiledCompositor GPLv3, fonts Inter and wp-metro under OFL 1.1 | Closest in spirit. Read structure and behaviour only; because of the GPL plan do not copy files; do not use its wp-metro font (provenance unknown, may imitate Microsoft glyphs). Its README disclaims any link to Microsoft |
| [WinJS](https://github.com/winjs/winjs) | JS library with turnstile, pointer, enter-page animations | MIT, Copyright Microsoft Corporation | Source of the motion numbers above |
| [Metro UI CSS](https://github.com/olton/Metro-UI-CSS) | CSS and JS tile and component framework | MIT | Tile CSS sizes and flip effects as ideas; check its icon sets separately |
| [MahApps.Metro](https://github.com/MahApps/MahApps.Metro) | WPF themes and controls (hamburger menu, dialogs) | MIT, .NET Foundation | Theming model (accent plus base theme) as reference for presets |
| [FluentUI for QML](https://github.com/zhuzichu520/FluentUI) | QML component library in Fluent style | MIT | Not Metro; useful for QML control structure |
| Qt Quick Controls 2 Universal style | Built into Qt, a Microsoft-guideline-based style (accent, light, dark) | Qt licences (LGPLv3, GPLv3, commercial) | Accent and theme property model (`Universal.accent`, `Universal.theme`) as reference |

### (e) Accessibility and ergonomics

- Touch targets: 9 mm recommended, 7 mm minimum (only for rare or wide controls), at least 2 mm between targets, the visible element 60 to 100% of the target, minimum font 15 pt, provide feedback on touch. Sources: [UX/UI guidelines, touch targets](https://learn.microsoft.com/en-us/archive/blogs/africaapps/uxui-guidelines-for-windows-phone-8) and [Windows blog on finger-friendly targets](https://blogs.windows.com/windowsdeveloper/2010/12/07/4-of-10-make-sure-your-finger-can-hit-the-target-and-text-is-legible/). The current Windows guideline is 7.5 mm, about 40 px at 135 PPI ([Targeting](https://learn.microsoft.com/en-us/windows/apps/develop/input/guidelines-for-targeting)).
- WCAG 2.2: pointer targets at least 24x24 CSS px (AA, [2.5.8](https://www.disabilityworld.org/toolkit/standards/wcag/2-5-8-target-size-minimum/)), 44x44 (AAA, [2.5.5](https://www.disabilityworld.org/toolkit/standards/wcag/2-5-5-target-size-enhanced/)).
- Contrast ([W3C understanding 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)): normal text 4.5:1; large text 3:1, where large is at least 18 pt (24 px) or 14 pt bold (about 18.7 px bold); graphics and UI parts 3:1 (SC 1.4.11, value from the W3C criterion, not re-fetched).
- mm to px at the 540 design width: with a screen about 67 mm wide that is about 8.1 px per mm, so 9 mm is about 73 px, 7 mm about 57 px, 2 mm about 16 px. Do not hard-code: use `Screen.pixelDensity` (px per mm) times the design scale, e.g. `Theme.mm(n)`. Reference rows of 64 to 72 px are about 8 to 9 mm, fine. Small glyph buttons (status, nav, AlphaJump, tile edit buttons) need a hit area of at least 57 px even if the glyph is 30 px. The 6 px tile gap is under 2 mm but each tile is a very large target; the 2 mm rule matters for small controls.
- Computed contrast (this pass, WCAG relative luminance) for the accents and Glaze tile colours:

| Colour | White text | Black text | Note |
| --- | --- | --- | --- |
| terracotta #D97757 | 3.12 | 6.73 | white fails 4.5 for 15 px labels |
| red #E5484D | 3.91 | 5.37 | |
| pink #E8508C | 3.53 | 5.96 | |
| purple #A855D6 | 4.25 | 4.94 | |
| indigo #6E56CF | 5.39 | 3.90 | white passes |
| blue #3E63DD | 5.21 | 4.03 | white passes |
| cyan #0F8BD6 | 3.69 | 5.68 | |
| teal #12A594 | 3.07 | 6.84 | white barely passes 3:1 |
| green #30A46C | 3.16 | 6.65 | |
| lime #7D9A2E | 3.21 | 6.53 | |
| amber #E5A100 | 2.23 | 9.43 | white fails even 3:1, use dark text |
| steel #7A7A7A | 4.29 | 4.89 | |
| ink #22211f | 16.09 | 1.31 | |
| paper #d8d6cf | 1.45 | 14.44 | white fails, needs ink text |

  Consequences: (1) tile glyphs (3 px strokes, SC 1.4.11 needs 3:1) pass in white on all accents except amber and paper; (2) white 15 px labels on most accents fail 4.5:1 (they need large text: at least 24 px, or 18.7 px bold). Fix: tile labels Medium weight at 18 px and up at 540, or choose the label colour automatically as the higher contrast of white and ink; implement `Theme.onColor(c)` returning white unless the white contrast is under 3:1 (amber, paper, any light user colour), then ink or black. This relaxes "tile text always white" only for those colours. (3) Dim text #9a9a9a on black is 7.46:1 and on card #1b1b1b 6.12:1, light dim #5f5f5f on white 6.39:1: all pass. (4) Over wallpaper (picture tiles, translucent AMOLED tiles) add a semi-transparent black layer behind text (Microsoft's own advice for contrast over images, UX/UI guidelines section 13).

### Not found (do not treat as facts)

Official live tile flip duration and period; official toggle switch timing; pivot and panorama parallax ratios; official gap and margin for WP 8.1 and 10 Mobile (only the derived 8 px effective gap and the exact WP8 5% / 2.5% proportions); whether a wide tile spans 4 of 6 columns in the six-column layout; exact available weights of Selawik and the licences of Open Sans, Noto Sans and Source Sans 3 in this pass; Windows Phone Toolkit source (fetch returned 404).

## Personalisation

Engine: C++ QML singleton `Personalise` (`shell/src/Personalise.{h,cpp}`, module `FlowShell`), consumed by `shell/qml/Theme.qml`. Every setter validates and clamps, emits its NOTIFY signal (live apply) and restarts a 600 ms debounce timer that writes the file (atomic, `QSaveFile`). Also flushed on quit.

### File

Path: `$TILESDE_CONFIG`, else `$XDG_CONFIG_HOME/tilesde/theme.json`, else `~/.config/tilesde/theme.json`. Missing file: defaults, `Personalise.status == "missing"`. Corrupt file (not a JSON object): defaults, status `"corrupt"`, the bad file is copied to `theme.json.bad`, the next save overwrites `theme.json`. Unknown keys and invalid values in a valid file are ignored per key.

| key | type | range / values | default |
|---|---|---|---|
| preset | string | `glaze` `classic` `mono` `paper` or a custom preset name | `glaze` |
| scheme | string | `dark` `amoled` (pure `#000000` page) `light` | `dark` |
| accent | colour | `#rrggbb` (or `#aarrggbb`) | `#d97757` |
| tileOpacity | real | 0.2 to 1 | 1 |
| tileRadius | int px | 0 to 40 | 0 |
| gap | int px | 0 to 12 | 6 |
| columns | int | 3 or 4 | 4 |
| tilesOverWallpaper | bool | | false |
| grain | real | 0 to 1 (paper-grain strength) | 0.6 (glaze) |
| labels | bool | tile labels | true |
| badges | bool | live badges | true |
| flipSpeed | int | 0 off, 1 normal, 2 fast | 1 |
| fontWeight | int | 100 to 900 in hundreds | 300 |
| titleCase | string | `lower` `upper` | `lower` |
| motion | string | `off` `low` `normal` `high` | `normal` |
| groups | array | `[{name, collapsed}]`, names unique, max 32, 40 chars | Productivity, Explore |
| tileColors | object | `{tileId: colour}` per-tile override | `{}` |
| startPhoto | string | file path or url, empty = none | `""` |
| customPresets | object | `{name: definition}` | `{}` |

Applying a preset (`applyPreset`, key `preset`) copies its defaults for scheme, accent, tileOpacity, tileRadius, gap, columns, grain, labels, badges, fontWeight, titleCase, tilesOverWallpaper into the live settings; later edits then override it. `flipSpeed`, `motion`, `groups`, `tileColors`, `startPhoto` are never touched by presets.

### Built-in presets

| name | scheme | accent | tile palette | dark bg | card |
|---|---|---|---|---|---|
| glaze | dark | `#d97757` | terracotta `#d97757`, ink `#22211f`, paper `#d8d6cf` | `#363532` dark paper, grain 0.6 | `#2a2927` |
| classic | dark | `#1ba1e2` | yellow `#e8a900`, blue `#1ba1e2`, green `#339933`, red `#a20025` | `#000000` | `#1b1b1b` |
| mono | dark | `#8a8a8a` | greys `#3a3a3a` `#5a5a5a` `#8a8a8a` `#b5b5b5` | `#000000` | `#1b1b1b` |
| paper | light | `#d97757` | as glaze | light bg `#efeee8` | `#e2e0d8` |

Light scheme background is the preset `bgLight` (white for glaze, classic, mono). Amoled forces `#000000` and card `#121212`. Preset definition keys: `label palette accent scheme bgDark bgLight cardDark cardLight textDark dimDark tileOpacity tileRadius gap columns grain labels badges fontWeight titleCase tilesOverWallpaper base custom`. A custom preset is a snapshot of the current look (`savePreset(name)`); the preset's own accent swatch inside `palette` is replaced by the live accent.

### QML API

`Personalise` properties (all read/write except where noted, each with `<name>Changed`): `preset scheme accent tileOpacity tileRadius gap columns tilesOverWallpaper grain labels badges flipSpeed fontWeight titleCase motion groups tileColors startPhoto customPresets`. Read-only: `presetNames` (built-in then custom), `builtinPresetNames`, `currentPreset` (definition map), `accentColours` (12), `accentNames` (12), `path`, `status` (`ok|missing|corrupt`), `dirty`. Signal `changed(key)` fires for every change.

Methods: `set(key, value)`, `get(key|"all")`, `command(key, valueString)`, `toJson()`, `toMap()`, `applyPreset(name)`, `presetData(name)`, `savePreset(name)`, `deletePreset(name)`, `reset()`, `reload()`, `saveNow()`, `setTileColor(id, colour)` (empty clears), `clearTileColors()`, `addGroup(name)`, `removeGroup(i)`, `renameGroup(i, name)`, `setGroupCollapsed(i, b)`, `toggleGroup(i)`, `moveGroup(from, to)`.

`Theme` (Tiles theme): `scheme amoled light preset presetDef presetAccent tilesC pageBg tilePalette tileOpacity tilesOverWallpaper grain showLabels showBadges startPhoto groups tileGap gap tileCols tileRadius fontLight fontWeightTitle titleCase motionScale tiltScale flipSpeed flipEnabled flipMs flipPeriodMs pressMs turnstileMs systemReduceMotion`; functions `tileColor(id, defaultIndex)`, `hasTileColor(id)`, `onColor(fill)` (white unless white contrast under 3:1), `luminance(c)`, `contrast(a, b)`, `tileBackOf(fill)`, `presetInfo(name)` (swatches `{bg, card, text, accent, palette}`), `title(s)`, `setDark(b)`, `setAccent(i)`, `rowWidth(w)`, `tileUnit(w)`, `tileW/tileH(size, w)`. With 3 columns, wide and large tiles span the 3-column row; medium stays 2x2.
Legacy writes still work: `Theme.dark = x`, `Theme.reduceMotion = x`, `Theme.userAccent = c` are forwarded to the store. `Theme.reduceMotion` is true when the system flag or `motion == "off"`.

### Control socket

Wire in `Main.qml` `onCommand(k, v)`: `Personalise.command(k, v)` for any key not handled elsewhere. Keys (value is a string):
`preset <name>`, `scheme dark|amoled|light`, `amoled on|off`, `accent <#rrggbb | name | index 0..11>`, `opacity <0.2..1>`, `radius <0..40>`, `gap <0..12>`, `columns 3|4`, `wallpaper on|off` (tilesOverWallpaper), `grain <0..1>`, `labels on|off`, `badges on|off`, `flip <0..2>`, `weight <100..900>`, `case lower|upper`, `motion off|low|normal|high`, `photo <path>`, `groups <json array>` or `addGroup <name>`, `removeGroup <i>`, `toggleGroup <i>`, `tileColor <id>=<colour>` (no `=colour` clears), `clearTileColors`, `tileColors <json object>`, `customPresets <json object>`, `savePreset <name>`, `loadPreset <name>`, `deletePreset <name>`, `reset`, `reload`, `flush` (write now). Schema key names work too (`tileOpacity`, `tileRadius`, `fontWeight`...). `command` returns false on an invalid key or value (nothing changes). Env at start: `FLOWDE_PRESET`, `FLOWDE_SCHEME=dark|amoled|light`, `TILESDE_CONFIG`.

Self-check: `shell/tools/check-config.sh` (needs a running shell with `Main.qml` wired and `TILESDE_CONFIG` pointing at a scratch file).

### Default tile layout (`shell/qml/TilePresets.js`)

`.pragma library`, data only. `import "TilePresets.js" as TilePresets`. Tile fields: `id label glyph size group color live picture badge` (`group` "" = top block above the first header; `color` = index into `Theme.tilePalette`, wrapped; `picture` = photo tile using `Personalise.startPhoto`; `badge` = count, 0 none). Functions: `defaultTiles()`, `previewTiles()` (10 tiles for the Settings preview), `find(id)`, `colorIndex(id)`, `tilesInGroup(list, name)`, `defaultGroups()`. Fill of a tile: `Theme.tileColor(t.id, t.color)`, ink `Theme.onColor(fill)`.

## Controls (Wave 2)

Files in `shell/qml/`, all colours from Theme (dark, amoled, light), fonts `Theme.font`/`Theme.fontLight`, animation off under `Theme.reduceMotion`. Not yet in `QML_FILES` (integrator registers).

- `Pivot`: props `caption`, `currentIndex`, `titleSize` 80, `captionSize` 21, `headerHeight`, `titles`; `goTo(i)`; signal `pageChanged(i)`. Children are `PivotPage`. Caption uppercase, active title lowercase light, next title at 38% opacity at the right edge. Header slides by title spacing (28 px gap), not page width: parallax. Swipe snaps over `Theme.turnstileMs`; tap a title to jump.
- `PivotPage`: vertical Flickable, `title`, `margin` 18, children go in a column.
- `MetroToggle`: `label`, `checked`, `onText`/`offText`, signal `toggled(bool)`. 96x40 outlined 2px, 34x30 sliding block (accent when on), 30 px value label above.
- `MetroDropdown`: `label`, `model` (strings), `currentIndex`, `currentText`, signal `activated(i)`. 2px outlined 56 px box; opens full-width bottom sheet, rows 64 px, current in accent.
- `MetroButton`: `text`, `accentFill`, `enabled2`, `clicked()`. 2px outline, pressed fills with text colour.
- `MetroTextField`: `label`, `text`, `placeholder`, `echoMode`, `validator`, `accepted()`, `edited()`. 2px outline, accent border on focus.
- `MetroListRow`: `title` (24 light), `subtitle` (18 dim), `glyph` (TileGlyph name in 56 px accent square), `iconColor`, `usage` (0..1, -1 hides), `usageColor`, `trailing`, `clicked()`, `pressAndHold()`. Height 68, 80 with bar, no dividers; host column gives the 18 px margin.
- `MetroSlider`: `label`, `value`, `from`, `to`, `stepSize`, `suffix`, `decimals`, `moved(v)`. 4 px track, accent fill, 16x36 square thumb.
- `MetroColorGrid`: `value`, `columns` 6, `colors` (default `Theme.accents`, 12), `showHex`, `picked(c)`. Hex field accepts `#rrggbb`.
- `MetroSectionHeader`: `text`, `accent`. 28 px light dim.
- `AppBar`: `items [{glyph,label}]`, `menuItems`, `expanded`, `activated(i)`, `menuActivated(i)`. 72 px, round 48 px outlined buttons, `...` expands labels and menu rows.
- `ControlsGallery`: Pivot with inputs, lists, colours pages plus AppBar. Suggested socket: `screen=controls`.

Unverified: not compiled or linted (no Qt toolchain run in this task).
