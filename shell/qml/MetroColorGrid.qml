import QtQuick
import FlowShell

// 12 accent swatches (Theme.accents) plus hex field. Props: color value, columns (6). Signal picked(color c).
Item {
    id: root
    property color value: Theme.accent
    property int columns: 6
    property real gap: 6
    property bool showHex: true
    property var colors: Theme.accents
    signal picked(color c)
    readonly property real cell: (width - gap * (columns - 1)) / columns
    implicitWidth: 360
    implicitHeight: grid.height + (showHex ? 12 + hex.implicitHeight : 0)
    function _same(a, b) { return Qt.colorEqual ? Qt.colorEqual(a, b) : String(Qt.color(a)) === String(Qt.color(b)) }
    function _pick(c) { value = c; picked(c) }
    Grid {
        id: grid
        columns: root.columns; spacing: root.gap
        Repeater {
            model: root.colors
            Rectangle {
                required property var modelData
                width: root.cell; height: root.cell
                color: modelData
                border.width: root._same(modelData, root.value) ? 3 : 0
                border.color: Theme.text
                opacity: sw.pressed ? 0.7 : 1
                MouseArea { id: sw; anchors.fill: parent; onClicked: root._pick(parent.modelData) }
            }
        }
    }
    MetroTextField {
        id: hex
        visible: root.showHex
        y: grid.height + 12; width: parent.width
        label: "Hex"
        text: String(root.value).toUpperCase()
        placeholder: "#RRGGBB"
        onAccepted: {
            var t = text.trim()
            if (/^#?[0-9a-fA-F]{6}$/.test(t)) root._pick(Qt.color(t[0] === "#" ? t : "#" + t))
            else text = String(root.value).toUpperCase()
        }
    }
    Connections { target: root; function onValueChanged() { if (!hex.text || hex.text.toLowerCase() !== String(root.value)) hex.text = String(root.value).toUpperCase() } }
}
