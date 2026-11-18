import QtQuick
import FlowShell
import "settings2/index.js" as More

// Settings app: SettingsHome plus a navigation stack of sub-pages with turnstile transitions
// (page swings about its left edge; the covered page fades and tilts). Respects Theme.reduceMotion.
// API: open(name) name = "start+theme" | "lock screen" | "app:<tileId>" | "applications" | "system";
//      back() pops (emits closed() at root); goHome(); page (top page name, read-only); topInset; signal closed().
Item {
    id: root
    property real topInset: 36
    readonly property string page: _top
    property string _top: "home"
    property int live: 1          // stack entries not leaving (covered = below the topmost live one)
    property int homeIndex: 0     // pivot page of the home screen: 0 system, 1 applications
    property bool _busy: false
    signal closed

    function _find(name) { for (var i = 0; i < stack.count; ++i) if (stack.get(i).name === name) return i; return -1 }
    function open(name) {
        name = String(name)
        if (name === "system" || name === "applications") { goHome(); homeIndex = name === "system" ? 0 : 1; return }
        if (name === "" || name === "home") { goHome(); return }
        if (_find(name) >= 0 || _busy) return
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

    focus: true
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    ListModel { id: stack; ListElement { name: "home"; leaving: false } }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Component { id: startC; SettingsStartTheme {} }
    Component { id: lockC; SettingsLockPage {} }
    Component { id: appC; SettingsAppPage {} }

    Repeater {
        model: stack
        delegate: Item {
            id: d
            required property int index
            required property string name
            required property bool leaving
            readonly property bool covered: index < root.live - 1
            property real p: 0
            property real cover: covered ? 1 : 0
            width: root.width; height: root.height
            visible: p > 0.005 && cover < 0.995
            opacity: Math.min(1, p * 4) * (1 - cover)
            Behavior on p { enabled: d.index > 0 && !Theme.reduceMotion
                NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
            Behavior on cover { enabled: !Theme.reduceMotion
                NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
            Component.onCompleted: p = 1
            onLeavingChanged: if (leaving) p = 0
            onPChanged: if (leaving && p <= 0.001) Qt.callLater(root._drop, d.name)
            transform: Rotation {
                origin.x: 0; origin.y: d.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: -90 * (1 - Math.max(0, Math.min(1, d.p))) + 40 * d.cover
            }
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
