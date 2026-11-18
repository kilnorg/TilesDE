import QtQuick
import FlowShell

// Flat slider: 4px track, accent fill, square thumb. Caption + value above.
// Props: label, value, from, to, stepSize, suffix, decimals. Signals moved(real) while dragging.
Item {
    id: root
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true
    signal moved(real value)
    implicitWidth: 360; implicitHeight: 28 + 48
    Text {
        text: root.label; color: Theme.textDim; width: parent.width - 100; elide: Text.ElideRight
        font.family: Theme.font; font.pixelSize: 21
    }
    Text {
        visible: root.showValue; anchors.right: parent.right
        text: root.value.toFixed(root.decimals) + root.suffix; color: Theme.text
        font.family: Theme.font; font.pixelSize: 21
    }
    Item {
        id: bar
        y: 28; width: parent.width; height: 48
        readonly property real frac: root.to > root.from ? (root.value - root.from) / (root.to - root.from) : 0
        readonly property real usable: width - thumb.width
        Rectangle { y: 22; width: parent.width; height: 4; color: Theme.dark ? "#3a3a3a" : "#c8c8c8" }
        Rectangle { y: 22; width: thumb.x + thumb.width / 2; height: 4; color: Theme.accent }
        Rectangle {
            id: thumb
            width: 16; height: 36; y: 6
            x: bar.frac * bar.usable
            color: area.pressed ? Theme.accent : Theme.text
        }
        MouseArea {
            id: area
            anchors.fill: parent
            function setFrom(mx) {
                var f = Math.max(0, Math.min(1, (mx - thumb.width / 2) / bar.usable))
                var v = root.from + f * (root.to - root.from)
                if (root.stepSize > 0) v = root.from + Math.round((v - root.from) / root.stepSize) * root.stepSize
                v = Math.max(root.from, Math.min(root.to, v))
                if (v !== root.value) { root.value = v; root.moved(v) }
            }
            onPressed: (m) => setFrom(m.x)
            onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
        }
    }
}
