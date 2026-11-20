import QtQuick
import FlowShell

// Store: Alpine/postmarketOS apk (apk search/info/add/del via sudo) + Flathub (appstream API v2, flatpak --user). All work is async in StoreBackend (src/StoreBackend.*).
// Offline: apk keeps working, Flathub falls back to the API cache in ~/.cache/tilesde/store; icons and screenshots are cached there too.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    StoreBackend { id: be }

    // ---- state
    property string query: ""
    property string category: "all"
    property int token: 1
    property var apkItems: []
    property var flatItems: []
    property bool flatMore: false
    property int flatPage: 1
    property string flatState: "loading"      // loading | ok | cached | offline
    property bool apkDone: false
    property var featApk: []
    property var featFlat: []
    property var instItems: []
    property bool instLoaded: false
    property var updItems: []
    property string updNote: "tap check to look for updates"
    property bool updChecking: false
    property bool detailOpen: false
    property var cur: ({})                    // item shown in the detail sheet (summary data, then replaced by full details)
    property bool detailLoading: false
    property string detailError: ""
    property bool confirmRemove: false
    property var gameApk: []
    property var gameFlat: []
    readonly property var games: gameFlat.slice(0, 12).concat(gameApk)
    property bool pwOpen: false
    property string pwError: ""
    property var pwPending: null           // function to run once the sudo password is verified
    function needPw(fn) {
        if (be.needsPassword) { pwPending = fn; pwError = ""; pwOpen = true; pwField.text = ""; return true }
        return false
    }
    property string toast: ""
    readonly property var categories: ["all", "internet", "media", "graphics", "office", "utilities", "development", "games", "system", "education", "science"]
    readonly property var merged: apkItems.concat(flatItems)
    readonly property var featured: featFlat.slice(0, 2).concat(featApk.slice(0, 1))

    function key(src, id) { return src + ":" + id }
    function isInstalled(src, id) { return be.installedKeys[src + ":" + id] !== undefined }
    function sourceLabel(src) { return src === "apk" ? "apk" : "flathub" }
    function reload() {
        token++
        apkItems = []; flatItems = []; flatMore = false; flatPage = 1; flatState = "loading"; apkDone = false
        if (query.trim().length >= 2) be.search(token, query.trim()); else be.browse(token, category, 1)
    }
    function loadMore() { if (flatMore) be.browse(token, category, flatPage + 1) }
    function openDetail(item) {
        cur = item; detailOpen = true; detailLoading = true; detailError = ""; confirmRemove = false
        be.details(item.source, item.id)
    }
    function say(t) { toast = t; toastTimer.restart() }
    function doInstall() {
        var src = cur.source, id = cur.id
        if (src === "apk" && needPw(function() { be.install(src, id) })) return
        be.install(src, id)
    }
    function doRemove() {
        if (!confirmRemove) { confirmRemove = true; confirmTimer.restart(); return }
        confirmRemove = false
        var src = cur.source, id = cur.id
        if (src === "apk" && needPw(function() { be.remove(src, id) })) return
        be.remove(src, id)
    }
    function doUpdateAll() {
        if (needPw(function() { be.upgradeAll() })) return
        be.upgradeAll()
    }
    function doCheck() {
        updChecking = true
        if (needPw(function() { be.checkUpdates(true) })) { updChecking = false; return }
        be.checkUpdates(true)
    }

    Component.onCompleted: { be.refresh(); be.browse(0, "all", 1); be.browse(-1, "games", 1); reload() }
    Timer { id: searchTimer; interval: 400; onTriggered: root.reload() }
    Timer { id: toastTimer; interval: 5000; onTriggered: root.toast = "" }
    Timer { id: confirmTimer; interval: 4000; onTriggered: root.confirmRemove = false }

    Connections {
        target: be
        function onResults(tok, source, items, page, hasMore, offline) {
            if (tok === 0) {
                if (source === "apk") root.featApk = items; else root.featFlat = items
                return
            }
            if (tok === -1) {
                if (source === "apk") root.gameApk = items; else root.gameFlat = items
                return
            }
            if (tok !== root.token) return
            if (source === "apk") { root.apkItems = items; root.apkDone = true; return }
            root.flatItems = page > 1 ? root.flatItems.concat(items) : items
            root.flatPage = page; root.flatMore = hasMore
            root.flatState = offline ? "cached" : "ok"
        }
        function onSearchFailed(tok, source, msg) {
            if (tok === root.token && source === "flathub") root.flatState = "offline"
        }
        function onDetailsReady(d) {
            if (!root.detailOpen || d.id !== root.cur.id || d.source !== root.cur.source) return
            var m = {}
            for (var k in root.cur) m[k] = root.cur[k]
            for (var j in d) if (d[j] !== "" && d[j] !== undefined) m[j] = d[j]
            root.cur = m; root.detailLoading = false
        }
        function onDetailsFailed(src, id, msg) {
            if (root.detailOpen && id === root.cur.id) { root.detailLoading = false; root.detailError = msg }
        }
        function onPasswordChecked(ok) {
            if (ok) { root.pwOpen = false; var f = root.pwPending; root.pwPending = null; if (f) f() }
            else root.pwError = "wrong password"
        }
        function onInstalledListReady(items) { root.instItems = items; root.instLoaded = true }
        function onUpdatesReady(items, refreshed, note) {
            root.updChecking = false; root.updItems = items
            var base = items.length === 0 ? "everything is up to date" : items.length + (items.length === 1 ? " update available" : " updates available")
            root.updNote = note !== "" ? base + ". " + note : base
        }
        function onOpFinished(ok, title, msg) {
            root.say(ok ? title.replace("ing ", "ed ").replace("updated", "updated") + " - done" : title + " failed: " + msg)
            root.confirmRemove = false
            if (ok && title.indexOf("updating") === 0) be.checkUpdates(false)
        }
    }

    focus: true
    function back() { if (pwOpen) pwOpen = false; else if (detailOpen) detailOpen = false; else closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    // ---- shared pieces
    component RemoteImage: Item {
        id: ri
        property string url: ""
        property var backend: be
        property int fillMode: Image.PreserveAspectFit
        property int decodeW: 256
        readonly property bool ready: img.status === Image.Ready
        function load() {
            if (url === "") { img.source = ""; return }
            var p = ri.backend.cachedImage(url)
            img.source = p !== "" ? "file://" + p : ""
        }
        onUrlChanged: load()
        Component.onCompleted: load()
        Connections {
            target: ri.backend
            function onImageReady(u, p) { if (u === ri.url) img.source = "file://" + p }
        }
        Image {
            id: img
            anchors.fill: parent
            fillMode: ri.fillMode
            asynchronous: true
            sourceSize.width: ri.decodeW
            smooth: true
        }
    }

    component AppIcon: Item {
        id: ai
        property var item: ({})
        property real size: 56
        width: size; height: size
        Rectangle {
            anchors.fill: parent; color: Theme.accent
            visible: !icon.ready
            Text {
                anchors.centerIn: parent
                text: ai.item && ai.item.name ? String(ai.item.name).charAt(0).toUpperCase() : "?"
                color: Theme.onColor(Theme.accent); font.family: Theme.font; font.pixelSize: ai.size * 0.5; font.weight: Theme.fontLight
            }
        }
        RemoteImage { id: icon; anchors.fill: parent; url: ai.item && ai.item.icon ? ai.item.icon : "" }
    }

    component StoreRow: Item {
        id: sr
        property var item: ({})
        signal clicked
        width: parent ? parent.width : 360; height: 76
        opacity: ra.pressed ? 0.6 : 1
        AppIcon { id: sic; item: sr.item; size: 56; y: 10 }
        Column {
            x: 72; y: 8; width: parent.width - 72 - (tr.visible ? tr.width + 10 : 0)
            Text {
                width: parent.width; elide: Text.ElideRight; text: sr.item.name || ""
                color: Theme.text; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.sourceLabel(sr.item.source) + (sr.item.summary ? "  ·  " + sr.item.summary : "")
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
            }
        }
        Text {
            id: tr
            visible: text !== ""
            anchors.right: parent.right; y: 12
            text: root.isInstalled(sr.item.source, sr.item.id) ? "installed" : ""
            color: Theme.accent; font.family: Theme.font; font.pixelSize: 18
        }
        MouseArea { id: ra; anchors.fill: parent; onClicked: sr.clicked() }
    }

    component Hint: Text {
        width: parent ? parent.width : 300
        wrapMode: Text.WordWrap
        color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
    }

    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - (opBar.visible ? opBar.height : 0)
        caption: "store"

        PivotPage {
            title: "featured"
            Hint {
                visible: be.escalation === "none"
                text: "no sudo here: apk installs open in a terminal instead."
            }
            Hint { visible: root.flatState === "offline"; text: "offline: flathub unavailable, showing apk only." }
            Repeater {
                model: root.featured
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property color tint: index === 0 ? Theme.accent : (index === 1 ? Qt.darker(Theme.accent, 1.5) : Qt.darker(Theme.accent, 2.2))
                    width: parent.width; height: index === 0 ? 288 : 188
                    Rectangle {
                        width: parent.width; height: index === 0 ? 280 : 180; color: parent.tint
                        opacity: fma.pressed ? 0.7 : 1
                        Column {
                            x: 16; y: 14; width: parent.width - 32 - (tileIcon.ready ? (tile.index === 0 ? 160 : 96) : 0); spacing: 4
                            Text {
                                width: parent.width; elide: Text.ElideRight; text: tile.modelData.name.toLowerCase()
                                color: Theme.onColor(tile.tint)
                                font.family: Theme.font; font.pixelSize: tile.index === 0 ? 56 : 44; font.weight: Theme.fontLight
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                text: tile.modelData.summary
                                color: Theme.onColor(tile.tint); opacity: 0.85
                                font.family: Theme.font; font.pixelSize: 22
                            }
                        }
                        RemoteImage { id: tileIcon; x: parent.width - (tile.index === 0 ? 176 : 112); y: tile.index === 0 ? 24 : 16; width: tile.index === 0 ? 160 : 96; height: width; url: tile.modelData.icon || ""; decodeW: 256 }
                        Text {
                            x: 16; y: parent.height - 36
                            text: root.sourceLabel(tile.modelData.source) + (root.isInstalled(tile.modelData.source, tile.modelData.id) ? "  ·  installed" : "")
                            color: Theme.onColor(tile.tint); opacity: 0.85
                            font.family: Theme.font; font.pixelSize: 20
                        }
                        MouseArea { id: fma; anchors.fill: parent; onClicked: root.openDetail(tile.modelData) }
                    }
                }
            }
            Hint {
                visible: root.featured.length === 0
                text: "loading..."
            }
            Hint { topPadding: 8; text: "sources: apk (this system) and flathub. open the apps tab to search and browse categories." }
        }

        PivotPage {
            title: "apps"
            MetroTextField {
                width: parent.width
                placeholder: "search apps and packages"
                onEdited: { root.query = text; searchTimer.restart() }
            }
            Item { width: 1; height: 10 }
            Flickable {
                width: parent.width; height: 48
                contentWidth: chips.width; contentHeight: 48
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds; clip: true
                Row {
                    id: chips
                    spacing: 8
                    Repeater {
                        model: root.categories
                        Rectangle {
                            required property string modelData
                            readonly property bool sel: root.category === modelData
                            width: chipText.width + 32; height: 48
                            color: sel ? Theme.accent : "transparent"
                            border.width: 2; border.color: sel ? Theme.accent : Theme.text
                            opacity: cha.pressed ? 0.6 : 1
                            Text {
                                id: chipText
                                anchors.centerIn: parent; text: parent.modelData
                                color: parent.sel ? Theme.onColor(Theme.accent) : Theme.text
                                font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
                            }
                            MouseArea { id: cha; anchors.fill: parent; onClicked: { root.category = parent.modelData; root.reload() } }
                        }
                    }
                }
            }
            Item { width: 1; height: 12 }
            Hint { visible: root.flatState === "offline"; text: "offline: flathub unreachable. showing apk only." }
            Hint { visible: root.flatState === "cached"; text: "offline: flathub results come from the local cache." }
            Hint { visible: root.flatState === "loading" || !root.apkDone; text: "loading..." }
            Hint {
                visible: root.apkDone && root.flatState !== "loading" && root.merged.length === 0
                text: "no matching apps"
                font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.merged
                StoreRow {
                    required property var modelData
                    item: modelData
                    onClicked: root.openDetail(modelData)
                }
            }
            MetroButton {
                visible: root.flatMore
                width: parent.width; text: "more from flathub"
                onClicked: root.loadMore()
            }
        }

        PivotPage {
            title: "games"
            Hint { visible: root.games.length === 0; text: root.flatState === "offline" ? "offline: no games to show." : "loading..." }
            Repeater {
                model: root.games
                StoreRow {
                    required property var modelData
                    item: modelData
                    onClicked: root.openDetail(modelData)
                }
            }
        }

        PivotPage {
            title: "my apps"
            Hint { visible: !root.instLoaded; text: "loading..." }
            Hint { visible: root.instLoaded && root.instItems.length === 0; text: "nothing installed yet" }
            Hint { visible: root.instItems.length > 0; text: root.instItems.length + " apps (installed by you: apk packages and flatpaks)" }
            Repeater {
                model: root.instItems
                StoreRow {
                    required property var modelData
                    item: modelData
                    onClicked: root.openDetail(modelData)
                }
            }
        }

        PivotPage {
            title: "updates"
            Text {
                width: parent.width; wrapMode: Text.WordWrap; bottomPadding: 12
                text: root.updChecking ? "checking..." : root.updNote
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Row {
                spacing: 12
                MetroButton { text: "check"; enabled2: !root.updChecking && !be.busy; onClicked: root.doCheck() }
                MetroButton {
                    text: "update all"; accentFill: true; enabled2: root.updItems.length > 0 && !be.busy
                    onClicked: { if (be.escalation === "none") be.openInTerminal("apk", "", "upgrade"); else root.doUpdateAll() }
                }
            }
            Item { width: 1; height: 14 }
            Repeater {
                model: root.updItems
                MetroListRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: root.sourceLabel(modelData.source) + "  ·  " + modelData.text
                    onClicked: root.openDetail({ source: modelData.source, id: modelData.id, name: modelData.name, summary: "", icon: "" })
                }
            }
        }
    }

    // ---- progress strip for running install/remove/upgrade
    Item {
        id: opBar
        visible: be.busy
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 84
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        Rectangle { width: parent.width; height: 2; color: Theme.textDim; opacity: 0.4 }
        Text {
            x: 18; y: 10; width: parent.width - 36 - 110; elide: Text.ElideRight
            text: be.opTitle + (be.opProgress >= 0 ? "  " + Math.round(be.opProgress * 100) + "%" : "")
            color: Theme.text; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
        }
        Text {
            x: 18; y: 40; width: parent.width - 36; elide: Text.ElideRight; text: be.opLine
            color: Theme.textDim; font.family: Theme.font; font.pixelSize: 17
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 10; text: "cancel"
            color: Theme.accent; font.family: Theme.font; font.pixelSize: 22
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: be.cancel() }
        }
        Rectangle {
            id: track
            x: 18; y: 70; width: parent.width - 36; height: 6; color: Theme.textDim; opacity: 0.35
        }
        Rectangle {
            id: fill
            x: 18; y: 70; height: 6; color: Theme.accent
            width: be.opProgress >= 0 ? track.width * be.opProgress : track.width * 0.25
            SequentialAnimation on x {
                running: opBar.visible && be.opProgress < 0 && !Theme.reduceMotion
                loops: Animation.Infinite
                NumberAnimation { from: 18; to: 18 + track.width * 0.75; duration: 900 }
                NumberAnimation { from: 18 + track.width * 0.75; to: 18; duration: 900 }
            }
        }
    }

    Text {
        visible: root.toast !== "" && !be.busy
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 18; anchors.bottomMargin: 12
        wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
        text: root.toast; color: Theme.accent; font.family: Theme.font; font.pixelSize: 20
        z: 5
    }

    // ---- detail sheet
    Item {
        id: sheet
        anchors.fill: parent
        visible: root.detailOpen
        readonly property bool inst: root.detailOpen && root.isInstalled(root.cur.source, root.cur.id)
        readonly property bool opHere: be.busy && be.opSource === root.cur.source && be.opId === root.cur.id
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Flickable {
            id: sflick
            x: 18; y: root.topInset + 12
            width: parent.width - 36; height: parent.height - root.topInset - 12 - (opBar.visible ? opBar.height : 0)
            contentWidth: width; contentHeight: dcol.height + 40
            boundsBehavior: Flickable.StopAtBounds; clip: true
            Column {
                id: dcol
                width: parent.width; spacing: 14
                Row {
                    spacing: 16
                    AppIcon { item: root.cur; size: 96 }
                    Column {
                        width: dcol.width - 112; spacing: 4
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            text: (root.cur.name || "").toLowerCase()
                            color: Theme.text; font.family: Theme.font; font.pixelSize: 40; font.weight: Theme.fontLight
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: root.sourceLabel(root.cur.source) + (root.cur.version ? "  ·  " + root.cur.version : "")
                            color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
                        }
                        Text {
                            text: sheet.inst ? "installed" : "not installed"
                            color: sheet.inst ? Theme.accent : Theme.textDim
                            font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                        }
                    }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: root.cur.summary || ""
                    visible: text !== ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                }
                // actions
                Row {
                    spacing: 12
                    MetroButton {
                        visible: !sheet.inst
                        text: sheet.opHere ? "installing..." : "install"
                        accentFill: true; enabled2: !be.busy
                        onClicked: { if (be.escalation === "none" && root.cur.source === "apk") be.openInTerminal("apk", root.cur.id, "install"); else root.doInstall() }
                    }
                    MetroButton {
                        visible: sheet.inst
                        text: "open"; accentFill: true
                        onClicked: be.openApp(root.cur.source, root.cur.id)
                    }
                    MetroButton {
                        visible: sheet.inst
                        text: root.confirmRemove ? "tap again to confirm" : "uninstall"
                        enabled2: !be.busy
                        onClicked: { if (be.escalation === "none" && root.cur.source === "apk") be.openInTerminal("apk", root.cur.id, "remove"); else root.doRemove() }
                    }
                }
                Hint { visible: root.cur.source === "apk" && be.escalation === "none"; text: "install/uninstall opens a terminal (sudo is not available here)." }
                Hint { visible: root.cur.source === "flathub" && !be.hasFlatpak; text: "flatpak is not installed on this system (apk add flatpak)." }
                // progress
                Item {
                    visible: sheet.opHere
                    width: parent.width; height: 40
                    Text { width: parent.width; elide: Text.ElideRight; text: be.opLine; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Rectangle { y: 30; width: parent.width; height: 6; color: Theme.textDim; opacity: 0.35 }
                    Rectangle { y: 30; width: be.opProgress >= 0 ? parent.width * be.opProgress : parent.width * 0.25; height: 6; color: Theme.accent }
                }
                Hint { visible: root.detailLoading; text: "loading details..." }
                Hint { visible: root.detailError !== ""; text: root.detailError }
                // screenshots
                Flickable {
                    visible: root.cur.screenshots !== undefined && root.cur.screenshots.length > 0
                    width: parent.width; height: 300
                    contentWidth: shots.width; contentHeight: 300
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds; clip: true
                    Row {
                        id: shots
                        spacing: 10
                        Repeater {
                            model: root.cur.screenshots || []
                            RemoteImage {
                                required property string modelData
                                height: 300; width: 480; url: modelData; decodeW: 800
                            }
                        }
                    }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    visible: text !== ""
                    text: root.cur.description || ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
                }
                Text {
                    width: parent.width; wrapMode: Text.WrapAnywhere
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 19; lineHeight: 1.2
                    text: {
                        var c = root.cur, l = []
                        l.push("id: " + (c.id || ""))
                        if (c.developer) l.push("by: " + c.developer)
                        if (c.category) l.push("category: " + c.category)
                        if (c.license) l.push("license: " + c.license)
                        if (c.downloadSize) l.push("download: " + (c.downloadSize / 1048576).toFixed(1) + " MB")
                        if (c.installedSize) l.push("installed size: " + (c.installedSize / 1048576).toFixed(1) + " MB")
                        if (c.homepage) l.push("web: " + c.homepage)
                        if (c.offline) l.push("(cached copy, flathub unreachable)")
                        return l.join("\n")
                    }
                }
                MetroButton { width: parent.width; text: "close"; onClicked: root.detailOpen = false }
            }
        }
    }

    // ---- sudo password prompt (apk needs root; kept in memory only, verified with `sudo -S -v`)
    Item {
        anchors.fill: parent
        visible: root.pwOpen
        z: 10
        Rectangle { anchors.fill: parent; color: Theme.pageBg; opacity: 0.96 }
        MouseArea { anchors.fill: parent }
        Column {
            x: 18; y: root.topInset + 60; width: parent.width - 36; spacing: 14
            Text { text: "password"; color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: "installing system packages needs your account password (sudo). it stays in memory until you close the store."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            MetroTextField {
                id: pwField
                width: parent.width
                placeholder: "password"
                echoMode: TextInput.Password
                onAccepted: be.checkPassword(text)
            }
            Text { visible: root.pwError !== ""; text: root.pwError; color: Theme.accent; font.family: Theme.font; font.pixelSize: 20 }
            Row {
                spacing: 12
                MetroButton { text: "ok"; accentFill: true; onClicked: be.checkPassword(pwField.text) }
                MetroButton { text: "cancel"; onClicked: root.pwOpen = false }
            }
        }
    }
}
