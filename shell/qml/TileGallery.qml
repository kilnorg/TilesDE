import QtQuick
import FlowShell

// Test page: every glyph, every tile size, live flips. Reach with: screen=gallery (when Main.qml hosts it) or temporary overlay.
Rectangle {
    id: root
    color: Theme.pageBg
    property bool showGlyphs: false
    Flickable {
        anchors.fill: parent; anchors.topMargin: 36
        contentWidth: width; contentHeight: col.height + 40
        Column {
            id: col
            x: Theme.pageMargin; width: parent.width - 2 * Theme.pageMargin; spacing: Theme.gap
            Text { text: "start"; color: Theme.text; font.family: Theme.font; font.pixelSize: 40; font.weight: Font.Light; bottomPadding: 6 }
            Flow {
                width: parent.width; spacing: Theme.gap
                MetroTile { size: "small"; glyph: "phone"; index: 0; screenW: root.width }
                MetroTile { size: "small"; glyph: "message"; index: 1; screenW: root.width }
                MetroTile { size: "small"; glyph: "mail"; index: 2; screenW: root.width }
                MetroTile { size: "small"; glyph: "calendar"; index: 3; screenW: root.width }
                MetroTile {
                    size: "wide"; glyph: "calendar"; label: "calendar"; live: true; index: 1; screenW: root.width
                    Column { anchors { left: parent.left; bottom: parent.bottom; margins: 10 } spacing: 2
                        Text { text: "Standup 10:30"; color: Theme.tileText; font.family: Theme.font; font.pixelSize: 15 }
                        Text { text: "Thursday 14"; color: Theme.tileText; font.family: Theme.font; font.pixelSize: 28; font.weight: Font.Light } }
                }
                MetroTile { size: "medium"; glyph: "people"; label: "people"; screenW: root.width; accent: Theme.accents[4] }
                MetroTile {
                    size: "medium"; glyph: "weather"; label: "weather"; live: true; index: 2; screenW: root.width
                    Text { anchors { left: parent.left; bottom: parent.bottom; margins: 10 } text: "18°"; color: Theme.tileText; font.family: Theme.font; font.pixelSize: 48; font.weight: Font.Light }
                }
                MetroTile { size: "small"; glyph: "photos"; screenW: root.width }
                MetroTile { size: "small"; glyph: "music"; screenW: root.width }
                MetroTile { size: "small"; glyph: "maps"; screenW: root.width }
                MetroTile { size: "small"; glyph: "notes"; screenW: root.width }
                MetroTile { size: "wide"; glyph: "store"; label: "store"; screenW: root.width; live: true; index: 4
                    Text { anchors { left: parent.left; bottom: parent.bottom; margins: 10 } text: "3 updates"; color: Theme.tileText; font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Light } }
            }
            Text { text: "glyphs"; color: Theme.text; font.family: Theme.font; font.pixelSize: 28; font.weight: Font.Light; topPadding: 10; bottomPadding: 4 }
            Flow {
                width: parent.width; spacing: Theme.gap
                Repeater {
                    model: ["phone","message","mail","calendar","clock","photos","music","maps","notes","files","weather","terminal","store","camera","settings","people","browser","wallet","noxal","video","search","star","back","plus","close","grid"]
                    Rectangle { width: Theme.tileUnit(root.width); height: width; color: Theme.accent
                        TileGlyph { anchors.centerIn: parent; size: parent.width * 0.6; name: modelData } }
                }
            }
            MetroTile { size: "large"; glyph: "settings"; label: "settings"; screenW: root.width; accent: Theme.accents[6] }
        }
    }
}
