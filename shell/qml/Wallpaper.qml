import QtQuick
import FlowShell

Item {
    id: root
    // procedural wallpaper (no assets); animated phase is slow and off when reduce-motion
    property real phase: 0.6
    // 1 Hz steps instead of a 60 fps animation: a full-screen shader redraw every vsync was the biggest idle GPU cost.
    property bool active: true
    Timer {
        interval: 1000; repeat: true
        running: root.active && !Theme.reduceMotion && Theme.wallpaperSource === "" && root.visible && !Services.asleep
        onTriggered: root.phase = root.phase + 0.0698 > 6.88 ? 0.6 : root.phase + 0.0698
    }
    Image {
        anchors.fill: parent; visible: Theme.wallpaperSource !== ""
        source: Theme.wallpaperSource; fillMode: Image.PreserveAspectCrop; asynchronous: false; smooth: true
        sourceSize: Qt.size(root.width * 2, root.height * 2)
    }
    ShaderEffect {
        anchors.fill: parent; visible: Theme.wallpaperSource === ""
        property real aspect: width / Math.max(1, height)
        property real phase: root.phase
        property color c0: Theme.wall0
        property color c1: Theme.wall1
        property color c2: Theme.wall2
        property color c3: Theme.wall3
        fragmentShader: "qrc:/FlowShell/shaders/wallpaper.frag.qsb"
    }
}
