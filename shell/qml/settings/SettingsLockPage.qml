import QtQuick
import FlowShell

// "lock screen" settings page (clone of the reference). Choices are kept in this page's state only
// (Personalise has no lock-screen keys); `quick`, `detailed`, `timeout`, `showArtist` are readable for wiring.
Pivot {
    id: root
    caption: "settings"
    titleSize: 80
    property bool showArtist: false
    property int detailed: 0
    property int timeout: 2
    property var quick: ["phone", "message", "mail", "calendar", "clock"]
    property var quickOn: [true, true, false, true, false]
    readonly property var apps: ["Calendar", "Mail", "Messages", "Phone", "Clock"]
    readonly property var timeouts: ["15 seconds", "30 seconds", "1 minute", "2 minutes", "5 minutes", "never"]

    PivotPage {
        title: "lock screen"
        Item { width: 1; height: 24 }
        MetroToggle { width: parent.width; label: "Show artist when playing music"
            checked: root.showArtist; onToggled: (v) => root.showArtist = v }
        Item { width: 1; height: 24 }
        MetroSectionHeader { text: "notifications" }
        MetroDropdown { width: parent.width; label: "Choose an app to show detailed status"
            model: root.apps; currentIndex: root.detailed; onActivated: (i) => root.detailed = i }
        Item { width: 1; height: 24 }
        Text { text: "Choose apps to show quick status"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21
            width: parent.width; elide: Text.ElideRight }
        Item { width: 1; height: 8 }
        Row {
            spacing: (parent.width - 5 * 74) / 4
            Repeater {
                model: root.quick
                Item {
                    required property int index
                    required property string modelData
                    width: 74; height: 74
                    opacity: qa.pressed ? 0.6 : 1
                    Rectangle { anchors.fill: parent; border.width: 2; border.color: Theme.text
                        color: root.quickOn[index] ? Theme.text : "transparent" }
                    TileGlyph { anchors.centerIn: parent; name: modelData; size: 36; stroke: 2
                        color: root.quickOn[index] ? Theme.pageBg : Theme.text }
                    MouseArea { id: qa; anchors.fill: parent
                        onClicked: { var q = root.quickOn.slice(); q[index] = !q[index]; root.quickOn = q } }
                }
            }
        }
        Item { width: 1; height: 40 }
        MetroDropdown { width: parent.width; label: "Screen times out after"
            model: root.timeouts; currentIndex: root.timeout; onActivated: (i) => root.timeout = i }
        Item { width: 1; height: 40 }
    }
}
