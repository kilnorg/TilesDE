import QtQuick
import FlowShell

// 2px outlined input; caption above; border turns accent on focus.
Item {
    id: root
    property string label: ""
    property alias text: input.text
    property string placeholder: ""
    property alias echoMode: input.echoMode
    property alias inputMethodHints: input.inputMethodHints
    property alias validator: input.validator
    signal accepted
    signal edited
    implicitWidth: 360; implicitHeight: box.y + 56
    Text {
        id: cap
        visible: root.label !== ""
        text: root.label; color: Theme.textDim
        font.family: Theme.font; font.pixelSize: 21
        height: visible ? 28 : 0
    }
    Rectangle {
        id: box
        y: cap.height
        width: parent.width; height: 56
        color: input.activeFocus ? Theme.text : "transparent"
        border.width: 2; border.color: input.activeFocus ? Theme.accent : Theme.text
        TextInput {
            id: input
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: activeFocus ? Theme.pageBg : Theme.text
            selectionColor: Theme.accent
            font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            onAccepted: root.accepted()
            onTextEdited: root.edited()
            Text {
                visible: input.text === "" && !input.activeFocus
                text: root.placeholder; color: Theme.textDim
                font: input.font; anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
