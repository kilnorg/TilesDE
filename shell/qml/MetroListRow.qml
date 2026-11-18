import QtQuick
import FlowShell

// List row: 24px light title, grey subtitle, optional accent square icon (TileGlyph name), optional usage bar (0..1, <0 hides).
// Height 68 (72 with bar). Left margin 0 (host column supplies 18). No dividers.
Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property color iconColor: Theme.accent
    property real usage: -1
    property color usageColor: Theme.accent
    property string trailing: ""
    signal clicked
    signal pressAndHold
    width: parent ? parent.width : 360
    height: usage >= 0 ? 72 + 8 : 68
    opacity: area.pressed ? 0.6 : 1
    readonly property real iconW: glyph !== "" ? 56 : 0
    Rectangle {
        id: icon
        visible: root.glyph !== ""
        y: 6; width: 56; height: 56; color: root.iconColor
        TileGlyph { anchors.centerIn: parent; name: root.glyph; size: 34; color: Theme.onColor(root.iconColor) }
    }
    Column {
        x: root.iconW > 0 ? root.iconW + 14 : 0
        y: root.glyph !== "" ? 6 : 4
        width: parent.width - x - (trail.visible ? trail.width + 12 : 0)
        Text {
            width: parent.width; text: root.title; color: Theme.text; elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
        }
        Text {
            visible: root.subtitle !== ""
            width: parent.width; text: root.subtitle; color: Theme.textDim; elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 18
        }
        Item {
            visible: root.usage >= 0
            width: parent.width; height: 12
            Rectangle { y: 4; width: parent.width; height: 6; color: Theme.dark ? "#333333" : "#cccccc" }
            Rectangle { y: 4; width: parent.width * Math.max(0, Math.min(1, root.usage)); height: 6; color: root.usageColor }
        }
    }
    Text {
        id: trail
        visible: root.trailing !== ""
        anchors.right: parent.right; y: 6
        text: root.trailing; color: Theme.textDim
        font.family: Theme.font; font.pixelSize: 18
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: root.clicked(); onPressAndHold: root.pressAndHold() }
}
