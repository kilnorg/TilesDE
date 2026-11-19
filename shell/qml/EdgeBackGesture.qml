import QtQuick

// Left-edge back swipe strip. Emits moved(f) with f = 0..1 (fraction of `span` dragged right) and
// finished(commit) on release (commit: dragged past a third of span or flicked right).
// Owner renders the peek (e.g. PageSlide.p = 1 - f) and completes or cancels on finished().
Item {
    id: root
    property real span: 540
    property real _f: 0
    width: 18
    signal moved(real f)
    signal finished(bool commit)

    DragHandler {
        target: null; yAxis.enabled: false
        onTranslationChanged: if (active) { root._f = Math.max(0, Math.min(1, translation.x / root.span)); root.moved(root._f) }
        onActiveChanged: if (!active) { const c = root._f > 0.33 || centroid.velocity.x > 800; root._f = 0; root.finished(c) }
    }
}
