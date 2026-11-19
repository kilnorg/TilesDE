import QtQuick
import FlowShell

// Terminal (Termux-style): TermSession (forkpty + libvterm, see src/TermSession.h) rendered as one RichText Text per row.
// Up to 4 sessions (tabs). Input: a hidden TextInput holds focus so the shell's TilesKeyboard shows; committed text is
// forwarded as deltas (sentinel char keeps Backspace detectable), Enter arrives via accepted(). Extra-keys rows with sticky CTRL/ALT.
// Swipe = scrollback (alt screen: arrow keys), pinch = font size. Store key "terminal": { size }.
// Test hook: env FLOWDE_TERM_TEST="ls --color; echo done" is typed into the first session (see TermSession.h).
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    readonly property int maxTabs: 4
    readonly property string mono: "Liberation Mono"
    property int fontSize: 16
    property var sess: []              // [{term, ended, code}]
    property int cur: 0
    property int rev: 0                // bumped when per-session state changes
    property var term: null            // current TermSession
    property int scrollOff: 0          // lines scrolled back from the bottom
    property bool ctrlOn: false
    property bool altOn: false
    property bool menuOpen: false
    property bool blinkOn: true
    readonly property color fgC: Theme.text
    readonly property color bgC: Theme.pageBg
    onFgCChanged: applyTheme()
    onBgCChanged: applyTheme()
    readonly property real cw: charM.advanceWidth / 20
    readonly property real lh: Math.ceil(charM.height)
    readonly property var curSess: (rev >= 0 && sess.length > cur) ? sess[cur] : null

    TextMetrics { id: charM; font.family: root.mono; font.pixelSize: root.fontSize; font.hintingPreference: Font.PreferNoHinting; text: "MMMMMMMMMMMMMMMMMMMM" }
    Component { id: termComp; TermSession {} }

    // ------------------------------------------------------------ sessions
    function applyTheme() {
        for (var i = 0; i < sess.length; ++i) {
            var t = sess[i].term
            t.darkPalette = Theme.dark; t.defaultFg = fgC.toString(); t.defaultBg = bgC.toString()
        }
        refreshAll()
    }
    function addSession() {
        if (sess.length >= maxTabs) return
        var t = termComp.createObject(root, { darkPalette: Theme.dark, defaultFg: fgC.toString(), defaultBg: bgC.toString() })
        var s = { term: t, ended: false, code: 0 }
        t.finished.connect(function (c) { s.ended = true; s.code = c; root.rev++ })
        t.titleChanged.connect(function () { root.rev++ })
        sess = sess.concat([s])
        select(sess.length - 1)
        if (view.cols > 0) t.resize(view.cols, view.rows)
        t.start()
    }
    function closeSession() {
        if (sess.length === 0) return
        var s = sess[cur]
        var l = sess.slice(); l.splice(cur, 1)
        term = null
        sess = l
        s.term.stop(); s.term.destroy()
        if (sess.length === 0) { closeRequested(); return }
        select(Math.min(cur, sess.length - 1))
    }
    function select(i) {
        cur = i; term = sess[i].term; scrollOff = 0
        if (view.cols > 0) term.resize(view.cols, view.rows)
        refreshAll(); rev++
    }
    function restart() { var s = sess[cur]; s.ended = false; rev++; s.term.start(); refreshAll() }

    // ------------------------------------------------------------ rendering
    function lineFor(r) {
        if (!term) return ""
        var sb = term.scrollbackCount, v = sb - scrollOff + r
        return v < sb ? term.scrollbackLineHtml(v) : term.lineHtml(v - sb)
    }
    function refreshRows(a, b) {
        for (var r = a; r <= b && r < rowsRep.count; ++r) { var it = rowsRep.itemAt(r); if (it) it.html = lineFor(r) }
    }
    function refreshAll() { refreshRows(0, rowsRep.count - 1) }
    function setScroll(n) {
        n = Math.max(0, Math.min(term ? term.scrollbackCount : 0, n))
        if (n !== scrollOff) { scrollOff = n; refreshAll() }
    }
    Connections {
        target: root.term
        function onRowsDamaged(a, b) { if (root.scrollOff > 0) root.scrollOff = 0; root.refreshRows(a, b) }
        function onScreenReset() { root.scrollOff = 0; root.refreshAll() }
        function onCursorChanged() { root.blinkOn = true }
    }

    // ------------------------------------------------------------ input
    function mods() { return (ctrlOn ? Qt.ControlModifier : 0) | (altOn ? Qt.AltModifier : 0) }
    function clearMods() { ctrlOn = false; altOn = false }
    function key(k, m) { if (term) { term.sendKey(k, m === undefined ? mods() : m); clearMods() } }
    function typed(s) {
        if (!term || s.length === 0) return
        if (ctrlOn || altOn) {
            var ch = s.charAt(0), code = ch.toUpperCase().charCodeAt(0)
            key(code, mods())
            if (s.length > 1) term.write(s.substring(1))
        } else term.write(s)
    }
    function extra(id) {
        switch (id) {
        case "ESC": key(Qt.Key_Escape); break
        case "TAB": key(Qt.Key_Tab); break
        case "CTRL": ctrlOn = !ctrlOn; break
        case "ALT": altOn = !altOn; break
        case "UP": key(Qt.Key_Up); break
        case "DOWN": key(Qt.Key_Down); break
        case "LEFT": key(Qt.Key_Left); break
        case "RIGHT": key(Qt.Key_Right); break
        case "HOME": key(Qt.Key_Home); break
        case "END": key(Qt.Key_End); break
        case "PGUP": key(Qt.Key_PageUp); break
        case "PGDN": key(Qt.Key_PageDown); break
        case "KBD": if (input.activeFocus) input.focus = false; else input.forceActiveFocus(); break
        default: typed(id)
        }
    }
    function showKeyboard() { input.focus = false; input.forceActiveFocus() }   // toggling re-arms the shell's OSK
    function paste() { clip.text = ""; clip.paste(); if (term && clip.text.length) term.write(clip.text); clip.text = "" }
    function copyScreen() { if (!term) return; clip.text = term.screenText(); clip.selectAll(); clip.copy(); clip.text = "" }
    function setFont(sz) { fontSize = Math.max(8, Math.min(40, sz)); AppStore.save("terminal", { size: fontSize }) }

    TextEdit { id: clip; visible: false }
    TextInput {
        id: input
        readonly property string sent: "​"
        property bool busy: false
        x: 0; y: 0; width: 1; height: 1; opacity: 0
        text: sent
        cursorPosition: 1
        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData
        function reset() { busy = true; text = sent; cursorPosition = 1; busy = false }
        onTextChanged: {
            if (busy || text === sent) return
            if (text.indexOf(sent) < 0) { root.key(Qt.Key_Backspace, 0) }     // sentinel eaten = Backspace
            else root.typed(text.replace(sent, ""))
            reset()
        }
        onCursorPositionChanged: if (!busy && text === sent && cursorPosition !== 1) reset()
        onAccepted: { root.key(Qt.Key_Return, 0); reset() }
        Keys.onPressed: (e) => {                 // hardware keys + anything the soft keyboard sends as key events
            var k = e.key, m = e.modifiers | root.mods()
            var special = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End, Qt.Key_PageUp, Qt.Key_PageDown,
                           Qt.Key_Insert, Qt.Key_Delete, Qt.Key_Tab, Qt.Key_Backtab, Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Backspace]
            var isF = k >= Qt.Key_F1 && k <= Qt.Key_F12
            var combo = (m & (Qt.ControlModifier | Qt.AltModifier)) && k >= 0x20 && k < 0x7f
            if (special.indexOf(k) >= 0 || isF || combo) { root.term && root.term.sendKey(k, m); root.clearMods(); e.accepted = true }
        }
    }
    Component.onCompleted: {
        var st = AppStore.load("terminal", {})
        if (st && typeof st.size === "number") fontSize = Math.max(8, Math.min(40, st.size))
        addSession()
        Qt.callLater(function () { input.forceActiveFocus() })
    }
    Component.onDestruction: { for (var i = 0; i < sess.length; ++i) sess[i].term.stop() }

    focus: true
    function back() { if (menuOpen) menuOpen = false; else closeRequested() }
    Keys.onBackPressed: back()

    // ------------------------------------------------------------ top strip
    Item {
        id: strip
        anchors { top: parent.top; topMargin: root.topInset; left: parent.left; right: parent.right }
        height: 40
        Row {
            id: tabs
            anchors { left: parent.left; leftMargin: Theme.pageMargin / 2; verticalCenter: parent.verticalCenter }
            spacing: 6
            Repeater {
                model: root.sess.length
                Rectangle {
                    width: 28; height: 28
                    color: index === root.cur ? Theme.accent : "transparent"
                    border.width: 2; border.color: index === root.cur ? Theme.accent : Theme.textDim
                    Text { anchors.centerIn: parent; text: index + 1; font.pixelSize: 15; color: index === root.cur ? Theme.onColor(Theme.accent) : Theme.text }
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.select(index) }
                }
            }
            Rectangle {
                visible: root.sess.length < root.maxTabs
                width: 28; height: 28; color: "transparent"
                Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 24; color: Theme.text }
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.addSession() }
            }
        }
        Text {
            anchors { left: tabs.right; leftMargin: 12; right: dots.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: root.rev >= 0 && root.term && root.term.title ? root.term.title : "terminal"
            elide: Text.ElideRight; font.pixelSize: 15; color: Theme.textDim
        }
        Text {
            id: dots
            anchors { right: parent.right; rightMargin: Theme.pageMargin; verticalCenter: parent.verticalCenter }
            text: "..."; font.pixelSize: 24; font.bold: true; color: Theme.text
            MouseArea { anchors.fill: parent; anchors.margins: -14; onClicked: root.menuOpen = !root.menuOpen }
        }
    }

    // ------------------------------------------------------------ extra keys
    readonly property var keyRows: [["ESC", "TAB", "CTRL", "ALT", "-", "/", "~", "|", "KBD"],
                                    ["UP", "DOWN", "LEFT", "RIGHT", "HOME", "END", "PGUP", "PGDN"]]
    readonly property var glyph: ({ UP: "↑", DOWN: "↓", LEFT: "←", RIGHT: "→", KBD: "⌨" })
    Column {
        id: extras
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        spacing: 2
        Repeater {
            model: root.keyRows
            Row {
                spacing: 2
                width: extras.width
                readonly property var ids: modelData
                Repeater {
                    model: ids
                    Rectangle {
                        readonly property bool sticky: (modelData === "CTRL" && root.ctrlOn) || (modelData === "ALT" && root.altOn)
                        width: (extras.width - (ids.length - 1) * 2) / ids.length; height: 44
                        color: sticky ? Theme.accent : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
                        Text {
                            anchors.centerIn: parent
                            text: root.glyph[modelData] || modelData
                            font.pixelSize: modelData.length > 2 ? 14 : 18
                            color: parent.sticky ? Theme.onColor(Theme.accent) : Theme.text
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.extra(modelData) }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ terminal view
    Item {
        id: view
        anchors { top: strip.bottom; bottom: extras.top; bottomMargin: 2; left: parent.left; right: parent.right }
        clip: true
        readonly property int cols: Math.max(2, Math.floor(width / root.cw))
        readonly property int rows: Math.max(2, Math.floor(height / root.lh))
        onColsChanged: sizer.restart()
        onRowsChanged: sizer.restart()
        Connections { target: root; function onCwChanged() { sizer.restart() } function onLhChanged() { sizer.restart() } }
        Timer {
            id: sizer; interval: 80
            onTriggered: if (root.term) root.term.resize(view.cols, view.rows)
        }
        Column {
            Repeater {
                id: rowsRep
                model: view.rows
                Text {
                    property string html: root.lineFor(index)
                    width: view.width; height: root.lh
                    text: html
                    textFormat: Text.RichText
                    wrapMode: Text.NoWrap
                    lineHeightMode: Text.FixedHeight; lineHeight: root.lh
                    font.family: root.mono; font.pixelSize: root.fontSize; font.hintingPreference: Font.PreferNoHinting
                    color: Theme.text
                    Component.onCompleted: html = root.lineFor(index)
                }
            }
        }
        Rectangle {     // cursor
            visible: root.term && root.term.cursorVisible && root.scrollOff === 0 && root.blinkOn && !(root.curSess && root.curSess.ended)
            x: root.term ? root.term.cursorCol * root.cw : 0
            y: root.term ? root.term.cursorRow * root.lh : 0
            width: root.cw; height: root.lh
            color: Theme.accent; opacity: 0.7
        }
        Timer {
            interval: 530; repeat: true; running: !Theme.reduceMotion && root.term !== null
            onTriggered: root.blinkOn = !root.blinkOn
        }
        // scroll: scrollback on the main screen, arrow keys on the alt screen
        DragHandler {
            id: drag
            target: null; xAxis.enabled: false
            minimumPointCount: 1; maximumPointCount: 1
            property int done: 0
            onActiveChanged: if (active) done = 0
            onTranslationChanged: {
                if (!active || !root.term) return
                var n = Math.round(translation.y / root.lh), d = n - done
                if (d === 0) return
                done = n
                if (root.term.altScreen) {
                    for (var i = 0; i < Math.abs(d); ++i) root.term.sendKey(d > 0 ? Qt.Key_Up : Qt.Key_Down, 0)
                } else root.setScroll(root.scrollOff + d)
            }
        }
        PinchHandler {
            id: pinch
            target: null
            property int base: 16
            onActiveChanged: if (active) base = root.fontSize
            onActiveScaleChanged: if (active) root.setFont(Math.round(base * activeScale))
        }
        TapHandler { onTapped: { root.menuOpen = false; root.showKeyboard() } }
        // process ended
        Rectangle {
            visible: root.curSess !== null && root.curSess.ended
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 56; color: Theme.pageBg
            border.width: 1; border.color: Theme.textDim
            Text {
                anchors.centerIn: parent; color: Theme.text; font.pixelSize: 15
                text: "[process exited " + (root.curSess ? root.curSess.code : 0) + " - tap to restart]"
            }
            MouseArea { anchors.fill: parent; onClicked: root.restart() }
        }
    }

    // ------------------------------------------------------------ menu
    MouseArea { anchors.fill: parent; visible: root.menuOpen; z: 5; onClicked: root.menuOpen = false }
    Rectangle {
        id: menu
        visible: root.menuOpen; z: 6
        anchors { top: strip.bottom; right: parent.right; rightMargin: Theme.pageMargin / 2 }
        width: 230; height: menuCol.height
        color: Theme.pageBg; border.width: 1; border.color: Theme.textDim
        Column {
            id: menuCol; width: parent.width
            Repeater {
                model: [{ t: "new session", a: "new" }, { t: "close session", a: "close" }, { t: "font +", a: "inc" },
                        { t: "font -", a: "dec" }, { t: "paste", a: "paste" }, { t: "copy visible screen", a: "copy" }, { t: "open foot", a: "foot" }]
                Item {
                    width: menuCol.width; height: 48
                    Text { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: modelData.t; font.pixelSize: 18; color: Theme.text }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var keep = modelData.a === "inc" || modelData.a === "dec"
                            if (!keep) root.menuOpen = false
                            switch (modelData.a) {
                            case "new": root.addSession(); break
                            case "close": root.closeSession(); break
                            case "inc": root.setFont(root.fontSize + 1); break
                            case "dec": root.setFont(root.fontSize - 1); break
                            case "paste": root.paste(); break
                            case "copy": root.copyScreen(); break
                            case "foot": Sys.launch("foot", []); break
                            }
                        }
                    }
                }
            }
        }
    }
}
