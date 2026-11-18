import QtQuick
import FlowShell

// Reminders. Persisted under AppStore "reminders": [{id, title, due ("yyyy-MM-dd" or ""), done, list}].
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var items: []
    property string draft: ""
    property string pendingDue: ""          // "", "today", "tomorrow", "week"
    property int listIndex: 0
    property string confirmId: ""           // row armed for delete (long-press, then tap again)
    property string todayStr: dateStr(new Date())
    readonly property var lists: ["inbox", "personal", "work", "shopping"]

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function dateStr(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function offsetStr(days) { var d = new Date(); d.setDate(d.getDate() + days); return dateStr(d) }
    function save() { AppStore.save("reminders", items) }
    function back() {
        if (confirmId !== "") { confirmId = ""; return }
        closeRequested()
    }
    function dueLabel(due) {
        if (due === "") return "no date"
        if (due === todayStr) return "today"
        if (due === offsetStr(1)) return "tomorrow"
        var p = due.split("-")
        var d = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
        return Qt.formatDate(d, "ddd d MMM").toLowerCase()
    }
    function addItem() {
        var t = draft.trim()
        if (t === "") return
        var due = ""
        if (pendingDue === "today") due = offsetStr(0)
        else if (pendingDue === "tomorrow") due = offsetStr(1)
        else if (pendingDue === "week") due = offsetStr(7)
        var list = items.slice()
        list.unshift({ id: String(Date.now()) + String(Math.floor(Math.random() * 1000)), title: t, due: due, done: false, list: lists[listIndex] })
        items = list
        draft = ""; pendingDue = ""
        save()
    }
    function toggle(id) {
        items = items.map(function(r) { if (r.id === id) { r.done = !r.done } return r })
        confirmId = ""
        save()
    }
    function remove(id) {
        items = items.filter(function(r) { return r.id !== id })
        confirmId = ""
        save()
    }
    function filtered(kind) {
        var out = items.filter(function(r) {
            if (kind === "done") return r.done
            if (r.done) return false
            if (kind === "today") return r.due === "" || r.due <= todayStr
            return r.due !== "" && r.due > todayStr
        })
        out.sort(function(a, b) {
            if (a.due === b.due) return 0
            if (a.due === "") return 1
            if (b.due === "") return -1
            return a.due < b.due ? -1 : 1
        })
        return out
    }

    Component.onCompleted: {
        var v = AppStore.load("reminders", [])
        items = Array.isArray(v) ? v : []
    }
    Timer {   // roll "today" over at midnight / on resume
        interval: 60000; running: true; repeat: true
        onTriggered: root.todayStr = root.dateStr(new Date())
    }

    // quick due chip: flat outlined, filled with accent when selected
    component Chip: Item {
        id: chip
        property string text: ""
        property bool active: false
        signal clicked
        width: lbl.implicitWidth + 28; height: 48
        Rectangle {
            anchors.fill: parent
            color: chip.active ? Theme.accent : "transparent"
            border.width: 2; border.color: chip.active ? Theme.accent : Theme.textDim
            opacity: ma.pressed ? 0.6 : 1
        }
        Text {
            id: lbl; anchors.centerIn: parent; text: chip.text
            color: chip.active ? Theme.onColor(Theme.accent) : Theme.text
            font.family: Theme.font; font.pixelSize: 20; font.weight: Theme.fontLight
        }
        MouseArea { id: ma; anchors.fill: parent; onClicked: chip.clicked() }
    }

    component RRow: Item {
        id: row
        property var rec: ({})
        property bool overdue: !rec.done && rec.due !== "" && rec.due < root.todayStr
        property bool armed: root.confirmId === rec.id
        width: parent ? parent.width : 360
        height: 72
        Rectangle {   // square outline checkbox
            id: box
            x: 0; y: 12; width: 48; height: 48
            color: row.rec.done ? Theme.accent : "transparent"
            border.width: 2; border.color: row.rec.done ? Theme.accent : Theme.text
            Rectangle { anchors.centerIn: parent; visible: row.rec.done; width: 20; height: 20; color: Theme.onColor(Theme.accent) }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.toggle(row.rec.id) }
        }
        Column {
            x: 66; y: 8; width: parent.width - 66
            opacity: textArea.pressed ? 0.6 : 1
            Text {
                width: parent.width; text: row.rec.title || ""; elide: Text.ElideRight
                color: row.rec.done ? Theme.textDim : Theme.text
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                font.strikeout: !!row.rec.done
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: 18
                color: row.armed || row.overdue ? Theme.accent : Theme.textDim
                opacity: row.armed ? 1 : (row.overdue ? 0.7 : 1)
                text: row.armed ? "tap to delete"
                    : (row.overdue ? "overdue · " : "") + root.dueLabel(row.rec.due || "")
                      + (row.rec.list && row.rec.list !== "inbox" ? " · " + row.rec.list : "")
            }
        }
        MouseArea {
            id: textArea
            x: 66; width: parent.width - 66; height: parent.height
            onClicked: { if (row.armed) root.remove(row.rec.id); else root.confirmId = "" }
            onPressAndHold: root.confirmId = row.armed ? "" : row.rec.id
        }
    }

    // shared add panel placed at the top of every page
    Component {
        id: addPanel
        Column {
            width: parent ? parent.width : 360
            spacing: 10
            MetroTextField {
                width: parent.width
                placeholder: "add a reminder"
                text: root.draft
                onEdited: root.draft = text
                onAccepted: root.addItem()
            }
            Row {
                spacing: 8
                Chip { text: "today"; active: root.pendingDue === "today"; onClicked: root.pendingDue = active ? "" : "today" }
                Chip { text: "tomorrow"; active: root.pendingDue === "tomorrow"; onClicked: root.pendingDue = active ? "" : "tomorrow" }
                Chip { text: "next week"; active: root.pendingDue === "week"; onClicked: root.pendingDue = active ? "" : "week" }
            }
            MetroDropdown {
                width: parent.width
                label: "list"
                model: root.lists
                currentIndex: root.listIndex
                onActivated: function(i) { root.listIndex = i }
            }
            Item {
                width: parent.width; height: 56
                MetroButton { text: "add"; accentFill: true; enabled2: root.draft.trim() !== ""; onClicked: root.addItem() }
            }
            Item { width: 1; height: 8 }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Pivot {
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "reminders"

        PivotPage {
            title: "today"
            Loader { width: parent.width; sourceComponent: addPanel }
            Repeater {
                model: root.filtered("today")
                RRow { required property var modelData; rec: modelData }
            }
            Text {
                visible: root.filtered("today").length === 0
                width: parent.width; wrapMode: Text.Wrap; color: Theme.textDim
                text: "nothing due. add a reminder above."
                font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
            }
        }
        PivotPage {
            title: "upcoming"
            Loader { width: parent.width; sourceComponent: addPanel }
            Repeater {
                model: root.filtered("upcoming")
                RRow { required property var modelData; rec: modelData }
            }
            Text {
                visible: root.filtered("upcoming").length === 0
                width: parent.width; wrapMode: Text.Wrap; color: Theme.textDim
                text: "nothing coming up."
                font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
            }
        }
        PivotPage {
            title: "done"
            Repeater {
                model: root.filtered("done")
                RRow { required property var modelData; rec: modelData }
            }
            Text {
                visible: root.filtered("done").length === 0
                width: parent.width; wrapMode: Text.Wrap; color: Theme.textDim
                text: "completed reminders show up here. long-press a row to delete it."
                font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
            }
        }
    }
}
