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
