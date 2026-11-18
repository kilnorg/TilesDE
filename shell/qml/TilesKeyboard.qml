import QtQuick
import FlowShell

// TilesKeyboard: on-screen keyboard in the Tiles (Windows Phone) look on a pure black panel.
// Key placement follows Gboard (number row, QWERTY, shift/backspace row, ?123 / , / space / . / enter).
//
//   target   : the TextInput / TextEdit that receives the keys (null = hidden)
//   shown    : true while the keyboard should be up (Main sets it from the focused item)
//   visibleH : animated height currently on screen (use it to lift content above the keyboard)
//   numberRow: true = permanent 1..0 row (default)
//   signal hideRequested : the user tapped the collapse chevron
//
// Features: shift (tap = once, double tap = caps lock, auto capital at sentence start), key preview bubble,
// long-press accent / symbol alternates (drag to pick, release to commit), backspace repeat, space-bar
// cursor drag, symbols page 1 and 2, numeric pad for ImhDigitsOnly / ImhFormattedNumbersOnly fields,
// enter emits accepted() on TextInput. Colours come from Theme (dark, AMOLED, light, accent).
Item {
    id: root
    property Item target: null
    property bool shown: false
    property bool numberRow: true
    readonly property real visibleH: height * p
    property real p: shown ? 1 : 0
    signal hideRequested

    readonly property real keyH: 58
    readonly property real barH: 30
    readonly property int pad: 3
    readonly property int rowCount: layoutRows.length
    height: barH + rowCount * keyH + pad * 2
    visible: p > 0.001
    transform: Translate { y: (1 - root.p) * root.height }
    Behavior on p { enabled: !Theme.reduceMotion
        NumberAnimation { duration: root.shown ? 240 : 180; easing.type: root.shown ? Easing.OutCubic : Easing.InCubic } }

    // ---- state ----
    property string kbLayer: "abc"          // abc | sym | sym2 | num
    property string shiftState: "off"     // off | once | lock
    readonly property bool numeric: target && (target.inputMethodHints & (Qt.ImhDigitsOnly | Qt.ImhFormattedNumbersOnly | Qt.ImhDialableCharactersOnly)) !== 0
    readonly property bool autoCap: target && !(target.inputMethodHints & (Qt.ImhNoAutoUppercase | Qt.ImhLowercaseOnly | Qt.ImhEmailCharactersOnly | Qt.ImhUrlCharactersOnly | Qt.ImhSensitiveData))
    onTargetChanged: {
        kbLayer = numeric ? "num" : "abc"
        shiftState = "off"
        _autoCapitalise()
    }

    // ---- layouts: tokens; "@x" = special, "@pad" = half-key spacer ----
    readonly property var layouts: ({
        abc: [
            ["1","2","3","4","5","6","7","8","9","0"],
            ["q","w","e","r","t","y","u","i","o","p"],
            ["@pad","a","s","d","f","g","h","j","k","l","@pad"],
            ["@shift","z","x","c","v","b","n","m","@bksp"],
            ["@sym",",","@space",".","@enter"]],
        sym: [
            ["1","2","3","4","5","6","7","8","9","0"],
            ["@","#","$","_","&","-","+","(",")","/"],
            ["@pad","*","\"","'",":",";","!","?","@pad"],
            ["@sym2","=","%","~","\\","|","<",">","@bksp"],
            ["@abc",",","@space",".","@enter"]],
        sym2: [
            ["1","2","3","4","5","6","7","8","9","0"],
            ["`","•","√","π","÷","×","¶","∆","{","}"],
            ["@pad","£","¢","€","¥","^","°","[","]","@pad"],
            ["@sym","©","®","™","✓","¡","¿","«","»","@bksp"],
            ["@abc",",","@space",".","@enter"]],
        num: [
            ["1","2","3","@bksp"],
            ["4","5","6","."],
            ["7","8","9",","],
            ["-","0","@enter"]]
    })
    readonly property var layoutRows: {
        let rows = layouts[kbLayer] || layouts.abc
        if (!numberRow && kbLayer !== "num") rows = rows.slice(1)
        return rows
    }
    readonly property var weights: ({ "@shift": 1.5, "@bksp": 1.5, "@sym": 1.5, "@sym2": 1.5, "@abc": 1.5, "@space": 5, "@enter": 1.5, "@pad": 0.5 })

    readonly property var alternates: ({
        a: ["à","á","â","ä","æ","ã","å","ā"], e: ["é","è","ê","ë","ē","ę"],
        i: ["í","ì","î","ï","ī"], o: ["ó","ò","ô","ö","õ","œ","ø"],
        u: ["ú","ù","û","ü","ū"], c: ["ç","ć","č"], n: ["ñ","ń"],
        s: ["ß","š","ś"], y: ["ý","ÿ"], z: ["ž","ź","ż"], l: ["ł"], d: ["ď"],
        r: ["ř"], t: ["ť"], g: ["ğ"],
        ".": ["…","?","!",":",";"], ",": [";",":","“","”"], "-": ["–","—","•"],
        "$": ["€","£","¥","¢"], "0": ["°"], "?": ["¿"], "!": ["¡"], "\"": ["“","”","«","»"]
    })

    // ---- text editing ----
    function _hasSel() { return target && target.selectedText !== undefined && target.selectionStart !== target.selectionEnd }
    function commit(t) {
        if (!target) return
        if (_hasSel()) target.remove(target.selectionStart, target.selectionEnd)
        const pos = target.cursorPosition
        target.insert(pos, t)
        target.cursorPosition = pos + t.length
        if (shiftState === "once") shiftState = "off"
        if (kbLayer === "sym" || kbLayer === "sym2") { if (t === " ") kbLayer = "abc" }
        _autoCapitalise()
    }
    function backspace() {
        if (!target) return
        if (_hasSel()) { target.remove(target.selectionStart, target.selectionEnd) }
        else if (target.cursorPosition > 0) { const p0 = target.cursorPosition; target.remove(p0 - 1, p0); target.cursorPosition = p0 - 1 }
        _autoCapitalise()
    }
    function enter() {
        if (!target) return
        if (typeof target.accepted === "function" || target.accepted !== undefined) { target.accepted(); return }
        commit("\n")
    }
    function moveCursor(d) { if (target) target.cursorPosition = Math.max(0, Math.min(target.length, target.cursorPosition + d)) }
    function _autoCapitalise() {
        if (!autoCap || kbLayer !== "abc" || shiftState === "lock") return
        const t = target.text.substring(0, target.cursorPosition)
        shiftState = (t.length === 0 || /[.!?]\s+$/.test(t) || /\n$/.test(t)) ? "once" : "off"
    }
    function pressShift() {
        if (shiftState === "off") shiftState = "once"
        else if (shiftState === "once") shiftState = dbl.running ? "lock" : "off"
        else shiftState = "off"
        dbl.restart()
    }
    Timer { id: dbl; interval: 340 }

    // ---- visuals ----
    readonly property color keyFill: Theme.dark ? "#262626" : "#d7d7d7"
    readonly property color keyFillSpecial: Theme.dark ? "#171717" : "#c4c4c4"
    readonly property color panelFill: Theme.dark ? "#000000" : "#ececec"

    Rectangle { anchors.fill: parent; color: root.panelFill }
    MouseArea { anchors.fill: parent }   // swallow taps in key gaps so they never reach the page below
    Rectangle { width: parent.width; height: 1; color: Theme.dark ? "#2e2e2e" : "#c8c8c8" }

    // collapse bar
    Item {
        id: bar
        width: parent.width; height: root.barH
        Canvas {
            id: chev
            width: 22; height: 12; anchors.centerIn: parent
            property color ink: Theme.textDim
            onInkChanged: requestPaint()
            onPaint: { const c = getContext("2d"); c.clearRect(0, 0, width, height); c.strokeStyle = ink; c.lineWidth = 2.4
                c.beginPath(); c.moveTo(2, 2); c.lineTo(11, 10); c.lineTo(20, 2); c.stroke() }
        }
        MouseArea { anchors.fill: parent; onClicked: root.hideRequested() }
    }

    // key icon (shift, backspace, enter) drawn with the canvas, no font dependence
    component KeyIcon : Canvas {
        property string kind: ""
        property color ink: Theme.text
        property bool filled: false
        width: 26; height: 26
        onKindChanged: requestPaint(); onInkChanged: requestPaint(); onFilledChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.clearRect(0, 0, width, height)
            c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 2.2; c.lineJoin = "round"; c.lineCap = "round"
            c.beginPath()
            if (kind === "shift") {
                c.moveTo(13, 3); c.lineTo(23, 13); c.lineTo(17, 13); c.lineTo(17, 22); c.lineTo(9, 22); c.lineTo(9, 13); c.lineTo(3, 13); c.closePath()
                if (filled) c.fill(); else c.stroke()
            } else if (kind === "bksp") {
                c.moveTo(9, 4); c.lineTo(23, 4); c.lineTo(23, 22); c.lineTo(9, 22); c.lineTo(2, 13); c.closePath(); c.stroke()
                c.beginPath(); c.moveTo(12, 9); c.lineTo(19, 17); c.moveTo(19, 9); c.lineTo(12, 17); c.stroke()
            } else if (kind === "enter") {
                c.moveTo(22, 5); c.lineTo(22, 15); c.lineTo(5, 15); c.moveTo(11, 9); c.lineTo(5, 15); c.lineTo(11, 21); c.stroke()
            }
        }
    }

    // one key
    component Key : Item {
        id: k
        property string tok: ""
        property real unit: 40
        readonly property bool pad: tok === "@pad"
        readonly property bool special: tok.charAt(0) === "@"
        readonly property real wt: special ? (root.weights[tok] || 1) : 1
        readonly property bool letter: !special && tok.length === 1 && tok.toLowerCase() !== tok.toUpperCase()
        readonly property string ch: letter && root.shiftState !== "off" ? tok.toUpperCase() : tok
        readonly property var alts: {
            const a = root.alternates[tok.toLowerCase()]
            if (!a || special) return []
            return letter && root.shiftState !== "off" ? a.map(x => x.toUpperCase()) : a
        }
        property bool down: false
        property bool altOpen: false
        property int altHover: -1
        width: wt * unit; height: root.keyH
        visible: !pad || true

        Rectangle {
            visible: !k.pad
            anchors { fill: parent; margins: 2 }
            color: k.down ? Theme.accent
                 : (k.tok === "@enter" ? Theme.accent
                 : (k.tok === "@shift" && root.shiftState !== "off" ? Theme.accent
                 : (k.special ? root.keyFillSpecial : root.keyFill)))
            Text {
                visible: !k.special || k.tok === "@sym" || k.tok === "@sym2" || k.tok === "@abc"
                anchors.centerIn: parent
                text: k.tok === "@sym" ? "?123" : k.tok === "@sym2" ? "=\\<" : k.tok === "@abc" ? "ABC" : (k.tok === "@space" ? "" : k.ch)
                color: (k.down || k.tok === "@enter") ? Theme.onColor(Theme.accent) : Theme.text
                font.family: Theme.font; font.pixelSize: k.special ? 20 : 27; font.weight: Font.Normal
            }
            // language/space label
            Text { visible: k.tok === "@space"; anchors.centerIn: parent; text: "tiles"; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 16; font.letterSpacing: 2 }
            KeyIcon {
                visible: k.tok === "@shift" || k.tok === "@bksp" || k.tok === "@enter"
                anchors.centerIn: parent
                kind: k.tok.substring(1)
                filled: root.shiftState === "lock"
                ink: (k.down || k.tok === "@enter" || (k.tok === "@shift" && root.shiftState !== "off")) ? Theme.onColor(Theme.accent) : Theme.text
            }
        }

        // press bubble (letters and symbols)
        Rectangle {
            visible: k.down && !k.special && !k.altOpen && k.tok !== " "
            width: k.width + 8; height: k.height + 6
            x: -4; y: -k.height - 10
            z: 20; color: Theme.accent
            Text { anchors.centerIn: parent; text: k.ch; color: Theme.onColor(Theme.accent)
                font.family: Theme.font; font.pixelSize: 38; font.weight: Font.Normal }
        }
        // alternates strip
        Rectangle {
            id: strip
            visible: k.altOpen
            readonly property real cell: 46
            width: k.alts.length * cell; height: 56
            x: Math.max(-k.x + 2, Math.min(root.width - k.x - width - 2, (k.width - width) / 2)); y: -height - 10
            z: 30; color: Theme.dark ? "#1b1b1b" : "#e4e4e4"; border.width: 2; border.color: Theme.accent
            Row {
                Repeater {
                    model: k.alts
                    Rectangle {
                        required property int index
                        required property string modelData
                        width: strip.cell; height: strip.height - 4; y: 2
                        color: index === k.altHover ? Theme.accent : "transparent"
                        Text { anchors.centerIn: parent; text: modelData; font.family: Theme.font; font.pixelSize: 28
                            color: index === k.altHover ? Theme.onColor(Theme.accent) : Theme.text }
                    }
                }
            }
        }

        // press handling
        Timer { id: holdT; interval: 420; onTriggered: if (k.alts.length > 0 && k.down) { k.altOpen = true; k.altHover = 0 } }
        Timer { id: repT; interval: 400; repeat: false
            onTriggered: { root.backspace(); repT.interval = 55; repT.repeat = true; repT.start() } }
        property real spaceX: 0
        property real spaceAcc: 0
        property bool spaceDragged: false

        MouseArea {
            anchors.fill: parent
            enabled: !k.pad
            preventStealing: true
            onPressed: (m) => {
                k.down = true; k.altHover = -1
                if (k.tok === "@bksp") { root.backspace(); repT.interval = 400; repT.repeat = false; repT.start() }
                else if (k.tok === "@space") { k.spaceX = m.x; k.spaceAcc = 0; k.spaceDragged = false }
                else if (k.alts.length > 0) holdT.restart()
            }
            onPositionChanged: (m) => {
                if (k.altOpen) {
                    const i = Math.floor((m.x - strip.x) / strip.cell)
                    k.altHover = (i >= 0 && i < k.alts.length && m.y < k.height) ? i : (m.y < 0 ? Math.max(0, Math.min(k.alts.length - 1, i)) : -1)
                } else if (k.tok === "@space") {
                    const d = m.x - k.spaceX
                    if (Math.abs(d) > 14 || k.spaceDragged) { k.spaceDragged = true
                        const steps = Math.trunc(d / 16)
                        if (steps !== 0) { root.moveCursor(steps); k.spaceX += steps * 16 } }
                }
            }
            onReleased: (m) => {
                holdT.stop(); repT.stop(); repT.repeat = false
                const wasDown = k.down
                k.down = false
                if (k.altOpen) {
                    if (k.altHover >= 0 && k.altHover < k.alts.length) root.commit(k.alts[k.altHover])
                    k.altOpen = false; k.altHover = -1; return
                }
                if (!wasDown) return
                switch (k.tok) {
                case "@bksp": break
                case "@shift": root.pressShift(); break
                case "@sym": root.kbLayer = "sym"; break
                case "@sym2": root.kbLayer = "sym2"; break
                case "@abc": root.kbLayer = "abc"; break
                case "@space": if (!k.spaceDragged) root.commit(" "); break
                case "@enter": root.enter(); break
                default: root.commit(k.ch)
                }
            }
            onCanceled: { holdT.stop(); repT.stop(); k.down = false; k.altOpen = false }
        }
    }

    // rows
    Column {
        y: root.barH + root.pad
        width: parent.width
        Repeater {
            model: root.layoutRows
            Row {
                required property var modelData
                required property int index
                readonly property real wsum: {
                    let s = 0
                    for (let i = 0; i < modelData.length; i++) {
                        const t = modelData[i]
                        s += t.charAt(0) === "@" ? (root.weights[t] || 1) : 1
                    }
                    return s
                }
                Repeater {
                    model: parent.modelData
                    Key {
                        required property string modelData
                        tok: modelData
                        unit: root.width / parent.wsum
                    }
                }
            }
        }
    }
}
