import QtQuick
import QtWebEngine
import FlowShell

// In-shell browser on Qt WebEngine (compiled in only when Qt6WebEngineQuick is found; BrowserApp.qml loads this file and falls back
// to launching an external browser otherwise). Windows Phone IE look: bottom address bar, tab tiles, favourites + history.
// Shares AppStore "browser" { pins, bookmarks: [{title,url}], history: [{url,time}] } with BrowserApp.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property string mode: "page"          // page | tabs | favs
    property int cur: 0
    property var bookmarks: []
    property var history: []
    property var pins: []
    property string toast: ""
    readonly property string home: "https://duckduckgo.com/"
    readonly property var view: tabRep.count > 0 && tabRep.itemAt(cur) ? tabRep.itemAt(cur).web : null

    function persist() { AppStore.save("browser", { pins: pins, bookmarks: bookmarks, history: history }) }
    function say(t) { toast = t; toastT.restart() }
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
    function go(text) { var u = resolve(text); if (u !== "" && view) { view.url = u; mode = "page"; view.forceActiveFocus() } }
    function newTab(u) { tabs.append({ addr: u || home, ttl: "" }); cur = tabs.count - 1; mode = "page" }
    function closeTab(i) {
        if (tabs.count <= 1) { tabs.set(0, { addr: home, ttl: "" }); mode = "page"; return }
        tabs.remove(i); cur = Math.min(cur, tabs.count - 1)
    }
    function isBookmarked(u) { for (var i = 0; i < bookmarks.length; ++i) if (bookmarks[i].url === u) return true; return false }
    function toggleBookmark() {
        if (!view) return
        var u = view.url.toString(), b = bookmarks.slice()
        if (isBookmarked(u)) b = b.filter(function(x) { return x.url !== u }); else b.unshift({ title: view.title || u, url: u })
        bookmarks = b; persist(); say(isBookmarked(u) ? "added to favourites" : "removed")
    }
    function pinToStart() {
        if (!view) return
        var u = view.url.toString(), p = pins.slice()
        p.unshift({ title: view.title || u, url: u }); pins = p; persist(); say("pinned")
    }
    function addHistory(u) {
        if (!u || u === "about:blank") return
        var h = history.slice(); if (h.length && h[0].url === u) return
        h.unshift({ url: u, time: Date.now() }); history = h.slice(0, 200); persist()
    }
    function back() {
        if (mode !== "page") mode = "page"
        else if (view && view.canGoBack) view.goBack()
        else closeRequested()
    }
    focus: true
    Keys.onBackPressed: back()
    Keys.onEscapePressed: back()

    Component.onCompleted: {
        var s = AppStore.load("browser", null)
        if (s) {
            var l = function(v) { return (v && typeof v.length === "number") ? Array.prototype.slice.call(v) : [] }
            bookmarks = l(s.bookmarks); history = l(s.history); pins = l(s.pins)
        }
        tabs.append({ addr: home, ttl: "" })
    }
    ListModel { id: tabs }
    Timer { id: toastT; interval: 2500; onTriggered: root.toast = "" }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // ---- pages
    Item {
        id: pageArea
        y: root.topInset; width: parent.width; height: parent.height - root.topInset - bar.height
        visible: root.mode === "page"
        Repeater {
            id: tabRep
            model: tabs
            Item {
                id: tabItem
                required property int index
                required property string addr
                property alias web: wv
                anchors.fill: parent
                visible: index === root.cur
                WebEngineView {
                    id: wv
                    anchors.fill: parent
                    url: tabItem.addr
                    onTitleChanged: tabs.setProperty(tabItem.index, "ttl", title)
                    onLoadingChanged: (r) => { if (r.status === WebEngineLoadingInfo.LoadSucceededStatus) root.addHistory(url.toString()) }
                    onNewWindowRequested: (r) => root.newTab(r.requestedUrl.toString())
                    onUrlChanged: if (tabItem.index === root.cur && !addrField.activeFocus) addrField.text = url.toString()
                }
            }
        }
        Rectangle {
            visible: root.view && root.view.loading
            width: parent.width * (root.view ? root.view.loadProgress / 100 : 0); height: 4; color: Theme.accent
        }
    }

    // ---- tabs (tile grid)
    Flickable {
        y: root.topInset; width: parent.width; height: parent.height - root.topInset - bar.height
        visible: root.mode === "tabs"
        contentHeight: grid.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            x: 18; width: parent.width - 36; spacing: 10
            Text { text: "tabs"; color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight }
            Grid {
                id: grid
                columns: 2; spacing: 10
                Repeater {
                    model: tabs
                    Rectangle {
                        required property int index
                        required property string addr
                        required property string ttl
                        width: (grid.parent.width - 10) / 2; height: width
                        color: index === root.cur ? Theme.accent : (Theme.dark ? "#1b1b1b" : "#e6e6e6")
                        Text {
                            x: 12; y: 12; width: parent.width - 24; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                            text: ttl !== "" ? ttl : addr
                            color: index === root.cur ? Theme.onColor(Theme.accent) : Theme.text; font.family: Theme.font; font.pixelSize: 22
                        }
                        Text { x: 12; y: parent.height - 34; width: parent.width - 24; elide: Text.ElideRight; text: addr; opacity: 0.7
                            color: index === root.cur ? Theme.onColor(Theme.accent) : Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
                        MouseArea { anchors.fill: parent; onClicked: { root.cur = index; root.mode = "page" } }
                        Text { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; text: "✕"
                            color: index === root.cur ? Theme.onColor(Theme.accent) : Theme.text; font.pixelSize: 26
                            MouseArea { anchors.fill: parent; anchors.margins: -14; onClicked: root.closeTab(index) } }
                    }
                }
            }
            MetroButton { width: parent.width; text: "new tab"; accentFill: true; onClicked: root.newTab() }
        }
    }

    // ---- favourites + history
    Flickable {
        y: root.topInset; width: parent.width; height: parent.height - root.topInset - bar.height
        visible: root.mode === "favs"
        contentHeight: fcol.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: fcol
            x: 18; width: parent.width - 36
            Text { text: "favourites"; color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight }
            Text { visible: root.bookmarks.length === 0; text: "none yet. use the star in the page menu."; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20 }
            Repeater {
                model: root.bookmarks
                MetroListRow {
                    required property var modelData
                    title: modelData.title; subtitle: modelData.url
                    onClicked: root.go(modelData.url)
                    onPressAndHold: { root.bookmarks = root.bookmarks.filter(function(b) { return b.url !== modelData.url }); root.persist() }
                }
            }
            Item { width: 1; height: 16 }
            Text { text: "history"; color: Theme.text; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
            Repeater {
                model: root.history.slice(0, 50)
                MetroListRow {
                    required property var modelData
                    title: modelData.url; subtitle: Qt.formatDateTime(new Date(modelData.time), "yyyy-MM-dd hh:mm")
                    onClicked: root.go(modelData.url)
                }
            }
        }
    }

    // ---- bottom bar
    Rectangle {
        id: bar
        anchors.bottom: parent.bottom; width: parent.width; height: 84
        color: Theme.dark ? "#111111" : "#eeeeee"
        Row {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Text { width: 44; height: parent.height; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                text: "‹"; font.pixelSize: 48; color: root.view && root.view.canGoBack ? Theme.text : Theme.textDim
                MouseArea { anchors.fill: parent; onClicked: if (root.view) root.view.goBack() } }
            Text { width: 44; height: parent.height; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                text: "›"; font.pixelSize: 48; color: root.view && root.view.canGoForward ? Theme.text : Theme.textDim
                MouseArea { anchors.fill: parent; onClicked: if (root.view) root.view.goForward() } }
            MetroTextField {
                id: addrField
                width: parent.width - 44 * 2 - 84 * 2 - 8 * 4; height: parent.height
                placeholder: "search or type address"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                onAccepted: root.go(text)
            }
            Rectangle { width: 76; height: parent.height; color: "transparent"; border.width: 2; border.color: Theme.text
                Text { anchors.centerIn: parent; text: tabs.count; color: Theme.text; font.family: Theme.font; font.pixelSize: 26 }
                MouseArea { anchors.fill: parent; onClicked: root.mode = root.mode === "tabs" ? "page" : "tabs" } }
            Text { width: 76; height: parent.height; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                text: "⋯"; font.pixelSize: 40; color: Theme.text
                MouseArea { anchors.fill: parent; onClicked: menu.open = !menu.open } }
        }
    }

    // ---- page menu
    Rectangle {
        id: menu
        property bool open: false
        visible: open
        anchors.right: parent.right; anchors.bottom: bar.top; width: 320; height: mcol.height
        color: Theme.dark ? "#222222" : "#dddddd"
        Column {
            id: mcol; width: parent.width
            Repeater {
                model: [ root.view && root.isBookmarked(root.view.url.toString()) ? "remove favourite" : "add to favourites", "favourites & history",
                         "pin to start", "reload", "new tab", "close browser" ]
                Text {
                    required property string modelData
                    width: mcol.width; height: 64; leftPadding: 18; verticalAlignment: Text.AlignVCenter
                    text: modelData; color: Theme.text; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                    MouseArea { anchors.fill: parent; onClicked: {
                        menu.open = false
                        if (modelData.indexOf("favourite") >= 0 && modelData.indexOf("&") < 0) root.toggleBookmark()
                        else if (modelData.indexOf("&") >= 0) root.mode = "favs"
                        else if (modelData === "pin to start") root.pinToStart()
                        else if (modelData === "reload") { if (root.view) root.view.reload() }
                        else if (modelData === "new tab") root.newTab()
                        else root.closeRequested()
                    } }
                }
            }
        }
    }
    Text { visible: root.toast !== ""; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: bar.top; anchors.bottomMargin: 10
        text: root.toast; color: Theme.accent; font.family: Theme.font; font.pixelSize: 22 }
}
