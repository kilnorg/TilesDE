import QtQuick
import FlowShell

// Action Centre: solid near-black panel sliding from the top. progress 0..1.
Item {
    id: root
    property real progress: 0
    property bool expanded: false
    visible: progress > 0.001
    y: -(1 - progress) * height
    readonly property color panel: Theme.dark ? "#101010" : "#ececec"
    readonly property color cardColor: Theme.dark ? "#1f1f1f" : "#ffffff"
    onProgressChanged: if (progress < 0.01) expanded = false

    Rectangle { anchors.fill: parent; color: root.panel
        MouseArea { anchors.fill: parent } }   // swallow taps

    Column {
        id: top
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 56; leftMargin: Theme.pageMargin; rightMargin: Theme.pageMargin }
        spacing: Theme.tileGap
        readonly property real tw: (width - 3 * Theme.tileGap) / 4
        Row {
            spacing: Theme.tileGap
            Toggle { width: top.tw; height: top.tw; label: "Wi-Fi"; glyph: "wifi"; active: Services.wifi; onToggled: Services.wifi = !Services.wifi }
            Toggle { width: top.tw; height: top.tw; label: "Bluetooth"; glyph: "bluetooth"; active: Services.bluetooth; onToggled: Services.bluetooth = !Services.bluetooth }
            Toggle { width: top.tw; height: top.tw; label: "Rotation"; glyph: "rotate"; active: Services.rotationLock; onToggled: Services.rotationLock = !Services.rotationLock }
            Toggle { width: top.tw; height: top.tw; label: "Quiet"; glyph: "moon"; active: Services.dnd; onToggled: Services.dnd = !Services.dnd }
        }
        Item {
            width: parent.width
            height: root.expanded ? top.tw : 0
            clip: true
            opacity: root.expanded ? 1 : 0
            Behavior on height { enabled: !Theme.reduceMotion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { enabled: !Theme.reduceMotion; NumberAnimation { duration: 200 } }
            Row {
                spacing: Theme.tileGap
                Toggle { width: top.tw; height: top.tw; label: "Airplane"; glyph: "plane"; active: Services.airplane; onToggled: Services.airplane = !Services.airplane }
                Toggle { width: top.tw; height: top.tw; label: Theme.dark ? "Dark" : "Light"; glyph: "sun"; active: Theme.dark; onToggled: Theme.dark = !Theme.dark }
                Toggle { width: top.tw; height: top.tw; label: "Sound"; glyph: "sound"; active: Services.volume > 0.01; onToggled: Services.volume = (Services.volume > 0.01 ? 0 : 0.45) }
                Toggle { width: top.tw; height: top.tw; label: "Motion"; glyph: "motion"; active: !Services.reduceMotion; onToggled: Services.reduceMotion = !Services.reduceMotion }
            }
        }
        Item {
            width: parent.width; height: 40
            Text { id: expTxt; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: root.expanded ? "collapse" : "expand"; color: Theme.text
                font.pixelSize: 16; font.family: Theme.font; font.weight: Theme.fontLight
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: root.expanded = !root.expanded } }
        }
        SliderRow { width: parent.width; height: 48; glyph: "sun"; value: Services.brightness; onMoved: (v) => Services.brightness = v }
    }

    Item {
        id: nhead
        anchors { top: top.bottom; topMargin: 14; left: parent.left; right: parent.right; leftMargin: Theme.pageMargin + 2; rightMargin: Theme.pageMargin + 2 }
        height: 36
        Text { anchors.verticalCenter: parent.verticalCenter; text: "notifications"; color: Theme.text
            font.pixelSize: 22; font.family: Theme.font; font.weight: Theme.fontLight }
        Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: "clear all"; color: Theme.accent
            font.pixelSize: 16; font.family: Theme.font; font.weight: Theme.fontLight
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: Services.notifications.clear() } }
    }

    ListView {
        id: nl
        anchors { top: nhead.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: Theme.pageMargin; rightMargin: Theme.pageMargin; bottomMargin: 36 }
        spacing: Theme.tileGap; clip: true; model: Services.notifications
        boundsBehavior: Flickable.StopAtBounds
        Text { visible: nl.count === 0; anchors { top: parent.top; topMargin: 20; left: parent.left; leftMargin: 4 }
            text: "no new notifications"; color: Theme.textDim; font.pixelSize: 16; font.family: Theme.font; font.weight: Theme.fontLight }
        delegate: Item {
            id: dl
            required property int index
            required property string app
            required property string title
            required property string body
            required property string time
            width: nl.width
            height: card.height
            Rectangle {
                id: card
                width: dl.width; height: txt.implicitHeight + 24
                color: root.cardColor
                opacity: 1 - Math.min(1, Math.abs(x) / (dl.width * 0.8))
                Rectangle { width: 4; height: parent.height; color: Theme.accent }
                Column {
                    id: txt
                    x: 16; y: 12; width: parent.width - 32; spacing: 2
                    Row { width: parent.width
                        Text { width: parent.width - tm.implicitWidth; text: dl.app.toLowerCase(); elide: Text.ElideRight; color: Theme.accent
                            font.pixelSize: 13; font.family: Theme.font }
                        Text { id: tm; text: dl.time; color: Theme.textDim; font.pixelSize: 12; font.family: Theme.font } }
                    Text { width: parent.width; text: dl.title; elide: Text.ElideRight; color: Theme.text
                        font.pixelSize: 17; font.family: Theme.font; font.weight: Font.DemiBold }
                    Text { width: parent.width; text: dl.body; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: Theme.textDim
                        font.pixelSize: 14; font.family: Theme.font; font.weight: Theme.fontLight }
                }
                DragHandler {
                    id: dh
                    target: card; yAxis.enabled: false
                    onActiveChanged: if (!active) {
                        if (Math.abs(card.x) > dl.width * 0.35) away.start(); else back.start()
                    }
                }
                NumberAnimation { id: back; target: card; property: "x"; to: 0; duration: Theme.reduceMotion ? 0 : 160 }
                SequentialAnimation { id: away
                    NumberAnimation { target: card; property: "x"; to: card.x > 0 ? dl.width : -dl.width; duration: Theme.reduceMotion ? 0 : 160 }
                    ScriptAction { script: Services.notifications.dismiss(dl.index) } }
            }
        }
    }

    Rectangle { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        width: 44; height: 4; color: Theme.text; opacity: 0.4 }
}
