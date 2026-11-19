import QtQuick
import FlowShell

// Messages: threads persisted in AppStore "messages" ([{thread, items:[{me, text, time, sent}], unread}]).
// `thread` is a contact id (AppStore "contacts") or a raw phone number. No SMS backend yet: sending stores locally.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var contacts: []
    property var threads: []
    property string openId: ""
    property bool convOpen: false
    property bool pickOpen: false
    property string pickQuery: ""

    readonly property var byTime: _byTime(threads)
    readonly property var unreadList: byTime.filter(function(t) { return (t.unread || 0) > 0 })
    readonly property var current: _thread(openId)
    readonly property var convRows: _rows(current)
    readonly property var pickList: _pick(contacts, pickQuery)

    function _digits(s) { return String(s).replace(/[^0-9]/g, "") }
    function _seedContacts() {
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
        if (!Array.isArray(c)) c = []
        if (c.length === 0 && Sys.demoData) { c = _seedContacts(); AppStore.save("contacts", c) }
        contacts = c
        var m = AppStore.load("messages", [])
        if (!Array.isArray(m)) m = []
        if (m.length === 0 && Sys.demoData) {
            var now = Date.now()
            m = [
                { thread: "demo1", unread: 1, items: [
                    { me: false, text: "demo message: hello from the Messages app", time: now - 3600000 * 5, sent: true },
                    { me: true, text: "demo reply, stored locally", time: now - 3600000 * 4, sent: true },
                    { me: false, text: "demo message: nothing is sent over the network yet", time: now - 600000, sent: true } ] },
                { thread: "demo3", unread: 0, items: [
                    { me: true, text: "demo: are we still on for tomorrow?", time: now - 86400000 * 2, sent: true },
                    { me: false, text: "demo: yes, see you then", time: now - 86400000 * 2 + 300000, sent: true } ] }
            ]
            AppStore.save("messages", m)
        }
        threads = m
    }
    function persist() { AppStore.save("messages", threads) }
    function _contact(id) {
        for (var i = 0; i < contacts.length; ++i) if (contacts[i].id === id) return contacts[i]
        return null
    }
    function _thread(id) {
        for (var i = 0; i < threads.length; ++i) if (threads[i].thread === id) return threads[i]
        return null
    }
    function nameOf(id) {
        var c = _contact(id)
        if (c) return c.name
        var d = _digits(id)
        if (d.length >= 3)
            for (var i = 0; i < contacts.length; ++i)
                for (var k = 0; k < contacts[i].numbers.length; ++k) {
                    var cd = _digits(contacts[i].numbers[k].number)
                    if (cd === d || (d.length >= 7 && cd.slice(-7) === d.slice(-7))) return contacts[i].name
                }
        return id
    }
    function numberOf(id) {
        var c = _contact(id)
        if (c) return c.numbers.length > 0 ? c.numbers[0].number : ""
        return id
    }
    function lastTime(t) { return t.items.length > 0 ? t.items[t.items.length - 1].time : 0 }
    function _byTime(list) {
        var a = list.slice()
        a.sort(function(x, y) { return lastTime(y) - lastTime(x) })
        return a
    }
    function preview(t) {
        if (t.items.length === 0) return ""
        var l = t.items[t.items.length - 1]
        return (l.me ? "you: " : "") + l.text.replace(/\s+/g, " ")
    }
    function whenText(t) {
        if (!t) return ""
        var d = new Date(t), n = new Date()
        if (d.toDateString() === n.toDateString()) return Qt.formatDateTime(d, "HH:mm")
        return Qt.formatDateTime(d, "d MMM")
    }
    function _rows(t) {
        var out = []
        if (!t) return out
        var prev = 0
        for (var i = 0; i < t.items.length; ++i) {
            var m = t.items[i]
            if (m.time - prev > 600000) {
                var d = new Date(m.time), n = new Date()
                out.push({ kind: "time", text: (d.toDateString() === n.toDateString() ? "" : Qt.formatDateTime(d, "d MMM") + " ") + Qt.formatDateTime(d, "HH:mm") })
            }
            prev = m.time
            out.push({ kind: "msg", me: m.me, text: m.text, last: false })
        }
        // offline note once, under the newest sent message
        for (var j = out.length - 1; j >= 0; --j) if (out[j].kind === "msg" && out[j].me) { out[j].last = true; break }
        return out
    }
    function _pick(list, q) {
        var ql = String(q).trim().toLowerCase(), out = []
        for (var i = 0; i < list.length; ++i) {
            var c = list[i]
            if (c.numbers.length === 0) continue
            if (ql === "" || String(c.name).toLowerCase().indexOf(ql) >= 0 || c.numbers[0].number.indexOf(ql) >= 0)
                out.push(c)
        }
        out.sort(function(a, b) { return String(a.name).toLowerCase().localeCompare(String(b.name).toLowerCase()) })
        return out
    }
    function openThread(id) {
        var t = threads.slice(), found = false
        for (var i = 0; i < t.length; ++i) if (t[i].thread === id) { found = true; if (t[i].unread) t[i] = Object.assign({}, t[i], { unread: 0 }) }
        if (!found) t.push({ thread: id, unread: 0, items: [] })
        threads = t; persist()
        openId = id
        pickOpen = false
        convOpen = true
    }
    function send() {
        var txt = compose.text.trim()
        if (txt === "" || openId === "") return
        var t = threads.slice()
        for (var i = 0; i < t.length; ++i) if (t[i].thread === openId) {
            var items = t[i].items.slice()
            items.push({ me: true, text: txt, time: Date.now(), sent: true })
            t[i] = Object.assign({}, t[i], { items: items })
        }
        threads = t; persist()
        compose.text = ""
        Qt.callLater(function() { conv.positionViewAtEnd() })
    }
    function back() {
        if (pickOpen) pickOpen = false
        else if (convOpen) { convOpen = false; _dropEmpty() }
        else closeRequested()
    }
    function _dropEmpty() {
        var t = threads.filter(function(x) { return x.items.length > 0 })
        if (t.length !== threads.length) { threads = t; persist() }
    }

    focus: true
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
    Component.onCompleted: load()
    onVisibleChanged: if (visible) load()

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Component {
        id: threadRow
        Item {
            id: tr
            required property var modelData
            readonly property int unread: modelData.unread || 0
            width: parent ? parent.width : 360
            height: 84
            opacity: tma.pressed ? 0.6 : 1
            Column {
                anchors.left: parent.left; anchors.right: badge.visible ? badge.left : parent.right
                anchors.rightMargin: 12
                y: 8
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - when.width - 8; elide: Text.ElideRight
                        text: root.nameOf(tr.modelData.thread); color: Theme.text
                        font.family: Theme.font; font.pixelSize: 24
                        font.weight: tr.unread > 0 ? Font.Bold : Theme.fontLight
                    }
                    Text {
                        id: when; text: root.whenText(root.lastTime(tr.modelData)); color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 18
                    }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: root.preview(tr.modelData); color: tr.unread > 0 ? Theme.text : Theme.textDim
                    font.family: Theme.font; font.pixelSize: 18
                    font.weight: tr.unread > 0 ? Font.DemiBold : Font.Normal
                }
            }
            Rectangle {
                id: badge
                visible: tr.unread > 0
                anchors.right: parent.right; y: 36
                width: 32; height: 32; color: Theme.accent
                Text {
                    anchors.centerIn: parent; text: tr.unread > 99 ? "99+" : tr.unread
                    color: Theme.onColor(Theme.accent); font.family: Theme.font; font.pixelSize: 18
                }
            }
            MouseArea { id: tma; anchors.fill: parent; onClicked: root.openThread(tr.modelData.thread) }
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: root.topInset

        Pivot {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: bar.top
            caption: "messages"

            PivotPage {
                title: "threads"
                Text {
                    visible: root.byTime.length === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: "no conversations. tap + to start one."
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
                Repeater { model: root.byTime; delegate: threadRow }
            }
            PivotPage {
                title: "unread"
                Text {
                    visible: root.unreadList.length === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: "nothing unread"
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
                Repeater { model: root.unreadList; delegate: threadRow }
            }
        }

        AppBar {
            id: bar
            anchors.bottom: parent.bottom
            items: [{ glyph: "plus", label: "new message" }]
            onActivated: (i) => { root.pickQuery = ""; pickField.text = ""; root.pickOpen = true }
        }

        // ---- conversation ----
        Item {
            width: parent.width; height: parent.height
            x: root.convOpen ? 0 : width
            visible: x < width
            Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; color: Theme.pageBg }
            MouseArea { anchors.fill: parent }

            Item {
                id: cHead
                width: parent.width; height: 72
                Item {
                    x: 6; y: 12; width: 48; height: 48
                    opacity: bka.pressed ? 0.5 : 1
                    TileGlyph { anchors.centerIn: parent; name: "back"; size: 28; color: Theme.text; stroke: 2 }
                    MouseArea { id: bka; anchors.fill: parent; onClicked: root.back() }
                }
                Text {
                    x: 62; width: parent.width - 62 - 66; anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.nameOf(root.openId); color: Theme.text
                    font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight
                }
                Item {
                    anchors.right: parent.right; anchors.rightMargin: 12; y: 12; width: 48; height: 48
                    opacity: cla.pressed ? 0.5 : 1
                    TileGlyph { anchors.centerIn: parent; name: "phone"; size: 28; color: Theme.text; stroke: 2 }
                    MouseArea { id: cla; anchors.fill: parent
                        onClicked: Qt.openUrlExternally("tel:" + String(root.numberOf(root.openId)).replace(/[^0-9+*#]/g, "")) }
                }
            }

            ListView {
                id: conv
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: cHead.bottom; anchors.bottom: cBar.top
                clip: true; boundsBehavior: Flickable.StopAtBounds
                spacing: 6
                topMargin: 8; bottomMargin: 8
                model: root.convRows
                onCountChanged: Qt.callLater(function() { conv.positionViewAtEnd() })
                Text {
                    visible: conv.count === 0
                    anchors.centerIn: parent
                    text: "no messages yet"; color: Theme.textDim
                    font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
                delegate: Item {
                    id: bub
                    required property var modelData
                    readonly property bool isTime: modelData.kind === "time"
                    readonly property real maxW: conv.width * 0.78
                    width: conv.width
                    height: isTime ? 26 : (rect.height + (modelData.last ? 22 : 0))
                    Text {
                        visible: bub.isTime
                        anchors.centerIn: parent
                        text: bub.modelData.text; color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 16
                    }
                    TextMetrics {
                        id: tm
                        text: bub.modelData.text || ""
                        font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                    }
                    Rectangle {
                        id: rect
                        visible: !bub.isTime
                        x: bub.modelData.me ? bub.width - width - 12 : 12
                        width: Math.min(tm.advanceWidth + 28, bub.maxW)
                        height: body.height + 20
                        color: bub.modelData.me ? Theme.accent : (Theme.dark ? "#2b2b2b" : "#d6d6d6")
                        Text {
                            id: body
                            x: 14; y: 10; width: parent.width - 28
                            wrapMode: Text.Wrap
                            text: bub.modelData.text || ""
                            color: bub.modelData.me ? Theme.onColor(Theme.accent) : Theme.text
                            font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                        }
                    }
                    Text {
                        visible: !bub.isTime && bub.modelData.last
                        anchors.right: parent.right; anchors.rightMargin: 12; y: rect.height + 3
                        text: "offline: stored locally"; color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 14
                    }
                }
            }

            Item {
                id: cBar
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: box.height + 16
                Rectangle {
                    id: box
                    x: 12; y: 8
                    width: parent.width - 12 - 12 - 56 - 8
                    height: Math.min(tf.contentHeight, 4 * lineM.height) + 16
                    color: compose.activeFocus ? Theme.text : "transparent"
                    border.width: 2; border.color: compose.activeFocus ? Theme.accent : Theme.text
                    TextMetrics { id: lineM; text: "Ag"; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight }
                    Flickable {
                        id: tf
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.topMargin: 8; anchors.bottomMargin: 8
                        contentWidth: width; contentHeight: compose.contentHeight
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        function ensureVisible(r) {
                            if (contentY >= r.y) contentY = r.y
                            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
                        }
                        TextEdit {
                            id: compose
                            width: tf.width
                            wrapMode: TextEdit.Wrap
                            color: activeFocus ? Theme.pageBg : Theme.text
                            selectionColor: Theme.accent
                            font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                            onCursorRectangleChanged: tf.ensureVisible(cursorRectangle)
                            Text {
                                visible: compose.text === "" && !compose.activeFocus
                                text: "message"; color: Theme.textDim; font: compose.font
                            }
                        }
                    }
                }
                Rectangle {
                    x: parent.width - 12 - 56; y: box.y + box.height - 56
                    width: 56; height: 56
                    color: compose.text.trim() === "" ? (Theme.dark ? "#2b2b2b" : "#d6d6d6") : (sma.pressed ? Qt.darker(Theme.accent, 1.25) : Theme.accent)
                    TileGlyph {
                        anchors.centerIn: parent; name: "forward"; size: 30; stroke: 2
                        color: compose.text.trim() === "" ? Theme.textDim : Theme.onColor(Theme.accent)
                    }
                    MouseArea { id: sma; anchors.fill: parent; onClicked: root.send() }
                }
            }
        }

        // ---- new message picker ----
        Item {
            width: parent.width; height: parent.height
            x: root.pickOpen ? 0 : width
            visible: x < width
            Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; color: Theme.pageBg }
            MouseArea { anchors.fill: parent }

            Column {
                id: pHead
                x: 18; y: 24; width: parent.width - 36; spacing: 8
                Text {
                    text: "MESSAGES"; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
                }
                Text {
                    text: "new"; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
                }
                MetroTextField {
                    id: pickField
                    width: parent.width
                    placeholder: "name or number"
                    onEdited: root.pickQuery = text
                    onAccepted: if (root._digits(text).length >= 3) root.openThread(text.trim())
                }
            }
            Flickable {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: pHead.bottom; anchors.topMargin: 12; anchors.bottom: pBar.top
                contentWidth: width; contentHeight: pCol.implicitHeight + 24
                boundsBehavior: Flickable.StopAtBounds; clip: true
                Column {
                    id: pCol
                    x: 18; width: parent.width - 36
                    MetroListRow {
                        visible: root._digits(root.pickQuery).length >= 3
                        height: visible ? 68 : 0
                        title: "send to " + root.pickQuery.trim()
                        subtitle: "number"
                        onClicked: root.openThread(root.pickQuery.trim())
                    }
                    Repeater {
                        model: root.pickList
                        MetroListRow {
                            required property var modelData
                            title: modelData.name
                            subtitle: modelData.numbers[0].number
                            onClicked: root.openThread(modelData.id)
                        }
                    }
                }
            }
            AppBar {
                id: pBar
                anchors.bottom: parent.bottom
                items: [{ glyph: "close", label: "cancel" }]
                onActivated: (i) => root.pickOpen = false
            }
        }
    }
}
