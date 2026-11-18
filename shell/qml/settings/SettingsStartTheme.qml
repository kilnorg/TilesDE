import QtQuick
import FlowShell

// "start+theme" personalisation page (clone of the reference layout). Every control writes straight into
// Personalise (persisted, live) and re-syncs when Personalise changes (socket, presets, reset).
Pivot {
    id: root
    caption: "settings"
    titleSize: 80

    component Gap: Item { width: 1; height: 24 }
    component Note: Text {
        width: parent ? parent.width : 360; wrapMode: Text.WordWrap; textFormat: Text.StyledText
        color: Theme.text; font.family: Theme.font; font.pixelSize: 21; lineHeight: 1.1
    }
    component PToggle: MetroToggle {
        id: t
        property string key: ""
        property bool src: false
        width: parent ? parent.width : 360
        Binding { target: t; property: "checked"; value: t.src }
        onToggled: (v) => Personalise.set(t.key, v)
    }
    component PSlider: MetroSlider {
        id: s
        property string key: ""
        property real src: 0
        width: parent ? parent.width : 360
        Binding { target: s; property: "value"; value: s.src }
        onMoved: (v) => Personalise.set(s.key, v)
    }
    component PDrop: MetroDropdown {
        id: d
        property int src: 0
        width: parent ? parent.width : 360
        Binding { target: d; property: "currentIndex"; value: d.src }
    }

    readonly property var accentModel: Personalise.accentNames.concat(["custom"])
    readonly property int accentIdx: {
        var a = Qt.color(Personalise.accent).toString(), c = Personalise.accentColours
        for (var i = 0; i < c.length; ++i) if (Qt.color(c[i]).toString() === a) return i
        return c.length
    }
    readonly property var weights: [100, 300, 400, 700]
    readonly property int weightIdx: {
        var w = Personalise.fontWeight, b = 0
        for (var i = 1; i < weights.length; ++i) if (Math.abs(weights[i] - w) < Math.abs(weights[b] - w)) b = i
        return b
    }
    readonly property var schemes: ["dark", "amoled", "light"]
    readonly property var motions: ["off", "low", "normal", "high"]
    function _photoUrl(p) { return p === "" ? "" : (p.indexOf("://") > 0 || p.indexOf("qrc:") === 0 ? p : "file://" + p) }

    PivotPage {
        title: "start+theme"
        Gap { height: 14 }
        Note { text: "Change your phone's background and <font color=\"" + Theme.accent + "\">accent colour</font> to suit your mood today, this week or all month." }
        Gap {}
        PDrop { label: "Background"; model: root.schemes; src: root.schemes.indexOf(Personalise.scheme)
            onActivated: (i) => Personalise.scheme = root.schemes[i] }
        Gap { height: 18 }
        PDrop { label: "Accent colour"; model: root.accentModel; src: root.accentIdx
            onActivated: (i) => { if (i < Personalise.accentColours.length) Personalise.accent = Personalise.accentColours[i] }
            Rectangle { x: parent.width - 62; y: 28 + 16; width: 24; height: 24; color: Theme.accent } }
        Gap { height: 14 }
        MetroColorGrid { width: parent.width; value: Theme.accent; columns: 6
            colors: Personalise.accentColours; onPicked: (c) => Personalise.accent = String(c) }
        Gap {}
        PDrop { label: "Preset"; model: Personalise.presetNames
            src: Personalise.presetNames.indexOf(Personalise.preset)
            onActivated: (i) => Personalise.applyPreset(Personalise.presetNames[i]) }
        Gap {}
        // start background: thumbnail + choose photo / remove
        Item {
            id: bgRow
            width: parent.width; height: 168
            property bool entering: false
            Rectangle { id: thumb; width: 160; height: 160; color: Theme.accent
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
                    source: root._photoUrl(Personalise.startPhoto); visible: Personalise.startPhoto !== "" } }
            Column {
                x: thumb.width + 22; width: parent.width - x; spacing: 8
                Text { text: "Start background"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21 }
                MetroButton { text: "choose photo"; onClicked: bgRow.entering = !bgRow.entering }
                Text { text: "remove"; color: Theme.text; font.family: Theme.font; font.pixelSize: 21; font.underline: true
                    opacity: Personalise.startPhoto !== "" ? 1 : 0.4
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: Personalise.startPhoto = "" } }
            }
        }
        MetroTextField { width: parent.width; visible: bgRow.entering; label: "Photo path"
            placeholder: "/path/to/photo.jpg"; text: Personalise.startPhoto
            onAccepted: { Personalise.startPhoto = text.trim(); bgRow.entering = false } }
        Gap {}
        Note { text: "You can change the size and number of Tiles available on your start screen." }
        Gap {}
        PToggle { label: "Show more Tiles"; src: Personalise.columns === 4; onToggled: (v) => Personalise.columns = v ? 4 : 3 }
        Gap {}
        SettingsTilePreview { width: parent.width }

        MetroSectionHeader { text: "tile style" }
        PSlider { label: "Tile gap"; from: 0; to: 12; stepSize: 1; suffix: " px"; key: "gap"; src: Personalise.gap }
        Gap { height: 12 }
        PSlider { label: "Corner radius"; from: 0; to: 40; stepSize: 1; suffix: " px"; key: "tileRadius"; src: Personalise.tileRadius }
        Gap { height: 12 }
        PSlider { label: "Tile opacity"; from: 0.2; to: 1; stepSize: 0.05; decimals: 2; key: "tileOpacity"; src: Personalise.tileOpacity }
        Gap { height: 12 }
        PSlider { label: "Wallpaper grain"; from: 0; to: 1; stepSize: 0.05; decimals: 2; key: "grain"; src: Personalise.grain }
        Gap { height: 12 }
        PToggle { label: "Tile labels"; key: "labels"; src: Personalise.labels }
        Gap { height: 12 }
        PToggle { label: "Badges"; key: "badges"; src: Personalise.badges }
        Gap { height: 12 }
        PToggle { label: "Tiles over wallpaper"; key: "tilesOverWallpaper"; src: Personalise.tilesOverWallpaper }
        Gap { height: 12 }
        PDrop { label: "Live tile flip speed"; model: ["off", "normal", "fast"]; src: Personalise.flipSpeed
            onActivated: (i) => Personalise.flipSpeed = i }
        Gap { height: 18 }

        MetroSectionHeader { text: "text + motion" }
        PDrop { label: "Font weight"; model: ["thin", "light", "regular", "bold"]; src: root.weightIdx
            onActivated: (i) => Personalise.fontWeight = root.weights[i] }
        Gap { height: 18 }
        PDrop { label: "Title case"; model: ["lowercase", "uppercase"]; src: Personalise.titleCase === "upper" ? 1 : 0
            onActivated: (i) => Personalise.titleCase = i === 1 ? "upper" : "lower" }
        Gap { height: 18 }
        PDrop { label: "Motion"; model: root.motions; src: root.motions.indexOf(Personalise.motion)
            onActivated: (i) => Personalise.motion = root.motions[i] }

        MetroSectionHeader { text: "start groups" }
        SettingsGroupManager {}

        MetroSectionHeader { text: "presets" }
        Row {
            spacing: 14
            MetroButton { text: "reset to preset"; onClicked: Personalise.applyPreset(Personalise.preset) }
            MetroButton { text: "reset all"; onClicked: Personalise.reset() }
        }
        Gap {}
        MetroTextField { id: presetName; width: parent.width; label: "Save current look as preset"; placeholder: "preset name" }
        Gap { height: 14 }
        Row {
            spacing: 14
            MetroButton { text: "save preset"; accentFill: true; enabled2: presetName.text.trim() !== ""
                onClicked: { if (Personalise.savePreset(presetName.text.trim())) presetName.text = "" } }
            MetroButton { text: "delete preset"; enabled2: Theme.presetInfo(Personalise.preset).custom
                onClicked: Personalise.deletePreset(Personalise.preset) }
        }
        Gap { height: 40 }
    }
}
