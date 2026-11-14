import QtQuick
import FlowShell

// Full-screen letter grid. Letters without apps are greyed and inert.
// `available`: object {"a": true, ...}. Emits picked(letter) or closed().
Item {
    id: root
    property var available: ({})
    property bool open: false
    signal picked(string letter)
    signal closed()

    readonly property var letters: ["#","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
    visible: opacity > 0.01
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : 160 } }

    Rectangle { anchors.fill: parent; color: "#F2000000" }
    MouseArea { anchors.fill: parent; onClicked: root.closed() }

    Grid {
        id: grid
        columns: 4
        spacing: Theme.tileGap
        anchors.centerIn: parent
        readonly property real cell: Math.floor((root.width - 2 * Theme.pageMargin - 3 * Theme.tileGap) / 4)
        scale: root.open ? 1 : 0.92
        Behavior on scale { NumberAnimation { duration: Theme.reduceMotion ? 0 : 200; easing.type: Easing.OutCubic } }

        Repeater {
            model: root.letters
            delegate: Rectangle {
                id: cell
                required property string modelData
                required property int index
                readonly property bool has: root.available[modelData] === true
                width: grid.cell; height: grid.cell
                color: has ? (ma.pressed ? Qt.darker(Theme.accent, 1.25) : Theme.accent) : "#2A2A2A"
                scale: ma.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: Theme.reduceMotion ? 0 : 90 } }
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: 8; bottomMargin: 4 }
                    text: cell.modelData
                    color: cell.has ? "white" : "#6A6A6A"
                    font.family: "Inter"; font.weight: Font.Light; font.pixelSize: 40
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    enabled: cell.has
                    onClicked: root.picked(cell.modelData)
                }
            }
        }
    }
}
