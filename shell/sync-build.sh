#!/usr/bin/env bash
# Sync shell/ to the FedeOS VM and build it (heavy build lock). Usage: shell/sync-build.sh
# Dev flow builds with demo data ON (TILES_DEMO_DATA=OFF shell/sync-build.sh for a release-like build; env TILES_DEMO=1/0 overrides at runtime).
# VM layout: ~/flowde-shell-build/{shell (sources), tools (scripts, synced from shell/tools), b-shell (build), shots}
# Binary stays named flowde-shell (CMake target); rename is optional and must be done everywhere.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; VM="$HERE/../../vm"
SSHO="ssh -i $HERE/../../fedeos_key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
"$VM" 'mkdir -p ~/flowde-shell-build/shell ~/flowde-shell-build/tools ~/flowde-shell-build/shots'
rsync -a --delete -e "$SSHO" "$HERE/" fede@localhost:flowde-shell-build/shell/
rsync -a --delete -e "$SSHO" "$HERE/tools/" fede@localhost:flowde-shell-build/tools/
"$VM" 'cd ~/flowde-shell-build/shell && cmake -S . -B ../b-shell -G Ninja -DCMAKE_BUILD_TYPE=Release -DTILES_DEMO_DATA=${TILES_DEMO_DATA:-ON} >/dev/null && flock /tmp/heavy-build.lock cmake --build ../b-shell -j2 2>&1 | tail -40'
