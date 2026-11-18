import QtQuick
import FlowShell

// Phone: keypad, call history, voicemail. Contacts shared via AppStore "contacts"; recents in "phone-recents"
// ([{name, number, dir: "out"|"in"|"missed", time}]). Calling hands off to Qt.openUrlExternally("tel:...").
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var contacts: []
    property var recents: []
    property string num: ""
    property bool saveOpen: false

    readonly property var suggestions: _suggest(num, contacts)
    readonly property bool known: nameFor(num) !== ""

    readonly property var keys: [
        { d: "1", l: "" }, { d: "2", l: "ABC" }, { d: "3", l: "DEF" },
        { d: "4", l: "GHI" }, { d: "5", l: "JKL" }, { d: "6", l: "MNO" },
        { d: "7", l: "PQRS" }, { d: "8", l: "TUV" }, { d: "9", l: "WXYZ" },
        { d: "*", l: "" }, { d: "0", l: "+" }, { d: "#", l: "" }
    ]

    function _digits(s) { return String(s).replace(/[^0-9]/g, "") }
    function _seed() {
        function mk(id, n, num, mail) { return { id: id, name: n, numbers: [{ label: "mobile", number: num }], email: mail, note: "demo contact", fav: false } }
        return [mk("demo1", "Ada Lovelace", "+44 20 7946 0101", "ada@example.org"),
                mk("demo2", "Alan Turing", "+44 20 7946 0102", "alan@example.org"),
                mk("demo3", "Grace Hopper", "+1 202 555 0103", "grace@example.org"),
                mk("demo4", "Katherine Johnson", "+1 202 555 0104", ""),
                mk("demo5", "Margaret Hamilton", "+1 202 555 0105", "margaret@example.org"),
                mk("demo6", "Tim Berners-Lee", "+44 20 7946 0106", "")]
    }
    function load() {
        var c = AppStore.load("contacts", [])
        if (!Array.isArray(c) || c.length === 0) { c = _seed(); AppStore.save("contacts", c) }
        contacts = c
        var r = AppStore.load("phone-recents", [])
        recents = Array.isArray(r) ? r : []
    }
    function nameFor(number) {
        var d = _digits(number)
        if (d.length < 3) return ""
        for (var i = 0; i < contacts.length; ++i)
            for (var k = 0; k < contacts[i].numbers.length; ++k) {
                var cd = _digits(contacts[i].numbers[k].number)
                if (cd === d || (d.length >= 7 && cd.slice(-7) === d.slice(-7))) return contacts[i].name
            }
        return ""
    }
    function _suggest(n, list) {
        var d = _digits(n), out = []
        if (d.length === 0) return out
        for (var i = 0; i < list.length && out.length < 2; ++i)
            for (var k = 0; k < list[i].numbers.length; ++k)
                if (_digits(list[i].numbers[k].number).indexOf(d) >= 0) {
                    out.push({ name: list[i].name, number: list[i].numbers[k].number }); break
                }
        return out
    }
    function press(ch) { num = num + ch }
    function backspace() { if (num.length > 0) num = num.slice(0, -1) }
    function _log(number, dir) {
        var r = recents.slice()
        r.unshift({ name: nameFor(number), number: number, dir: dir, time: Date.now() })
        if (r.length > 100) r.length = 100
        recents = r
        AppStore.save("phone-recents", recents)
    }
    function call(number) {
        number = String(number).trim()
        if (number === "") { if (recents.length > 0) num = recents[0].number; return }
        _log(number, "out")
        Qt.openUrlExternally("tel:" + number.replace(/[^0-9+*#]/g, ""))
    }
    function clearHistory() { recents = []; AppStore.save("phone-recents", recents) }
    function saveContact() {
        var name = saveName.text.trim()
        if (name === "") return
        var c = contacts.slice()
        c.push({ id: "c" + Date.now() + Math.floor(Math.random() * 1000), name: name,
                 numbers: [{ label: "mobile", number: num }], email: "", note: "", fav: false })
        contacts = c
        AppStore.save("contacts", contacts)
        saveOpen = false
    }
    function whenText(t) {
        var d = new Date(t), n = new Date()
        if (d.toDateString() === n.toDateString()) return Qt.formatDateTime(d, "HH:mm")
        return Qt.formatDateTime(d, "d MMM")
    }
    function dirText(d) { return d === "in" ? "incoming" : d === "missed" ? "missed" : "outgoing" }
    function back() { if (saveOpen) saveOpen = false; else closeRequested() }

    focus: true
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
    Component.onCompleted: load()
    onVisibleChanged: if (visible) load()

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Item {
        anchors.fill: parent
        anchors.topMargin: root.topInset

        Pivot {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: bar.top
            caption: "phone"

            PivotPage {
                id: padPage
                title: "keypad"
                readonly property real gap: 4
                readonly property real keyW: Math.floor((width - margin * 2 - 2 * gap) / 3)
                readonly property real keyH: 60

                Item {
                    width: parent.width; height: 64
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: root.num
                        color: Theme.text
                        font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
                    }
                }
                Column {
                    width: parent.width
                    Repeater {
                        model: root.suggestions
                        Item {
                            id: sg
                            required property var modelData
                            width: parent.width; height: 40
                            opacity: sma.pressed ? 0.6 : 1
                            Text {
                                anchors.fill: parent; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                text: sg.modelData.name + "  " + sg.modelData.number
                                color: Theme.accent
                                font.family: Theme.font; font.pixelSize: 20
                            }
                            MouseArea { id: sma; anchors.fill: parent; onClicked: root.num = sg.modelData.number }
                        }
                    }
                }
                Item { width: 1; height: 8 }
                Grid {
                    columns: 3; spacing: padPage.gap
                    Repeater {
                        model: root.keys
                        Rectangle {
                            id: key
                            required property var modelData
                            property bool held: false
                            width: padPage.keyW; height: padPage.keyH
                            color: kma.pressed ? Theme.accent : (Theme.dark ? "#2b2b2b" : "#d6d6d6")
                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: key.modelData.d
                                    color: kma.pressed ? Theme.onColor(Theme.accent) : Theme.text
                                    font.family: Theme.font; font.weight: Theme.fontLight; font.pixelSize: 30
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 14; visible: text !== ""
                                    text: key.modelData.l
                                    color: kma.pressed ? Theme.onColor(Theme.accent) : Theme.textDim
                                    font.family: Theme.font; font.pixelSize: 12
                                }
                            }
                            MouseArea {
                                id: kma
                                anchors.fill: parent
                                onPressed: key.held = false
                                onPressAndHold: if (key.modelData.d === "0") { key.held = true; root.press("+") }
                                onClicked: if (!key.held) root.press(key.modelData.d)
                            }
                        }
                    }
                }
                Item { width: 1; height: 14 }
                Item {
                    width: parent.width; height: 76
                    Rectangle {
                        anchors.centerIn: parent
                        width: 72; height: 72; radius: 36
                        color: cma.pressed ? Qt.darker(Theme.accent, 1.25) : Theme.accent
                        TileGlyph { anchors.centerIn: parent; name: "phone"; size: 36; color: Theme.onColor(Theme.accent); stroke: 2 }
                        MouseArea { id: cma; anchors.fill: parent; onClicked: root.call(root.num) }
                    }
                    Item {
                        id: bsp
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 72
                        opacity: bma.pressed ? 0.5 : 1
                        visible: root.num !== ""
                        Text {
                            anchors.centerIn: parent; text: "⌫"
                            color: Theme.text; font.pixelSize: 36; font.family: Theme.font
                        }
                        Timer {
                            id: rep
                            interval: 90; repeat: true
                            onTriggered: root.backspace()
                        }
                        Timer { id: rep0; interval: 400; onTriggered: rep.start() }
                        MouseArea {
                            id: bma; anchors.fill: parent
                            onPressed: { root.backspace(); rep0.start() }
                            onReleased: { rep0.stop(); rep.stop() }
                            onCanceled: { rep0.stop(); rep.stop() }
                        }
                    }
                    Item {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 100; height: 56
                        visible: root.num !== "" && !root.known
                        opacity: sva.pressed ? 0.5 : 1
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "save to\ncontacts"; color: Theme.accent
                            font.family: Theme.font; font.pixelSize: 18; lineHeight: 0.9
                        }
                        MouseArea { id: sva; anchors.fill: parent; onClicked: { saveName.text = ""; root.saveOpen = true } }
                    }
                }
            }

            PivotPage {
                title: "history"
                Text {
                    visible: root.recents.length === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: "no recent calls"
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
                Repeater {
                    model: root.recents
                    MetroListRow {
                        required property var modelData
                        title: modelData.name !== "" ? modelData.name : modelData.number
                        subtitle: root.dirText(modelData.dir) + (modelData.name !== "" ? "  " + modelData.number : "")
                        trailing: root.whenText(modelData.time)
                        iconColor: modelData.dir === "missed" ? "#e51400" : Theme.accent
                        onClicked: root.call(modelData.number)
                    }
                }
            }

            PivotPage {
                title: "voicemail"
                Text {
                    width: parent.width; wrapMode: Text.Wrap
                    text: "no voicemail. visual voicemail needs a carrier connection, which isn't set up yet."
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
            }
        }

        AppBar {
            id: bar
            anchors.bottom: parent.bottom
            items: [{ glyph: "plus", label: "save contact" }]
            menuItems: ["clear history"]
            onActivated: (i) => { if (root.num !== "" && !root.known) { saveName.text = ""; root.saveOpen = true } }
            onMenuActivated: (i) => root.clearHistory()
        }

        // ---- save to contacts ----
        Item {
            width: parent.width; height: parent.height
            x: root.saveOpen ? 0 : width
            visible: x < width
            Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; color: Theme.pageBg }
            MouseArea { anchors.fill: parent }
            Column {
                x: 18; y: 24; width: parent.width - 36; spacing: 12
                Text {
                    text: "PHONE"; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
                }
                Text {
                    text: "save"; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: root.num; color: Theme.accent
                    font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight
                }
                MetroTextField { id: saveName; width: parent.width; label: "name"; onAccepted: root.saveContact() }
            }
            AppBar {
                anchors.bottom: parent.bottom
                items: [{ glyph: "forward", label: "save" }, { glyph: "close", label: "cancel" }]
                onActivated: (i) => { if (i === 0) root.saveContact(); else root.saveOpen = false }
            }
        }
    }
}
