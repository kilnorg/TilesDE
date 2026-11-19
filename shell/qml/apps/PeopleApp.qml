import QtQuick
import FlowShell

// People: contacts shared with Phone/Messages via AppStore key "contacts"
// ([{id, name, numbers:[{label, number}], email, note, fav}]). Pages: all (alphabetical + search), favourites (accent tiles).
// Detail and edit views slide over the pivot.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var contacts: []
    property string selId: ""
    property bool detailOpen: false
    property bool editOpen: false
    property bool confirmDelete: false
    property string editId: ""        // "" = new contact
    property string query: ""

    readonly property var selected: _find(selId)
    readonly property var sorted: _sorted(contacts)
    readonly property var favs: sorted.filter(function(c) { return c.fav === true })
    readonly property var entries: _entries(sorted, query)

    function _find(id) {
        for (var i = 0; i < contacts.length; ++i) if (contacts[i].id === id) return contacts[i]
        return null
    }
    function _sorted(list) {
        var a = list.slice()
        a.sort(function(x, y) { return String(x.name).toLowerCase().localeCompare(String(y.name).toLowerCase()) })
        return a
    }
    function _letter(name) {
        var ch = String(name || "").trim().charAt(0).toUpperCase()
        return (ch >= "A" && ch <= "Z") ? ch : "#"
    }
    function _entries(list, q) {
        var out = [], cur = "", ql = String(q).trim().toLowerCase()
        for (var i = 0; i < list.length; ++i) {
            var c = list[i]
            if (ql !== "") {
                var hit = String(c.name).toLowerCase().indexOf(ql) >= 0
                for (var k = 0; k < c.numbers.length && !hit; ++k) if (String(c.numbers[k].number).indexOf(ql) >= 0) hit = true
                if (!hit) continue
            }
            var l = _letter(c.name)
            if (l !== cur) { cur = l; out.push({ kind: "header", letter: l }) }
            out.push({ kind: "contact", id: c.id, name: c.name, sub: c.numbers.length > 0 ? c.numbers[0].number : (c.email || "") })
        }
        return out
    }
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
        if (!Array.isArray(c)) c = []
        if (c.length === 0 && Sys.demoData) { c = _seed(); AppStore.save("contacts", c) }
        contacts = c
    }
    function persist() { AppStore.save("contacts", contacts) }
    function initials(name) {
        var p = String(name).trim().split(/\s+/)
        return ((p[0] || "").charAt(0) + (p.length > 1 ? p[p.length - 1].charAt(0) : "")).toUpperCase()
    }
    function openDetail(id) { selId = id; confirmDelete = false; detailOpen = true }
    function toggleFav(id) {
        var c = contacts.slice()
        for (var i = 0; i < c.length; ++i) if (c[i].id === id) c[i] = Object.assign({}, c[i], { fav: !c[i].fav })
        contacts = c; persist()
    }
    function startEdit(id) {
        editId = id
        var c = id !== "" ? _find(id) : null
        fName.text = c ? c.name : ""
        var labels = ["mobile", "home", "work"]
        var nums = c ? c.numbers : []
        for (var i = 0; i < 3; ++i) {
            var n = ""
            for (var k = 0; k < nums.length; ++k) if (String(nums[k].label) === labels[i]) n = nums[k].number
            if (n === "" && i < nums.length && labels.indexOf(String(nums[i].label)) < 0) n = nums[i].number
            numFields.itemAt(i).text = n
        }
        fMail.text = c ? (c.email || "") : ""
        fNote.text = c ? (c.note || "") : ""
        editOpen = true
    }
    function saveEdit() {
        var name = fName.text.trim()
        var labels = ["mobile", "home", "work"], nums = []
        for (var i = 0; i < 3; ++i) {
            var n = numFields.itemAt(i).text.trim()
            if (n !== "") nums.push({ label: labels[i], number: n })
        }
        if (name === "") name = nums.length > 0 ? nums[0].number : fMail.text.trim()
        if (name === "") return
        var c = contacts.slice()
        if (editId === "") {
            var id = "c" + Date.now() + Math.floor(Math.random() * 1000)
            c.push({ id: id, name: name, numbers: nums, email: fMail.text.trim(), note: fNote.text.trim(), fav: false })
            selId = id
        } else {
            for (var j = 0; j < c.length; ++j) if (c[j].id === editId)
                c[j] = Object.assign({}, c[j], { name: name, numbers: nums, email: fMail.text.trim(), note: fNote.text.trim() })
        }
        contacts = c; persist()
        editOpen = false
        detailOpen = true
    }
    function deleteSel() {
        var c = contacts.filter(function(x) { return x.id !== selId })
        contacts = c; persist()
        confirmDelete = false; detailOpen = false; selId = ""
    }
    function back() {
        if (editOpen) { editOpen = false; if (editId === "") detailOpen = false }
        else if (detailOpen) detailOpen = false
        else closeRequested()
    }

    focus: true
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
    Component.onCompleted: load()
    onVisibleChanged: if (visible) load()

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: root.topInset

        Pivot {
            id: pivot
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: bar.top
            caption: "people"

            PivotPage {
                title: "all"
                MetroTextField {
                    width: parent.width
                    placeholder: "search"
                    text: root.query
                    onEdited: root.query = text
                }
                Item { width: 1; height: 12 }
                Text {
                    visible: root.entries.length === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: root.contacts.length === 0 ? "no contacts yet. tap + to add one." : "no matches"
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
                Repeater {
                    model: root.entries
                    Item {
                        id: row
                        required property var modelData
                        width: parent.width
                        height: modelData.kind === "header" ? 64 : 68
                        Rectangle {
                            visible: row.modelData.kind === "header"
                            y: 8; width: 48; height: 48
                            color: "transparent"; border.width: 2; border.color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.letter || ""; color: Theme.accent
                                font.family: Theme.font; font.weight: Font.Light; font.pixelSize: 28
                            }
                        }
                        MetroListRow {
                            visible: row.modelData.kind === "contact"
                            anchors.fill: parent
                            title: row.modelData.name || ""
                            subtitle: row.modelData.sub || ""
                            onClicked: root.openDetail(row.modelData.id)
                        }
                    }
                }
            }

            PivotPage {
                id: favPage
                title: "favourites"
                readonly property real tile: Math.floor((width - margin * 2 - Theme.tileGap) / 2)
                Text {
                    visible: root.favs.length === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: "no favourites. open a contact and tap the star."
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
                Flow {
                    width: parent.width
                    spacing: Theme.tileGap
                    Repeater {
                        model: root.favs
                        Rectangle {
                            id: tl
                            required property var modelData
                            width: favPage.tile; height: favPage.tile
                            color: Theme.accent
                            scale: tma.pressed ? 0.96 : 1
                            Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: 90 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.initials(tl.modelData.name)
                                color: Theme.onColor(Theme.accent)
                                font.family: Theme.font; font.weight: Font.Light; font.pixelSize: Math.round(tl.width * 0.36)
                            }
                            Text {
                                x: 10; width: parent.width - 20; y: parent.height - height - 8
                                text: tl.modelData.name; elide: Text.ElideRight
                                color: Theme.onColor(Theme.accent)
                                font.family: Theme.font; font.pixelSize: 20
                            }
                            MouseArea { id: tma; anchors.fill: parent; onClicked: root.openDetail(tl.modelData.id) }
                        }
                    }
                }
            }
        }

        AppBar {
            id: bar
            anchors.bottom: parent.bottom
            items: [{ glyph: "plus", label: "new" }]
            onActivated: (i) => root.startEdit("")
        }

        // ---- detail ----
        Item {
            id: detail
            width: parent.width; height: parent.height
            x: root.detailOpen ? 0 : width
            visible: x < width
            Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; color: Theme.pageBg }
            MouseArea { anchors.fill: parent }

            Flickable {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.bottom: dBar.top
                contentWidth: width; contentHeight: dCol.implicitHeight + 40
                boundsBehavior: Flickable.StopAtBounds; clip: true
                Column {
                    id: dCol
                    x: 18; y: 24; width: parent.width - 36; spacing: 0
                    Text {
                        text: "PEOPLE"; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                        text: root.selected ? root.selected.name : ""
                        color: Theme.text
                        font.family: Theme.font; font.pixelSize: 48; font.weight: Theme.fontLight
                    }
                    Item { width: 1; height: 20 }
                    Repeater {
                        model: root.selected ? root.selected.numbers : []
                        Item {
                            id: nr
                            required property var modelData
                            width: parent.width; height: 76
                            opacity: nma.pressed ? 0.6 : 1
                            Text {
                                text: nr.modelData.label; color: Theme.textDim
                                font.family: Theme.font; font.pixelSize: 18
                            }
                            Text {
                                y: 22; width: parent.width; elide: Text.ElideRight
                                text: nr.modelData.number; color: Theme.accent
                                font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight
                            }
                            MouseArea { id: nma; anchors.fill: parent
                                onClicked: Qt.openUrlExternally("tel:" + String(nr.modelData.number).replace(/[^0-9+*#]/g, "")) }
                        }
                    }
                    Item {
                        visible: !!root.selected && root.selected.email !== ""
                        width: parent.width; height: visible ? 76 : 0
                        Text { text: "email"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                        Text {
                            y: 22; width: parent.width; elide: Text.ElideRight
                            text: root.selected ? root.selected.email : ""; color: Theme.text
                            font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                        }
                    }
                    Item {
                        visible: !!root.selected && root.selected.note !== ""
                        width: parent.width; height: visible ? noteT.y + noteT.height + 16 : 0
                        Text { text: "note"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                        Text {
                            id: noteT
                            y: 22; width: parent.width; wrapMode: Text.Wrap
                            text: root.selected ? root.selected.note : ""; color: Theme.text
                            font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                        }
                    }
                    Item { width: 1; height: 12; visible: root.confirmDelete }
                    Text {
                        visible: root.confirmDelete
                        width: parent.width; wrapMode: Text.Wrap
                        text: "delete this contact?"; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 24
                    }
                    Row {
                        visible: root.confirmDelete
                        spacing: 12; topPadding: 12
                        MetroButton { text: "delete"; accentFill: true; onClicked: root.deleteSel() }
                        MetroButton { text: "cancel"; onClicked: root.confirmDelete = false }
                    }
                }
            }
            AppBar {
                id: dBar
                anchors.bottom: parent.bottom
                items: [{ glyph: "back", label: "back" }, { glyph: "star", label: root.selected && root.selected.fav ? "unstar" : "star" },
                        { glyph: "notes", label: "edit" }]
                menuItems: ["delete"]
                onActivated: (i) => {
                    if (i === 0) root.detailOpen = false
                    else if (i === 1) root.toggleFav(root.selId)
                    else root.startEdit(root.selId)
                }
                onMenuActivated: (i) => root.confirmDelete = true
            }
        }

        // ---- edit ----
        Item {
            id: edit
            width: parent.width; height: parent.height
            x: root.editOpen ? 0 : width
            visible: x < width
            Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; color: Theme.pageBg }
            MouseArea { anchors.fill: parent }

            Flickable {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.bottom: eBar.top
                contentWidth: width; contentHeight: eCol.implicitHeight + 60
                boundsBehavior: Flickable.StopAtBounds; clip: true
                Column {
                    id: eCol
                    x: 18; y: 24; width: parent.width - 36; spacing: 12
                    Text {
                        text: "PEOPLE"; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
                    }
                    Text {
                        text: root.editId === "" ? "new" : "edit"; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
                    }
                    MetroTextField { id: fName; width: parent.width; label: "name" }
                    Repeater {
                        id: numFields
                        model: ["mobile", "home", "work"]
                        MetroTextField {
                            required property string modelData
                            width: eCol.width; label: modelData
                            inputMethodHints: Qt.ImhDialableCharactersOnly
                        }
                    }
                    MetroTextField { id: fMail; width: parent.width; label: "email"; inputMethodHints: Qt.ImhEmailCharactersOnly }
                    MetroTextField { id: fNote; width: parent.width; label: "note" }
                }
            }
            AppBar {
                id: eBar
                anchors.bottom: parent.bottom
                items: [{ glyph: "forward", label: "save" }, { glyph: "close", label: "cancel" }]
                onActivated: (i) => { if (i === 0) root.saveEdit(); else root.back() }
            }
        }
    }
}
