#!/usr/bin/env bash
# VM: drive the TilesDE shell over its socket and grim each screen to ~/flowde-shell-build/shots/t-*.png
export XDG_RUNTIME_DIR=/tmp/xdg-flow WAYLAND_DISPLAY=wayland-1
S=$XDG_RUNTIME_DIR/flowde-shell.sock; P=~/flowde-shell-build/tools/send.py; O=~/flowde-shell-build/shots; mkdir -p $O
set_() { python3 $P $S "{\"set\":\"$1\",\"value\":\"$2\"}" >/dev/null; }
shot() { sleep ${W:-2.2}; grim $O/t-$1.png; }
set_ scheme dark
set_ screen lock;     shot lock
set_ screen home;     W=3.5 shot start
set_ screen edit;     shot edit
set_ screen apps;     shot apps
set_ screen alpha;    shot alpha
set_ screen centre;   shot centre
set_ open Photos;     shot app
set_ screen switcher; shot switcher
set_ open Settings;   shot app-settings
set_ screen search;   shot search
set_ screen home;     W=5 shot start-flip
