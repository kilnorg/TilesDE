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
        // people: a stored contact (favourite first)
        const real = _arr("contacts").filter(c => c.name)
        const pc = real.filter(c => c.fav)[0] || real[0]
        set("people", pc ? { title: pc.name, subtitle: (pc.numbers && pc.numbers.length ? pc.numbers[0].number : "") || pc.email || "" } : { title: "", subtitle: "" })
        _photos()
    }

    // photos: newest picture under ~/Pictures (real files only; rescans at most every 5 minutes)
    property double _photosAt: 0
    function _photos() {
        const nowMs = Date.now()
        if (nowMs - _photosAt < 300000 && _photosAt > 0) return
        _photosAt = nowMs
        let list = []
        if (typeof Sys !== "undefined") {
            const dir = Sys.home() + "/Pictures"
            if (Sys.exists(dir)) list = _list(Sys.listDir(dir, ["jpg", "jpeg", "png", "webp"], true, 300))
        }
        list.sort((a, b) => b.modified - a.modified)
        set("photos", list.length ? { title: "Photos", subtitle: list.length + (list.length === 1 ? " photo" : " photos"), imageSource: list[0].path } : { title: "", subtitle: "" })
    }

    // ---- weather (Open-Meteo, keyless). Cache in AppStore "weather-cache" {key: {at, cur, days, hours}}; places in "weather-places".
    // Place: {name, lat, lon} or {auto: true, name?, lat?, lon?} (located by IP at most every 6 h). Stale cache stays usable offline.
    property var weather: ({})
    property string weatherStatus: ""     // "", "loading", "offline"
    signal weatherUpdated
    function wxText(c) {
        if (c === 0) return "clear"
        if (c <= 2) return "partly cloudy"
        if (c === 3) return "cloudy"
        if (c === 45 || c === 48) return "fog"
        if (c >= 51 && c <= 57) return "drizzle"
        if (c === 61 || c === 63 || c === 80 || c === 81) return "rain"
        if (c === 65 || c === 82) return "heavy rain"
        if (c === 66 || c === 67) return "freezing rain"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow"
        if (c >= 95) return "storm"
        return "cloudy"
    }
    function wxKey(p) { return p.lat.toFixed(2) + "," + p.lon.toFixed(2) }
    function wxFor(p) { return p && p.lat !== undefined ? (weather[wxKey(p)] || null) : null }
    function _get(url, cb) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== 4) return
            let j = null
            if (x.status === 200) { try { j = JSON.parse(x.responseText) } catch (e) { j = null } }
            cb(j)
        }
        x.timeout = 20000
        x.ontimeout = function() { }
        x.open("GET", url)
        x.send()
    }
    function wxSearch(q, cb) {
        _get("https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name=" + encodeURIComponent(q), function(j) {
            cb(j && j.results ? j.results.map(function(r) {
                return { name: r.name, sub: [r.admin1, r.country].filter(function(v) { return v }).join(", "), lat: r.latitude, lon: r.longitude }
            }) : null)
        })
    }
    function wxLocate(p, cb) {
        if (p.lat !== undefined && Date.now() - (p.locAt || 0) < 6 * 3600000) { cb(p); return }
        _get("https://ipwho.is/", function(j) {
            if (j && j.success !== false && j.latitude !== undefined)
                cb(Object.assign({}, p, { name: j.city || "Here", lat: j.latitude, lon: j.longitude, locAt: Date.now() }))
            else cb(p.lat !== undefined ? p : null)
        })
    }
    function wxFetch(p, force, done) {
        if (!p || p.lat === undefined) { if (done) done(false); return }
        const k = wxKey(p), c = weather[k]
        if (!force && c && Date.now() - c.at < 25 * 60000) { if (done) done(true); return }
        const u = "https://api.open-meteo.com/v1/forecast?latitude=" + p.lat + "&longitude=" + p.lon +
            "&current=temperature_2m,apparent_temperature,relative_humidity_2m,surface_pressure,wind_speed_10m,weather_code" +
            "&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code,uv_index_max" +
            "&timezone=auto&forecast_days=8"
        weatherStatus = "loading"
        _get(u, function(j) {
            if (!j || !j.current || !j.daily || !j.hourly) { weatherStatus = "offline"; weatherUpdated(); if (done) done(false); return }
            const d = j.daily, h = j.hourly, cur = j.current, out = { at: Date.now(), days: [], hours: [] }
            for (let i = 0; i < d.time.length; ++i)
                out.days.push({ date: d.time[i], hi: d.temperature_2m_max[i], lo: d.temperature_2m_min[i], code: d.weather_code[i], uv: d.uv_index_max[i] })
            const nowIso = cur.time
            let s = 0
            for (let i = 0; i < h.time.length; ++i) if (h.time[i] >= nowIso.slice(0, 13)) { s = i; break }
            for (let i = s; i < Math.min(s + 24, h.time.length); ++i)
                out.hours.push({ hh: h.time[i].slice(11, 13), temp: h.temperature_2m[i], code: h.weather_code[i] })
            out.cur = { temp: cur.temperature_2m, feels: cur.apparent_temperature, hum: cur.relative_humidity_2m, pres: cur.surface_pressure,
                        wind: cur.wind_speed_10m, code: cur.weather_code, hi: d.temperature_2m_max[0], lo: d.temperature_2m_min[0], uv: d.uv_index_max[0] }
            const w = Object.assign({}, weather); w[k] = out
            // keep only the 12 newest places
            const ks = Object.keys(w).sort(function(a, b) { return w[b].at - w[a].at }).slice(0, 12), w2 = {}
            ks.forEach(function(x) { w2[x] = w[x] })
            weather = w2
            AppStore.save("weather-cache", weather)
            weatherStatus = ""
            weatherUpdated()
            _weatherTile()
            if (done) done(true)
        })
    }
    // selected place of the Weather app (resolving "my location"), then fetch + update the tile
    function weatherRefresh(force) {
        const s = AppStore.load("weather-places", null)
        const list = s && s.places ? _list(s.places) : []
        if (!list.length) { _weatherTile(); return }
        const i = Math.max(0, Math.min(s.selected | 0, list.length - 1)), p = list[i]
        if (p && p.auto) {
            wxLocate(p, function(r) {
                if (!r) { weatherStatus = "offline"; _weatherTile(); return }
                if (r.lat !== p.lat) {
                    const l2 = list.slice(); l2[i] = r
                    AppStore.save("weather-places", Object.assign({}, s, { places: l2 }))
                }
                wxFetch(r, force)
            })
        } else wxFetch(p, force)
    }
    function _weatherTile() {
        const s = AppStore.load("weather-places", null), list = s && s.places ? _list(s.places) : []
        const p = list.length ? list[Math.max(0, Math.min(s.selected | 0, list.length - 1))] : null
        const w = wxFor(p), f = s && s.unit === "F"
        if (!w || !w.cur) { set("weather", { title: "", subtitle: "" }); return }
        const t = function(c) { return Math.round(f ? c * 9 / 5 + 32 : c) + "\u00b0" }
        set("weather", { title: p.name + ", " + wxText(w.cur.code), subtitle: "\u2191" + t(w.cur.hi) + " \u2193" + t(w.cur.lo), big: t(w.cur.temp) })
    }
    property Timer _wx: Timer { interval: 30 * 60000; running: true; repeat: true; onTriggered: root.weatherRefresh(false) }

    // ---- clock service: alarms / timer fire here (always running), not only while the Clock app is open ----
    // Stores: "clock-alarms" [{id,h,m,label,days,on}], "clock-timer" {state:"running",end,total}|{state:"paused",left,total}.
    // Ringing = pending `rings` list ([{kind,text,alarmId}]) + a notification + looping sound until the Clock app (or lock/notif) dismisses.
    property var rings: []
    property var _snoozes: []
    property double _clkStamp: -1
    property var _tm: null
    property int _beeps: 0
    signal ringFired
    function _loadTimer() { const t = AppStore.load("clock-timer", null); _tm = t && !Array.isArray(t) ? t : null }
    function ringPush(kind, text, id) {
        rings = rings.concat([{ kind: kind, text: text, alarmId: id }])
        Services.notifications.add("clock", kind === "alarm" ? "Alarm" : "Timer", text)
        _beeps = 0; _beep.restart(); _beepNow()
        ringFired()
    }
    function ringPop() { rings = rings.slice(1); if (!rings.length) _beep.stop() }
    function snoozeFirst() {
        const r = rings[0]
        if (!r) return
        if (r.kind === "alarm") _snoozes = _snoozes.concat([{ alarmId: r.alarmId, text: r.text, until: Date.now() + 5 * 60000 }])
        ringPop()
    }
    function _beepNow() {
        if (typeof Sys === "undefined") return
        const f = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        if (Sys.exists(f)) Sys.launch("paplay", [f])
    }
    property Timer _beep: Timer { interval: 3500; repeat: true; onTriggered: { if (++root._beeps > 30 || !root.rings.length) stop(); else root._beepNow() } }
    function _clockCheck(d) {
        const hh = d.getHours(), mm = d.getMinutes(), dow = (d.getDay() + 6) % 7
        const list = _arr("clock-alarms"); let changed = false
        const out = list.map(function(a) {
            if (!a.on || a.h !== hh || a.m !== mm) return a
            const days = _list(a.days), rep = days.some(function(x) { return x })
            if (rep && !days[dow]) return a
            ringPush("alarm", a.label ? a.label : "alarm", a.id)
            if (!rep) { changed = true; const c = Object.assign({}, a); c.on = false; return c }
            return a
        })
        if (changed) AppStore.save("clock-alarms", out)
        // calendar events starting now, and a 09:00 digest of reminders due today or overdue
        const today = _ds(d), hm = _p2(hh) + ":" + _p2(mm)
        _arr("calendar-events").forEach(function(e) {
            if (e.date === today && e.start === hm) Services.notifications.add("calendar", e.title, e.start + (e.place ? " \u00b7 " + e.place : ""))
        })
        if (hh === 9 && mm === 0) {
            const rd = _arr("reminders").filter(function(r) { return !r.done && r.due && r.due <= today })
            if (rd.length) Services.notifications.add("reminders", rd.length === 1 ? rd[0].title : rd.length + " reminders due", rd.length === 1 ? "Due today" : rd[0].title + ", ...")
        }
    }
    function _clockTick() {
        const now = Date.now(), stamp = Math.floor(now / 60000)
        if (stamp !== _clkStamp) {
            const d = new Date(now)
            if (_clkStamp >= 0 || d.getSeconds() < 3) _clockCheck(d)
            _clkStamp = stamp
        }
        if (_snoozes.length) {
            const keep = []
            _snoozes.forEach(function(sn) { if (now >= sn.until) ringPush("alarm", sn.text, sn.alarmId); else keep.push(sn) })
            if (keep.length !== _snoozes.length) _snoozes = keep
        }
        if (_tm && _tm.state === "running" && now >= _tm.end) {
            _tm = null
            AppStore.save("clock-timer", { state: "idle" })
            ringPush("timer", "timer finished", -1)
        }
    }
    property Timer _clk: Timer { interval: 1000; running: true; repeat: true; onTriggered: root._clockTick() }

    property Connections _notifs: Connections { target: Services.notifications; function onCountChanged() { root._soon.restart() } }
    property Timer _tick: Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh() }
    property Timer _soon: Timer { interval: 400; onTriggered: root.refresh() }
    Component.onCompleted: {
        const v = AppStore.load("livetiles", {})
        tiles = (v && !Array.isArray(v)) ? v : {}
        AppStore.saved.connect(function(app) { if (app === "clock-timer") root._loadTimer(); if (app !== "livetiles") root._soon.restart() })
        _loadTimer()
        _clkStamp = Math.floor(Date.now() / 60000)
        const wc = AppStore.load("weather-cache", {})
        weather = (wc && !Array.isArray(wc)) ? wc : {}
        refresh()
        weatherRefresh(false)
    }
}
