#!/usr/bin/env python3
"""TilesDE window manager shim (sway). Keeps third-party app windows inside the phone shell window.

New non-shell toplevels are floated, borderless, and sized to the shell window content minus status bar (28 design px)
and nav bar (56 design px), so the TilesDE nav stays usable. One window is "shown"; the rest wait in the sway scratchpad.
State (polled by Main.qml): $XDG_RUNTIME_DIR/tiles-wm.json  {shown:<con_id>|0, wins:[{id,app_id,title}]}
Commands (one per line) to $XDG_RUNTIME_DIR/tiles-wm.fifo:  show <id> | hide | close <id> | closeall | replace
Only windows created after the daemon starts are adopted. Single instance (flock).
"""
import fcntl, json, os, subprocess, sys, threading, time

RT = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE, FIFO, LOCK = RT + "/tiles-wm.json", RT + "/tiles-wm.fifo", RT + "/tiles-wm.lock"
DESIGN_W, TOP, BOTTOM = 540.0, 28, 56
if not os.environ.get("SWAYSOCK"):
    import glob
    s = sorted(glob.glob(RT + "/sway-ipc.*.sock"))
    if s: os.environ["SWAYSOCK"] = s[0]

mu = threading.RLock()
wins = {}        # con_id -> {app_id,title}
hidden = set()   # ids parked in scratchpad
shown = 0
raise_timer = None

def sway(*a):
    return subprocess.run(["swaymsg", *a], capture_output=True, text=True).stdout

def walk(n):
    yield n
    for c in n.get("nodes", []) + n.get("floating_nodes", []):
        yield from walk(c)

def is_shell(n):
    return n.get("app_id") == "flowde-shell" or n.get("name") == "TilesDE"

def tree():
    try: return json.loads(sway("-t", "get_tree", "-r"))
    except Exception: return {}

def shell_rect():
    for n in walk(tree()):
        if is_shell(n) and n.get("pid"):
            r, w = n["rect"], n["window_rect"]      # content area = window_rect inside the decorated container
            return {"x": r["x"] + w["x"], "y": r["y"] + w["y"], "width": w["width"], "height": w["height"]}
    return None

def info(n):
    wp = n.get("window_properties") or {}
    return {"app_id": n.get("app_id") or wp.get("class") or "app", "title": n.get("name") or ""}

def save():
    d = {"shown": shown, "wins": [{"id": i, **w} for i, w in wins.items()]}
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f: json.dump(d, f)
    os.replace(tmp, STATE)

def place(i):
    r = shell_rect()
    if not r: return
    s = r["width"] / DESIGN_W
    top, bot = round(TOP * s), round(BOTTOM * s)
    sway(f"[con_id={i}] floating enable, border none, resize set {r['width']} {r['height'] - top - bot}, "
         f"move absolute position {r['x']} {r['y'] + top}")

def show(i):
    global shown
    with mu:
        if i not in wins: return
        if shown and shown != i: hide()
        if i in hidden:
            sway(f"[con_id={i}] scratchpad show"); hidden.discard(i)
        place(i); sway(f"[con_id={i}] focus"); shown = i; save()

def hide():
    global shown
    with mu:
        if shown in wins and shown not in hidden:
            sway(f"[con_id={shown}] move scratchpad"); hidden.add(shown)
        shown = 0; save()
    sway("[app_id=flowde-shell] focus")

def close(i):
    sway(f"[con_id={i}] kill")

def raise_shown():
    with mu:
        if shown and shown in wins: sway(f"[con_id={shown}] focus")

def on_event(e):
    global raise_timer, shown
    c, n = e.get("change"), e.get("container") or {}
    i = n.get("id")
    if c == "new" and not is_shell(n) and (n.get("app_id") or n.get("window_properties")):
        with mu:
            wins[i] = info(n)
        threading.Timer(0.25, lambda: (show(i), place(i))).start()   # app_id/title settle after map
    elif c in ("title",) and i in wins:
        with mu: wins[i] = info(n); save()
    elif c == "close" and i in wins:
        with mu:
            wins.pop(i, None); hidden.discard(i)
            if shown == i: shown = 0; sway("[app_id=flowde-shell] focus")
            save()
    elif c == "focus" and is_shell(n) and shown:
        # clicking the shell nav raises the shell over the app window; put the app back after the click completes
        if raise_timer: raise_timer.cancel()
        raise_timer = threading.Timer(0.3, raise_shown); raise_timer.start()

def commands():
    if not os.path.exists(FIFO): os.mkfifo(FIFO)
    fd = os.open(FIFO, os.O_RDWR)
    with os.fdopen(fd) as f:
        for line in f:
            p = line.split()
            if not p: continue
            try:
                if p[0] == "show": show(int(p[1]))
                elif p[0] == "hide": hide()
                elif p[0] == "close": close(int(p[1]))
                elif p[0] == "closeall":
                    for i in list(wins): close(i)
                elif p[0] == "replace" and shown: place(shown)
            except Exception as ex: print("cmd error", line, ex, file=sys.stderr)

def main():
    lk = open(LOCK, "w")
    try: fcntl.flock(lk, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: return
    save()
    threading.Thread(target=commands, daemon=True).start()
    while True:
        p = subprocess.Popen(["swaymsg", "-t", "subscribe", "-m", '["window"]'], stdout=subprocess.PIPE, text=True)
        for line in p.stdout:
            try: on_event(json.loads(line))
            except Exception as ex: print("event error", ex, file=sys.stderr)
        time.sleep(2)

if __name__ == "__main__": main()
