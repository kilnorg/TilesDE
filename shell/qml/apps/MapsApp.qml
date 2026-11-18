import QtQuick
import FlowShell

// Maps: offline Metro shell. No map engine; search, favourites and directions open OpenStreetMap in the browser.
// Store key "maps": { favs: [{id, name, lat, lon, addr}] }
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    property var favs: []
    property string curId: ""        // favourite shown in the detail sheet
    property bool detailOpen: false
    property bool editOpen: false
    property string editId: ""       // "" = new
    property string editError: ""
    property bool confirmDelete: false
    property string toast: ""

    function persist() { AppStore.save("maps", { favs: favs }) }
    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36) }
    function indexOf(id) { for (var i = 0; i < favs.length; ++i) if (favs[i].id === id) return i; return -1 }
    function getFav(id) { var i = indexOf(id); return i >= 0 ? favs[i] : null }
    function hasCoords(f) { return f && f.lat !== "" && f.lon !== "" && !isNaN(parseFloat(f.lat)) && !isNaN(parseFloat(f.lon)) }
    function showToast(t) { toast = t; toastTimer.restart() }

    Component.onCompleted: {
        var d = AppStore.load("maps", { favs: [] })
        favs = d && Array.isArray(d.favs) ? d.favs : []
    }

    function openSearch(q) {
        q = String(q).trim()
        if (q === "") { showToast("type something to search"); return }
        Sys.openUrl("https://www.openstreetmap.org/search?query=" + encodeURIComponent(q))
    }
    function openFav(f) {
        if (!f) return
        if (hasCoords(f)) {
            var la = parseFloat(f.lat), lo = parseFloat(f.lon)
            Sys.openUrl("https://www.openstreetmap.org/?mlat=" + la + "&mlon=" + lo + "#map=16/" + la + "/" + lo)
        } else if (String(f.addr).trim() !== "") openSearch(f.addr)
        else openSearch(f.name)
    }
    function favSubtitle(f) {
        if (hasCoords(f)) return parseFloat(f.lat).toFixed(5) + ", " + parseFloat(f.lon).toFixed(5)
        return f.addr !== "" ? f.addr : "no location"
    }

    // ---- editor
    function startEdit(id) {
        var f = id !== "" ? getFav(id) : null
        editId = id
        editError = ""
        fName.text = f ? f.name : ""
        fLat.text = f ? f.lat : ""
        fLon.text = f ? f.lon : ""
        fAddr.text = f ? f.addr : ""
        editOpen = true
    }
    function saveEdit() {
        var name = fName.text.trim(), lat = fLat.text.trim(), lon = fLon.text.trim(), addr = fAddr.text.trim()
        if (name === "") { editError = "give the place a name"; return }
        if ((lat === "") !== (lon === "")) { editError = "enter both latitude and longitude, or neither"; return }
        if (lat !== "") {
            var la = Number(lat), lo = Number(lon)
            if (isNaN(la) || isNaN(lo) || la < -90 || la > 90 || lo < -180 || lo > 180) {
                editError = "latitude is -90..90 and longitude -180..180"; return
            }
        }
        if (lat === "" && addr === "") { editError = "enter coordinates or an address"; return }
        var list = favs.slice()
        var rec = { id: editId !== "" ? editId : newId(), name: name, lat: lat, lon: lon, addr: addr }
        var i = indexOf(editId)
        if (editId !== "" && i >= 0) list[i] = rec; else list.push(rec)
        favs = list; persist()
        editOpen = false
        fName.focus = false
    }
    function deleteFav(id) {
        favs = favs.filter(function(f) { return f.id !== id }); persist()
        detailOpen = false; confirmDelete = false; curId = ""
    }

    focus: true
    function back() {
        if (editOpen) { editOpen = false; return }
        if (detailOpen) { detailOpen = false; confirmDelete = false; return }
        closeRequested()
    }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    Timer { id: toastTimer; interval: 1600; onTriggered: root.toast = "" }

    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset - 72
        caption: "maps"

        PivotPage {
            title: "search"
            // decorative placeholder: abstract streets, not real data
            Canvas {
                id: mapArt
                width: parent.width; height: 170
                property color bg: Theme.accent
                property color ink: Theme.dark ? "#000000" : "#ffffff"
                onBgChanged: requestPaint()
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"), w = width, h = height
                    c.clearRect(0, 0, w, h)
                    c.fillStyle = Qt.darker(bg, 1.7); c.fillRect(0, 0, w, h)
                    var gx = 36, gy = 34
                    // city blocks
                    c.fillStyle = Qt.darker(bg, 1.35)
                    for (var y = 0; y < h; y += gy)
                        for (var x = 0; x < w; x += gx)
                            if (((x / gx) * 7 + (y / gy) * 13) % 5 < 2) c.fillRect(x + 4, y + 4, gx - 8, gy - 8)
                    // streets
                    c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.35); c.lineWidth = 2
                    c.beginPath()
                    for (var xx = 0; xx <= w; xx += gx) { c.moveTo(xx, 0); c.lineTo(xx, h) }
                    for (var yy = 0; yy <= h; yy += gy) { c.moveTo(0, yy); c.lineTo(w, yy) }
                    c.stroke()
                    // two avenues in accent
                    c.strokeStyle = bg; c.lineWidth = 7
                    c.beginPath()
                    c.moveTo(0, h * 0.72); c.lineTo(w * 0.45, h * 0.72); c.lineTo(w * 0.7, h * 0.18); c.lineTo(w, h * 0.18)
                    c.moveTo(w * 0.28, 0); c.lineTo(w * 0.28, h)
                    c.stroke()
                    // pin
                    c.fillStyle = Theme.dark ? "#ffffff" : "#000000"
                    c.fillRect(w * 0.28 - 7, h * 0.72 - 7, 14, 14)
                }
            }
            Text {
                width: parent.width; topPadding: 8; wrapMode: Text.WordWrap
                text: "interactive map lands with the Tiles map engine"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
            }
            Item { width: 1; height: 16 }
            MetroTextField {
                id: q
                width: parent.width
                label: "search places"
                placeholder: "address, city or place"
                onAccepted: root.openSearch(text)
            }
            Item { width: 1; height: 16 }
            MetroButton {
                text: "search on openstreetmap"; accentFill: true
                onClicked: root.openSearch(q.text)
            }
            Text {
                width: parent.width; topPadding: 12; wrapMode: Text.WordWrap
                text: "opens in your browser. an internet connection is needed there."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
            }
        }

        PivotPage {
            title: "favourites"
            Text {
                visible: root.favs.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no favourite places yet. tap new to add one."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.favs
                MetroListRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: root.favSubtitle(modelData)
                    glyph: "maps"
                    onClicked: root.openFav(modelData)
                    onPressAndHold: { root.curId = modelData.id; root.confirmDelete = false; root.detailOpen = true }
                }
            }
            Text {
                visible: root.favs.length > 0
                width: parent.width; topPadding: 12; wrapMode: Text.WordWrap
                text: "tap to open on the map. long-press to edit or delete."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
            }
        }

        PivotPage {
            title: "directions"
            MetroTextField { id: dFrom; width: parent.width; label: "from"; placeholder: "start address or lat,lon" }
            Item { width: 1; height: 12 }
            MetroTextField { id: dTo; width: parent.width; label: "to"; placeholder: "destination or lat,lon"
                onAccepted: root.route() }
            Item { width: 1; height: 12 }
            MetroDropdown { id: dMode; width: parent.width; label: "mode"; model: ["walk", "bike", "car"] }
            Item { width: 1; height: 20 }
            MetroButton { text: "show route"; accentFill: true; onClicked: root.route() }
            Text {
                width: parent.width; topPadding: 12; wrapMode: Text.WordWrap
                text: "route is calculated on openstreetmap in your browser."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
            }
        }
    }

    function route() {
        var f = dFrom.text.trim(), t = dTo.text.trim()
        if (f === "" || t === "") { showToast("fill in from and to"); return }
        var eng = ["foot", "bike", "car"][dMode.currentIndex]
        Sys.openUrl("https://www.openstreetmap.org/directions?engine=fossgis_osrm_" + eng
                    + "&route=" + encodeURIComponent(f) + ";" + encodeURIComponent(t))
    }

    AppBar {
        anchors.bottom: parent.bottom
        items: [{ glyph: "plus", label: "new place" }]
        onActivated: (i) => { pivot.goTo(1); root.startEdit("") }
    }

    // ---- detail sheet
    Item {
        anchors.fill: parent
        visible: root.detailOpen
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Column {
            x: 18; y: root.topInset + 24; width: parent.width - 36; spacing: 14
            property var f: root.getFav(root.curId)
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: parent.f ? parent.f.name.toLowerCase() : ""
                color: Theme.text; font.family: Theme.font; font.pixelSize: 56; font.weight: Theme.fontLight
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: parent.f ? root.favSubtitle(parent.f) : ""
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Item { width: 1; height: 8 }
            MetroButton { width: parent.width; text: "open on map"; accentFill: true
                onClicked: root.openFav(root.getFav(root.curId)) }
            MetroButton { width: parent.width; text: "route here"
                onClicked: {
                    var f = root.getFav(root.curId)
                    if (!f) return
                    dTo.text = root.hasCoords(f) ? parseFloat(f.lat) + "," + parseFloat(f.lon) : (f.addr !== "" ? f.addr : f.name)
                    root.detailOpen = false
                    pivot.goTo(2)
                } }
            MetroButton { width: parent.width; text: "edit"
                onClicked: { root.detailOpen = false; root.startEdit(root.curId) } }
            MetroButton { width: parent.width; text: root.confirmDelete ? "tap again to delete" : "delete"
                onClicked: { if (root.confirmDelete) root.deleteFav(root.curId); else root.confirmDelete = true } }
        }
    }

    // ---- editor sheet
    Item {
        anchors.fill: parent
        visible: root.editOpen
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Flickable {
            id: eflick
            x: 18; y: root.topInset + 12
            width: parent.width - 36; height: parent.height - root.topInset - 12
            contentWidth: width; contentHeight: ecol.height + 32
            boundsBehavior: Flickable.StopAtBounds; clip: true
            Column {
                id: ecol
                width: parent.width; spacing: 10
                Text {
                    text: root.editId === "" ? "new place" : "edit place"
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 48; font.weight: Theme.fontLight
                }
                MetroTextField { id: fName; width: parent.width; label: "name"; placeholder: "home, work, cafe" }
                MetroTextField { id: fLat; width: parent.width; label: "latitude (optional)"; placeholder: "48.85837"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly }
                MetroTextField { id: fLon; width: parent.width; label: "longitude (optional)"; placeholder: "2.29448"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly }
                MetroTextField { id: fAddr; width: parent.width; label: "address (if no coordinates)"; placeholder: "street, city" }
                Text {
                    visible: root.editError !== ""
                    width: parent.width; wrapMode: Text.WordWrap
                    text: root.editError; color: Theme.accent
                    font.family: Theme.font; font.pixelSize: 21
                }
                Row {
                    spacing: 12
                    MetroButton { text: "save"; accentFill: true; onClicked: root.saveEdit() }
                    MetroButton { text: "cancel"; onClicked: root.editOpen = false }
                }
            }
        }
    }

    Rectangle {
        visible: root.toast !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 72 - 64
        width: toastText.width + 36; height: 44
        color: Theme.accent
        Text {
            id: toastText
            anchors.centerIn: parent; text: root.toast; color: Theme.onColor(Theme.accent)
            font.family: Theme.font; font.pixelSize: 20
        }
    }
}
