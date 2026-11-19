import QtQuick
import FlowShell
import "TilePresets.js" as TilePresets

// TilesDE Start page: named tile groups (Glaze style headings, collapsible) over a 3 or 4 column grid.
// Tiles come from TilePresets.defaultTiles(); fill = Theme.tileColor(id, colorIdx) (per-tile override or palette),
// opacity/radius/gap/columns/labels/badges/flip speed/grain all follow Theme + Personalise live.
// Faces: TileFaces (calendar, photo, contact, missed call, text), only from real data (LiveTiles: calendar/mail/messages/
// reminders/clock/people/photos). A tile without data shows the plain front (glyph + label) and does not flip. Picture tiles
// show a real photo (LiveTiles / Theme.startPhoto) or none. Edit mode (long press): tiles shrink, unpin (x) + resize buttons, drag to reorder (also across
// groups), drag the corner arrow to resize (snaps to s/m/w/l, neighbours reflow live; tap it to cycle), tap a tile to open the colour sheet (12 swatches, size, photo, unpin), headings become editable.
// Tap background / exitEdit() leaves. Pull-down at the top is NOT handled here (Action Centre).
Item {
    id: root

    // ---- public API ----
    signal launched(string name, rect r, bool real)
    signal appsRequested()
    property bool editing: false
    property real pagerP: 0                    // 0 = start page, 1 = all apps (drives the tile fly-out)
    property int topInset: 28                  // status bar
    property int bottomInset: 56               // nav bar
    property bool flipsOn: true                // host can pause live flips
    readonly property bool exiting: _exiting
    property alias model: tileModel
    readonly property string selectedId: _selId   // tile open in the colour sheet ("" = none)
    function enterEdit() {
        if (editing) return
        editing = true
        _editAt = Date.now()
    }
    function exitEdit() { editing = false; dragIndex = -1; _selId = ""; refreshSel() }
    function playEnter() { _exiting = false; enterRequested() }
    function playExit() { _exiting = true; exitRequested() }
    // rapid open/close: tiles snap straight back, no lay-down animation
    property string heroTid: ""          // tile the open app came from: it returns first, so the closing app lands on a visible tile
    signal snapRequested
    function snapEnter() { _exiting = false; snapRequested() }
    function indexOfId(tid) { for (let i = 0; i < tileModel.count; i++) if (tileModel.get(i).tid === tid) return i; return -1 }
    function unpin(i) { if (i >= 0 && i < tileModel.count) { if (tileModel.get(i).tid === _selId) { _selId = ""; refreshSel() } tileModel.remove(i) } }
    // returns false when the app is already pinned
    function pinApp(name, glyph) {
        for (let i = 0; i < tileModel.count; i++) if (tileModel.get(i).name === name) return false
        const g = glyph && glyph !== "" ? glyph : (glyphs.indexOf(name.toLowerCase()) >= 0 ? name.toLowerCase() : "grid")
        const gs = Theme.groups
        const grp = gs && gs.length ? gs[gs.length - 1].name : ""
        tileModel.append(mkRow({ id: name.toLowerCase().replace(/\s+/g, "-"), label: name, glyph: g, size: "medium", group: grp,
                                 color: tileModel.count, live: false, picture: false, badge: 0 }))
        Qt.callLater(function() { root.scrollTo(Math.max(-flick.topMargin, flick.contentHeight - flick.height + flick.bottomMargin)) })
        return true
    }
    function scrollTo(y) {
        scrollAnim.stop()
        if (Theme.reduceMotion) { flick.contentY = y; return }
        scrollAnim.to = y
        scrollAnim.start()
    }
    function scrollTop() { scrollTo(-flick.topMargin) }
    function resize(i) {
        if (i < 0 || i >= tileModel.count) return
        const s = tileModel.get(i).size
        tileModel.setProperty(i, "size", s === "small" ? "medium" : (s === "medium" ? "wide" : (s === "wide" ? "large" : "small")))
    }
    function unitPx() { return Theme.tileUnit(width) }
    // nearest grid size to a pixel size (w, h)
    function snapSize(w, h) {
        const names = ["small", "medium", "wide", "large"]
        let best = "small", bd = 1e12
        for (let k = 0; k < names.length; k++) {
            const dw = w - Theme.tileW(names[k], width), dh = h - Theme.tileH(names[k], width), d = dw * dw + dh * dh
            if (d < bd) { bd = d; best = names[k] }
        }
        return best
    }
    function setSize(i, sz) { if (i >= 0 && i < tileModel.count && ["small", "medium", "wide", "large"].indexOf(sz) >= 0) tileModel.setProperty(i, "size", sz) }
    // open the colour sheet for a tile id (enters edit mode first); "" closes it
    function selectTile(tid) {
        if (tid === "") { _selId = ""; refreshSel(); return true }
        if (indexOfId(tid) < 0) return false
        enterEdit()
        _selId = tid
        refreshSel()
        return true
    }
    // socket helper: select <id> | tilesize <id>=<size> | unpintile <id> | tilepicture <id>=on|off | tilelabel <id>=<text> | closesheet
    function command(k, v) {
        const s = String(v), eq = s.indexOf("=")
        const id = eq >= 0 ? s.substring(0, eq) : s, val = eq >= 0 ? s.substring(eq + 1) : ""
        if (k === "select") return selectTile(id)
        if (k === "closesheet") return selectTile("")
        const i = indexOfId(id)
        if (i < 0) return false
        if (k === "tilesize") { if (["small", "medium", "wide", "large"].indexOf(val) < 0) return false; setSize(i, val); return true }
        if (k === "unpintile") { unpin(i); return true }
        if (k === "tilepicture") { tileModel.setProperty(i, "picture", val === "on" || val === "1" || val === "true"); return true }
        if (k === "tilelabel") { tileModel.setProperty(i, "label", val); return true }
        return false
    }

    // ---- internals ----
    property bool _exiting: false
    property double _editAt: 0
    property string _selId: ""
    property var selRow: null                  // plain copy of the selected model row (for the sheet bindings)
    property int dragIndex: -1
    property bool resizingNow: false
    property var dragCell: null
    property point dragVp: Qt.point(0, 0)      // pointer in viewport coords
    property point dragGrab: Qt.point(0, 0)    // pointer offset from tile centre
    property double _lastMove: 0
    property var layout: []
    property var heads: []                     // [{name, gi, y, collapsed, count}]
    property real rowsHeight: 0
    readonly property int headH: 36
    signal enterRequested()
    signal exitRequested()

    readonly property var glyphs: ["phone", "message", "mail", "calendar", "clock", "photos", "music", "maps", "notes", "files", "weather",
        "terminal", "store", "camera", "settings", "people", "browser", "wallet", "noxal", "video"]

    // A face exists only for real data from LiveTiles. No data (or nothing worth showing) = plain front, no flip.
    function hasLive(id, lt) {
        if (!lt) return false
        switch (id) {
        case "calendar": return true                       // today's date is always real
        case "clock": return lt.subtitle !== ""            // only with a real alarm
        case "photos": return lt.imageSource !== ""
        case "people": return lt.title !== ""
        default: return lt.badge > 0 || lt.big !== ""
        }
    }
    function faceFor(id) {
        const d = new Date(), lt = LiveTiles.get(id), none = { face: "text", big: "", line1: "", line2: "", img: "" }
        if (!hasLive(id, lt)) return none
        const big = lt.big !== "" ? lt.big : (lt.badge > 0 ? String(lt.badge) : "")
        switch (id) {
        case "calendar": return { face: "calendar", big: Qt.formatDate(d, "d"), line1: Qt.formatDate(d, "dddd"), line2: lt.title === "" ? "No upcoming events" : lt.title + ", " + lt.subtitle, img: "" }
        case "photos": return { face: "photo", big: "", line1: lt.title, line2: lt.subtitle, img: lt.imageSource }
        case "people": return { face: "contact", big: "", line1: lt.title, line2: lt.subtitle, img: "" }
        default: return { face: "text", big: big, line1: lt.title, line2: lt.subtitle, img: lt.imageSource }
        }
    }
    // push fresh LiveTiles data into the existing rows
    // (only touches rows whose face data changed; faces never affect the layout, so no relayout per row)
    property bool _faceBatch: false
    function refreshFaces() {
        _faceBatch = true
        for (let i = 0; i < tileModel.count; i++) {
            const r = tileModel.get(i), lt = LiveTiles.get(r.tid), f = faceFor(r.tid), hd = hasLive(r.tid, lt), bd = lt ? lt.badge : 0
            if (r.face !== f.face || r.big !== f.big || r.line1 !== f.line1 || r.line2 !== f.line2 || r.img !== f.img || r.hasData !== hd || r.badge !== bd)
                tileModel.set(i, { face: f.face, big: f.big, line1: f.line1, line2: f.line2, img: f.img, hasData: hd, badge: bd })
        }
        _faceBatch = false
    }
    Connections { target: LiveTiles; function onChanged() { root.refreshFaces() } }
    // every row carries the same roles (ListModel requirement)
    function mkRow(t) {
        const f = faceFor(t.id), lt = LiveTiles.get(t.id)
        return { tid: t.id, name: t.label, label: t.label, glyph: t.glyph, size: t.size, group: t.group || "", colorIdx: t.color | 0,
                 live: !!t.live, picture: !!t.picture, badge: lt ? lt.badge : 0, face: f.face, big: f.big, line1: f.line1, line2: f.line2, img: f.img, hasData: hasLive(t.id, lt) }
    }

    function refreshSel() {
        const i = _selId === "" ? -1 : indexOfId(_selId)
        if (i < 0) { selRow = null; if (_selId !== "") _selId = ""; return }
        const r = tileModel.get(i)
        selRow = { index: i, tid: r.tid, label: r.label, size: r.size, picture: r.picture, group: r.group }
    }

    ListModel { id: tileModel }

    Component.onCompleted: {
        const t = TilePresets.defaultTiles()
        for (let i = 0; i < t.length; i++) tileModel.append(mkRow(t[i]))
        computeLayout()
    }

    function cellsOf(sz) {
        const c = Theme.tileCols
        return sz === "small" ? [1, 1] : (sz === "medium" ? [2, 2] : (sz === "wide" ? [c, 2] : [c, c]))
    }
    // first-fit packing per group on a Theme.tileCols occupancy grid; group headings between sections
    function computeLayout() {
        if (width <= 0) return
        const cols = Theme.tileCols, u = Theme.tileUnit(width), g = Theme.tileGap, m = Theme.pageMargin
        const gs = Theme.groups || []
        const names = [""]
        for (let s = 0; s < gs.length; s++) names.push(gs[s].name)
        const buckets = []
        for (let s = 0; s < names.length; s++) buckets.push([])
        for (let i = 0; i < tileModel.count; i++) {
            let k = names.indexOf(tileModel.get(i).group)
            if (k < 0) k = 0
            buckets[k].push(i)
        }
        const out = new Array(tileModel.count), hd = []
        let y = 0
        for (let s = 0; s < names.length; s++) {
            const collapsed = s > 0 && !!gs[s - 1].collapsed
            if (s > 0) {
                if (y > 0) y += 12
                hd.push({ name: names[s], gi: s - 1, y: y, collapsed: collapsed, count: buckets[s].length })
                y += headH + 2
            }
            const occ = []
            function free(r, c, cw, ch) {
                for (let rr = r; rr < r + ch; rr++)
                    for (let cc = c; cc < c + cw; cc++) if (occ[rr] && occ[rr][cc]) return false
                return true
            }
            let rows = 0
            const list = buckets[s]
            for (let n = 0; n < list.length; n++) {
                const i = list[n], sz = tileModel.get(i).size
                const cs = cellsOf(sz), cw = cs[0], ch = cs[1]
                let done = false
                for (let r = 0; !done; r++) {
                    for (let c = 0; c <= cols - cw && !done; c++) {
                        if (!free(r, c, cw, ch)) continue
                        for (let rr = r; rr < r + ch; rr++) {
                            if (!occ[rr]) { occ[rr] = []; for (let q = 0; q < cols; q++) occ[rr].push(false) }
                            for (let cc = c; cc < c + cw; cc++) occ[rr][cc] = true
                        }
                        const ty = collapsed ? y : y + r * (u + g)
                        out[i] = { x: m + c * (u + g), y: ty, w: Theme.tileW(sz, width), h: Theme.tileH(sz, width),
                                   row: Math.round(ty / (u + g)), col: c, hidden: collapsed, sec: s }
                        rows = Math.max(rows, r + ch)
                        done = true
                    }
                }
            }
            if (!collapsed) y += rows * (u + g)
        }
        rowsHeight = y
        heads = hd
        layout = out
        refreshSel()
    }
    onWidthChanged: computeLayout()
    Connections {
        target: tileModel
        function onRowsInserted() { root.computeLayout() }
        function onRowsRemoved() { root.computeLayout() }
        function onRowsMoved() { root.computeLayout() }
        function onDataChanged() { if (!root._faceBatch) root.computeLayout() }
    }
    Connections {
        target: Theme
        function onTileColsChanged() { root.computeLayout() }
        function onTileGapChanged() { root.computeLayout() }
        function onGroupsChanged() { root.computeLayout() }
    }

    function renameGroup(gi, oldName, newName) {
        Personalise.renameGroup(gi, newName)
        for (let i = 0; i < tileModel.count; i++) if (tileModel.get(i).group === oldName) tileModel.setProperty(i, "group", newName)
    }

    function updateDrag() {
        const c = root.dragCell
        if (!c || root.dragIndex < 0) return
        const cx = root.dragVp.x - root.dragGrab.x
        const cy = root.dragVp.y + flick.contentY - root.dragGrab.y
        c.dragX = cx - c.width / 2
        c.dragY = cy - c.height / 2
        const now = Date.now()
        if (now - root._lastMove < 160) return
        for (let j = 0; j < root.layout.length; j++) {
            if (j === root.dragIndex) continue
            const lay = root.layout[j]
            if (!lay || lay.hidden) continue
            if (cx > lay.x + lay.w * 0.2 && cx < lay.x + lay.w * 0.8 && cy > lay.y + lay.h * 0.2 && cy < lay.y + lay.h * 0.8) {
                const from = root.dragIndex
                tileModel.setProperty(from, "group", tileModel.get(j).group)
                tileModel.move(from, j, 1)
                root.dragIndex = j
                root._lastMove = now
                return
            }
        }
        // dropped on a group heading: join that group (top block when above the first heading)
        for (let h = 0; h < root.heads.length; h++) {
            const hd = root.heads[h]
            if (cy > hd.y && cy < hd.y + root.headH) {
                if (tileModel.get(root.dragIndex).group !== hd.name) { tileModel.setProperty(root.dragIndex, "group", hd.name); root._lastMove = now }
                return
            }
        }
    }
    Timer {
        interval: 16; repeat: true; running: root.dragIndex >= 0
        onTriggered: {
            const y = root.dragVp.y
            let d = 0
            if (y < root.topInset + 80) d = -10
            else if (y > flick.height - root.bottomInset - 60) d = 10
            if (d !== 0) {
                const lo = -flick.topMargin
                const hi = Math.max(lo, flick.contentHeight - flick.height + flick.bottomMargin)
                flick.contentY = Math.max(lo, Math.min(hi, flick.contentY + d))
                root.updateDrag()
            }
        }
    }

    // ---- background: page colour, optional wallpaper (tiles over wallpaper), procedural paper grain ----
    Rectangle { anchors.fill: parent; color: Theme.pageBg }
    Item {
        anchors.fill: parent
        visible: Theme.tilesOverWallpaper
        TileFaces { anchors.fill: parent; face: "scene"; seed: 7 }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 }
    }
    Canvas {
        id: grainCv
        anchors.fill: parent
        visible: Theme.grain > 0.01
        opacity: Math.min(1, Theme.grain) * 0.55
        property bool lightBg: !Theme.dark
        onLightBgChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width < 2 || height < 2) return
            const n = Math.round(width * height * 0.012)
            let s = 12345
            for (let i = 0; i < n; i++) {
                s = (s * 1103515245 + 12345) & 0x7fffffff
                const x = s % Math.floor(width)
                s = (s * 1103515245 + 12345) & 0x7fffffff
                const y = s % Math.floor(height)
                s = (s * 1103515245 + 12345) & 0x7fffffff
                const a = 0.15 + (s % 100) / 100 * 0.55
                ctx.fillStyle = (s & 1024) ? "rgba(255,255,255," + a.toFixed(2) + ")" : "rgba(0,0,0," + a.toFixed(2) + ")"
                ctx.fillRect(x, y, 1, 1)
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        topMargin: root.topInset + 2
        bottomMargin: root.bottomInset + (root.selRow ? sheet.height : 0)
        contentWidth: width
        contentHeight: content.height
        interactive: root.dragIndex < 0 && !root.resizingNow
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Component.onCompleted: contentY = -topMargin
        onMovingChanged: Theme.scrollTick++
        NumberAnimation { id: scrollAnim; target: flick; property: "contentY"; duration: 320; easing.type: Easing.InOutCubic }

        Item {
            id: content
            width: flick.width
            height: root.rowsHeight + 8 + 64 + (root.editing ? 48 : 0)

            // background tap leaves edit mode
            MouseArea {
                anchors.fill: parent; z: -1
                onClicked: if (root.editing) root.exitEdit()
            }

            // group headings
            Repeater {
                model: root.heads
                delegate: TileGroupHeader {
                    required property var modelData
                    x: Theme.pageMargin; y: modelData.y
                    Behavior on y { enabled: !Theme.reduceMotion; NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    width: content.width - 2 * Theme.pageMargin
                    height: root.headH
                    text: modelData.name
                    collapsed: modelData.collapsed
                    count: modelData.count
                    editing: root.editing
                    opacity: Math.max(0, 1 - root.pagerP * 2)
                    visible: opacity > 0.01
                    onToggled: Personalise.toggleGroup(modelData.gi)
                    onRenamed: (n) => root.renameGroup(modelData.gi, modelData.name, n)
                    onRemoveRequested: Personalise.removeGroup(modelData.gi)
                }
            }

            Repeater {
                model: tileModel
                delegate: Item {
                    id: cell
                    required property int index
                    required property string tid
                    required property string name
                    required property string label
                    required property string glyph
                    required property string size
                    required property string group
                    required property int colorIdx
                    required property bool live
                    required property bool picture
                    required property int badge
                    required property string face
                    required property string big
                    required property string line1
                    required property string line2
                    required property string img
                    required property bool hasData

                    readonly property var lay: (root.layout.length > index) ? root.layout[index] : null
                    // fill colour is cached and re-synced imperatively: a colour pick repaints only the tile whose colour changed
                    // (a binding on Personalise.tileColors would re-evaluate and repaint all tiles)
                    property color fillC: "transparent"
                    function syncColour() { const c = Theme.tileColor(cell.tid, cell.colorIdx); if (c.toString() !== cell.fillC.toString()) cell.fillC = c }
                    onColorIdxChanged: syncColour()
                    Connections { target: Personalise; function onTileColorsChanged() { cell.syncColour() } }
                    Connections { target: Theme; function onTilePaletteChanged() { cell.syncColour() } }
                    readonly property bool liveOn: cell.hasData && cell.size !== "small"
                    readonly property string photoPath: cell.img !== "" ? cell.img : Theme.startPhoto
                    readonly property bool hasPhoto: cell.picture && photoPath !== "" && (photoPath.indexOf("://") >= 0 || photoPath.indexOf("qrc:") === 0 || (typeof Sys !== "undefined" && Sys.exists(photoPath)))
                    property bool resizing: false
                    property real rw: 0
                    property real rh: 0
                    property bool dragging: false
                    property real dragX: 0
                    property real dragY: 0
                    property real enterP: 0
                    property bool held: false
                    property bool dMoved: false
                    property point dPress: Qt.point(0, 0)
                    function dragStep(mx, my, src) {
                        const vp = src.mapToItem(flick.parent, mx, my)
                        if (!dMoved) {
                            if (Math.abs(mx - dPress.x) + Math.abs(my - dPress.y) < 12) return
                            dMoved = true
                            const p0 = src.mapToItem(content, dPress.x, dPress.y)
                            root.dragGrab = Qt.point(p0.x - (cell.x + cell.width / 2), p0.y - (cell.y + cell.height / 2))
                            cell.dragX = cell.x; cell.dragY = cell.y
                            cell.dragging = true
                            root.dragCell = cell
                            root.dragIndex = cell.index
                        }
                        root.dragVp = Qt.point(vp.x, vp.y)
                        root.dragIndex = cell.index
                        root.updateDrag()
                    }
                    function dragFinish() {
                        if (dMoved) { cell.dragging = false; root.dragIndex = -1; root.dragCell = null }
                        dMoved = false
                    }
                    Connections {
                        target: tile.mouse
                        function onPositionChanged(m) { if (cell.held && root.editing && tile.mouse.pressed) cell.dragStep(m.x, m.y, tile.mouse) }
                        function onReleased() { if (cell.held) { cell.held = false; cell.dragFinish() } }
                        function onCanceled() { if (cell.held) { cell.held = false; cell.dragFinish() } }
                    }
                    readonly property real stag: lay ? Math.min(0.5, lay.row * 0.08 + lay.col * 0.04) : 0
                    readonly property real pagerAng: Math.max(0, Math.min(1, root.pagerP * 1.5 - stag)) * 90
                    readonly property real turn: -((1 - enterP) * 90 + pagerAng)

                    x: dragging ? dragX : (lay ? lay.x : 0)
                    y: dragging ? dragY : (lay ? lay.y : 0)
                    width: resizing ? rw : (lay ? lay.w : 0)
                    height: resizing ? rh : (lay ? lay.h : 0)
                    // collapse / expand: tiles tuck under their group heading while fading, then the groups below glide up
                    property real showP: (lay !== null && !lay.hidden) ? 1 : 0
                    Behavior on showP { enabled: !Theme.reduceMotion && cell.enterP >= 1; NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    opacity: showP
                    visible: lay !== null && showP > 0.01 && Math.abs(turn) < 89.5
                    z: dragging ? 10 : 0
                    transformOrigin: Item.Center
                    scale: (root.editing ? (dragging ? 1.04 : 0.88) : 1) * (0.9 + 0.1 * showP)
                    Behavior on x { enabled: !cell.dragging && !Theme.reduceMotion && cell.enterP >= 1; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !cell.dragging && !Theme.reduceMotion && cell.enterP >= 1; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: !Theme.reduceMotion && cell.enterP >= 1 && !cell.resizing; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: !Theme.reduceMotion && cell.enterP >= 1 && !cell.resizing; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Rotation {
                        origin.x: -cell.x; origin.y: cell.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: cell.turn
                    }

                    function playIn() {
                        if (Theme.reduceMotion) { enterP = 1; return }
                        enterAnim.stop(); exitAnim.stop()
                        if (enterP >= 0.999) enterP = 0     // replay; otherwise turn back from wherever the exit got to
                        enterAnim.restart()
                    }
                    function playOut() {
                        if (Theme.reduceMotion) { enterP = 0; return }
                        enterAnim.stop()
                        exitAnim.restart()
                    }
                    Component.onCompleted: { syncColour(); playIn() }
                    Connections {
                        target: root
                        function onEnterRequested() { cell.playIn() }
                        function onExitRequested() { cell.playOut() }
                        function onSnapRequested() { enterAnim.stop(); exitAnim.stop(); cell.enterP = 1 }
                    }
                    SequentialAnimation {
                        id: enterAnim
                        PauseAnimation { duration: cell.tid === root.heroTid ? 0 : (cell.lay ? Math.min(260, cell.lay.row * 40 + cell.lay.col * 20) : 0) + (root.heroTid !== "" ? 50 : 0) }
                        NumberAnimation { target: cell; property: "enterP"; to: 1; duration: cell.tid === root.heroTid ? Theme.turnstileMs * 0.7 : Theme.turnstileMs + 80; easing.type: Easing.OutCubic }
                    }
                    SequentialAnimation {
                        id: exitAnim
                        PauseAnimation { duration: cell.lay ? Math.min(400, cell.lay.row * 45 + cell.lay.col * 25) : 0 }
                        NumberAnimation { target: cell; property: "enterP"; to: 0; duration: Theme.turnstileMs; easing.type: Easing.InCubic }
                    }

                    MetroTile {
                        id: tile
                        anchors.fill: parent
                        size: cell.size
                        label: cell.label
                        glyph: cell.glyph
                        live: cell.liveOn
                        accent: cell.fillC
                        picture: cell.hasPhoto
                        index: cell.index
                        screenW: root.width
                        flat: root.editing
                        flipEnabled: root.flipsOn && !root.editing && !root._exiting && cell.enterP >= 1
                        glyphScale: cell.hasPhoto ? 0.8 : 1
                        onClicked: (r) => {
                            if (root.editing || Date.now() - root._editAt < 400) return
                            root.heroTid = cell.tid
                            root.launched(cell.name, r, false)
                            root.playExit()
                        }
                        onPressAndHold: {
                            // hand the held press to the drag logic so hold-then-drag is one gesture
                            cell.held = true
                            cell.dMoved = false
                            cell.dPress = Qt.point(tile.mouse.mouseX, tile.mouse.mouseY)
                            root.enterEdit()
                        }

                        // picture layer (photo tiles): a real photo (LiveTiles / Theme.startPhoto) under the glyph, else nothing
                        frontLayer: [
                            Image {
                                readonly property string p: cell.photoPath
                                anchors.fill: parent
                                visible: cell.hasPhoto && status === Image.Ready
                                source: cell.hasPhoto ? (p.indexOf("://") >= 0 || p.indexOf("qrc:") === 0 ? p : "file://" + p) : ""
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 600; sourceSize.height: 600
                            },
                            // numeric badge: lives on the front face so it tilts/flips with the tile
                            Text {
                                visible: Theme.showBadges && cell.badge > 0 && !root.editing
                                anchors { right: parent.right; top: parent.top; rightMargin: 9; topMargin: 2 }
                                text: cell.badge
                                color: tile.ink
                                font.family: Theme.font; font.weight: Theme.fontLight
                                font.pixelSize: cell.size === "small" ? Math.round(cell.width * 0.34) : 46
                            }
                        ]

                        // live back face
                        Loader {
                            anchors.fill: parent
                            active: cell.liveOn
                            sourceComponent: TileFaces {
                                face: cell.face; size: cell.size; big: cell.big; line1: cell.line1; line2: cell.line2; imageSource: cell.img
                                ink: tile.ink; seed: root.hashOf(cell.tid) + 1
                                animate: tile.showingBack
                            }
                        }
                    }

                    // selected in edit mode: outline
                    Rectangle {
                        visible: root.editing && root._selId === cell.tid
                        anchors.fill: parent; anchors.margins: -3
                        color: "transparent"; border.width: 3; border.color: Theme.text
                        radius: Theme.tileRadius > 0 ? Theme.tileRadius + 3 : 0
                    }

                    // edit mode: drag surface; a plain tap selects the tile for the colour sheet
                    MouseArea {
                        id: dragMa
                        anchors.fill: parent
                        enabled: root.editing
                        visible: root.editing
                        z: 5
                        preventStealing: true
                        onPressed: (m) => { cell.dMoved = false; cell.dPress = Qt.point(m.x, m.y) }
                        onPositionChanged: (m) => { if (pressed) cell.dragStep(m.x, m.y, dragMa) }
                        onReleased: { const moved = cell.dMoved; cell.dragFinish(); if (!moved && !cell.held) root.selectTile(cell.tid === root._selId ? "" : cell.tid) }
                        onCanceled: cell.dragFinish()
                    }

                    // edit mode: unpin
                    Rectangle {
                        id: unpinBtn
                        visible: root.editing && !cell.dragging
                        z: 10
                        readonly property int d: cell.size === "small" ? 28 : 36
                        width: d; height: d; radius: d / 2
                        anchors { right: parent.right; top: parent.top; rightMargin: 4; topMargin: 4 }
                        color: "#f2f2f2"
                        TileGlyph { anchors.centerIn: parent; size: Math.round(parent.d * 0.55); name: "close"; color: "#111111"; stroke: 2.4 }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.unpin(cell.index) }
                    }
                    // edit mode: resize toggle (small -> medium -> wide -> large -> small)
                    Rectangle {
                        id: sizeBtn
                        visible: root.editing && !cell.dragging
                        z: 10
                        readonly property int d: cell.size === "small" ? 28 : 36
                        width: d; height: d; radius: d / 2
                        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 4; bottomMargin: 4 }
                        color: "#f2f2f2"
                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "#111111"; ctx.lineWidth = 2.2; ctx.lineCap = "round"; ctx.lineJoin = "round"
                                const w = width, h = height
                                ctx.beginPath()
                                ctx.moveTo(w * 0.32, h * 0.68); ctx.lineTo(w * 0.68, h * 0.32)
                                ctx.moveTo(w * 0.32, h * 0.52); ctx.lineTo(w * 0.32, h * 0.68); ctx.lineTo(w * 0.48, h * 0.68)
                                ctx.moveTo(w * 0.52, h * 0.32); ctx.lineTo(w * 0.68, h * 0.32); ctx.lineTo(w * 0.68, h * 0.48)
                                ctx.stroke()
                            }
                        }
                        // drag: continuous resize with snapping to s/m/w/l (live reflow); a plain tap still cycles
                        MouseArea {
                            id: sizeMa
                            anchors.fill: parent; anchors.margins: -10
                            preventStealing: true
                            property point p0
                            property real w0: 0
                            property real h0: 0
                            property bool moved: false
                            function pt(m) { return sizeMa.mapToItem(content, m.x, m.y) }
                            onPressed: (m) => {
                                p0 = pt(m); w0 = cell.width; h0 = cell.height; moved = false
                            }
                            onPositionChanged: (m) => {
                                if (!pressed) return
                                const p = pt(m)
                                if (!moved) {
                                    if (Math.abs(p.x - p0.x) + Math.abs(p.y - p0.y) < 10) return
                                    moved = true
                                    cell.rw = w0; cell.rh = h0; cell.resizing = true; root.resizingNow = true
                                }
                                // the tile is drawn at editing scale: undo it so the corner follows the finger
                                const k = 1 / 0.88, cw = root.width - 2 * Theme.pageMargin
                                cell.rw = Math.max(root.unitPx(), Math.min(cw, w0 + (p.x - p0.x) * k))
                                cell.rh = Math.max(root.unitPx(), Math.min(cw, h0 + (p.y - p0.y) * k))
                                const sz = root.snapSize(cell.rw, cell.rh)
                                if (sz !== cell.size) root.setSize(cell.index, sz)
                            }
                            onReleased: { if (moved) end(); else root.resize(cell.index) }
                            onCanceled: end()
                            function end() { cell.resizing = false; root.resizingNow = false; moved = false }
                        }
                    }
                }
            }

            // edit mode: add an empty group
            Item {
                visible: root.editing
                x: Theme.pageMargin; y: root.rowsHeight + 12
                width: addTxt.width + 28; height: 36
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Theme.textDim }
                Text { id: addTxt; anchors.centerIn: parent; text: Theme.title("new group"); color: Theme.text
                    font.family: Theme.font; font.pixelSize: 17; font.weight: Theme.fontLight }
                MouseArea { anchors.fill: parent; onClicked: Personalise.addGroup("New group") }
            }

            // "all apps" arrow: footer row below the last tile
            Item {
                id: arrowBtn
                width: 48; height: 48
                x: content.width - width - Theme.pageMargin; y: root.rowsHeight + 8 + 8
                opacity: root.editing ? 0 : Math.max(0, 1 - root.pagerP * 2)
                visible: opacity > 0.01
                Behavior on opacity { enabled: !Theme.reduceMotion; NumberAnimation { duration: 150 } }
                scale: arrowMa.pressed ? 0.92 : 1
                Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.pressMs } }
                Rectangle { anchors.fill: parent; radius: 24; color: "transparent"; border.width: 2; border.color: Theme.text }
                Canvas {
                    anchors.fill: parent
                    property color ink: Theme.text
                    onInkChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = ink; ctx.lineWidth = 2.6; ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.beginPath()
                        ctx.moveTo(width * 0.30, height * 0.5); ctx.lineTo(width * 0.70, height * 0.5)
                        ctx.moveTo(width * 0.52, height * 0.30); ctx.lineTo(width * 0.72, height * 0.5); ctx.lineTo(width * 0.52, height * 0.70)
                        ctx.stroke()
                    }
                }
                MouseArea { id: arrowMa; anchors.fill: parent; anchors.margins: -8; onClicked: root.appsRequested() }
            }
        }
    }

    function hashOf(s) { let h = 7; s = String(s); for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return Math.abs(h) }

    // ---- edit-mode colour sheet: 12 swatches, size, photo, unpin ----
    component SheetBtn: Rectangle {
        id: sb
        property string text: ""
        property bool on: false
        signal tapped()
        implicitWidth: lbl.width + 28; implicitHeight: 40
        color: on ? Theme.text : "transparent"
        border.width: 2; border.color: Theme.text
        Text { id: lbl; anchors.centerIn: parent; text: sb.text; color: sb.on ? Theme.pageBg : Theme.text
            font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Normal }
        MouseArea { anchors.fill: parent; onClicked: sb.tapped() }
    }

    Rectangle {
        id: sheet
        readonly property bool open: root.editing && root.selRow !== null
        readonly property string curCol: Theme.hasTileColor(root._selId) ? Qt.color(Personalise.tileColors[root._selId]).toString() : ""   // evaluated once, not per swatch
        width: parent.width
        height: sheetCol.height + 28
        y: open ? parent.height - root.bottomInset - height : parent.height
        visible: y < parent.height
        z: 20
        color: Theme.c.card
        Behavior on y { enabled: !Theme.reduceMotion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // swallow taps

        Column {
            id: sheetCol
            x: 16; y: 14
            width: parent.width - 32
            spacing: 12
            Item {
                width: parent.width; height: 30
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.selRow ? Theme.title(root.selRow.label) : ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight }
                Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: Theme.title("done")
                    color: Theme.accent; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.Normal
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: root.selectTile("") } }
            }
            // 12 swatches (+ auto = clear override)
            Grid {
                id: swGrid
                columns: 7; spacing: 8
                readonly property real sw: Math.floor((sheetCol.width - 6 * 8) / 7)
                Repeater {
                    model: Personalise.accentColours
                    delegate: Rectangle {
                        required property var modelData
                        width: swGrid.sw; height: swGrid.sw
                        color: modelData
                        border.width: sheet.curCol !== "" && sheet.curCol === Qt.color(modelData).toString() ? 3 : 0
                        border.color: Theme.text
                        MouseArea { anchors.fill: parent; onClicked: Personalise.setTileColor(root._selId, Qt.color(parent.modelData).toString()) }
                    }
                }
                Rectangle {
                    width: swGrid.sw; height: swGrid.sw
                    color: "transparent"; border.width: 2; border.color: Theme.textDim
                    Text { anchors.centerIn: parent; text: Theme.title("auto"); color: Theme.text; font.family: Theme.font; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: Personalise.setTileColor(root._selId, "") }
                }
            }
            Row {
                spacing: 8
                Repeater {
                    model: ["small", "medium", "wide", "large"]
                    delegate: SheetBtn {
                        required property string modelData
                        text: Theme.title(modelData === "small" ? "s" : modelData === "medium" ? "m" : modelData === "wide" ? "w" : "l")
                        on: root.selRow !== null && root.selRow.size === modelData
                        onTapped: root.setSize(root.indexOfId(root._selId), modelData)
                    }
                }
                SheetBtn {
                    text: Theme.title("photo"); on: root.selRow !== null && root.selRow.picture
                    onTapped: { const i = root.indexOfId(root._selId); if (i >= 0) tileModel.setProperty(i, "picture", !tileModel.get(i).picture) }
                }
                SheetBtn { text: Theme.title("unpin"); onTapped: root.unpin(root.indexOfId(root._selId)) }
            }
        }
    }
}
