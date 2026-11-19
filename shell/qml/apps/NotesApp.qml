import QtQuick
import FlowShell

// Notes: pivot "all" / "pinned" list plus a full-height editor that slides over it.
// Store key "notes": [{id, body, pinned, modified (ms since epoch)}]. Title = first line of body.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var notes: []
    property string query: ""
    property string curId: ""          // note open in the editor
    property bool editorOpen: false
    property bool loading: false
    property string loadedBody: ""
    property string menuId: ""         // note targeted by the long-press menu
    property string toast: ""
    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function titleOf(body) {
        var l = String(body).split("\n")[0].trim()
        return l !== "" ? l : "new note"
    }
    function previewOf(body) {
        var lines = String(body).split("\n"), out = []
        for (var i = 1; i < lines.length; ++i) { var t = lines[i].trim(); if (t !== "") out.push(t) }
        return out.join(" ")
    }
    function dateOf(ms) {
        var d = new Date(ms), n = new Date()
        if (d.toDateString() === n.toDateString()) return pad(d.getHours()) + ":" + pad(d.getMinutes())
        return d.getDate() + " " + monthNames[d.getMonth()]
    }
    function subtitleOf(n) { var p = previewOf(n.body); return dateOf(n.modified) + (p !== "" ? "  ·  " + p : "") }
    function sorted(list, onlyPinned, q) {
        q = q.trim().toLowerCase()
        var out = list.filter(function(n) {
            if (onlyPinned && !n.pinned) return false
            return q === "" || String(n.body).toLowerCase().indexOf(q) >= 0
        })
        out.sort(function(a, b) {
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1
            return b.modified - a.modified
        })
        return out
    }
    property var allNotes: sorted(notes, false, query)
    property var pinnedNotes: sorted(notes, true, "")

    function persist() { AppStore.save("notes", notes) }
    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36) }
    function indexOf(id) { for (var i = 0; i < notes.length; ++i) if (notes[i].id === id) return i; return -1 }
    function getNote(id) { var i = indexOf(id); return i >= 0 ? notes[i] : null }
    function patch(id, fields) {
        var i = indexOf(id)
        if (i < 0) return
        var list = notes.slice(), n = {}
        for (var k in list[i]) n[k] = list[i][k]
        for (var f in fields) n[f] = fields[f]
        list[i] = n; notes = list; persist()
    }
    function removeNote(id) { notes = notes.filter(function(n) { return n.id !== id }); persist() }
    function togglePin(id) { var n = getNote(id); if (n) patch(id, { pinned: !n.pinned }) }

    Component.onCompleted: {
        var l = AppStore.load("notes", [])
        if (!Array.isArray(l)) l = []
        if (l.length === 0 && Sys.demoData) {
            l = [{ id: newId(), pinned: false, modified: Date.now(),
                   body: "Welcome to notes (demo note)\nThe first line is the title. Edits save automatically. Long-press a note in the list to pin or delete it." }]
            notes = l; persist()
        } else notes = l
    }

    // ---- editor
    function openNote(id) {
        var n = getNote(id)
        if (!n) return
        curId = id
        loading = true
        loadedBody = n.body
        ed.text = n.body
        loading = false
        ed.cursorPosition = ed.length
        flick.contentY = 0
        editorOpen = true
        ed.forceActiveFocus()
    }
    function createNote() {
        var id = newId()
        var list = notes.slice()
        list.push({ id: id, body: "", pinned: false, modified: Date.now() })
        notes = list            // not persisted until it has text
        openNote(id)
    }
    function commit() {
        saveTimer.stop()
        if (curId === "" || ed.text === loadedBody) return
        loadedBody = ed.text
        patch(curId, { body: ed.text, modified: Date.now() })
    }
    function closeEditor() {
        commit()
        var n = getNote(curId)
        if (n && String(n.body).trim() === "") removeNote(curId)
        else if (!n) { /* already deleted */ }
        ed.focus = false
        editorOpen = false
        curId = ""
    }
    function deleteCurrent() {
        saveTimer.stop()
        removeNote(curId)
        ed.focus = false
        editorOpen = false
        curId = ""
    }
    function showToast(t) { toast = t; toastTimer.restart() }
    function shareCurrent() {
        ed.selectAll(); ed.copy(); ed.deselect()
        showToast("copied to clipboard")
    }
    function pinCurrent() {
        commit()
        togglePin(curId)
        var n = getNote(curId)
        showToast(n && n.pinned ? "pinned" : "unpinned")
    }

    focus: true
    function back() { if (menuId !== "") menuId = ""; else if (editorOpen) closeEditor(); else closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    Timer { id: saveTimer; interval: 400; onTriggered: root.commit() }
    Timer { id: toastTimer; interval: 1400; onTriggered: root.toast = "" }

    // ---- list view
    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - 72
        caption: "notes"

        PivotPage {
            title: "all"
            MetroTextField {
                width: parent.width
                placeholder: "search"
                onEdited: root.query = text
            }
            Item { width: 1; height: 12 }
            Text {
                visible: root.allNotes.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: root.query.trim() !== "" ? "no matching notes" : "no notes yet. tap new to write one."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.allNotes
                MetroListRow {
                    required property var modelData
                    title: root.titleOf(modelData.body)
                    subtitle: root.subtitleOf(modelData)
                    trailing: modelData.pinned ? "pinned" : ""
                    onClicked: root.openNote(modelData.id)
                    onPressAndHold: root.menuId = modelData.id
                }
            }
        }

        PivotPage {
            title: "pinned"
            Text {
                visible: root.pinnedNotes.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no pinned notes. long-press a note to pin it."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.pinnedNotes
                MetroListRow {
                    required property var modelData
                    title: root.titleOf(modelData.body)
                    subtitle: root.subtitleOf(modelData)
                    onClicked: root.openNote(modelData.id)
                    onPressAndHold: root.menuId = modelData.id
                }
            }
        }
    }

    AppBar {
        anchors.bottom: parent.bottom
        items: [{ glyph: "plus", label: "new" }]
        onActivated: (i) => root.createNote()
    }

    // ---- long-press menu
    Item {
        anchors.fill: parent
        visible: root.menuId !== ""
        Rectangle { anchors.fill: parent; color: Theme.pageBg; opacity: 0.75 }
        MouseArea { anchors.fill: parent; onClicked: root.menuId = "" }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 72; height: menuCol.height + 24
            color: Theme.dark ? "#1b1b1b" : "#e6e6e6"
            border.width: 2; border.color: Theme.text
            MouseArea { anchors.fill: parent }
            Column {
                id: menuCol
                y: 12; width: parent.width
                Repeater {
                    model: {
                        var n = root.getNote(root.menuId)
                        return [n && n.pinned ? "unpin" : "pin", "delete", "cancel"]
                    }
                    Item {
                        required property int index
                        required property string modelData
                        width: parent.width; height: 56
                        opacity: mma.pressed ? 0.5 : 1
                        Text {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            text: modelData; color: Theme.text
                            font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                        }
                        MouseArea {
                            id: mma; anchors.fill: parent
                            onClicked: {
                                var id = root.menuId
                                root.menuId = ""
                                if (index === 0) root.togglePin(id)
                                else if (index === 1) root.removeNote(id)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- editor sub-view
    Item {
        id: editor
        width: root.width; height: root.height
        property real p: root.editorOpen ? 1 : 0
        Behavior on p { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
        visible: p > 0.005
        opacity: Math.min(1, p * 3)
        x: (1 - p) * 60
        transform: Rotation {
            origin.x: 0; origin.y: editor.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: Theme.reduceMotion ? 0 : -60 * (1 - editor.p)
        }
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }

        Flickable {
            id: flick
            x: 18; y: root.topInset + 12
            width: parent.width - 36; height: parent.height - root.topInset - 12 - 72
            contentWidth: width; contentHeight: Math.max(height, ed.implicitHeight + 24)
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
            }
            TextEdit {
                id: ed
                width: flick.width; height: flick.contentHeight
                wrapMode: TextEdit.Wrap
                color: Theme.text; selectionColor: Theme.accent
                selectedTextColor: Theme.onColor(Theme.accent)
                font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                onTextChanged: if (!root.loading) saveTimer.restart()
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                Text {
                    visible: ed.length === 0
                    text: "title on the first line"; color: Theme.textDim
                    font: ed.font
                }
            }
        }

        Rectangle {
            visible: root.toast !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 72 - 64
            width: toastText.width + 36; height: 44
            color: Theme.accent
            Text {
                id: toastText
                anchors.centerIn: parent; text: root.toast
                color: Theme.onColor(Theme.accent)
                font.family: Theme.font; font.pixelSize: 20
            }
        }

        AppBar {
            anchors.bottom: parent.bottom
            items: [{ glyph: "back", label: "done" }, { glyph: "star", label: "pin" },
                    { glyph: "forward", label: "share" }, { glyph: "close", label: "delete" }]
            onActivated: (i) => {
                if (i === 0) root.closeEditor()
                else if (i === 1) root.pinCurrent()
                else if (i === 2) root.shareCurrent()
                else root.deleteCurrent()
            }
        }
    }
}
