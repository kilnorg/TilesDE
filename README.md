# TilesDE

A touch-first phone shell for Linux in the style of Windows Phone: live tiles,
a pivot-based Settings app, an action-centre shade, a lock screen and an
on-screen keyboard with glide typing. Qt 6 / QML, runs as a Wayland client.

Status: works on a Debian aarch64 VM under Sway. Not yet tested on real
hardware, so expect rough edges on a phone.

## How it runs

TilesDE is not a compositor. `flowde-shell` is a fullscreen Wayland client.
It runs inside a small compositor (Sway is the tested one). Third-party
windows are kept inside the phone frame by `shell/tools/tiles-wm.py`, a Sway
IPC helper that the shell starts for the apps it launches.

```
sway (or any wlroots compositor)
 └─ flowde-shell          the shell (this repo, shell/)
     └─ tiles-wm.py       keeps launched apps inside the phone frame
```

(`compositor/` is a Rust experiment for a dedicated compositor and is not
needed to run the shell.)

## Dependencies

Build: CMake >= 3.21, Ninja, a C++17 compiler, Qt 6.5+ (6.8 tested) with
Core, Gui, Qml, Quick, Network, DBus and ShaderTools.

Runtime: Qt Wayland platform plugin, QtQuick modules (Controls not required),
Sway, Python 3, `foot` (terminal app), and for the real device features
`NetworkManager` (`nmcli`), `wireplumber` (`wpctl`), `bluez`
(`bluetoothctl`), `brightnessctl`. Missing hardware tools just grey out the
matching toggle.

Debian / Kiln:

```bash
sudo apt install build-essential cmake ninja-build pkg-config \
  qt6-base-dev qt6-declarative-dev qt6-shadertools-dev qt6-wayland \
  qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-shapes \
  qml6-module-qt-labs-folderlistmodel \
  sway python3 foot network-manager wireplumber bluez brightnessctl
```

postmarketOS (Alpine). Package names below are from memory, check them with
`apk search` if one is missing:

```bash
sudo apk add build-base cmake samurai pkgconf \
  qt6-qtbase-dev qt6-qtdeclarative-dev qt6-qtshadertools-dev qt6-qtwayland \
  sway python3 foot networkmanager wireplumber bluez brightnessctl
```

## Build

```bash
git clone https://github.com/kilnorg/TilesDE
cd TilesDE/shell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build        # installs `flowde-shell` to /usr/local/bin
```

The binary is still called `flowde-shell`.

Release builds contain no demo data. For a build that seeds fake mail,
contacts, notes, calendar, music and weather (development only):

```bash
cmake -S . -B build -G Ninja -DTILES_DEMO_DATA=ON
```

`TILES_DEMO=1` or `TILES_DEMO=0` in the environment overrides this at run
time.

## Run

Inside an existing Sway session (for example from a terminal on the phone):

```bash
export QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl
flowde-shell
```

To make it the whole session, point Sway at it. Minimal `~/.config/sway/config`:

```
default_border none
focus_follows_mouse no
output * transform 0
exec flowde-shell
```

Useful environment variables:

| Variable | Effect |
|---|---|
| `FLOWDE_START` | first screen: `lock`, `home`, ... |
| `FLOWDE_SCHEME` | `dark` or `light` |
| `FLOWDE_THEME` | accent theme |
| `FLOWDE_MOCK=1` | show demo notifications |
| `TILES_DEMO=1` | seed demo app data |

The design width is 540 px. The UI scales to the window width, so any phone
resolution works.

## Notes for phone installs

- Wi-Fi, volume, brightness, battery and Bluetooth are read through the tools
  listed above. Whatever the device has is shown, the rest is greyed out.
- The notification shade owns `org.freedesktop.Notifications` on the session
  bus, so a running notification daemon (mako, dunst) will conflict. Stop it.
- App store: pulls from Debian apt and Flathub. On postmarketOS apt does not
  exist, so only Flathub works there until an apk backend is added.
- Touch input needs a compositor with touchscreen support. Sway has it.
- First launch can be slow while Qt compiles shaders.

## Development

`run-gui.sh` and `shell/sync-build.sh` assume the author's QEMU test VM and
are not needed for a normal build.

## License

See `LICENSE`.
