import QtQuick
import FlowShell

// Settings > sound. Single page "sound". Volume from Services; ringtone, vibrate are local options (not persisted).
Item {
    id: root
    property string title: "sound"

    readonly property var ringtones: ["default", "pulse", "chime", "none"]
    property int ringtoneIndex: 0
    property bool vibrate: true

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "sound"

            MetroSectionHeader { text: "volume" }
            MetroSlider {
                width: parent.width
                label: "master"
                from: 0; to: 100; decimals: 0; suffix: "%"
                value: Services.volume * 100
                onMoved: (v) => Services.volume = v / 100
            }
            MetroSectionHeader { text: "alerts" }
            MetroDropdown {
                width: parent.width
                label: "ringtone"
                model: root.ringtones
                currentIndex: root.ringtoneIndex
                onActivated: (i) => root.ringtoneIndex = i
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "vibrate"
                onText: "On"; offText: "Off"
                checked: root.vibrate
                onToggled: (v) => root.vibrate = v
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "quiet (do not disturb)"
                onText: "On"; offText: "Off"
                checked: Services.dnd
                onToggled: (v) => Services.dnd = v
            }
        }
    }
}
