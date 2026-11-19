import QtQuick
import FlowShell

// Music app. Playback is SIMULATED (a Timer advances the position); the audio backend is TODO.
// `provider` is the only library source; replace its functions with a real backend later.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // ---- state (persisted under AppStore "music-state") ----
    property var queue: []          // track ids
    property int index: 0
    property real position: 0       // seconds
    property bool playing: false
    property bool shuffle: false
    property bool repeat: false
    // drill-down sub-view: kind "album" | "artist", name
    property string drillKind: ""
    property string drillName: ""

    readonly property var current: queue.length > 0 && index >= 0 && index < queue.length ? provider.track(queue[index]) : null
    readonly property var allTracks: provider.tracks()
    readonly property var drillTracks: drillKind === "" ? [] : provider.tracksBy(drillKind, drillName)

    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
    function save() { AppStore.save("music-state", { queue: queue, index: index, position: position, shuffle: shuffle, repeat: repeat }) }
    function playList(list, i) {
        queue = list.map(function(t) { return t.id })
        index = i; position = 0; playing = true
        save()
    }
    function next(auto) {
        if (queue.length === 0) return
        var n
        if (shuffle && queue.length > 1) {
            n = index
            while (n === index) n = Math.floor(Math.random() * queue.length)
        } else n = index + 1
        if (n >= queue.length) {
            if (repeat || !auto) n = 0
            else { playing = false; position = 0; save(); return }
        }
        index = n; position = 0; save()
    }
    function prev() {
        if (queue.length === 0) return
        if (position > 3) position = 0
        else { index = index > 0 ? index - 1 : queue.length - 1; position = 0 }
        save()
    }
    Component.onCompleted: {
        var s = AppStore.load("music-state", null)
        var ids = []
        if (s && s.queue) ids = s.queue.filter(function(id) { return provider.track(id) !== null })
        if (ids.length === 0) ids = allTracks.map(function(t) { return t.id })
        else {
            index = Math.max(0, Math.min(ids.length - 1, s.index || 0))
            position = s.position || 0
            shuffle = !!s.shuffle; repeat = !!s.repeat
        }
        queue = ids
        if (current && position >= current.dur) position = 0
    }

    // ---- data provider (offline demo library) ----
    QtObject {
        id: provider
        readonly property var lib: !Sys.demoData ? [] : [
            { id: 1, title: "Low Tide Signal", artist: "Northern Static", album: "Harbour Lights", dur: 214 },
            { id: 2, title: "Paper Lanterns", artist: "Northern Static", album: "Harbour Lights", dur: 187 },
            { id: 3, title: "Salt and Neon", artist: "Northern Static", album: "Harbour Lights", dur: 243 },
            { id: 4, title: "Quiet Engines", artist: "Northern Static", album: "Harbour Lights", dur: 198 },
            { id: 5, title: "Glass Orchard", artist: "Mira Voss", album: "Greenhouse", dur: 226 },
            { id: 6, title: "Slow Bloom", artist: "Mira Voss", album: "Greenhouse", dur: 205 },
            { id: 7, title: "Dew Point", artist: "Mira Voss", album: "Greenhouse", dur: 179 },
            { id: 8, title: "Fern Season", artist: "Mira Voss", album: "Greenhouse", dur: 251 },
            { id: 9, title: "Night Bus Home", artist: "The Copper Hours", album: "Last Service", dur: 232 },
            { id: 10, title: "Platform Nine", artist: "The Copper Hours", album: "Last Service", dur: 195 },
            { id: 11, title: "Transfer Ticket", artist: "The Copper Hours", album: "Last Service", dur: 208 },
            { id: 12, title: "Terminus", artist: "The Copper Hours", album: "Last Service", dur: 267 },
            { id: 13, title: "Amber Static", artist: "Oku", album: "Small Rooms", dur: 173 },
            { id: 14, title: "Floorboards", artist: "Oku", album: "Small Rooms", dur: 189 },
            { id: 15, title: "Radiator Hymn", artist: "Oku", album: "Small Rooms", dur: 221 },
            { id: 16, title: "Cartography", artist: "Delta Fern", album: "Open Water", dur: 238 },
            { id: 17, title: "Undertow", artist: "Delta Fern", album: "Open Water", dur: 202 },
            { id: 18, title: "Skyline Draft", artist: "Delta Fern", album: "Open Water", dur: 216 },
            { id: 19, title: "Morning Relay", artist: "Mira Voss", album: "Singles", dur: 184 },
            { id: 20, title: "Afterglow Protocol", artist: "Oku", album: "Singles", dur: 247 }
        ]
        function tracks() { return lib }
        function track(id) { for (var i = 0; i < lib.length; ++i) if (lib[i].id === id) return lib[i]; return null }
        function groups(kind) {
            var out = [], seen = {}
            for (var i = 0; i < lib.length; ++i) {
                var k = kind === "album" ? lib[i].album : lib[i].artist
                if (seen[k] === undefined) { seen[k] = out.length; out.push({ name: k, count: 0, sub: kind === "album" ? lib[i].artist : "" }) }
                out[seen[k]].count++
            }
            return out
        }
        function tracksBy(kind, name) {
            return lib.filter(function(t) { return (kind === "album" ? t.album : t.artist) === name })
        }
    }

    Timer {
        interval: 1000; repeat: true
        running: root.playing && root.current !== null
        onTriggered: {
            root.position += 1
            if (root.position >= root.current.dur) root.next(true)
            else if (root.position % 5 === 0) root.save()
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // round transport button: kind prev | play | pause | next
    component RoundBtn: Item {
        id: rb
        property string kind: "play"
        property real d: 64
        signal clicked
        width: d; height: d
        opacity: ma.pressed ? 0.5 : 1
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 2; border.color: Theme.text }
        Canvas {
            id: cv
            anchors.fill: parent
            property color ink: Theme.text
            property string k: rb.kind
            onInkChanged: requestPaint()
            onKChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"), w = width, u = w / 64
                c.reset()
                c.fillStyle = ink
                c.beginPath()
                if (k === "play") { c.moveTo(25 * u, 20 * u); c.lineTo(46 * u, 32 * u); c.lineTo(25 * u, 44 * u) }
                else if (k === "pause") { c.rect(22 * u, 20 * u, 7 * u, 24 * u); c.rect(35 * u, 20 * u, 7 * u, 24 * u) }
                else if (k === "next") { c.moveTo(21 * u, 21 * u); c.lineTo(37 * u, 32 * u); c.lineTo(21 * u, 43 * u); c.rect(39 * u, 21 * u, 5 * u, 22 * u) }
                else { c.moveTo(43 * u, 21 * u); c.lineTo(27 * u, 32 * u); c.lineTo(43 * u, 43 * u); c.rect(20 * u, 21 * u, 5 * u, 22 * u) }
                c.closePath()
                c.fill()
            }
        }
        MouseArea { id: ma; anchors.fill: parent; anchors.margins: -4; onClicked: rb.clicked() }
    }

    // text block used by song rows
    function rowSub(t) { return t.artist + " · " + t.album }

    Pivot {
        id: pivot
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "music"

        PivotPage {
            title: "now playing"
            Item { width: 1; height: 6 }
            Rectangle {
                id: art
                readonly property real side: Math.min(parent.width, 300)
                width: side; height: side
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.accent
                TileGlyph { anchors.centerIn: parent; name: "music"; size: parent.width * 0.5; color: Theme.onColor(Theme.accent); stroke: 3 }
            }
            Item { width: 1; height: 14 }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.current ? root.current.title : "nothing queued"
                color: Theme.text; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.current ? root.current.artist + " · " + root.current.album : ""
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21
            }
            Item { width: 1; height: 10 }
            MetroSlider {
                width: parent.width
                label: root.current ? root.fmt(root.position) + " / " + root.fmt(root.current.dur) : "0:00"
                showValue: false
                from: 0; to: root.current ? root.current.dur : 1
                value: root.position
                onMoved: (v) => { root.position = v; root.save() }
            }
            Item { width: 1; height: 4 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28
                RoundBtn { kind: "prev"; onClicked: root.prev() }
                RoundBtn { kind: root.playing ? "pause" : "play"; d: 76
                    onClicked: if (root.current) root.playing = !root.playing }
                RoundBtn { kind: "next"; onClicked: root.next(false) }
            }
            Item { width: 1; height: 22 }
            Row {
                width: parent.width
                MetroToggle {
                    width: parent.width / 2
                    label: "shuffle"
                    checked: root.shuffle
                    onToggled: (v) => { root.shuffle = v; root.save() }
                }
                MetroToggle {
                    width: parent.width / 2
                    label: "repeat"
                    checked: root.repeat
                    onToggled: (v) => { root.repeat = v; root.save() }
                }
            }
            Item { width: 1; height: 16 }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: "demo library, playback simulated: no audio backend yet (TODO)"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
        }

        PivotPage {
            title: "songs"
            Repeater {
                model: root.allTracks
                MetroListRow {
                    required property var modelData
                    required property int index
                    glyph: "music"
                    title: modelData.title
                    subtitle: root.rowSub(modelData)
                    trailing: root.fmt(modelData.dur)
                    onClicked: { root.playList(root.allTracks, index); pivot.goTo(0) }
                }
            }
            Item { width: 1; height: 8 }
            Text { visible: root.allTracks.length === 0; width: parent.width; wrapMode: Text.Wrap; text: "no music yet."; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22 }
            Text { visible: Sys.demoData; text: "demo library (offline)"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }

        PivotPage {
            title: "albums"
            Repeater {
                model: provider.groups("album")
                MetroListRow {
                    required property var modelData
                    glyph: "music"
                    title: modelData.name
                    subtitle: modelData.sub + " · " + modelData.count + " tracks"
                    onClicked: { root.drillKind = "album"; root.drillName = modelData.name }
                }
            }
        }

        PivotPage {
            title: "artists"
            Repeater {
                model: provider.groups("artist")
                MetroListRow {
                    required property var modelData
                    glyph: "people"
                    title: modelData.name
                    subtitle: modelData.count + " tracks"
                    onClicked: { root.drillKind = "artist"; root.drillName = modelData.name }
                }
            }
        }
    }

    // drill-down track list (album or artist)
    Item {
        id: drill
        anchors.fill: parent
        visible: root.drillKind !== ""
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }   // swallow touches
        Text {
            x: 18; y: root.topInset + 24
            text: root.drillKind.toUpperCase(); color: Theme.text
            font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
        }
        Text {
            id: dtitle
            x: 18; y: root.topInset + 52; width: parent.width - 36
            text: Theme.title(root.drillName); color: Theme.text; elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
        }
        ListView {
            id: dlist
            x: 18; y: dtitle.y + dtitle.height + 12
            width: parent.width - 36
            height: parent.height - y - dbar.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: root.drillTracks
            delegate: MetroListRow {
                required property var modelData
                required property int index
                width: dlist.width
                glyph: "music"
                title: modelData.title
                subtitle: root.drillKind === "album" ? modelData.artist : modelData.album
                trailing: root.fmt(modelData.dur)
                onClicked: { root.playList(root.drillTracks, index); root.drillKind = ""; pivot.goTo(0) }
            }
        }
        AppBar {
            id: dbar
            anchors.bottom: parent.bottom
            items: [{ glyph: "back", label: "back" }]
            onActivated: root.drillKind = ""
        }
    }

    focus: true
    function back() { if (root.drillKind !== "") root.drillKind = ""; else closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
