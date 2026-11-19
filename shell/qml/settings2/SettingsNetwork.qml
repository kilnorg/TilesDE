import QtQuick
import FlowShell

// Settings > network+. Pivot: "network" (radios from Services) and "advanced" (local options, not persisted).
Item {
    id: root
    property string title: "network+"

    readonly property var dataModel: ["off", "4g", "3g"]
    property int dataIndex: 1
    property bool metered: false
    property string deviceName: "tilesde"

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "network"

            MetroSectionHeader { text: "radios" }
            MetroToggle {
                width: parent.width
                label: "wi-fi"
                onText: "On"; offText: "Off"
                checked: Services.wifi
                onToggled: (v) => Services.wifi = v
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "bluetooth"
                onText: "On"; offText: "Off"
                checked: Services.bluetooth
                onToggled: (v) => Services.bluetooth = v
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "airplane mode"
                onText: "On"; offText: "Off"
                checked: Services.airplane
                onToggled: (v) => Services.airplane = v
            }
            MetroSectionHeader { text: "status" }
            MetroListRow {
                width: parent.width
                glyph: "browser"
                title: !Services.wifiAvailable ? "no wi-fi hardware" : (Services.airplane ? "airplane mode" : (Services.wifi ? (Services.wifiName || "not connected") : "wi-fi off"))
                subtitle: Services.wifiAvailable ? "signal " + Services.signal + " of 4" : "bluetooth " + (Services.bluetoothAvailable ? "available" : "not available")
                usage: Services.signal / 4
                usageColor: Theme.accent
            }
        }

        PivotPage {
            title: "advanced"

            MetroSectionHeader { text: "mobile data" }
            MetroDropdown {
                width: parent.width
                label: "data"
                model: root.dataModel
                currentIndex: root.dataIndex
                onActivated: (i) => root.dataIndex = i
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "metered connection"
                onText: "On"; offText: "Off"
                checked: root.metered
                onToggled: (v) => root.metered = v
            }
            MetroSectionHeader { text: "this device" }
            MetroTextField {
                width: parent.width
                label: "device name"
                text: root.deviceName
                placeholder: "tilesde"
                onAccepted: root.deviceName = text.trim() || "tilesde"
            }
        }
    }
}
