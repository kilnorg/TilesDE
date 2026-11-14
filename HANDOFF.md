# HANDOFF.md: state of the Kiln / Glaze / TilesDE work (written 2026-11-14)

For Codex or any other agent continuing while Claude is away. Read this fully, then pick a task from "Work queue". Be honest in reports: say what you built, ran and did not test.

## Ground rules (from the owner)

1. Commit author must be `Mandrusia <143601569+Mandrusian@users.noreply.github.com>`. No `Co-Authored-By` lines and no Claude/Anthropic/AI trailers or mentions in commits, PR text or contributor lists. The owner explicitly removed Claude from every contributors list.
2. Never force-push. Do not push to GitHub unless the task below says push is allowed. Pushes already authorised by the owner: `glaze` to `Mandrusian/glaze` branch `main`, `stage-kiln` to `achillesorg/kiln-gnu-linux` branch `beta`. TilesDE has no remote yet: commit locally only.
3. No credentials, tokens or passwords in files or chat. Never run live-build or ISO builds on the Mac host; use the Debian VM or a Debian 13 container.
4. Design references (Windows 10 taskbar/Start screenshots, Windows Phone tiles screenshot) are private. Copy the layout and feel, but use no Microsoft names, logos, icons or font files. Own colours. `glaze/docs/design-ref/` is gitignored and must never be committed.
5. Light, honest reporting. Do not claim something boots or works unless you ran it.

## Machines and access

- Mac host, project root `~/fedeos` (this file lives there).
- aarch64 Debian 13 VM in QEMU: start with `cd ~/fedeos && ./run.sh` (run it with nohup in the background; macOS has no `setsid` or `timeout`). SSH wrapper: `~/fedeos/vm "<command>"`, or `ssh -i ~/fedeos/fedeos_key -p 2222 fede@localhost`. QMP socket: `~/fedeos/qmp.sock`.
- In non-login ssh shells the system rustc is 1.85, too old. Always `export PATH=$HOME/.cargo/bin:$PATH` (rustc 1.100 via rustup) before cargo.
- Heavy builds in the VM must hold the lock: `flock /tmp/heavy-build.lock <cmd>`, and use `-j2`.
- The VM freezes when Mac swap fills. If ssh gives "Connection timed out during banner exchange": kill QEMU, `./run.sh` again, `fstrim -av` inside the VM. VM disk has about 8 GB free.
- Glaze compositor soak runs on tty2; the user's tty1 session runs Sway, not the Glaze compositor (see below).

## Repos and branches

| Path | What | Remote / branch |
|---|---|---|
| `~/fedeos/glaze` | Glaze desktop (Rust: compositor, shell, settings, session) | `Mandrusian/glaze`, `main`. Has uncommitted work (44+ files from earlier). |
| `~/fedeos/stage-kiln` | Public-ish snapshot: `glaze/`, `kiln-apps/`, `brand/`, `build/`, `AI.md` | `achillesorg/kiln-gnu-linux`, `beta` (private). Last pushed commit 29e5fbe (x86_64 pipeline). |
| `~/fedeos/kiln-apps` | Themed app forks + Kiln Store (local commits, not mirrored) | local |
| `~/fedeos/flowde` and worktrees `flowde-mobile`, `flowde-pages`, `flowde-site` | Old FlowDE project | `achillesorg/FlowDE` |
| `~/fedeos/tilesde` | NEW: TilesDE, the Windows-Phone-style mobile shell, imported from `flowde-mobile` (commit d8f9291) | no remote |
| `~/fedeos/backups/flowde-backup-2026-11-14/` | Full FlowDE backup: `flowde-all-branches.bundle` (all branches, verified) plus a tarball of each worktree incl. uncommitted files | local |

Restore FlowDE from the backup: `git clone flowde-all-branches.bundle restored` or untar the worktree archives.

## Project 1: TilesDE (top priority, owner's latest request)

## TilesDE current state (final handoff, 2026-11-14)

**Goal.** A Windows-Phone-style tiles shell (Qt 6.8 / QML) for phones, with own colours and no Microsoft assets. Default accent terracotta `#D97757`, Inter font.

**What exists (commits d8f9291 import, b392a99 tiles shell, 5e8f5c9 review fixes; nothing pushed, no remote).** In `shell/qml/`: Main, Theme (Tiles default, 12 accents, old themes kept), StartScreen (tile grid, edit mode, pin, resize, reorder, turnstile), MetroTile (4 sizes, perspective flip, press tilt), TileGlyph (26 Canvas glyphs), TileGallery, AllApps (alphabetical list, letter squares, AlphaJump, pin menu), AlphaJump, HomeScreen, LockScreen, Shade (Action Centre), AppSwitcher (2 columns), AppPage, NavBar, StatusBar, GestureBar, Toggle, SliderRow, GlassPanel, GlassIcon, AppIcon, Wallpaper. C++ in `shell/src/` (AppModel, Services mocked, main.cpp). `compositor/` is a Rust Smithay skeleton with gesture code.

**Build and run.** VM only, see "How to test TilesDE". `~/fedeos/tilesde/shell/sync-build.sh`, then `~/fedeos/vm 'bash ~/flowde-shell-build/tools/run-shell.sh'`, then `shots.sh`. Binary still `flowde-shell`. Check `/tmp/shell.log` for QML warnings (last build: none).

**Screenshots in `docs/screens/`.** m1-tiles.png, t-start.png, t-start-flip.png, t-edit.png, t-apps.png, t-alpha.png, t-lock.png, t-centre.png, t-switcher.png, t-search.png, t-app.png, t-app-settings.png. Only start, flip, apps, centre were visually confirmed; the rest were retaken but not read.

**Known defects.**
- Edit mode: dragMa uses preventStealing, Start cannot scroll while dragging a tile; edit resize button glyph not state-specific.
- Turnstile app open/close is orthographic (no perspective).
- Start grid can end in a partial row at max scroll.
- Tile order and size are not persisted; no personalisation page or theme file.
- Lock wallpaper is plain (no vector scene); clear-all has no staggered slide-out; back face not lazy-loaded.
- No debug touch-injection command; touch paths only code-reviewed.
- Light scheme, reduceMotion, other accents and old themes not screenshotted after the Theme edit.
- Toggle/SliderRow still glass-styled under Tiles when `Theme.paper` is false.
- Names `flowde-shell` / `flowde-shell-build` not renamed.

