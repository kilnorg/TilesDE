import QtQuick
import FlowShell

// Videos: library (Sys.listDir) and recent (AppStore "videos"). Playback via an external player (mpv, vlc, ffplay).
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var library: []     // [{path,name,size,mod}]
    property var recent: []      // [{path,name,size,mod}] newest first, max 30
    property string player: ""   // first available, "" if none
    property bool checked: false
    property string message: ""

    function fmtSize(b) { return b > 1073741824 ? (b / 1073741824).toFixed(1) + " gb" : b > 1048576 ? Math.round(b / 1048576) + " mb" : Math.max(1, Math.round(b / 1024)) + " kb" }
    function fmtDate(t) { return t > 0 ? new Date(t).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : "" }
    function sub(v) { return fmtSize(v.size) + (v.mod > 0 ? "  -  " + fmtDate(v.mod) : "") }

    function scan() {
        var h = Sys.home()
        var exts = ["mp4", "mkv", "webm", "avi", "mov"]
        var seen = {}, all = []
        var dirs = [h + "/Videos", h + "/Downloads", h + "/Desktop"]
        for (var d = 0; d < dirs.length; ++d) {
            if (!Sys.exists(dirs[d])) continue
            var l = Sys.listDir(dirs[d], exts, true, 500)
            for (var i = 0; i < l.length; ++i) {
                var e = l[i]
                if (seen[e.path]) continue
                seen[e.path] = true
                var t = new Date(e.modified).getTime()
                all.push({ path: e.path, name: e.name, size: e.size, mod: isNaN(t) ? 0 : t })
            }
        }
        all.sort(function(a, b) { return b.mod - a.mod })
        library = all
    }
    function detect() {
        var ps = ["mpv", "vlc", "ffplay"]
        player = ""
        for (var i = 0; i < ps.length; ++i) {
            var r = Sys.run("which", [ps[i]], 2000)
            if (r && r.code === 0) { player = ps[i]; break }
        }
        checked = true
    }
    function play(v) {
        if (player === "") { message = "no video player installed"; return }
        var args = player === "ffplay" ? ["-autoexit", v.path] : player === "vlc" ? ["--fullscreen", v.path] : ["--fs", v.path]
        if (Sys.launch(player, args)) {
            message = ""
            var r = recent.filter(function(x) { return x.path !== v.path })
            r.unshift(v)
            if (r.length > 30) r.length = 30
            recent = r
            AppStore.save("videos", r)
        } else message = "could not start " + player
    }
    Component.onCompleted: {
        var s = AppStore.load("videos", [])
        recent = Array.isArray(s) ? s : []
        detect()
        scan()
    }

    // honest message banner as shared component
    component Notice: Text {
        width: parent.width; wrapMode: Text.WordWrap
        color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20; font.weight: Theme.fontLight
        bottomPadding: 12
    }

    Pivot {
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "videos"

        PivotPage {
            title: "library"
            Notice {
                visible: root.checked && root.player === ""
                text: "no video player installed. install one: sudo apt install mpv"
                color: Theme.accent
            }
            Notice { visible: root.message !== "" && root.player !== ""; text: root.message }
            Notice {
                visible: root.library.length === 0
                text: "no videos found in ~/Videos, ~/Downloads or ~/Desktop"
            }
            Repeater {
                model: root.library
                MetroListRow {
                    required property var modelData
                    glyph: "video"
                    title: modelData.name
                    subtitle: root.sub(modelData)
                    onClicked: root.play(modelData)
                }
            }
        }

        PivotPage {
            title: "recent"
            Notice {
                visible: root.checked && root.player === ""
                text: "no video player installed. install one: sudo apt install mpv"
                color: Theme.accent
            }
            Notice { visible: root.recent.length === 0; text: "nothing played yet" }
            Repeater {
                model: root.recent
                MetroListRow {
                    required property var modelData
                    glyph: "video"
                    title: modelData.name
                    subtitle: root.sub(modelData)
                    onClicked: root.play(modelData)
                }
            }
        }
    }

    focus: true
    function back() { closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
