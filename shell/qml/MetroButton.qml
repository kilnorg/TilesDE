import QtQuick
import FlowShell

// Outlined 2px button. Pressed: filled with text colour. `accent: true` fills with accent.
Item {
    id: root
    property string text: ""
    property bool accentFill: false
    property bool enabled2: true
    signal clicked
    implicitWidth: Math.max(140, label.implicitWidth + 48); implicitHeight: 56
    opacity: enabled2 ? 1 : 0.4
    Rectangle {
        anchors.fill: parent
        color: area.pressed ? Theme.text : (root.accentFill ? Theme.accent : "transparent")
        border.width: 2; border.color: root.accentFill ? Theme.accent : Theme.text
        Behavior on color { enabled: !Theme.reduceMotion; ColorAnimation { duration: 80 } }
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: area.pressed ? Theme.pageBg : (root.accentFill ? Theme.onColor(Theme.accent) : Theme.text)
        font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
    }
    MouseArea { id: area; anchors.fill: parent; enabled: root.enabled2; onClicked: root.clicked() }
}
