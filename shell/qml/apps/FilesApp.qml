import QtQuick
import Qt.labs.folderlistmodel
import FlowShell

// Files: real filesystem browser (read-only). Pivot "files": browse | places.
// API: goUp() goes to the parent folder, or emits closeRequested at the root (home or "/").
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    focus: true

    // ---- state ----
    property string homePath: "/"
    property string path: "/"
    property string sortBy: "name"        // name | date | size
    property bool showHidden: false
    property bool _loaded: false
    property var sel: null                // row the action sheet is about
    property bool sheetOpen: false
    property bool detailsMode: false

    readonly property bool atRoot: path === homePath || path === "/"

    function _toUrl(p) {
        var u = encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F")
        return "file://" + u
    }
    function _parent(p) {
        var r = p.replace(/\/[^\/]+\/*$/, "")
        return r === "" ? "/" : r
    }
    function _stripHome(s) {
        s = String(s)
        if (s.indexOf("file://") === 0) s = s.substring(7)
        try { s = decodeURIComponent(s) } catch (e) { }
        var i = s.indexOf("/.config")
        return i > 0 ? s.substring(0, i) : ""
    }
    function _humanSize(n) {
        if (n < 1024) return n + " B"
        var u = ["KB", "MB", "GB", "TB"], v = n / 1024, i = 0
        while (v >= 1024 && i < u.length - 1) { v /= 1024; ++i }
        return (v >= 10 ? Math.round(v) : Math.round(v * 10) / 10) + " " + u[i]
    }
    function _date(d) { return Qt.formatDateTime(d, "yyyy-MM-dd HH:mm") }
    function _segments() {
        var out = [{ label: "/", path: "/" }]
        var parts = path.split("/"), acc = ""
        for (var i = 0; i < parts.length; ++i) {
            if (parts[i] === "") continue
            acc += "/" + parts[i]
            out.push({ label: parts[i], path: acc })
        }
        return out
    }
    function go(p) {
        if (p === "") p = "/"
        path = p
        closeSheet()
    }
    function back() { goUp() }
    function goUp() {
        if (sheetOpen) { closeSheet(); return }
        if (atRoot) { closeRequested(); return }
        path = _parent(path)
    }
    function closeSheet() { sheetOpen = false; detailsMode = false }
    function openSheet(row) { sel = row; detailsMode = false; sheetOpen = true }
    function openEntry(row) {
        if (row.isDir) go(row.path)
        else Qt.openUrlExternally(row.url)
    }
    function copyText(t) { clip.text = t; clip.selectAll(); clip.copy() }
    function _save() {
        if (!_loaded) return
        AppStore.save("files", { sort: sortBy, hidden: showHidden })
    }

    Component.onCompleted: {
        var h = ""
        try { h = _stripHome(AppStore.dir()) } catch (e) { }
        homePath = h !== "" ? h : "/"
        path = homePath
        var s = AppStore.load("files", {})
        if (s && s.sort) sortBy = s.sort
        if (s && s.hidden !== undefined) showHidden = !!s.hidden
        _loaded = true
        forceActiveFocus()
    }

    Keys.onBackPressed: goUp()
    Keys.onEscapePressed: goUp()

    TextEdit { id: clip; visible: false }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    FolderListModel {
        id: fm
        folder: root._toUrl(root.path)
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        sortField: root.sortBy === "date" ? FolderListModel.Time
                 : root.sortBy === "size" ? FolderListModel.Size : FolderListModel.Name
        sortReversed: root.sortBy !== "name"
    }

    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - bar.collapsedH
        caption: "files"

        Item {
            property string title: "browse"

            // breadcrumb
            Flickable {
                id: crumbs
                width: parent.width; height: 48
                clip: true
                contentWidth: crumbRow.width + 36; contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                // keep the tail (current folder) visible: the head scrolls off to the left
                function _tail() { contentX = Math.max(0, contentWidth - width) }
                onContentWidthChanged: _tail()
                onWidthChanged: _tail()
                Row {
                    id: crumbRow
                    x: 18; height: parent.height
                    Repeater {
                        model: root._segments()
                        Item {
                            id: seg
                            required property int index
                            required property var modelData
                            readonly property bool last: index === root._segments().length - 1
                            width: segText.width + 12; height: 48
                            Text {
                                id: segText
                                x: 0; anchors.verticalCenter: parent.verticalCenter
                                text: seg.modelData.label + (seg.index > 0 && !seg.last ? " /" : "")
                                color: seg.last ? Theme.text : Theme.textDim
                                font.family: Theme.font; font.pixelSize: 20
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.go(seg.modelData.path) }
                        }
                    }
                }
            }

            ListView {
                id: list
                y: crumbs.height
                width: parent.width; height: parent.height - crumbs.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: fm
                delegate: MetroListRow {
                    id: row
                    required property string fileName
                    required property string filePath
                    required property url fileUrl
                    required property double fileSize
                    required property date fileModified
                    required property bool fileIsDir
                    width: list.width - 36
                    x: 18
                    glyph: "files"
                    iconColor: fileIsDir ? Theme.accent : (Theme.dark ? "#3a3a3a" : "#9a9a9a")
                    title: fileName
                    subtitle: fileIsDir ? root._date(fileModified)
                                        : root._humanSize(fileSize) + "  " + root._date(fileModified)
                    function _row() {
                        return { name: fileName, path: filePath, url: fileUrl.toString(), size: fileSize,
                                 modified: fileModified, isDir: fileIsDir }
                    }
                    onClicked: root.openEntry(_row())
                    onPressAndHold: root.openSheet(_row())
                }
                footer: Item { width: 1; height: 24 }
            }

            Text {
                visible: fm.status === FolderListModel.Ready && list.count === 0
                anchors.centerIn: parent
                text: "this folder is empty"
                color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
        }

        PivotPage {
            title: "places"
            Repeater {
                model: [
                    { name: "Home", p: root.homePath },
                    { name: "Documents", p: root.homePath + "/Documents" },
                    { name: "Downloads", p: root.homePath + "/Downloads" },
                    { name: "Pictures", p: root.homePath + "/Pictures" },
                    { name: "Music", p: root.homePath + "/Music" },
                    { name: "Videos", p: root.homePath + "/Videos" },
                    { name: "Desktop", p: root.homePath + "/Desktop" },
                    { name: "/", p: "/" }
                ]
                MetroListRow {
                    required property var modelData
                    glyph: "files"
                    title: modelData.name
                    subtitle: modelData.p
                    onClicked: { root.go(modelData.p); pivot.goTo(0) }
                }
            }
        }
    }

    AppBar {
        id: bar
        anchors.bottom: parent.bottom
        items: [
            { glyph: "back", label: "up" },
            { glyph: "files", label: "home" }
        ]
        menuItems: [
            "sort by name" + (root.sortBy === "name" ? " *" : ""),
            "sort by date" + (root.sortBy === "date" ? " *" : ""),
            "sort by size" + (root.sortBy === "size" ? " *" : ""),
            root.showHidden ? "hide hidden files" : "show hidden files"
        ]
        onActivated: function(i) {
            if (i === 0) { if (root.atRoot) root.go(root._parent(root.path)); else root.goUp() }
            else { root.go(root.homePath); pivot.goTo(0) }
        }
        onMenuActivated: function(i) {
            if (i === 0) root.sortBy = "name"
            else if (i === 1) root.sortBy = "date"
            else if (i === 2) root.sortBy = "size"
            else root.showHidden = !root.showHidden
            root._save()
        }
    }

    // ---- action sheet ----
    property real sheetP: sheetOpen ? 1 : 0
    Behavior on sheetP { enabled: !Theme.reduceMotion
        NumberAnimation { duration: root.sheetOpen ? 260 : 180; easing.type: root.sheetOpen ? Easing.OutCubic : Easing.InCubic } }

    Item {
        id: sheet
        anchors.fill: parent
        z: 100
        visible: root.sheetP > 0.001
        MouseArea { anchors.fill: parent; onClicked: root.closeSheet() }
        Rectangle { anchors.fill: parent; color: Theme.pageBg; opacity: 0.6 * root.sheetP }
        Rectangle {
            id: panel
            width: parent.width
            height: 20 + 36 + (root.detailsMode ? detailCol.height + 24 : actions.height + 12)
            y: parent.height - height * root.sheetP
            color: Theme.dark ? "#1b1b1b" : "#e9e9e9"
            MouseArea { anchors.fill: parent }
            Text {
                x: 18; y: 16; width: parent.width - 36
                text: root.sel ? root.sel.name : ""
                elide: Text.ElideMiddle
                color: Theme.text
                font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
            }
            Column {
                id: actions
                y: 56; width: parent.width
                visible: !root.detailsMode
                Repeater {
                    model: ["open", "copy path", "details"]
                    Item {
                        required property int index
                        required property string modelData
                        width: actions.width; height: 64
                        opacity: ar.pressed ? 0.6 : 1
                        Text {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            text: modelData; color: Theme.text
                            font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                        }
                        MouseArea {
                            id: ar; anchors.fill: parent
                            onClicked: {
                                var s = root.sel
                                if (!s) return
                                if (index === 0) { root.closeSheet(); root.openEntry(s) }
                                else if (index === 1) { root.copyText(s.path); root.closeSheet() }
                                else root.detailsMode = true
                            }
                        }
                    }
                }
            }
            Column {
                id: detailCol
                x: 18; y: 56; width: parent.width - 36
                visible: root.detailsMode
                spacing: 8
                Repeater {
                    model: root.sel ? [
                        { k: "name", v: root.sel.name },
                        { k: "type", v: root.sel.isDir ? "folder" : "file" },
                        { k: "size", v: root.sel.isDir ? "-" : root._humanSize(root.sel.size) + " (" + root.sel.size + " bytes)" },
                        { k: "modified", v: root._date(root.sel.modified) },
                        { k: "path", v: root.sel.path }
                    ] : []
                    Column {
                        required property var modelData
                        width: detailCol.width
                        Text { text: modelData.k; color: Theme.textDim
                            font.family: Theme.font; font.pixelSize: 18 }
                        Text { width: parent.width; text: modelData.v; color: Theme.text; wrapMode: Text.WrapAnywhere
                            font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight }
                    }
                }
            }
        }
    }
}
