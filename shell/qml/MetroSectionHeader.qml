import QtQuick
import FlowShell

// Section title inside a page: 28px light, dim, with top gap.
Item {
    id: root
    property string text: ""
    property bool accent: false
    width: parent ? parent.width : 360
    height: 28 * 1.3 + 28
    Text {
        y: 22
        width: parent.width; elide: Text.ElideRight
        text: Theme.title ? Theme.title(root.text) : root.text
        color: root.accent ? Theme.accent : Theme.textDim
        font.family: Theme.font; font.pixelSize: 28; font.weight: Theme.fontLight
    }
}
