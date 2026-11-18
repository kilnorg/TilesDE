#!/usr/bin/env bash
# VM: Wave 2 screenshots. Drives the running shell over its socket and grims each state to ~/flowde-shell-build/shots/w2-*.png
# Usage: bash ~/flowde-shell-build/tools/w2-shots.sh [name ...]   (no args = all)
export XDG_RUNTIME_DIR=/tmp/xdg-flow WAYLAND_DISPLAY=wayland-1
S=$XDG_RUNTIME_DIR/flowde-shell.sock; P=~/flowde-shell-build/tools/send.py; O=~/flowde-shell-build/shots; mkdir -p $O
set_() { python3 $P $S "{\"set\":\"$1\",\"value\":\"$2\"}" >/dev/null; }
shot() { sleep ${W:-${SLOW:-4}}; grim $O/w2-$1.png; }
want() { [ -z "$ARGS" ] && return 0; for a in $ARGS; do [ "$a" = "$1" ] && return 0; done; return 1; }
ARGS="$*"
start() { set_ reset 1; set_ preset $1; set_ scheme $2; set_ screen home; W=${SLOW:-5} shot start-$1-$2; }
want start && { start glaze dark; start glaze amoled; start classic dark; start classic light; start mono amoled; }
set_ reset 1; set_ preset glaze; set_ scheme dark
want edit && { set_ screen home; set_ select mail; W=${SLOW:-5} shot edit-sheet; set_ closesheet 1; set_ screen home; }
want groups && { set_ screen home; set_ toggleGroup 0; set_ toggleGroup 1; shot groups-collapsed; set_ toggleGroup 0; set_ toggleGroup 1; }
want settings && {
  set_ screen settings; W=${SLOW:-5} shot settings-home
  set_ settings start+theme; W=${SLOW:-5} shot settings-theme
  set_ scroll 700; shot settings-theme-scrolled
  set_ scroll end; shot settings-theme-end
  set_ settings home; set_ settings "lock screen"; W=${SLOW:-5} shot settings-lock
  set_ settings home; set_ settings notifications; W=${SLOW:-5} shot settings-notifications
  set_ settings home; set_ settings battery; W=${SLOW:-5} shot settings-battery
  set_ settings close
}
want chrome && {
  set_ screen apps; shot allapps
  set_ screen centre; shot centre
  set_ screen lock; shot lock
  set_ screen controls; shot controls
  set_ screen home
}
