import QtQuick
import FlowShell

// Start-screen group heading (Glaze style): light type, small chevron that rotates when collapsed.
// Tap toggles collapse (signal toggled). In edit mode the title is editable (renamed(newName)) and a remove button shows.
// Heading text honours Theme.title (lower/upper case) and Theme.fontLight weight. Respects Theme.reduceMotion.
Item {
    id: root
    property string text: ""
    property bool collapsed: false
    property bool editing: false
    property int count: 0                      // tiles in the group (shown dimmed when collapsed)
    signal toggled()
    signal renamed(string newName)
    signal removeRequested()

    implicitHeight: 36

    Row {
        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
        spacing: 10
        Text {
            id: label
            visible: !root.editing
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.title(root.text)
            color: Theme.text
            font.family: Theme.font; font.pixelSize: 20; font.weight: Theme.fontLight
        }
        TextInput {
            id: edit
            visible: root.editing
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(80, contentWidth + 8)
            text: root.text
            color: Theme.text; selectionColor: Theme.accent
            font.family: Theme.font; font.pixelSize: 20; font.weight: Theme.fontLight
            onEditingFinished: { if (text.trim() !== "" && text !== root.text) root.renamed(text.trim()); else text = root.text }
            onVisibleChanged: if (!visible) focus = false
        }
        Text {
            visible: root.collapsed && root.count > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            color: Theme.textDim
            font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Light
        }
        // chevron
        Canvas {
            id: chev
            width: 14; height: 14
            anchors.verticalCenter: parent.verticalCenter
            rotation: root.collapsed ? -90 : 0
            Behavior on rotation { enabled: !Theme.reduceMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            property color ink: Theme.textDim
            onInkChanged: requestPaint()
            onPaint: {
                const c = getContext("2d")
                c.clearRect(0, 0, width, height)
                c.strokeStyle = ink; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
                c.beginPath(); c.moveTo(2, 4.5); c.lineTo(7, 9.5); c.lineTo(12, 4.5); c.stroke()
            }
        }
    }

    // tap area (toggle) covers the title row; ignored while renaming
    MouseArea {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: removeBtn.visible ? removeBtn.left : parent.right }
        enabled: !root.editing
        onClicked: root.toggled()
    }

    // edit mode: remove group (its tiles fall back to the top block)
    Rectangle {
        id: removeBtn
        visible: root.editing
        width: 28; height: 28; radius: 14
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        color: Theme.c.card
        border.width: 1; border.color: Theme.textDim
        TileGlyph { anchors.centerIn: parent; size: 16; name: "close"; color: Theme.text; stroke: 2 }
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.removeRequested() }
    }
}
