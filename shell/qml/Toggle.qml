import QtQuick
import FlowShell

// Flat quick-action square. Accent fill when active, dark grey when off. Glyph names drawn here:
// wifi bluetooth rotate moon plane sun sound motion. Unknown name draws a small square.
Item {
    id: root
    property string label: ""
    property string glyph: ""
    property bool active: false
    signal toggled

    Rectangle {
        anchors.fill: parent
        color: root.active ? Theme.accent : (Theme.dark ? "#2b2b2b" : "#cfcfcf")
        Behavior on color { enabled: !Theme.reduceMotion; ColorAnimation { duration: 120 } }
    }

    component Glyph: Canvas {
        id: g
        property string name: ""
        property color ink: "white"
        antialiasing: true
        onNameChanged: requestPaint()
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const s = width / 48
            c.scale(s, s)
            c.strokeStyle = g.ink; c.fillStyle = g.ink
            c.lineWidth = 3
            c.lineCap = "butt"; c.lineJoin = "miter"
            c.beginPath()
            switch (g.name) {
            case "wifi":
                for (let i = 1; i <= 3; i++) c.arc(24, 38, i * 9, -Math.PI * 0.75, -Math.PI * 0.25)
                c.stroke()
                c.beginPath(); c.rect(21.5, 35.5, 5, 5); c.fill()
                break
            case "bluetooth":
                c.moveTo(14, 16); c.lineTo(32, 32); c.lineTo(24, 40); c.lineTo(24, 8); c.lineTo(32, 16); c.lineTo(14, 32)
                c.stroke(); break
            case "rotate":
                c.arc(24, 24, 13, Math.PI * 0.2, Math.PI * 1.75); c.stroke()
                c.beginPath(); c.moveTo(30, 6); c.lineTo(38, 12); c.lineTo(30, 18); c.closePath(); c.fill()
                break
            case "moon":
                c.arc(24, 24, 15, Math.PI * 0.35, Math.PI * 1.65, false)
                c.arc(31, 24, 12, Math.PI * 1.45, Math.PI * 0.55, true)
                c.closePath(); c.stroke(); break
            case "plane":
                c.moveTo(24, 5); c.lineTo(28, 18); c.lineTo(43, 27); c.lineTo(43, 31); c.lineTo(28, 27)
                c.lineTo(27, 38); c.lineTo(32, 42); c.lineTo(16, 42); c.lineTo(21, 38); c.lineTo(20, 27)
                c.lineTo(5, 31); c.lineTo(5, 27); c.lineTo(20, 18); c.closePath(); c.stroke(); break
            case "sun":
                c.rect(17, 17, 14, 14); c.stroke()
                c.beginPath()
                for (let k = 0; k < 8; k++) {
                    const a = k * Math.PI / 4
                    c.moveTo(24 + Math.cos(a) * 14, 24 + Math.sin(a) * 14)
                    c.lineTo(24 + Math.cos(a) * 20, 24 + Math.sin(a) * 20)
                }
                c.stroke(); break
            case "sound":
                c.moveTo(6, 18); c.lineTo(14, 18); c.lineTo(24, 9); c.lineTo(24, 39); c.lineTo(14, 30); c.lineTo(6, 30); c.closePath(); c.stroke()
                c.beginPath(); c.arc(24, 24, 10, -Math.PI * 0.35, Math.PI * 0.35); c.stroke()
                c.beginPath(); c.arc(24, 24, 18, -Math.PI * 0.35, Math.PI * 0.35); c.stroke()
                break
            case "motion":
                c.moveTo(5, 24); c.lineTo(14, 24); c.lineTo(19, 10); c.lineTo(27, 38); c.lineTo(32, 24); c.lineTo(43, 24); c.stroke(); break
            default:
                c.rect(14, 14, 20, 20); c.stroke()
            }
        }
    }

    Glyph {
        width: 38; height: 38
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -10 }
        name: root.glyph
        ink: root.active ? Theme.tileText : Theme.text
    }
    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 6; bottomMargin: 6 }
        text: root.label.toLowerCase(); elide: Text.ElideRight
        color: root.active ? Theme.tileText : Theme.text
        font.pixelSize: 12; font.family: Theme.font; font.weight: Theme.fontLight
    }
    scale: ma.pressed ? 0.95 : 1
    Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.pressMs } }
    MouseArea { id: ma; anchors.fill: parent; onClicked: root.toggled() }
}
