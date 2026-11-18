import QtQuick
import FlowShell

// Camera launcher. There is no camera backend in the shell: this only runs an external capture tool if one is
// installed (checked with `which`). Nothing is faked: without a tool the viewfinder stays black and the shutter is disabled.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // Configurable capture commands, first installed wins. %1 = output path. Edit here to change the command.
    property var stillTools: [
        { prog: "libcamera-still", args: ["-n", "-o", "%1"] },
        { prog: "rpicam-still",    args: ["-n", "-o", "%1"] },
        { prog: "fswebcam",        args: ["-r", "1280x720", "--no-banner", "%1"] },
        { prog: "ffmpeg",          args: ["-f", "v4l2", "-i", "/dev/video0", "-frames:v", "1", "-y", "%1"] }
    ]
    property var videoTools: [
        { prog: "libcamera-vid", args: ["-n", "-t", "10000", "-o", "%1"] },
        { prog: "rpicam-vid",    args: ["-n", "-t", "10000", "-o", "%1"] }
    ]
    property var stillTool: null
    property var videoTool: null
    property bool otherTool: false     // some camera program exists but no capture command
    property string otherName: ""
    property int mode: 0               // 0 photo, 1 video
    property string newest: ""
    property string message: ""
    property bool busy: false

    readonly property var tool: mode === 0 ? stillTool : videoTool
    readonly property bool ready: tool !== null
    readonly property string status: ready ? "ready: " + tool.prog
        : (otherTool ? "camera tool found (" + otherName + ") but no capture command is configured" : "camera backend not available")

    function has(p) { var r = Sys.run("which", [p], 2000); return r && r.code === 0 }
    function firstOf(list) { for (var i = 0; i < list.length; ++i) if (has(list[i].prog)) return list[i]; return null }
    function detect() {
        stillTool = firstOf(stillTools)
        videoTool = firstOf(videoTools)
        otherTool = false; otherName = ""
        if (!stillTool && !videoTool) {
            var o = ["libcamera-hello", "rpicam-hello", "cam", "ffplay"]
            for (var i = 0; i < o.length; ++i) if (has(o[i])) { otherTool = true; otherName = o[i]; break }
        }
    }
    function refreshNewest() {
        var dir = Sys.home() + "/Pictures"
        newest = ""
        if (!Sys.exists(dir)) return
        var l = Sys.listDir(dir, ["jpg", "jpeg", "png", "webp"], true, 500)
        var best = null, bt = -1
        for (var i = 0; i < l.length; ++i) {
            var t = new Date(l[i].modified).getTime()
            if (isNaN(t)) t = 0
            if (t > bt) { bt = t; best = l[i] }
        }
        if (best) newest = best.path
    }
    function capture() {
        if (!ready || busy) return
        var ts = Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")
        var out = mode === 0 ? Sys.home() + "/Pictures/IMG_" + ts + ".jpg" : Sys.home() + "/Videos/VID_" + ts + ".h264"
        var args = tool.args.map(function(a) { return a.replace("%1", out) })
        if (Sys.launch(tool.prog, args)) {
            busy = true
            message = mode === 0 ? "capturing..." : "recording 10 s..."
            doneTimer.interval = mode === 0 ? 3500 : 11500
            doneTimer.restart()
        } else message = "could not start " + tool.prog
    }
    Timer {
        id: doneTimer
        onTriggered: {
            busy = false
            message = root.mode === 0 ? "saved to ~/Pictures" : "saved to ~/Videos"
            root.refreshNewest()
        }
    }
    Component.onCompleted: { detect(); refreshNewest() }

    Pivot {
        id: pivot
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "camera"
        titleSize: 56
        currentIndex: root.mode
        onPageChanged: function(i) { root.mode = i }

        PivotPage { title: "photo"; clip: false }
        PivotPage { title: "video"; clip: false }
    }

    // viewfinder (fixed, below the pivot header)
    Item {
        id: vf
        x: 18; y: root.topInset + pivot.headerHeight + 8
        width: parent.width - 36
        height: Math.max(120, parent.height - y - shutterRow.height - 24)
        Rectangle { anchors.fill: parent; color: "black"; border.width: 1; border.color: Theme.dark ? "#333333" : "#999999" }
        // accent corner brackets
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property bool r: index % 2 === 1
                readonly property bool b: index >= 2
                x: r ? vf.width - 14 - 40 : 14
                y: b ? vf.height - 14 - 40 : 14
                width: 40; height: 40
                Rectangle { width: 40; height: 4; color: Theme.accent; y: parent.b ? 36 : 0 }
                Rectangle { width: 4; height: 40; color: Theme.accent; x: parent.r ? 36 : 0 }
            }
        }
        Text {
            anchors.centerIn: parent
            width: parent.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: root.status
            color: "#cccccc"; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
        }
        Text {
            visible: !root.ready
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 24
            width: parent.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: root.mode === 0 ? "install one to enable the shutter: sudo apt install libcamera-apps"
                                  : "video capture needs libcamera-vid or rpicam-vid: sudo apt install libcamera-apps"
            color: "#888888"; font.family: Theme.font; font.pixelSize: 16
        }
        Text {
            visible: root.message !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 60
            text: root.message; color: Theme.accent
            font.family: Theme.font; font.pixelSize: 18
        }
    }

    // shutter row: gallery shortcut | shutter
    Item {
        id: shutterRow
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        width: parent.width; height: 96

        Item {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            width: 72; height: 72
            Rectangle { anchors.fill: parent; color: Theme.dark ? "#222222" : "#dddddd" }
            Image {
                anchors.fill: parent
                visible: root.newest !== ""
                source: root.newest !== "" ? "file://" + root.newest : ""
                sourceSize: Qt.size(144, 144)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            TileGlyph { visible: root.newest === ""; anchors.centerIn: parent; name: "photos"; size: 34; color: Theme.textDim }
            MouseArea {
                anchors.fill: parent
                enabled: root.newest !== ""
                onClicked: Sys.openUrl("file://" + root.newest)
            }
        }

        Item {
            id: shutter
            anchors.centerIn: parent
            width: 84; height: 84
            opacity: root.ready && !root.busy ? (sma.pressed ? 0.6 : 1) : 0.35
            Rectangle { anchors.fill: parent; radius: 42; color: "transparent"; border.width: 4; border.color: Theme.text }
            Rectangle {
                anchors.centerIn: parent; width: 56; height: 56; radius: 28
                color: root.mode === 1 ? Theme.accent : Theme.text
            }
            MouseArea { id: sma; anchors.fill: parent; enabled: root.ready && !root.busy; onClicked: root.capture() }
        }
    }

    focus: true
    function back() { closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
