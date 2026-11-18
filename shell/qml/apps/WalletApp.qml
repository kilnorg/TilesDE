import QtQuick
import FlowShell

// Wallet: local, offline membership/loyalty cards, tickets and notes. NOT for payment cards (blocked by a Luhn check).
// Store key "wallet": { cards: [{id,name,number,note,color}], passes: [{id,title,date,note}], notes: [{id,title,body}] }
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var cards: []
    property var passes: []
    property var notes: []

    property bool detailOpen: false   // card detail
    property string curId: ""
    property bool editOpen: false
    property string kind: "card"      // card | pass | note being edited
    property string editId: ""
    property string editError: ""
    property color editColor: Theme.accent
    property bool confirmDelete: false

    function persist() { AppStore.save("wallet", { cards: cards, passes: passes, notes: notes }) }
    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36) }
    function find(list, id) { for (var i = 0; i < list.length; ++i) if (list[i].id === id) return i; return -1 }
    function getCard(id) { var i = find(cards, id); return i >= 0 ? cards[i] : null }

    Component.onCompleted: {
        var d = AppStore.load("wallet", {})
        if (!d || typeof d !== "object") d = {}
        cards = Array.isArray(d.cards) ? d.cards : []
        passes = Array.isArray(d.passes) ? d.passes : []
        notes = Array.isArray(d.notes) ? d.notes : []
    }

    // ---- payment card guard: any 13-19 digit run (spaces/dashes allowed) that passes Luhn is refused
    function luhn(s) {
        var sum = 0, dbl = false
        for (var i = s.length - 1; i >= 0; --i) {
            var d = s.charCodeAt(i) - 48
            if (dbl) { d *= 2; if (d > 9) d -= 9 }
            sum += d; dbl = !dbl
        }
        return sum % 10 === 0
    }
    function looksLikePaymentCard(text) {
        var runs = String(text).match(/\d(?:[ \-]?\d){12,}/g)
        if (!runs) return false
        for (var r = 0; r < runs.length; ++r) {
            var digits = runs[r].replace(/[^0-9]/g, "")
            for (var len = 13; len <= 19; ++len)
                for (var st = 0; st + len <= digits.length; ++st)
                    if (luhn(digits.substr(st, len))) return true
        }
        return false
    }

    // ---- editor
    function startEdit(k, id) {
        kind = k; editId = id; editError = ""; confirmDelete = false
        var rec = null
        if (id !== "") rec = k === "card" ? getCard(id) : (k === "pass" ? passes[find(passes, id)] : notes[find(notes, id)])
        if (k === "card") {
            f1.text = rec ? rec.name : ""; f2.text = rec ? rec.number : ""; f3.text = rec ? rec.note : ""
            editColor = rec ? rec.color : Theme.accent
        } else if (k === "pass") {
            f1.text = rec ? rec.title : ""; f2.text = rec ? rec.date : ""; f3.text = rec ? rec.note : ""
        } else {
            f1.text = rec ? rec.title : ""; f2.text = ""; f3.text = rec ? rec.body : ""
        }
        detailOpen = false
        editOpen = true
    }
    function saveEdit() {
        var a = f1.text.trim(), b = f2.text.trim(), c = f3.text.trim()
        if (a === "") { editError = "enter a name"; return }
        if (looksLikePaymentCard(a + "\n" + b + "\n" + c)) {
            editError = "this looks like a payment card number. payment cards are never stored here."
            return
        }
        var rec
        if (kind === "card") {
            if (b === "") { editError = "enter the card or membership number"; return }
            rec = { id: editId !== "" ? editId : newId(), name: a, number: b, note: c, color: String(editColor) }
            cards = upsert(cards, rec)
        } else if (kind === "pass") {
            rec = { id: editId !== "" ? editId : newId(), title: a, date: b, note: c }
            passes = upsert(passes, rec)
        } else {
            rec = { id: editId !== "" ? editId : newId(), title: a, body: c }
            notes = upsert(notes, rec)
        }
        persist()
        editOpen = false
        f1.focus = false
    }
    function upsert(list, rec) {
        var l = list.slice(), i = find(l, rec.id)
        if (i >= 0) l[i] = rec; else l.push(rec)
        return l
    }
    function deleteCurrent() {
        var id = editId !== "" ? editId : curId
        if (kind === "card") cards = cards.filter(function(x) { return x.id !== id })
        else if (kind === "pass") passes = passes.filter(function(x) { return x.id !== id })
        else notes = notes.filter(function(x) { return x.id !== id })
        persist()
        editOpen = false; detailOpen = false; confirmDelete = false
    }

    focus: true
    function back() {
        if (editOpen) { editOpen = false; return }
        if (detailOpen) { detailOpen = false; confirmDelete = false; return }
        closeRequested()
    }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - 72
        caption: "wallet"

        PivotPage {
            title: "cards"
            Text {
                width: parent.width; wrapMode: Text.WordWrap; bottomPadding: 14
                text: "stored locally on this device, not encrypted yet - do not store card numbers"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            Text {
                visible: root.cards.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no cards yet. tap new to add a loyalty or membership card."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.cards
                Item {
                    required property var modelData
                    width: parent.width; height: 116
                    Rectangle {
                        width: parent.width; height: 108
                        color: modelData.color
                        opacity: cma.pressed ? 0.7 : 1
                        Column {
                            x: 16; y: 14; width: parent.width - 32
                            Text {
                                width: parent.width; elide: Text.ElideRight; text: modelData.name
                                color: Theme.onColor(modelData.color)
                                font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight; text: modelData.number
                                color: Theme.onColor(modelData.color); opacity: 0.8
                                font.family: Theme.font; font.pixelSize: 22
                            }
                        }
                        MouseArea { id: cma; anchors.fill: parent
                            onClicked: { root.curId = modelData.id; root.confirmDelete = false; root.detailOpen = true } }
                    }
                }
            }
        }

        PivotPage {
            title: "passes"
            Text {
                visible: root.passes.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no passes yet. tap new to add an event or ticket."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.passes
                MetroListRow {
                    required property var modelData
                    title: modelData.title
                    subtitle: (modelData.date !== "" ? modelData.date : "no date") + (modelData.note !== "" ? "  ·  " + modelData.note : "")
                    onClicked: root.startEdit("pass", modelData.id)
                }
            }
        }

        PivotPage {
            title: "notes"
            Text {
                width: parent.width; wrapMode: Text.WordWrap; bottomPadding: 14
                text: "stored locally on this device, not encrypted yet - do not store card numbers"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            Text {
                visible: root.notes.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no notes yet. tap new to add one."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.notes
                MetroListRow {
                    required property var modelData
                    title: modelData.title
                    subtitle: String(modelData.body).replace(/\s+/g, " ")
                    onClicked: root.startEdit("note", modelData.id)
                }
            }
        }
    }

    AppBar {
        anchors.bottom: parent.bottom
        items: [{ glyph: "plus", label: "new" }]
        onActivated: (i) => root.startEdit(["card", "pass", "note"][Math.min(2, pivot.currentIndex)], "")
    }

    // ---- card detail
    Item {
        id: detail
        anchors.fill: parent
        visible: root.detailOpen
        property var c: root.getCard(root.curId)
        Rectangle { anchors.fill: parent; color: detail.c ? detail.c.color : Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Column {
            x: 18; y: root.topInset + 24; width: parent.width - 36; spacing: 16
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: detail.c ? detail.c.name.toLowerCase() : ""
                color: detail.c ? Theme.onColor(detail.c.color) : Theme.text
                font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
            }
            Text {
                width: parent.width; wrapMode: Text.WrapAnywhere
                text: detail.c ? detail.c.number : ""
                color: detail.c ? Theme.onColor(detail.c.color) : Theme.text
                font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight
            }
            Text {
                visible: detail.c && detail.c.note !== ""
                width: parent.width; wrapMode: Text.WordWrap
                text: detail.c ? detail.c.note : ""
                color: detail.c ? Theme.onColor(detail.c.color) : Theme.text; opacity: 0.85
                font.family: Theme.font; font.pixelSize: 24
            }
        }
        Row {
            x: 18; width: parent.width - 36; spacing: 12
            y: parent.height - 72 - 56 - 16
            MetroButton { width: (parent.width - 12) / 2; text: "edit"; onClicked: root.startEdit("card", root.curId) }
            MetroButton { width: (parent.width - 12) / 2; text: "close"; onClicked: root.back() }
        }
    }

    // ---- editor
    Item {
        anchors.fill: parent
        visible: root.editOpen
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Flickable {
            x: 18; y: root.topInset + 12
            width: parent.width - 36; height: parent.height - root.topInset - 12
            contentWidth: width; contentHeight: ecol.height + 32
            boundsBehavior: Flickable.StopAtBounds; clip: true
            Column {
                id: ecol
                width: parent.width; spacing: 10
                Text {
                    text: (root.editId === "" ? "new " : "edit ") + (root.kind === "card" ? "card" : (root.kind === "pass" ? "pass" : "note"))
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 48; font.weight: Theme.fontLight
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "stored locally on this device, not encrypted yet - do not store card numbers"
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
                }
                MetroTextField { id: f1; width: parent.width
                    label: root.kind === "card" ? "name" : "title"
                    placeholder: root.kind === "card" ? "library, gym, airline" : (root.kind === "pass" ? "concert, train" : "title") }
                MetroTextField { id: f2; width: parent.width
                    visible: root.kind !== "note"; height: visible ? implicitHeight : 0
                    label: root.kind === "card" ? "number" : "date"
                    placeholder: root.kind === "card" ? "membership number" : "e.g. 2026-12-24 19:30" }
                MetroTextField { id: f3; width: parent.width
                    label: root.kind === "note" ? "text" : "note"; placeholder: root.kind === "note" ? "note text" : "optional" }
                Text {
                    visible: root.kind === "card"
                    text: "colour"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21
                }
                MetroColorGrid {
                    visible: root.kind === "card"; height: visible ? implicitHeight : 0
                    width: parent.width; showHex: false; columns: 6
                    value: root.editColor
                    onPicked: (c) => root.editColor = c
                }
                Text {
                    visible: root.editError !== ""
                    width: parent.width; wrapMode: Text.WordWrap
                    text: root.editError; color: Theme.accent
                    font.family: Theme.font; font.pixelSize: 21
                }
                Row {
                    spacing: 12
                    MetroButton { text: "save"; accentFill: true; onClicked: root.saveEdit() }
                    MetroButton { text: "cancel"; onClicked: root.editOpen = false }
                }
                MetroButton {
                    visible: root.editId !== ""; height: visible ? implicitHeight : 0
                    text: root.confirmDelete ? "tap again to delete" : "delete"
                    onClicked: { if (root.confirmDelete) root.deleteCurrent(); else root.confirmDelete = true }
                }
            }
        }
    }
}
