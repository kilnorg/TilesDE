import QtQuick
import FlowShell

// Recorder: honest launcher for an external capture tool (arecord / pw-record / parecord). No audio backend in QML.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property string recTool: ""          // first available capture tool, "" if none
    property string playTool: ""         // first available player, "" if none
    property bool recording: false
    property string startedTool: ""      // tool name actually launched (the only one we ever pkill)
    property string currentFile: ""
    property real startMs: 0
    property int elapsed: 0              // seconds
    property string playingTool: ""
    property string notice: ""
    property var recordings: []
    readonly property string dir: Sys.home() + "/Recordings"

    function back() { closeRequested() }
    function has(prog) {
        var r = Sys.run("which", [prog], 2000)
        return r && r.code === 0 && String(r.out).trim() !== ""
    }
    function fmtTime(s) {
        var m = Math.floor(s / 60), x = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (x < 10 ? "0" : "") + x
    }
    function fmtSize(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " mb"
        if (b >= 1024) return Math.round(b / 1024) + " kb"
        return b + " b"
    }
    function refresh() {
        var l = Sys.listDir(dir, ["wav", "ogg", "opus", "mp3"], false, 500) || []
        l = l.slice()
        l.sort(function(a, b) { return new Date(b.modified) - new Date(a.modified) })
        recordings = l
    }
    function startRec() {
        if (recTool === "" || recording) return
        var r = Sys.run("mkdir", ["-p", dir], 3000)
        if (!r || r.code !== 0) { notice = "could not create ~/Recordings"; return }
        var f = dir + "/rec_" + Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss") + ".wav"
        var args
        if (recTool === "arecord") args = ["-f", "cd", "-q", f]
        else if (recTool === "pw-record") args = [f]
        else args = ["--file-format=wav", f]
        if (!Sys.launch(recTool, args)) { notice = "failed to start " + recTool; return }
        notice = ""
        currentFile = f; startedTool = recTool
        startMs = Date.now(); elapsed = 0; recording = true
    }
    function stopRec() {
        if (!recording) return
        Sys.run("pkill", ["-INT", startedTool], 2000)
        recording = false
        notice = "saved " + currentFile.substring(currentFile.lastIndexOf("/") + 1)
        refreshTimer.restart()
    }
    function play(path) {
        if (playTool === "") return
        if (playingTool !== "") Sys.run("pkill", [playingTool], 2000)
        var ext = path.substring(path.lastIndexOf(".") + 1).toLowerCase()
        if (playTool === "aplay" && ext !== "wav") { notice = "aplay plays wav only; install pw-play, paplay or mpv"; return }
        if (Sys.launch(playTool, [path])) { playingTool = playTool; notice = "playing " + path.substring(path.lastIndexOf("/") + 1) }
        else notice = "failed to start " + playTool
    }
    function stopPlay() {
        if (playingTool !== "") Sys.run("pkill", [playingTool], 2000)
        playingTool = ""
        notice = ""
    }

    Component.onCompleted: {
        var rt = ["arecord", "pw-record", "parecord"]
        for (var i = 0; i < rt.length; ++i) if (has(rt[i])) { recTool = rt[i]; break }
        var pt = ["pw-play", "paplay", "aplay", "mpv"]
        for (var j = 0; j < pt.length; ++j) if (has(pt[j])) { playTool = pt[j]; break }
        refresh()
    }
    Timer { id: refreshTimer; interval: 700; onTriggered: root.refresh() }
    Timer {
        interval: 250; repeat: true; running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startMs) / 1000)
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Pivot {
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "recorder"

        PivotPage {
            title: "record"
            Item { width: 1; height: 24 }
            Item {
                width: parent.width; height: 220
                Rectangle {
                    id: btn
                    width: 180; height: 180; radius: 90
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "transparent"
                    border.width: 4
                    border.color: root.recording ? Theme.accent : Theme.text
                    opacity: root.recTool === "" ? 0.35 : (ma.pressed ? 0.6 : 1)
                    Rectangle {   // flat dot when idle, square when recording
                        anchors.centerIn: parent
                        width: root.recording ? 64 : 110; height: width
                        radius: root.recording ? 0 : width / 2
                        color: Theme.accent
                    }
                    MouseArea {
                        id: ma; anchors.fill: parent; enabled: root.recTool !== ""
                        onClicked: root.recording ? root.stopRec() : root.startRec()
                    }
                }
            }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: root.fmtTime(root.elapsed)
                color: root.recording ? Theme.accent : Theme.textDim
                font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight
            }
            Item { width: 1; height: 12 }
            Text {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
                text: root.recTool === ""
                    ? "no capture tool found. install alsa-utils (arecord), pipewire (pw-record) or pulseaudio-utils (parecord) to record."
                    : (root.recording ? "recording with " + root.startedTool + " — tap to stop"
                                      : "tap to record with " + root.recTool + " → ~/Recordings")
            }
            Item { width: 1; height: 8 }
            Text {
                visible: root.notice !== ""
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                color: Theme.accent; font.family: Theme.font; font.pixelSize: 18
                text: root.notice
            }
        }

        PivotPage {
            title: "recordings"
            Text {
                visible: root.playTool === ""
                width: parent.width; wrapMode: Text.Wrap; color: Theme.textDim
                text: "no player found (pw-play, paplay, aplay or mpv). files are listed but cannot be played here."
                font.family: Theme.font; font.pixelSize: 18
            }
            Item {
                visible: root.playingTool !== ""
                width: parent.width; height: visible ? 64 : 0
                MetroButton { y: 4; text: "stop playback"; onClicked: root.stopPlay() }
            }
            Repeater {
                model: root.recordings
                MetroListRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: root.fmtSize(modelData.size) + " · " + Qt.formatDateTime(new Date(modelData.modified), "d MMM yyyy HH:mm").toLowerCase()
                    onClicked: root.play(modelData.path)
                }
            }
            Text {
                visible: root.recordings.length === 0
                width: parent.width; wrapMode: Text.Wrap; color: Theme.textDim
                text: "no recordings in ~/Recordings yet."
                font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
            }
            Item { width: 1; height: 12 }
            MetroButton { text: "refresh"; onClicked: root.refresh() }
        }
    }
}
