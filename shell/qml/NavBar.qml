import QtQuick
import FlowShell

// Bottom navigation bar: back, home (circle with star), search. Swipe-up compatible with GestureBar.
Rectangle {
    id: root
    height: 56
    color: Theme.pageBg
    property color ink: Theme.text
    signal back
    signal home
    signal search
    signal backHeld
    signal dragged(real dy)
    signal released(real dy, real vy)

    // one glyph button; kind: "back" | "home" | "search"
    component NavButton : Item {
        id: btn
        property string kind: ""
        property bool held: false
        signal activated
        signal longPressed
        property bool _long: false
        width: root.width / 3; height: root.height
        Canvas {
            id: cv
            width: 32; height: 32; anchors.centerIn: parent
            scale: btn.held ? 0.86 : 1.0
            opacity: btn.held ? 0.6 : 1.0
            Behavior on scale { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.pressMs; easing.type: Easing.OutCubic } }
            Behavior on opacity { enabled: !Theme.reduceMotion; NumberAnimation { duration: Theme.pressMs } }
            property color ink: root.ink
            onInkChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.clearRect(0, 0, width, height)
                c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 2.2; c.lineCap = "round"; c.lineJoin = "round"
                if (btn.kind === "back") {
                    c.beginPath(); c.moveTo(27, 16); c.lineTo(6, 16); c.stroke()
                    c.beginPath(); c.moveTo(15, 7); c.lineTo(6, 16); c.lineTo(15, 25); c.stroke()
                } else if (btn.kind === "home") {
                    c.beginPath(); c.arc(16, 16, 13, 0, Math.PI * 2); c.stroke()
                    c.beginPath()
                    for (let i = 0; i < 10; i++) {
                        const r = (i % 2 === 0) ? 6.4 : 2.7, a = -Math.PI / 2 + i * Math.PI / 5
                        const x = 16 + r * Math.cos(a), y = 16.5 + r * Math.sin(a)
                        if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
                    }
                    c.closePath(); c.fill(); c.stroke()
                } else {
                    c.beginPath(); c.arc(13, 13, 8.5, 0, Math.PI * 2); c.stroke()
                    c.beginPath(); c.moveTo(19.5, 19.5); c.lineTo(28, 28); c.stroke()
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onPressed: { btn.held = true; btn._long = false }
            onReleased: btn.held = false
            onCanceled: btn.held = false
            onPressAndHold: { btn._long = true; btn.longPressed() }       // hold back = running apps, like Windows Phone
            onClicked: if (!btn._long) btn.activated()
        }
    }

    // exposed held state: true while any button is pressed
    readonly property bool held: bBack.held || bHome.held || bSearch.held

    Row {
        anchors.fill: parent
        NavButton { id: bBack; kind: "back"; onActivated: root.back(); onLongPressed: root.backHeld() }
        NavButton { id: bHome; kind: "home"; onActivated: root.home() }
        NavButton { id: bSearch; kind: "search"; onActivated: root.search() }
    }

    // swipe-up gesture, same signals as GestureBar (buttons keep taps; drag takes over on movement)
    DragHandler {
        target: null; yAxis.enabled: true; xAxis.enabled: false
        onTranslationChanged: if (active) root.dragged(-translation.y)
        onActiveChanged: if (!active) root.released(-translation.y, centroid.velocity.y)
    }
}
