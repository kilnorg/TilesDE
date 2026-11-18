import QtQuick
import FlowShell

// Games: 2048, minesweeper, snake. High scores persisted under AppStore "games": {g2048, mines (best seconds), snake}.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property string game: ""             // "" | "2048" | "mines" | "snake"
    property string shown: ""            // last opened game (kept loaded while the overlay slides out)
    property var scores: ({})

    readonly property var defs: [
        { key: "2048", title: "2048", sub: "swipe to merge tiles" },
        { key: "mines", title: "minesweeper", sub: "9x9 · 10 mines · long-press to flag" },
        { key: "snake", title: "snake", sub: "swipe to turn · speeds up as you eat" }
    ]

    function back() {
        if (game !== "") { game = ""; return }
        closeRequested()
    }
    function open(k) { shown = k; game = k }
    function titleOf(k) { for (var i = 0; i < defs.length; ++i) if (defs[i].key === k) return defs[i].title; return "" }
    function fmtTime(s) { var m = Math.floor(s / 60), x = s % 60; return m + ":" + (x < 10 ? "0" : "") + x }
    function report(key, val) {
        var cur = scores[key]
        var better = cur === undefined || cur === null || (key === "mines" ? val < cur : val > cur)
        if (!better) return
        var s = {}
        for (var k in scores) s[k] = scores[k]
        s[key] = val
        scores = s
        AppStore.save("games", scores)
    }
    function resetScores() { scores = ({}); AppStore.save("games", scores) }

    Component.onCompleted: {
        var v = AppStore.load("games", {})
        scores = (v && typeof v === "object" && !Array.isArray(v)) ? v : ({})
    }

    // win / lose banner
    component Banner: Item {
        id: ban
        property string text: ""
        property string sub: ""
        signal again
        Rectangle { anchors.fill: parent; color: Theme.pageBg; opacity: 0.8 }
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent
            spacing: 10
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ban.text; color: Theme.accent
                font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ban.sub; color: Theme.textDim; visible: text !== ""
                font.family: Theme.font; font.pixelSize: 22
            }
            Item { width: 1; height: 8 }
            MetroButton { anchors.horizontalCenter: parent.horizontalCenter; text: "play again"; accentFill: true; onClicked: ban.again() }
        }
    }

    // ---------------------------------------------------------------- 2048
    Component {
        id: c2048
        Item {
            id: g
            property var cells: []
            property int score: 0
            property int best: root.scores.g2048 || 0
            property bool over: false
            property bool won: false
            property bool keepGoing: false
            readonly property real board: Math.max(120, Math.min(width - 36, height - 110))
            readonly property real gap: 8
            readonly property real tile: (board - gap * 5) / 4

            function idx(dir, r, k) {
                if (dir === 0) return r * 4 + k
                if (dir === 2) return r * 4 + (3 - k)
                if (dir === 1) return k * 4 + r
                return (3 - k) * 4 + r
            }
            function spawn(a) {
                var e = []
                for (var i = 0; i < 16; ++i) if (a[i] === 0) e.push(i)
                if (e.length === 0) return
                a[e[Math.floor(Math.random() * e.length)]] = Math.random() < 0.9 ? 2 : 4
            }
            function canMove(a) {
                for (var i = 0; i < 16; ++i) {
                    if (a[i] === 0) return true
                    var r = Math.floor(i / 4), c = i % 4
                    if (c < 3 && a[i] === a[i + 1]) return true
                    if (r < 3 && a[i] === a[i + 4]) return true
                }
                return false
            }
            function restart() {
                var a = []
                for (var i = 0; i < 16; ++i) a.push(0)
                spawn(a); spawn(a)
                cells = a; score = 0; over = false; won = false; keepGoing = false
            }
            function move(dir) {
                if (over || (won && !keepGoing)) return
                var a = cells.slice(), gained = 0, changed = false
                for (var r = 0; r < 4; ++r) {
                    var vals = []
                    for (var k = 0; k < 4; ++k) { var v = a[idx(dir, r, k)]; if (v > 0) vals.push(v) }
                    var out = []
                    for (var i = 0; i < vals.length; ++i) {
                        if (i + 1 < vals.length && vals[i] === vals[i + 1]) { out.push(vals[i] * 2); gained += vals[i] * 2; ++i }
                        else out.push(vals[i])
                    }
                    while (out.length < 4) out.push(0)
                    for (var j = 0; j < 4; ++j) {
                        var p = idx(dir, r, j)
                        if (a[p] !== out[j]) changed = true
                        a[p] = out[j]
                    }
                }
                if (!changed) return
                spawn(a)
                cells = a
                score += gained
                if (score > best) best = score
                if (gained > 0) root.report("g2048", score)
                if (!keepGoing && a.indexOf(2048) >= 0) won = true
                else if (!canMove(a)) over = true
            }
            function shade(v) {
                if (v <= 0) return Theme.dark ? "#1f1f1f" : "#dcdcdc"
                var lvl = Math.round(Math.log(v) / Math.LN2)
                var d = [0, 2.4, 2.0, 1.6, 1.3, 1.0]
                if (lvl <= 5) return Qt.darker(Theme.accent, d[lvl])
                return Qt.lighter(Theme.accent, Math.min(2.2, 1.0 + (lvl - 5) * 0.2))
            }
            Component.onCompleted: restart()

            Row {
                x: (g.width - g.board) / 2; y: 10
                spacing: 24
                Column {
                    Text { text: "score"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text { text: g.score; color: Theme.text; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
                }
                Column {
                    Text { text: "best"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text { text: g.best; color: Theme.accent; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
                }
            }
            Item {
                id: boardItem
                x: (g.width - g.board) / 2; y: 90
                width: g.board; height: g.board
                Rectangle { anchors.fill: parent; color: Theme.dark ? "#0d0d0d" : "#efefef"; border.width: 2; border.color: Theme.dark ? "#2a2a2a" : "#cfcfcf" }
                Repeater {
                    model: 16
                    Rectangle {
                        required property int index
                        readonly property int v: g.cells[index] || 0
                        x: g.gap + (index % 4) * (g.tile + g.gap)
                        y: g.gap + Math.floor(index / 4) * (g.tile + g.gap)
                        width: g.tile; height: g.tile
                        color: g.shade(v)
                        Text {
                            anchors.centerIn: parent; visible: parent.v > 0
                            text: parent.v
                            color: Theme.onColor(parent.color)
                            font.family: Theme.font; font.weight: Theme.fontLight
                            font.pixelSize: parent.v < 100 ? g.tile * 0.5 : (parent.v < 1000 ? g.tile * 0.4 : g.tile * 0.3)
                        }
                    }
                }
            }
            DragHandler {
                target: null
                property bool fired: false
                onActiveChanged: fired = false
                onTranslationChanged: {
                    if (!active || fired) return
                    var tx = translation.x, ty = translation.y
                    if (Math.max(Math.abs(tx), Math.abs(ty)) < 36) return
                    fired = true
                    g.move(Math.abs(tx) > Math.abs(ty) ? (tx > 0 ? 2 : 0) : (ty > 0 ? 3 : 1))
                }
            }
            Banner {
                anchors.fill: boardItem
                visible: g.over || (g.won && !g.keepGoing)
                text: g.over ? "game over" : "2048!"
                sub: "score " + g.score
                onAgain: g.restart()
            }
        }
    }

    // ---------------------------------------------------------------- minesweeper
    Component {
        id: cMines
        Item {
            id: m
            readonly property int n: 9
            readonly property int total: 10
            property var mine: []
            property var rev: []
            property var flag: []
            property var adj: []
            property string phase: "ready"      // ready | play | won | lost
            property int secs: 0
            property int flags: 0
            readonly property real cell: Math.floor(Math.max(30, Math.min(width - 24, height - 100)) / n)

            function nb(i) {
                var r = Math.floor(i / n), c = i % n, out = []
                for (var dr = -1; dr <= 1; ++dr)
                    for (var dc = -1; dc <= 1; ++dc) {
                        if (dr === 0 && dc === 0) continue
                        var rr = r + dr, cc = c + dc
                        if (rr >= 0 && rr < n && cc >= 0 && cc < n) out.push(rr * n + cc)
                    }
                return out
            }
            function restart() {
                var a = [], b = [], c = [], d = []
                for (var i = 0; i < n * n; ++i) { a.push(false); b.push(false); c.push(false); d.push(0) }
                mine = a; rev = b; flag = c; adj = d
                phase = "ready"; secs = 0; flags = 0
            }
            function place(first) {
                var safe = nb(first); safe.push(first)
                var mm = mine.slice(), placed = 0
                while (placed < total) {
                    var p = Math.floor(Math.random() * n * n)
                    if (mm[p] || safe.indexOf(p) >= 0) continue
                    mm[p] = true; ++placed
                }
                var ad = []
                for (var i = 0; i < n * n; ++i) {
                    var cnt = 0, l = nb(i)
                    for (var j = 0; j < l.length; ++j) if (mm[l[j]]) ++cnt
                    ad.push(cnt)
                }
                mine = mm; adj = ad
            }
            function reveal(i) {
                if (phase === "won" || phase === "lost" || rev[i] || flag[i]) return
                if (phase === "ready") { place(i); phase = "play" }
                var rv = rev.slice()
                if (mine[i]) {
                    for (var k = 0; k < n * n; ++k) if (mine[k]) rv[k] = true
                    rev = rv; phase = "lost"
                    return
                }
                var stack = [i]
                while (stack.length > 0) {
                    var cur = stack.pop()
                    if (rv[cur] || flag[cur]) continue
                    rv[cur] = true
                    if (adj[cur] === 0) {
                        var l = nb(cur)
                        for (var j = 0; j < l.length; ++j) if (!rv[l[j]]) stack.push(l[j])
                    }
                }
                rev = rv
                var cnt = 0
                for (var q = 0; q < n * n; ++q) if (rv[q]) ++cnt
                if (cnt === n * n - total) {
                    phase = "won"
                    var fl = flag.slice()
                    for (var z = 0; z < n * n; ++z) if (mine[z]) fl[z] = true
                    flag = fl; flags = total
                    root.report("mines", secs)
                }
            }
            function toggleFlag(i) {
                if (phase === "won" || phase === "lost" || rev[i]) return
                var fl = flag.slice()
                fl[i] = !fl[i]
                flag = fl
                var c = 0
                for (var k = 0; k < n * n; ++k) if (fl[k]) ++c
                flags = c
            }
            Component.onCompleted: restart()
            Timer { interval: 1000; repeat: true; running: m.phase === "play"; onTriggered: m.secs++ }

            Row {
                x: (m.width - m.cell * m.n) / 2; y: 10
                spacing: 24
                Column {
                    Text { text: "mines"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text { text: m.total - m.flags; color: Theme.text; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
                }
                Column {
                    Text { text: "time"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text { text: root.fmtTime(m.secs); color: Theme.accent; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
                }
                Column {
                    Text { text: "best"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text {
                        text: root.scores.mines !== undefined ? root.fmtTime(root.scores.mines) : "-"
                        color: Theme.text; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight
                    }
                }
            }
            Item {
                id: boardItem
                x: (m.width - m.cell * m.n) / 2; y: 90
                width: m.cell * m.n; height: width
                Repeater {
                    model: m.n * m.n
                    Rectangle {
                        required property int index
                        readonly property bool isRev: m.rev[index] === true
                        readonly property bool isMine: m.mine[index] === true
                        x: (index % m.n) * m.cell
                        y: Math.floor(index / m.n) * m.cell
                        width: m.cell - 2; height: m.cell - 2
                        color: isRev ? (isMine ? Theme.accent : (Theme.dark ? "#141414" : "#ececec"))
                                     : (Theme.dark ? "#3a3a3a" : "#bdbdbd")
                        opacity: area.pressed && !isRev ? 0.7 : 1
                        Text {
                            anchors.centerIn: parent
                            visible: parent.isRev && !parent.isMine && m.adj[parent.index] > 0
                            text: m.adj[parent.index]
                            color: Theme.accent
                            font.family: Theme.font; font.pixelSize: m.cell * 0.55
                        }
                        Rectangle {   // flag marker
                            anchors.centerIn: parent
                            visible: !parent.isRev && m.flag[parent.index] === true
                            width: m.cell * 0.4; height: width; color: Theme.accent
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: parent.isRev && parent.isMine
                            text: "*"; color: Theme.onColor(Theme.accent)
                            font.family: Theme.font; font.pixelSize: m.cell * 0.7
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            onClicked: m.reveal(parent.index)
                            onPressAndHold: m.toggleFlag(parent.index)
                        }
                    }
                }
            }
            Text {
                x: boardItem.x; y: boardItem.y + boardItem.height + 12
                width: boardItem.width; wrapMode: Text.Wrap
                text: "tap to reveal · long-press to flag · first tap is always safe"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16
            }
            Banner {
                anchors.fill: boardItem
                visible: m.phase === "won" || m.phase === "lost"
                text: m.phase === "won" ? "you win" : "boom"
                sub: m.phase === "won" ? "time " + root.fmtTime(m.secs) : ""
                onAgain: m.restart()
            }
        }
    }

    // ---------------------------------------------------------------- snake
    Component {
        id: cSnake
        Item {
            id: s
            readonly property int cols: 16
            readonly property int rows: 20
            readonly property real cell: Math.floor(Math.max(10, Math.min((width - 24) / cols, (height - 90) / rows)))
            property var body: []
            property var food: ({ x: 0, y: 0 })
            property int dx: 1
            property int dy: 0
            property int ndx: 1
            property int ndy: 0
            property int score: 0
            property int best: root.scores.snake || 0
            property string phase: "ready"      // ready | play | over

            function placeFood() {
                var free = []
                for (var y = 0; y < rows; ++y)
                    for (var x = 0; x < cols; ++x) {
                        var hit = false
                        for (var i = 0; i < body.length; ++i) if (body[i].x === x && body[i].y === y) { hit = true; break }
                        if (!hit) free.push({ x: x, y: y })
                    }
                if (free.length === 0) { phase = "over"; return }
                food = free[Math.floor(Math.random() * free.length)]
            }
            function restart() {
                body = [{ x: 8, y: 10 }, { x: 7, y: 10 }, { x: 6, y: 10 }]
                dx = 1; dy = 0; ndx = 1; ndy = 0
                score = 0; phase = "ready"
                placeFood()
            }
            function turn(ax, ay) {
                if (phase === "over") return
                if ((ax !== 0 && dx !== 0) || (ay !== 0 && dy !== 0)) {
                    if (phase === "ready") phase = "play"   // same axis as current heading: just start
                    return
                }
                ndx = ax; ndy = ay
                if (phase === "ready") phase = "play"
            }
            function tick() {
                dx = ndx; dy = ndy
                var hx = body[0].x + dx, hy = body[0].y + dy
                if (hx < 0 || hy < 0 || hx >= cols || hy >= rows) { die(); return }
                var ate = hx === food.x && hy === food.y
                var limit = ate ? body.length : body.length - 1
                for (var i = 0; i < limit; ++i) if (body[i].x === hx && body[i].y === hy) { die(); return }
                var nbody = [{ x: hx, y: hy }].concat(ate ? body : body.slice(0, body.length - 1))
                body = nbody
                if (ate) {
                    score += 1
                    if (score > best) best = score
                    placeFood()
                }
            }
            function die() {
                phase = "over"
                root.report("snake", score)
            }
            Component.onCompleted: restart()
            Timer {
                interval: Math.max(60, 180 - s.score * 6)
                repeat: true; running: s.phase === "play"
                onTriggered: s.tick()
            }

            Row {
                x: (s.width - s.cell * s.cols) / 2; y: 10
                spacing: 24
                Column {
                    Text { text: "score"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text { text: s.score; color: Theme.text; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
                }
                Column {
                    Text { text: "best"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                    Text { text: s.best; color: Theme.accent; font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
                }
            }
            Item {
                id: boardItem
                x: (s.width - s.cell * s.cols) / 2; y: 76
                width: s.cell * s.cols; height: s.cell * s.rows
                Rectangle { anchors.fill: parent; color: Theme.dark ? "#0d0d0d" : "#efefef"; border.width: 2; border.color: Theme.dark ? "#2a2a2a" : "#cfcfcf" }
                Rectangle {
                    x: s.food.x * s.cell + 1; y: s.food.y * s.cell + 1
                    width: s.cell - 2; height: s.cell - 2
                    color: Theme.text
                }
                Repeater {
                    model: s.body
                    Rectangle {
                        required property int index
                        required property var modelData
                        x: modelData.x * s.cell + 1; y: modelData.y * s.cell + 1
                        width: s.cell - 2; height: s.cell - 2
                        color: index === 0 ? Qt.lighter(Theme.accent, 1.4) : Theme.accent
                    }
                }
                Text {
                    anchors.centerIn: parent; visible: s.phase === "ready"
                    text: "swipe to start"; color: Theme.textDim
                    font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                }
            }
            DragHandler {
                target: null
                property bool fired: false
                onActiveChanged: fired = false
                onTranslationChanged: {
                    if (!active || fired) return
                    var tx = translation.x, ty = translation.y
                    if (Math.max(Math.abs(tx), Math.abs(ty)) < 28) return
                    fired = true
                    if (Math.abs(tx) > Math.abs(ty)) s.turn(tx > 0 ? 1 : -1, 0)
                    else s.turn(0, ty > 0 ? 1 : -1)
                }
            }
            Banner {
                anchors.fill: boardItem
                visible: s.phase === "over"
                text: "game over"
                sub: "score " + s.score
                onAgain: s.restart()
            }
        }
    }

    // ---------------------------------------------------------------- pivot
    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    Pivot {
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "games"

        PivotPage {
            title: "play"
            Repeater {
                model: root.defs
                MetroListRow {
                    required property var modelData
                    title: modelData.title
                    subtitle: modelData.sub
                    onClicked: root.open(modelData.key)
                }
            }
        }
        PivotPage {
            title: "scores"
            MetroListRow {
                title: "2048"
                subtitle: root.scores.g2048 !== undefined ? "best score " + root.scores.g2048 : "no score yet"
            }
            MetroListRow {
                title: "minesweeper"
                subtitle: root.scores.mines !== undefined ? "best time " + root.fmtTime(root.scores.mines) : "no win yet"
            }
            MetroListRow {
                title: "snake"
                subtitle: root.scores.snake !== undefined ? "best score " + root.scores.snake : "no score yet"
            }
            Item { width: 1; height: 16 }
            MetroButton { text: "reset scores"; onClicked: root.resetScores() }
        }
    }

    // full-screen game view; slides in from the right
    Item {
        id: overlay
        property real p: root.game !== "" ? 1 : 0
        Behavior on p { enabled: !Theme.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        visible: p > 0.001
        x: (1 - p) * root.width
        y: root.topInset
        width: root.width
        height: root.height - root.topInset

        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }

        Item {
            id: bar
            width: parent.width; height: 72
            Item {
                id: backBtn
                width: 64; height: 72
                opacity: backArea.pressed ? 0.5 : 1
                Canvas {
                    width: 16; height: 28; x: 24; anchors.verticalCenter: parent.verticalCenter
                    property color ink: Theme.text
                    onInkChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d"); c.clearRect(0, 0, width, height)
                        c.strokeStyle = ink; c.lineWidth = 3
                        c.beginPath(); c.moveTo(14, 2); c.lineTo(3, 14); c.lineTo(14, 26); c.stroke()
                    }
                }
                MouseArea { id: backArea; anchors.fill: parent; onClicked: root.back() }
            }
            Text {
                x: 64; anchors.verticalCenter: parent.verticalCenter
                text: root.titleOf(root.shown)
                color: Theme.text; font.family: Theme.font; font.pixelSize: 40; font.weight: Theme.fontLight
            }
            MetroButton {
                anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                text: "restart"
                onClicked: if (gameLoader.item) gameLoader.item.restart()
            }
        }
        Loader {
            id: gameLoader
            y: bar.height
            width: parent.width; height: parent.height - bar.height
            active: root.game !== "" || overlay.p > 0.001
            sourceComponent: root.shown === "2048" ? c2048 : (root.shown === "mines" ? cMines : (root.shown === "snake" ? cSnake : null))
        }
    }
}
