import QtQuick
import FlowShell

// Outlined rectangle with sliding block; caption above, big On/Off label.
// Props: label, checked, onText/offText. Signal toggled(bool).
Item {
    id: root
    property string label: ""
    property bool checked: false
    property string onText: "On"
    property string offText: "Off"
    signal toggled(bool value)
    implicitWidth: 360
    Text {
        id: cap
        visible: root.label !== ""
        text: root.label; color: Theme.textDim
        font.family: Theme.font; font.pixelSize: 21
        width: parent.width; elide: Text.ElideRight
    }
    Text {
        id: val
        y: cap.visible ? cap.height + 4 : 0
        text: root.checked ? root.onText : root.offText
        color: Theme.text
        font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight
    }
    Rectangle {
        id: track
        y: val.y + val.height + 8
        width: 96; height: 40
        color: "transparent"
        border.width: 2; border.color: Theme.text
        Rectangle {
            id: block
            y: 5; width: 34; height: 30
            x: root.checked ? track.width - width - 5 : 5
            color: root.checked ? Theme.accent : Theme.text
            Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { enabled: !Theme.reduceMotion; ColorAnimation { duration: 140 } }
        }
        opacity: area.pressed ? 0.6 : 1
    }
    MouseArea {
        id: area
        anchors.fill: track
        anchors.margins: -12
        onClicked: { root.checked = !root.checked; root.toggled(root.checked) }
    }
    implicitHeight: track.y + track.height
}
