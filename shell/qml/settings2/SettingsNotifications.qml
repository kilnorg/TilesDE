import QtQuick
import FlowShell

// Settings > notifications+actions. Pivot: "notifications" (per-app list, like the Action Centre list)
// and "actions" (quick toggles for the Action Centre tiles). Reads Services.notifications (roles app, title, body, time).
Item {
    id: root
    property string title: "notifications+actions"

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "notifications"

            MetroSectionHeader { text: "recent" }
            Item {
                width: parent.width
                height: 40
                visible: notifRep.count === 0
                Text {
                    text: "no notifications"; color: Theme.textDim
                    font.family: Theme.font; font.pixelSize: 21
                }
            }
            // roles from NotifModel: app, title, body, time (read through the `model` context object)
            Repeater {
                id: notifRep
                model: Services.notifications
                delegate: MetroListRow {
                    width: parent.width
                    glyph: model.app.toLowerCase().indexOf("message") >= 0 ? "message"
                         : model.app.toLowerCase().indexOf("calendar") >= 0 ? "calendar"
                         : model.app.toLowerCase().indexOf("mail") >= 0 ? "mail"
                         : "star"
                    title: model.app
                    subtitle: model.title + (model.body ? ": " + model.body : "")
                    trailing: model.time
                    onPressAndHold: Services.notifications.dismiss(model.index)
                }
            }
            Item { width: 1; height: 24 }
            MetroButton {
                text: "clear all"
                enabled2: notifRep.count > 0
                onClicked: Services.notifications.clear()
            }
            Item { width: 1; height: 12 }
            Text {
                width: parent.width
                text: "press and hold a notification to remove it"
                color: Theme.textDim; wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 18
            }
        }

        PivotPage {
            title: "actions"

            MetroSectionHeader { text: "quick actions" }
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
            Item { width: 1; height: 24 }
            MetroToggle {
                width: parent.width
                label: "rotation lock"
                onText: "On"; offText: "Off"
                checked: Services.rotationLock
                onToggled: (v) => Services.rotationLock = v
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
