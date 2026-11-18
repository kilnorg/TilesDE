import QtQuick
import FlowShell
import "apps/index.js" as NativeApps

// Built-in app page with turnstile transition: the page swings about its left edge in Y, angle -90 deg (p = 0)
// to 0 (p = 1). Solid page, accent title bar, a few mock blocks per app name. Real data comes later.
Item {
    id: root
    property string name: ""
    property rect from: Qt.rect(240, 560, 62, 62)   // kept for API compatibility; unused by the turnstile
    property real fromRadius: 0
    signal back
    // shell back gesture: let the native app close an inner view first; true = handled by the app
    function systemBack() {
        const it = nativeL.item
        if (nativeSrc !== "" && it && typeof it.back === "function") { it.back(); return true }
        return false
    }
    property bool launching: false                   // real app being started: placeholder until its window maps
    property real p: 0                               // 0 hidden .. 1 fully open; spring/finger-driven by Main
    property real kbH: 0                             // on-screen keyboard height (apps shrink above it)
    readonly property string nativeSrc: NativeApps.source(name)
    property real sw: 540
    property real sh: 1170
    visible: p > 0.005
    opacity: Math.min(1, p * 4)

    Item {
        id: page
        width: root.sw; height: root.sh
        transform: Rotation {
            origin.x: 0; origin.y: root.sh / 2
            axis { x: 0; y: 1; z: 0 }
            angle: -90 * (1 - Math.max(0, Math.min(1, root.p)))
        }

        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }

        // accent title bar
        Rectangle {
            id: head
            visible: root.nativeSrc === ""
            width: parent.width; height: visible ? 132 : 0; color: Theme.accent
            Item {
                x: 4; y: 44; width: 52; height: 44
                TileGlyph { anchors.centerIn: parent; size: 24; stroke: 2.5; name: "back"; color: Theme.onColor(Theme.accent) }
                MouseArea { anchors.fill: parent; onClicked: root.back() }
            }
            Text { anchors { left: parent.left; leftMargin: Theme.pageMargin + 4; bottom: parent.bottom; bottomMargin: 10 }
                text: Theme.title(root.name); color: Theme.onColor(Theme.accent)
                font.pixelSize: 40; font.family: Theme.font; font.weight: Theme.fontLight }
        }

        Item {
            id: body
            anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: (root.nativeSrc !== "" ? 56 : 80) + root.kbH }
            Loader {
                id: nativeL
                anchors.fill: parent
                active: root.nativeSrc !== ""
                source: root.nativeSrc
                onLoaded: if (item.hasOwnProperty("topInset")) item.topInset = 36
                Connections { target: nativeL.item; ignoreUnknownSignals: true; function onCloseRequested() { root.back() } }
            }
            Loader {
                anchors.fill: parent
                active: root.nativeSrc === ""
                sourceComponent: {
                    switch (root.name) {
                    case "Clock": return clockC
                    case "Calendar": return calC
                    case "Notes": return notesC
                    case "Settings": return settingsC
                    case "Phone": return phoneC
                    case "Noxal": return noxalC
                    default: return emptyC
                    }
                }
            }
        }
    }

    component Row2: Item {
        id: r
        property string title: ""
        property string sub: ""
        property bool toggle: false
        property bool on: false
        signal clicked
        width: parent ? parent.width : 0; height: 68
        Column { x: Theme.pageMargin + 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Text { text: r.title; color: Theme.text; font.pixelSize: 20; font.family: Theme.font; font.weight: Theme.fontLight }
            Text { visible: r.sub !== ""; text: r.sub; color: Theme.textDim; font.pixelSize: 14; font.family: Theme.font } }
        Rectangle { visible: r.toggle; anchors { right: parent.right; rightMargin: Theme.pageMargin + 4; verticalCenter: parent.verticalCenter }
            width: 48; height: 24; color: r.on ? Theme.accent : "transparent"; border.width: 2; border.color: r.on ? Theme.accent : Theme.text
            Rectangle { width: 10; height: 16; y: 4; x: r.on ? 34 : 4; color: r.on ? Theme.tileText : Theme.text
                Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 120 } } } }
        MouseArea { anchors.fill: parent; onClicked: r.clicked() }
    }
    component Block: Rectangle {
        property string label: ""
        property string value: ""
        color: Theme.accent
        Text { anchors { left: parent.left; bottom: parent.bottom; margins: 8 } text: parent.label.toLowerCase(); color: Theme.tileText; font.pixelSize: 14; font.family: Theme.font }
        Text { anchors { left: parent.left; top: parent.top; margins: 8 } text: parent.value; color: Theme.tileText; font.pixelSize: 32; font.family: Theme.font; font.weight: Theme.fontLight }
    }

    Component { id: clockC
        Item {
            id: ck
            property date now: new Date()
            Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: ck.now = new Date() }
            Text { id: big; anchors { top: parent.top; topMargin: 30; left: parent.left; leftMargin: Theme.pageMargin + 4 }
                text: Qt.formatTime(ck.now, "hh:mm:ss"); color: Theme.text; font.pixelSize: 72; font.family: Theme.font; font.weight: Font.ExtraLight }
            Text { anchors { top: big.bottom; left: big.left } text: Qt.formatDate(ck.now, "dddd, d MMMM").toLowerCase(); color: Theme.textDim; font.pixelSize: 18; font.family: Theme.font; font.weight: Theme.fontLight }
            Column { anchors { top: big.bottom; topMargin: 60; left: parent.left; right: parent.right }
                Row2 { id: a1; title: "07:00"; sub: "weekdays"; toggle: true; on: true; onClicked: on = !on }
                Row2 { title: "22:30"; sub: "wind down"; toggle: true; on: false; onClicked: on = !on }
                Row2 { title: "timer"; sub: "10 min" }
            }
        } }
    Component { id: calC
        Column {
            Text { x: Theme.pageMargin + 4; topPadding: 18; bottomPadding: 10; text: Qt.formatDate(new Date(), "dddd d MMMM").toLowerCase(); color: Theme.textDim; font.pixelSize: 16; font.family: Theme.font }
            Row2 { title: "Design review"; sub: "15:00 - 15:45  room 4" }
            Row2 { title: "Dinner with Mara"; sub: "20:00  table booked" }
            Row2 { title: "Plan TilesDE"; sub: "all day" }
        } }
    Component { id: notesC
        Item {
            Flickable { anchors.fill: parent; anchors.margins: Theme.pageMargin + 4; contentHeight: te.height; clip: true
                TextEdit { id: te; width: parent.width; height: Math.max(implicitHeight, 400); color: Theme.text; font.pixelSize: 18; font.family: Theme.font; font.weight: Theme.fontLight; wrapMode: TextEdit.Wrap
                    text: "TilesDE ideas\n\n- flat accent tiles\n- turnstile transitions\n"; selectByMouse: true } }
        } }
    Component { id: settingsC
        Column {
            Text { x: Theme.pageMargin + 4; topPadding: 16; bottomPadding: 6; text: "accent colour"; color: Theme.textDim; font.pixelSize: 15; font.family: Theme.font }
            Item { width: parent.width; height: 120
                Grid { x: Theme.pageMargin + 4; columns: 6; spacing: Theme.tileGap
                    Repeater { model: Theme.accents
                        Rectangle { required property var modelData; required property int index
                            width: 56; height: 56; color: modelData
                            border.width: Theme.accent.toString() === Qt.color(modelData).toString() ? 3 : 0; border.color: Theme.text
                            MouseArea { anchors.fill: parent; onClicked: Theme.setAccent(index) } } } } }
            Row2 { title: "dark theme"; toggle: true; on: Theme.dark; onClicked: Theme.dark = !Theme.dark }
            Row2 { title: "reduce motion"; toggle: true; on: Services.reduceMotion; onClicked: Services.reduceMotion = !Services.reduceMotion }
            Row2 { title: "quiet hours"; toggle: true; on: Services.dnd; onClicked: Services.dnd = !Services.dnd }
            Row2 { title: "wi-fi"; sub: Services.wifi ? "on" : "off"; toggle: true; on: Services.wifi; onClicked: Services.wifi = !Services.wifi }
        } }
    Component { id: phoneC
        Item {
            id: ph
            property string num: ""
            Text { id: nlab; anchors { top: parent.top; topMargin: 20; left: parent.left; leftMargin: Theme.pageMargin + 4 }
                text: ph.num.length ? ph.num : " "; color: Theme.text; font.pixelSize: 40; font.family: Theme.font; font.weight: Theme.fontLight }
            Grid { anchors { top: nlab.bottom; topMargin: 24; horizontalCenter: parent.horizontalCenter } columns: 3; spacing: Theme.tileGap
                Repeater { model: ["1","2","3","4","5","6","7","8","9","*","0","#"]
                    Rectangle { required property string modelData; width: 100; height: 80
                        color: kma.pressed ? Theme.accent : (Theme.dark ? "#2b2b2b" : "#dcdcdc")
                        Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 30; color: Theme.text; font.family: Theme.font; font.weight: Theme.fontLight }
                        MouseArea { id: kma; anchors.fill: parent; onClicked: ph.num += modelData } } } }
        } }
    Component { id: noxalC
        Item {
            Column { anchors { top: parent.top; topMargin: 20; left: parent.left; right: parent.right; margins: Theme.pageMargin + 4 } spacing: Theme.tileGap
                Rectangle { width: parent.width * 0.85; height: t1.height + 24; color: Theme.dark ? "#2b2b2b" : "#dcdcdc"
                    Text { id: t1; x: 14; y: 12; width: parent.width - 28; wrapMode: Text.Wrap; text: "Hi, I am Noxal. Ask me to summarise your notifications or plan your day. (prototype: no model attached)"; color: Theme.text; font.pixelSize: 16; font.family: Theme.font; font.weight: Theme.fontLight } } }
            Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: Theme.pageMargin + 4 } height: 48; color: "transparent"; border.width: 2; border.color: Theme.text
                Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "ask noxal"; color: Theme.textDim; font.pixelSize: 16; font.family: Theme.font } }
        } }
    Component { id: emptyC
        Item {
            Column { anchors { top: parent.top; topMargin: 20; left: parent.left; right: parent.right; margins: Theme.pageMargin + 4 } spacing: Theme.tileGap
                Block { width: parent.width; height: 120; label: root.name; value: root.launching ? "starting" : "ready" }
                Row { spacing: Theme.tileGap
                    Block { width: (parent.parent.width - Theme.tileGap) / 2; height: 120; label: "recent"; value: "3" }
                    Block { width: (parent.parent.width - Theme.tileGap) / 2; height: 120; label: "new"; value: "1" } }
                Text { topPadding: 14; text: "prototype page. nothing here yet."; color: Theme.textDim; font.pixelSize: 15; font.family: Theme.font }
            }
        } }
}
