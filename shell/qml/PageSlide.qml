import QtQuick
import FlowShell

// Reusable iOS-style page slide. A page enters from the right edge (p 0 -> 1) over the page below it.
// The page below is told how far it is covered (cover 0..1): it shifts left by `parallax` * width and dims.
// Drive p / cover from a finger (back-swipe peek) or an animation; this item only renders them.
// Content goes in as children. Width/height are set by the user (page size).
Item {
    id: root
    property real p: 1                 // enter progress: 0 off-screen right, 1 settled
    property real cover: 0             // how far a newer page covers this one: 0 none, 1 fully
    property real parallax: 0.3        // fraction of width this page shifts left while covered
    property real dimMax: 0.3          // black overlay opacity at cover = 1
    property bool edgeShadow: true
    default property alias content: holder.data

    x: (1 - Math.max(0, Math.min(1, p))) * width - Math.max(0, Math.min(1, cover)) * parallax * width

    Item { id: holder; anchors.fill: parent }

    // soft shadow cast on the page below by this page's left edge
    Rectangle {
        visible: root.edgeShadow && root.p < 0.999 && root.p > 0.001
        anchors.right: parent.left; width: 16; height: parent.height
        gradient: Gradient { orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#40000000" } }
    }
    // dim while covered
    Rectangle {
        anchors.fill: parent; z: 1000; color: "black"
        visible: root.cover > 0.001
        opacity: Math.max(0, Math.min(1, root.cover)) * root.dimMax
    }
}
