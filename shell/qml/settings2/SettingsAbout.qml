import QtQuick
import FlowShell

// Settings > extras+info. Pivot: "extras" (personalisation file and reset) and "info" (device facts).
Item {
    id: root
    property string title: "extras+info"

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "extras"

            MetroSectionHeader { text: "personalisation" }
            MetroListRow {
                width: parent.width
                glyph: "settings"
                title: "preset " + Personalise.preset
                subtitle: Personalise.scheme + " scheme"
            }
            MetroListRow {
                width: parent.width
                title: "settings file"
                subtitle: Personalise.path
                trailing: Personalise.status
            }
            Item { width: 1; height: 24 }
            MetroButton {
                text: "reset personalisation"
                onClicked: Personalise.reset()
            }
            Item { width: 1; height: 12 }
            Text {
                width: parent.width
                text: "restores the glaze preset, default groups and tile colours"
                color: Theme.textDim; wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 18
            }
        }

        PivotPage {
            title: "info"

            MetroSectionHeader { text: "this phone" }
            MetroListRow {
                width: parent.width
                glyph: "phone"
                title: "TilesDE"
                subtitle: "start screen shell"
            }
            MetroListRow {
                width: parent.width
                title: "battery"
                subtitle: Services.charging ? "charging" : "on battery"
                trailing: Services.battery + "%"
            }
            MetroListRow {
                width: parent.width
                title: "services"
                subtitle: Services.mock ? "mock data, no device" : "device services"
            }
            MetroListRow {
                width: parent.width
                title: "design size"
                subtitle: "540 x 1170"
            }
        }
    }
}
