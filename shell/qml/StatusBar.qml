import QtQuick
import FlowShell

// Thin status bar: no pills, light weight, signal bars + wifi + battery % + clock at right.
Item {
    id: root
    height: 28
    property color ink: "#ffffff"
    property date now: new Date()
    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // left cluster: signal + wifi; right cluster: battery + clock (flat, thin, no pills)
    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 10
        // signal bars
        Row {
            spacing: 2; anchors.verticalCenter: parent.verticalCenter
            Repeater { model: 4
                Rectangle { width: 3; height: 4 + index * 3; anchors.bottom: parent.bottom
                    color: root.ink; opacity: (Services.airplane ? false : index < Services.signal) ? 1 : 0.3 } }
        }
        // wifi: three arcs
        Canvas {
            width: 16; height: 12; anchors.verticalCenter: parent.verticalCenter
            property color ink: root.ink
            property bool on: Services.wifi && !Services.airplane
            onInkChanged: requestPaint(); onOnChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.clearRect(0, 0, width, height)
                c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.6; c.lineCap = "butt"
                c.globalAlpha = on ? 1 : 0.3
                for (let i = 1; i <= 3; i++) { c.beginPath(); c.arc(8, 11.5, i * 3.4, -Math.PI * 0.8, -Math.PI * 0.2); c.stroke() }
                c.beginPath(); c.arc(8, 11, 1.2, 0, 6.3); c.fill()
            }
        }
    }
    Row {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 10
        // battery
        Row {
            spacing: 3; anchors.verticalCenter: parent.verticalCenter
            Text { visible: true; text: Services.battery + "%"; color: root.ink; font.pixelSize: 12; font.weight: Theme.fontLight
                font.family: Theme.font; anchors.verticalCenter: parent.verticalCenter }
            Item {
                width: 22; height: 11; anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: 20; height: 11; color: "transparent"; border.width: 1; border.color: root.ink
                    Rectangle { x: 2; y: 2; height: parent.height - 4; width: (parent.width - 4) * Math.max(0, Math.min(100, Services.battery)) / 100
                        color: Services.charging ? "#4cd964" : (Services.battery < 20 ? "#ff453a" : root.ink) } }
                Rectangle { x: 20; y: 3; width: 2; height: 5; color: root.ink }
            }
        }
        Text { text: Qt.formatTime(root.now, "hh:mm"); color: root.ink; font.pixelSize: 14; font.weight: Theme.fontLight
            font.family: Theme.font; anchors.verticalCenter: parent.verticalCenter }
    }
}
