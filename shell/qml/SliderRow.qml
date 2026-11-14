import QtQuick
import FlowShell

// Flat slider: thin line, accent fill, square thumb. value 0..1, moved(v) while dragging.
Item {
    id: root
    property real value: 0.5
    property string glyph: ""      // "sun" or "sound"; empty hides the glyph
    signal moved(real v)
    implicitHeight: 52
    readonly property real _x0: glyphBox.visible ? 44 : 0
    readonly property real _len: Math.max(1, width - _x0 - 8)

    Item {
        id: glyphBox
        visible: root.glyph !== ""
        width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
        Canvas {
            anchors.fill: parent
            property color ink: Theme.text
            onInkChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset(); c.scale(width / 48, width / 48)
                c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 3.5
                if (root.glyph === "sound") {
                    c.beginPath(); c.moveTo(6, 18); c.lineTo(14, 18); c.lineTo(24, 9); c.lineTo(24, 39); c.lineTo(14, 30); c.lineTo(6, 30); c.closePath(); c.stroke()
                    c.beginPath(); c.arc(24, 24, 12, -Math.PI * 0.35, Math.PI * 0.35); c.stroke()
                } else {
                    c.beginPath(); c.rect(16, 16, 16, 16); c.stroke(); c.beginPath()
                    for (let k = 0; k < 8; k++) { const a = k * Math.PI / 4
                        c.moveTo(24 + Math.cos(a) * 15, 24 + Math.sin(a) * 15); c.lineTo(24 + Math.cos(a) * 21, 24 + Math.sin(a) * 21) }
                    c.stroke()
                }
            }
        }
    }
    Rectangle { x: root._x0; width: root._len; height: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.dark ? "#4a4a4a" : "#b5b5b5" }
    Rectangle { x: root._x0; width: root._len * root.value; height: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
    Rectangle {
        width: 12; height: 28; anchors.verticalCenter: parent.verticalCenter
        x: root._x0 + (root._len - width) * root.value
        color: ma.pressed ? Theme.accent : Theme.text
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        function setFrom(mx) { root.moved(Math.max(0, Math.min(1, (mx - root._x0 - 6) / Math.max(1, root._len - 12)))) }
        onPressed: (m) => setFrom(m.x)
        onPositionChanged: (m) => setFrom(m.x)
    }
}
