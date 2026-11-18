import QtQuick
import FlowShell

// Alphabetical app list: letter header squares, accent icon squares, long-press context menu, alphabet jump.
// Public: signal launched(string name, rect r), signal pinRequested(string name, string glyph), property string filter
// (case-insensitive substring), function scrollToLetter(l), function reset().
Item {
    id: root
    property string filter: ""
    signal launched(string name, rect r)
    signal pinRequested(string name)
    signal searchRequested()

    readonly property int rowH: 72
    readonly property real iconS: 52
    readonly property real headS: 44
    readonly property bool menuShown: menu.shown

    // built-in phone apps: [name, glyph]
    readonly property var builtins: [
        ["Alarms","clock"],["Browser","browser"],["Calculator","grid"],["Calendar","calendar"],["Camera","camera"],
        ["Clock","clock"],["Contacts","people"],["Files","files"],["Mail","mail"],["Maps","maps"],
        ["Messages","message"],["Music","music"],["Notes","notes"],["Phone","phone"],["Photos","photos"],
        ["Settings","settings"],["Store","store"],["Terminal","terminal"],["Videos","video"],["Voice Recorder","music"],
        ["Wallet","wallet"],["Weather","weather"],["Noxal","noxal"],["People","people"],["Search","search"],
        ["Games","star"],["Podcasts","music"],["Radio","music"],["Reminders","notes"],["Stopwatch","clock"]
    ]
    readonly property var glyphNames: ["phone","message","mail","calendar","clock","photos","music","maps","notes","files","weather","terminal","store","camera","settings","people","browser","wallet","noxal","video","search","star"]

    property var entries: []      // flat: {kind:"header"|"app", letter, name, glyph}
    property var letterIndex: ({}) // letter -> entry index
    property var available: ({})

    function glyphFor(name, icon) {
        const n = (name || "").toLowerCase(), ic = (icon || "").toLowerCase()
        for (let i = 0; i < glyphNames.length; i++)
            if (n.indexOf(glyphNames[i]) >= 0 || ic.indexOf(glyphNames[i]) >= 0) return glyphNames[i]
        return ""
    }
    function letterOf(name) {
        const c = (name || "").charAt(0).toLowerCase()
        return (c >= "a" && c <= "z") ? c : "#"
    }

    function rebuild() {
        const seen = {}, apps = []
        try {
            if (typeof Apps !== "undefined" && Apps && Apps.count > 0) {
                for (let i = 0; i < Apps.count; i++) {
                    const a = Apps.get(i)
                    if (!a || !a.name) continue
                    const k = a.name.toLowerCase()
                    if (seen[k]) continue
                    seen[k] = true
                    apps.push({ name: a.name, glyph: glyphFor(a.name, a.icon) })
                }
            }
        } catch (e) {}
        // fill from built-ins when model sparse, or always add missing ones
        for (let j = 0; j < builtins.length; j++) {
            const k2 = builtins[j][0].toLowerCase()
            if (seen[k2]) continue
            seen[k2] = true
            apps.push({ name: builtins[j][0], glyph: builtins[j][1] })
        }
        const f = filter.toLowerCase()
        const list = apps.filter(a => f === "" || a.name.toLowerCase().indexOf(f) >= 0)
        list.sort((a, b) => {
            const la = letterOf(a.name), lb = letterOf(b.name)
            if (la === "#" && lb !== "#") return -1
            if (lb === "#" && la !== "#") return 1
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : (a.name.toLowerCase() > b.name.toLowerCase() ? 1 : 0)
        })
        const out = [], idx = {}, av = {}
        let cur = ""
        for (let m = 0; m < list.length; m++) {
            const l = letterOf(list[m].name)
            if (l !== cur) { cur = l; idx[l] = out.length; av[l] = true; out.push({ kind: "header", letter: l, name: "", glyph: "" }) }
            out.push({ kind: "app", letter: l, name: list[m].name, glyph: list[m].glyph })
        }
        letterIndex = idx
        available = av
        entries = out
    }
    onFilterChanged: Qt.callLater(rebuild)
    Component.onCompleted: rebuild()
    Connections {
        target: (typeof Apps !== "undefined") ? Apps : null
        ignoreUnknownSignals: true
        function onCountChanged() { Qt.callLater(root.rebuild) }
        function onRowsInserted() { Qt.callLater(root.rebuild) }
        function onRowsRemoved() { Qt.callLater(root.rebuild) }
        function onModelReset() { Qt.callLater(root.rebuild) }
        function onDataChanged() { Qt.callLater(root.rebuild) }
    }

    property int entranceTick: 0
    property alias alpha: jump
    function closeOverlays() { jump.open = false; menu.shown = false }
    function reset() { list.contentY = list.originY; entranceTick++; jump.open = false; menu.shown = false }

    function scrollToLetter(l) {
        const i = letterIndex[l]
        if (i === undefined) return
        const from = list.contentY
        list.positionViewAtIndex(i, ListView.Beginning)
        const to = list.contentY
        if (Theme.reduceMotion) return
        list.contentY = from
        scrollAnim.stop()
        scrollAnim.from = from; scrollAnim.to = to
        scrollAnim.start()
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Text {
        id: title
        x: Theme.pageMargin; y: 44
        text: "apps"
        color: Theme.text
        font.family: Theme.font; font.weight: Theme.fontLight; font.pixelSize: 44
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: title.bottom; bottom: parent.bottom; topMargin: 12; bottomMargin: 56 }
        clip: true
        model: root.entries
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600
        maximumFlickVelocity: 7000
        cacheBuffer: 600
        NumberAnimation { id: scrollAnim; target: list; property: "contentY"; duration: 380; easing.type: Easing.InOutCubic }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool isHeader: modelData.kind === "header"
            width: list.width
            height: root.rowH

            // turnstile entrance
            property real ang: 0
            transform: Rotation { origin.x: 0; origin.y: row.height / 2; axis { x: 0; y: 1; z: 0 } angle: row.ang }
            opacity: 1 - Math.abs(ang) / 120
            function playIn() {
                if (Theme.reduceMotion) { ang = 0; return }
                ang = -80
                enter.stop(); enter.start()
            }
            SequentialAnimation {
                id: enter
                PauseAnimation { duration: Math.min(row.index, 12) * 28 }
                NumberAnimation { target: row; property: "ang"; to: 0; duration: Theme.turnstileMs; easing.type: Easing.OutCubic }
            }
            Component.onCompleted: if (index < 14) playIn()
            Connections { target: root; function onEntranceTickChanged() { if (row.index < 14) row.playIn() } }

            // header square
            Rectangle {
                visible: row.isHeader
                x: Theme.pageMargin + (root.iconS - root.headS) / 2; anchors.verticalCenter: parent.verticalCenter
                width: root.headS; height: root.headS
                color: hma.pressed ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : "transparent"
                border.width: 2; border.color: Theme.accent; radius: Theme.tileRadius
                Text {
                    anchors.centerIn: parent
                    text: row.modelData.letter
                    color: Theme.accent
                    font.family: Theme.font; font.weight: Font.Light; font.pixelSize: 28
                }
                MouseArea { id: hma; anchors.fill: parent; onClicked: jump.open = true }
            }

            // app row
            Item {
                visible: !row.isHeader
                anchors.fill: parent
                scale: ama.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Theme.reduceMotion ? 0 : Theme.pressMs } }
                Rectangle {
                    id: ico
                    x: Theme.pageMargin; anchors.verticalCenter: parent.verticalCenter
                    width: root.iconS; height: root.iconS; radius: Theme.tileRadius
                    color: Theme.accent; opacity: Theme.tileOpacity
                    TileGlyph {
                        anchors.centerIn: parent
                        size: 36
                        name: row.modelData.glyph
                        visible: row.modelData.glyph !== ""
                        color: Theme.onColor(Theme.accent)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: row.modelData.glyph === ""
                        text: row.modelData.name.charAt(0).toUpperCase()
                        color: Theme.onColor(Theme.accent)
                        font.family: Theme.font; font.weight: Font.Normal; font.pixelSize: 26
                    }
                }
                Text {
                    anchors { left: ico.right; leftMargin: 16; right: parent.right; rightMargin: Theme.pageMargin; verticalCenter: parent.verticalCenter }
                    text: row.modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font; font.weight: Theme.fontLight; font.pixelSize: 22
                }
                MouseArea {
                    id: ama
                    anchors.fill: parent
                    pressAndHoldInterval: 450
                    onClicked: {
                        const p = ico.mapToItem(null, 0, 0)
                        root.launched(row.modelData.name, Qt.rect(p.x, p.y, ico.width, ico.height))
                    }
                    onPressAndHold: {
                        const p = ico.mapToItem(root, 0, 0)
                        menu.appName = row.modelData.name
                        menu.appGlyph = row.modelData.glyph
                        menu.px = Math.min(Math.max(p.x + ico.width + 8, 12), root.width - menu.w - 12)
                        menu.py = Math.min(Math.max(p.y, 40), root.height - menu.h - 120)
                        menu.shown = true
                    }
                }
            }
        }
    }

    // context menu
    Item {
        id: menu
        anchors.fill: parent
        property bool shown: false
        property string appName: ""
        property string appGlyph: ""
        property real px: 0
        property real py: 0
        readonly property real w: 240
        readonly property real h: 64
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : 120 } }
        z: 5
        Rectangle { anchors.fill: parent; color: "#99000000" }
        MouseArea { anchors.fill: parent; onClicked: menu.shown = false }
        Rectangle {
            x: menu.px; y: menu.py; width: menu.w; height: menu.h
            color: "#1F1F1F"; border.width: 1; border.color: "#3A3A3A"
            Text {
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                text: "pin to start"; color: "white"
                font.family: Theme.font; font.weight: Font.Light; font.pixelSize: 24
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.pinRequested(menu.appName, menu.appGlyph); menu.shown = false }
            }
        }
    }

    // round outlined search button
    Rectangle {
        id: sbtn
        anchors { right: parent.right; rightMargin: Theme.pageMargin + 4; bottom: parent.bottom; bottomMargin: 72 }
        width: 56; height: 56; radius: 28
        color: sma.pressed ? Theme.accent : "transparent"; border.width: 2; border.color: Theme.text
        scale: sma.pressed ? 0.92 : 1
        Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.pressMs } }
        TileGlyph { anchors.centerIn: parent; size: 26; stroke: 2.4; name: "search"; color: sma.pressed ? Theme.onColor(Theme.accent) : Theme.text }
        MouseArea { id: sma; anchors.fill: parent; onClicked: root.searchRequested() }
    }

    AlphaJump {
        id: jump
        anchors.fill: parent
        z: 10
        available: root.available
        onPicked: (l) => { jump.open = false; root.scrollToLetter(l) }
        onClosed: jump.open = false
    }
}
