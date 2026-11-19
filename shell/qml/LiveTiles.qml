pragma Singleton
import QtQuick
import FlowShell

// Live-tile data store. Apps publish what their tile shows: LiveTiles.set("mail", { title, subtitle, badge, imageSource [, big] }).
// Persisted in AppStore key "livetiles" so tiles show real data right after boot. The built-in apps are covered by refresh(),
// which derives their tiles from the apps' own stores (calendar-events, mail, messages + contacts, reminders, clock-alarms);
// it runs every 60 s and shortly after any AppStore save. StartScreen/TileFaces read get(id) and listen to `changed`.
QtObject {
    id: root
    property var tiles: ({})
    signal changed

    function get(id) { return tiles[id === "messages" ? "message" : id] || null }
    function set(id, data) {
        const t = Object.assign({}, tiles)
        t[id] = { title: data.title || "", subtitle: data.subtitle || "", badge: data.badge | 0, imageSource: data.imageSource || "", big: data.big === undefined ? "" : String(data.big) }
        if (JSON.stringify(t[id]) === JSON.stringify(tiles[id])) return
        tiles = t
        AppStore.save("livetiles", tiles)
        changed()
    }

    // AppStore lists arrive as QVariantList wrappers (Array.isArray is false): copy into a real array
    function _list(v) { return (v && typeof v === "object" && typeof v.length === "number") ? Array.prototype.slice.call(v) : [] }
    function _arr(k) { return _list(AppStore.load(k, [])) }
    function _p2(n) { return (n < 10 ? "0" : "") + n }
    function _ds(d) { return d.getFullYear() + "-" + _p2(d.getMonth() + 1) + "-" + _p2(d.getDate()) }

    function _nc(app) { return Services.notifications.counts[app] || 0 }

    function refresh() {
        const now = new Date(), today = _ds(now), nowKey = today + " " + _p2(now.getHours()) + ":" + _p2(now.getMinutes())
        // calendar: next upcoming event (all-day events count for today)
        const ev = _arr("calendar-events").filter(e => e.date > today || (e.date === today && (!e.start || (e.date + " " + e.start) >= nowKey)))
            .sort((a, b) => (a.date + " " + (a.start || "00:00")).localeCompare(b.date + " " + (b.start || "00:00")))[0]
        set("calendar", ev ? { title: ev.title, subtitle: (ev.date === today ? "" : ev.date.slice(5) + " ") + (ev.start || "all day") } : { title: "", subtitle: "" })
        // mail: unread count + newest unread subject
        const ms = AppStore.load("mail", null), un = _list(ms ? ms.msgs : null).filter(m => !m.read).sort((a, b) => b.ts - a.ts)
        set("mail", { title: un.length ? un[0].subject : "Inbox", subtitle: un.length ? un[0].from : "No unread", badge: Math.max(un.length, _nc("mail")), big: un.length ? un.length : "" })
        // messages: unread total + newest unread thread
        const names = {}; _arr("contacts").forEach(c => names[c.id] = c.name)
        const th = _arr("messages").filter(t => (t.unread | 0) > 0)
        let n = 0; th.forEach(t => n += t.unread | 0)
        const last = th.length ? th[0] : null, li = last && last.items && last.items.length ? last.items[last.items.length - 1] : null
        set("message", { title: last ? (names[last.thread] || last.thread) : "Messages", subtitle: li ? li.text : "No unread", badge: Math.max(n, _nc("messages")), big: n ? n : "" })
        // phone: missed-call notifications posted by the dialer (app name "Phone")
        const pn = _nc("phone"), N = Services.notifications
        set("phone", { title: pn ? N.latestTitle("phone") : "Phone", subtitle: pn ? N.latestBody("phone") : "No missed calls", badge: pn, big: pn ? pn : "" })
        // reminders: open items due today or overdue
        const rd = _arr("reminders").filter(r => !r.done && r.due && r.due <= today)
        set("reminders", { title: rd.length ? rd[0].title : "Reminders", subtitle: rd.length ? rd.length + " due today" : "Nothing due", badge: rd.length, big: rd.length ? rd.length : "" })
        // clock: next enabled alarm (days = [bool x7 Mon..Sun], none ticked = every day)
        let best = null
        _arr("clock-alarms").filter(a => a.on).forEach(a => {
            const days = _list(a.days), rep = days.some(x => x)
            for (let d = 0; d < 8; ++d) {
                const c = new Date(now.getFullYear(), now.getMonth(), now.getDate() + d, a.h, a.m)
                if (c <= now || (rep && !days[(c.getDay() + 6) % 7])) continue
                if (!best || c < best.at) best = { at: c, label: a.label }
                break
            }
        })
        set("clock", best ? { title: Qt.formatTime(best.at, "hh:mm"), subtitle: (best.label || "Next alarm") + ", " + Qt.formatDate(best.at, "ddd") } : { title: "No alarm", subtitle: "" })
    }

    property Connections _notifs: Connections { target: Services.notifications; function onCountChanged() { root._soon.restart() } }
    property Timer _tick: Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh() }
    property Timer _soon: Timer { interval: 400; onTriggered: root.refresh() }
    Component.onCompleted: {
        const v = AppStore.load("livetiles", {})
        tiles = (v && !Array.isArray(v)) ? v : {}
        AppStore.saved.connect(function(app) { if (app !== "livetiles") root._soon.restart() })
        refresh()
    }
}
