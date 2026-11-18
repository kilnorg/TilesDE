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

    Rectangle { anchors.fill: parent; color: Theme.pageBg }
    MouseArea { anchors.fill: parent; onClicked: root.closed() }

    // 4 x 7 grid that fills the space between the status bar and the nav bar (Windows Phone jump list):
    // letters with apps are solid accent squares, the rest are dark and inert
    readonly property real topPad: 56
    readonly property real botPad: 76
    Grid {
        id: grid
        columns: 4
        spacing: Theme.tileGap
        x: Theme.pageMargin; y: root.topPad
        readonly property real cellW: Math.floor((root.width - 2 * Theme.pageMargin - 3 * Theme.tileGap) / 4)
        readonly property real cellH: Math.floor((root.height - root.topPad - root.botPad - 6 * Theme.tileGap) / 7)
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : 160 } }

        Repeater {
            model: root.letters
            delegate: Rectangle {
                id: cell
                required property string modelData
                required property int index
                readonly property bool has: root.available[modelData] === true
                width: grid.cellW; height: grid.cellH
                radius: Theme.tileRadius
                color: has ? (ma.pressed ? Qt.lighter(Theme.accent, 1.25) : Theme.accent) : (Theme.dark ? "#1a1a1a" : "#e2e2e2")
                scale: ma.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: Theme.reduceMotion ? 0 : 90 } }
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: 10; bottomMargin: 4 }
                    text: cell.modelData
                    color: cell.has ? Theme.onColor(Theme.accent) : Theme.textDim
                    opacity: cell.has ? 1 : 0.45
                    font.family: Theme.font; font.weight: Theme.fontLight; font.pixelSize: Math.min(44, grid.cellH * 0.5)
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
