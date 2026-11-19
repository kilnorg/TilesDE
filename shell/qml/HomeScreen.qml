import QtQuick
import FlowShell

// Horizontal pager: page 0 = StartScreen (tiles), page 1 = AllApps (authored in AllApps.qml).
Item {
    id: root
    property bool searchOpen: false
    property string query: ""
    property real dim: 0
    property real pagerP: 0                      // 0 = start, 1 = all apps
    property bool pagerDrag: false
    property int topInset: 48
    property int bottomInset: 96
    property real kbH: 0                         // on-screen keyboard height (lifts the search results)
    readonly property bool editing: start.editing
    property alias start: start
    property alias allApps: apps
    signal launched(string name, rect r, bool real)

    // search results come from the All Apps list
    readonly property var searchable: {
        const q = query.toLowerCase(), out = []
        const e = apps.entries
        for (let i = 0; i < e.length; i++)
            if (e[i].kind === "app" && (q === "" || e[i].name.toLowerCase().indexOf(q) >= 0)) out.push(e[i])
        return out
    }
    onSearchOpenChanged: {
        if (searchOpen) Qt.callLater(function() { input.forceActiveFocus() })
        else { query = ""; input.text = ""; input.focus = false }
    }

    Behavior on pagerP { enabled: !root.pagerDrag && !Theme.reduceMotion; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    function showApps() { start.exitEdit(); pagerP = 1 }
    function showStart() { apps.closeOverlays(); pagerP = 0 }
    // returns true when the back action was consumed
    function goBack() {
        if (searchOpen) { searchOpen = false; return true }
        if (apps.alpha.open || apps.menuShown) { apps.closeOverlays(); return true }
        if (start.editing) { start.exitEdit(); return true }
        if (pagerP > 0.5) { showStart(); return true }
        return false
    }
    function launchByName(name, r) { root.launched(name, r, false) }

    StartScreen {
        id: start
        width: parent.width; height: parent.height
        x: -root.pagerP * width * 0.3
        opacity: root.searchOpen ? 0.1 : 1 - root.pagerP * 0.9
        visible: root.pagerP < 0.999 && !(root.searchOpen && searchLayer.opacity > 0.99)   // fully covered by search: stop rendering it
        pagerP: root.pagerP
        topInset: root.topInset
        bottomInset: root.bottomInset
        flipsOn: root.dim < 0.01 && root.pagerP < 0.5 && !root.searchOpen
        onLaunched: (n, r, real) => root.launched(n, r, real)
        onAppsRequested: root.showApps()
    }

    AllApps {
        id: apps
        width: parent.width; height: parent.height
        x: (1 - root.pagerP) * width
        visible: root.pagerP > 0.001
        onLaunched: (n, r) => root.launched(n, r, false)
        onPinRequested: (n, g) => { if (start.pinApp(n, g)) root.showStart() }
        onSearchRequested: root.searchOpen = true
    }

    // horizontal page swipe (vertical drags stay with the Flickables)
    DragHandler {
        id: swipe
        target: null
        enabled: !start.editing && !root.searchOpen && !apps.alpha.open && !apps.menuShown
        xAxis.enabled: true; yAxis.enabled: false
        property real baseP: 0
        onActiveChanged: {
            if (active) { baseP = root.pagerP; root.pagerDrag = true; return }
            root.pagerDrag = false
            const t = translation.x
            const vx = centroid.velocity.x
            if (baseP < 0.5) root.pagerP = (t < -root.width * 0.2 || vx < -900) ? 1 : 0
            else root.pagerP = (t > root.width * 0.2 || vx > 900) ? 0 : 1
        }
        onTranslationChanged: if (active) root.pagerP = Math.max(0, Math.min(1, baseP - translation.x / root.width))
    }

    // returning to Start (from an app or the lock screen) replays the turnstile entrance
    property bool _exited: false
    property bool _hidden: opacity < 0.05
    property bool _tilesOut: false
    property real _launchAt: 0
    // tiles fly in on the LAST close: during rapid open/close they stay out and the entrance waits until things settle
    Timer { id: settleTimer; interval: 380; onTriggered: if (!root._exited) { root._tilesOut = false; start.playEnter() } }
    onLaunched: {
        _exited = true; _launchAt = Date.now(); settleTimer.stop()
        if (!_tilesOut) { _tilesOut = true; start.playExit() }
    }
    property real _lastDim: 0
    onDimChanged: {
        // tiles turn back as soon as the app is closing (dim falling), not after it has fully gone; a re-launch reverses them
        if (_exited && dim < _lastDim && dim < 0.2) {
            _exited = false
            settleTimer.interval = (Date.now() - _launchAt < 1200) ? 250 : 1; settleTimer.restart()
        }
        _lastDim = dim
    }
    onOpacityChanged: {
        if (opacity < 0.05) _hidden = true
        else if (_hidden && opacity > 0.5 && !_exited) { _hidden = false; _tilesOut = false; start.playEnter() }
    }

    // search overlay (flat, black)
    Item {
        id: searchLayer
        anchors.fill: parent; visible: opacity > 0.01; opacity: root.searchOpen ? 1 : 0
        z: 4
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        Behavior on opacity { enabled: !Theme.reduceMotion; NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; onClicked: root.searchOpen = false }
        Rectangle {
            id: bar
            x: 12; y: root.topInset + 12; width: parent.width - 24; height: 52
            color: "transparent"; border.width: 2; border.color: Theme.text
            TextInput {
                id: input
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text; font.pixelSize: 22; font.family: Theme.font; font.weight: Font.Light
                onTextChanged: root.query = text; focus: root.searchOpen; clip: true
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                Text { visible: !input.text.length; text: "search"; color: Theme.textDim; font: input.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        ListView {
            id: results
            anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: root.bottomInset + root.kbH }
            clip: true
            model: root.searchable
            delegate: Item {
                required property var modelData
                width: results.width; height: 64
                Row {
                    anchors { fill: parent; leftMargin: 12 }
                    spacing: 14
                    Rectangle {
                        width: 48; height: 48; anchors.verticalCenter: parent.verticalCenter
                        color: Theme.tileColor(modelData.name.toLowerCase(), 0); opacity: Theme.tileOpacity
                        TileGlyph { anchors.centerIn: parent; size: 28; name: modelData.glyph; visible: modelData.glyph !== ""; color: Theme.onColor(parent.color) }
                        Text { anchors.centerIn: parent; visible: modelData.glyph === ""; text: modelData.name.charAt(0).toUpperCase(); color: Theme.onColor(parent.color); font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Normal }
                    }
                    Text { text: modelData.name; anchors.verticalCenter: parent.verticalCenter; color: Theme.text; font.pixelSize: 22; font.weight: Font.Light; font.family: Theme.font }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.searchOpen = false; root.launched(modelData.name, Qt.rect(root.width / 2 - 30, root.height / 2 - 30, 60, 60), false) }
                }
            }
        }
    }

    Rectangle { anchors.fill: parent; color: "black"; opacity: root.dim; z: 5; visible: opacity > 0.005 }
}
