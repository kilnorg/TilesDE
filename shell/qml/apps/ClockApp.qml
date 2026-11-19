import QtQuick
import FlowShell

// Clock: alarms, world clock, stopwatch, timer. Everything lives in this one Item so timers/stopwatch keep
// running while another pivot page is shown. Persistence: AppStore "clock-alarms", "clock-world".
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // ---------- shared time ----------
    property double nowMs: Date.now()
    property double lastMinuteStamp: -1

    // ---------- data ----------
    property var alarms: []           // [{id,h,m,label,days:[bool x7 Mon..Sun],on}]
    property var worldCities: []      // [{name,off}]
    property int armedCity: -1
    readonly property var dayNames: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    readonly property var cityDb: [
        { name: "Honolulu", off: -10 }, { name: "Anchorage", off: -9 }, { name: "Los Angeles", off: -8 },
        { name: "Vancouver", off: -8 }, { name: "Denver", off: -7 }, { name: "Mexico City", off: -6 },
        { name: "Chicago", off: -6 }, { name: "New York", off: -5 }, { name: "Toronto", off: -5 },
        { name: "Bogota", off: -5 }, { name: "Santiago", off: -4 }, { name: "Sao Paulo", off: -3 },
        { name: "Buenos Aires", off: -3 }, { name: "Reykjavik", off: 0 }, { name: "London", off: 0 },
        { name: "Lisbon", off: 0 }, { name: "Madrid", off: 1 }, { name: "Paris", off: 1 },
        { name: "Berlin", off: 1 }, { name: "Rome", off: 1 }, { name: "Cairo", off: 2 },
        { name: "Johannesburg", off: 2 }, { name: "Istanbul", off: 3 }, { name: "Moscow", off: 3 },
        { name: "Nairobi", off: 3 }, { name: "Dubai", off: 4 }, { name: "Karachi", off: 5 },
        { name: "Mumbai", off: 5.5 }, { name: "Dhaka", off: 6 }, { name: "Bangkok", off: 7 },
        { name: "Singapore", off: 8 }, { name: "Beijing", off: 8 }, { name: "Seoul", off: 9 },
        { name: "Tokyo", off: 9 }, { name: "Sydney", off: 10 }, { name: "Auckland", off: 12 }
    ]

    // ---------- ring banners ----------
    readonly property var rings: LiveTiles.rings   // pending ringing alarms/timers; fired by the LiveTiles clock service even when this app is closed

    // ---------- stopwatch ----------
    property bool swRunning: false
    property double swStart: 0
    property double swBase: 0
    property var laps: []             // newest first: {n, split, total}
    property double swLastLapTotal: 0
    readonly property double swElapsed: swRunning ? swBase + (nowMs - swStart) : swBase

    // ---------- timer ----------
    property string tmState: "idle"   // idle | running | paused
    property double tmEnd: 0
    property double tmTotal: 0
    property double tmPausedLeft: 0
    property int tmH: 0
    property int tmM: 5
    property int tmS: 0
    readonly property double tmLeft: tmState === "running" ? Math.max(0, tmEnd - nowMs)
                                     : (tmState === "paused" ? tmPausedLeft : 0)

    // ---------- editor / overlay state ----------
    property bool editing: false
    property int editId: -1
    property int editH: 7
    property int editM: 0
    property string editLabel: ""
    property var editDays: [false, false, false, false, false, false, false]
    property bool adding: false
    property string cityFilter: ""

    // ---------- helpers ----------
    function pad(n, w) { var s = String(Math.floor(n)); while (s.length < (w || 2)) s = "0" + s; return s }
    function save() { AppStore.save("clock-alarms", alarms) }
    function saveWorld() { AppStore.save("clock-world", worldCities) }
    function sortAlarms() {
        alarms = alarms.slice().sort(function(a, b) { return (a.h * 60 + a.m) - (b.h * 60 + b.m) })
    }
    function daysText(d) {
        var n = 0, i
        for (i = 0; i < 7; ++i) if (d[i]) n++
        if (n === 0) return "once"
        if (n === 7) return "every day"
        if (n === 5 && !d[5] && !d[6]) return "weekdays"
        if (n === 2 && d[5] && d[6]) return "weekends"
        var out = []
        for (i = 0; i < 7; ++i) if (d[i]) out.push(dayNames[i])
        return out.join(" ")
    }
    function offText(off) {
        var s = off < 0 ? "-" : "+", a = Math.abs(off)
        var h = Math.floor(a), m = Math.round((a - h) * 60)
        return "UTC" + s + h + (m ? ":" + pad(m) : "")
    }
    // wall-clock Date (read with getUTC*) for a UTC offset in hours
    function cityDate(off) { return new Date(nowMs + off * 3600000) }
    function dayRel(off) {
        var c = cityDate(off), l = cityDate(-new Date(nowMs).getTimezoneOffset() / 60)
        var a = Date.UTC(c.getUTCFullYear(), c.getUTCMonth(), c.getUTCDate())
        var b = Date.UTC(l.getUTCFullYear(), l.getUTCMonth(), l.getUTCDate())
        return a > b ? "tomorrow" : (a < b ? "yesterday" : "today")
    }
    function cityTime(off) { var c = cityDate(off); return pad(c.getUTCHours()) + ":" + pad(c.getUTCMinutes()) }
    function fmtMs(ms, withCs) {
        var t = Math.max(0, ms), cs = Math.floor(t / 10) % 100
        var s = Math.floor(t / 1000) % 60, m = Math.floor(t / 60000) % 60, h = Math.floor(t / 3600000)
        return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s) + (withCs ? "." + pad(cs) : "")
    }
    function fmtCountdown(ms) {
        var t = Math.ceil(Math.max(0, ms) / 1000)
        return pad(Math.floor(t / 3600)) + ":" + pad(Math.floor(t / 60) % 60) + ":" + pad(t % 60)
    }

    // ---------- alarms ----------
    function openEditor(id) {
        editId = id
        var a = null
        for (var i = 0; i < alarms.length; ++i) if (alarms[i].id === id) a = alarms[i]
        if (a) { editH = a.h; editM = a.m; editLabel = a.label; editDays = a.days.slice() }
        else {
            var d = new Date()
            editH = d.getHours(); editM = (d.getMinutes() + 1) % 60; editLabel = ""
            editDays = [false, false, false, false, false, false, false]
        }
        hPick.set(editH); mPick.set(editM)
        labelField.text = editLabel
        editing = true
    }
    function commitEditor() {
        var list = alarms.slice()
        var rec = { id: editId, h: hPick.value, m: mPick.value, label: labelField.text, days: editDays.slice(), on: true }
        if (editId < 0) {
            var mx = 0
            for (var i = 0; i < list.length; ++i) mx = Math.max(mx, list[i].id)
            rec.id = mx + 1
            list.push(rec)
        } else {
            for (var j = 0; j < list.length; ++j) if (list[j].id === editId) { rec.on = true; list[j] = rec }
        }
        alarms = list; sortAlarms(); save()
        editing = false
    }
    function deleteEdited() {
        alarms = alarms.filter(function(a) { return a.id !== editId })
        save(); editing = false
    }
    function setAlarmOn(id, v) {
        alarms = alarms.map(function(a) { if (a.id === id) { var c = Object.assign({}, a); c.on = v; return c } return a })
        save()
    }
    function dismissRing() { LiveTiles.ringPop() }
    function snoozeRing() { LiveTiles.snoozeFirst() }
    function tick() { nowMs = Date.now() }
    function saveTimer() {
        AppStore.save("clock-timer", tmState === "running" ? { state: "running", end: tmEnd, total: tmTotal }
            : tmState === "paused" ? { state: "paused", left: tmPausedLeft, total: tmTotal } : { state: "idle" })
    }
    function loadTimer() {
        var t = AppStore.load("clock-timer", null)
        if (t && t.state === "running" && t.end > Date.now()) { tmEnd = t.end; tmTotal = t.total; tmState = "running" }
        else if (t && t.state === "paused") { tmPausedLeft = t.left; tmTotal = t.total; tmState = "paused" }
        else tmState = "idle"
    }

    // ---------- stopwatch / timer ----------
    function swToggle() {
        if (swRunning) { swBase = swElapsed; swRunning = false }
        else { swStart = Date.now(); nowMs = swStart; swRunning = true }
    }
    function swLap() {
        var t = swElapsed
        var l = laps.slice()
        l.unshift({ n: laps.length + 1, split: t - swLastLapTotal, total: t })
        laps = l; swLastLapTotal = t
    }
    function swReset() { swRunning = false; swBase = 0; laps = []; swLastLapTotal = 0 }
    function tmStart() {
        var total = (tmH * 3600 + tmM * 60 + tmS) * 1000
        if (total <= 0) return
        tmTotal = total; tmEnd = Date.now() + total; nowMs = Date.now(); tmState = "running"; saveTimer()
    }
    function tmToggle() {
        if (tmState === "idle") tmStart()
        else if (tmState === "running") { tmPausedLeft = Math.max(0, tmEnd - Date.now()); tmState = "paused"; saveTimer() }
        else { tmEnd = Date.now() + tmPausedLeft; nowMs = Date.now(); tmState = "running"; saveTimer() }
    }
    function tmReset() { tmState = "idle"; saveTimer() }

    // ---------- world ----------
    function addCity(c) {
        var l = worldCities.slice()
        l.push({ name: c.name, off: c.off })
        worldCities = l; saveWorld(); adding = false; cityFilter = ""
    }
    function removeCity(i) {
        var l = worldCities.slice()
        l.splice(i, 1)
        worldCities = l; saveWorld(); armedCity = -1
    }

    Component.onCompleted: {
        var a = AppStore.load("clock-alarms", null)
        alarms = LiveTiles._list(a)
        var w = AppStore.load("clock-world", null)
        // default list when the store is empty: three common cities (not user data)
        worldCities = Array.isArray(w) ? w : [cityDb[7], cityDb[14], cityDb[33]]
        if (!Array.isArray(w)) saveWorld()
        loadTimer()
    }
    Connections {
        target: AppStore
        function onSaved(app) {
            if (app === "clock-timer") root.loadTimer()
            else if (app === "clock-alarms") { var a = AppStore.load("clock-alarms", null); root.alarms = LiveTiles._list(a) }
        }
    }

    Timer {
        interval: root.swRunning ? 40 : (root.tmState === "running" ? 200 : 1000)
        running: true; repeat: true
        onTriggered: root.tick()
    }

    // ---------- number column (hours / minutes / seconds picker) ----------
    component NumberColumn: Item {
        id: nc
        property int count: 60
        property int value: 0
        readonly property int rowH: 64
        width: 110; height: rowH * 3
        function set(v) {
            lv.currentIndex = v
            nc.value = v
            lv.positionViewAtIndex(v, ListView.Center)
        }
        clip: true
        ListView {
            id: lv
            anchors.fill: parent
            model: nc.count
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: nc.rowH
            preferredHighlightEnd: nc.rowH * 2
            highlightMoveDuration: Theme.reduceMotion ? 0 : 120
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 2500
            onCurrentIndexChanged: if (nc.value !== currentIndex) nc.value = currentIndex
            delegate: Item {
                id: cell
                required property int index
                width: lv.width; height: nc.rowH
                readonly property real dist: Math.min(1, Math.abs((y - lv.contentY) - nc.rowH) / nc.rowH)
                opacity: 1 - 0.65 * dist
                Text {
                    anchors.centerIn: parent
                    text: root.pad(cell.index)
                    color: cell.dist < 0.5 ? Theme.accent : Theme.text
                    font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight
                }
                MouseArea { anchors.fill: parent; onClicked: lv.currentIndex = cell.index }
            }
        }
    }

    // ---------- main content ----------
    readonly property bool appBarShown: editing || adding || pivot.currentIndex === 0 || pivot.currentIndex === 1

    Pivot {
        id: pivot
        x: 0; y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - (root.appBarShown ? bar.collapsedH : 0)
        caption: "clock"
        visible: !root.editing && !root.adding

        // ===== alarms =====
        PivotPage {
            title: "alarms"
            Text {
                visible: root.alarms.length === 0
                width: parent.width; topPadding: 8
                text: "no alarms. tap + to add one."
                color: Theme.textDim; wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.alarms
                Item {
                    id: arow
                    required property var modelData
                    width: parent.width; height: 100
                    opacity: modelData.on ? 1 : 0.55
                    Text {
                        id: atime
                        y: 4
                        text: root.pad(arow.modelData.h) + ":" + root.pad(arow.modelData.m)
                        color: Theme.text
                        font.family: Theme.font; font.pixelSize: 52; font.weight: Theme.fontLight
                    }
                    Text {
                        x: atime.width + 16; y: 22; width: parent.width - x - 120
                        text: (arow.modelData.label !== "" ? arow.modelData.label + "\n" : "") + root.daysText(arow.modelData.days)
                        color: Theme.textDim; elide: Text.ElideRight; maximumLineCount: 2
                        font.family: Theme.font; font.pixelSize: 18
                    }
                    MouseArea {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        anchors.right: atog.left
                        onClicked: root.openEditor(arow.modelData.id)
                    }
                    MetroToggle {
                        id: atog
                        anchors.right: parent.right; y: 4
                        width: 96
                        checked: arow.modelData.on
                        onToggled: (v) => root.setAlarmOn(arow.modelData.id, v)
                    }
                }
            }
        }

        // ===== world =====
        PivotPage {
            title: "world"
            // local time first
            Item {
                width: parent.width; height: 76
                Text {
                    y: 4; width: parent.width - 150
                    text: "local"; color: Theme.accent; elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                }
                Text {
                    y: 34; width: parent.width - 150
                    text: root.offText(-new Date(root.nowMs).getTimezoneOffset() / 60)
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
                }
                Text {
                    anchors.right: parent.right; y: 4
                    text: { var d = new Date(root.nowMs); return root.pad(d.getHours()) + ":" + root.pad(d.getMinutes()) }
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
                }
            }
            Repeater {
                model: root.worldCities
                Item {
                    id: wrow
                    required property int index
                    required property var modelData
                    width: parent.width; height: 76
                    Text {
                        y: 4; width: parent.width - 150
                        text: wrow.modelData.name; color: Theme.text; elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                    }
                    Text {
                        y: 34; width: parent.width - 150
                        text: root.offText(wrow.modelData.off) + " · " + root.dayRel(wrow.modelData.off)
                        color: Theme.textDim; elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 18
                    }
                    Text {
                        visible: root.armedCity !== wrow.index
                        anchors.right: parent.right; y: 4
                        text: root.cityTime(wrow.modelData.off)
                        color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
                    }
                    MetroButton {
                        visible: root.armedCity === wrow.index
                        anchors.right: parent.right; y: 10
                        implicitWidth: 140; width: 140; height: 52
                        text: "remove"; accentFill: true
                        onClicked: root.removeCity(wrow.index)
                    }
                    MouseArea {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: parent.width - (root.armedCity === wrow.index ? 150 : 0)
                        onClicked: root.armedCity = (root.armedCity === wrow.index) ? -1 : wrow.index
                    }
                }
            }
            Text {
                visible: root.worldCities.length === 0
                width: parent.width; topPadding: 8
                text: "tap + to add a city."
                color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
        }

        // ===== stopwatch =====
        PivotPage {
            title: "stopwatch"
            Item { width: 1; height: 24 }
            Text {
                width: parent.width; height: 96
                text: root.fmtMs(root.swElapsed, true)
                color: Theme.text
                font.family: Theme.font; font.pixelSize: 84; font.weight: Theme.fontLight
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 40
                verticalAlignment: Text.AlignVCenter
            }
            Item { width: 1; height: 20 }
            Row {
                spacing: 12
                MetroButton {
                    text: root.swRunning || root.swElapsed === 0 ? "lap" : "reset"
                    enabled2: root.swElapsed > 0
                    onClicked: root.swRunning ? root.swLap() : root.swReset()
                }
                MetroButton {
                    text: root.swRunning ? "pause" : "start"
                    accentFill: true
                    onClicked: root.swToggle()
                }
            }
            Item { width: 1; height: 20 }
            Repeater {
                model: root.laps
                Item {
                    id: lrow
                    required property var modelData
                    width: parent.width; height: 44
                    Text {
                        text: "lap " + lrow.modelData.n; color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.font; font.pixelSize: 22
                    }
                    Text {
                        x: 90; anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtMs(lrow.modelData.split, true); color: Theme.text
                        font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtMs(lrow.modelData.total, true); color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 20
                    }
                }
            }
        }

        // ===== timer =====
        PivotPage {
            title: "timer"
            Item { width: 1; height: 12 }
            // picker (idle)
            Item {
                visible: root.tmState === "idle"
                width: parent.width; height: 192
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    NumberColumn { id: tmHPick; count: 100; width: 96; Component.onCompleted: set(root.tmH); onValueChanged: root.tmH = value }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "h"; color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 24; width: 24 }
                    NumberColumn { id: tmMPick; width: 96; Component.onCompleted: set(root.tmM); onValueChanged: root.tmM = value }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "m"; color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 24; width: 24 }
                    NumberColumn { id: tmSPick; width: 96; Component.onCompleted: set(root.tmS); onValueChanged: root.tmS = value }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "s"; color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 24; width: 24 }
                }
            }
            // countdown (running / paused)
            Item {
                visible: root.tmState !== "idle"
                width: parent.width; height: 192
                Text {
                    anchors.left: parent.left; anchors.right: parent.right
                    y: 24; height: 100
                    text: root.fmtCountdown(root.tmLeft)
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 84; font.weight: Theme.fontLight
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: 40
                    verticalAlignment: Text.AlignVCenter
                    opacity: root.tmState === "paused" ? 0.6 : 1
                }
                Rectangle { y: 140; width: parent.width; height: 8; color: Theme.dark ? "#333333" : "#cccccc" }
                Rectangle {
                    y: 140; height: 8; color: Theme.accent
                    width: parent.width * (root.tmTotal > 0 ? Math.max(0, Math.min(1, 1 - root.tmLeft / root.tmTotal)) : 0)
                }
            }
            Item { width: 1; height: 20 }
            Row {
                spacing: 12
                MetroButton {
                    text: "reset"
                    enabled2: root.tmState !== "idle"
                    onClicked: root.tmReset()
                }
                MetroButton {
                    text: root.tmState === "running" ? "pause" : (root.tmState === "paused" ? "resume" : "start")
                    accentFill: true
                    enabled2: root.tmState !== "idle" || (root.tmH + root.tmM + root.tmS) > 0
                    onClicked: root.tmToggle()
                }
            }
        }
    }

    // ---------- alarm editor ----------
    Item {
        id: editor
        visible: root.editing
        x: 0; y: root.topInset
        width: parent.width; height: parent.height - root.topInset - bar.collapsedH
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        Flickable {
            anchors.fill: parent
            contentWidth: width; contentHeight: edCol.implicitHeight + 32
            boundsBehavior: Flickable.StopAtBounds; clip: true
            Column {
                id: edCol
                x: 18; width: parent.width - 36
                Item { width: 1; height: 24 }
                Text { text: "CLOCK"; color: Theme.text; font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5 }
                Text {
                    text: root.editId < 0 ? "new alarm" : "edit alarm"
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
                }
                Item { width: 1; height: 12 }
                Item {
                    width: parent.width; height: 192
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        NumberColumn { id: hPick; count: 24 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; color: Theme.text
                            font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight }
                        NumberColumn { id: mPick; count: 60 }
                    }
                }
                Item { width: 1; height: 16 }
                MetroTextField {
                    id: labelField
                    width: parent.width
                    label: "label"; placeholder: "alarm"
                }
                Item { width: 1; height: 16 }
                Text { text: "repeat"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21 }
                Item { width: 1; height: 6 }
                Row {
                    id: dayRow
                    spacing: 4
                    readonly property real cw: Math.floor((edCol.width - 6 * 4) / 7)
                    Repeater {
                        model: 7
                        Item {
                            id: dcell
                            required property int index
                            width: dayRow.cw; height: 56
                            readonly property bool sel: root.editDays[index]
                            Rectangle {
                                anchors.fill: parent
                                color: dcell.sel ? Theme.accent : "transparent"
                                border.width: 2; border.color: dcell.sel ? Theme.accent : Theme.text
                            }
                            Text {
                                anchors.centerIn: parent
                                text: root.dayNames[dcell.index].charAt(0).toUpperCase()
                                color: dcell.sel ? Theme.onColor(Theme.accent) : Theme.text
                                font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { var d = root.editDays.slice(); d[dcell.index] = !d[dcell.index]; root.editDays = d }
                            }
                        }
                    }
                }
                Text {
                    topPadding: 6
                    text: root.daysText(root.editDays)
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
                }
            }
        }
    }

    // ---------- add city ----------
    Item {
        id: cityPicker
        visible: root.adding
        x: 0; y: root.topInset
        width: parent.width; height: parent.height - root.topInset - bar.collapsedH
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        Column {
            id: cpHead
            x: 18; width: parent.width - 36
            Item { width: 1; height: 24 }
            Text { text: "CLOCK"; color: Theme.text; font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5 }
            Text {
                text: "add city"; color: Theme.text
                font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight; font.letterSpacing: -1.5
            }
            Item { width: 1; height: 8 }
            MetroTextField {
                width: parent.width
                placeholder: "search"
                text: root.cityFilter
                onEdited: root.cityFilter = text.toLowerCase()
            }
            Item { width: 1; height: 8 }
        }
        ListView {
            id: cityList
            x: 18; y: cpHead.height
            width: parent.width - 36; height: parent.height - cpHead.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: {
                var have = {}
                for (var i = 0; i < root.worldCities.length; ++i) have[root.worldCities[i].name] = true
                return root.cityDb.filter(function(c) {
                    return !have[c.name] && (root.cityFilter === "" || c.name.toLowerCase().indexOf(root.cityFilter) >= 0)
                })
            }
            delegate: MetroListRow {
                required property var modelData
                width: cityList.width
                title: modelData.name
                subtitle: root.offText(modelData.off)
                onClicked: root.addCity(modelData)
            }
            footer: Text {
                visible: cityList.count === 0
                width: cityList.width; topPadding: 8
                text: "no more cities"; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
        }
    }

    // ---------- app bar ----------
    AppBar {
        id: bar
        visible: root.appBarShown
        anchors.bottom: parent.bottom
        items: root.editing ? [{ glyph: "forward", label: "save" }, { glyph: "close", label: "cancel" }]
             : (root.adding ? [{ glyph: "close", label: "cancel" }]
             : [{ glyph: "plus", label: "add" }])
        menuItems: (root.editing && root.editId >= 0) ? ["delete"] : []
        onActivated: (i) => {
            if (root.editing) { if (i === 0) root.commitEditor(); else root.editing = false }
            else if (root.adding) { root.adding = false; root.cityFilter = "" }
            else if (pivot.currentIndex === 0) root.openEditor(-1)
            else if (pivot.currentIndex === 1) { root.armedCity = -1; root.adding = true }
        }
        onMenuActivated: (i) => { if (root.editing && i === 0) root.deleteEdited() }
    }

    // ---------- ring banner ----------
    Rectangle {
        id: banner
        visible: root.rings.length > 0
        x: 0; y: root.topInset
        width: parent.width; height: bcol.implicitHeight + 24
        color: Theme.accent
        MouseArea { anchors.fill: parent }
        Column {
            id: bcol
            x: 18; y: 12; width: parent.width - 36
            spacing: 4
            Text {
                width: parent.width
                text: root.rings.length > 0 ? (root.rings[0].kind === "alarm" ? "alarm" : "timer") : ""
                color: Theme.onColor(Theme.accent)
                font.family: Theme.font; font.pixelSize: 21; font.letterSpacing: 0.5
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.rings.length > 0 ? root.rings[0].text : ""
                color: Theme.onColor(Theme.accent)
                font.family: Theme.font; font.pixelSize: 40; font.weight: Theme.fontLight
            }
            Row {
                spacing: 12
                topPadding: 8
                Item {
                    width: 140; height: 52
                    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Theme.onColor(Theme.accent) }
                    Text { anchors.centerIn: parent; text: "dismiss"; color: Theme.onColor(Theme.accent)
                        font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight }
                    MouseArea { anchors.fill: parent; onClicked: root.dismissRing() }
                }
                Item {
                    visible: root.rings.length > 0 && root.rings[0].kind === "alarm"
                    width: 160; height: 52
                    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Theme.onColor(Theme.accent) }
                    Text { anchors.centerIn: parent; text: "snooze 5 min"; color: Theme.onColor(Theme.accent)
                        font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight }
                    MouseArea { anchors.fill: parent; onClicked: root.snoozeRing() }
                }
            }
        }
    }
}
