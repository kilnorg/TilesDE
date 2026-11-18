import QtQuick
import FlowShell

// Pivot: small uppercase caption, huge lowercase active title, next title dim at the right edge.
// Horizontal swipe; header slides slower than the pages (parallax: title spacing < page width).
// Children: PivotPage items. Titles are read from each page's `title`.
// Props: caption, currentIndex, titles (read-only), titleSize (80), headerHeight. Signal pageChanged(i).
Item {
    id: root
    property string caption: ""
    property int currentIndex: 0
    property real titleSize: 80
    property real captionSize: 21
    readonly property int count: row.children.length
    readonly property var titles: _titles
    property var _titles: []
    readonly property real headerHeight: 24 + captionText.height + 2 + titleSize * 1.15
    default property alias pages: row.data
    signal pageChanged(int index)

    function goTo(i) {
        i = Math.max(0, Math.min(count - 1, i))
        snap.stop()
        snap.to = i * width
        snap.duration = Theme.reduceMotion ? 0 : Theme.turnstileMs
        snap.start()
    }
    function _collect() {
        var t = []
        for (var i = 0; i < row.children.length; ++i) {
            var p = row.children[i]
            p.width = Qt.binding(function() { return root.width })
            p.height = Qt.binding(function() { return root.height - root.headerHeight })
            t.push(row.children[i].title || "")
        }
        _titles = t
    }
    Component.onCompleted: { _collect(); flick.contentX = currentIndex * width }
    onWidthChanged: if (!flick.dragging && !flick.flicking) flick.contentX = currentIndex * width

    readonly property real prog: width > 0 ? flick.contentX / width : 0

    // header
    Item {
        id: header
        width: parent.width; height: root.headerHeight
        clip: true
        Text {
            id: captionText
            x: 18; y: 24
            text: root.caption.toUpperCase()
            color: Theme.text
            font.family: Theme.font; font.pixelSize: root.captionSize
            font.weight: Font.Normal; font.letterSpacing: 0.5
        }
        Row {
            id: titleRow
            y: captionText.y + captionText.height + 2
            spacing: 28
            property real offset: {
                var n = root.count
                if (n < 1 || titleRep.count < n) return 0
                var p = Math.max(0, Math.min(n - 1, root.prog))
                var i = Math.floor(p), f = p - i
                var a = titleRep.itemAt(i), b = titleRep.itemAt(Math.min(n - 1, i + 1))
                if (!a || !b) return 0
                return a.x + (b.x - a.x) * f
            }
            x: 18 - offset
            Repeater {
                id: titleRep
                model: root._titles
                Text {
                    required property int index
                    required property string modelData
                    text: Theme.title ? Theme.title(modelData) : modelData.toLowerCase()
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: root.titleSize
                    font.weight: Theme.fontLight; font.letterSpacing: -1.5
                    opacity: 1 - 0.62 * Math.min(1, Math.abs(root.prog - index))
                    TapHandler { onTapped: root.goTo(index) }
                }
            }
        }
    }

    Flickable {
        id: flick
        y: root.headerHeight
        width: parent.width; height: parent.height - root.headerHeight
        contentWidth: row.width; contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        maximumFlickVelocity: 3000
        onDraggingChanged: if (!dragging && !flicking) root._settle()
        onFlickEnded: root._settle()
        Row { id: row }
        NumberAnimation { id: snap; target: flick; property: "contentX"; easing.type: Easing.OutCubic }
    }
    function _settle() {
        var i = Math.round(flick.contentX / width)
        if (flick.horizontalVelocity > 400) i = Math.ceil(flick.contentX / width - 0.01)
        goTo(i)
        if (i !== currentIndex) { currentIndex = Math.max(0, Math.min(count - 1, i)); pageChanged(currentIndex) }
    }
    onCurrentIndexChanged: if (!flick.dragging && !flick.flicking && Math.abs(flick.contentX - currentIndex * width) > 1) goTo(currentIndex)
}
