import QtQuick
import FlowShell

// Calculator. Immediate-execution engine (chained ops, no parentheses), results rounded to 12 significant digits.
// Swipe the keypad sideways: basic <-> scientific. History persisted under AppStore key "calc".
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // engine state
    property string cur: "0"          // entry / current value as text
    property var acc: null            // accumulator (number) when an operator is pending
    property string op: ""            // pending operator: + - * / ^
    property bool fresh: true         // next digit starts a new entry
    property bool justEq: false       // last action was "="
    property string err: ""
    property string expr: ""          // history line
    property bool deg: true
    property var history: []          // newest last, max 20
    property bool showHistory: false

    readonly property var sym: ({ "+": "+", "-": "−", "*": "×", "/": "÷", "^": "^" })

    function round12(x) { return Number(x.toPrecision(12)) }
    function fmt(x) {
        if (x === 0) return "0"
        var r = round12(x)
        if (r === 0) return "0"
        var s = String(r)
        if (s.indexOf("e") >= 0) s = s.replace("e+", "e")
        return s
    }
    function val() { return Number(cur) }
    function fail(msg) {
        err = msg; cur = "0"; acc = null; op = ""; fresh = true; justEq = false; expr = ""
    }
    function resetState() { cur = "0"; acc = null; op = ""; fresh = true; justEq = false; err = ""; expr = "" }
    function pushHistory(s) {
        var h = history.slice()
        h.push(s)
        if (h.length > 20) h = h.slice(h.length - 20)
        history = h
        save()
    }
    function save() { AppStore.save("calc", { history: history }) }

    function digit(d) {
        if (err !== "") resetState()
        if (fresh) {
            if (justEq) { acc = null; op = ""; expr = ""; justEq = false }
            cur = d; fresh = false
        } else if (cur.replace("-", "").replace(".", "").length < 16) {
            cur = (cur === "0") ? d : (cur === "-0" ? "-" + d : cur + d)
        }
    }
    function dot() {
        if (err !== "") resetState()
        if (fresh) {
            if (justEq) { acc = null; op = ""; expr = ""; justEq = false }
            cur = "0."; fresh = false
        } else if (cur.indexOf(".") < 0) cur += "."
    }
    function negate() {
        if (err !== "") return
        if (cur === "0" ) { if (!fresh) cur = "-0"; return }
        cur = cur.charAt(0) === "-" ? cur.slice(1) : "-" + cur
    }
    function backspace() {
        if (err !== "") { resetState(); return }
        if (fresh) return
        cur = cur.slice(0, -1)
        if (cur === "" || cur === "-" || cur === "-0") cur = "0"
    }
    function compute(a, o, b) {
        if (o === "+") return a + b
        if (o === "-") return a - b
        if (o === "*") return a * b
        if (o === "/") return b === 0 ? NaN : a / b
        if (o === "^") return Math.pow(a, b)
        return b
    }
    function operator(o) {
        if (err !== "") return
        if (op !== "" && !fresh) {
            var r = compute(acc, op, val())
            if (op === "/" && val() === 0) { fail("cannot divide by zero"); return }
            if (!isFinite(r)) { fail("invalid input"); return }
            acc = round12(r); cur = fmt(acc)
        } else if (op === "" || justEq) {
            acc = val()
        }
        op = o; fresh = true; justEq = false
        expr = fmt(acc) + " " + sym[o]
    }
    function equals() {
        if (err !== "") return
        if (op === "") { if (!fresh) { expr = cur + " ="; fresh = true; justEq = true } return }
        var a = acc, b = val()
        if (op === "/" && b === 0) { fail("cannot divide by zero"); return }
        var r = compute(a, op, b)
        if (!isFinite(r)) { fail("invalid input"); return }
        r = round12(r)
        var line = fmt(a) + " " + sym[op] + " " + fmt(b) + " ="
        expr = line
        pushHistory(line + " " + fmt(r))
        cur = fmt(r); acc = null; op = ""; fresh = true; justEq = true
    }
    function percent() {
        if (err !== "") return
        var v = val()
        var r = (op !== "" && acc !== null && (op === "+" || op === "-")) ? acc * v / 100 : v / 100
        cur = fmt(r); fresh = false
    }
    function unary(name) {
        if (err !== "") return
        var v = val(), r = NaN, k = deg ? Math.PI / 180 : 1
        switch (name) {
        case "sin": r = Math.sin(v * k); break
        case "cos": r = Math.cos(v * k); break
        case "tan":
            if (deg ? (Math.abs(v % 180) === 90) : (Math.abs(Math.cos(v)) < 1e-15)) { fail("invalid input"); return }
            r = Math.tan(v * k); break
        case "ln": if (v <= 0) { fail("invalid input"); return } r = Math.log(v); break
        case "log": if (v <= 0) { fail("invalid input"); return } r = Math.log(v) / Math.LN10; break
        case "√": if (v < 0) { fail("invalid input"); return } r = Math.sqrt(v); break
        case "x²": r = v * v; break
        case "1/x": if (v === 0) { fail("cannot divide by zero"); return } r = 1 / v; break
        case "eˣ": r = Math.exp(v); break
        case "10ˣ": r = Math.pow(10, v); break
        case "|x|": r = Math.abs(v); break
        case "n!":
            if (v < 0 || v > 170 || Math.floor(v) !== v) { fail("invalid input"); return }
            r = 1
            for (var i = 2; i <= v; ++i) r *= i
            break
        }
        if (!isFinite(r)) { fail("invalid input"); return }
        if ((name === "sin" || name === "cos" || name === "tan") && Math.abs(r) < 1e-12) r = 0
        r = round12(r)
        var call = name + "(" + fmt(v) + ")"
        pushHistory(call + " = " + fmt(r))
        expr = (op !== "" && acc !== null) ? fmt(acc) + " " + sym[op] + " " + call : call
        cur = fmt(r); fresh = true; justEq = false
    }
    function constant(v) {
        if (err !== "") resetState()
        if (justEq) { acc = null; op = ""; expr = ""; justEq = false }
        cur = fmt(v); fresh = true
        // typing a digit after a constant starts a new entry (fresh)
    }

    Component.onCompleted: {
        var d = AppStore.load("calc", null)
        if (d && Array.isArray(d.history)) {
            history = d.history.slice(-20)
            if (history.length > 0) expr = history[history.length - 1]
        }
    }

    // ---- display ----
    Item {
        id: top
        x: 0; y: root.topInset
        width: parent.width; height: 168
        Text {
            id: histLine
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.left: parent.left; anchors.leftMargin: 18
            y: 6; height: 30
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: root.expr
            color: Theme.textDim
            font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: root.showHistory = !root.showHistory }
        }
        Text {
            id: disp
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.right: parent.right; anchors.rightMargin: 18
            y: 40; height: 112
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: root.err !== "" ? root.err : root.cur
            color: Theme.text
            font.family: Theme.font; font.pixelSize: root.err !== "" ? 40 : 96
            font.weight: Theme.fontLight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 24
            maximumLineCount: 1
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 154; spacing: 8
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    width: 8; height: 8
                    color: index === pages.currentIndex ? Theme.text : Theme.textDim
                    opacity: index === pages.currentIndex ? 1 : 0.5
                }
            }
        }
    }

    // ---- keys ----
    component Key: Item {
        id: k
        property string label: ""
        property string glyph: ""
        property color fill: root.numFill
        property color ink: Theme.text
        property int fontSize: 34
        signal clicked
        Rectangle {
            anchors.fill: parent
            color: area.pressed ? Theme.text : k.fill
        }
        Text {
            visible: k.glyph === ""
            anchors.centerIn: parent
            text: k.label
            color: area.pressed ? Theme.pageBg : k.ink
            font.family: Theme.font; font.pixelSize: k.fontSize; font.weight: Theme.fontLight
        }
        TileGlyph {
            visible: k.glyph !== ""
            anchors.centerIn: parent
            name: k.glyph; size: 32
            color: area.pressed ? Theme.pageBg : k.ink
        }
        MouseArea { id: area; anchors.fill: parent; onClicked: k.clicked() }
    }

    readonly property color numFill: Theme.dark ? "#2b2b2b" : "#d4d4d4"
    readonly property color fnFill: Theme.dark ? "#1c1c1c" : "#e6e6e6"
    readonly property color opFill: Theme.accent
    readonly property color opInk: Theme.onColor(Theme.accent)

    ListView {
        id: pages
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: top.bottom; anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Theme.reduceMotion ? 0 : 200
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: 2
        delegate: Item {
            id: pg
            required property int index
            width: pages.width; height: pages.height
            readonly property real g: Theme.tileGap
            readonly property real m: Theme.pageMargin
            readonly property real kw: Math.floor((width - 2 * m - 3 * g) / 4)
            readonly property real kh: Math.min(kw, Math.floor((height - 4 * g) / 5))
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(0, parent.height - (5 * pg.kh + 4 * pg.g))
                sourceComponent: pg.index === 0 ? basic : sci
                onLoaded: { item.kw = pg.kw; item.kh = pg.kh; item.g = pg.g }
            }
        }
    }

    Component {
        id: basic
        Grid {
            property real kw: 80
            property real kh: 80
            property real g: 6
            columns: 4; spacing: g
            Key { width: kw; height: kh; label: "AC"; fill: root.fnFill; fontSize: 28; onClicked: root.resetState() }
            Key { width: kw; height: kh; glyph: "back"; fill: root.fnFill; onClicked: root.backspace() }
            Key { width: kw; height: kh; label: "%"; fill: root.fnFill; onClicked: root.percent() }
            Key { width: kw; height: kh; label: "÷"; fill: root.opFill; ink: root.opInk; onClicked: root.operator("/") }
            Key { width: kw; height: kh; label: "7"; onClicked: root.digit("7") }
            Key { width: kw; height: kh; label: "8"; onClicked: root.digit("8") }
            Key { width: kw; height: kh; label: "9"; onClicked: root.digit("9") }
            Key { width: kw; height: kh; label: "×"; fill: root.opFill; ink: root.opInk; onClicked: root.operator("*") }
            Key { width: kw; height: kh; label: "4"; onClicked: root.digit("4") }
            Key { width: kw; height: kh; label: "5"; onClicked: root.digit("5") }
            Key { width: kw; height: kh; label: "6"; onClicked: root.digit("6") }
            Key { width: kw; height: kh; label: "−"; fill: root.opFill; ink: root.opInk; onClicked: root.operator("-") }
            Key { width: kw; height: kh; label: "1"; onClicked: root.digit("1") }
            Key { width: kw; height: kh; label: "2"; onClicked: root.digit("2") }
            Key { width: kw; height: kh; label: "3"; onClicked: root.digit("3") }
            Key { width: kw; height: kh; label: "+"; fill: root.opFill; ink: root.opInk; onClicked: root.operator("+") }
            Key { width: kw; height: kh; label: "+/−"; fill: root.fnFill; fontSize: 26; onClicked: root.negate() }
            Key { width: kw; height: kh; label: "0"; onClicked: root.digit("0") }
            Key { width: kw; height: kh; label: "."; onClicked: root.dot() }
            Key { width: kw; height: kh; label: "="; fill: root.opFill; ink: root.opInk; onClicked: root.equals() }
        }
    }

    Component {
        id: sci
        Grid {
            property real kw: 80
            property real kh: 80
            property real g: 6
            columns: 4; spacing: g
            Key { width: kw; height: kh; label: "sin"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("sin") }
            Key { width: kw; height: kh; label: "cos"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("cos") }
            Key { width: kw; height: kh; label: "tan"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("tan") }
            Key { width: kw; height: kh; label: root.deg ? "deg" : "rad"; fill: root.opFill; ink: root.opInk; fontSize: 26
                onClicked: root.deg = !root.deg }
            Key { width: kw; height: kh; label: "ln"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("ln") }
            Key { width: kw; height: kh; label: "log"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("log") }
            Key { width: kw; height: kh; label: "√"; fill: root.fnFill; onClicked: root.unary("√") }
            Key { width: kw; height: kh; label: "x²"; fill: root.fnFill; fontSize: 28; onClicked: root.unary("x²") }
            Key { width: kw; height: kh; label: "xʸ"; fill: root.opFill; ink: root.opInk; fontSize: 28; onClicked: root.operator("^") }
            Key { width: kw; height: kh; label: "π"; fill: root.fnFill; onClicked: root.constant(Math.PI) }
            Key { width: kw; height: kh; label: "e"; fill: root.fnFill; onClicked: root.constant(Math.E) }
            Key { width: kw; height: kh; label: "1/x"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("1/x") }
            Key { width: kw; height: kh; label: "n!"; fill: root.fnFill; fontSize: 28; onClicked: root.unary("n!") }
            Key { width: kw; height: kh; label: "eˣ"; fill: root.fnFill; fontSize: 28; onClicked: root.unary("eˣ") }
            Key { width: kw; height: kh; label: "10ˣ"; fill: root.fnFill; fontSize: 24; onClicked: root.unary("10ˣ") }
            Key { width: kw; height: kh; label: "|x|"; fill: root.fnFill; fontSize: 26; onClicked: root.unary("|x|") }
            Key { width: kw; height: kh; label: "AC"; fill: root.fnFill; fontSize: 28; onClicked: root.resetState() }
            Key { width: kw; height: kh; glyph: "back"; fill: root.fnFill; onClicked: root.backspace() }
            Key { width: kw; height: kh; label: "+/−"; fill: root.fnFill; fontSize: 26; onClicked: root.negate() }
            Key { width: kw; height: kh; label: "="; fill: root.opFill; ink: root.opInk; onClicked: root.equals() }
        }
    }

    // ---- history overlay ----
    Rectangle {
        visible: root.showHistory
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: top.bottom; anchors.bottom: parent.bottom
        color: Theme.pageBg
        MouseArea { anchors.fill: parent }   // swallow touches
        Text {
            visible: root.history.length === 0
            x: 18; y: 12
            text: "no history yet"; color: Theme.textDim
            font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
        }
        ListView {
            id: hl
            anchors.fill: parent; anchors.bottomMargin: 72
            clip: true; boundsBehavior: Flickable.StopAtBounds
            verticalLayoutDirection: ListView.BottomToTop
            model: root.history.slice().reverse()
            delegate: Text {
                required property string modelData
                width: hl.width - 36; x: 18
                height: 44
                horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideLeft
                text: modelData; color: Theme.text
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
        }
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            MetroButton { text: "clear"; onClicked: { root.history = []; root.save(); root.expr = ""; root.showHistory = false } }
            MetroButton { text: "close"; accentFill: true; onClicked: root.showHistory = false }
        }
    }
}