**Ranked next steps.**
1. Read the unread screenshots (lock, switcher, search, app, edit, alpha) and fix visible defects.
2. Add a touch-injection socket command; exercise reorder, hold-drag, pager swipe, lock bounce, shade drag.
3. Fix edit-mode drag vs scroll.
4. Screenshot light scheme, reduceMotion, other accents, old themes; fix regressions.
5. Persist tile layout and accent; build the personalisation page.
6. Perspective turnstile; staggered clear-all; lazy back face; wallpaper scene.
7. Restyle Toggle/SliderRow for Tiles; rename binary consistently or not at all.
8. Hook the shell to the real compositor (`compositor/`) with real app launching.

**Owner should test on a real phone or compositor.** Touch press tilt and flip feel; long-press into edit mode, drag to reorder and resize; swipe left to All Apps and back; alphabet jump; lock swipe-up bounce; Action Centre pull-down and swipe-away; app open/close turnstile smoothness; switcher close; NavBar back/home/search; frame rate at native resolution (`FLOWDE_FPS=1`); text legibility and tile sizes at the real DPI; real gesture edges from the compositor (`compositor/check.sh` for unit tests).

## TilesDE progress log

### M1 Foundation: Tiles theme, MetroTile, pipeline

**Goal of this milestone.** Build the visual and tooling foundation for TilesDE: a Tiles theme with an accent palette and tile geometry, a reusable live-tile component with flip and press-tilt, a glyph set, and a working build-and-screenshot pipeline in the VM.

**What was done.**
- `shell/qml/Theme.qml`: theme "Tiles" is now the default (dark scheme default) with 12 accents, `tileUnit`, `tileW`, `tileH`, gap 6 and page margin 12. Public API: `accent` (readonly, equals `userAccent` in Tiles), `userAccent`, `setAccent(i)`, `accents[12]`, `accentNames[12]`, `tiles`, `tileText`, `tileBack`, `tileDisabled`, `pageBg`, `tileGap`, `gap`, `pageMargin`, `tileCols`, `glyphStroke`, `tileUnit(w)`, `tileW(size,w)`, `tileH(size,w)`, `flipMs` 450, `flipPeriodMs` 6000, `flipStaggerMs` 140, `pressMs` 140, `turnstileMs` 320, `fontLight`.
- `shell/qml/MetroTile.qml`: four sizes (small, medium, wide, large), X-axis flip staggered by index, press tilt plus 0.96 scale, `clicked(rect r)` in window coordinates, `pressAndHold()`, and a default slot that is the back face (aliases `back`, `backItem`, `mouse`). Props: `size`, `label`, `glyph`, `accent` (transparent means `Theme.accent`), `live`, `index`, `screenW` (540), `tiltMax`, `flat`, `flipEnabled`, `forcePressed`, `touch`, `flipAngle`, `showingBack`; also `sceneRect()`.
- `shell/qml/TileGlyph.qml`: 26 Canvas glyphs at 3px stroke (props `name`, `color`, `stroke`, `size`). Names: phone message mail calendar clock photos music maps notes files weather terminal store camera settings people browser wallet noxal video, plus search star back forward plus close grid.
- `shell/qml/TileGallery.qml` test page, `docs/tiles-spec.md`, `shell/src/main.cpp` env defaults.
- Pipeline: `shell/sync-build.sh` builds in the VM (about 2 minutes); headless sway plus grim screenshot copied to `docs/screens/m1-tiles.png`. `sync-build.sh` now also rsyncs `tools/` to `~/flowde-shell-build/tools`, and `tools/vm-rebuild.sh` was fixed.

**Verified.** Build in the VM; screenshot viewed showing tiles, flip mid-motion with an upright back face, all glyphs; tilt direction checked (touched edge recedes) and the sign was fixed.

**Not verified.** The `clicked` and `pressAndHold` signals and real touch input (only `forcePressed` was exercised). Light scheme not screenshotted. `reduceMotion` paths not run. Old themes not re-verified after the Theme edit. Nothing is committed.

**Caveats.**
1. MetroTile, TileGlyph and TileGallery are NOT in `shell/CMakeLists.txt` `QML_FILES`; the next agent must add them. The gallery was tested through a VM-only patch of CMakeLists and Main.qml (an overlay `TileGallery` with `visible: StartScreen === "gallery"`), which is not in the repo.
2. `sync-build.sh` uses `rsync --delete`, so VM-local patches are wiped on every sync.
3. Binary and VM directory keep the old names `flowde-shell` and `flowde-shell-build`.
4. `Theme.paper` is false for Tiles, so SliderRow, Toggle and other old components render glass-style under Tiles until replaced.

**Next agent should.** Add the three new files to `QML_FILES` and put the gallery hook into Main.qml properly; build the Start screen on MetroTile; replace the old components (Toggle, SliderRow) with Tiles-styled ones; screenshot the light scheme; exercise click, press-and-hold and real touch; re-check the old themes; commit locally.

### Review fixes (done)

**Goal.** Fix review findings so TilesDE matches the reference: tight insets, tile mix, correct gestures, no per-frame glyph repaints.

**Done.** Insets 28/56, all-apps arrow is a footer row, reordered tiles (4 small, 2 medium, wide, clusters), lock drag springs back, shade close drag no longer spring-chases, Behaviors respect `Theme.reduceMotion`, back/home close alpha jump and context menu, search fed from AllApps, hold-then-drag in edit mode, resize cycle reaches large, pin passes glyph and animates scroll, flip uses perspective matrix inside the cell, glyph size snapped (no repaint while animating), filled glyph accents, Action Centre and nav/status/lock tweaks, stray `StartScreen.qml-E` removed. VM build clean, no QML warnings; screenshots in `docs/screens/t-*.png` retaken.

**Not verified.** Real touch (lock bounce, shade close, hold-drag), light scheme, reduce-motion paths.

#### Earlier entries

Goal: faithful Windows-Phone-10-Mobile look on the Qt/QML shell (black, solid accent live tiles, turnstile, alphabetical app list, nav bar, lock, action centre). Default accent terracotta `#D97757`.

