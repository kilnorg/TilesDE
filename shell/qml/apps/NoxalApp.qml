import QtQuick
import FlowShell

// Noxal assistant chat. PROTOTYPE: no model attached; a tiny local rule-based responder answers.
// Persisted under AppStore "noxal": {messages: [{role: "me"|"noxal", text, ts}], endpoint: int}.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var messages: []
    property int endpointIndex: 0           // placeholder only, stored for future use, never used
    property bool settingsOpen: false
    readonly property var endpoints: ["not set", "http://localhost:8080/v1", "custom (not implemented)"]

    function back() {
        if (settingsOpen) { settingsOpen = false; return }
        closeRequested()
    }
    function save() { AppStore.save("noxal", { messages: messages, endpoint: endpointIndex }) }
    function push(role, text) {
        var l = messages.slice()
        l.push({ role: role, text: text, ts: Date.now() })
        if (l.length > 300) l = l.slice(l.length - 300)
        messages = l
        save()
    }
    function pad(n) { return (n < 10 ? "0" : "") + n }

    // ---- safe arithmetic (recursive descent; no eval) ----
    function calc(src) {
        var s = src.replace(/\s+/g, ""), pos = 0
        function peek() { return s.charAt(pos) }
        function num() {
            var st = pos
            while (/[0-9.]/.test(peek())) pos++
            if (st === pos) return NaN
            return parseFloat(s.substring(st, pos))
        }
        function factor() {
            var c = peek()
            if (c === "-") { pos++; return -factor() }
            if (c === "+") { pos++; return factor() }
            if (c === "(") {
                pos++
                var v = expr()
                if (peek() !== ")") return NaN
                pos++
                return v
            }
            return num()
        }
        function term() {
            var v = factor()
            while (peek() === "*" || peek() === "/") {
                var op = peek(); pos++
                var r = factor()
                v = op === "*" ? v * r : v / r
            }
            return v
        }
        function expr() {
            var v = term()
            while (peek() === "+" || peek() === "-") {
                var op = peek(); pos++
                var r = term()
                v = op === "+" ? v + r : v - r
            }
            return v
        }
        var res = expr()
        return pos === s.length ? res : NaN
    }
    function findMath(text) {
        var t = text.replace(/(\d)\s*[x×]\s*(\d)/gi, "$1*$2").replace(/÷/g, "/")
        var m = t.match(/[\d.+\-*\/()\s]+/g)
        if (!m) return null
        var best = null
        for (var i = 0; i < m.length; ++i) {
            var c = m[i].trim()
            if (/\d/.test(c) && /[+\-*\/]/.test(c.replace(/^[-+]/, "")) && (best === null || c.length > best.length)) best = c
        }
        return best
    }

    // ---- local rule-based responder ----
    function reply(text) {
        var t = text.toLowerCase().trim()
        var now = new Date()
        if (/\b(reminders?|to-?dos?)\b/.test(t) && /\b(list|show|what|my)\b/.test(t)) {
            var v = AppStore.load("reminders", [])
            var open = (Array.isArray(v) ? v : []).filter(function(r) { return !r.done })
            if (open.length === 0) return "you have no open reminders."
            var lines = open.slice(0, 12).map(function(r) {
                return "- " + r.title + (r.due ? " (" + r.due + ")" : "")
            })
            return "you have " + open.length + " open reminder" + (open.length === 1 ? "" : "s") + ":\n" + lines.join("\n")
                + (open.length > 12 ? "\n...and " + (open.length - 12) + " more" : "")
        }
        var expr = findMath(text)
        if (expr !== null) {
            var r = calc(expr)
            if (!isNaN(r)) {
                if (!isFinite(r)) return "that divides by zero."
                return expr + " = " + String(Math.round(r * 1e10) / 1e10)
            }
        }
        if (/\b(time|clock|hour)\b/.test(t)) return "it is " + pad(now.getHours()) + ":" + pad(now.getMinutes()) + "."
        if (/\b(date|day|today)\b/.test(t)) return "today is " + Qt.formatDate(now, "dddd, d MMMM yyyy").toLowerCase() + "."
        if (/^(hi|hello|hey)\b/.test(t)) return "hello. i'm a prototype with a few built-in tricks. type \"help\" to see them."
        if (/\bhelp\b|what can you do/.test(t))
            return "i can tell the time or date, do simple arithmetic (try 12 * (3 + 4)), and list your reminders. anything else needs a model, which i don't have yet."
        return "i'm not connected to a model yet, so i can't answer that. this is a prototype: i only handle time, date, simple arithmetic and \"list my reminders\"."
    }
    function send() {
        var t = input.text.trim()
        if (t === "") return
        input.text = ""
        push("me", t)
        push("noxal", reply(t))
    }

    Component.onCompleted: {
        var v = AppStore.load("noxal", null)
        if (v && Array.isArray(v.messages)) messages = v.messages
        if (v && typeof v.endpoint === "number") endpointIndex = Math.max(0, Math.min(endpoints.length - 1, v.endpoint))
        if (messages.length === 0)
            push("noxal", "hi, i'm noxal. prototype build: no model attached yet. type \"help\" to see what i can do offline.")
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // header
    Item {
        id: header
        y: root.topInset
        width: parent.width; height: 96
        Text {
            x: 18; y: 4; text: "noxal"
            color: Theme.text; font.family: Theme.font; font.pixelSize: 64; font.weight: Theme.fontLight
        }
        Text {
            x: 18; y: 70; text: "PROTOTYPE · NO MODEL ATTACHED"
            color: Theme.accent; font.family: Theme.font; font.pixelSize: 15; font.letterSpacing: 0.5
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 30
            text: "settings"; color: root.settingsOpen ? Theme.accent : Theme.textDim
            font.family: Theme.font; font.pixelSize: 22
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: root.settingsOpen = !root.settingsOpen }
        }
    }

    Column {
        id: settings
        visible: root.settingsOpen
        x: 18; y: header.y + header.height
        width: parent.width - 36
        spacing: 12
        MetroDropdown {
            width: parent.width
            label: "endpoint (placeholder, not used)"
            model: root.endpoints
            currentIndex: root.endpointIndex
            onActivated: function(i) { root.endpointIndex = i; root.save() }
        }
        MetroButton {
            text: "clear chat"
            onClicked: { root.messages = []; root.save(); root.push("noxal", "chat cleared. prototype build, no model attached.") }
        }
        Item { width: 1; height: 4 }
    }

    ListView {
        id: list
        x: 0; y: settings.visible ? settings.y + settings.height : header.y + header.height
        width: parent.width
        height: compose.y - y
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 10
        model: root.messages
        topMargin: 8; bottomMargin: 8
        onCountChanged: Qt.callLater(function() { list.positionViewAtEnd() })
        delegate: Item {
            id: dlg
            required property var modelData
            readonly property bool mine: modelData.role === "me"
            readonly property real maxW: list.width * 0.78
            width: list.width
            height: bubble.height
            Text { id: measure; visible: false; text: dlg.modelData.text; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight }
            Rectangle {
                id: bubble
                x: dlg.mine ? dlg.width - width - 18 : 18
                width: Math.min(dlg.maxW, measure.implicitWidth + 28)
                height: msg.implicitHeight + 24
                color: dlg.mine ? Theme.accent : (Theme.dark ? "#2b2b2b" : "#d6d6d6")
                Text {
                    id: msg
                    x: 14; y: 12; width: parent.width - 28
                    text: dlg.modelData.text; wrapMode: Text.Wrap
                    color: dlg.mine ? Theme.onColor(Theme.accent) : Theme.text
                    font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
            }
        }
    }

    // compose bar
    Rectangle {
        id: compose
        x: 0; width: parent.width
        height: Math.max(72, Math.min(160, inputBox.height + 16))
        y: parent.height - height
        color: Theme.dark ? "#1b1b1b" : "#e6e6e6"
        Rectangle {
            id: inputBox
            x: 12; y: 8
            width: parent.width - 12 - 12 - 8 - 56
            height: Math.max(56, Math.min(144, input.contentHeight + 20))
            color: input.activeFocus ? Theme.text : "transparent"
            border.width: 2; border.color: input.activeFocus ? Theme.accent : Theme.text
            Flickable {
                id: inputFlick
                anchors.fill: parent; anchors.margins: 10
                contentWidth: width; contentHeight: input.contentHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: input
                    width: inputFlick.width
                    wrapMode: TextEdit.Wrap
                    color: activeFocus ? Theme.pageBg : Theme.text
                    selectionColor: Theme.accent
                    font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                    Keys.onReturnPressed: function(ev) {
                        if (ev.modifiers & Qt.ShiftModifier) ev.accepted = false
                        else root.send()
                    }
                    Text {
                        visible: input.text === "" && !input.activeFocus
                        text: "message noxal"; color: Theme.textDim; font: input.font
                    }
                }
            }
        }
        Rectangle {
            x: parent.width - 12 - 56; y: 8; width: 56; height: 56
            color: Theme.accent
            opacity: sendArea.pressed ? 0.6 : (input.text.trim() === "" ? 0.4 : 1)
            Text {
                anchors.centerIn: parent; text: "send"; color: Theme.onColor(Theme.accent)
                font.family: Theme.font; font.pixelSize: 18; font.weight: Theme.fontLight
            }
            MouseArea { id: sendArea; anchors.fill: parent; onClicked: root.send() }
        }
    }
}
