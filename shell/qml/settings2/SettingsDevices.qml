import QtQuick
import FlowShell

// Settings > device hub. Pivot: "devices" (bluetooth radio and paired devices) and "nearby" (scan).
// Paired devices are MOCK entries; a real pairing source is not wired yet.
Item {
    id: root
    property string title: "device hub"
    property bool scanning: false

    readonly property var paired: [
        { name: "headset", detail: "audio, paired", glyph: "music", linked: true },
        { name: "watch", detail: "health, paired", glyph: "clock", linked: false },
        { name: "laptop", detail: "files, paired", glyph: "files", linked: false }
    ]

    Timer {
        id: scanTimer
        interval: 2000
        onTriggered: root.scanning = false
    }

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "devices"

            MetroSectionHeader { text: "bluetooth" }
            MetroToggle {
                width: parent.width
                label: "bluetooth"
                onText: "On"; offText: "Off"
                checked: Services.bluetooth
                onToggled: (v) => Services.bluetooth = v
            }
            MetroSectionHeader { text: "paired" }
            Repeater {
                model: root.paired
                delegate: MetroListRow {
                    required property var modelData
                    width: parent.width
                    glyph: modelData.glyph
                    title: modelData.name
                    subtitle: modelData.detail
                    trailing: modelData.linked && Services.bluetooth ? "connected" : ""
                }
            }
        }

        PivotPage {
            title: "nearby"

            MetroSectionHeader { text: "discovery" }
            MetroListRow {
                width: parent.width
                title: root.scanning ? "searching" : "nothing found yet"
                subtitle: Services.bluetooth ? "press scan to look for devices" : "turn bluetooth on first"
                glyph: "search"
            }
            Item { width: 1; height: 24 }
            MetroButton {
                text: root.scanning ? "scanning" : "scan"
                enabled2: Services.bluetooth && !root.scanning
                onClicked: { root.scanning = true; scanTimer.restart() }
            }
        }
    }
}
