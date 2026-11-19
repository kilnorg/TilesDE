import QtQuick
import FlowShell

// Weather app. Offline demo data: deterministic pseudo-random values seeded from city name + date.
// `provider` is the only data source; replace its functions with a real backend later (same return shapes).
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // ---- state (persisted under AppStore "weather-places") ----
    property var places: Sys.demoData ? ["Barcelona", "London", "Tokyo"] : []
    property string unit: "C"
    property int selected: 0
    readonly property string city: places.length > 0 ? places[Math.max(0, Math.min(selected, places.length - 1))] : ""
    readonly property var now: Sys.demoData && city !== "" ? provider.current(city) : null
    readonly property var days: city !== "" ? provider.daily(city, 7) : []
    readonly property var hours: city !== "" ? provider.hourly(city, 24) : []

    function toU(c) { return Math.round(unit === "F" ? c * 9 / 5 + 32 : c) }
    function tStr(c) { return toU(c) + "°" }
    function save() { AppStore.save("weather-places", { places: places, unit: unit, selected: selected }) }
    Component.onCompleted: {
        var s = AppStore.load("weather-places", null)
        if (s && s.places) {
            places = s.places
            unit = s.unit === "F" ? "F" : "C"
            selected = s.selected || 0
        }
    }

    // ---- data provider (offline demo) ----
    QtObject {
        id: provider
        readonly property var cities: [
            { name: "Barcelona", base: 19, amp: 7 }, { name: "London", base: 12, amp: 6 },
            { name: "Tokyo", base: 17, amp: 9 }, { name: "New York", base: 14, amp: 11 },
            { name: "Sydney", base: 21, amp: 6 }, { name: "Reykjavik", base: 4, amp: 5 },
            { name: "Cairo", base: 27, amp: 8 }, { name: "Mumbai", base: 30, amp: 4 },
            { name: "Sao Paulo", base: 23, amp: 5 }, { name: "Berlin", base: 10, amp: 8 },
            { name: "Vancouver", base: 9, amp: 6 }, { name: "Cape Town", base: 18, amp: 6 }
        ]
        readonly property var conditions: ["clear", "partly cloudy", "cloudy", "light rain", "rain", "storm", "fog"]
        function dayNumber(off) { return Math.floor(Date.now() / 86400000) + (off || 0) }
        function hash(str) {
            var h = 2166136261
            for (var i = 0; i < str.length; ++i) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) }
            return h >>> 0
        }
        function rng(seed) {
            var a = seed >>> 0
            return function() {
                a = (a + 0x6D2B79F5) >>> 0
                var t = a
                t = Math.imul(t ^ (t >>> 15), t | 1)
                t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
                return ((t ^ (t >>> 14)) >>> 0) / 4294967296
            }
        }
        function info(city) {
            for (var i = 0; i < cities.length; ++i) if (cities[i].name === city) return cities[i]
            return { name: city, base: 15, amp: 7 }
        }
        function builtinCities() { return !Sys.demoData ? [] : cities.map(function(c) { return c.name }) }
        // day record for offset d (0 = today)
        function dayRec(city, d) {
            var ci = info(city), r = rng(hash(city) ^ Math.imul(dayNumber(d), 2654435761))
            var mean = ci.base + (r() - 0.5) * ci.amp
            var spread = 3 + r() * 4
            return { hi: mean + spread / 2, lo: mean - spread / 2, cond: Math.floor(r() * conditions.length),
                     wind: 3 + r() * 25, hum: 35 + r() * 55, uv: Math.floor(r() * 10), pres: 1000 + r() * 30, r: r }
        }
        function current(city) {
            var d = dayRec(city, 0), hr = new Date().getHours()
            var t = d.lo + (d.hi - d.lo) * (0.5 - 0.5 * Math.cos((hr - 4) / 24 * 2 * Math.PI))
            return { temp: t, feels: t - 1 + (d.hum - 60) / 30, hi: d.hi, lo: d.lo, condition: conditions[d.cond],
                     wind: d.wind, humidity: d.hum, uv: d.uv, pressure: d.pres }
        }
        function daily(city, n) {
            var out = [], names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
            for (var i = 0; i < n; ++i) {
                var d = dayRec(city, i), dt = new Date(Date.now() + i * 86400000)
                out.push({ label: i === 0 ? "today" : names[dt.getDay()], hi: d.hi, lo: d.lo, condition: conditions[d.cond] })
            }
            return out
        }
        function hourly(city, n) {
            var d = dayRec(city, 0), out = [], start = new Date().getHours()
            for (var i = 0; i < n; ++i) {
                var h = (start + i) % 24, dd = i + start >= 24 ? dayRec(city, 1) : d
                var t = dd.lo + (dd.hi - dd.lo) * (0.5 - 0.5 * Math.cos((h - 4) / 24 * 2 * Math.PI))
                out.push({ label: (h < 10 ? "0" : "") + h, temp: t })
            }
            return out
        }
    }

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
                text: Sys.demoData ? "no places saved. add a city on the places page." : "no weather source yet. nothing to show."
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
                Text { text: "demo data (offline)"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
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
            Text { text: "demo data (offline)"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }

        PivotPage {
            title: "places"
            id: ppage
            property int addIndex: 0
            readonly property var available: provider.builtinCities().filter(function(c) { return root.places.indexOf(c) < 0 })

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
                    required property string modelData
                    required property int index
                    glyph: "weather"
                    title: modelData
                    subtitle: (index === root.selected ? "shown on today · " : "") + provider.current(modelData).condition
                    trailing: root.tStr(provider.current(modelData).temp)
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
            Item {
                visible: ppage.available.length === 0
                width: parent.width; height: 40
                Text { text: "all built-in cities added."; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22 }
            }
            MetroDropdown {
                visible: ppage.available.length > 0
                width: parent.width
                height: visible ? implicitHeight : 0
                label: "city"
                model: ppage.available
                currentIndex: Math.min(ppage.addIndex, Math.max(0, ppage.available.length - 1))
                onActivated: (i) => ppage.addIndex = i
            }
            Item { width: 1; height: 12 }
            MetroButton {
                visible: ppage.available.length > 0
                text: "add"
                accentFill: true
                onClicked: {
                    var c = ppage.available[Math.min(ppage.addIndex, ppage.available.length - 1)]
                    if (c === undefined) return
                    root.places = root.places.concat([c])
                    ppage.addIndex = 0
                    root.save()
                }
            }
            Item { width: 1; height: 12 }
            Text { text: "demo data (offline)"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }
    }
}
