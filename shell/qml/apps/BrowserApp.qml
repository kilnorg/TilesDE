import QtQuick
import FlowShell

// Browser launcher: no web engine on the target, so pages open in firefox-esr (fallback xdg-open). The window is placed
// inside the phone window by tools/tiles-wm.py (Main.qml); back closes it, the switcher lists it.
// Store key "browser": { pins: [{title, url}], bookmarks: [{title, url}], history: [{url, time (ms)}] }
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var pins: []
    property var bookmarks: []
    property var history: []
    property string toast: ""
    // long-press menu target: kind "pin" | "bookmark" | "history", idx into that list
    property string menuKind: ""
    property int menuIdx: -1

    readonly property int historyCap: 200
    readonly property string honest: "opens in firefox until the Tiles web engine lands"

    function persist() { AppStore.save("browser", { pins: pins, bookmarks: bookmarks, history: history }) }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function stamp(ms) {
        var d = new Date(ms)
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "  " + pad(d.getHours()) + ":" + pad(d.getMinutes())
    }
    function showToast(t) { toast = t; toastTimer.restart() }

    // URL vs search
    function looksLikeUrl(s) {
        if (/^[a-z][a-z0-9+.\-]*:\/\/\S+$/i.test(s)) return true
        if (/\s/.test(s)) return false
        if (/^localhost(:\d+)?(\/.*)?$/i.test(s)) return true
        return /^[^.\/?#]+(\.[^.\/?#]+)+(:\d+)?([\/?#].*)?$/.test(s)
    }
    function resolve(s) {
        s = String(s).trim()
        if (s === "") return ""
        if (looksLikeUrl(s)) return /^[a-z][a-z0-9+.\-]*:\/\//i.test(s) ? s : "https://" + s
        return "https://duckduckgo.com/?q=" + encodeURIComponent(s)
    }
    function hostOf(url) {
        var m = /^[a-z][a-z0-9+.\-]*:\/\/([^\/?#]+)/i.exec(url)
        return m ? m[1].replace(/^www\./i, "") : url
    }
    function letterOf(p) {
        var t = String(p.title || hostOf(p.url)).trim()
        return t === "" ? "?" : t.charAt(0).toUpperCase()
    }
    function titleFor(url) { return hostOf(url) }

    function openUrl(url) {
        if (url === "") return
        var h = history.slice()
        h.unshift({ url: url, time: Date.now() })
        if (h.length > historyCap) h.length = historyCap
        history = h; persist()
        if (!Sys.launch("firefox-esr", [url])) {
            if (!Sys.openUrl(url)) { showToast("could not open a browser"); return }
        }
        showToast("opening in firefox")
    }
    function go(text) {
        var u = resolve(text)
        if (u !== "") openUrl(u)
    }

    function indexOfUrl(list, url) { for (var i = 0; i < list.length; ++i) if (list[i].url === url) return i; return -1 }
    function addBookmark(title, url) {
        var u = resolve(url)
        if (u === "") { showToast("type a url first"); return false }
        if (indexOfUrl(bookmarks, u) >= 0) { showToast("already bookmarked"); return false }
        var t = String(title).trim()
        var b = bookmarks.slice()
        b.push({ title: t !== "" ? t : titleFor(u), url: u })
        bookmarks = b; persist()
        showToast("bookmark added")
        return true
    }
    function removeAt(kind, i) {
        if (kind === "pin") { var p = pins.slice(); p.splice(i, 1); pins = p }
        else if (kind === "bookmark") { var b = bookmarks.slice(); b.splice(i, 1); bookmarks = b }
        else if (kind === "history") { var h = history.slice(); h.splice(i, 1); history = h }
        persist()
    }
    function pinEntry(e) {
        if (indexOfUrl(pins, e.url) >= 0) { showToast("already pinned"); return }
        var p = pins.slice()
        p.push({ title: e.title || titleFor(e.url), url: e.url })
        pins = p; persist()
        showToast("pinned to start")
    }
    function menuEntry() {
        var list = menuKind === "pin" ? pins : menuKind === "bookmark" ? bookmarks : menuKind === "history" ? history : []
        return menuIdx >= 0 && menuIdx < list.length ? list[menuIdx] : null
    }
    function closeMenu() { menuKind = ""; menuIdx = -1 }

    Component.onCompleted: {
        var s = AppStore.load("browser", null)
        if (s && typeof s === "object" && !Array.isArray(s)) {
            pins = Array.isArray(s.pins) ? s.pins : []
            bookmarks = Array.isArray(s.bookmarks) ? s.bookmarks : []
            history = Array.isArray(s.history) ? s.history : []
        } else {
            // default pins (suggested sites, not browsing data)
            pins = [{ title: "DuckDuckGo", url: "https://duckduckgo.com/" },
                    { title: "Wikipedia", url: "https://wikipedia.org/" }]
            persist()
        }
    }

    focus: true
    function back() {
        if (menuKind !== "") closeMenu()
        else if (pivot.currentIndex !== 0) pivot.goTo(0)
        else closeRequested()
    }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    Timer { id: toastTimer; interval: 1600; onTriggered: root.toast = "" }

    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset
        caption: "browser"

        // ---- start
        PivotPage {
            title: "start"
            Item { width: 1; height: 8 }
            MetroTextField {
                id: urlBox
                width: parent.width
                placeholder: "search or type a url"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onAccepted: { var t = text; if (t.trim() !== "") { root.go(t); text = "" } }
            }
            Text {
                width: parent.width; topPadding: 8; bottomPadding: 8
                text: root.honest; color: Theme.textDim; wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 18
            }
            MetroButton {
                text: "go"; accentFill: true
                enabled2: urlBox.text.trim() !== ""
                onClicked: { root.go(urlBox.text); urlBox.text = "" }
            }
            MetroSectionHeader { text: "pinned sites" }
            Text {
                visible: root.pins.length === 0
                text: "nothing pinned. long-press a bookmark to pin it."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
                width: parent.width; wrapMode: Text.WordWrap
            }
            Flow {
                id: grid
                width: parent.width
                spacing: Theme.tileGap
                readonly property real cell: Math.floor((width - spacing * 2) / 3)
                Repeater {
                    model: root.pins
                    Rectangle {
                        required property int index
                        required property var modelData
                        width: grid.cell; height: grid.cell
                        color: Theme.accent
                        opacity: tileArea.pressed ? 0.6 : 1
                        Text {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -8
                            text: root.letterOf(modelData)
                            color: Theme.onColor(Theme.accent)
                            font.family: Theme.font; font.pixelSize: Math.round(grid.cell * 0.5); font.weight: Theme.fontLight
                        }
                        Text {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 8
                            text: modelData.title || root.hostOf(modelData.url)
                            elide: Text.ElideRight
                            color: Theme.onColor(Theme.accent)
                            font.family: Theme.font; font.pixelSize: 17
                        }
                        MouseArea {
                            id: tileArea; anchors.fill: parent
                            onClicked: root.openUrl(modelData.url)
                            onPressAndHold: { root.menuKind = "pin"; root.menuIdx = index }
                        }
                    }
                }
            }
        }

        // ---- bookmarks
        PivotPage {
            title: "bookmarks"
            Item { width: 1; height: 8 }
            MetroTextField {
                id: bmTitle
                width: parent.width; label: "title"
                placeholder: "optional"
                inputMethodHints: Qt.ImhNoPredictiveText
            }
            Item { width: 1; height: 8 }
            MetroTextField {
                id: bmUrl
                width: parent.width; label: "url"
                placeholder: urlBox.text !== "" ? urlBox.text : "example.org"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onAccepted: bmAdd.clicked()
            }
            Item { width: 1; height: 12 }
            MetroButton {
                id: bmAdd
                text: "add bookmark"
                onClicked: {
                    var u = bmUrl.text.trim() !== "" ? bmUrl.text : urlBox.text
                    if (root.addBookmark(bmTitle.text, u)) { bmTitle.text = ""; bmUrl.text = "" }
                }
            }
            Item { width: 1; height: 12 }
            Text {
                visible: root.bookmarks.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no bookmarks yet"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22
            }
            Repeater {
                model: root.bookmarks
                MetroListRow {
                    required property int index
                    required property var modelData
                    title: modelData.title || root.hostOf(modelData.url)
                    subtitle: modelData.url
                    onClicked: root.openUrl(modelData.url)
                    onPressAndHold: { root.menuKind = "bookmark"; root.menuIdx = index }
                }
            }
        }

        // ---- history
        PivotPage {
            title: "history"
            Item { width: 1; height: 8 }
            MetroButton {
                text: "clear all"
                enabled2: root.history.length > 0
                onClicked: { root.history = []; root.persist(); root.showToast("history cleared") }
            }
            Item { width: 1; height: 12 }
            Text {
                visible: root.history.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "nothing opened yet"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22
            }
            Repeater {
                model: root.history
                MetroListRow {
                    required property int index
                    required property var modelData
                    title: modelData.url
                    subtitle: root.stamp(modelData.time)
                    onClicked: root.openUrl(modelData.url)
                    onPressAndHold: { root.menuKind = "history"; root.menuIdx = index }
                }
            }
        }
    }

    // toast
    Rectangle {
        visible: root.toast !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        width: toastText.implicitWidth + 40; height: 48
        color: Theme.dark ? "#2b2b2b" : "#e0e0e0"
        Text {
            id: toastText; anchors.centerIn: parent
            text: root.toast; color: Theme.text
            font.family: Theme.font; font.pixelSize: 20
        }
    }

    // long-press menu
    Rectangle {
        anchors.fill: parent
        visible: root.menuKind !== ""
        color: Theme.dark ? "#cc000000" : "#ccffffff"
        MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
        Column {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
                x: 18; width: parent.width - 36; bottomPadding: 12
                text: { var e = root.menuEntry(); return e ? (e.title || e.url) : "" }
                elide: Text.ElideRight; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 20
            }
            Repeater {
                model: {
                    var k = root.menuKind
                    if (k === "pin") return ["open", "unpin"]
                    if (k === "bookmark") return ["open", "pin to start", "delete"]
                    if (k === "history") return ["open", "bookmark", "remove"]
                    return []
                }
                Item {
                    required property string modelData
                    width: parent.width; height: 60
                    opacity: itemArea.pressed ? 0.5 : 1
                    Text {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        text: modelData; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight
                    }
                    MouseArea {
                        id: itemArea; anchors.fill: parent
                        onClicked: {
                            var e = root.menuEntry(), k = root.menuKind, i = root.menuIdx
                            root.closeMenu()
                            if (!e) return
                            if (modelData === "open") root.openUrl(e.url)
                            else if (modelData === "pin to start") root.pinEntry(e)
                            else if (modelData === "bookmark") root.addBookmark(root.titleFor(e.url), e.url)
                            else root.removeAt(k, i)   // unpin / delete / remove
                        }
                    }
                }
            }
        }
    }
}
