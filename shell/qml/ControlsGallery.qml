import QtQuick
import FlowShell

// Gallery of every control, inside a 3-page Pivot. Expose as screen=controls.
Rectangle {
    id: root
    color: Theme.pageBg
    property alias pivot: pv
    Pivot {
        id: pv
        anchors.fill: parent; anchors.bottomMargin: bar.height
        caption: "tilesde controls"
        PivotPage {
            title: "inputs"
            MetroSectionHeader { text: "toggles" }
            MetroToggle { label: "Wi-Fi networking"; checked: true }
            Item { width: 1; height: 20 }
            MetroToggle { label: "Bluetooth" }
            MetroSectionHeader { text: "fields" }
            MetroTextField { width: parent.width; label: "Name"; placeholder: "type here" }
            Item { width: 1; height: 16 }
            MetroDropdown { width: parent.width; label: "Sound profile"; model: ["Normal", "Silent", "Vibrate", "Meeting"] }
            Item { width: 1; height: 16 }
            MetroButton { text: "save" }
            Item { width: 1; height: 12 }
            MetroButton { text: "apply"; accentFill: true }
        }
        PivotPage {
            title: "lists"
            MetroSectionHeader { text: "system" }
            MetroListRow { title: "personalisation"; subtitle: "start, theme, colours"; glyph: "settings" }
            MetroListRow { title: "notifications"; subtitle: "banners and sounds"; glyph: "message" }
            MetroListRow { title: "storage"; subtitle: "24.1 GB of 64 GB used"; glyph: "files"; usage: 0.38 }
            MetroListRow { title: "battery"; subtitle: "82% left"; usage: 0.82 }
            MetroSectionHeader { text: "sliders" }
            MetroSlider { width: parent.width; label: "Tile opacity"; from: 0.2; to: 1; value: 0.9; decimals: 2 }
            MetroSlider { width: parent.width; label: "Tile gap"; from: 0; to: 12; stepSize: 1; value: 6; suffix: " px" }
        }
        PivotPage {
            title: "colours"
            MetroSectionHeader { text: "accent" }
            MetroColorGrid { width: parent.width }
        }
    }
    AppBar {
        id: bar
        anchors.bottom: parent.bottom
        items: [{glyph: "plus", label: "add"}, {glyph: "search", label: "search"}, {glyph: "settings", label: "settings"}]
        menuItems: ["select all", "clear"]
    }
}
