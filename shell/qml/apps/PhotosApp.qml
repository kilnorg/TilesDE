import QtQuick
import FlowShell

// Photos: all / albums / favourites. Images come from Sys.listDir over ~/Pictures, ~/Downloads, ~/Desktop.
// Favourites persisted under AppStore "photos" ({favs: [path...]}).
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var photos: []          // [{path,name,size,mod,dir}] newest first
    property var favs: []            // paths
    property var albums: []          // [{dir,name,count,items}]
    property string albumDir: ""     // drill-down
    property var albumItems: []
    // viewer
    property bool viewing: false
    property var viewList: []
    property int viewIndex: 0
    property bool showInfo: false
    property string toast: ""
    readonly property var cur: viewing && viewIndex >= 0 && viewIndex < viewList.length ? viewList[viewIndex] : null
    readonly property var favPhotos: photos.filter(function(p) { return favs.indexOf(p.path) >= 0 })
    readonly property real gap: 3

    function dirOf(p) { var i = p.lastIndexOf("/"); return i > 0 ? p.substring(0, i) : "/" }
    function folderName(d) { var i = d.lastIndexOf("/"); return i >= 0 ? d.substring(i + 1) : d }
    function isFav(p) { return favs.indexOf(p) >= 0 }
    function fmtSize(b) { return b > 1048576 ? (b / 1048576).toFixed(1) + " mb" : Math.max(1, Math.round(b / 1024)) + " kb" }
    function fmtDate(t) { return t > 0 ? new Date(t).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : "" }
    function toggleFav(p) {
        var f = favs.slice(), i = f.indexOf(p)
        if (i >= 0) f.splice(i, 1); else f.push(p)
        favs = f
        AppStore.save("photos", { favs: f })
    }
    function flash(t) { toast = t; toastTimer.restart() }

    function scan() {
        var h = Sys.home()
        var exts = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
        var seen = {}, all = []
        var dirs = [h + "/Pictures", h + "/Downloads", h + "/Desktop"]
        for (var d = 0; d < dirs.length; ++d) {
            if (!Sys.exists(dirs[d])) continue
            var l = Sys.listDir(dirs[d], exts, true, 500)
            for (var i = 0; i < l.length; ++i) {
                var e = l[i]
                if (seen[e.path]) continue
                seen[e.path] = true
                var t = new Date(e.modified).getTime()
                all.push({ path: e.path, name: e.name, size: e.size, mod: isNaN(t) ? 0 : t, dir: dirOf(e.path) })
            }
        }
        all.sort(function(a, b) { return b.mod - a.mod })
        if (all.length > 500) all.length = 500
        photos = all
        var m = {}, al = []
        for (var k = 0; k < all.length; ++k) {
            var p = all[k]
            if (!m[p.dir]) { m[p.dir] = { dir: p.dir, name: folderName(p.dir), count: 0, items: [] }; al.push(m[p.dir]) }
            m[p.dir].count++; m[p.dir].items.push(p)
        }
        albums = al
    }
    function openViewer(list, i) { viewList = list; viewIndex = i; showInfo = false; viewing = true }
    function step(d) {
        var n = viewIndex + d
        if (n >= 0 && n < viewList.length) { viewIndex = n; showInfo = false }
    }
    Component.onCompleted: {
        var s = AppStore.load("photos", { favs: [] })
        favs = (s && s.favs) ? s.favs : []
        scan()
    }

    // ---- reusable square thumbnail ----
    component Thumb: Item {
        id: th
        property var photo
        property bool inView: true
        signal activated
        Rectangle { anchors.fill: parent; color: Theme.dark ? "#222222" : "#dddddd" }
        Image {
            anchors.fill: parent
            source: th.inView && th.photo ? "file://" + th.photo.path : ""
            sourceSize: Qt.size(Math.ceil(th.width), Math.ceil(th.height))
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            opacity: ta.pressed ? 0.6 : 1
        }
        TileGlyph {
            visible: th.photo && root.isFav(th.photo.path)
            x: parent.width - 28; y: 4; size: 22; name: "star"; color: Theme.accent
        }
        MouseArea { id: ta; anchors.fill: parent; onClicked: th.activated() }
    }

    Pivot {
        id: pivot
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "photos"

        PivotPage {
            id: allPage
            title: "all"
            readonly property real cell: Math.floor((width - 36 - root.gap * 2) / 3)
            Text {
                visible: root.photos.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no pictures yet - put some in ~/Pictures"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
            }
            Flow {
                width: parent.width; spacing: root.gap
                Repeater {
                    model: root.photos
                    Thumb {
                        required property var modelData
                        required property int index
                        photo: modelData
                        width: allPage.cell; height: allPage.cell
                        inView: y + height + 400 > allPage.contentY && y < allPage.contentY + allPage.height + 400
                        onActivated: root.openViewer(root.photos, index)
                    }
                }
            }
        }

        PivotPage {
            title: "albums"
            Text {
                visible: root.albums.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no pictures yet - put some in ~/Pictures"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.albums
                MetroListRow {
                    required property var modelData
                    glyph: "photos"
                    title: modelData.name
                    subtitle: modelData.count + (modelData.count === 1 ? " picture" : " pictures")
                    onClicked: { root.albumDir = modelData.dir; root.albumItems = modelData.items }
                }
            }
        }

        PivotPage {
            id: favPage
            title: "favourites"
            readonly property real cell: Math.floor((width - 36 - root.gap * 2) / 3)
            Text {
                visible: root.favPhotos.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no favourites yet - open a picture and tap the star"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
            }
            Flow {
                width: parent.width; spacing: root.gap
                Repeater {
                    model: root.favPhotos
                    Thumb {
                        required property var modelData
                        required property int index
                        photo: modelData
                        width: favPage.cell; height: favPage.cell
                        inView: y + height + 400 > favPage.contentY && y < favPage.contentY + favPage.height + 400
                        onActivated: root.openViewer(root.favPhotos, index)
                    }
                }
            }
        }
    }

    // ---- album drill-down ----
    Item {
        id: drill
        anchors.fill: parent
        visible: root.albumDir !== ""
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Text {
            x: 18; y: root.topInset + 24
            text: "ALBUM"; color: Theme.text
            font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
        }
        Text {
            id: dtitle
            x: 18; y: root.topInset + 52; width: parent.width - 36
            text: Theme.title(root.folderName(root.albumDir)); color: Theme.text; elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
        }
        GridView {
            id: dgrid
            x: 18; y: dtitle.y + dtitle.height + 12
            width: parent.width - 36; height: parent.height - y - dbar.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            cellWidth: Math.floor(width / 3); cellHeight: cellWidth
            model: root.albumItems
            delegate: Item {
                required property var modelData
                required property int index
                width: dgrid.cellWidth; height: dgrid.cellHeight
                Thumb {
                    anchors.fill: parent; anchors.margins: root.gap / 2
                    photo: modelData
                    onActivated: root.openViewer(root.albumItems, index)
                }
            }
        }
        AppBar {
            id: dbar
            anchors.bottom: parent.bottom
            items: [{ glyph: "back", label: "back" }]
            onActivated: root.albumDir = ""
        }
    }

    // ---- full-screen viewer ----
    Item {
        id: viewer
        anchors.fill: parent
        visible: root.viewing || x > 0
        x: root.viewing ? 0 : width
        Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Rectangle { anchors.fill: parent; color: "black" }
        MouseArea { anchors.fill: parent }

        Item {
            id: stage
            anchors.fill: parent
            clip: true
            Item {
                id: zoomBox
                width: stage.width; height: stage.height
                property real swipeX: 0
                x: swipeX
                Image {
                    id: big
                    anchors.fill: parent
                    source: root.cur ? "file://" + root.cur.path : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    autoTransform: true
                    sourceSize: Qt.size(stage.width * 2, stage.height * 2)
                    transformOrigin: Item.Center
                    onSourceChanged: { scale = 1; x = 0; y = 0 }
                }
                PinchHandler {
                    id: pinch
                    target: big
                    minimumScale: 1; maximumScale: 6
                    minimumRotation: 0; maximumRotation: 0
                    onActiveChanged: if (!active && big.scale < 1.02) { big.scale = 1; big.x = 0; big.y = 0 }
                }
                // pan while zoomed
                DragHandler {
                    target: big
                    enabled: big.scale > 1.02
                    minimumPointCount: 1; maximumPointCount: 1
                }
                // swipe neighbours when not zoomed
                DragHandler {
                    id: swipeH
                    target: null
                    enabled: big.scale <= 1.02
                    xAxis.enabled: true; yAxis.enabled: false
                    onTranslationChanged: if (active) zoomBox.swipeX = translation.x
                    onActiveChanged: {
                        if (active) return
                        var dx = zoomBox.swipeX, th = stage.width * 0.2
                        zoomBox.swipeX = 0
                        if (dx < -th) root.step(1)
                        else if (dx > th) root.step(-1)
                    }
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onDoubleTapped: {
                        if (big.scale > 1.02) { big.scale = 1; big.x = 0; big.y = 0 }
                        else big.scale = 2.5
                    }
                }
            }
        }
        Text {
            visible: big.status === Image.Error
            anchors.centerIn: parent
            text: "cannot open this picture"
            color: "white"; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
        }

        // top caption
        Rectangle { x: 0; y: 0; width: parent.width; height: root.topInset + 52; color: "#99000000" }
        Text {
            x: 18; y: root.topInset + 8; width: parent.width - 36
            text: root.cur ? root.cur.name : ""
            color: "white"; elide: Text.ElideMiddle
            font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
        }
        Text {
            visible: root.viewList.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.topInset + 34
            text: (root.viewIndex + 1) + " / " + root.viewList.length
            color: "#bbbbbb"; font.family: Theme.font; font.pixelSize: 16
        }

        // info panel
        Column {
            visible: root.showInfo && root.cur
            x: 18; width: parent.width - 36
            anchors.bottom: vbar.top; anchors.bottomMargin: 12
            Text { width: parent.width; wrapMode: Text.WrapAnywhere; color: "white"; font.family: Theme.font; font.pixelSize: 18
                text: root.cur ? root.cur.path : "" }
            Text { color: "#bbbbbb"; font.family: Theme.font; font.pixelSize: 18
                text: root.cur ? root.fmtSize(root.cur.size) + (big.implicitWidth > 0 ? "  -  " + big.implicitWidth + " x " + big.implicitHeight : "") +
                      (root.cur.mod > 0 ? "  -  " + root.fmtDate(root.cur.mod) : "") : "" }
        }
        Text {
            visible: root.toast !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: vbar.top; anchors.bottomMargin: 60
            text: root.toast; color: "white"
            font.family: Theme.font; font.pixelSize: 20; font.weight: Theme.fontLight
        }
        Timer { id: toastTimer; interval: 2200; onTriggered: root.toast = "" }

        AppBar {
            id: vbar
            anchors.bottom: parent.bottom
            items: [
                { glyph: "back", label: "back" },
                { glyph: "star", label: root.cur && root.isFav(root.cur.path) ? "unfavourite" : "favourite" },
                { glyph: "lock", label: "lock screen" },
                { glyph: "notes", label: "info" }
            ]
            onActivated: function(i) {
                if (i === 0) root.viewing = false
                else if (i === 1 && root.cur) root.toggleFav(root.cur.path)
                else if (i === 2 && root.cur) {
                    if (typeof Personalise !== "undefined" && Personalise.set("startPhoto", root.cur.path))
                        root.flash("set as lock-screen photo")
                    else root.flash("cannot set lock-screen photo")
                }
                else if (i === 3) root.showInfo = !root.showInfo
            }
        }
    }

    focus: true
    function back() {
        if (viewing) viewing = false
        else if (albumDir !== "") albumDir = ""
        else closeRequested()
    }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
