import QtQuick
import FlowShell

// Terminal: up to 3 TermSession tabs, small ANSI parser (SGR, \r \n \b \t, CSI K/J/C/D/G/H/P/@/X) into a styled line buffer.
// Not supported: full-screen TUI programs (cursor addressing, alt screen). Store key "terminal": { size }.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    readonly property int maxTabs: 3
    readonly property int lineCap: 3000
    property int fontSize: 18
    property var sessList: []          // [{term, model, scr, ended, closed, needs}]
    property int cur: 0
    property int rev: 0                // bumped when per-tab state (ended) changes
    property bool stick: true          // follow output
    property bool ctrlOn: false
    property bool altOn: false
    property bool menuOpen: false

    // ---------------------------------------------------------------- colours
    readonly property var palDark: ["#4a4a4a", "#e5484d", "#46c05f", "#e0b13a", "#4f8dff", "#c678dd", "#33c1c9", "#d0d0d0",
                                    "#7a7a7a", "#ff6b6b", "#6fe58a", "#ffd866", "#7aa7ff", "#e599f7", "#5fe3ea", "#ffffff"]
    readonly property var palLight: ["#000000", "#c4262e", "#2e7d32", "#a06a00", "#1a5fd0", "#8e3bb5", "#00838f", "#595959",
                                     "#555555", "#e53935", "#388e3c", "#b8860b", "#2f7bff", "#a64dc9", "#00a0b0", "#2a2a2a"]
    // render context; recreated (and everything re-rendered) when theme colours change
    property var ctx: ({ pal: Theme.dark ? palDark : palLight, fg: Theme.text.toString(), bg: Theme.pageBg.toString(),
                         cur: Theme.accent.toString(), cache: {} })
    onCtxChanged: rerenderAll()

    // ---------------------------------------------------------------- style table
    property var styleTab: [{ fg: -1, bg: -1, b: 0, d: 0, r: 0 }]
    property var styleMap: ({ "-1|-1|0|0|0": 0 })
    function styleId(S) {
        var k = S.fg + "|" + S.bg + "|" + (S.b ? 1 : 0) + "|" + (S.d ? 1 : 0) + "|" + (S.r ? 1 : 0)
        var id = styleMap[k]
        if (id === undefined) {
            id = styleTab.length
            styleTab.push({ fg: S.fg, bg: S.bg, b: S.b ? 1 : 0, d: S.d ? 1 : 0, r: S.r ? 1 : 0 })
            styleMap[k] = id
        }
        return id
    }
    function hex2(n) { n = Math.max(0, Math.min(255, Math.round(n))); return (n < 16 ? "0" : "") + n.toString(16) }
    function mix(a, b, t) {      // a*(1-t) + b*t, "#rrggbb"
        var ca = Qt.color(a), cb = Qt.color(b)
        return "#" + hex2((ca.r * (1 - t) + cb.r * t) * 255) + hex2((ca.g * (1 - t) + cb.g * t) * 255) + hex2((ca.b * (1 - t) + cb.b * t) * 255)
    }
    function colorOf(v, c) {
        if (v === -1) return null
        if (typeof v === "string") return v
        if (v < 16) return c.pal[v]
        if (v < 232) {
            var n = v - 16, lv = [0, 95, 135, 175, 215, 255]
            return "#" + hex2(lv[Math.floor(n / 36)]) + hex2(lv[Math.floor(n / 6) % 6]) + hex2(lv[n % 6])
        }
        var g = 8 + (v - 232) * 10
        return "#" + hex2(g) + hex2(g) + hex2(g)
    }
    function spanCss(id, c) {
        var hit = c.cache[id]
        if (hit !== undefined) return hit
        var st = styleTab[id], css = ""
        if (id !== 0) {
            var fv = st.fg
            if (st.b && typeof fv === "number" && fv >= 0 && fv < 8) fv += 8      // bold brightens the base 8
            var fg = colorOf(fv, c) || c.fg, bg = colorOf(st.bg, c)
            if (st.d) fg = mix(fg, bg || c.bg, 0.45)
            if (st.r) { var t = fg; fg = bg || c.bg; bg = t }
            if (fg !== c.fg) css += "color:" + fg + ";"
            if (bg) css += "background-color:" + bg + ";"
            if (st.b) css += "font-weight:bold;"
        }
        c.cache[id] = css
        return css
    }

    // ---------------------------------------------------------------- screen model
    function newLine() { return { c: [], s: [] } }
    function newScreen() {
        return { lines: [newLine()], cx: 0, cy: 0, st: 0, fg: -1, bg: -1, b: false, d: false, r: false,
                 mode: 0, params: "", dirty: ({}), base: 0, curAbs: -1, clear: false }
    }
    function dirtyRow(S, row) { S.dirty[row + S.base] = 1 }

    function newlineTo(S) {
        dirtyRow(S, S.cy)
        S.cy++
        if (S.cy >= S.lines.length) S.lines.push(newLine())
        dirtyRow(S, S.cy)
    }
    function putChar(S, ch) {
        var ln = S.lines[S.cy]
        while (ln.c.length < S.cx) { ln.c.push(" "); ln.s.push(0) }
        ln.c[S.cx] = ch; ln.s[S.cx] = S.st
        S.cx++
        S.dirty[S.cy + S.base] = 1
    }
    function control(S, code) {
        if (code === 13) { S.cx = 0 }
        else if (code === 10 || code === 11 || code === 12) { newlineTo(S) }
        else if (code === 8) { S.cx = Math.max(0, S.cx - 1) }
        else if (code === 9) { S.cx = (Math.floor(S.cx / 8) + 1) * 8 }
        dirtyRow(S, S.cy)   // cursor moved
    }
    function wipe(S) {
        S.lines = [newLine()]; S.cx = 0; S.cy = 0; S.dirty = ({}); S.base = 0; S.curAbs = -1; S.clear = true
    }
    function applySgr(S, nums) {
        if (nums.length === 0) nums = [0]
        for (var i = 0; i < nums.length; ++i) {
            var n = nums[i]
            if (n === 0) { S.fg = -1; S.bg = -1; S.b = false; S.d = false; S.r = false }
            else if (n === 1) S.b = true
            else if (n === 2) S.d = true
            else if (n === 22) { S.b = false; S.d = false }
            else if (n === 7) S.r = true
            else if (n === 27) S.r = false
            else if (n >= 30 && n <= 37) S.fg = n - 30
            else if (n >= 90 && n <= 97) S.fg = n - 90 + 8
            else if (n === 39) S.fg = -1
            else if (n >= 40 && n <= 47) S.bg = n - 40
            else if (n >= 100 && n <= 107) S.bg = n - 100 + 8
            else if (n === 49) S.bg = -1
            else if (n === 38 || n === 48) {
                var val = null
                if (nums[i + 1] === 5 && i + 2 < nums.length) { val = Math.max(0, Math.min(255, nums[i + 2])); i += 2 }
                else if (nums[i + 1] === 2 && i + 4 < nums.length) {
                    val = "#" + hex2(nums[i + 2]) + hex2(nums[i + 3]) + hex2(nums[i + 4]); i += 4
                } else i = nums.length
                if (val !== null) { if (n === 38) S.fg = val; else S.bg = val }
            }
        }
        S.st = styleId(S)
    }
    function csi(S, fin) {
        var p = S.params
        if (/^[?<>=]/.test(p) || /[ -\/]/.test(p)) return          // private modes (bracketed paste, cursor keys...), intermediates
        var nums = p === "" ? [] : p.split(/[;:]/).map(function(x) { var v = parseInt(x, 10); return isNaN(v) ? 0 : v })
        var n1 = nums.length > 0 && nums[0] > 0 ? nums[0] : 1
        var ln = S.lines[S.cy], i
        switch (fin) {
        case "m": applySgr(S, nums); return
        case "K": {
            var km = nums.length ? nums[0] : 0
            if (km === 0) { if (ln.c.length > S.cx) { ln.c.length = S.cx; ln.s.length = S.cx } }
            else if (km === 1) { for (i = 0; i <= S.cx && i < ln.c.length; ++i) { ln.c[i] = " "; ln.s[i] = 0 } }
            else if (km === 2) { ln.c = []; ln.s = [] }
            dirtyRow(S, S.cy); return
        }
        case "J": {
            var jm = nums.length ? nums[0] : 0
            if (jm === 0) {
                if (ln.c.length > S.cx) { ln.c.length = S.cx; ln.s.length = S.cx }
                S.lines.length = S.cy + 1
            } else if (jm === 1) {
                for (i = 0; i < S.cy; ++i) { S.lines[i] = newLine(); dirtyRow(S, i) }
                for (i = 0; i <= S.cx && i < ln.c.length; ++i) { ln.c[i] = " "; ln.s[i] = 0 }
            } else wipe(S)
            dirtyRow(S, S.cy); return
        }
        case "C": S.cx += n1; break
        case "D": S.cx = Math.max(0, S.cx - n1); break
        case "G": S.cx = Math.max(0, n1 - 1); break
        case "H": case "f": S.cx = nums.length > 1 && nums[1] > 0 ? nums[1] - 1 : 0; break   // row ignored: no cursor addressing
        case "P": ln.c.splice(S.cx, n1); ln.s.splice(S.cx, n1); break
        case "X": for (i = S.cx; i < S.cx + n1 && i < ln.c.length; ++i) { ln.c[i] = " "; ln.s[i] = 0 } break
        case "@": {
            if (S.cx > ln.c.length) return
            var sp = [], ss = []
            for (i = 0; i < n1; ++i) { sp.push(" "); ss.push(0) }
            ln.c.splice.apply(ln.c, [S.cx, 0].concat(sp)); ln.s.splice.apply(ln.s, [S.cx, 0].concat(ss))
            break
        }
        default: return     // everything else ignored (A/B row movement, scroll regions, DSR, ...)
        }
        dirtyRow(S, S.cy)
    }

    // Parser modes: 0 text, 1 ESC, 2 CSI, 3 string (OSC/DCS/APC.. until BEL or ST), 4 skip one char (charset), 5 ESC inside string
    function feed(S, text) {
        for (var i = 0; i < text.length; ++i) {
            var ch = text.charAt(i), code = text.charCodeAt(i)
            switch (S.mode) {
            case 0:
                if (code === 27) S.mode = 1
                else if (code < 32) control(S, code)
                else if (code !== 127) putChar(S, ch)
                break
            case 1:
                if (ch === "[") { S.mode = 2; S.params = "" }
                else if (ch === "]" || ch === "P" || ch === "X" || ch === "^" || ch === "_") S.mode = 3
                else if (ch === "(" || ch === ")" || ch === "*" || ch === "+" || ch === "#") S.mode = 4
                else if (code === 27) S.mode = 1
                else S.mode = 0
                break
            case 2:
                if (code >= 0x20 && code <= 0x3f) S.params += ch
                else if (code >= 0x40 && code <= 0x7e) { S.mode = 0; csi(S, ch) }
                else if (code === 27) S.mode = 1
                else if (code === 24 || code === 26) S.mode = 0
                break
            case 3:
                if (code === 7) S.mode = 0
                else if (code === 27) S.mode = 5
                break
            case 5:
                if (ch === "\\") S.mode = 0
                else { S.mode = 1; i-- }
                break
            case 4:
                S.mode = 0
                break
            }
        }
    }
    function writeStyled(S, text, color) {
        S.fg = color; S.st = styleId(S)
        for (var i = 0; i < text.length; ++i) putChar(S, text.charAt(i))
        S.fg = -1; S.st = styleId(S)
    }

    // ---------------------------------------------------------------- rendering
    function esc(ch) {
        switch (ch) {
        case "&": return "&amp;"
        case "<": return "&lt;"
        case ">": return "&gt;"
        case " ": return "&nbsp;"
        default: return ch
        }
    }
    function renderLine(S, row, withCursor) {
        var ln = S.lines[row], c = ctx
        var len = ln.c.length
        var total = withCursor ? Math.max(len, S.cx + 1) : len
        var html = "", run = "", runSid = -1
        function flushRun() {
            if (run === "") return
            var css = spanCss(runSid, c)
            html += css === "" ? run : "<span style=\"" + css + "\">" + run + "</span>"
            run = ""
        }
        for (var j = 0; j < total; ++j) {
            var chr = j < len ? ln.c[j] : " ", sid = j < len ? ln.s[j] : 0
            if (withCursor && j === S.cx) {
                flushRun(); runSid = -1
                html += "<span style=\"color:" + c.bg + ";background-color:" + c.fg + ";\">" + esc(chr) + "</span>"
                continue
            }
            if (sid !== runSid) { flushRun(); runSid = sid }
            run += esc(chr)
        }
        flushRun()
        return html === "" ? "&nbsp;" : html
    }
    function flush(sess) {
        var S = sess.scr, m = sess.model, i
        if (S.clear) { m.clear(); S.clear = false }
        while (m.count < S.lines.length) m.append({ html: "" })
        while (m.count > S.lines.length) m.remove(m.count - 1)
        if (S.lines.length > lineCap + 200) {          // hysteresis so trimming is not per line
            var n = S.lines.length - lineCap
            S.lines.splice(0, n); m.remove(0, n)
            S.base += n; S.cy -= n
            if (S.cy < 0) S.cy = 0
        }
        var curAbs = S.cy + S.base
        S.dirty[curAbs] = 1
        if (S.curAbs >= 0) S.dirty[S.curAbs] = 1
        for (var k in S.dirty) {
            var row = Number(k) - S.base
            if (row < 0 || row >= S.lines.length) continue
            m.setProperty(row, "html", renderLine(S, row, row === S.cy))
        }
        S.dirty = ({})
        S.curAbs = curAbs
        sess.needs = false
        if (sess === cs() && stick) Qt.callLater(scrollEnd)
    }
    function rerenderAll() {
        for (var i = 0; i < sessList.length; ++i) {
            var S = sessList[i].scr
            for (var r = 0; r < S.lines.length; ++r) S.dirty[r + S.base] = 1
            flush(sessList[i])
        }
    }
    Timer {
        id: flushTimer
        interval: 30; repeat: true
        onTriggered: {
            var any = false
            for (var i = 0; i < root.sessList.length; ++i) {
                var s = root.sessList[i]
                if (s.needs) { root.flush(s); any = true }
            }
            if (!any) stop()
        }
    }

    // ---------------------------------------------------------------- sessions
    function cs() { return cur >= 0 && cur < sessList.length ? sessList[cur] : null }
    function calcCols() { return view.width > 0 && charW.advance1 > 0 ? Math.max(20, Math.floor((view.width - 24) / charW.advance1)) : 48 }
    function calcRows() { return view.height > 0 && charW.height > 0 ? Math.max(8, Math.floor(view.height / charW.height)) : 24 }
    function updateSizes() {
        var c = calcCols(), r = calcRows()
        for (var i = 0; i < sessList.length; ++i) { sessList[i].term.cols = c; sessList[i].term.rows = r }
    }
    function startTerm(sess) {
        sess.term.cols = calcCols(); sess.term.rows = calcRows()
        sess.ended = false
        sess.term.start()
        rev++
    }
    function addSession() {
        if (sessList.length >= maxTabs) { return }
        var sess = { term: null, model: modelComp.createObject(root), scr: newScreen(), ended: false, closed: false, needs: false }
        sess.term = termComp.createObject(root)
        sess.term.output.connect(function(text) {
            if (sess.closed) return
            feed(sess.scr, text)
            sess.needs = true
            if (!flushTimer.running) flushTimer.start()
        })
        sess.term.finished.connect(function(code) {
            if (sess.closed) return
            var S = sess.scr
            if (S.cx > 0) { S.mode = 0; newlineTo(S); S.cx = 0 }
            writeStyled(S, "session ended - tap to restart", Theme.textDim.toString())
            newlineTo(S); S.cx = 0
            sess.ended = true
            flush(sess)
            rev++
        })
        sessList = sessList.concat([sess])
        cur = sessList.length - 1
        stick = true
        startTerm(sess)
        flush(sess)
    }
    function closeSession(i) {
        if (i < 0 || i >= sessList.length) return
        var sess = sessList[i]
        sess.closed = true
        sess.term.stop()
        var l = sessList.slice(); l.splice(i, 1)
        sessList = l
        if (cur >= l.length) cur = l.length - 1
        else if (cur > i) cur--
        sess.model.destroy(); sess.term.destroy()
        if (l.length === 0) { closeRequested(); return }
        stick = true
        Qt.callLater(scrollEnd)
    }
    function selectTab(i) {
        if (i === cur || i >= sessList.length) return
        cur = i; stick = true
        Qt.callLater(scrollEnd)
    }
    function restartCur() {
        var s = cs()
        if (!s || !s.ended) return false
        var S = s.scr
        if (S.cx > 0) newlineTo(S)
        S.cx = 0
        flush(s)
        startTerm(s)
        return true
    }
    function scrollEnd() { if (list.count > 0) list.positionViewAtEnd() }

    // ---------------------------------------------------------------- input
    function sendRaw(t) {
        if (restartCur()) return
        var s = cs()
        if (s && s.term.running) s.term.write(t)
    }
    function flushInput() {
        var t = input.text
        if (t !== "") { input.text = ""; input.prev = ""; sendRaw(t) }
    }
    function clearMods() { ctrlOn = false; altOn = false }
    function sendMod(ch) {
        // sticky Ctrl/Alt applied to one typed character
        var out = ch
        if (ctrlOn) {
            var u = ch.toUpperCase().charCodeAt(0)
            if (u >= 64 && u <= 95) out = String.fromCharCode(u & 0x1f)
            else if (ch === " ") out = "\x00"
            else if (ch === "?") out = "\x7f"
        }
        if (altOn) out = "\x1b" + out
        clearMods()
        sendRaw(out)
    }
    function arrow(fin) {
        flushInput()
        var mods = 1 + (altOn ? 2 : 0) + (ctrlOn ? 4 : 0)
        clearMods()
        sendRaw(mods > 1 ? "\x1b[1;" + mods + fin : "\x1b[" + fin)
    }
    function insertChar(ch) {
        if (ctrlOn || altOn) { sendMod(ch); return }
        input.insert(input.cursorPosition, ch)
    }
    function keyPress(id) {
        switch (id) {
        case "esc": flushInput(); clearMods(); sendRaw("\x1b"); break
        case "tab": flushInput(); clearMods(); sendRaw("\t"); break
        case "ctrl": ctrlOn = !ctrlOn; break
        case "alt": altOn = !altOn; break
        case "up": arrow("A"); break
        case "down": arrow("B"); break
        case "right": arrow("C"); break
        case "left": arrow("D"); break
        case "ctrlc": {
            input.text = ""; input.prev = ""; clearMods()
            var s = cs()
            if (s && s.term.running) s.term.interrupt()
            break
        }
        default: insertChar(id)
        }
    }
    function setFontSize(sz) {
        fontSize = Math.max(12, Math.min(32, sz))
        AppStore.save("terminal", { size: fontSize })
        Qt.callLater(updateSizes)
        stick = true
        Qt.callLater(scrollEnd)
    }

    Component.onCompleted: {
        var st = AppStore.load("terminal", {})
        if (st && typeof st.size === "number") fontSize = Math.max(12, Math.min(32, st.size))
        // sessions start once the view has a size (see onHeightChanged / view.onWidthChanged)
        starter.start()
    }
    Timer { id: starter; interval: 0; onTriggered: if (root.sessList.length === 0) root.addSession() }
    Component.onDestruction: {
        for (var i = 0; i < sessList.length; ++i) { sessList[i].closed = true; sessList[i].term.stop() }
    }

    focus: true
    function back() {
        if (menuOpen) menuOpen = false
        else closeRequested()
    }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    Component { id: modelComp; ListModel {} }
    Component { id: termComp; TermSession {} }

    TextMetrics {
        id: charW
        font.family: "monospace"; font.styleHint: Font.Monospace; font.pixelSize: root.fontSize
        text: "MMMMMMMMMMMMMMMMMMMM"
        readonly property real advance1: advanceWidth / 20
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // ---------------------------------------------------------------- header
    Item {
        id: header
        y: root.topInset
        width: parent.width
        height: 24 + capText.height + 2 + 52 * 1.15 + 6 + 48
        Text {
            id: capText
            x: 18; y: 24
            text: "TILESDE"; color: Theme.text
            font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
        }
        Text {
            id: titleText
            x: 18; y: capText.y + capText.height + 2
            text: "terminal"; color: Theme.text
            font.family: Theme.font; font.pixelSize: 52; font.weight: Theme.fontLight; font.letterSpacing: -1.5
        }
        // tab row
        Row {
            id: tabRow
            x: 18; y: parent.height - 48 + 4
            spacing: 6
            Repeater {
                model: root.sessList.length
                Rectangle {
                    required property int index
                    width: 40; height: 40
                    readonly property bool active: index === root.cur
                    readonly property bool ended: { root.rev; return root.sessList[index] ? root.sessList[index].ended : false }
                    color: active ? Theme.accent : "transparent"
                    border.width: 2; border.color: active ? Theme.accent : (ended ? Theme.textDim : Theme.text)
                    Text {
                        anchors.centerIn: parent; text: String(index + 1)
                        color: parent.active ? Theme.onColor(Theme.accent) : (parent.ended ? Theme.textDim : Theme.text)
                        font.family: Theme.font; font.pixelSize: 22
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -2; onClicked: root.selectTab(index) }
                }
            }
            Rectangle {
                visible: root.sessList.length < root.maxTabs
                width: 40; height: 40; color: "transparent"
                border.width: 2; border.color: Theme.text
                TileGlyph { anchors.centerIn: parent; name: "plus"; size: 24; color: Theme.text; stroke: 2 }
                MouseArea { anchors.fill: parent; anchors.margins: -2; onClicked: root.addSession() }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 12
            y: parent.height - 48 + 4
            spacing: 0
            Repeater {
                model: ["A-", "A+", "..."]
                Item {
                    required property string modelData
                    width: 52; height: 40
                    opacity: hm.pressed ? 0.5 : 1
                    Text {
                        anchors.centerIn: parent; text: modelData; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                    }
                    MouseArea {
                        id: hm; anchors.fill: parent
                        onClicked: {
                            if (modelData === "A-") root.setFontSize(root.fontSize - 2)
                            else if (modelData === "A+") root.setFontSize(root.fontSize + 2)
                            else root.menuOpen = !root.menuOpen
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- output
    ListView {
        id: list
        x: 0; y: header.y + header.height
        width: parent.width; height: view.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: { root.cur; return root.sessList.length > 0 && root.cs() ? root.cs().model : null }
        leftMargin: 12; rightMargin: 12
        delegate: Text {
            required property string html
            width: list.width - 24
            text: html
            textFormat: Text.RichText
            wrapMode: Text.WrapAnywhere
            color: Theme.text
            font.family: "monospace"; font.styleHint: Font.Monospace; font.pixelSize: root.fontSize
        }
        onMovementEnded: root.stick = atYEnd
        onFlickEnded: root.stick = atYEnd
        onDragStarted: root.stick = false
        onHeightChanged: if (root.stick) Qt.callLater(root.scrollEnd)
    }
    Item {
        anchors.fill: list
        TapHandler {
            onTapped: {
                if (!root.restartCur()) input.forceActiveFocus()
                root.menuOpen = false
            }
        }
    }
    // invisible sizing proxy: space between header and the bottom bars
    Item {
        id: view
        x: 0; y: header.y + header.height
        width: parent.width
        height: Math.max(0, bottomBar.y - y)
        onWidthChanged: Qt.callLater(root.updateSizes)
        onHeightChanged: Qt.callLater(root.updateSizes)
    }

    // ---------------------------------------------------------------- bottom bars
    Item {
        id: bottomBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 48 + 6 + 56 + 8

        Flickable {
            id: keys
            x: 0; y: 0; width: parent.width; height: 48
            contentWidth: keyRow.width + 24; contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: keyRow
                x: 12; spacing: 6
                Repeater {
                    model: [{ id: "esc", l: "Esc" }, { id: "tab", l: "Tab" }, { id: "ctrl", l: "Ctrl", sticky: true },
                            { id: "alt", l: "Alt", sticky: true }, { id: "up", l: "↑" }, { id: "down", l: "↓" },
                            { id: "left", l: "←" }, { id: "right", l: "→" }, { id: "|", l: "|" },
                            { id: "~", l: "~" }, { id: "-", l: "-" }, { id: "/", l: "/" }, { id: "ctrlc", l: "Ctrl+C" }]
                    Rectangle {
                        required property var modelData
                        readonly property bool on: (modelData.id === "ctrl" && root.ctrlOn) || (modelData.id === "alt" && root.altOn)
                        width: Math.max(52, kl.implicitWidth + 24); height: 48
                        color: km.pressed ? Theme.text : (on ? Theme.accent : "transparent")
                        border.width: 2; border.color: on ? Theme.accent : Theme.text
                        Text {
                            id: kl
                            anchors.centerIn: parent; text: modelData.l
                            color: km.pressed ? Theme.pageBg : (parent.on ? Theme.onColor(Theme.accent) : Theme.text)
                            font.family: Theme.font; font.pixelSize: 22
                        }
                        MouseArea { id: km; anchors.fill: parent; onClicked: root.keyPress(modelData.id) }
                    }
                }
            }
        }

        Rectangle {
            x: 12; y: 48 + 6
            width: parent.width - 24; height: 56
            color: "transparent"
            border.width: 2; border.color: input.activeFocus ? Theme.accent : Theme.text
            TextInput {
                id: input
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Theme.text
                selectionColor: Theme.accent
                font.family: "monospace"; font.styleHint: Font.Monospace; font.pixelSize: Math.max(18, root.fontSize)
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase
                property string prev: ""
                property bool busy: false
                onTextChanged: {
                    if (busy) return
                    if ((root.ctrlOn || root.altOn) && text.length === prev.length + 1) {
                        var i = 0
                        while (i < prev.length && prev.charAt(i) === text.charAt(i)) i++
                        var ch = text.charAt(i)
                        busy = true; text = prev; busy = false
                        cursorPosition = text.length
                        root.sendMod(ch)
                        return
                    }
                    prev = text
                }
                onAccepted: {
                    var t = text
                    text = ""; prev = ""
                    root.clearMods()
                    root.stick = true
                    root.sendRaw(t + "\n")
                }
                Text {
                    visible: input.text === "" && !input.activeFocus
                    text: "type a command"; color: Theme.textDim
                    font: input.font; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ---------------------------------------------------------------- header menu
    MouseArea { anchors.fill: parent; visible: root.menuOpen; onClicked: root.menuOpen = false }
    Rectangle {
        visible: root.menuOpen
        x: parent.width - width - 12; y: header.y + header.height - 4
        width: Math.min(parent.width - 24, 420); height: menuCol.height + 16
        color: Theme.dark ? "#1b1b1b" : "#e6e6e6"
        border.width: 2; border.color: Theme.text
        Column {
            id: menuCol
            x: 12; y: 8; width: parent.width - 24
            Repeater {
                model: ["open foot", "clear screen", "close session"]
                Item {
                    required property string modelData
                    width: parent.width; height: 56
                    opacity: mm.pressed ? 0.5 : 1
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                    }
                    MouseArea {
                        id: mm; anchors.fill: parent
                        onClicked: {
                            root.menuOpen = false
                            if (modelData === "open foot") Sys.launch("foot")
                            else if (modelData === "clear screen") {
                                var s = root.cs()
                                if (s) { root.wipe(s.scr); s.needs = true; root.flush(s) }
                            } else root.closeSession(root.cur)
                        }
                    }
                }
            }
            Text {
                width: parent.width; topPadding: 4; bottomPadding: 8
                text: "full-screen programs (vim, htop) are not supported yet"
                wrapMode: Text.WordWrap; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 17
            }
        }
    }
}
