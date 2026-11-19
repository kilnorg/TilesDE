import QtQuick
import FlowShell

// Weather app. Real data from Open-Meteo (keyless) via LiveTiles.weatherRefresh/wxSearch; cached on disk, stale cache shown offline.
// Places persisted in AppStore "weather-places": {places:[{name,lat,lon} | {auto:true,...}], unit, selected}.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var places: []
    property string unit: "C"
    property int selected: 0
    property int rev: 0
    readonly property var place: places.length > 0 ? places[Math.max(0, Math.min(selected, places.length - 1))] : null
    readonly property var wx: { rev; return LiveTiles.wxFor(place) }
    readonly property string city: place ? (place.name || "my location") : ""
    readonly property var now: wx && wx.cur ? { temp: wx.cur.temp, feels: wx.cur.feels, hi: wx.cur.hi, lo: wx.cur.lo,
        condition: LiveTiles.wxText(wx.cur.code), wind: wx.cur.wind, humidity: wx.cur.hum, uv: Math.round(wx.cur.uv || 0), pressure: wx.cur.pres } : null
    readonly property var days: {
        var out = [], names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        if (!wx) return out
        for (var i = 0; i < Math.min(7, wx.days.length); ++i) {
            var d = wx.days[i], dt = new Date(d.date + "T12:00:00")
            out.push({ label: i === 0 ? "today" : names[dt.getDay()], hi: d.hi, lo: d.lo, condition: LiveTiles.wxText(d.code) })
        }
        return out
    }
    readonly property var hours: wx ? wx.hours.map(function(h) { return { label: h.hh, temp: h.temp } }) : []
    readonly property string status: {
        rev
        if (!place) return ""
        if (!wx) return LiveTiles.weatherStatus === "offline" ? "offline. no saved data." : "loading..."
        var age = Date.now() - wx.at
        return (age > 3600000 || LiveTiles.weatherStatus === "offline" ? "offline, " : "") + "updated " + Qt.formatTime(new Date(wx.at), "hh:mm") + " \u00b7 open-meteo.com"
    }

    function toU(c) { return Math.round(unit === "F" ? c * 9 / 5 + 32 : c) }
    function tStr(c) { return toU(c) + "\u00b0" }
    function save() { AppStore.save("weather-places", { places: places, unit: unit, selected: selected }); LiveTiles.weatherRefresh(false); LiveTiles._weatherTile() }
    function load() {
        var s = AppStore.load("weather-places", null)
        if (s && s.places) {
            var l = Array.prototype.slice.call(s.places)
            places = l.filter(function(p) { return p && typeof p === "object" })
            unit = s.unit === "F" ? "F" : "C"
            selected = s.selected || 0
        }
    }
    Component.onCompleted: {
        load()
        if (places.length === 0) { places = [{ auto: true }]; selected = 0; save() }   // first run: locate by IP
        LiveTiles.weatherRefresh(false)
    }
    Connections { target: LiveTiles; function onWeatherUpdated() { root.rev++ } }
    Connections { target: AppStore; function onSaved(app) { if (app === "weather-places") root.load() } }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // accent info block
    component Block: Rectangle {
        id: blk
        property string label: ""
        property string value: ""
        color: Theme.accent
        height: 96
        Text { x: 12; y: 8; text: blk.label; color: Theme.onColor(Theme.accent); opacity: 0.8
            font.family: Theme.font; font.pixelSize: 18 }
        Text { x: 12; y: 34; width: parent.width - 24; text: blk.value; color: Theme.onColor(Theme.accent); elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 36; font.weight: Theme.fontLight }
    }

    Pivot {
        id: pivot
        anchors.fill: parent
        anchors.topMargin: root.topInset
        caption: "weather"

        PivotPage {
            title: "today"
            Item { width: 1; height: 8 }
            Text {
                visible: root.now === null
                width: parent.width; wrapMode: Text.Wrap
                text: root.place ? root.status : "no places saved. add a city on the places page."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22
            }
            Column {
                visible: root.now !== null
                width: parent.width
                spacing: 0
                Text { text: root.city; color: Theme.textDim; width: parent.width; elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: 26 }
                Row {
                    spacing: 16
                    Text { text: root.now ? root.tStr(root.now.temp) : ""; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 120; font.weight: Font.Thin }
                    TileGlyph { y: 30; name: "weather"; size: 72; color: Theme.accent; stroke: 3 }
                }
                Text { text: root.now ? root.now.condition : ""; color: Theme.text
                    font.family: Theme.font; font.pixelSize: 30; font.weight: Theme.fontLight }
                Text { text: root.now ? "feels like " + root.tStr(root.now.feels) + "   ↑ " + root.tStr(root.now.hi) + "   ↓ " + root.tStr(root.now.lo) : ""
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21 }
                Item { width: 1; height: 20 }
                Grid {
                    columns: 2; spacing: Theme.tileGap
                    readonly property real w: (parent.width - Theme.tileGap) / 2
                    Block { width: parent.w; label: "wind"; value: root.now ? Math.round(root.now.wind) + " km/h" : "" }
                    Block { width: parent.w; label: "humidity"; value: root.now ? Math.round(root.now.humidity) + "%" : "" }
                    Block { width: parent.w; label: "uv index"; value: root.now ? String(root.now.uv) : "" }
                    Block { width: parent.w; label: "pressure"; value: root.now ? Math.round(root.now.pressure) + " hPa" : "" }
                }
                Item { width: 1; height: 16 }
                Text { text: root.status; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
            }
        }

        PivotPage {
            title: "forecast"
            id: fpage
            readonly property real gMin: { var m = 1e9; for (var i = 0; i < root.days.length; ++i) m = Math.min(m, root.days[i].lo); return m }
            readonly property real gMax: { var m = -1e9; for (var i = 0; i < root.days.length; ++i) m = Math.max(m, root.days[i].hi); return m }
            MetroSectionHeader { text: "next 24 hours" }
            Flickable {
                width: parent.width; height: 132
                contentWidth: hrow.width; contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Row {
                    id: hrow
                    spacing: 6
                    Repeater {
                        model: root.hours
                        Item {
                            id: hcol
                            required property var modelData
                            width: 64; height: 132
                            Rectangle { anchors.fill: parent; color: Theme.dark ? "#1b1b1b" : "#e6e6e6" }
                            Text { y: 8; width: parent.width; horizontalAlignment: Text.AlignHCenter
                                text: hcol.modelData.label; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18 }
                            TileGlyph { x: 16; y: 40; name: "weather"; size: 32; color: Theme.accent; stroke: 2 }
                            Text { y: 88; width: parent.width; horizontalAlignment: Text.AlignHCenter
                                text: root.tStr(hcol.modelData.temp); color: Theme.text
                                font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight }
                        }
                    }
                }
            }
            MetroSectionHeader { text: "7 days" }
            Repeater {
                model: root.days
                Item {
                    id: drow
                    required property var modelData
                    width: parent.width; height: 64
                    Text { x: 0; y: 6; width: 90; text: drow.modelData.label; color: Theme.text
                        font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight }
                    Text { x: 0; y: 36; width: 150; text: drow.modelData.condition; color: Theme.textDim; elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 16 }
                    Text { x: 150; y: 10; width: 44; horizontalAlignment: Text.AlignRight; text: root.tStr(drow.modelData.lo)
                        color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22 }
                    Item {
                        x: 204; y: 0; height: parent.height
                        width: parent.width - 204 - 54
                        readonly property real span: Math.max(1, fpage.gMax - fpage.gMin)
                        Rectangle { y: 22; width: parent.width; height: 6; color: Theme.dark ? "#333333" : "#cccccc" }
                        Rectangle {
                            y: 22; height: 6; color: Theme.accent
                            x: parent.width * (drow.modelData.lo - fpage.gMin) / parent.span
                            width: Math.max(4, parent.width * (drow.modelData.hi - drow.modelData.lo) / parent.span)
                        }
                    }
                    Text { anchors.right: parent.right; y: 10; text: root.tStr(drow.modelData.hi); color: Theme.text
                        font.family: Theme.font; font.pixelSize: 22 }
                }
            }
            Item { width: 1; height: 12 }
            Text { text: root.status; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }

        PivotPage {
            title: "places"
            id: ppage
            property var results: []
            property string msg: ""
            function find() {
                var q = qf.text.trim()
                if (q.length < 2) return
                msg = "searching..."
                LiveTiles.wxSearch(q, function(r) { results = r || []; msg = r === null ? "offline. try again later." : (r.length ? "" : "nothing found.") })
            }
            function add(p) {
                for (var i = 0; i < root.places.length; ++i) if (!root.places[i].auto && root.places[i].lat === p.lat && root.places[i].lon === p.lon) return
                root.places = root.places.concat([{ name: p.name, lat: p.lat, lon: p.lon }])
                root.selected = root.places.length - 1
                results = []; qf.text = ""
                root.save()
            }

            MetroToggle {
                width: parent.width
                label: "units"
                onText: "Fahrenheit"; offText: "Celsius"
                checked: root.unit === "F"
                onToggled: (v) => { root.unit = v ? "F" : "C"; root.save() }
            }
            MetroSectionHeader { text: "saved cities" }
            Text {
                visible: root.places.length === 0
                width: parent.width; wrapMode: Text.Wrap
                text: "nothing saved yet."; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22
            }
            Repeater {
                model: root.places
                MetroListRow {
                    id: prow
                    required property var modelData
                    required property int index
                    readonly property var w: { root.rev; return LiveTiles.wxFor(modelData) }
                    glyph: modelData.auto ? "maps" : "weather"
                    title: (modelData.auto ? "my location" : modelData.name) + (modelData.auto && modelData.name ? " (" + modelData.name + ")" : "")
                    subtitle: (index === root.selected ? "shown on today \u00b7 " : "") + (w && w.cur ? LiveTiles.wxText(w.cur.code) : "no data yet")
                    trailing: w && w.cur ? root.tStr(w.cur.temp) : ""
                    onClicked: { root.selected = index; root.save(); pivot.goTo(0) }
                    onPressAndHold: {
                        var p = root.places.slice()
                        p.splice(index, 1)
                        root.places = p
                        root.selected = Math.max(0, Math.min(root.selected, p.length - 1))
                        root.save()
                    }
                }
            }
            Text { visible: root.places.length > 0; text: "tap to show, press and hold to remove"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
            MetroSectionHeader { text: "add a city" }
            MetroTextField {
                id: qf
                width: parent.width
                placeholder: "search city"
                onAccepted: ppage.find()
            }
            Item { width: 1; height: 8 }
            Row {
                spacing: 12
                MetroButton { text: "search"; accentFill: true; onClicked: ppage.find() }
                MetroButton {
                    text: "my location"
                    onClicked: {
                        for (var i = 0; i < root.places.length; ++i) if (root.places[i].auto) { root.selected = i; root.save(); return }
                        root.places = root.places.concat([{ auto: true }])
                        root.selected = root.places.length - 1
                        root.save()
                    }
                }
            }
            Text { visible: ppage.msg !== ""; text: ppage.msg; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20 }
            Repeater {
                model: ppage.results
                MetroListRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: modelData.sub
                    onClicked: ppage.add(modelData)
                }
            }
            Item { width: 1; height: 12 }
            Text { text: root.status; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }
    }
}
