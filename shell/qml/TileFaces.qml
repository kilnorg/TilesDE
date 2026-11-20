import QtQuick
import FlowShell

// Live-tile faces (back side of a flip, or the picture layer of a photo tile). One type, `face` picks the layout:
//   "text"     big number + two lines (Mail, Store)            "calendar" big day number, weekday, next event
//   "photo"    picture + caption                               "contact"  picture + avatar disc + name + message
//   "missed"   phone glyph + count + "missed call" text        "weather"  temperature, condition, high/low, sun glyph
//   "music"    album art + equaliser + track / artist          "scene"    only the generated picture (no text)
// Picture source: imageSource / Theme.startPhoto (real file path or url). Only the "scene" face (page wallpaper) falls back to a
// generated gradient; photo and contact faces show no picture when there is none. `seed` varies the pattern. Respects Theme.reduceMotion (music bars).
Item {
    id: root
    property string face: "text"
    property string size: "medium"          // small | medium | wide | large (scales type)
    property string big: ""
    property string line1: ""
    property string line2: ""
    property color ink: "#ffffff"
    property int seed: 0
    property string imageSource: ""        // LiveTiles picture (file path or url); wins over Theme.startPhoto
    property bool animate: true

    readonly property bool compact: size === "small"
    readonly property bool hasPicture: face === "photo" || face === "contact" || face === "scene"
    readonly property real unit: Math.min(width, height)
    readonly property string photoUrl: {
        const p = root.imageSource !== "" ? root.imageSource : Theme.startPhoto
        if (!p || p === "") return ""
        return (p.indexOf("://") >= 0 || p.indexOf("qrc:") === 0) ? p : "file://" + p
    }
    function hash(s) { let h = 7; s = String(s); for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return Math.abs(h) }

    Loader { anchors.fill: parent; sourceComponent: root.hasPicture ? sceneComp : null }
    // dark scrim under captions for contrast over pictures
    Rectangle {
        visible: root.face === "photo" || root.face === "contact"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * 0.6
        gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#b0000000" } }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.face) {
            case "calendar": return calComp
            case "photo": return photoComp
            case "contact": return contactComp
            case "missed": return missedComp
            case "weather": return weatherComp
            case "music": return musicComp
            case "scene": return null
            default: return textComp
            }
        }
    }

    // ---- shared text styles ----
    component Big: Text {
        color: root.ink; font.family: Theme.font; font.weight: Theme.fontLight
    }
    component Line: Text {
        color: root.ink; font.family: Theme.font; elide: Text.ElideRight
    }

    Component {
        id: sceneComp
        Item {
            Rectangle {
                id: base
                anchors.fill: parent
                radius: Theme.tileRadius
                visible: root.face === "scene" && img.status !== Image.Ready   // generated gradient only as the wallpaper; photo/contact faces never fake a picture
                readonly property var pal: Theme.tilePalette
                readonly property color c0: pal[(root.seed) % pal.length]
                readonly property color c1: pal[(root.seed + 1) % pal.length]
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: Qt.lighter(base.c1, 1.25) }
                    GradientStop { position: 0.6; color: base.c0 }
                    GradientStop { position: 1; color: Qt.darker(base.c0, 2.2) }
                }
                // sun: three concentric discs, kept inside the tile so rounded corners stay clean
                Rectangle {
                    readonly property real d: root.unit * 0.42
                    width: d; height: d; radius: d / 2
                    x: parent.width * (0.18 + 0.5 * ((root.seed % 5) / 4)); y: parent.height * 0.14
                    color: Qt.rgba(1, 1, 1, 0.20)
                    Rectangle { anchors.centerIn: parent; width: parent.width * 0.66; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.28)
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.55; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.55) } }
                }
                // hills only on square-cornered tiles
                Rectangle {
                    visible: Theme.tileRadius < 1
                    width: parent.width * 1.2; height: parent.height * 0.5; radius: height / 2
                    x: -parent.width * 0.1 - (root.seed % 3) * parent.width * 0.06; y: parent.height * 0.78
                    color: Qt.rgba(0, 0, 0, 0.30)
                }
                Rectangle {
                    visible: Theme.tileRadius < 1
                    width: parent.width * 0.9; height: parent.height * 0.4; radius: height / 2
                    x: parent.width * 0.35; y: parent.height * 0.86
                    color: Qt.rgba(0, 0, 0, 0.22)
                }
            }
            Image {
                id: img
                anchors.fill: parent
                source: root.photoUrl
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 600; sourceSize.height: 600
                visible: status === Image.Ready
            }
        }
    }

    Component {
        id: textComp
        Item {
            Big {
                visible: root.big !== ""
                anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: root.size === "large" ? 12 : 2 }
                text: root.big
                font.pixelSize: root.size === "large" ? 120 : (root.compact ? 40 : Math.round(root.unit * 0.42))
            }
            Column {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                spacing: 1
                Line { width: parent.width; text: root.line1; font.pixelSize: 17; font.weight: Font.Normal; visible: text !== "" }
                Line { width: parent.width; text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light; visible: text !== "" }
            }
        }
    }

    Component {
        id: calComp
        Item {
            Big {
                anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 0 }
                text: root.big
                font.pixelSize: root.size === "large" ? 150 : (root.compact ? 44 : Math.round(root.unit * 0.5))
            }
            Line {
                visible: !root.compact
                anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; bottom: ev.top; bottomMargin: 2 }
                text: Theme.title(root.line1); font.pixelSize: 18; font.weight: Font.Normal
            }
            Line {
                id: ev
                visible: !root.compact
                anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; bottom: parent.bottom; bottomMargin: 8 }
                text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light
            }
        }
    }

    Component {
        id: photoComp
        Item {
            Column {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                spacing: 1
                Line { width: parent.width; text: root.line1; font.pixelSize: 17; font.weight: Font.Normal; visible: text !== "" }
                Line { width: parent.width; text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light; visible: text !== "" }
            }
        }
    }

    Component {
        id: contactComp
        Item {
            Rectangle {
                id: av
                readonly property real d: Math.round(root.unit * (root.compact ? 0.5 : 0.36))
                width: d; height: d; radius: d / 2
                anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 10 }
                color: Qt.rgba(1, 1, 1, 0.9)
                Text { anchors.centerIn: parent; text: root.line1.charAt(0).toUpperCase(); color: "#22211f"; font.family: Theme.font; font.pixelSize: av.d * 0.55; font.weight: Font.Normal }
            }
            Column {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                spacing: 1
                Line { width: parent.width; text: root.line1; font.pixelSize: 18; font.weight: Font.Normal }
                Line { width: parent.width; text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light }
            }
        }
    }

    Component {
        id: missedComp
        Item {
            TileGlyph { id: ph; name: "phone"; color: root.ink; size: Math.round(root.unit * 0.26); stroke: 2.6; anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 10 } }
            Big {
                anchors { right: parent.right; top: parent.top; rightMargin: 10; topMargin: 0 }
                text: root.big; font.pixelSize: Math.round(root.unit * 0.42)
            }
            Column {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                spacing: 1
                Line { width: parent.width; text: root.line1; font.pixelSize: 17; font.weight: Font.Normal }
                Line { width: parent.width; text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light }
            }
        }
    }

    Component {
        id: weatherComp
        Item {
            Big { anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 0 }
                text: root.big; font.pixelSize: root.size === "wide" || root.size === "large" ? Math.round(root.unit * 0.5) : Math.round(root.unit * 0.4) }
            TileGlyph {
                visible: !root.compact
                name: "weather"; color: root.ink; stroke: 3
                size: Math.round(root.unit * 0.42)
                anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 12 }
            }
            Column {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                spacing: 1
                Line { width: parent.width; text: root.line1; font.pixelSize: 17; font.weight: Font.Normal }
                Line { width: parent.width; text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light }
            }
        }
    }

    Component {
        id: musicComp
        Item {
            id: m
            // album art square (generated) + three equaliser bars
            Rectangle {
                id: art
                readonly property real d: Math.round(root.unit * 0.5)
                width: d; height: d
                radius: Math.min(Theme.tileRadius, 6)
                anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 10 }
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                }
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.35)
                    Rectangle { anchors.centerIn: parent; width: parent.width * 0.25; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.7) } }
            }
            Row {
                anchors { left: art.right; leftMargin: 12; bottom: art.bottom }
                spacing: 4
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 5; height: 8 + index * 4; color: root.ink; anchors.bottom: parent.bottom
                        SequentialAnimation on height {
                            running: root.animate && !Theme.reduceMotion && m.visible && !Theme.animPause
                            loops: Animation.Infinite
                            NumberAnimation { to: 24 - index * 4; duration: 380 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 6 + index * 2; duration: 380 + index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Column {
                anchors { left: parent.left; bottom: parent.bottom; right: parent.right; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                spacing: 1
                Line { width: parent.width; text: root.line1; font.pixelSize: 17; font.weight: Font.Normal }
                Line { width: parent.width; text: root.line2; opacity: 0.85; font.pixelSize: 14; font.weight: Font.Light }
            }
        }
    }
}
