import QtQuick
import FlowShell

// Task switcher: two-column grid of flat app cards. Tap opens, x closes, "close all" at the bottom.
Item {
    id: root
    signal picked(string name)
    signal closedAll
    signal closedOne(string name)
    property var running: []
    visible: opacity > 0.02

    Text {
        id: head
        anchors { top: parent.top; topMargin: 44; left: parent.left; leftMargin: Theme.pageMargin }
        text: Theme.title("running apps"); color: Theme.text
        font.pixelSize: 36; font.family: Theme.font; font.weight: Theme.fontLight
    }
    Text {
        visible: root.running.length === 0
        anchors.centerIn: parent
        text: "no running apps"; color: Theme.textDim
        font.pixelSize: 18; font.family: Theme.font; font.weight: Theme.fontLight
    }
    GridView {
        id: grid
        anchors { top: head.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: Theme.pageMargin; rightMargin: Theme.pageMargin; bottomMargin: 56 + 44 + 28 }
        clip: true
        cellWidth: Math.floor((width + Theme.tileGap) / 2); cellHeight: Math.round(cellWidth * 1.45)
        boundsBehavior: Flickable.StopAtBounds
        model: root.running
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth; height: grid.cellHeight
            Rectangle {
                id: card
                anchors { fill: parent; leftMargin: 0; topMargin: 0; rightMargin: Theme.tileGap; bottomMargin: Theme.tileGap }
                color: Theme.dark ? "#1f1f1f" : "#e4e4e4"; radius: Theme.tileRadius
                scale: ma.pressed ? 0.96 : 1
                Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.pressMs } }
                Rectangle {
                    id: bar
                    width: parent.width; height: 38; color: Theme.dark ? "#2b2b2b" : "#cfcfcf"
                    Text { anchors { left: parent.left; leftMargin: 10; right: xbtn.left; verticalCenter: parent.verticalCenter }
                        text: String(cell.modelData).toLowerCase(); elide: Text.ElideRight; color: Theme.text
                        font.pixelSize: 12; font.family: Theme.font }
                    Item { id: xbtn; width: 38; height: 38; anchors.right: parent.right
                        TileGlyph { anchors.centerIn: parent; size: 18; stroke: 2; name: "close"; color: Theme.text }
                    }
                }
                Rectangle {
                    anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                    color: Theme.accent; radius: Theme.tileRadius; opacity: Theme.tileOpacity
                    TileGlyph { anchors.centerIn: parent; size: 56; name: String(cell.modelData).toLowerCase(); color: Theme.onColor(Theme.accent) }
                }
                MouseArea { id: ma; anchors.fill: parent; onClicked: root.picked(String(cell.modelData)) }
                MouseArea { anchors { top: parent.top; right: parent.right } width: 48; height: 44
                    onClicked: root.closedOne(String(cell.modelData)) }
            }
        }
    }
    Item {
        visible: root.running.length > 0
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 72 }
        width: 160; height: 44
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Theme.text
            opacity: allMa.pressed ? 0.6 : 1 }
        Text { anchors.centerIn: parent; text: "close all"; color: Theme.text; font.pixelSize: 16; font.family: Theme.font; font.weight: Theme.fontLight }
        MouseArea { id: allMa; anchors.fill: parent; onClicked: root.closedAll() }
    }
}
