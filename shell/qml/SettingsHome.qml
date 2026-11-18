import QtQuick
import FlowShell
import "TilePresets.js" as TilePresets
import "settings2/index.js" as More

// Settings root: pivot 'system' / 'applications'. Emits open(name) with a sub-page name:
// "start+theme", "lock screen", or "app:<tileId>".
Item {
    id: root
    property alias currentIndex: pivot.currentIndex
    signal open(string page)

    Pivot {
        id: pivot
        anchors.fill: parent
        caption: "settings"
        PivotPage {
            title: "system"
            Item { width: 1; height: 12 }
            MetroListRow { title: "start+theme"; subtitle: "background, accent, tiles, groups"
                onClicked: root.open("start+theme") }
            MetroListRow { title: "lock screen"; subtitle: "status, notifications, time-out"
                onClicked: root.open("lock screen") }
            Repeater {
                model: More.entries
                MetroListRow {
                    required property var modelData
                    title: modelData.title; subtitle: modelData.subtitle
                    onClicked: root.open(modelData.key)
                }
            }
        }
        PivotPage {
            title: "applications"
            Item { width: 1; height: 12 }
            Repeater {
                model: TilePresets.defaultTiles()
                MetroListRow {
                    required property var modelData
                    glyph: modelData.glyph; title: modelData.label.toLowerCase()
                    subtitle: modelData.group !== "" ? modelData.group : "start"
                    iconColor: Theme.tileColor(modelData.id, modelData.color)
                    onClicked: root.open("app:" + modelData.id)
                }
            }
        }
    }
}
