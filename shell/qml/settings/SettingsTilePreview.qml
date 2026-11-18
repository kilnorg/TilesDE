import QtQuick
import FlowShell
import "../TilePresets.js" as TilePresets

// Live phone-outline preview of the start layout. Reads Personalise/Theme (columns, gap, radius, opacity,
// tile colours, badges). Cropped at the bottom like the reference. Props: tiles (default previewTiles()), phoneH.
Item {
    id: root
    property var tiles: TilePresets.previewTiles()
    property real phoneH: 400
    readonly property int cols: Math.max(3, Math.min(4, Theme.tileCols))
    readonly property real pad: 14
    property real phoneW: Math.min(width, 340)
    readonly property real scaleF: (phoneW - 2 * pad) / 516
    readonly property real gapPx: Math.max(2, Theme.tileGap * scaleF * 1.4)
    readonly property real unit: (phoneW - 2 * pad - (cols - 1) * gapPx) / cols
    implicitWidth: 360; implicitHeight: phoneH
    height: phoneH
    clip: true

    function pack(list, c) {
        var occ = [], out = [], r, cc
        function free(x, y, w, h) {
            if (x + w > c) return false
            for (var j = y; j < y + h; j++) for (var i = x; i < x + w; i++) if (occ[j] && occ[j][i]) return false
            return true
        }
        function take(x, y, w, h) {
            for (var j = y; j < y + h; j++) { occ[j] = occ[j] || []; for (var i = x; i < x + w; i++) occ[j][i] = 1 }
        }
        for (var n = 0; n < list.length; n++) {
            var t = list[n], w = 1, h = 1
            if (t.size === "medium") { w = 2; h = 2 } else if (t.size === "wide") { w = c; h = 2 }
            var placed = false
            for (r = 0; r < 40 && !placed; r++) for (cc = 0; cc < c && !placed; cc++)
                if (free(cc, r, w, h)) { take(cc, r, w, h); out.push({ t: t, x: cc, y: r, w: w, h: h }); placed = true }
        }
        return out
    }
    readonly property var placed: pack(tiles, cols)

    Rectangle {
        id: body
        x: (root.width - root.phoneW) / 2; y: 0; width: root.phoneW; height: root.phoneH + 40; radius: 26
        color: "transparent"; border.width: 3; border.color: Theme.dark ? "#d8d8d8" : "#303030"
    }
    Rectangle { x: root.width / 2 - 28; y: 8; width: 56; height: 6; radius: 3; color: body.border.color }
    Item {
        x: body.x + root.pad; y: 30; width: root.phoneW - 2 * root.pad; height: parent.height - 30
        clip: true
        Repeater {
            model: root.placed
            Rectangle {
                required property var modelData
                readonly property var tl: modelData.t
                x: modelData.x * (root.unit + root.gapPx); y: modelData.y * (root.unit + root.gapPx)
                width: modelData.w * root.unit + (modelData.w - 1) * root.gapPx
                height: modelData.h * root.unit + (modelData.h - 1) * root.gapPx
                radius: Theme.tileRadius * root.scaleF * 1.4
                color: Theme.tileColor(tl.id, tl.color)
                opacity: Theme.tileOpacity
                Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !Theme.reduceMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: !Theme.reduceMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                TileGlyph {
                    anchors.centerIn: parent
                    visible: parent.width > 40
                    name: parent.tl.glyph; size: Math.min(34, Math.min(parent.width, parent.height) * 0.5); stroke: 1.5
                    color: Theme.onColor(parent.color)
                }
                Rectangle {
                    visible: Theme.showBadges && parent.tl.badge > 0
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3
                    width: 14; height: 14; radius: 7; color: Theme.onColor(parent.color) === "#ffffff" ? "#000000" : "#ffffff"
                    opacity: 0.85
                }
            }
        }
    }
}