- M1 Foundation (done, 2026-11-14): `Theme.qml` has theme `Tiles` (default, dark default scheme; `main.cpp` env defaults changed), 12 accents (`Theme.accents`, `Theme.userAccent`, `Theme.setAccent(i)`), `Theme.tileUnit/tileW/tileH`, gap 6, margin 12. New `MetroTile.qml` (sizes, flip, tilt, signals), `TileGlyph.qml` (26 glyphs), `TileGallery.qml` (test page), spec in `docs/tiles-spec.md`. Pipeline verified in VM: build, headless sway, grim screenshot `docs/screens/m1-tiles.png`. Fixed `shell/sync-build.sh` (also syncs `tools/` to `~/flowde-shell-build/tools`) and `tools/vm-rebuild.sh`. Not yet in `CMakeLists.txt` QML_FILES: MetroTile, TileGlyph, TileGallery (integrator adds). Run: `FLOWDE_START=gallery` needs a Main.qml hook (`TileGallery { anchors.fill: parent; z: 100; visible: StartScreen === "gallery" }`).

Goal: a Windows Phone (10 Mobile) clone UI for phones, built on the existing Qt 6.8 / QML shell. "Pivot drastically", work on this exclusively. Reference image: the Start screen with solid-colour live tiles on black (small, medium, wide tiles, People, Weather, Store tiles, etc.). Name: TilesDE.

Code: `~/fedeos/tilesde/shell/` (QML in `shell/qml/`, C++ in `shell/src/`, CMake in `shell/CMakeLists.txt`) plus `compositor/` (Rust Smithay skeleton, gestures). Existing QML: Main, Theme (singleton with several themes), HomeScreen, LockScreen, StatusBar, GestureBar, Shade, AppSwitcher, AppPage, GlassPanel/GlassIcon/AppIcon, Toggle, SliderRow, Wallpaper. Services are mocked in `src/Services.cpp` (wifi, bluetooth, battery, notifications); control socket for tests via `tools/send.py`. Decisions so far: `docs/mobile-DECISIONS.md`. Motion notes: `docs/mobile-motion.md`.

Build and test (nothing builds on the Mac, use the VM):
```bash
~/fedeos/tilesde/shell/sync-build.sh        # rsyncs to ~/flowde-shell-build in the VM, cmake+ninja under the heavy lock
~/fedeos/vm 'bash ~/flowde-shell-build/tools/run-shell.sh'   # starts the shell in headless Sway
~/fedeos/vm 'bash ~/flowde-shell-build/tools/shots.sh'       # drives every screen over the socket, grim screenshots to ~/flowde-shell-build/shots/
```
`sync-build.sh` still points at the old `flowde-shell-build` directory and binary name `flowde-shell`; renaming to `tiles-shell` is optional, do it consistently in CMake, tools and docs or not at all.

