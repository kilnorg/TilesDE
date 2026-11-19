import QtQuick
import QtQuick.Window
import FlowShell
import "apps/index.js" as NativeApps

Window {
    id: win
    visible: true
    // FLOWDE_SIZE=WxH sets the window size; the UI keeps its 540 px design width and scales to fit.
    width: StartSize.width; height: StartSize.height
    color: "black"
    title: "TilesDE"

    // "lock" | "home" | "switcher" | "app"
    property var openApps: []
    property string appName: ""
    property rect appRect: Qt.rect(240, 560, 62, 62)
    property bool appLaunching: false
    property bool appDrag: false
    property bool appSwipe: false      // left-edge back swipe in progress (finger drives appP)
    property real appP: 0
    // response ~0.4 s, damping ratio ~0.85 (see docs/mobile-motion.md)
    Behavior on appP { enabled: !win.appDrag && !win.appSwipe && !Theme.reduceMotion; SpringAnimation { spring: 4.2; damping: 0.38; epsilon: 0.001; mass: 1 } }
    // Starts on touch-up, never waits for the app: one progress value (appP) drives the shared element.
    function openApp(name, rect, launching) {
        if (name === "Settings") { openSettings(""); return }
        wmSend("from " + Math.round(rect.x) + " " + Math.round(rect.y) + " " + Math.round(rect.width) + " " + Math.round(rect.height))
        // installed (third-party) app: start it through the app model; its window is placed by tiles-wm
        if (NativeApps.source(name) === "" && !launching && typeof Apps !== "undefined" && Apps) {
            for (let i = 0; i < Apps.count; i++) {
                const a = Apps.get(i)
                if (a && a.name === name) {
                    if (extPick(name)) return
                    Apps.launch(i); launching = true
                    break
                }
            }
        }
        if (openApps.indexOf(name) < 0) openApps = openApps.concat([name])
        appName = name; appRect = rect; appLaunching = !!launching; shadeP = 0; page = "app"
        if (launching) launchTimer.restart()
    }
    // Settings app: full-screen layer above apps, below the status bar. "" keeps its current page.
    property bool settingsOpen: false
    property string overlay: ""        // "" | "controls"
    function openSettings(name) {
        shadeP = 0; home.searchOpen = false; overlay = ""
        if (page === "lock") page = "home"
        settingsOpen = true
        if (name !== "") settings.open(name)
        settings.forceActiveFocus()
    }
    function closeSettings() { settingsOpen = false; settings.goHome(true) }
    // first vertical Flickable on screen inside item (the visible pivot page)
    function _vflick(item) {
        for (let i = 0; i < item.children.length; ++i) {
            const c = item.children[i]
            if (!c.visible) continue
            if (c.flickableDirection === Flickable.VerticalFlick && c.contentHeight !== undefined) {
                const pt = c.mapToItem(root, 0, 0)
                if (pt.x > -10 && pt.x < root.width / 2) return c
            }
            const r = _vflick(c); if (r) return r
        }
        return null
    }
    function scrollSettings(v) {
        const f = _vflick(settingsOpen ? settings : root); if (!f) return false
        const max = Math.max(0, f.contentHeight - f.height)
        f.contentY = v === "end" ? max : v === "top" ? 0 : Math.max(0, Math.min(max, Number(v)))
        return true
    }
    // Third-party app windows (firefox, foot, ...): tools/tiles-wm.py keeps them inside this window and writes its state to
    // $XDG_RUNTIME_DIR/tiles-wm.json; commands go to its fifo. extShown = sway con_id of the visible one (0 = none).
    property var extWins: []
    property int extShown: 0
    property string wmScript: {
        const c = [Sys.home() + "/flowde-shell-build/tools/tiles-wm.py", "/usr/share/tilesde/tiles-wm.py"]
        for (const f of c) if (Sys.exists(f)) return f
        return ""
    }
    function wmSend(cmd) { Sys.launch("sh", ["-c", 'echo "$0" > "${XDG_RUNTIME_DIR:-/run/user/1000}/tiles-wm.fifo"', cmd]) }
    readonly property var extNames: extWins.map(w => w._n)
    function extPick(name) { const w = extWins.find(o => o._n === name); if (w) wmSend("show " + w.id); return !!w }
    Timer {
        interval: 400; repeat: true; running: win.wmScript !== ""
        onTriggered: {
            const t = Sys.readText(Sys.runtimeDir() + "/tiles-wm.json", 65536)
            if (t === "" || t === win._extRaw) return
            win._extRaw = t
            try {
                const d = JSON.parse(t)
                const l = d.wins; for (let i = 0; i < l.length; ++i) l[i]._n = l[i].app_id.charAt(0).toUpperCase() + l[i].app_id.slice(1)
                const seen = {}
                for (const w of l) { if (seen[w._n]) w._n += " " + w.id; seen[w._n] = 1 }
                const was = win.extShown
                win.extWins = l; win.extShown = d.shown
                if (d.shown > 0 && was !== d.shown && win.page === "lock") win.page = "home"
                if (d.shown > 0 && win.appLaunching) { launchTimer.stop(); win.appLaunching = false; win.openApps = win.openApps.filter(x => x !== win.appName) }
                if (d.shown > 0) { win.shadeP = 0; win.page = win.page === "switcher" ? "home" : win.page }
            } catch (e) {}
        }
    }
    property string _extRaw: ""
    Timer { id: launchTimer; interval: 8000; onTriggered: if (win.appLaunching) win.gesture("home") }
    
    property string page: ["shade","centre","search","apps","edit","alpha"].indexOf(StartPage) >= 0 ? "home" : StartPage
    property real lockP: StartPage === "lock" ? 0 : 1
    property real shadeP: StartPage === "shade" ? 1 : 0
    property real switchP: StartPage === "switcher" ? 1 : 0
    onPageChanged: { lockP = page === "lock" ? 0 : 1; switchP = page === "switcher" ? 1 : 0; appP = page === "app" ? 1 : 0 }

    Behavior on lockP { enabled: !lockDrag.active && !Theme.reduceMotion; SpringAnimation { spring: 3.2; damping: 0.32; epsilon: 0.002; mass: 1; modulus: 0 } }
    Behavior on shadeP { enabled: !shadeDrag.active && !shadeCloseDrag.active && !Theme.reduceMotion; SpringAnimation { spring: 3.4; damping: 0.3; epsilon: 0.002 } }
    Behavior on switchP { enabled: !Theme.reduceMotion; SpringAnimation { spring: 3.2; damping: 0.32; epsilon: 0.002 } }

    Component.onCompleted: {
        if (wmScript !== "") Sys.launch("python3", [wmScript])
        Theme.select(StartTheme)
        Theme.dark = StartDark
        Theme.backdrop = bsrc
        Theme.backdropItem = wall
        Theme.glass = Services.glassQuality
        Theme.reduceTransparency = Services.reduceTransparency
        Theme.reduceMotion = Services.reduceMotion
        Qt.callLater(win.applyStart)
    }
    function applyStart() {
        if (StartPage === "search") home.searchOpen = true
        else if (StartPage === "apps") home.showApps()
        else if (StartPage === "edit") home.start.enterEdit()
        else if (StartPage === "alpha") { home.showApps(); home.allApps.alpha.open = true }
    }
    function screenCmd(v) {
        if (v === "settings") { openSettings("home"); return }
        if (v === "settings-theme") { openSettings("start+theme"); return }
        if (v === "settings-lock") { openSettings("lock screen"); return }
        if (v === "groups") { openSettings("start+theme"); scrollLater.restart(); return }
        if (v === "controls") { settingsOpen = false; shadeP = 0; if (page === "lock") page = "home"; overlay = "controls"; return }
        if (v.indexOf("settings-") === 0) { openSettings(v.substring(9)); return }
        settingsOpen = false; overlay = ""
        home.searchOpen = false; home.allApps.closeOverlays()
        if (v !== "edit" && home.start.editing) home.start.exitEdit()
        if (v === "shade" || v === "centre") { shadeP = 1; return }
        shadeP = 0
        if (v === "search") { page = "home"; home.showStart(); home.searchOpen = true }
        else if (v === "apps") { page = "home"; home.showApps() }
        else if (v === "alpha") { page = "home"; home.showApps(); home.allApps.alpha.open = true }
        else if (v === "edit") { page = "home"; home.showStart(); home.start.enterEdit() }
        else if (v === "home") { page = "home"; home.showStart() }
        else page = v
    }
    Connections {
        target: Services
        function onChanged() {
            Theme.glass = Services.glassQuality
            Theme.reduceTransparency = Services.reduceTransparency
            Theme.reduceMotion = Services.reduceMotion
        }
        function onGesture(name) { win.gesture(name) }
        // Keys: theme, open, screen, settings (page name|back|home), scroll (px|top|end), get (config|<key>),
        // Start keys (select closesheet tilesize unpintile tilepicture tilelabel), else Personalise.command
        // (preset scheme accent amoled gap radius opacity columns labels badges grain flip weight case motion photo reset ...).
        function onCommand(k, v) {
            if (k === "theme") Theme.select(v)
            else if (k === "open") win.openApp(v, Qt.rect(root.width / 2 - 31, root.height * 0.2, 62, 62), false)
            else if (k === "screen") win.screenCmd(v)
            else if (k === "settings") { if (v === "back") settings.back(); else if (v === "close") win.closeSettings(); else win.openSettings(v) }
            else if (k === "scroll") win.scrollSettings(v)
            else if (k === "shot") win.contentItem.grabToImage(function(r) { r.saveToFile(v) })   // test hook: PNG of the window
            else if (k === "get") Services.send(JSON.stringify({ get: v, value: (v === "config" || v === "all" || v === "") ? Personalise.toMap() : Personalise.get(v) }))
            else if (["select", "closesheet", "tilesize", "unpintile", "tilepicture", "tilelabel"].indexOf(k) >= 0) home.start.command(k, v)
            else if (["glass", "reduceTransparency", "reduceMotion"].indexOf(k) >= 0) return
            else if (!Personalise.command(k, String(v))) console.info("tilesde: unknown or invalid command", k, v)
        }
    }

    // on-screen keyboard: shown while a text field has focus (TilesKeyboard types into that field)
    readonly property Item focusTarget: {
        const f = win.activeFocusItem
        return (f && typeof f.cursorPosition === "number" && typeof f.insert === "function" && !f.readOnly) ? f : null
    }
    property bool oskDismissed: false
    onFocusTargetChanged: oskDismissed = false
    // keyboard belongs to the app when the focused field lives inside it: it rides the app frame off screen
    function inApp(it) { while (it) { if (it === appPage) return true; it = it.parent } return false }
    readonly property bool kbInApp: focusTarget !== null && inApp(focusTarget)
    onAppPChanged: if (appP < 0.01 && page !== "app" && kbInApp) win.contentItem.forceActiveFocus()

    function gesture(name) {
        if (extShown > 0 && name !== "back") wmSend("hide")          // app windows stay running, listed in the switcher
        if (name === "back") { if (page !== "lock" || kb.shown || shadeP > 0.5) backStack(); return }
        if (page === "lock" && name !== "shade" && name !== "qs") return
        if (overlay !== "" && name === "home") { overlay = ""; return }
        if (settingsOpen && (name === "home" || name === "switcher")) closeSettings()
        if (name === "home") {
            shadeP = 0; home.searchOpen = false; home.allApps.closeOverlays()
            const wasStart = (page === "home" && home.pagerP < 0.5 && !home.start.editing)
            if (page === "home") home.start.exitEdit()
            page = "home"; home.showStart()
            if (wasStart) home.start.scrollTop()
        }
        else if (name === "switcher") { shadeP = 0; page = "switcher" }
        else if (name === "shade" || name === "qs") shadeP = 1
        else if (name === "search") { shadeP = 0; page = "home"; home.searchOpen = !home.searchOpen }
    }
    // Back: the first closer that has something to close consumes the gesture (topmost layer first).
    function backStack() {
        const closers = [
            () => { if (extShown <= 0) return false; wmSend("close " + extShown); return true },             // third-party window
            () => { if (!kb.shown) return false; oskDismissed = true; return true },                          // keyboard
            () => { if (shadeP <= 0.5) return false; shadeP = 0; return true },                              // shade / quick settings
            () => { if (overlay === "") return false; overlay = ""; return true },                           // overlay (controls gallery)
            () => { if (!settingsOpen) return false; settings.back(); return true },                         // settings pages
            () => page === "app" && appPage.systemBack(),                                                    // app inner view
            () => { if (page !== "app") return false; page = "home"; return true },                          // app
            () => { if (page !== "switcher") return false; page = "home"; return true },                     // switcher
            () => page === "home" && home.goBack()                                                           // search / apps / edit
        ]
        for (const close of closers) if (close()) return true
        return false
    }

    Timer { id: scrollLater; interval: Theme.turnstileMs + 400; onTriggered: win.scrollSettings("end") }

    Item {
        id: root
        // design width 540; height follows the window aspect
        width: 540; height: Math.round(win.height * 540 / Math.max(1, win.width))
        scale: win.width / 540; transformOrigin: Item.TopLeft
        Wallpaper { id: wall; anchors.fill: parent; visible: win.lockP < 0.995 }
        Rectangle { anchors.fill: parent; color: "black"; opacity: win.lockP }
        // one shared, quarter-resolution snapshot of the wallpaper feeds every glass panel
        ShaderEffectSource {
            id: bsrc
            sourceItem: wall; live: false; visible: false
            width: root.width; height: root.height
            textureSize: Qt.size(Math.max(1, root.width / 4), Math.max(1, root.height / 4))
            smooth: true
            Timer { interval: 1500; running: !Theme.reduceMotion && Theme.quality < 2; repeat: true; onTriggered: bsrc.scheduleUpdate() }
            Connections { target: Theme; function onWallpaperSourceChanged() { Qt.callLater(bsrc.scheduleUpdate) } function onNameChanged() { Qt.callLater(bsrc.scheduleUpdate) } function onDarkChanged() { Qt.callLater(bsrc.scheduleUpdate) } }
            Timer { interval: 400; running: true; onTriggered: bsrc.scheduleUpdate() }
        }

        HomeScreen {
            id: home
            anchors.fill: parent
            anchors.topMargin: 0
            scale: Theme.tiles ? (1 - 0.06 * win.appP) : (0.96 + 0.04 * win.lockP * (1 - win.switchP * 0.6)) * (1 - 0.06 * win.appP)
            topInset: 28; bottomInset: 56; kbH: kb.visibleH
            opacity: win.page === "switcher" ? 0.0 : 1      // lock screen is opaque and slides off, revealing this
            transform: Translate { x: win.appDrag ? 0 : -0.3 * root.width * win.appP }   // shifts left under a sliding app page
            // hidden under a full-screen Settings/controls layer: 3D tile flips otherwise poke through it
            visible: win.overlay === "" && !(win.settingsOpen && settings.opacity > 0.99)
            dim: 0.28 * win.appP
            onLaunched: (n, r, real) => win.openApp(n, r, real)
            Connections { target: home.allApps; function onSearchRequested() { win.gesture("search") } }
        }
        AppSwitcher {
            anchors.fill: parent
            opacity: win.switchP
            scale: 0.9 + 0.1 * win.switchP
            running: win.openApps.concat(win.extNames)
            onPicked: (n) => { if (!win.extPick(n)) win.openApp(n, Qt.rect(root.width / 2 - 31, root.height / 2 - 31, 62, 62), false) }
            onClosedAll: { win.openApps = []; win.wmSend("closeall"); win.page = "home" }
            onClosedOne: (n) => { const w = win.extWins.find(o => o._n === n); if (w) win.wmSend("close " + w.id); else win.openApps = win.openApps.filter(x => x !== n) }
        }
        AppPage { id: appPage; anchors.fill: parent; name: win.appName; from: win.appRect; p: win.appP; sw: root.width; sh: root.height; launching: win.appLaunching; kbH: kb.visibleH; z: 15; shrink: win.appDrag; onBack: win.gesture("home") }
        SettingsApp {
            id: settings
            anchors.fill: parent; anchors.bottomMargin: 56 + kb.visibleH; z: 16
            topInset: 36
            visible: opacity > 0.01
            enabled: win.settingsOpen
            opacity: win.settingsOpen ? 1 : 0
            scale: win.settingsOpen ? 1 : 0.94
            Behavior on opacity { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
            Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
            onClosed: win.closeSettings()
        }
        Rectangle {
            anchors.fill: parent; z: 17; color: Theme.pageBg
            visible: win.overlay === "controls"
            Loader { anchors.fill: parent; anchors.topMargin: 36; anchors.bottomMargin: 56; active: parent.visible; sourceComponent: ControlsGallery {} }
        }
        LockScreen { id: lock; anchors.fill: parent; progress: win.lockP }

        // left-edge back swipe: current page follows the finger, the previous one peeks beneath
        EdgeBackGesture {
            id: edgeBack
            z: 18; span: root.width
            anchors { left: parent.left; top: parent.top; topMargin: 60; bottom: parent.bottom; bottomMargin: 56 }
            enabled: win.overlay === "" && win.shadeP < 0.05 && !kb.shown && win.lockP > 0.9
                     && (win.settingsOpen ? settings.depth > 1 : win.page === "app")
            onMoved: (f) => { if (win.settingsOpen) settings.dragBack(f); else { win.appSwipe = true; win.appP = 1 - f } }
            onFinished: (commit) => {
                if (win.settingsOpen) { settings.endBack(commit); return }
                win.appSwipe = false
                if (commit && !appPage.systemBack()) win.gesture("home")
                else if (win.page === "app") win.appP = 1       // cancelled, or the app closed an inner view instead
            }
        }

        // lock: swipe up. Full-size pickable layer so the home screen underneath never takes the touch.
        Item {
            anchors.fill: parent; z: 19
            visible: win.page === "lock"
            DragHandler {
                id: lockDrag
                enabled: win.page === "lock"
                target: null; xAxis.enabled: false; dragThreshold: 4
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                // lock screen follows the finger 1:1 (LockScreen.y = -progress * height)
                onTranslationChanged: if (active) win.lockP = Math.max(0, Math.min(1, -translation.y / root.height))
                onActiveChanged: if (!active) {
                    if (win.lockP > 0.25 || centroid.velocity.y < -900) win.page = "home"
                    else { win.page = "lock"; win.lockP = 0 }
                }
            }
        }

        StatusBar { id: sbar; anchors { top: parent.top; left: parent.left; right: parent.right } z: 20; ink: win.lockP < 0.5 ? "white" : Theme.text }
        // top-edge pull for shade
        Item {
            z: 21; anchors { top: parent.top; left: parent.left; right: parent.right } height: 44
            DragHandler {
                id: shadeDrag
                target: null; xAxis.enabled: false
                onTranslationChanged: if (active) win.shadeP = Math.max(0, Math.min(1, translation.y / (root.height * 0.4)))
                onActiveChanged: if (!active) win.shadeP = win.shadeP > 0.3 ? 1 : 0
            }
        }
        Shade {
            id: shade; z: 30
            width: parent.width; height: parent.height
            progress: win.shadeP
            onOpenSettings: win.openSettings("home")
            onLockRequested: { win.shadeP = 0; win.page = "lock"; win.lockP = 0 }
            // swipe up on shade closes it
            DragHandler {
                id: shadeCloseDrag
                target: null; xAxis.enabled: false
                onTranslationChanged: if (active) win.shadeP = Math.max(0, Math.min(1, 1 + translation.y / (root.height * 0.4)))
                onActiveChanged: if (!active) win.shadeP = win.shadeP > 0.7 ? 1 : 0
            }
        }
        // status bar above shade too
        StatusBar { anchors { top: parent.top; left: parent.left; right: parent.right } z: 40; visible: win.shadeP > 0.01; ink: Theme.text }
        TilesKeyboard {
            id: kb; z: 45
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 56 }
            target: win.focusTarget
            shown: win.focusTarget !== null && !win.oskDismissed && win.lockP > 0.9
            onHideRequested: win.oskDismissed = true
            transform: Translate { y: win.kbInApp ? Math.max(0, Math.min(1, 1 - win.appP)) * (kb.height + 56) : 0 }
        }
        NavBar {
            z: 50; anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            visible: win.lockP > 0.9
            ink: Theme.text
            onBack: win.gesture("back")
            onBackHeld: win.gesture("switcher")
            onHome: win.gesture("home")
            onSearch: win.gesture("search")
            onDragged: (dy) => { if (win.page === "app") { win.appDrag = true; win.appP = Math.max(0.15, Math.min(1, 1 - dy / (root.height * 0.6))) } }
            onReleased: (dy, vy) => {
                if (win.page === "app") {
                    win.appDrag = false
                    if (dy > root.height * 0.4) win.gesture("switcher")
                    else if (dy > 70 || vy < -900) win.gesture("home"); else win.appP = 1
                } else if (dy > 60) { (dy > root.height * 0.4 || vy >= -900) ? win.gesture("switcher") : win.gesture("home") }
            }
        }
    }
}
