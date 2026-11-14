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
    readonly property bool editing: start.editing
    property alias start: start
    property alias allApps: apps
    signal launched(string name, rect r, bool real)

    readonly property var searchable: ["Photos", "Calendar", "Clock", "Music", "Maps", "Notes", "Files", "Weather", "Terminal", "Noxal", "Wallet", "Settings",
        "Phone", "Messages", "Browser", "Camera", "Mail", "People", "Store"]

    Behavior on pagerP { enabled: !root.pagerDrag && !Theme.reduceMotion; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    function showApps() { start.exitEdit(); pagerP = 1 }
    function showStart() { pagerP = 0 }
    // returns true when the back action was consumed
    function goBack() {
        if (searchOpen) { searchOpen = false; return true }
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
        visible: root.pagerP < 0.999
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
        onPinRequested: (n) => { start.pinApp(n); root.showStart() }
    }

    // horizontal page swipe (vertical drags stay with the Flickables)
    DragHandler {
        id: swipe
        target: null
        enabled: !start.editing && !root.searchOpen
        xAxis.enabled: true; yAxis.enabled: false
        property real baseP: 0
        onActiveChanged: {
            if (active) { baseP = root.pagerP; root.pagerDrag = true; return }
            root.pagerDrag = false
            const t = translation.x
            if (baseP < 0.5) root.pagerP = (t < -root.width * 0.2) ? 1 : 0
            else root.pagerP = (t > root.width * 0.2) ? 0 : 1
        }
        onTranslationChanged: if (active) root.pagerP = Math.max(0, Math.min(1, baseP - translation.x / root.width))
    }

    // returning to Start (from an app or the lock screen) replays the turnstile entrance
    property bool _exited: false
    property bool _hidden: opacity < 0.05
    onLaunched: _exited = true
    onDimChanged: if (_exited && dim < 0.01) { _exited = false; start.playEnter() }
    onOpacityChanged: {
        if (opacity < 0.05) _hidden = true
        else if (_hidden && opacity > 0.5 && !_exited) { _hidden = false; start.playEnter() }
    }

    // search overlay (flat, black)
    Item {
        anchors.fill: parent; visible: opacity > 0.01; opacity: root.searchOpen ? 1 : 0
        z: 4
        Behavior on opacity { enabled: !Theme.reduceMotion; NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; onClicked: root.searchOpen = false }
        Rectangle {
            id: bar
            x: 12; y: root.topInset + 12; width: parent.width - 24; height: 52
            color: "transparent"; border.width: 2; border.color: Theme.tileText
            TextInput {
                id: input
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text; font.pixelSize: 22; font.family: Theme.font; font.weight: Font.Light
                text: root.query; onTextChanged: root.query = text; focus: root.searchOpen; clip: true
                Text { visible: !input.text.length; text: "search"; color: Theme.textDim; font: input.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        ListView {
            id: results
            anchors { left: parent.left; right: parent.right; top: bar.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: root.bottomInset }
            clip: true
            model: root.searchable
            delegate: Item {
                required property string modelData
                readonly property bool match: root.query.length === 0 || modelData.toLowerCase().indexOf(root.query.toLowerCase()) >= 0
                visible: match
                width: results.width; height: match ? 64 : 0
                Row {
                    anchors { fill: parent; leftMargin: 12 }
                    spacing: 14
                    Rectangle {
                        width: 48; height: 48; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent
                        TileGlyph { anchors.centerIn: parent; size: 28; name: modelData.toLowerCase() === "messages" ? "message" : modelData.toLowerCase(); color: Theme.tileText }
                    }
                    Text { text: modelData; anchors.verticalCenter: parent.verticalCenter; color: Theme.text; font.pixelSize: 22; font.weight: Font.Light; font.family: Theme.font }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.searchOpen = false; root.launched(modelData, Qt.rect(root.width / 2 - 30, root.height / 2 - 30, 60, 60), false) }
                }
            }
        }
    }

    Rectangle { anchors.fill: parent; color: "black"; opacity: root.dim; z: 5; visible: opacity > 0.005 }
}
