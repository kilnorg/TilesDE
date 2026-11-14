import QtQuick
import FlowShell

// Live tile. Size from `size` ("small" 1x1, "medium" 2x2, "wide" 4x2, "large" 4x4) on a 4-column grid of width `screenW`.
// Parents that lay tiles out themselves may override width/height.
// Front: accent fill, white line glyph centred, label bottom-left (not on small). Back (live): children go into the default slot.
// Press: tilts toward the touch point (<= tiltMax deg) and scales 0.96, springs back on release.
// Flip: rotates about X, staggered by `index`, period Theme.flipPeriodMs. Disabled by Theme.reduceMotion.
// Signals: clicked(rect r) with r in window coordinates (for the launch animation), pressAndHold().
Item {
    id: root
    property string size: "medium"
    property string label: ""
    property string glyph: ""
    property color accent: "transparent"          // transparent = use Theme.accent
    property bool live: false
    property int index: 0                          // stagger slot for the flip
    property real screenW: 540
    property real tiltMax: 8
    property bool flat: false                      // no press effect (edit mode etc.)
    property bool flipEnabled: true                // lets the host pause flips (app open, edit mode)
    readonly property color fill: accent.a > 0 ? accent : Theme.accent
    readonly property bool pressed: ma.pressed || forcePressed
    property bool forcePressed: false              // test hook
    property point touch: Qt.point(width / 2, height / 2)
    property real flipAngle: 0                     // 0 = front, 180 = back, 360 = front again
    readonly property bool showingBack: { const a = flipAngle % 360; return a >= 90 && a < 270 }
    default property alias back: backContent.data
    property alias backItem: backContent
    property alias mouse: ma

    signal clicked(rect r)
    signal pressAndHold()

    width: Theme.tileW(size, screenW)
    height: Theme.tileH(size, screenW)

    function sceneRect() { return root.mapToItem(null, 0, 0, width, height) }

    // normalised touch position in [-1, 1]
    readonly property real nx: width > 0 ? Math.max(-1, Math.min(1, (touch.x - width / 2) / (width / 2))) : 0
    readonly property real ny: height > 0 ? Math.max(-1, Math.min(1, (touch.y - height / 2) / (height / 2))) : 0
    // touched edge recedes (signs verified in VM screenshot)
    readonly property real tiltSignX: -1
    readonly property real tiltSignY: 1
    property real tiltX: (pressed && !flat && !Theme.reduceMotion) ? tiltSignX * ny * tiltMax : 0
    property real tiltY: (pressed && !flat && !Theme.reduceMotion) ? tiltSignY * nx * tiltMax : 0
    property real pressScale: (pressed && !flat) ? 0.96 : 1
    Behavior on tiltX { enabled: !Theme.reduceMotion; SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.01 } }
    Behavior on tiltY { enabled: !Theme.reduceMotion; SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.01 } }
    Behavior on pressScale { enabled: !Theme.reduceMotion; SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.001 } }

    // flip with perspective: rotation about the tile's horizontal centre axis, projected, then scaled so
    // the near edge never grows past the cell (flip stays inside its gutter)
    readonly property real _persp: 900
    readonly property var flipM: {
        const a = flipAngle * Math.PI / 180, c = Math.cos(a), s = Math.sin(a)
        const cx = width / 2, cy = height / 2, d = _persp
        const k = 1 - (height / 2) * Math.abs(s) / d
        return Qt.matrix4x4(
            k, -cx * s / d, 0, cx - k * cx + cx * s * cy / d,
            0, k * c - cy * s / d, 0, cy - k * c * cy + cy * cy * s / d,
            0, s, 1, -s * cy,
            0, -s / d, 0, 1 + s * cy / d)
    }
    // glyph size from the nominal tile size, so it does not repaint while the cell animates
    readonly property real nomW: Theme.tileW(size, screenW)
    readonly property real nomH: Theme.tileH(size, screenW)

    Item {
        id: body
        anchors.fill: parent
        scale: root.pressScale
        layer.enabled: root.flipAngle % 360 !== 0
        layer.smooth: true
        transform: [
            Rotation { origin.x: body.width / 2; origin.y: body.height / 2; axis { x: 1; y: 0; z: 0 } angle: root.tiltX },
            Rotation { origin.x: body.width / 2; origin.y: body.height / 2; axis { x: 0; y: 1; z: 0 } angle: root.tiltY },
            Matrix4x4 { matrix: root.flipM }
        ]

        // front face
        Item {
            id: front
            anchors.fill: parent
            visible: !root.showingBack
            Rectangle { anchors.fill: parent; color: root.fill; radius: Theme.tileRadius }
            TileGlyph {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.size === "small" ? 0 : -Math.round(root.nomH * 0.04)
                size: root.size === "small" ? Math.round(root.nomW * 0.5) : Math.round(Math.min(root.nomW, root.nomH) * (root.size === "large" ? 0.36 : 0.42))
                stroke: root.size === "small" ? 3 : 3.8
                name: root.glyph
                color: Theme.tileText
            }
            Text {
                visible: root.size !== "small" && root.label !== ""
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 8; bottomMargin: 6; right: parent.right; rightMargin: 8 }
                text: root.label; elide: Text.ElideRight
                color: Theme.tileText; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Normal
            }
        }
        // back face: pre-rotated half a turn so it reads upright once the body has flipped
        Item {
            id: backFace
            anchors.fill: parent
            visible: root.showingBack
            transform: Rotation { origin.x: backFace.width / 2; origin.y: backFace.height / 2; axis { x: 1; y: 0; z: 0 } angle: 180 }
            Rectangle { anchors.fill: parent; color: root.fill; radius: Theme.tileRadius }
            Item { id: backContent; anchors.fill: parent }
        }
    }

    // flip schedule: one-time stagger pause, then every period: hold front, flip to back, hold, flip on to front
    SequentialAnimation {
        id: flipper
        running: root.live && root.flipEnabled && !Theme.reduceMotion && root.visible
        onRunningChanged: if (!running) root.flipAngle = 0
        PauseAnimation { duration: (root.index * Theme.flipStaggerMs * 3) % Theme.flipPeriodMs }
        SequentialAnimation {
            loops: Animation.Infinite
            PauseAnimation { duration: Theme.flipPeriodMs / 2 - Theme.flipMs }
            NumberAnimation { target: root; property: "flipAngle"; from: 0; to: 180; duration: Theme.flipMs; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: Theme.flipPeriodMs / 2 - Theme.flipMs }
            NumberAnimation { target: root; property: "flipAngle"; from: 180; to: 360; duration: Theme.flipMs; easing.type: Easing.InOutQuad }
            ScriptAction { script: root.flipAngle = 0 }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        preventStealing: root.flat
        onPressed: (m) => root.touch = Qt.point(m.x, m.y)
        onPositionChanged: (m) => root.touch = Qt.point(m.x, m.y)
        onClicked: root.clicked(root.sceneRect())
        onPressAndHold: root.pressAndHold()
    }
}
