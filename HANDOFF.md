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

Goal: a Windows Phone (10 Mobile) clone UI for phones, built on the existing Qt 6.8 / QML shell. "Pivot drastically", work on this exclusively. Reference image: the Start screen with solid-colour live tiles on black (small, medium, wide tiles, People, Weather, Store tiles, etc.). Name: TilesDE.

Code: `~/fedeos/tilesde/shell/` (QML in `shell/qml/`, C++ in `shell/src/`, CMake in `shell/CMakeLists.txt`) plus `compositor/` (Rust Smithay skeleton, gestures). Existing QML: Main, Theme (singleton with several themes), HomeScreen, LockScreen, StatusBar, GestureBar, Shade, AppSwitcher, AppPage, GlassPanel/GlassIcon/AppIcon, Toggle, SliderRow, Wallpaper. Services are mocked in `src/Services.cpp` (wifi, bluetooth, battery, notifications); control socket for tests via `tools/send.py`. Decisions so far: `docs/mobile-DECISIONS.md`. Motion notes: `docs/mobile-motion.md`.

Build and test (nothing builds on the Mac, use the VM):
```bash
~/fedeos/tilesde/shell/sync-build.sh        # rsyncs to ~/flowde-shell-build in the VM, cmake+ninja under the heavy lock
~/fedeos/vm 'bash ~/flowde-shell-build/tools/run-shell.sh'   # starts the shell in headless Sway
~/fedeos/vm 'bash ~/flowde-shell-build/tools/shots.sh'       # drives every screen over the socket, grim screenshots to ~/flowde-shell-build/shots/
```
`sync-build.sh` still points at the old `flowde-shell-build` directory and binary name `flowde-shell`; renaming to `tiles-shell` is optional, do it consistently in CMake, tools and docs or not at all.

Target design (not yet implemented, nothing in `tilesde` has been changed from FlowDE except the import):
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
