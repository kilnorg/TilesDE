import QtQuick
import FlowShell

// Bottom app bar: up to 4 outlined round buttons plus "..." to expand labels and menu rows.
// items: [{glyph, label}], menuItems: [string]. Signals activated(i), menuActivated(i). Height 72 (collapsed).
Item {
    id: root
    property var items: []
    property var menuItems: []
    property bool expanded: false
    signal activated(int index)
    signal menuActivated(int index)
    readonly property real collapsedH: 72
    readonly property real menuH: menuItems.length * 56
    width: parent ? parent.width : 540
    height: collapsedH + (expanded ? 28 + menuH : 0)
    Behavior on height { enabled: !Theme.reduceMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    clip: true
    Rectangle { anchors.fill: parent; color: Theme.dark ? "#1b1b1b" : "#e6e6e6" }
    Row {
        id: btns
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        spacing: 28
        Repeater {
            model: root.items
            Item {
                required property int index
                required property var modelData
                width: 56; height: 56 + (root.expanded ? 22 : 0)
                opacity: ma.pressed ? 0.5 : 1
                Rectangle { width: 48; height: 48; radius: 24; x: 4; color: "transparent"; border.width: 2; border.color: Theme.text }
                TileGlyph { x: 14; y: 10; name: modelData.glyph || ""; size: 28; color: Theme.text; stroke: 2 }
                Text {
                    visible: root.expanded; y: 54; width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: (modelData.label || "").toLowerCase(); color: Theme.text
                    font.family: Theme.font; font.pixelSize: 16
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.activated(index) }
            }
        }
    }
    Text {
        visible: root.menuItems.length > 0
        anchors.right: parent.right; anchors.rightMargin: 18; y: 12
        text: "..."; color: Theme.text; font.family: Theme.font; font.pixelSize: 28
        MouseArea { anchors.fill: parent; anchors.margins: -16; onClicked: root.expanded = !root.expanded }
    }
    Column {
        y: root.collapsedH + 12 + 0
        visible: root.expanded
        width: parent.width
        Repeater {
            model: root.menuItems
            Item {
                required property int index
                required property var modelData
                width: parent.width; height: 56
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: String(modelData).toLowerCase()
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight }
                MouseArea { anchors.fill: parent; onClicked: { root.expanded = false; root.menuActivated(index) } }
            }
        }
    }
}
