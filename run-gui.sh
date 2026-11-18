#!/usr/bin/env bash
# Open TilesDE in a real graphical window you can click: boots the Kiln/Debian aarch64 VM
# (its screen is the QEMU window on this Mac), builds the shell in the VM, and starts it
# as a floating phone-sized window inside the VM's live Sway session.
#
# Usage: ./run-gui.sh [--no-build] [--size WxH] [--stop]
#   --no-build   skip the rsync+cmake build, run what is already built
#   --size WxH   window size (default 400x866; design size is 540x1170, UI scales to width)
#   --stop       close the TilesDE window
# Env: FEDEOS_DIR (dir holding run.sh, vm, fedeos_key; default: parent of this repo),
#      FLOWDE_START (lock|home|...), FLOWDE_SCHEME (dark|light), FLOWDE_THEME.
# In the QEMU window: click inside to capture the mouse, Ctrl+Option+G releases it.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FEDEOS_DIR="${FEDEOS_DIR:-$(cd "$HERE/.." && pwd)}"
VM="$FEDEOS_DIR/vm"
SIZE=400x866
BUILD=1
STOP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) BUILD=0 ;;
    --size) SIZE="$2"; shift ;;
    --stop) STOP=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -x "$VM" ] || { echo "missing $VM (set FEDEOS_DIR)" >&2; exit 1; }
vm() { "$VM" "$@"; }
up() { vm 'echo up' 2>/dev/null | grep -q '^up$'; }

if [ "$STOP" = 1 ]; then
  vm 'pkill -x flowde-shell || true'; echo "TilesDE closed."; exit 0
fi

# 1. VM
if ! up; then
  if ! pgrep -f qemu-system-aarch64 >/dev/null; then
    echo "Starting the VM (a QEMU window will open)..."
    (cd "$FEDEOS_DIR" && nohup ./run.sh >/tmp/qemu.log 2>&1 &)
  fi
  printf "Waiting for ssh"
  for _ in $(seq 120); do up && break; printf .; sleep 2; done
  echo
  up || { echo "VM did not come up; see /tmp/qemu.log" >&2; exit 1; }
fi

# 2. Build
if [ "$BUILD" = 1 ]; then
  echo "Building TilesDE in the VM (first build takes a few minutes)..."
  "$HERE/shell/sync-build.sh"
fi
vm 'test -x ~/flowde-shell-build/b-shell/flowde-shell' \
  || { echo "no built binary; run without --no-build" >&2; exit 1; }

# 3. Run inside the VM's live Sway session
W="${SIZE%x*}"; H="${SIZE#*x}"
ENVV="FLOWDE_SIZE=$SIZE"
for v in FLOWDE_START FLOWDE_SCHEME FLOWDE_THEME FLOWDE_FPS TILESDE_CONFIG; do
  [ -n "${!v:-}" ] && ENVV="$ENVV $v=${!v}"
done
vm "bash -s" <<EOF
export XDG_RUNTIME_DIR=/run/user/1000
sock=\$(ls \$XDG_RUNTIME_DIR/wayland-[0-9] 2>/dev/null | head -1)
if [ -z "\$sock" ]; then
  echo "No live Wayland session. In the QEMU window log in on tty1 (Sway starts automatically), then rerun." >&2
  exit 3
fi
export WAYLAND_DISPLAY=\$(basename "\$sock")
export SWAYSOCK=\$(ls \$XDG_RUNTIME_DIR/sway-ipc.*.sock 2>/dev/null | head -1)
export QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl FLOWDE_SHELL_SOCKET=\$XDG_RUNTIME_DIR/flowde-shell.sock
pkill -x flowde-shell 2>/dev/null; sleep 0.5
env $ENVV nohup ~/flowde-shell-build/b-shell/flowde-shell >/tmp/shell-live.log 2>&1 &
sleep 4
swaymsg 'floating enable, resize set $W $H, move position center' >/dev/null 2>&1 || true
echo "log tail:"; tail -5 /tmp/shell-live.log
EOF
echo
echo "TilesDE is open in the QEMU window. Close it with: $0 --stop"
echo "Drive it: $VM 'export XDG_RUNTIME_DIR=/run/user/1000; python3 ~/flowde-shell-build/tools/send.py \$XDG_RUNTIME_DIR/flowde-shell.sock \"{\\\"set\\\":\\\"screen\\\",\\\"value\\\":\\\"lock\\\"}\"'"
