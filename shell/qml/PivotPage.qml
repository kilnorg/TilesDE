import QtQuick
import FlowShell

// One page of a Pivot. Vertically scrolling content; children go in the content column.
// `title` is the lowercase header text shown by the Pivot. Left margin 18 px (Theme-independent, WP list margin).
Flickable {
    id: root
    property string title: ""
    property int margin: 18
    default property alias content: col.data
    readonly property alias column: col
    contentWidth: width
    contentHeight: col.implicitHeight + 32
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    Column {
        id: col
        x: root.margin
        width: root.width - root.margin * 2
        spacing: 0
    }
}
