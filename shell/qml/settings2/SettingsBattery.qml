import QtQuick
import FlowShell

// Settings > battery saver. Pivot: "usage" (per-app bars, tiny accent) and "settings" (saver options).
// Battery level and charging come from Services. Per-app usage is MOCK data (no usage source exists yet).
Item {
    id: root
    property string title: "battery saver"

    // MOCK per-app usage, share of the recent drain (0..1). Replace with a Services usage model when one exists.
    readonly property var usageRows: [
        { name: "messages", glyph: "message", usage: 0.32, state: "allowed" },
        { name: "browser", glyph: "browser", usage: 0.21, state: "allowed" },
        { name: "maps", glyph: "maps", usage: 0.14, state: "limited" },
        { name: "music", glyph: "music", usage: 0.09, state: "allowed" },
        { name: "store", glyph: "store", usage: 0.05, state: "allowed" },
        { name: "mail", glyph: "mail", usage: 0.03, state: "limited" }
    ]

    // local options, not persisted (no battery backend yet)
    property bool saverOn: false
    property int saverAt: 20
    property bool allowBackground: true

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "usage"

            MetroListRow {
                width: parent.width
                title: Services.battery + "%"
                subtitle: Services.charging ? "charging" : "on battery"
                glyph: "clock"
            }
            MetroSectionHeader { text: "recent battery usage" }
            Repeater {
                model: root.usageRows
                delegate: MetroListRow {
                    required property var modelData
                    width: parent.width
                    glyph: modelData.glyph
                    title: modelData.name
                    subtitle: modelData.state
                    usage: modelData.usage
                    usageColor: Theme.accent
                }
            }
        }

        PivotPage {
            title: "settings"

            MetroSectionHeader { text: "saver" }
            MetroToggle {
                width: parent.width
                label: "battery saver"
                onText: "On"; offText: "Off"
                checked: root.saverOn
                onToggled: (v) => root.saverOn = v
            }
            Item { width: 1; height: 24 }
            MetroSlider {
                width: parent.width
                label: "turn on at"
                from: 5; to: 50; stepSize: 5; decimals: 0; suffix: "%"
                value: root.saverAt
                onMoved: (v) => root.saverAt = v
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "allow background apps"
                onText: "On"; offText: "Off"
                checked: root.allowBackground
                onToggled: (v) => root.allowBackground = v
            }
            Item { width: 1; height: 24 }
            MetroListRow {
                width: parent.width
                title: "charge level"
                subtitle: Services.battery + "% now"
                trailing: Services.charging ? "charging" : ""
            }
        }
    }
}
