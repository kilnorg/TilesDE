import QtQuick
import FlowShell

// Calendar: pivot "agenda" / "month", plus a full-height event editor that slides over the pivot.
// Store key "calendar-events": [{id, title, date "yyyy-MM-dd", start "HH:mm"|"" (all-day), end, place, notes}]
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var events: []
    property string todayStr: ""
    property int viewYear: 2026
    property int viewMonth: 0          // 0..11
    property string selected: ""
    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July",
                                       "August", "September", "October", "November", "December"]

    // ---- date helpers
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function fmt(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function parseD(s) { var p = String(s).split("-"); return new Date(+p[0], +p[1] - 1, +p[2]) }
    function hhmm(min) { return pad(Math.floor(min / 60)) + ":" + pad(min % 60) }
    function toMin(s) { var p = String(s).split(":"); return (+p[0]) * 60 + (+p[1]) }
    function dayLabel(s) {
        if (s === todayStr) return "today"
        var d = parseD(s), t = parseD(todayStr)
        if (isNaN(d) || isNaN(t)) return String(s)
        if (Math.round((d - t) / 86400000) === 1) return "tomorrow"
        return dayNames[d.getDay()] + " " + d.getDate() + " " + monthNames[d.getMonth()].substring(0, 3)
    }
    function longDate(s) {
        var d = parseD(s)
        if (isNaN(d)) return String(s)
        return dayNames[d.getDay()] + " " + d.getDate() + " " + monthNames[d.getMonth()].substring(0, 3) + " " + d.getFullYear()
    }
    function timeText(ev) {
        if (!ev.start) return "all day"
        return ev.start + (ev.end ? " - " + ev.end : "")
    }
    function subtitleOf(ev) { return timeText(ev) + (ev.place ? "  ·  " + ev.place : "") }
    function cmp(a, b) {
        if (a.date !== b.date) return a.date < b.date ? -1 : 1
        if (a.start !== b.start) return a.start < b.start ? -1 : 1
        return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0)
    }

    // ---- derived data
    function buildAgenda(list) {
        var up = list.filter(function(e) { return e.date >= todayStr }).sort(cmp)
        var groups = [], cur = null
        for (var i = 0; i < up.length; ++i) {
            if (!cur || cur.date !== up[i].date) { cur = { date: up[i].date, label: dayLabel(up[i].date), items: [] }; groups.push(cur) }
            cur.items.push(up[i])
        }
        return groups
    }
    function eventsOn(date, list) { return list.filter(function(e) { return e.date === date }).sort(cmp) }
    function dateSet(list) { var o = {}; for (var i = 0; i < list.length; ++i) o[list[i].date] = true; return o }
    property var agenda: buildAgenda(events)
    property var withEvents: dateSet(events)
    property var selEvents: eventsOn(selected, events)

    // ---- persistence
    function persist() { AppStore.save("calendar-events", events) }
    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36) }
    function upsert(ev) {
        var list = events.slice(), found = false
        for (var i = 0; i < list.length; ++i) if (list[i].id === ev.id) { list[i] = ev; found = true }
        if (!found) list.push(ev)
        events = list; persist()
    }
    function remove(id) { events = events.filter(function(e) { return e.id !== id }); persist() }

    Component.onCompleted: {
        var now = new Date()
        todayStr = fmt(now)
        selected = todayStr
        viewYear = now.getFullYear(); viewMonth = now.getMonth()
        var l = AppStore.load("calendar-events", [])
        if (!Array.isArray(l)) l = []
        if (l.length === 0 && Sys.demoData) {
            var tm = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
            l = [
                { id: newId(), title: "Demo event: welcome to calendar", date: todayStr, start: "", end: "", place: "", notes: "Sample entry, tap to edit or delete." },
                { id: newId(), title: "Demo event: sample meeting", date: fmt(tm), start: "10:00", end: "11:00", place: "Somewhere", notes: "" }
            ]
            events = l; persist()
        } else events = l
    }

    function shiftMonth(n) {
        var d = new Date(viewYear, viewMonth + n, 1)
        viewYear = d.getFullYear(); viewMonth = d.getMonth()
    }
    function goToday() {
        var now = new Date()
        todayStr = fmt(now); selected = todayStr
        viewYear = now.getFullYear(); viewMonth = now.getMonth()
    }

    // ---- editor state
    property string edId: ""
    property string edDate: ""
    property bool edAllDay: false
    property int edStart: 540
    property int edEnd: 600
    property bool edConfirmDelete: false
    property bool editorOpen: false

    function openEditor(ev, date) {
        edConfirmDelete = false
        if (ev) {
            edId = ev.id; edDate = ev.date
            titleF.text = ev.title; placeF.text = ev.place; notesF.text = ev.notes
            edAllDay = !ev.start
            edStart = ev.start ? toMin(ev.start) : 540
            edEnd = ev.end ? toMin(ev.end) : Math.min(1439, edStart + 60)
        } else {
            edId = ""; edDate = date || selected || todayStr
            titleF.text = ""; placeF.text = ""; notesF.text = ""
            edAllDay = false; edStart = 540; edEnd = 600
        }
        form.contentY = 0
        editorOpen = true
    }
    function closeEditor() { editorOpen = false }
    function saveEditor() {
        var t = titleF.text.trim()
        if (t === "") t = "untitled event"
        var en = Math.max(edStart, edEnd)
        upsert({ id: edId !== "" ? edId : newId(), title: t, date: edDate,
                 start: edAllDay ? "" : hhmm(edStart), end: edAllDay ? "" : hhmm(en),
                 place: placeF.text.trim(), notes: notesF.text.trim() })
        var d = parseD(edDate)
        selected = edDate; viewYear = d.getFullYear(); viewMonth = d.getMonth()
        closeEditor()
    }
    function deleteEditor() {
        if (edId === "") { closeEditor(); return }
        if (!edConfirmDelete) { edConfirmDelete = true; return }
        remove(edId); closeEditor()
    }
    function stepDay(n) { var d = parseD(edDate); d.setDate(d.getDate() + n); edDate = fmt(d) }
    function stepMonth(n) {
        var d = parseD(edDate), day = d.getDate()
        var t = new Date(d.getFullYear(), d.getMonth() + n, 1)
        var dim = new Date(t.getFullYear(), t.getMonth() + 1, 0).getDate()
        edDate = fmt(new Date(t.getFullYear(), t.getMonth(), Math.min(day, dim)))
    }
    function stepHour(v, n) { return ((v + n * 60) % 1440 + 1440) % 1440 }
    function stepMinute(v, n) { var h = Math.floor(v / 60); return h * 60 + (((v % 60) + n * 5) % 60 + 60) % 60 }

    function back() { if (editorOpen) closeEditor(); else closeRequested() }
    focus: true
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    component Stepper: Item {
        id: st
        property string label: ""
        property string value: ""
        signal minus
        signal plus
        implicitHeight: 28 + 52
        Text {
            text: st.label; color: Theme.textDim
            font.family: Theme.font; font.pixelSize: 21
        }
        Item {
            y: 28; width: parent.width; height: 52
            Rectangle {
                id: mBtn; width: 52; height: 52; color: mMa.pressed ? Theme.text : "transparent"
                border.width: 2; border.color: Theme.text
                Text { anchors.centerIn: parent; text: "−"; color: mMa.pressed ? Theme.pageBg : Theme.text
                    font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight }
                MouseArea { id: mMa; anchors.fill: parent; onClicked: st.minus() }
            }
            Text {
                anchors.left: mBtn.right; anchors.right: pBtn.left; height: parent.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: st.value; color: Theme.text; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Rectangle {
                id: pBtn; width: 52; height: 52; anchors.right: parent.right
                color: pMa.pressed ? Theme.text : "transparent"
                border.width: 2; border.color: Theme.text
                Text { anchors.centerIn: parent; text: "+"; color: pMa.pressed ? Theme.pageBg : Theme.text
                    font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight }
                MouseArea { id: pMa; anchors.fill: parent; onClicked: st.plus() }
            }
        }
    }

    // ---- main pivot
    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - 72
        caption: "calendar"

        PivotPage {
            title: "agenda"

            Item {
                visible: root.agenda.length === 0
                width: parent.width; height: 120
                Text {
                    y: 24; width: parent.width; wrapMode: Text.WordWrap
                    text: "nothing coming up. tap new to add an event."
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                }
            }
            Repeater {
                model: root.agenda
                Column {
                    id: grp
                    required property var modelData
                    width: parent.width
                    MetroSectionHeader { text: grp.modelData.label; accent: grp.modelData.date === root.todayStr }
                    Repeater {
                        model: grp.modelData.items
                        MetroListRow {
                            required property var modelData
                            title: modelData.title
                            subtitle: root.subtitleOf(modelData)
                            onClicked: root.openEditor(modelData)
                        }
                    }
                }
            }
        }

        PivotPage {
            title: "month"

            // month header with chevrons
            Item {
                width: parent.width; height: 56
                Item {
                    width: 56; height: 56
                    opacity: prevMa.pressed ? 0.5 : 1
                    TileGlyph { anchors.centerIn: parent; name: "back"; size: 28; color: Theme.text }
                    MouseArea { id: prevMa; anchors.fill: parent; onClicked: root.shiftMonth(-1) }
                }
                Text {
                    anchors.centerIn: parent; width: parent.width - 120; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Theme.title(root.monthNames[root.viewMonth] + " " + root.viewYear)
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 28; font.weight: Theme.fontLight
                }
                Item {
                    width: 56; height: 56; anchors.right: parent.right
                    opacity: nextMa.pressed ? 0.5 : 1
                    TileGlyph { anchors.centerIn: parent; name: "forward"; size: 28; color: Theme.text }
                    MouseArea { id: nextMa; anchors.fill: parent; onClicked: root.shiftMonth(1) }
                }
            }
            // weekday header (Monday first)
            Row {
                width: parent.width
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Text {
                        required property string modelData
                        width: Math.floor(parent.width / 7); height: 32
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData; color: Theme.textDim
                        font.family: Theme.font; font.pixelSize: 20
                    }
                }
            }
            Grid {
                id: grid
                columns: 7
                readonly property real cell: Math.floor(width / 7)
                width: parent.width
                readonly property int offset: (new Date(root.viewYear, root.viewMonth, 1).getDay() + 6) % 7
                Repeater {
                    model: 42
                    Item {
                        id: cellItem
                        required property int index
                        readonly property date d: new Date(root.viewYear, root.viewMonth, 1 - grid.offset + index)
                        readonly property string key: root.fmt(d)
                        readonly property bool inMonth: d.getMonth() === root.viewMonth
                        readonly property bool isToday: key === root.todayStr
                        readonly property bool isSel: key === root.selected
                        readonly property bool hasEv: root.withEvents[key] === true
                        width: grid.cell; height: grid.cell
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2
                            color: cellItem.isToday ? Theme.accent : "transparent"
                            border.width: cellItem.isSel ? 2 : 0
                            border.color: Theme.text
                            opacity: cellItem.inMonth ? 1 : 0.35
                            Text {
                                anchors.centerIn: parent; anchors.verticalCenterOffset: -3
                                text: cellItem.d.getDate()
                                color: cellItem.isToday ? Theme.onColor(Theme.accent) : Theme.text
                                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                            }
                            Rectangle {
                                visible: cellItem.hasEv
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height - 10; width: parent.width * 0.5; height: 4
                                color: cellItem.isToday ? Theme.onColor(Theme.accent) : Theme.accent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.selected = cellItem.key
                                if (!cellItem.inMonth) { root.viewYear = cellItem.d.getFullYear(); root.viewMonth = cellItem.d.getMonth() }
                            }
                        }
                    }
                }
            }
            MetroSectionHeader { text: root.selected !== "" ? root.longDate(root.selected) : "" }
            Text {
                visible: root.selEvents.length === 0
                width: parent.width; height: 48
                text: "no events"; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.selEvents
                MetroListRow {
                    required property var modelData
                    title: modelData.title
                    subtitle: root.subtitleOf(modelData)
                    onClicked: root.openEditor(modelData)
                }
            }
        }
    }

    AppBar {
        id: bar
        anchors.bottom: parent.bottom
        items: pivot.currentIndex === 1
            ? [{ glyph: "plus", label: "new" }, { glyph: "back", label: "previous" }, { glyph: "forward", label: "next" }]
            : [{ glyph: "plus", label: "new" }]
        menuItems: ["today"]
        onActivated: (i) => {
            if (i === 0) root.openEditor(null, pivot.currentIndex === 1 ? root.selected : root.todayStr)
            else if (i === 1) root.shiftMonth(-1)
            else if (i === 2) root.shiftMonth(1)
        }
        onMenuActivated: (i) => root.goToday()
    }

    // ---- editor sub-view
    Item {
        id: editor
        width: root.width; height: root.height
        property real p: root.editorOpen ? 1 : 0
        Behavior on p { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.turnstileMs; easing.type: Easing.OutCubic } }
        visible: p > 0.005
        opacity: Math.min(1, p * 3)
        x: (1 - p) * 60
        transform: Rotation {
            origin.x: 0; origin.y: editor.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: Theme.reduceMotion ? 0 : -60 * (1 - editor.p)
        }
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }

        Flickable {
            id: form
            y: root.topInset; width: parent.width; height: parent.height - root.topInset
            contentWidth: width; contentHeight: fcol.implicitHeight + 40
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Column {
                id: fcol
                x: 18; width: form.width - 36
                spacing: 18
                Text {
                    width: parent.width; elide: Text.ElideRight; topPadding: 16
                    text: Theme.title(root.edId === "" ? "new event" : "edit event")
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
                }
                MetroTextField { id: titleF; width: parent.width; label: "title" }
                Stepper {
                    width: parent.width; label: "date"; value: root.longDate(root.edDate)
                    onMinus: root.stepDay(-1); onPlus: root.stepDay(1)
                }
                Stepper {
                    width: parent.width; label: "month"
                    value: root.edDate !== "" ? root.monthNames[root.parseD(root.edDate).getMonth()] + " " + root.parseD(root.edDate).getFullYear() : ""
                    onMinus: root.stepMonth(-1); onPlus: root.stepMonth(1)
                }
                MetroToggle {
                    width: parent.width; label: "all day"; onText: "Yes"; offText: "No"
                    checked: root.edAllDay
                    onToggled: (v) => root.edAllDay = v
                }
                Column {
                    visible: !root.edAllDay
                    width: parent.width; spacing: 18
                    Row {
                        spacing: 16
                        Stepper {
                            width: (fcol.width - 16) / 2; label: "start hour"; value: root.pad(Math.floor(root.edStart / 60))
                            onMinus: root.edStart = root.stepHour(root.edStart, -1); onPlus: root.edStart = root.stepHour(root.edStart, 1)
                        }
                        Stepper {
                            width: (fcol.width - 16) / 2; label: "start min"; value: root.pad(root.edStart % 60)
                            onMinus: root.edStart = root.stepMinute(root.edStart, -1); onPlus: root.edStart = root.stepMinute(root.edStart, 1)
                        }
                    }
                    Row {
                        spacing: 16
                        Stepper {
                            width: (fcol.width - 16) / 2; label: "end hour"; value: root.pad(Math.floor(root.edEnd / 60))
                            onMinus: root.edEnd = root.stepHour(root.edEnd, -1); onPlus: root.edEnd = root.stepHour(root.edEnd, 1)
                        }
                        Stepper {
                            width: (fcol.width - 16) / 2; label: "end min"; value: root.pad(root.edEnd % 60)
                            onMinus: root.edEnd = root.stepMinute(root.edEnd, -1); onPlus: root.edEnd = root.stepMinute(root.edEnd, 1)
                        }
                    }
                }
                MetroTextField { id: placeF; width: parent.width; label: "place" }
                MetroTextField { id: notesF; width: parent.width; label: "notes" }
                Row {
                    spacing: 12
                    MetroButton { text: "save"; accentFill: true; onClicked: root.saveEditor() }
                    MetroButton { text: "cancel"; onClicked: root.closeEditor() }
                    MetroButton {
                        visible: root.edId !== ""
                        text: root.edConfirmDelete ? "sure?" : "delete"
                        onClicked: root.deleteEditor()
                    }
                }
                Item { width: 1; height: 24 }
            }
        }
    }
}
