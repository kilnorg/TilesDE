import QtQuick
import FlowShell
import "settings2/index.js" as More

// Settings app: SettingsHome plus a navigation stack of sub-pages with turnstile transitions
// (new page slides in over the previous one, which shifts left and dims; see PageSlide). Respects Theme.reduceMotion.
// API: open(name) name = "start+theme" | "lock screen" | "app:<tileId>" | "applications" | "system";
//      back() pops (emits closed() at root); goHome(); page (top page name, read-only); topInset; signal closed().
Item {
    id: root
    property real topInset: 36
    readonly property string page: _top
    property string _top: "home"
    property int live: 1          // stack entries not leaving
    property int homeIndex: 0     // pivot page of the home screen: 0 system, 1 applications
    property bool _busy: false
    signal closed

    function _find(name) { for (var i = 0; i < stack.count; ++i) if (stack.get(i).name === name) return i; return -1 }
    function open(name) {
        name = String(name)
        if (name === "system" || name === "applications") { goHome(); homeIndex = name === "system" ? 0 : 1; return }
        if (name === "" || name === "home") { goHome(); return }
        var f = _find(name)
        if (f >= 0 && !stack.get(f).leaving) return
        if (f >= 0) stack.remove(f)        // same page still sliding out: drop it so back/open stay consistent
        if (stack.count > 1) goHome(true)
        stack.append({ name: name, leaving: false })
        live = stack.count
        _top = name
    }
    function goHome(instant) {
        for (var i = stack.count - 1; i >= 1; --i) {
            if (instant) stack.remove(i); else stack.setProperty(i, "leaving", true)
        }
        live = 1
        _top = "home"
    }
    function back() {
        if (stack.count <= 1) { if (homeIndex > 0) { homeIndex -= 1; return } closed(); return }
        var i = stack.count - 1
        while (i > 0 && stack.get(i).leaving) --i
        if (i < 1) return
        stack.setProperty(i, "leaving", true)
        live = i
        _top = i > 1 ? stack.get(i - 1).name : "home"
    }
    // settings2/index.js pages (display, notifications, battery ...) load by file path
    function _moreSource(name) { for (var i = 0; i < More.entries.length; ++i) if (More.entries[i].key === name) return More.entries[i].component; return "" }
    function _drop(name) { var i = _find(name); if (i > 0) stack.remove(i) }

    clip: true
    focus: true
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    ListModel { id: stack; ListElement { name: "home"; leaving: false } }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Component { id: startC; SettingsStartTheme {} }
    Component { id: lockC; SettingsLockPage {} }
    Component { id: appC; SettingsAppPage {} }

    // iOS-style back-swipe peek: the topmost page follows the finger (f = 0..1 of the width), the page below peeks.
    readonly property int depth: live
    property int _dragIdx: -1
    function dragBack(f) {
        const i = live - 1
        if (i < 1) return
        const it = rep.itemAt(i); if (!it) return
        it.dragging = true; _dragIdx = i; it.p = 1 - f
    }
    function endBack(commit) {
        const it = rep.itemAt(_dragIdx); _dragIdx = -1
        if (!it) return
        it.dragging = false
        if (commit) back(); else it.p = 1
    }

    Repeater {
        id: rep
        model: stack
        delegate: PageSlide {
            id: d
            required property int index
            required property string name
            required property bool leaving
            property bool dragging: false
            width: root.width; height: root.height
            p: index === 0 ? 1 : 0
            visible: p > 0.005 && cover < 0.999
            Behavior on p { enabled: d.index > 0 && !d.dragging && !Theme.reduceMotion
                NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
            Component.onCompleted: p = 1
            onLeavingChanged: if (leaving) p = 0
            onPChanged: {
                // page below is covered exactly as far as this page has entered
                const b = rep.itemAt(index - 1); if (b) b.cover = p
                if (leaving && p <= 0.001) Qt.callLater(root._drop, d.name)
            }
            Component.onDestruction: { const b = rep.itemAt(index - 1); if (b) b.cover = 0 }
            Rectangle { anchors.fill: parent; color: Theme.pageBg }
            MouseArea { anchors.fill: parent }
            Item {
                y: root.topInset; width: parent.width; height: parent.height - root.topInset
                Loader {
                    id: ld
                    anchors.fill: parent
                    readonly property string more: root._moreSource(d.name)
                    source: more
                    sourceComponent: more !== "" ? null : d.name === "home" ? homeC : d.name === "start+theme" ? startC
                                     : d.name === "lock screen" ? lockC : appC
                    onLoaded: if (d.name.indexOf("app:") === 0) ld.item.appId = d.name.substring(4)
                }
            }
        }
    }

    Component { id: homeC
        SettingsHome {
            id: h
            onOpen: (pg) => root.open(pg)
            onCurrentIndexChanged: root.homeIndex = currentIndex
            Binding { target: h; property: "currentIndex"; value: root.homeIndex }
        }
    }
}
