import QtQuick
import FlowShell

// Settings > display. Pivot: "display" (screen) and "motion" (animation and glass).
// Writes to Services (screen brightness, rotation lock, glass, reduce flags) and Personalise (motion, flip).
Item {
    id: root
    property string title: "display"

    readonly property var glassModel: ["full", "blur", "flat"]
    readonly property var motionModel: ["off", "low", "normal", "high"]
    readonly property var flipModel: ["off", "normal", "fast"]

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "display"

            MetroSectionHeader { text: "screen" }
            MetroSlider {
                width: parent.width
                label: "brightness"
                from: 0; to: 100; decimals: 0; suffix: "%"
                value: Services.brightness * 100
                onMoved: (v) => Services.brightness = v / 100
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "auto rotation"
                onText: "On"; offText: "Off"
                checked: !Services.rotationLock
                onToggled: (v) => Services.rotationLock = !v
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "reduce transparency"
                onText: "On"; offText: "Off"
                checked: Services.reduceTransparency
                onToggled: (v) => Services.reduceTransparency = v
            }
            Item { width: 1; height: 24 }
            MetroDropdown {
                width: parent.width
                label: "glass"
                model: root.glassModel
                currentIndex: Math.max(0, root.glassModel.indexOf(Services.glassQuality))
                onActivated: (i) => Services.glassQuality = root.glassModel[i]
            }
        }

        PivotPage {
            title: "motion"

            MetroSectionHeader { text: "animation" }
            MetroDropdown {
                width: parent.width
                label: "motion intensity"
                model: root.motionModel
                currentIndex: Math.max(0, root.motionModel.indexOf(Personalise.motion))
                onActivated: (i) => Personalise.motion = root.motionModel[i]
            }
            Item { width: 1; height: 24 }
            MetroDropdown {
                width: parent.width
                label: "live tile flip"
                model: root.flipModel
                currentIndex: Math.max(0, Math.min(2, Personalise.flipSpeed))
                onActivated: (i) => Personalise.flipSpeed = i
            }
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "system reduce motion"
                onText: "On"; offText: "Off"
                checked: Services.reduceMotion
                onToggled: (v) => Services.reduceMotion = v
            }
            Item { width: 1; height: 24 }
            MetroListRow {
                width: parent.width
                title: "effective motion"
                subtitle: Theme.reduceMotion ? "reduced: animation is off" : "scale " + Theme.motionScale.toFixed(1)
            }
        }
    }
}
