import QtQuick
import FlowShell

// Flat outlined list picker. Tapping opens a full-width sheet of rows over the window.
// Props: label, model (array of strings), currentIndex, currentText (read-only). Signal activated(i).
Item {
    id: root
    property string label: ""
    property var model: []
    property int currentIndex: 0
    readonly property string currentText: currentIndex >= 0 && currentIndex < model.length ? String(model[currentIndex]) : ""
    property bool open: false
    signal activated(int index)
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
        color: "transparent"; border.width: 2; border.color: Theme.text
        opacity: area.pressed ? 0.6 : 1
        Text {
            anchors.verticalCenter: parent.verticalCenter; x: 12; width: parent.width - 60
            text: root.currentText; color: Theme.text; elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
        }
        Canvas {
            width: 16; height: 10; x: parent.width - 30; anchors.verticalCenter: parent.verticalCenter
            property color ink: Theme.text
            onInkChanged: requestPaint()
            onPaint: { var c = getContext("2d"); c.clearRect(0, 0, width, height); c.strokeStyle = ink; c.lineWidth = 2
                c.beginPath(); c.moveTo(1, 1); c.lineTo(8, 8); c.lineTo(15, 1); c.stroke() }
        }
    }
    MouseArea { id: area; anchors.fill: box; onClicked: root.open = true }

    // sheet is built lazily (only while open or animating) so a page with many dropdowns loads fast.
    // p: 0 closed .. 1 open; the panel slides up from the bottom edge, the scrim fades.
    property real p: open ? 1 : 0
    Behavior on p { enabled: !Theme.reduceMotion
        NumberAnimation { duration: root.open ? 280 : 200; easing.type: root.open ? Easing.OutCubic : Easing.InCubic } }

    Loader {
        id: sheetLoader
        active: root.open || root.p > 0.001
        parent: root.Window.contentItem
        anchors.fill: parent
        z: 10000
        sourceComponent: sheetC
    }
    Component {
        id: sheetC
        Item {
            id: sheet
            MouseArea { anchors.fill: parent; onClicked: root.open = false }
            Rectangle { anchors.fill: parent; color: Theme.pageBg; opacity: 0.6 * root.p }
            Rectangle {
                id: panel
                width: parent.width
                height: Math.min(parent.height * 0.8, 24 + 28 + list.contentHeight + 12)
                y: parent.height - height * root.p
                color: Theme.dark ? "#1b1b1b" : "#e9e9e9"
                MouseArea { anchors.fill: parent }   // taps on the panel never reach the scrim
                Text {
                    x: 18; y: 20; text: root.label.toUpperCase(); color: Theme.text
                    font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
                }
                ListView {
                    id: list
                    y: 56; width: parent.width; height: parent.height - 56 - 12
                    clip: true; model: root.model; boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        required property int index
                        required property var modelData
                        width: list.width; height: 64
                        opacity: rowArea.pressed ? 0.6 : 1
                        Text {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            text: String(modelData)
                            color: index === root.currentIndex ? Theme.accent : Theme.text
                            font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                        }
                        MouseArea { id: rowArea; anchors.fill: parent
                            onClicked: { root.currentIndex = index; root.open = false; root.activated(index) } }
                    }
                }
            }
        }
    }
}
