import QtQuick
import FlowShell
import "../TilePresets.js" as TilePresets

// Per-app (tile) settings: tile colour override. Set `appId` (tile id) before use. Writes Personalise.tileColors.
Pivot {
    id: root
    property string appId: ""
    readonly property var tile: TilePresets.find(appId)
    readonly property bool hasOverride: Theme.hasTileColor(appId)
    caption: "settings"
    titleSize: 80

    PivotPage {
        title: root.tile ? root.tile.label : "app"
        MetroSectionHeader { text: "tile colour"; height: 28 * 1.3 + 8 }
        Item { width: parent.width; height: 140
            Rectangle { id: sw; width: 130; height: 130; color: root.tile ? Theme.tileColor(root.appId, root.tile.color) : Theme.accent
                TileGlyph { anchors.centerIn: parent; name: root.tile ? root.tile.glyph : ""; size: 56; stroke: 2.5; color: Theme.onColor(sw.color) } }
            Text { x: 154; y: 8; width: parent.width - x; wrapMode: Text.WordWrap; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 21
                text: root.hasOverride ? "Custom colour for this tile." : "Follows the preset palette." }
        }
        Item { width: 1; height: 12 }
        MetroColorGrid { width: parent.width; columns: 6; value: sw.color; colors: Personalise.accentColours
            onPicked: (c) => Personalise.setTileColor(root.appId, String(c)) }
        Item { width: 1; height: 20 }
        MetroButton { text: "use preset colour"; enabled2: root.hasOverride; onClicked: Personalise.setTileColor(root.appId, "") }
        Item { width: 1; height: 40 }
    }
}
