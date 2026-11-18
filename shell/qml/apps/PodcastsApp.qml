import QtQuick
import FlowShell

// Podcasts app. RSS is fetched with XMLHttpRequest and parsed with plain JS (no XmlListModel).
// Playback and downloads use external programs (mpv/vlc/ffplay/mpg123, curl/wget) via Sys.launch; there is no audio backend in QML.
// Resume position is NOT supported: an episode always starts from the beginning. `provider` holds fetch/parse/player/download logic.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // ---- state (persisted under AppStore "podcasts") ----
    property var feeds: []          // [{name, url}]
    property var episodes: []       // cached [{feed, title, url, date, ts, dur}]
    property var played: ({})       // enclosure url -> true
    property var feedStatus: ({})   // feed url -> status text (not persisted)
    property string nowTitle: ""
    property string playStatus: ""
    property bool playing: false
    property string addError: ""
    property var files: []          // downloaded files
    property string dlMsg: ""

    readonly property string dlDir: Sys.home() + "/Podcasts"

    function save() { AppStore.save("podcasts", { feeds: feeds, episodes: episodes, played: played }) }
    function setStatus(url, msg) { var s = Object.assign({}, feedStatus); s[url] = msg; feedStatus = s }

    function addFeed(name, url) {
        name = name.trim(); url = url.trim()
        if (name === "" || !/^https?:\/\/\S+$/i.test(url)) { addError = "enter a name and a full http(s) feed url"; return false }
        for (var i = 0; i < feeds.length; ++i) if (feeds[i].url === url) { addError = "that feed is already subscribed"; return false }
        var f = feeds.slice(); f.push({ name: name, url: url })
        feeds = f; addError = ""; save()
        refresh(f[f.length - 1])
        return true
    }
    function removeFeed(url) {
        feeds = feeds.filter(function(f) { return f.url !== url })
        episodes = episodes.filter(function(e) { return e.feedUrl !== url })
        save()
    }
    function refresh(feed) {
        setStatus(feed.url, "loading...")
        provider.fetchFeed(feed, function(ok, res) {
            if (!ok) { root.setStatus(feed.url, res); return }
            var rest = root.episodes.filter(function(e) { return e.feedUrl !== feed.url })
            root.episodes = rest.concat(res)
            root.setStatus(feed.url, res.length + " episodes")
            root.save()
        })
    }
    function refreshAll() { for (var i = 0; i < feeds.length; ++i) refresh(feeds[i]) }
    function isPlayed(url) { return played[url] === true }
    function setPlayed(url, v) {
        var p = Object.assign({}, played)
        if (v) p[url] = true; else delete p[url]
        played = p; save()
    }
    function play(src, title) {
        provider.stop()
        var r = provider.start(src)
        playing = r.ok; playStatus = r.msg
        nowTitle = r.ok ? title : ""
    }
    function stopPlayback() { provider.stop(); playing = false; playStatus = "stopped" }
    function playEpisode(e) { setPlayed(e.url, true); play(e.url, e.title) }
    function scanFiles() {
        files = Sys.exists(dlDir) ? Sys.listDir(dlDir, ["mp3", "m4a", "ogg", "opus", "aac", "wav", "flac"], false, 500) : []
    }
    function download(e) {
        var r = provider.download(e)
        dlMsg = r
        dlTimer.restart()
    }
    function fmtSize(b) { return b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.round(b / 1024) + " KB" }

    Component.onCompleted: {
        var s = AppStore.load("podcasts", null)
        if (s) {
            feeds = (s.feeds || []).filter(function(f) { return f && f.url && f.name })
            episodes = s.episodes || []
            played = s.played || {}
        }
        provider.detect()
        scanFiles()
        if (feeds.length > 0) refreshAll()
    }

    QtObject {
        id: provider
        property string player: ""
        property string running: ""
        property string dler: ""
        function detect() {
            var c = ["mpv", "vlc", "ffplay", "mpg123"]
            player = ""
            for (var i = 0; i < c.length; ++i) {
                var r = Sys.run("which", [c[i]], 2000)
                if (r.code === 0 && String(r.out).trim() !== "") { player = c[i]; break }
            }
            dler = ""
            var d = ["curl", "wget"]
            for (var j = 0; j < d.length; ++j) {
                var q = Sys.run("which", [d[j]], 2000)
                if (q.code === 0 && String(q.out).trim() !== "") { dler = d[j]; break }
            }
        }
        function argsFor(p, src) {
            if (p === "mpv") return ["--no-video", "--really-quiet", src]
            if (p === "vlc") return ["-I", "dummy", "--no-video", "--play-and-exit", src]
            if (p === "ffplay") return ["-nodisp", "-autoexit", "-loglevel", "quiet", src]
            return ["-q", src]
        }
        function start(src) {
            if (player === "") detect()
            if (player === "") return { ok: false, msg: "no player installed (mpv, vlc, ffplay, mpg123): sudo apt install mpv" }
            if (!Sys.launch(player, argsFor(player, src))) return { ok: false, msg: "could not start " + player }
            running = player
            return { ok: true, msg: "playing via " + player + " (no resume: starts from the beginning)" }
        }
        function stop() {
            if (running !== "") Sys.run("pkill", ["-x", running], 2000)
            running = ""
        }
        function alive() { return running !== "" && Sys.run("pgrep", ["-x", running], 2000).code === 0 }

        function download(e) {
            if (dler === "") detect()
            if (dler === "") return "no downloader found: sudo apt install curl"
            Sys.run("mkdir", ["-p", root.dlDir], 2000)
            var ext = (/\.(mp3|m4a|ogg|opus|aac|wav|flac)(\?|$)/i.exec(e.url) || [0, "mp3"])[1].toLowerCase()
            var base = (e.title || "episode").replace(/[^A-Za-z0-9 _.-]/g, "").trim().substring(0, 60) || "episode"
            var out = root.dlDir + "/" + base + "." + ext
            var ok = dler === "curl" ? Sys.launch("curl", ["-L", "--fail", "-s", "-o", out, e.url])
                                     : Sys.launch("wget", ["-q", "-O", out, e.url])
            return ok ? "downloading to " + out + " (see downloads page, refresh when done)" : "could not start " + dler
        }

        // ---- RSS ----
        function decode(s) {
            return s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]+>/g, "")
                    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;|&#39;/g, "'")
                    .replace(/&amp;/g, "&").replace(/\s+/g, " ").trim()
        }
        function tag(block, name) {
            var m = new RegExp("<" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + name + ">", "i").exec(block)
            return m ? decode(m[1]) : ""
        }
        function parse(text, feed) {
            var parts = text.split(/<item[\s>]/i)
            var out = []
            for (var i = 1; i < parts.length && out.length < 50; ++i) {
                var b = parts[i]
                var m = /<enclosure[^>]*?\surl\s*=\s*["']([^"']+)["']/i.exec(b)
                if (!m) continue
                var date = tag(b, "pubDate")
                var ts = Date.parse(date)
                out.push({
                    feed: feed.name, feedUrl: feed.url,
                    title: tag(b, "title") || "untitled",
                    url: m[1].replace(/&amp;/g, "&"),
                    date: date, ts: isNaN(ts) ? 0 : ts,
                    dur: tag(b, "itunes:duration")
                })
            }
            return out
        }
        function fetchFeed(feed, cb) {
            var x = new XMLHttpRequest()
            x.onreadystatechange = function() {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status === 200 && x.responseText) {
                    var eps = parse(x.responseText, feed)
                    if (eps.length === 0) cb(false, "no episodes found in feed")
                    else cb(true, eps)
                } else if (x.status === 0) cb(false, "network unavailable or url unreachable (cached episodes kept)")
                else cb(false, "http error " + x.status)
            }
            x.open("GET", feed.url)
            x.timeout = 15000
            x.ontimeout = function() { cb(false, "request timed out (cached episodes kept)") }
            x.send()
        }
    }

    readonly property var sorted: episodes.slice().sort(function(a, b) { return b.ts - a.ts })

    Timer {
        interval: 3000; repeat: true; running: root.playing
        onTriggered: if (!provider.alive()) { root.playing = false; root.playStatus = "player exited (finished, failed or stopped)"; provider.running = "" }
    }
    Timer { id: dlTimer; interval: 8000; onTriggered: root.scanFiles() }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    component SmallBtn: Item {
        id: sb
        property string glyph: "close"
        property color ink: Theme.textDim
        signal clicked
        width: 56; height: 68
        opacity: sma.pressed ? 0.5 : 1
        TileGlyph { anchors.centerIn: parent; name: sb.glyph; size: 28; stroke: 2; color: sb.ink }
        MouseArea { id: sma; anchors.fill: parent; onClicked: sb.clicked() }
    }

    Pivot {
        id: pivot
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "podcasts"

        PivotPage {
            title: "subscriptions"
            Text {
                visible: root.feeds.length === 0
                width: parent.width; wrapMode: Text.Wrap
                text: "no subscriptions yet. paste a podcast rss feed url and a name below, then tap add. episodes load over the network."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            Repeater {
                model: root.feeds
                Item {
                    id: fr
                    required property var modelData
                    width: parent.width; height: 68
                    MetroListRow {
                        width: fr.width - 56
                        glyph: "people"
                        title: fr.modelData.name
                        subtitle: root.feedStatus[fr.modelData.url] || "tap to refresh"
                        onClicked: root.refresh(fr.modelData)
                    }
                    SmallBtn { x: fr.width - 56; glyph: "close"; onClicked: root.removeFeed(fr.modelData.url) }
                }
            }
            Item { width: 1; height: 12 }
            MetroButton { visible: root.feeds.length > 0; text: "refresh all"; onClicked: root.refreshAll() }
            Item { width: 1; height: 12 }
            MetroSectionHeader { text: "add feed" }
            MetroTextField { id: nameField; width: parent.width; label: "name"; placeholder: "my podcast" }
            Item { width: 1; height: 8 }
            MetroTextField { id: urlField; width: parent.width; label: "feed url"; placeholder: "https://.../feed.xml"
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
                onClicked: if (root.addFeed(nameField.text, urlField.text)) { nameField.text = ""; urlField.text = ""; pivot.goTo(1) }
            }
        }

        PivotPage {
            title: "episodes"
            Text {
                visible: root.playStatus !== ""
                width: parent.width; wrapMode: Text.Wrap
                text: (root.nowTitle !== "" ? root.nowTitle + ": " : "") + root.playStatus
                color: provider.player === "" ? Theme.accent : Theme.textDim
                font.family: Theme.font; font.pixelSize: 18
            }
            Item { visible: root.playing; width: 1; height: 8 }
            MetroButton { visible: root.playing; text: "stop"; onClicked: root.stopPlayback() }
            Item { visible: root.playStatus !== ""; width: 1; height: 10 }
            Text {
                visible: root.sorted.length === 0
                width: parent.width; wrapMode: Text.Wrap
                text: root.feeds.length === 0
                    ? "nothing here. add a feed on the subscriptions page."
                    : "no episodes loaded. check the feed status on the subscriptions page (network may be unavailable)."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            Repeater {
                model: root.sorted
                Item {
                    id: er
                    required property var modelData
                    width: parent.width; height: 68
                    MetroListRow {
                        width: er.width - 56
                        glyph: "music"
                        iconColor: root.isPlayed(er.modelData.url) ? (Theme.dark ? "#3a3a3a" : "#9a9a9a") : Theme.accent
                        title: er.modelData.title
                        subtitle: er.modelData.feed + (er.modelData.date ? " · " + er.modelData.date.replace(/ \d\d:\d\d:\d\d.*$/, "") : "")
                                  + (er.modelData.dur ? " · " + er.modelData.dur : "") + (root.isPlayed(er.modelData.url) ? " · played" : "")
                        onClicked: root.playEpisode(er.modelData)
                        onPressAndHold: root.setPlayed(er.modelData.url, !root.isPlayed(er.modelData.url))
                    }
                    SmallBtn { x: er.width - 56; glyph: "files"; onClicked: root.download(er.modelData) }
                }
            }
            Item { width: 1; height: 8 }
            Text {
                visible: root.sorted.length > 0
                width: parent.width; wrapMode: Text.Wrap
                text: "tap plays and marks played; hold toggles played; files button downloads. resume position is not supported."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 15
            }
        }

        PivotPage {
            title: "downloads"
            Text {
                visible: root.dlMsg !== ""
                width: parent.width; wrapMode: Text.Wrap
                text: root.dlMsg; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
            Text {
                text: "folder: " + root.dlDir
                width: parent.width; elide: Text.ElideMiddle
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
            Item { width: 1; height: 8 }
            Text {
                visible: root.files.length === 0
                width: parent.width; wrapMode: Text.Wrap
                text: "no downloaded episodes. use the files button on an episode (needs curl or wget), then refresh."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
            }
            Repeater {
                model: root.files
                MetroListRow {
                    required property var modelData
                    glyph: "music"
                    title: modelData.name
                    subtitle: root.fmtSize(modelData.size)
                    onClicked: { root.play(modelData.path, modelData.name); pivot.goTo(1) }
                }
            }
            Item { width: 1; height: 12 }
            MetroButton { text: "refresh"; onClicked: root.scanFiles() }
            Item { width: 1; height: 8 }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: provider.player === ""
                    ? "no audio player found: sudo apt install mpv"
                    : "player: " + provider.player + (provider.dler !== "" ? ", downloader: " + provider.dler : ", no downloader (sudo apt install curl)")
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
        }
    }

    focus: true
    function back() { closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
