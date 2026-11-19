import QtQuick
import QtQuick.Shapes
import FlowShell

// TilesKeyboard: on-screen keyboard in the Tiles (Windows Phone) look on a pure black panel.
// Key placement follows Gboard (number row, QWERTY, shift/backspace row, ?123 / , / space / . / enter).
//
//   target   : the TextInput / TextEdit that receives the keys (null = hidden)
//   shown    : true while the keyboard should be up (Main sets it from the focused item)
//   visibleH : height reserved by the keyboard. Snaps (no per-frame values) so the content above relayouts once,
//              not on every animation frame (resizing a native app surface per frame was the main stutter).
//   numberRow: true = permanent 1..0 row (default)
//   glideTyping: swipe typing on/off
//   signal hideRequested : the user tapped the collapse chevron
//
// Features: shift (tap = once, double tap = caps lock, auto capital), key preview bubble, long-press alternates
// (drag to pick), backspace repeat, space-bar cursor drag, symbols pages, numeric pad, glide typing with a trail
// and a suggestion strip (3 best words; tap one to swap the glided word), prefix completions while tapping.
// Perf: ONE MouseArea hit-tests keys (childAt), popups/bubble/strip are single shared items, icons are GPU Shapes
// (no Canvas), no per-key timers/bindings for alternates, constant height (no relayout on layer change).
Item {
    id: root
    property Item target: null
    property bool shown: false
    property bool numberRow: true
    property bool glideTyping: true
    readonly property real visibleH: shown ? height : 0
    property real p: shown ? 1 : 0
    signal hideRequested

    readonly property real barH: 40
    readonly property int pad: 3
    readonly property int maxRows: numberRow ? 5 : 4
    readonly property real keyH: 58
    readonly property int rowCount: layoutRows.length
    readonly property real rowH: (height - barH - pad * 2) / Math.max(1, rowCount)
    height: barH + maxRows * keyH + pad * 2
    visible: p > 0.001
    enabled: shown
    transform: Translate { y: (1 - root.p) * root.height }
    Behavior on p { enabled: !Theme.reduceMotion
        NumberAnimation { duration: root.shown ? 220 : 160; easing.type: root.shown ? Easing.OutCubic : Easing.InCubic } }

    // ---- state ----
    property string kbLayer: "abc"          // abc | sym | sym2 | num
    property string shiftState: "off"     // off | once | lock
    readonly property bool numeric: target && (target.inputMethodHints & (Qt.ImhDigitsOnly | Qt.ImhFormattedNumbersOnly | Qt.ImhDialableCharactersOnly)) !== 0
    readonly property bool autoCap: target && !(target.inputMethodHints & (Qt.ImhNoAutoUppercase | Qt.ImhLowercaseOnly | Qt.ImhEmailCharactersOnly | Qt.ImhUrlCharactersOnly | Qt.ImhSensitiveData))
    readonly property bool wordsOk: target && kbLayer === "abc" && !numeric && !(target.inputMethodHints & (Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhEmailCharactersOnly | Qt.ImhUrlCharactersOnly))
    onTargetChanged: {
        kbLayer = numeric ? "num" : "abc"
        shiftState = "off"
        _glideEnd = -1; sugg = []
        _autoCapitalise()
    }
    onKbLayerChanged: { if (kbLayer !== "abc") sugg = [] }

    // ---- layouts: tokens; "@x" = special, "@pad" = half-key spacer ----
    readonly property var layouts: ({
        abc: [
            ["1","2","3","4","5","6","7","8","9","0"],
            ["q","w","e","r","t","y","u","i","o","p"],
            ["@pad","a","s","d","f","g","h","j","k","l","@pad"],
            ["@shift","z","x","c","v","b","n","m","@bksp"],
            ["@sym",",","@space",".","@enter"]],
        sym: [
            ["1","2","3","4","5","6","7","8","9","0"],
            ["@","#","$","_","&","-","+","(",")","/"],
            ["@pad","*","\"","'",":",";","!","?","@pad"],
            ["@sym2","=","%","~","\\","|","<",">","@bksp"],
            ["@abc",",","@space",".","@enter"]],
        sym2: [
            ["1","2","3","4","5","6","7","8","9","0"],
            ["`","•","√","π","÷","×","¶","∆","{","}"],
            ["@pad","£","¢","€","¥","^","°","[","]","@pad"],
            ["@sym","©","®","™","✓","¡","¿","«","»","@bksp"],
            ["@abc",",","@space",".","@enter"]],
        num: [
            ["1","2","3","@bksp"],
            ["4","5","6","."],
            ["7","8","9",","],
            ["-","0","@enter"]]
    })
    readonly property var layoutRows: {
        let rows = layouts[kbLayer] || layouts.abc
        if (!numberRow && kbLayer !== "num") rows = rows.slice(1)
        return rows
    }
    readonly property var weights: ({ "@shift": 1.5, "@bksp": 1.5, "@sym": 1.5, "@sym2": 1.5, "@abc": 1.5, "@space": 5, "@enter": 1.5, "@pad": 0.5 })

    readonly property var alternates: ({
        a: ["à","á","â","ä","æ","ã","å","ā"], e: ["é","è","ê","ë","ē","ę"],
        i: ["í","ì","î","ï","ī"], o: ["ó","ò","ô","ö","õ","œ","ø"],
        u: ["ú","ù","û","ü","ū"], c: ["ç","ć","č"], n: ["ñ","ń"],
        s: ["ß","š","ś"], y: ["ý","ÿ"], z: ["ž","ź","ż"], l: ["ł"], d: ["ď"],
        r: ["ř"], t: ["ť"], g: ["ğ"],
        ".": ["…","?","!",":",";"], ",": [";",":","“","”"], "-": ["–","—","•"],
        "$": ["€","£","¥","¢"], "0": ["°"], "?": ["¿"], "!": ["¡"], "\"": ["“","”","«","»"]
    })
    function altsFor(k) {
        const a = alternates[k.tok.toLowerCase()]
        if (!a || k.special) return []
        return k.letter && shiftState !== "off" ? a.map(x => x.toUpperCase()) : a
    }

    // ---- text editing ----
    function _hasSel() { return target && target.selectedText !== undefined && target.selectionStart !== target.selectionEnd }
    function commit(t) {
        if (!target) return
        if (_hasSel()) target.remove(target.selectionStart, target.selectionEnd)
        const pos = target.cursorPosition
        target.insert(pos, t)
        target.cursorPosition = pos + t.length
        if (shiftState === "once") shiftState = "off"
        if (kbLayer === "sym" || kbLayer === "sym2") { if (t === " ") kbLayer = "abc" }
        _glideEnd = -1
        _autoCapitalise()
        _updatePrefix()
    }
    function backspace() {
        if (!target) return
        if (_hasSel()) { target.remove(target.selectionStart, target.selectionEnd) }
        else if (_glideEnd >= 0 && target.cursorPosition === _glideEnd && _glideLen > 0) {
            target.remove(_glideEnd - _glideLen, _glideEnd); target.cursorPosition = _glideEnd - _glideLen   // undo a whole glided word
        }
        else if (target.cursorPosition > 0) { const p0 = target.cursorPosition; target.remove(p0 - 1, p0); target.cursorPosition = p0 - 1 }
        _glideEnd = -1
        _autoCapitalise()
        _updatePrefix()
    }
    function enter() {
        if (!target) return
        if (typeof target.accepted === "function" || target.accepted !== undefined) { target.accepted(); return }
        commit("\n")
    }
    function moveCursor(d) { if (target) target.cursorPosition = Math.max(0, Math.min(target.length, target.cursorPosition + d)); _glideEnd = -1 }
    function _autoCapitalise() {
        if (!autoCap || kbLayer !== "abc" || shiftState === "lock") return
        const t = target.text.substring(0, target.cursorPosition)
        shiftState = (t.length === 0 || /[.!?]\s+$/.test(t) || /\n$/.test(t)) ? "once" : "off"
    }
    function pressShift() {
        if (shiftState === "off") shiftState = "once"
        else if (shiftState === "once") shiftState = dbl.running ? "lock" : "off"
        else shiftState = "off"
        dbl.restart()
    }
    Timer { id: dbl; interval: 340 }

    // ---- word model (compact frequency-ranked list, rank = position) ----
    readonly property string wordData: "the be to of and a in that have i it for not on with he as you do at this but his by from they we say her she or an will my one all would there their what so up out if about who get which go me when make can like time no just him know take people into year your good some could them see other than then now look only come its over think also back after use two how our work first well way even new want because any these give day most us is are was were been has had did said am does made find here thing many where much through long down should call world life still own see men might hand part great old high every school never same another begin while last between city tree cross since hard start might story saw far sea draw left late run dont press close night real life few north open seem together next white children begin got walk example ease paper often always music those both mark book letter until mile river car feet care second group carry took rain eat room friend began idea fish mountain stop once base hear horse cut sure watch color face wood main enough plain girl usual young ready above ever red list though feel talk bird soon body dog family direct pose leave song measure door product black short numeral class wind question happen complete ship area half rock order fire south problem piece told knew pass farm top whole king size heard best hour better true during hundred five remember step early hold west ground interest reach fast verb sing listen six table travel less morning ten simple several vowel toward war lay against pattern slow center love person money serve appear road map science rule govern pull cold notice voice fall power town fine certain fly unit lead cry dark machine note wait plan figure star box noun field rest correct able pound done beauty drive stood contain front teach week final gave green oh quick develop sleep warm free minute strong special mind behind clear tail produce fact street inch lot nothing course stay wheel full force blue object decide surface deep moon island foot yet busy test record boat common gold possible plane age dry wonder laugh thousand ago ran check game shape yes hot miss brought heat snow bed bring sit perhaps fill east weight language among is it's don't i'm can't that's i'll i've didn't doesn't isn't won't you're we're they're let's there's what's wasn't couldn't wouldn't shouldn't he's she's hello hi hey thanks thank please sorry okay ok yeah yes welcome goodbye bye morning evening tonight tomorrow today yesterday later soon maybe really very too more less again already almost quite rather pretty actually probably definitely exactly totally absolutely work works working worked home house phone call calls message messages text email mail send sent receive reply answer ask asked tell told talk speak spoke meet met meeting party dinner lunch breakfast coffee tea water food drink eat ate cook cooking restaurant hungry thirsty tired happy sad angry excited nervous scared worried glad proud sure want need needs needed like likes liked love loved hate enjoy prefer choose chose picked pick buy bought sell sold pay paid cost price cheap expensive free store shop shopping market order delivery go going goes went gone come coming came leave left arrive arrived travel trip flight train bus car drive driving walk walking run running ride bike airport station hotel read reading write writing wrote written draw play playing played game games movie film show watch watching listen music song songs video photo picture pictures camera learn learning learned study teach teacher student class school college university test exam question answer problem solution idea plan project task job career boss company business office team help helps helped helping try trying tried use used using make making made do doing done does did get getting got give giving gave take taking took put putting set let letting keep keeping kept think thinking thought know knowing knew believe feel feeling felt hope hoping wish guess mean means meant understand understood remember forget forgot wonder wondering imagine good great nice awesome amazing wonderful terrible awful bad best worst better worse fine cool fun funny interesting boring easy hard difficult simple possible impossible important special different same similar big small little large huge tiny long short tall high low wide narrow thick thin heavy light fast slow quick early late new old young red blue green yellow orange purple pink black white brown gray grey gold silver one two three four five six seven eight nine ten eleven twelve twenty thirty forty fifty hundred thousand million first second third last next monday tuesday wednesday thursday friday saturday sunday january february march april may june july august september october november december week weekend month year years day days hour hours minute minutes second seconds time times night nights man woman men women boy girl child children kid kids baby mother father mom dad brother sister son daughter wife husband friend friends family parents people person someone anyone everyone nobody everybody somebody here there where when why how what who which whose whom whatever whenever wherever however because although though unless until while whether either neither both each every any some many much most few several enough above below under over between among around about across along behind beside beyond inside outside near far before after during since still just only even also then than so very too quite because therefore however otherwise instead besides moreover meanwhile name names called call number numbers address city country state street place places room rooms phone screen keyboard computer laptop internet online website app apps application software update download install settings battery wifi network password account login today tonight tomorrow yesterday now soon later always never sometimes often usually rarely world life love death war peace money power time space light night day water fire earth air weather rain snow wind sun sunny cloudy cold hot warm cool storm body head hair face eye eyes ear ears nose mouth teeth hand hands arm arms leg legs foot feet heart doctor hospital health sick pain medicine anything something nothing everything anywhere somewhere nowhere everywhere really right wrong true false real fact truth lie looking look looks looked see seeing saw seen watch find finding found lost lose start started starting stop stopped stopping begin began finish finished end ended open opened close closed turn turned move moved change changed live lived living die died born grow grew grown people thing things way ways part parts lot lots kind sort type case point side end being become became becomes become seem seemed seems appear appeared should could would might must shall will can may okay alright sure thanks cheers sorry pardon excuse tiles shell launcher swipe glide"
    property var _W: null          // { w: [word], l: [letters only], rank: [n], first: {c: [idx]} }
    function _words() {
        if (_W) return _W
        const seen = {}, w = [], l = [], first = {}
        const src = wordData.split(/\s+/)
        for (let i = 0; i < src.length; i++) {
            const s = src[i]
            if (!s || seen[s]) continue
            seen[s] = 1
            const idx = w.length
            w.push(s); const lt = s.replace(/'/g, ""); l.push(lt)
            const c = lt.charAt(0); (first[c] || (first[c] = [])).push(idx)
        }
        _W = { w: w, l: l, first: first }
        return _W
    }
    function _styled(word, prefixOrNull) {   // apply shift / typed-prefix case to a lowercase word
        if (prefixOrNull && prefixOrNull.length > 1 && prefixOrNull === prefixOrNull.toUpperCase()) return word.toUpperCase()
        const cap = prefixOrNull ? (prefixOrNull.charAt(0) !== prefixOrNull.charAt(0).toLowerCase()) : shiftState !== "off"
        const up = !prefixOrNull && shiftState === "lock"
        return up ? word.toUpperCase() : (cap ? word.charAt(0).toUpperCase() + word.substring(1) : word)
    }

    // suggestion strip
    property var sugg: []          // displayed strings
    property string suggMode: "none"   // none | prefix | glide
    property string _prefix: ""
    property int _glideEnd: -1
    property int _glideLen: 0
    function _updatePrefix() {
        suggMode = "prefix"; _prefix = ""
        if (!wordsOk) { sugg = []; return }
        const m = /[A-Za-z']+$/.exec(target.text.substring(Math.max(0, target.cursorPosition - 24), target.cursorPosition))
        if (!m) { sugg = []; return }
        _prefix = m[0]
        const lp = _prefix.toLowerCase(), W = _words(), c = lp.charAt(0), cand = W.first[c.replace(/'/g,"")] || [], out = []
        for (let i = 0; i < cand.length && out.length < 3; i++) {
            const wd = W.w[cand[i]]
            if (wd.length > lp.length && wd.indexOf(lp) === 0) out.push(_styled(wd, _prefix))
        }
        sugg = out
    }
    function pickSuggestion(i) {
        if (!target || i >= sugg.length) return
        const w = sugg[i]
        if (suggMode === "glide" && _glideEnd >= 0 && target.cursorPosition === _glideEnd) {
            const s = _glideEnd - _glideLen
            target.remove(s, _glideEnd); target.insert(s, w + " ")
            const e = s + w.length + 1
            target.cursorPosition = e; _glideLen = w.length + 1; _glideEnd = e
        } else if (suggMode === "prefix") {
            const e = target.cursorPosition, s = e - _prefix.length
            target.remove(s, e); target.insert(s, w + " "); target.cursorPosition = s + w.length + 1
            _glideEnd = -1; _autoCapitalise(); _updatePrefix()
        }
    }

    // ---- glide decoding (SHARK2-style: resampled path vs. ideal key-centre polyline, anchored ends, frequency prior) ----
    function _resample(pts, n) {
        let L = 0
        for (let i = 1; i < pts.length; i++) L += Math.hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y)
        const out = []
        if (L < 1e-6) { for (let i = 0; i < n; i++) out.push(pts[0]); return out }
        const step = L / (n - 1)
        let acc = 0, seg = 1, a = pts[0]
        out.push(a)
        let need = step
        while (out.length < n - 1 && seg < pts.length) {
            const b = pts[seg], d = Math.hypot(b.x - a.x, b.y - a.y)
            if (d >= need && d > 0) {
                const t = need / d
                a = { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }
                out.push(a); need = step
            } else { need -= d; a = b; seg++ }
        }
        out.push(pts[pts.length - 1])
        while (out.length < n) out.push(pts[pts.length - 1])
        return out
    }
    function _plen(pts) { let L = 0; for (let i = 1; i < pts.length; i++) L += Math.hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y); return L }
    function decode(pts, centers, keyW) {
        const W = _words(), N = 28
        if (pts.length < 2) return []
        const uL = _plen(pts)
        if (uL < keyW * 1.2) return []
        const user = _resample(pts, N)
        const s0 = pts[0], e0 = pts[pts.length - 1]
        const res = []
        for (const c in centers) {
            const cc = centers[c]
            if (Math.hypot(cc.x - s0.x, cc.y - s0.y) > keyW * 1.25) continue
            const cand = W.first[c] || []
            for (let ci = 0; ci < cand.length; ci++) {
                const idx = cand[ci], lt = W.l[idx]
                const ideal = []
                let ok = true
                for (let j = 0; j < lt.length; j++) {
                    const k = centers[lt.charAt(j)]
                    if (!k) { ok = false; break }
                    if (ideal.length === 0 || ideal[ideal.length - 1] !== k) ideal.push(k)
                }
                if (!ok || ideal.length < 2) continue
                const last = ideal[ideal.length - 1]
                if (Math.hypot(last.x - e0.x, last.y - e0.y) > keyW * 1.5) continue
                const iL = _plen(ideal), ratio = iL / uL
                if (ratio < 0.4 || ratio > 1.8) continue
                const rs = _resample(ideal, N)
                let d = 0
                for (let j = 0; j < N; j++) d += Math.hypot(rs[j].x - user[j].x, rs[j].y - user[j].y)
                d = d / N / keyW
                const score = d + 0.07 * Math.log(1 + idx / 20) + 0.15 * Math.abs(Math.log(ratio))
                res.push({ i: idx, s: score })
            }
        }
        res.sort((a, b) => a.s - b.s)
        if (res.length === 0 || res[0].s > 2.2) return []
        return res.slice(0, 3).map(r => W.w[r.i])
    }

    // ---- visuals ----
    readonly property color keyFill: Theme.dark ? "#262626" : "#d7d7d7"
    readonly property color keyFillSpecial: Theme.dark ? "#171717" : "#c4c4c4"
    readonly property color panelFill: Theme.dark ? "#000000" : "#ececec"

    Rectangle { anchors.fill: parent; color: root.panelFill }
    MouseArea { anchors.fill: parent }   // swallow taps in gaps so they never reach the page below
    Rectangle { width: parent.width; height: 1; color: Theme.dark ? "#2e2e2e" : "#c8c8c8" }

    // top bar: collapse chevron + suggestion strip
    Item {
        id: bar
        width: parent.width; height: root.barH
        Item {
            width: 56; height: parent.height
            Shape {
                width: 22; height: 12; anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.textDim; strokeWidth: 2.4; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: [Qt.point(2, 2), Qt.point(11, 10), Qt.point(20, 2)] }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.hideRequested() }
        }
        Row {
            x: 56; width: parent.width - 56; height: parent.height
            Repeater {
                model: root.sugg
                Item {
                    required property int index
                    required property string modelData
                    width: parent.width / 3; height: bar.height
                    Rectangle { visible: index > 0; width: 1; height: parent.height * 0.5; anchors.verticalCenter: parent.verticalCenter
                        color: Theme.dark ? "#333333" : "#bbbbbb" }
                    Text {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        text: modelData; font.family: Theme.font; font.pixelSize: 19
                        font.weight: (index === 0 && root.suggMode === "glide") ? Font.DemiBold : Font.Normal
                        color: (index === 0 && root.suggMode === "glide") ? Theme.accent : Theme.text
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.pickSuggestion(index) }
                }
            }
        }
    }

    // key icon (shift, backspace, enter): GPU Shape, no Canvas
    component KeyIcon : Shape {
        id: ic
        property string kind: ""
        property color ink: Theme.text
        property bool filled: false
        width: 26; height: 26
        preferredRendererType: Shape.CurveRenderer
        readonly property var p1: kind === "shift" ? [Qt.point(13,3), Qt.point(23,13), Qt.point(17,13), Qt.point(17,22), Qt.point(9,22), Qt.point(9,13), Qt.point(3,13), Qt.point(13,3)]
            : kind === "bksp" ? [Qt.point(9,4), Qt.point(23,4), Qt.point(23,22), Qt.point(9,22), Qt.point(2,13), Qt.point(9,4)]
            : [Qt.point(22,5), Qt.point(22,15), Qt.point(5,15)]
        readonly property var p2: kind === "bksp" ? [Qt.point(12,9), Qt.point(19,17)] : kind === "enter" ? [Qt.point(11,9), Qt.point(5,15), Qt.point(11,21)] : []
        readonly property var p3: kind === "bksp" ? [Qt.point(19,9), Qt.point(12,17)] : []
        ShapePath {
            strokeColor: ic.ink; strokeWidth: 2.2; fillColor: ic.filled ? ic.ink : "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathPolyline { path: ic.p1 }
        }
        ShapePath {
            strokeColor: ic.ink; strokeWidth: 2.2; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathPolyline { path: ic.p2 }
        }
        ShapePath {
            strokeColor: ic.ink; strokeWidth: 2.2; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathPolyline { path: ic.p3 }
        }
    }

    // one key: purely visual (input is handled by kbArea)
    component Key : Item {
        id: k
        property string tok: ""
        property real unit: 40
        readonly property bool pad: tok === "@pad"
        readonly property bool special: tok.charAt(0) === "@"
        readonly property real wt: special ? (root.weights[tok] || 1) : 1
        readonly property bool letter: !special && tok.length === 1 && tok.toLowerCase() !== tok.toUpperCase()
        readonly property string ch: letter && root.shiftState !== "off" ? tok.toUpperCase() : tok
        readonly property bool down: root.pressedKey === k
        width: wt * unit; height: root.rowH

        Rectangle {
            visible: !k.pad
            anchors { fill: parent; margins: 2 }
            color: k.down ? Theme.accent
                 : (k.tok === "@enter" ? Theme.accent
                 : (k.tok === "@shift" && root.shiftState !== "off" ? Theme.accent
                 : (k.special ? root.keyFillSpecial : root.keyFill)))
            Text {
                visible: !k.special || k.tok === "@sym" || k.tok === "@sym2" || k.tok === "@abc"
                anchors.centerIn: parent
                text: k.tok === "@sym" ? "?123" : k.tok === "@sym2" ? "=\\<" : k.tok === "@abc" ? "ABC" : k.ch
                color: (k.down || k.tok === "@enter") ? Theme.onColor(Theme.accent) : Theme.text
                font.family: Theme.font; font.pixelSize: k.special ? 20 : 27
            }
            Text { visible: k.tok === "@space"; anchors.centerIn: parent; text: "tiles"; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 16; font.letterSpacing: 2 }
            Loader {
                anchors.centerIn: parent
                active: k.tok === "@shift" || k.tok === "@bksp" || k.tok === "@enter"
                sourceComponent: KeyIcon {
                    kind: k.tok.substring(1)
                    filled: root.shiftState === "lock"
                    ink: (k.down || k.tok === "@enter" || (k.tok === "@shift" && root.shiftState !== "off")) ? Theme.onColor(Theme.accent) : Theme.text
                }
            }
        }
    }

    // rows
    Column {
        id: rowsCol
        y: root.barH + root.pad
        width: parent.width
        Repeater {
            model: root.layoutRows
            Row {
                id: rowItem
                required property var modelData
                required property int index
                readonly property bool isRow: true
                readonly property real wsum: {
                    let s = 0
                    for (let i = 0; i < modelData.length; i++) {
                        const t = modelData[i]
                        s += t.charAt(0) === "@" ? (root.weights[t] || 1) : 1
                    }
                    return s
                }
                Repeater {
                    model: rowItem.modelData
                    Key {
                        required property string modelData
                        tok: modelData
                        unit: root.width / rowItem.wsum
                    }
                }
            }
        }
    }

    // ---- input: one MouseArea for the whole key block ----
    property Item pressedKey: null
    property bool gliding: false
    property bool altOpen: false
    property var altList: []
    property int altHover: -1
    property real _bx: 0           // pressed key rect in root coordinates
    property real _by: 0
    property real _bw: 0
    property real _bh: 0
    property real spaceX: 0
    property bool spaceDragged: false
    property var glidePts: []
    property var trailPts: []
    property var _centers: null
    property real _gx: 0
    property real _gy: 0

    function keyAt(x, y) {      // x,y in kbArea coordinates
        const cy = Math.max(0, Math.min(rowsCol.height - 1, y - pad))
        const row = rowsCol.childAt(x, cy)
        if (!row || !row.isRow) return null
        const k = row.childAt(Math.max(0, Math.min(row.width - 1, x)), cy - row.y)
        return (k && k.tok !== undefined) ? k : null
    }
    function _centerMap() {
        const m = {}
        const rows = rowsCol.children
        for (let i = 0; i < rows.length; i++) {
            const r = rows[i]
            if (!r.isRow) continue
            for (let j = 0; j < r.children.length; j++) {
                const k = r.children[j]
                if (k.tok !== undefined && k.letter) m[k.tok.toLowerCase()] = { x: r.x + k.x + k.width / 2, y: r.y + k.y + k.height / 2 }
            }
        }
        return m
    }

    Timer { id: holdT; interval: 420
        onTriggered: { const k = root.pressedKey; if (!k || root.gliding) return
            const a = root.altsFor(k); if (a.length > 0) { root.altList = a; root.altOpen = true; root.altHover = 0 } } }
    Timer { id: repT; interval: 400
        onTriggered: { root.backspace(); repT.interval = 55; repT.repeat = true; repT.start() } }

    function pressAt(x, y) {
        const k = keyAt(x, y)
        if (!k || k.pad) return
        pressedKey = k; gliding = false; altHover = -1
        const pt = k.mapToItem(root, 0, 0); _bx = pt.x; _by = pt.y; _bw = k.width; _bh = k.height
        glidePts = [{ x: x, y: y }]; _gx = x; _gy = y; _centers = null
        if (k.tok === "@bksp") { backspace(); repT.interval = 400; repT.repeat = false; repT.start() }
        else if (k.tok === "@space") { spaceX = x; spaceDragged = false }
        else if (altsFor(k).length > 0) holdT.restart()
    }
    function moveTo(x, y) {
        const k = pressedKey
        if (!k) return
        if (altOpen) {
            const rx = x, ry = y + barH
            const i = Math.floor((rx - altStrip.x) / altStrip.cell)
            const n = altList.length
            altHover = (i >= 0 && i < n && ry < _by + _bh) ? i : (ry < _by ? Math.max(0, Math.min(n - 1, i)) : -1)
        } else if (k.tok === "@space") {
            const d = x - spaceX
            if (Math.abs(d) > 14 || spaceDragged) { spaceDragged = true
                const steps = Math.trunc(d / 16)
                if (steps !== 0) { moveCursor(steps); spaceX += steps * 16 } }
        } else if (glideTyping && k.letter && kbLayer === "abc" && wordsOk) {
            if (Math.hypot(x - _gx, y - _gy) < 4) return
            _gx = x; _gy = y
            glidePts.push({ x: x, y: y })
            if (!gliding) {
                const kk = keyAt(x, y)
                if (kk && kk !== k && kk.letter) {
                    gliding = true; holdT.stop(); _centers = _centerMap(); trailPts = []
                } else return
            }
            trailPts.push(Qt.point(x, y + barH))
            trailPoly.path = trailPts.slice(-60)
        }
    }
    function releaseAt() {
        holdT.stop(); repT.stop(); repT.repeat = false
        const k = pressedKey
        pressedKey = null
        if (!k) return
        if (altOpen) {
            if (altHover >= 0 && altHover < altList.length) commit(altList[altHover])
            altOpen = false; altHover = -1; return
        }
        if (gliding) { gliding = false; _finishGlide(); return }
        switch (k.tok) {
        case "@bksp": break
        case "@shift": pressShift(); break
        case "@sym": kbLayer = "sym"; break
        case "@sym2": kbLayer = "sym2"; break
        case "@abc": kbLayer = "abc"; break
        case "@space": if (!spaceDragged) commit(" "); break
        case "@enter": enter(); break
        default: commit(k.ch)
        }
    }
    MouseArea {
        id: kbArea
        y: root.barH; width: parent.width; height: parent.height - root.barH
        preventStealing: true
        onPressed: (m) => root.pressAt(m.x, m.y)
        onPositionChanged: (m) => root.moveTo(m.x, m.y)
        onReleased: root.releaseAt()
        onCanceled: { holdT.stop(); repT.stop(); root.pressedKey = null; root.altOpen = false; root.gliding = false }
    }

    function _finishGlide() {
        const kw = root.width / 10
        const words = decode(glidePts, _centers, kw)
        if (words.length === 0 || !target) return
        const styled = words.map(w => _styled(w, null))
        if (_hasSel()) target.remove(target.selectionStart, target.selectionEnd)
        const pos = target.cursorPosition
        const txt = styled[0] + " "
        target.insert(pos, txt)
        target.cursorPosition = pos + txt.length
        if (shiftState === "once") shiftState = "off"
        _glideLen = txt.length; _glideEnd = pos + txt.length
        suggMode = "glide"; sugg = styled
        _autoCapitalise()
    }

    // ---- shared popups ----
    Rectangle {   // key preview bubble
        visible: root.pressedKey !== null && !root.gliding && !root.altOpen && !root.pressedKey.special
        width: root._bw + 8; height: root._bh + 6
        x: root._bx - 4; y: root._by - root._bh - 10
        z: 20; color: Theme.accent
        Text { anchors.centerIn: parent; text: root.pressedKey ? root.pressedKey.ch : ""; color: Theme.onColor(Theme.accent)
            font.family: Theme.font; font.pixelSize: 38 }
    }
    Rectangle {   // alternates strip
        id: altStrip
        visible: root.altOpen
        readonly property real cell: 46
        width: root.altList.length * cell; height: 56
        x: Math.max(2, Math.min(root.width - width - 2, root._bx + (root._bw - width) / 2)); y: root._by - height - 10
        z: 30; color: Theme.dark ? "#1b1b1b" : "#e4e4e4"; border.width: 2; border.color: Theme.accent
        Row {
            Repeater {
                model: root.altList
                Rectangle {
                    required property int index
                    required property string modelData
                    width: altStrip.cell; height: altStrip.height - 4; y: 2
                    color: index === root.altHover ? Theme.accent : "transparent"
                    Text { anchors.centerIn: parent; text: modelData; font.family: Theme.font; font.pixelSize: 28
                        color: index === root.altHover ? Theme.onColor(Theme.accent) : Theme.text }
                }
            }
        }
    }
    Shape {   // glide trail
        anchors.fill: parent; z: 25
        opacity: root.gliding ? 0.85 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 220 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.accent; strokeWidth: 8; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathPolyline { id: trailPoly; path: [] }
        }
    }
}