Target design (now implemented, see "Current state" above; kept as the spec):
- Start screen: black background, 4 small-tile columns across the width with small gaps. Tile sizes small (1x1), medium (2x2), wide (4x2), large (4x4). Solid accent-colour tiles with a white line glyph and a label bottom-left. Default accent: terracotta `#D97757` (owner's brand), selectable accent palette in settings. Optional translucent tiles showing the wallpaper.
- Live tiles: staggered flip animation (rotate about X) every few seconds, showing mock content (calendar, weather, mail count, photos).
- Tile interaction: press tilts toward the touch point (small 3D tilt plus scale 0.96); long-press enters edit mode (tiles shrink, unpin button, resize corner, drag to reorder, grid reflows).
- Entrance and exit: turnstile (tiles flip in from the left edge with stagger, flip out when launching an app).
- All apps: swipe left from Start, or the arrow at the bottom right. Alphabetical list, letter header squares, tap a letter for the alphabet jump grid, long-press an app to pin to Start.
- Navigation bar at the bottom: back, home (circle with a star, matching the desktop Start button), search. Status bar on top: signal, wifi, battery, clock.
- Lock screen: wallpaper, big light-weight clock and date left-aligned, notification badge icons at the bottom, swipe up to unlock with a small bounce.
- Action Centre (pull down): row of quick-action buttons with Expand, brightness slider, notification list with Clear all.
- App open/close: turnstile rotation about the left edge. App switcher: two-column cards with close buttons.
- Typography: light weights, lowercase page titles, Inter as the font (Inter is installed in the VM). No Segoe, no Microsoft logos.
- Add a `Metro`/`Tiles` theme to `Theme.qml`, make it the default, keep the old themes selectable. Register every new QML file in `shell/CMakeLists.txt` `QML_FILES`.
- Verify with screenshots in light and dark of: start, edit mode, all apps, alphabet jump, lock, action centre, switcher, an app page. Commit locally in `~/fedeos/tilesde` as Mandrusia. Do not push (no remote).

### M2 Build: screens written (untested)

**Goal of this milestone.** Write the main TilesDE screens in the Tiles style: a Start screen with live tiles and edit mode, a pager Home with an All Apps list, and Tiles-styled status bar, nav bar and lock screen. Nothing was run, so the aim here is complete first drafts for the next agent to integrate, build and test.

**What was done.**
- `shell/qml/StartScreen.qml` (new): 20 tiles (the brief said about 16), live back faces (mock text), numeric badges, first-fit 4-column packer, edit mode with unpin, resize (small, medium, wide) and drag-reorder, turnstile in and out, and an all-apps arrow. API: signals `launched(name, rect, real)`, `appsRequested()`; properties `editing`, `pagerP`, `topInset` (48), `bottomInset` (96), `flipsOn`, readonly `exiting`, alias `model`; functions `enterEdit()`, `exitEdit()`, `playEnter()`, `playExit()`, `unpin(i)`, `resize(i)`, `pinApp(name)`.
- `shell/qml/HomeScreen.qml` (rewritten): pager between StartScreen and AllApps, plus a flat black search overlay driven by `searchOpen`. Keeps `searchOpen`, `query`, `dim` for Main.qml; adds `pagerP` (0 start, 1 all apps), `topInset`, `bottomInset`, readonly `editing`, aliases `start` and `allApps`, functions `showApps()`, `showStart()`, `goBack()`, `launchByName(name, r)`.
- `shell/qml/AllApps.qml` and `AlphaJump.qml` (new): alphabetical flat list, accent-outlined letter header squares, accent square icons using TileGlyph, staggered left-edge turnstile entrance over the first 12 rows, tap to launch, long-press menu with "pin to start", and an alphabet jump grid (27 cells) with a 380 ms scroll. AllApps API: signals `launched(name, rect)`, `pinRequested(name)`; property `filter`; functions `scrollToLetter(l)`, `reset()`. It merges the `Apps` model with about 30 built-in names.
- `shell/qml/StatusBar.qml` and `LockScreen.qml` (rewritten), `shell/qml/NavBar.qml` (new, 56 px black bar with back, home, search; signals `back()`, `home()`, `search()`, `dragged(dy)`, `released(dy, vy)`; no switcher signal). LockScreen has a 96 px Thin left-aligned clock, lowercase date, mock badge counts (`mailCount`, `messageCount`, `calendarCount`) and a periodic bounce. `GestureBar.qml` is untouched.
- `Shade.qml`, `Toggle.qml`, `SliderRow.qml`, `AppSwitcher.qml`, `AppPage.qml` were rewritten in Tiles style (see the M-centre entry for details).

**Verified.** Only `qmllint` was run, on the Shade, Toggle, SliderRow, AppSwitcher and AppPage files: no syntax errors, only FlowShell import warnings. Nothing else was run, synced or built. All behaviour of the files above, including Start, All Apps, Lock, NavBar and StatusBar, is unverified in the VM.

**Not verified / known risks.**
- Edit-mode drag-reorder uses `ListModel.move` and assumes the Repeater keeps the dragged delegate; it also uses a 160 ms cooldown, a 20 to 80 % hit window and edge autoscroll. Check this first if drag misbehaves.
- A 400 ms guard (`_editAt`) stops the long-press release from launching the app.
- Turnstile is a Y rotation about the left edge with no perspective, so it reads as a horizontal squash. Tiles beyond 89.5 degrees are hidden.
- `topInset` 48 and `bottomInset` 96 are guesses and should match the real status bar and nav bar.
- NavBar tap versus drag competition on touch is untested. Hand-drawn glyphs (rotate, moon, plane) are not visually checked. The light scheme is not screenshotted.
- Tile order and size are not persisted, all tiles use `Theme.accent`, back faces are mock text, `real` is always false, and the search overlay uses a hard-coded name list instead of the `Apps` model. Badge counts are static mocks. Lock text colours are hard-coded white.
- Nothing is committed.

**Next agent should.**
1. Add `StartScreen`, `AllApps`, `AlphaJump`, `NavBar`, `TileGlyph`, `MetroTile` to `QML_FILES` in `shell/CMakeLists.txt`.
2. Edit `Main.qml`: instantiate NavBar (56 px, hidden on lock) in place of GestureBar and wire back, home, search, and map slow or held drags to the switcher via `released()`; call `home.goBack()` first on the back gesture; map socket command `screen`: `apps` to `win.page="home"; home.showApps()`, `home` to `home.showStart()`, `edit` to `win.page="home"; home.showStart(); home.start.enterEdit()`; keep the Shade `progress` binding; use a 28 px StatusBar. If the `dim` or `opacity` bindings change, call `home.start.playEnter()` explicitly.
3. Run `shell/sync-build.sh`, fix build errors, and screenshot Start, All Apps, Lock, Action Centre and the switcher.
4. Exercise edit mode, drag-reorder, long-press, and real touch, then check the Shade swipe-away against Main's DragHandler.
5. Persist tile layout, then commit locally.

### M3 Integrate: runs in VM with screenshots

**Goal of this milestone.** Integrate the new Tiles QML types into the shell so TilesDE builds and runs cleanly in the VM, and capture screenshots of every main screen. The Start screen should closely match the Windows-Phone-style reference.

**What was done.** The shell now runs without QML warnings in the VM and is committed locally as `b392a99` (not pushed). The new QML types MetroTile, TileGlyph, TileGallery, StartScreen, AllApps, AlphaJump and NavBar are registered in `shell/CMakeLists.txt`. In `shell/qml/Main.qml`, NavBar replaces GestureBar, the wallpaper shows only on the lock screen, and the window title is TilesDE. The Services mock notification text now says TilesDE. In `shell/src/main.cpp` the `StartScreen` context property clashed with the new StartScreen QML type, so it was renamed `StartPage`. Two bugs from earlier agents were fixed: an uppercase property name `L` in `StartScreen.qml` (now `lay`) and an undefined `badge` role. A capture script was added at `shell/tools/tiles-shots.sh`.
- Screens rendered: start, edit, all apps, alpha jump, lock, Action Centre, switcher, app page. Screenshots are in `docs/screens/t-start.png`, `t-edit.png`, `t-apps.png`, `t-alpha.png`, `t-lock.png`, `t-centre.png`, `t-switcher.png`, `t-app.png`.
- Start matches the reference in layout: black background, solid terracotta tiles, white glyphs, labels bottom-left, 6px gaps, bottom nav bar with the circled-star home button. Edit mode shows unpin and resize buttons per tile. Lock has the terracotta gradient wallpaper, a thin 96px clock, a lowercase date and badge counts. Action Centre has accent quick toggles, a brightness slider and a notification list. The switcher shows cards with a close button and a close-all button. The app page has an accent title bar with a turnstile entrance.
- Public API: control socket `{"set":"screen","value":"<screen>"}` with screen one of lock, home, apps, edit, centre (alias shade), alpha, search, switcher; `{"set":"open","value":"<App>"}` opens an app page. Main.qml functions: `screenCmd(v)`, `applyStart()`, `gesture(name)` (home, switcher, shade, qs, search, back). Env `FLOWDE_START` takes the same screen names. AllApps has a new alias `alpha` (AlphaJump). The binary and VM directory keep the old names `flowde-shell` and `flowde-shell-build`.

**Verified.** Clean VM build, no QML warnings in the log, and each screen above checked visually through control-socket screenshots.

**Not verified.** Real touch input was never used: drag-reorder, press-and-hold, the pager swipe, NavBar tap versus drag, the lock swipe bounce and Action Centre swipe-away are untested. The light scheme, `reduceMotion` and the other accents were not screenshotted, and the old themes were not re-checked. The turnstile is a Y-rotation without perspective, so it reads as a squash; only one mid-flip frame (Photos tile) was captured and the full animation was not judged.

**Caveats.**
1. The all-apps arrow button overlaps the bottom-right of the last visible tile row on Start.
2. The search nav button opens the flat search overlay, not the All Apps list with a filter field, and that overlay uses a hard-coded name list.
3. Tile order and size are not persisted. Live tiles, badges and lock counts are mock data.
4. The wallpaper is a plain procedural gradient (Theme Tiles dark w0-w3), not a photo.
5. Builds are slow when other agents hold the VM heavy lock, though each finished. The first sync-build call exceeded the 120s tool timeout and was backgrounded, so the VM ran several queued builds of the same directory; the final build is current.
6. `docs/design-ref` was already git-ignored, so the reference image was not committed.
7. The commit message has no trailers and the author is the repo-local git config.

**Next agent should.** Test with real touch input (reorder, press-and-hold, pager swipe, NavBar, lock swipe, Action Centre swipe-away). Fix the all-apps arrow overlap. Screenshot the light scheme, `reduceMotion` and other accents, and re-check the old themes. Add perspective to the turnstile and review the full animation. Make search open All Apps with a filter field. Persist tile order and size. Then build the personalisation page and persisted theme file described in the design references section.

### M4 Review: findings fixed

**Goal of this milestone.** Work through the review of the TilesDE shell (36 findings) so the Start screen, All Apps, lock, Action Centre and switcher match the Tiles design references and behave correctly, and keep the VM build clean.

**What was done.** Nearly all findings were fixed and committed as 5e8f5c9 "TilesDE: review fixes" (author Mandrusia, no trailers, not pushed). Files touched: Main, StartScreen, HomeScreen, MetroTile, TileGlyph, AllApps, Shade, NavBar, StatusBar, LockScreen, AppSwitcher and Theme under `shell/qml/`, plus this file and `docs/screens/`.
- Start: insets 28/56 passed from Main, arrow moved into the Flickable footer, tile model reordered (4 small, 2 medium, wide, medium+small clusters), width/height Behaviors gated on enterP>=1, glyph size snapped to nominal tile size (no per-frame Canvas repaint), resize cycle small, medium, wide, large, small, hold-then-drag handoff in edit mode, home on Start scrolls to top, pin passes the glyph and only returns to Start on success with an animated scroll.
- MetroTile and glyphs: label 14px with 8/6 margins, perspective flip via Matrix4x4 capped to the cell with a layer while flipping (mid-flip screenshot stays in the gutter), glyph stroke 3.6, filled mail/store/calendar/people/star accents, turnstile pivot at the screen left edge, playExit on any launch.
- Lock, shade, input: lock release below threshold resets lockP to 0 (also on fling unlock), shadeCloseDrag id fixed in the Behavior condition, reduceMotion honoured on lock/shade/switch Behaviors, Shade progress clamped, back/home/search close alpha jump plus menu handling, swipe pager disabled while overlays are open and uses velocity, lock-state gestures ignored.
- Other screens: search fed from AllApps.entries with the query cleared, focus forced and a toggle; AllApps title, headers and names restyled (Theme.font, 22px, 44px header square with 1px border, glyph-less first-letter Normal weight, rebuild on rows signals with callLater); Action Centre flat #1b1b1b, 36px top, no accent stripe, chevron on collapse/expand; NavBar 32px canvas, r13, filled star; StatusBar clock 14, battery percent hidden, rightMargin 12; Lock clock 120 ExtraLight and hint 12px at 0.5; AppSwitcher 2 columns with 6px gutters; HomeScreen scale animation skipped under Theme.tiles; stray StartScreen.qml-E deleted.
- New public API: StartScreen.pinApp(name, glyph) returns bool; StartScreen.scrollTop()/scrollTo(y); AllApps.pinRequested(name, glyph); AllApps.closeOverlays(); AllApps.menuShown (readonly bool); Theme.glyphStroke is now a real 3.6; MetroTile.flipM, nomW, nomH. No new QML types.

**Verified.** VM build is clean and /tmp/shell.log shows no QML warnings. The t-*.png screenshots were retaken, and the start, flip, apps and centre screens were viewed and confirmed.

**Not verified.** Lock, switcher, search, app and edit screenshots were retaken but not visually read. Real touch paths (lock bounce, shade close drag, hold-then-drag, tilt) are code-reviewed only. The light scheme and reduceMotion were not screenshotted.

**Not done.** Wallpaper vector scene (lock, optional); staggered clear-all slide-out; Loader lazy back face and flipper restart tweak (optional); dragMa still uses preventStealing so Start cannot be scrolled by dragging tiles in edit mode; the edit-mode resize button glyph is not state-specific; no debug touch-injection command; the turnstile is still orthographic (pivot fixed, no perspective); the Start grid can still end in a partial row at max scroll (a footer row was added).

**Next agent should.** Read the lock, switcher, search, app and edit screenshots and fix anything visible; screenshot the light scheme and reduceMotion; add a debug touch-injection command so real touch paths can be exercised; resolve the edit-mode drag-scroll limitation; then take on the optional items above (wallpaper scene, staggered clear-all, lazy back face, perspective turnstile). Push the commit only when the owner asks.

### How to test TilesDE (build, run, see it in a graphical session, drive it, screenshot it)

Nothing about the shell builds or runs on the Mac. Everything happens in the aarch64 Debian VM (QEMU window on the Mac, display `-display cocoa`).

1. Start the VM if it is down (from `~/fedeos`, in the background; macOS has no `setsid`/`timeout`):
   ```bash
   cd ~/fedeos && nohup ./run.sh > /tmp/qemu.log 2>&1 &
   ```
   Wait until `~/fedeos/vm 'echo up'` prints `up`. A QEMU window titled "QEMU" opens on the Mac: that is the VM's real graphical screen (virtio-gpu, 1280x800). Click inside it to capture the mouse, press Ctrl+Option+G to release it. If ssh says "Connection timed out during banner exchange" the Mac is out of memory: kill QEMU, restart, run `fstrim -av` in the VM.
2. Build (rsyncs `shell/` to `~/flowde-shell-build/shell/` in the VM, configures with cmake+Ninja, builds under `flock /tmp/heavy-build.lock -j2`; reads shaders with qsb):
   ```bash
   ~/fedeos/tilesde/shell/sync-build.sh
   ```
   The built binary is `~/flowde-shell-build/b-shell/flowde-shell` (name may have changed, check `shell/CMakeLists.txt`). Always `export PATH=$HOME/.cargo/bin:$PATH` in non-login ssh shells (only needed for the Rust compositor, not for the Qt shell). Note: the helper scripts reference `~/flowde-shell-build/tools/*` while rsync puts them in `~/flowde-shell-build/shell/tools/`; a copy of the tools is at `~/flowde-shell-build/tools/` already. Re-copy after editing: `~/fedeos/vm 'cp -r ~/flowde-shell-build/shell/tools/. ~/flowde-shell-build/tools/'`.
3. Run headless (portrait 540x1170, the default for screenshots and automated tests; uses a throwaway Sway with `WLR_BACKENDS=headless`, it never touches the live session):
   ```bash
   ~/fedeos/vm 'bash ~/flowde-shell-build/tools/run-shell.sh'            # starts throwaway Sway + the shell, log in /tmp/shell.log
   ~/fedeos/vm 'tail -30 /tmp/shell.log'                                  # QML errors show up here
   ~/fedeos/vm 'bash ~/flowde-shell-build/tools/shots.sh'                 # drives every screen and grims PNGs into ~/flowde-shell-build/shots/
   ```
   Environment knobs read by the shell: `FLOWDE_START` (lock|home|switcher|shade|search), `FLOWDE_THEME`, `FLOWDE_SCHEME` (light|dark), `FLOWDE_GLASS` (full|blur|flat), `FLOWDE_FPS=1` (frame-time log), `FLOWDE_SHELL_SOCKET`. Pull screenshots to the Mac and look at them with the Read tool:
   ```bash
   scp -i ~/fedeos/fedeos_key -P 2222 -o StrictHostKeyChecking=no 'fede@localhost:flowde-shell-build/shots/*.png' ~/fedeos/tilesde/docs/screens/
   ```
4. Drive a running shell over its control socket (JSON lines, no touch needed):
   ```bash
   ~/fedeos/vm 'export XDG_RUNTIME_DIR=/tmp/xdg-flow; python3 ~/flowde-shell-build/tools/send.py $XDG_RUNTIME_DIR/flowde-shell.sock "{\"set\":\"screen\",\"value\":\"home\"}"'
   ```
   Keys: `screen` (lock, home, search, switcher, shade, app via `open`), `theme`, `scheme` (light|dark), `glass`, `reduceTransparency`. New TilesDE screens and `set` keys (apps, edit, centre, alpha, accent, amoled, gap, radius, opacity, preset ...) must be added to `onCommand` in `shell/qml/Main.qml` and documented in `docs/tiles-spec.md`.
5. See it live in the graphical session (the QEMU window): the VM's tty1 session is Sway (`pgrep -a sway`, Wayland socket under `/run/user/1000`). Run the shell inside it as a window:
   ```bash
   ~/fedeos/vm 'export XDG_RUNTIME_DIR=/run/user/1000; export WAYLAND_DISPLAY=$(basename $(ls /run/user/1000/wayland-[0-9] | head -1)); export QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl; nohup ~/flowde-shell-build/b-shell/flowde-shell >/tmp/shell-live.log 2>&1 &'
   ```
   The window is 540x1170 on a 1280x800 screen, so scale it down in Sway (for example `swaymsg floating enable` then resize to 360x780) or add a `FLOWDE_SIZE=WxH` environment override in `Main.qml`/`main.cpp` (recommended, then use `FLOWDE_SIZE=400x780`). Kill it with `pkill -x flowde-shell`. Do not kill the desktop panel/session processes.
6. Screenshot the live QEMU screen (works for any session): `python3 ~/fedeos/glaze/scripts/vm/qmp_screendump.py ~/fedeos/qmp.sock /path/out.png`, or `GLAZE_SHOT_GRIM=1 ~/fedeos/glaze/scripts/vm/shot.sh NAME M0` for grim. QMP screendump can lag a few seconds; wait 2 s after a change.
7. Inject touch/mouse and keys in the live session (to test drag, long-press, swipes): `python3 ~/fedeos/glaze/scripts/vm/qmp_pointer.py --size 1280x800 ...` (see its usage text; it supports mouse moves, press/release, drags and key chords over QMP). The nested shell treats the mouse as one finger. Real touch comes from the compositor (`compositor/`, Smithay, gestures in `compositor/src/gesture.rs`, 6 unit tests via `compositor/check.sh`).
8. Optional: run on the Mac. Install Qt 6.8 (`brew install qt`), build with CMake (`qt_add_shaders` needs `qsb`), run with `QT_QPA_PLATFORM=cocoa`. Untested; Services are mocked so it should start.
9. Acceptance for any change: shell starts with zero QML warnings in `/tmp/shell.log`, screenshots of every screen in the default theme and in AMOLED/light checked with the Read tool, frame times acceptable with `FLOWDE_FPS=1`, work committed locally in `~/fedeos/tilesde` as Mandrusia with no trailers.

### TilesDE design references (owner's instruction: take heavy inspiration and reference from these)

All local, private, gitignored (`docs/design-ref/` must never be committed). Open them with an image viewer or the Read tool:

1. `/Users/xavi/fedeos/tilesde/docs/design-ref/phone-start-wp10-mobile.png` (same file as `phone-start.png`): Windows 10 Mobile Start screen. Medium tiles, wide Outlook-style tiles, a Store tile, 2-column look, bottom nav.
2. `/Users/xavi/fedeos/tilesde/docs/design-ref/phone-start-wp8-three-phones.webp`: three Windows Phone 8 Start screens in yellow, blue and green. Study: 4 small tiles per row; big white numeric badges next to glyphs (mail 1, messages 4, calls 3); medium and wide live tiles with photos and text (contact name on a photo, "Missed call" with caller at the bottom, calendar tile with date number); full-bleed picture tiles; flat colour tiles with no rounding and a small 6 px gap; status bar with signal, 4G, battery and clock; the bottom hardware-style bar with back, home, search.
3. `/Users/xavi/fedeos/tilesde/docs/design-ref/glaze-start-menu-tiles.png`: the Glaze desktop Start menu tile pane, which TilesDE must look like in colours and customizability. Terracotta (`#D97757`-ish), ink-dark (`#22211f`-ish) and paper-grey (`#d8d6cf`-ish) flat tiles, group headings "Productivity" and "Explore" in light type above each group, labels bottom-left (small, left aligned), glyph centred, one large tile and several medium tiles per group, subtle paper-grain dark background, no corner rounding.

More references (all in `/Users/xavi/fedeos/tilesde/docs/design-ref/`, owner wants these used for the Settings app, All Apps, lock screen settings, Action Centre and every list screen, not only Start):

4. `wp-settings-system-pivot.png`: Settings in the "pivot" style. Small uppercase app title ("SETTINGS"), then a huge light lowercase page title ("system") with the next pivot page title ("applications") half visible in dim grey to the right, swipe horizontally between pivot pages. Below: a plain list, each row a lowercase 24 px light title with a small grey subtitle ("display / brightness, battery saving and colour"). No icons, no dividers, large left margin of about 18 px, pure black.
5. `wp-all-apps-letter-boxes-navbar.png`: All Apps list. Letter headers are accent-outlined squares containing the letter (no fill), app rows are accent-filled squares with a white glyph plus the name in 20 px; a round search button top-left; bottom nav bar with back arrow, home (logo-style glyph, use our circle-with-star), search. Status bar shows signal, wifi, clock.
6. `wp-settings-lock-screen-boxes-toggle.png`: form controls of this style: toggle is a flat outlined rectangle with a white block that slides, label above, value "Off"/"On" in 28 px; dropdowns are flat white-outlined rectangles with the value inside; "choose apps" squares are white-outlined 52 px boxes with a glyph; section headings in dim grey lowercase ("notifications").
7. `wp-start-theme-settings-tile-preview.png`: "start+theme" page. Dropdown fields "Background: dark" and "Accent colour: cobalt" (with a small coloured square), a "Start background" picture with "choose photo" button and "remove" link, "Show more tiles: On/Off" toggle with a phone-outline preview of the tile layout in the accent colour. Left strip shows picture tiles and the live badge look. Build this exact page as the personalisation page.
8. `wp-settings-list-and-accounts.png`: Settings list ("ringtones+sounds / theme / email+accounts / internet sharing / lock screen / screen rotation / Wi-Fi") with grey subtitles, and a sub-page "email+accounts" with a circled-plus "add an account" row and account rows with big glyph squares. Note the "+" in page titles ("email+accounts").
9. `wp-action-centre-and-notifications-list.png`: Action Centre: 4 flat accent-blue quick-action tiles in a row with small uppercase captions (Wi-Fi network, Bluetooth "NOT CONNECTED", Airplane mode, Rotation lock; an off tile is dark grey), below them a row "x CLEAR ALL" left and a gear "ALL SETTINGS" right, then notifications each with an accent square app icon, app name in 24 px, text below in 17 px bold-ish and the time at right ("5:19p"). A thin accent-coloured bar with a small handle at the bottom edge closes it. Right half shows "notifications+actions" list: accent squares with glyph, big name, grey status line.
10. `wp-battery-usage-pivot.png`: another pivot page ("usage" big, "settings" dim) with accent-square icons and tiny accent usage bars under each app name, "allowed" in grey.

Common visual rules extracted from all references: pure black background; flat accent-coloured squares (no radius, no shadow, no gradients) for icons; white text only, light/regular weight, big lowercase titles, small uppercase app caption; generous vertical rhythm (rows about 64 to 72 px, 18 px left margin); outlined (1.5 to 2 px white) rectangles for inputs; motion is horizontal sliding pivots, turnstile page flips and staggered tile flips.

Instruction to the next agent (Codex): do your own research before and while building. Study how Windows Phone 8.1 / Windows 10 Mobile Start, pivot, panorama, app bar, toggle, list picker, hub and Action Centre behave: exact tile unit sizes and gaps (WP8.1 small tile 71 px on a 480 px wide screen, 3 columns, or 6 columns with "show more tiles"), the turnstile and continuum-style transition timings and easing, press-tilt behaviour, live-tile flip timing, parallax in panorama titles, font metrics of the light type, and any open-source Metro/Modern UI clone projects and QML Metro style libraries for ideas (read their code, check licences, do not copy proprietary assets). Write what you learned into `docs/tiles-spec.md` with source links so decisions can be audited. Keep the no-Microsoft-names/logos/icons/fonts rule.

Requirement from the owner: a TilesDE Start screen that combines the Windows Phone structure (live tiles, numeric badges, picture tiles, flip animations) with the Glaze Start menu look (named tile groups, the terracotta / ink / paper colours) and is extremely customizable. It should feel very "Microsoft Windows Phone" (flat, bold, typographic, motion-driven) with no Microsoft names, logos, icons or font files.

Customizability and theming requirements (implement as real settings, persisted, applied live):
- Colour schemes as presets and fully editable: "Glaze" (terracotta, ink, paper tiles on dark), "Classic Phone" (yellow, blue, green, red tile colours like the WP8 reference), "Mono", plus user presets. Per-tile colour override (accent, ink, paper, any custom RGB), global accent colour picker with a 12-colour palette and a free colour field.
- AMOLED theme: pure `#000000` background, tiles may be solid, outlined or translucent over the wallpaper; light theme as well; automatic switch by time optional. Dark, AMOLED and light must all work everywhere (lock, apps list, action centre, switcher, app pages).
- Tile options: sizes small / medium / wide / large per tile, tile gap (0 to 12 px), tile corner radius (0 default, up to 16), tile opacity, label on/off, glyph size, picture tiles (use a photo as tile face), numeric badge on/off, live-tile flip speed and on/off.
- Groups: named tile groups ("Productivity", "Explore" ...) with editable names, add/remove/reorder groups, collapse.
- Start screen options: tiles over wallpaper vs black, background grain on/off, columns (3 or 4), density.
- Type: font weight (light default), uppercase / lowercase titles.
- Motion: global intensity (off / low / normal / high) like Glaze's `[motion] intensity`.
- Settings page "personalisation" with a live preview, plus control-socket commands (`set theme`, `set accent`, `set scheme`, `set amoled`, `set gap`, `set radius`, `set opacity`, `set preset`) so the screenshot tools and tests can drive it. Persist in a single file (JSON or TOML, for example `~/.config/tilesde/theme.json`) with a documented schema in `docs/tiles-spec.md`.

## Project 2: Glaze desktop (paused; agents died on a rate limit)

State: tty1 is still Sway. The Glaze compositor runs on tty2 for tests only. Last measured (VM, software GL, 4 vCPUs): open/close p95 about 10 ms, but the 5-minute soak (`~/fedeos/glaze/scripts/vm/m4-soak.sh 5 1280x800`) showed many 5-second windows at 1-7 fps (p95 100 ms to 2.4 s). Likely cause: the new snapshot morph (maximise/snap/tiling) and workspace slides. The compositor stayed alive for the whole soak with no panics. Do NOT switch tty1 to Glaze until a soak is smooth; the switch script is `scripts/vm/make-glaze-default.sh`, rollback `make-glaze-default.sh --rollback` or `echo sway > ~/.config/glaze/session-backend`.

Compositor animation work (done in code, `crates/glaze-compositor/src/{anim,state,render}.rs`, config key `[motion] intensity = off|low|normal|high`) was never committed or pushed. Verified only on tty2.

Open bugs, all reported by the owner from the tty1 Sway session (shell and Sway code, `apps/glaze-shell/`):
1. Minimise/restore on Sway shows a blank screen with a thin terracotta outlined box: `apps/glaze-shell/src/ghost.rs` paper-outline overlay is painted opaque. Make it transparent or skip on Sway.
2. Windows under Sway have Sway's title bar with no min/max/close buttons (control strip in `wincontrols.rs`), and window bottoms run under the taskbar (backend Sway fit command).
3. Top/side snap: Sway has no drag snap; keyboard snap is `/usr/local/bin/glaze-snap` via `sway.conf`. Verify keyboard snap, add drag snap if feasible. On the Glaze compositor drag snap and keyboard snap work.
4. Start menu close animation (mirror of the open slide-up) and the older Start menu glitch.
5. The NEW look must be the default: Windows-10-style taskbar (full width, circle-with-star Start button with no text, search, task view, icon buttons with underlines, tray, two-line clock, show-desktop sliver) and the two-pane tiles Start menu. After a compositor reset the desktop came back with the old text "Glaze" Start button. Fix the `panel.style` and `start.style` defaults and the deployed VM config; keep the old style selectable.
6. `glaze-shell` is killed by `zwlr_layer_surface_v1: width 0 requested without setting left and right anchors` (seen on scheme reload and the toast overlay). It blocks a clean soak.
7. Unfinished from the shell plan: popup edge-flipping for right-click menus, desktop icons and marquee selection, merging a pinned taskbar icon with its running window into one button, broader animation catalogue with an intensity slider.

Build: Glaze compositor in the VM at `~/glaze-comp`: `export PATH=$HOME/.cargo/bin:$PATH; flock /tmp/heavy-build.lock cargo build -j2 --release -p glaze-compositor -p glaze-session`, install both into `~/.local/glaze-m4/bin`. Test scripts in `~/fedeos/glaze/scripts/vm/` (`m4-openclose.sh`, `m4-soak.sh`, `m4-check.sh`).

## Project 3: Kiln GNU/Linux ISOs (Debian 13 based)

- x86_64: pipeline is written and pushed (commit 29e5fbe on `beta`) but never run. Files: `stage-kiln/build/x86/Dockerfile`, `build/x86/build-iso.sh`, `.github/workflows/build-iso.yml`, `build/README.md`, `.gitattributes`. Owner's goal: boot the live ISO on real x86 hardware, building from Windows with Docker Desktop (WSL2). Expect first-run fixes: `docker build`, the amd64 Rust compile, `lb build`, hook failures, package names that exist only on amd64 (`linux-image-amd64`, `grub-pc-bin`, `syslinux`), boot entries. Nothing has been booted.
- arm64: ISO build died during squashfs (VM out of memory/disk). Retry in the VM: `cd ~/glaze-pkg/packaging/kilnlinux/image && (nohup ./build.sh --slim > ~/kiln-iso-out/build-wrapper.log 2>&1 </dev/null &)`. That copy is the old arm64-only recipe; the new recipe is in `stage-kiln/glaze/packaging/kilnlinux/image`. Slim needs about 7 GB peak, VM has about 8 GB free. Boot test script: `~/fedeos/iso/boot-test.sh` (never run).
- `AI.md` in `stage-kiln` tells any AI how to build the ISO.
- Kiln Store and app forks in `~/fedeos/kiln-apps`: Installed tab, pkexec prompt and real Flatpak install are unverified.

## Work queue (suggested order)

1. TilesDE: implement the design above in `~/fedeos/tilesde`, verify in the VM with screenshots, commit locally.
2. Glaze fixes 5, 6, 1-2, 4 above (shell code), then the soak regression, then commit. Pushing `glaze` to `Mandrusian/glaze` `main` is authorised.
3. x86_64 ISO: only if Docker is available; otherwise leave it for the owner's Windows run and fix whatever they report.
4. arm64 ISO retry once the VM has more free disk.

## Reporting

Finish each task with: what changed (files), what you ran, what you did not test, the commit hash, and whether it was pushed.

### M-centre: Action Centre, switcher, turnstile page (2026-11-14)
Goal: Tiles-style Shade (Action Centre), Toggle, SliderRow, AppSwitcher, AppPage. Rewrote the five files (no new QML types; no QML_FILES change). Shade: 4 flat accent quick tiles (wifi, bluetooth, rotation, quiet) + "expand" row (airplane, dark, sound, motion), flat brightness slider, notifications with swipe-away and "clear all". AppSwitcher: 2-col grid, x close, "close all"; emits closedOne(name) with a string (old code emitted an object). AppPage: turnstile (Rotation about left edge, -90..0 by p), accent title bar, mock content per app; settings page has accent picker. Verified only with qmllint syntax; not run in the VM. Toggle draws its own glyph names (wifi bluetooth rotate moon plane sun sound motion); AppSwitcher/AppPage use TileGlyph (must be in QML_FILES).
