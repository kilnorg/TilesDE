import QtQuick
import FlowShell

// Start-group manager: rename (inline field), reorder (up/down), remove, add. Operates on Personalise.groups.
Column {
    id: root
    width: parent ? parent.width : 360
    spacing: 10
    component SquareBtn: Item {
        id: sb
        property string glyph: ""
        property real rot: 0
        property bool on: true
        signal tapped
        width: 56; height: 56
        opacity: !on ? 0.3 : (ma.pressed ? 0.5 : 1)
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Theme.text }
        TileGlyph { anchors.centerIn: parent; name: sb.glyph; size: 26; color: Theme.text; stroke: 2; rotation: sb.rot }
        MouseArea { id: ma; anchors.fill: parent; enabled: sb.on; onClicked: sb.tapped() }
    }
    Repeater {
        model: Personalise.groups
        Row {
            required property int index
            required property var modelData
            spacing: 8
            width: root.width
            MetroTextField {
                width: parent.width - 3 * 64
                text: modelData.name
                onAccepted: { Personalise.renameGroup(index, text) }
            }
            SquareBtn { glyph: "back"; rot: 90; on: index > 0; onTapped: Personalise.moveGroup(index, index - 1) }
            SquareBtn { glyph: "back"; rot: -90; on: index < Personalise.groups.length - 1; onTapped: Personalise.moveGroup(index, index + 1) }
            SquareBtn { glyph: "close"; onTapped: Personalise.removeGroup(index) }
        }
    }
    Row {
        spacing: 8
        width: root.width
        MetroTextField { id: nameField; width: parent.width - 64; placeholder: "new group name"
            onAccepted: if (text.trim() !== "") { Personalise.addGroup(text.trim()); text = "" } }
        SquareBtn { glyph: "plus"; on: nameField.text.trim() !== ""
            onTapped: { Personalise.addGroup(nameField.text.trim()); nameField.text = "" } }
    }
}
