import QtQuick
import FlowShell

// Radio app. No audio backend in QML: streams are played by an external player (mpv/vlc/ffplay/mpg123)
// started with Sys.launch and stopped with pkill. `provider` holds the station list and player control.
// The elapsed timer is SIMULATED (counts seconds since launch); status comes from polling the player process.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // ---- state (persisted under AppStore "radio") ----
    property var custom: []        // [{name, url}]
    property var favs: []          // [url]
    property string curUrl: ""     // station last started
    property string curName: ""
    property bool playing: false
    property int elapsed: 0
    property string status: "stopped"
    property string addError: ""

    readonly property var all: provider.curated.concat(custom)
    readonly property var favList: all.filter(function(s) { return favs.indexOf(s.url) >= 0 })

    function save() { AppStore.save("radio", { custom: custom, favs: favs, last: curUrl }) }
    function isFav(url) { return favs.indexOf(url) >= 0 }
    function toggleFav(url) {
        var f = favs.slice(), i = f.indexOf(url)
        if (i >= 0) f.splice(i, 1); else f.push(url)
        favs = f; save()
    }
    function addStation(name, url) {
        name = name.trim(); url = url.trim()
        if (name === "" || !/^https?:\/\/\S+$/i.test(url)) { addError = "enter a name and a full http(s) stream url"; return false }
        for (var i = 0; i < all.length; ++i) if (all[i].url === url) { addError = "that url is already in the list"; return false }
        var c = custom.slice(); c.push({ name: name, url: url, note: "custom station" })
        custom = c; addError = ""; save()
        return true
    }
    function removeCustom(url) {
        custom = custom.filter(function(s) { return s.url !== url })
        favs = favs.filter(function(u) { return u !== url })
        save()
    }
    function play(st) {
        provider.stop()
        curUrl = st.url; curName = st.name; elapsed = 0
        var r = provider.start(st.url)
        playing = r.ok
        status = r.msg
        save()
    }
    function stopPlayback() {
        provider.stop()
        playing = false; elapsed = 0
        status = "stopped"
    }
    function fmt(s) {
        var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, x = s % 60
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (x < 10 ? "0" : "") + x
    }
    Component.onCompleted: {
        var s = AppStore.load("radio", null)
        if (s) {
            custom = (s.custom || []).filter(function(c) { return c && c.url && c.name })
            favs = s.favs || []
            var last = all.filter(function(x) { return x.url === s.last })
            if (last.length > 0) { curUrl = last[0].url; curName = last[0].name }
        }
        provider.detect()
    }

    // ---- provider: stations + external player control ----
    QtObject {
        id: provider
        property string player: ""       // found player program ("" = none)
        property string running: ""      // player name we started and may kill
        function detect() {
            var c = ["mpv", "vlc", "ffplay", "mpg123"]
            player = ""
            for (var i = 0; i < c.length; ++i) {
                var r = Sys.run("which", [c[i]], 2000)
                if (r.code === 0 && String(r.out).trim() !== "") { player = c[i]; return }
            }
        }
        function argsFor(p, url) {
            if (p === "mpv") return ["--no-video", "--really-quiet", url]
            if (p === "vlc") return ["-I", "dummy", "--no-video", url]
            if (p === "ffplay") return ["-nodisp", "-loglevel", "quiet", url]
            return ["-q", url]
        }
        function start(url) {
            if (player === "") detect()
            if (player === "") return { ok: false, msg: "no player installed: sudo apt install mpv" }
            if (!Sys.launch(player, argsFor(player, url))) return { ok: false, msg: "could not start " + player }
            running = player
            return { ok: true, msg: "starting " + player + "..." }
        }
        function stop() {
            if (running !== "") Sys.run("pkill", ["-x", running], 2000)
            running = ""
        }
        function alive() {
            if (running === "") return false
            return Sys.run("pgrep", ["-x", running], 2000).code === 0
        }
        // Official public stream URLs. note "unverified link" = not checked against the provider's current list.
        readonly property var curated: [
            { name: "SomaFM Groove Salad", url: "https://ice1.somafm.com/groovesalad-128-mp3", note: "ambient / downtempo" },
            { name: "SomaFM Drone Zone", url: "https://ice1.somafm.com/dronezone-128-mp3", note: "ambient space music" },
            { name: "SomaFM Secret Agent", url: "https://ice1.somafm.com/secretagent-128-mp3", note: "lounge / spy" },
            { name: "SomaFM DEF CON Radio", url: "https://ice1.somafm.com/defcon-128-mp3", note: "hacker music" },
            { name: "SomaFM Lush", url: "https://ice1.somafm.com/lush-128-mp3", note: "mellow vocals" },
            { name: "SomaFM Space Station", url: "https://ice1.somafm.com/spacestation-128-mp3", note: "spacey electronica" },
            { name: "SomaFM Deep Space One", url: "https://ice1.somafm.com/deepspaceone-128-mp3", note: "deep ambient" },
            { name: "SomaFM Fluid", url: "https://ice1.somafm.com/fluid-128-mp3", note: "instrumental hip-hop" },
            { name: "SomaFM Indie Pop Rocks", url: "https://ice1.somafm.com/indiepop-128-mp3", note: "indie pop" },
            { name: "SomaFM The Trip", url: "https://ice1.somafm.com/thetrip-128-mp3", note: "progressive" },
            { name: "SomaFM Boot Liquor", url: "https://ice1.somafm.com/bootliquor-128-mp3", note: "americana" },
            { name: "SomaFM Sonic Universe", url: "https://ice1.somafm.com/sonicuniverse-128-mp3", note: "jazz / fusion" },
            { name: "SomaFM Underground 80s", url: "https://ice1.somafm.com/u80s-128-mp3", note: "new wave" },
            { name: "SomaFM PopTron", url: "https://ice1.somafm.com/poptron-128-mp3", note: "electropop" },
            { name: "SomaFM Beat Blender", url: "https://ice1.somafm.com/beatblender-128-mp3", note: "downtempo beats" },
            { name: "SomaFM cliqhop idm", url: "https://ice1.somafm.com/cliqhop-128-mp3", note: "idm / glitch" },
            { name: "SomaFM Folk Forward", url: "https://ice1.somafm.com/folkfwd-128-mp3", note: "indie folk" },
            { name: "SomaFM Seven Inch Soul", url: "https://ice1.somafm.com/7soul-128-mp3", note: "vintage soul" },
            { name: "Radio Paradise Main Mix", url: "https://stream.radioparadise.com/mp3-128", note: "eclectic, unverified link" },
            { name: "Radio Paradise Mellow Mix", url: "https://stream.radioparadise.com/mellow-128", note: "mellow, unverified link" },
            { name: "KEXP Seattle", url: "https://kexp.streamguys1.com/kexp128.mp3", note: "indie / eclectic, unverified link" },
            { name: "BBC World Service", url: "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service", note: "news, unverified link (may be geo-limited)" },
            { name: "FIP (Radio France)", url: "https://icecast.radiofrance.fr/fip-midfi.mp3", note: "eclectic, unverified link" },
            { name: "Deutschlandfunk", url: "https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3", note: "news / talk (de), unverified link" },
            { name: "NTS Radio 1", url: "https://stream-relay-geo.ntslive.net/stream", note: "underground, unverified link" }
        ]
    }

    // elapsed counter (simulated clock since launch)
    Timer {
        interval: 1000; repeat: true; running: root.playing
        onTriggered: root.elapsed += 1
    }
    // status from player process
    Timer {
        interval: 3000; repeat: true; running: root.playing
        onTriggered: {
            if (provider.alive()) root.status = "playing via " + provider.running
            else { root.playing = false; root.status = "player exited (stream failed, offline or stopped)"; provider.running = "" }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // station row: tap plays; star toggles favourite; close removes custom stations
    component StationRow: Item {
        id: sr
        property var st
        property bool removable: false
        width: parent ? parent.width : 360
        height: 68
        MetroListRow {
            width: sr.width - (sr.removable ? 112 : 56)
            glyph: "music"
            iconColor: sr.st.url === root.curUrl && root.playing ? Theme.accent : (Theme.dark ? "#3a3a3a" : "#9a9a9a")
            title: sr.st.name
            subtitle: sr.st.note || ""
            onClicked: { root.play(sr.st); pivot.goTo(2) }
        }
        Item {
            x: sr.width - (sr.removable ? 112 : 56); width: 56; height: 68
            opacity: fma.pressed ? 0.5 : 1
            TileGlyph { anchors.centerIn: parent; name: "star"; size: 30; stroke: 2
                color: root.isFav(sr.st.url) ? Theme.accent : Theme.textDim }
            MouseArea { id: fma; anchors.fill: parent; onClicked: root.toggleFav(sr.st.url) }
        }
        Item {
            visible: sr.removable
            x: sr.width - 56; width: 56; height: 68
            opacity: dma.pressed ? 0.5 : 1
            TileGlyph { anchors.centerIn: parent; name: "close"; size: 26; stroke: 2; color: Theme.textDim }
            MouseArea { id: dma; anchors.fill: parent; onClicked: root.removeCustom(sr.st.url) }
        }
    }

    Pivot {
        id: pivot
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "radio"

        PivotPage {
            title: "stations"
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: "tap to play, star to favourite. links marked unverified may be offline."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
            Item { width: 1; height: 8 }
            Repeater {
                model: root.all
                StationRow {
                    required property var modelData
                    st: modelData
                    removable: modelData.note === "custom station"
                }
            }
            Item { width: 1; height: 16 }
            MetroSectionHeader { text: "add station" }
            MetroTextField { id: nameField; width: parent.width; label: "name"; placeholder: "my station" }
            Item { width: 1; height: 8 }
            MetroTextField { id: urlField; width: parent.width; label: "stream url"; placeholder: "https://..."
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText }
            Item { width: 1; height: 8 }
            Text {
                visible: root.addError !== ""
                width: parent.width; wrapMode: Text.Wrap
                text: root.addError; color: Theme.accent; font.family: Theme.font; font.pixelSize: 18
            }
            Item { width: 1; height: 8 }
            MetroButton {
                text: "add"; accentFill: true
                onClicked: if (root.addStation(nameField.text, urlField.text)) { nameField.text = ""; urlField.text = "" }
            }
        }

        PivotPage {
            title: "favourites"
            Text {
                visible: root.favList.length === 0
                width: parent.width; wrapMode: Text.Wrap
                text: "no favourites yet. star a station on the stations page."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            Repeater {
                model: root.favList
                StationRow {
                    required property var modelData
                    st: modelData
                    removable: modelData.note === "custom station"
                }
            }
        }

        PivotPage {
            title: "now playing"
            Item { width: 1; height: 6 }
            Rectangle {
                readonly property real side: Math.min(parent.width, 240)
                width: side; height: side
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.accent
                TileGlyph { anchors.centerIn: parent; name: "music"; size: parent.width * 0.5; color: Theme.onColor(Theme.accent); stroke: 3 }
            }
            Item { width: 1; height: 14 }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.curName !== "" ? root.curName : "nothing selected"
                color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Theme.fontLight
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: root.status
                color: provider.player === "" ? Theme.accent : Theme.textDim
                font.family: Theme.font; font.pixelSize: 20
            }
            Item { width: 1; height: 6 }
            Text {
                text: root.fmt(root.elapsed)
                color: Theme.text; font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: "elapsed is a simulated clock since launch, not a stream position."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 15
            }
            Item { width: 1; height: 16 }
            Row {
                spacing: 16
                MetroButton {
                    text: root.playing ? "stop" : "play"; accentFill: !root.playing
                    enabled2: root.playing || root.curUrl !== ""
                    onClicked: {
                        if (root.playing) root.stopPlayback()
                        else root.play({ name: root.curName, url: root.curUrl })
                    }
                }
                MetroButton {
                    text: root.curUrl !== "" && root.isFav(root.curUrl) ? "unfavourite" : "favourite"
                    enabled2: root.curUrl !== ""
                    onClicked: root.toggleFav(root.curUrl)
                }
            }
            Item { width: 1; height: 16 }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: provider.player === ""
                    ? "no player found (mpv, vlc, ffplay, mpg123). install one: sudo apt install mpv"
                    : "player: " + provider.player + ". stop ends all running " + provider.player + " processes."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
            Item { width: 1; height: 8 }
            MetroButton { text: "recheck player"; onClicked: provider.detect() }
        }
    }

    focus: true
    function back() { closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
