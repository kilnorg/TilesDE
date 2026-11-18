#!/usr/bin/env bash
# Round-trip check of the personalisation store through the control socket.
# Needs: a running flowde-shell whose Main.qml forwards unknown {"set":k,"value":v} to Personalise.command(k, v),
# started with TILESDE_CONFIG=<scratch file>. Usage: TILESDE_CONFIG=/tmp/theme.json [FLOWDE_SHELL_SOCKET=...] check-config.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CFG="${TILESDE_CONFIG:?set TILESDE_CONFIG to the scratch file the running shell uses}"
SOCK="${FLOWDE_SHELL_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/flowde-shell.sock}"
send() { python3 "$HERE/send.py" "$SOCK" "{\"set\":\"$1\",\"value\":$2}" >/dev/null; }
fail=0
check() { # key expected-json-literal
  local got; got="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get(sys.argv[2]),sort_keys=True))' "$CFG" "$1" 2>/dev/null)"
  if [ "$got" = "$2" ]; then echo "PASS $1 = $got"; else echo "FAIL $1: want $2 got $got"; fail=1; fi
}
send reset '"1"'
send preset '"classic"'; send scheme '"amoled"'; send accent '"teal"'; send opacity '"0.8"'; send radius '"12"'
send gap '"9"'; send columns '"3"'; send badges '"off"'; send flip '"2"'; send weight '"400"'; send case '"upper"'
send motion '"low"'; send addGroup '"Games"'; send tileColor '"mail=#ff00ff"'; send photo '"/tmp/x.jpg"'
send scheme '"neon"'; send columns '"5"'; send gap '"abc"'          # invalid: must not change anything
send flush '"1"'; sleep 0.3
check preset '"classic"'; check scheme '"amoled"'; check accent '"#12a594"'; check tileOpacity 0.8; check tileRadius 12
check gap 9; check columns 3; check badges false; check flipSpeed 2; check fontWeight 400; check titleCase '"upper"'
check motion '"low"'; check tileColors '{"mail": "#ff00ff"}'; check startPhoto '"/tmp/x.jpg"'
check groups '[{"collapsed": false, "name": "Productivity"}, {"collapsed": false, "name": "Explore"}, {"collapsed": false, "name": "Games"}]'
# reload from disk must reproduce the file
before="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$CFG")"
send reload '"1"'; send flush '"1"'; sleep 0.3
after="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$CFG")"
if [ "$before" = "$after" ]; then echo "PASS reload round-trip"; else echo "FAIL reload round-trip"; fail=1; fi
send reset '"1"'; send flush '"1"'
exit $fail
