import QtQuick
import FlowShell

// Lock screen: wallpaper shows through, huge light clock lower left, notification count badges.
Item {
    id: root
    property real progress: 0          // 0 = locked, 1 = unlocked (slid away)
    property date now: new Date()
    property int mailCount: 3
    property int messageCount: 2
    property int calendarCount: 1
    property real bounce: 0            // hint lift in px, animated while idle
    Timer { interval: 5000; running: root.visible; repeat: true; onTriggered: root.now = new Date() }
    opacity: 1 - progress * 0.9
    y: -progress * height * 0.55 - bounce
    visible: progress < 0.999

    // bounce hint: lifts 24px, settles, every 6s while idle
    SequentialAnimation {
        running: root.progress < 0.01 && root.visible && !Theme.reduceMotion
        loops: Animation.Infinite
        PauseAnimation { duration: 6000 }
        NumberAnimation { target: root; property: "bounce"; to: 24; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "bounce"; to: 0; duration: 650; easing.type: Easing.OutBounce }
    }

    // subtle scrim so light text reads on any wallpaper
    Rectangle { anchors.fill: parent; z: -1
        gradient: Gradient { GradientStop { position: 0.45; color: "transparent" } GradientStop { position: 1.0; color: "#99000000" } } }

    Column {
        id: clock
        anchors { left: parent.left; leftMargin: 28; bottom: badges.top; bottomMargin: 36 }
        spacing: -10
        Text { text: Qt.formatTime(root.now, "hh:mm"); color: "#ffffff"
            font.pixelSize: 136; font.weight: Font.ExtraLight; font.family: Theme.font }
        Text { text: Qt.formatDate(root.now, "dddd, d MMMM").toLowerCase(); color: "#ffffff"
            font.pixelSize: 26; font.weight: Theme.fontLight; font.family: Theme.font }
    }

    Row {
        id: badges
        anchors { left: parent.left; leftMargin: 28; bottom: hint.top; bottomMargin: 24 }
        spacing: 22
        Repeater {
            model: [ { g: "mail", n: root.mailCount }, { g: "message", n: root.messageCount }, { g: "calendar", n: root.calendarCount } ]
            delegate: Row {
                required property var modelData
                spacing: 10
                visible: Theme.showBadges
                Rectangle {
                    width: 44; height: 44; radius: Theme.tileRadius
                    color: modelData.n > 0 ? Theme.accent : "transparent"
                    border.width: modelData.n > 0 ? 0 : 1.5; border.color: "#ffffff"
                    TileGlyph { anchors.centerIn: parent; name: modelData.g; size: 26; stroke: 2; color: modelData.n > 0 ? Theme.onColor(Theme.accent) : "#ffffff" }
                }
                Text { text: modelData.n; color: "#ffffff"; font.pixelSize: 26; font.weight: Theme.fontLight
                    font.family: Theme.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Text { id: hint; anchors { bottom: parent.bottom; bottomMargin: 20; horizontalCenter: parent.horizontalCenter }
        text: "swipe up to unlock"; color: "#ffffff"; opacity: 0.6; font.pixelSize: 12; font.weight: Theme.fontLight; font.family: Theme.font }
}
