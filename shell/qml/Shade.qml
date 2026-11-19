import QtQuick
import FlowShell

// Action Centre: solid near-black panel sliding from the top. progress 0..1.
Item {
    id: root
    property real progress: 0
    property bool expanded: false
    visible: progress > 0.001
    y: -(1 - Math.min(1, Math.max(0, progress))) * height
    signal openSettings
    signal lockRequested
    // notification app name -> TileGlyph name
    function glyphFor(app) {
        const a = String(app).toLowerCase()
        const m = { messages: "message", messaging: "message", system: "settings", updates: "settings", contacts: "people", photos: "photos" }
        return m[a] || a
    }
    readonly property color panel: Theme.pageBg
    readonly property color cardColor: "transparent"
    onProgressChanged: if (progress < 0.01) expanded = false

    // flat quick tile: Toggle supplies fill and glyph, caption is drawn here in uppercase
    component QTile : Item {
        id: qt
        property string label: ""
        property string glyph: ""
        property bool active: false
        property bool avail: true      // false: hardware missing, tile dimmed and inert
        signal toggled
        opacity: avail ? 1 : 0.4
        Toggle { id: tg; anchors.fill: parent; glyph: qt.glyph; active: qt.active; enabled: qt.avail; onToggled: qt.toggled() }
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 6; bottomMargin: 6 }
            text: qt.label.toUpperCase(); elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
            color: qt.active ? Theme.onColor(Theme.accent) : Theme.text
            font.pixelSize: 11; font.family: Theme.font; font.weight: Font.DemiBold; lineHeight: 0.95
        }
    }

    Rectangle { anchors.fill: parent; color: root.panel
        MouseArea { anchors.fill: parent } }   // swallow taps

    Column {
        id: top
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 36; leftMargin: Theme.pageMargin; rightMargin: Theme.pageMargin }
        spacing: Theme.tileGap
        readonly property real tw: (width - 3 * Theme.tileGap) / 4
        Row {
            spacing: Theme.tileGap
            QTile { width: top.tw; height: top.tw; avail: Services.wifiAvailable; label: !Services.wifiAvailable ? "No Wi-Fi" : (Services.wifi ? (Services.wifiName || "Wi-Fi") : "Wi-Fi off"); glyph: "wifi"; active: Services.wifi && Services.wifiAvailable; onToggled: Services.wifi = !Services.wifi }
            QTile { width: top.tw; height: top.tw; avail: Services.bluetoothAvailable; label: !Services.bluetoothAvailable ? "No Bluetooth" : (Services.bluetooth ? "Bluetooth" : "Bluetooth off"); glyph: "bluetooth"; active: Services.bluetooth && Services.bluetoothAvailable; onToggled: Services.bluetooth = !Services.bluetooth }
            QTile { width: top.tw; height: top.tw; label: "Rotation lock"; glyph: "rotate"; active: Services.rotationLock; onToggled: Services.rotationLock = !Services.rotationLock }
            QTile { width: top.tw; height: top.tw; label: "Quiet"; glyph: "moon"; active: Services.dnd; onToggled: Services.dnd = !Services.dnd }
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
                QTile { width: top.tw; height: top.tw; label: "Airplane mode"; glyph: "plane"; active: Services.airplane; onToggled: Services.airplane = !Services.airplane }
                QTile { width: top.tw; height: top.tw; label: Theme.dark ? "Dark" : "Light"; glyph: "sun"; active: Theme.dark; onToggled: Theme.dark = !Theme.dark }
                QTile { width: top.tw; height: top.tw; label: "Sound"; glyph: "sound"; avail: Services.volumeAvailable; active: Services.volume > 0.01; onToggled: Services.volume = (Services.volume > 0.01 ? 0 : 0.45) }
                QTile { width: top.tw; height: top.tw; label: "Motion"; glyph: "motion"; active: !Services.reduceMotion; onToggled: Services.reduceMotion = !Services.reduceMotion }
            }
        }
        Item {
            width: parent.width; height: 28
            Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: root.expanded ? "less" : "more"; color: Theme.textDim; font.pixelSize: 12; font.family: Theme.font
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: root.expanded = !root.expanded } }
        }
        SliderRow { width: parent.width; height: 48; glyph: "sun"; value: Services.brightness; onMoved: (v) => Services.brightness = v
            enabled: Services.brightnessAvailable; opacity: enabled ? 1 : 0.4 }
        SliderRow { width: parent.width; height: 48; glyph: "sound"; value: Services.volume; onMoved: (v) => Services.volume = v
            enabled: Services.volumeAvailable; opacity: enabled ? 1 : 0.4 }
    }

    Item {
        id: nhead
        anchors { top: top.bottom; topMargin: 12; left: parent.left; right: parent.right; leftMargin: Theme.pageMargin + 4; rightMargin: Theme.pageMargin + 4 }
        height: 40
        Row { id: clearRow; spacing: 10; anchors.verticalCenter: parent.verticalCenter
            TileGlyph { size: 18; stroke: 2.4; name: "close"; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "CLEAR ALL"; color: Theme.text; font.pixelSize: 12; font.family: Theme.font; font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter } }
        MouseArea { anchors.fill: clearRow; anchors.margins: -12; onClicked: Services.notifications.clear() }
        Row { id: lockRow; spacing: 10; anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            TileGlyph { size: 18; stroke: 2.4; name: "lock"; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "LOCK"; color: Theme.text; font.pixelSize: 12; font.family: Theme.font; font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter } }
        MouseArea { anchors.fill: lockRow; anchors.margins: -12; onClicked: root.lockRequested() }
        Row { id: setRow; spacing: 10; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            TileGlyph { size: 18; stroke: 2.4; name: "settings"; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "ALL SETTINGS"; color: Theme.text; font.pixelSize: 12; font.family: Theme.font; font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter } }
        MouseArea { anchors.fill: setRow; anchors.margins: -12; onClicked: root.openSettings() }
    }

    ListView {
        id: nl
        anchors { top: nhead.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: Theme.pageMargin; rightMargin: Theme.pageMargin; bottomMargin: 28 }
        spacing: 14; clip: true; model: Services.notifications
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
            required property int urgency
            readonly property int appCount: Services.notifications.counts[String(app).toLowerCase()] || 1
            width: nl.width
            height: card.height
            Rectangle {
                id: card
                width: dl.width; height: txt.implicitHeight + 20
                color: "transparent"
                opacity: 1 - Math.min(1, Math.abs(x) / (dl.width * 0.8))
                Rectangle { visible: dl.urgency >= 2; width: 4; height: parent.height - 12; y: 6; color: Theme.accent }
                Column {
                    id: txt
                    x: 4; y: 10; width: parent.width - 8; spacing: 8
                    Row { spacing: 14
                        Rectangle { width: 44; height: 44; radius: Theme.tileRadius; color: Theme.accent
                            TileGlyph { anchors.centerIn: parent; size: 26; stroke: 2.2; name: root.glyphFor(dl.app); color: Theme.onColor(Theme.accent) } }
                        Text { text: dl.app + (dl.appCount > 1 ? "  " + dl.appCount : ""); color: Theme.text; anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 26; font.family: Theme.font; font.weight: Theme.fontLight } }
                    Row { width: parent.width
                        Text { width: parent.width - tm.implicitWidth - 8; text: dl.title + (dl.body ? ": " + dl.body : ""); elide: Text.ElideRight
                            color: Theme.text; font.pixelSize: 17; font.family: Theme.font; font.weight: Font.DemiBold }
                        Text { id: tm; text: dl.time; color: Theme.text; font.pixelSize: 15; font.family: Theme.font } }
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

    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 16; color: Theme.accent
        Rectangle { anchors.centerIn: parent; width: 24; height: 3; color: Theme.onColor(Theme.accent); opacity: 0.8 } }
}
