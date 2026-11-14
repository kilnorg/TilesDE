import QtQuick
import FlowShell

// Own line-icon renderer: hand-authored paths on a 48x48 grid, stroked with a constant pixel width.
// Names: phone message mail calendar clock photos music maps notes files weather terminal store camera
//        settings people browser wallet noxal video, plus UI glyphs: search star back forward plus close grid.
// Unknown name draws a rounded square. No third-party artwork.
Canvas {
    id: root
    property string name: ""
    property color color: Theme.tileText
    property real stroke: Theme.glyphStroke      // pixels on screen, independent of size
    property real size: 56
    width: size; height: size
    antialiasing: true

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onSizeChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // ---- path helpers (48x48 coordinates) ----
    function rr(c, x, y, w, h, r) {
        c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r)
        c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
        c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r)
        c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y); c.closePath()
    }
    function ell(c, cx, cy, rx, ry) {
        const k = 0.5523
        c.moveTo(cx + rx, cy)
        c.bezierCurveTo(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry)
        c.bezierCurveTo(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy)
        c.bezierCurveTo(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry)
        c.bezierCurveTo(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy)
        c.closePath()
    }
    function ln(c, x1, y1, x2, y2) { c.moveTo(x1, y1); c.lineTo(x2, y2) }

    function draw(c, n) {
        switch (n) {
        case "phone":
            c.moveTo(13, 6); c.lineTo(19, 6); c.lineTo(23, 16); c.lineTo(18, 20)
            c.bezierCurveTo(20, 26, 24, 30, 30, 32); c.lineTo(34, 27); c.lineTo(44, 31); c.lineTo(44, 37)
            c.bezierCurveTo(44, 40, 42, 42, 39, 42); c.bezierCurveTo(21, 42, 6, 27, 6, 9)
            c.bezierCurveTo(6, 7, 8, 6, 10, 6); c.closePath(); break
        case "message":
            c.moveTo(7, 8); c.lineTo(41, 8); c.lineTo(41, 33); c.lineTo(26, 33); c.lineTo(16, 42); c.lineTo(16, 33); c.lineTo(7, 33); c.closePath()
            ln(c, 14, 17, 34, 17); ln(c, 14, 25, 28, 25); break
        case "mail":
            rr(c, 5, 10, 38, 28, 2); c.moveTo(5, 13); c.lineTo(24, 28); c.lineTo(43, 13); break
        case "calendar":
            rr(c, 6, 10, 36, 32, 2); ln(c, 6, 19, 42, 19); ln(c, 15, 5, 15, 14); ln(c, 33, 5, 33, 14)
            ln(c, 14, 27, 18, 27); ln(c, 22, 27, 26, 27); ln(c, 30, 27, 34, 27); ln(c, 14, 34, 18, 34); ln(c, 22, 34, 26, 34); break
        case "clock":
            ell(c, 24, 24, 18, 18); c.moveTo(24, 12); c.lineTo(24, 24); c.lineTo(32, 29); break
        case "photos":
            rr(c, 5, 8, 38, 32, 2); ell(c, 16, 19, 3.5, 3.5)
            c.moveTo(5, 35); c.lineTo(17, 24); c.lineTo(26, 32); c.lineTo(32, 26); c.lineTo(43, 36); break
        case "music":
            ell(c, 15, 36, 5.5, 4.5); ell(c, 35, 32, 5.5, 4.5)
            c.moveTo(20.5, 36); c.lineTo(20.5, 11); c.lineTo(40.5, 6); c.lineTo(40.5, 32); break
        case "maps":
            c.moveTo(24, 44); c.bezierCurveTo(14, 32, 10, 26, 10, 19); c.bezierCurveTo(10, 11.3, 16.3, 5, 24, 5)
            c.bezierCurveTo(31.7, 5, 38, 11.3, 38, 19); c.bezierCurveTo(38, 26, 34, 32, 24, 44); c.closePath()
            ell(c, 24, 19, 5, 5); break
        case "notes":
            rr(c, 9, 5, 30, 38, 2); ln(c, 16, 15, 32, 15); ln(c, 16, 23, 32, 23); ln(c, 16, 31, 26, 31); break
        case "files":
            c.moveTo(5, 11); c.lineTo(19, 11); c.lineTo(24, 17); c.lineTo(43, 17); c.lineTo(43, 38); c.lineTo(5, 38); c.closePath()
            ln(c, 5, 23, 43, 23); break
        case "weather":
            ell(c, 24, 24, 8, 8)
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4, ca = Math.cos(a), sa = Math.sin(a)
                ln(c, 24 + ca * 13, 24 + sa * 13, 24 + ca * 19, 24 + sa * 19)
            }
            break
        case "terminal":
            rr(c, 5, 8, 38, 32, 2); c.moveTo(13, 17); c.lineTo(21, 24); c.lineTo(13, 31); ln(c, 25, 32, 35, 32); break
        case "store":
            rr(c, 8, 15, 32, 27, 2); c.moveTo(16, 15); c.lineTo(16, 12); c.bezierCurveTo(16, 3, 32, 3, 32, 12); c.lineTo(32, 15); break
        case "camera":
            c.moveTo(5, 14); c.lineTo(15, 14); c.lineTo(18, 9); c.lineTo(30, 9); c.lineTo(33, 14); c.lineTo(43, 14); c.lineTo(43, 39); c.lineTo(5, 39); c.closePath()
            ell(c, 24, 26, 8, 8); break
        case "settings": {
            const teeth = 8, ro = 18, ri = 13.5
            for (let i = 0; i < teeth; i++) {
                const a0 = (i / teeth) * 2 * Math.PI, w = Math.PI / teeth * 0.5, wi = Math.PI / teeth * 0.8
                const pts = [[ri, a0 - wi], [ro, a0 - w], [ro, a0 + w], [ri, a0 + wi]]
                for (let j = 0; j < 4; j++) {
                    const x = 24 + Math.cos(pts[j][1]) * pts[j][0], y = 24 + Math.sin(pts[j][1]) * pts[j][0]
                    if (i === 0 && j === 0) c.moveTo(x, y); else c.lineTo(x, y)
                }
            }
            c.closePath(); ell(c, 24, 24, 6, 6); break }
        case "people":
            ell(c, 24, 16, 7.5, 7.5)
            c.moveTo(9, 42); c.bezierCurveTo(9, 32, 16, 27, 24, 27); c.bezierCurveTo(32, 27, 39, 32, 39, 42); break
        case "browser":
            ell(c, 24, 24, 18, 18); ell(c, 24, 24, 8, 18); ln(c, 6, 24, 42, 24); ln(c, 9, 14, 39, 14); ln(c, 9, 34, 39, 34); break
        case "wallet":
            rr(c, 5, 12, 38, 28, 3); c.moveTo(5, 19); c.lineTo(43, 19)
            rr(c, 29, 25, 14, 9, 2); break
        case "noxal":
            c.moveTo(12, 39); c.lineTo(12, 9); c.lineTo(36, 39); c.lineTo(36, 9); break
        case "video":
            rr(c, 5, 9, 38, 30, 3); c.moveTo(20, 17); c.lineTo(32, 24); c.lineTo(20, 31); c.closePath(); break
        // UI glyphs
        case "search":
            ell(c, 21, 21, 12, 12); ln(c, 30, 30, 41, 41); break
        case "star": {
            for (let i = 0; i < 10; i++) {
                const a = -Math.PI / 2 + i * Math.PI / 5, r = (i % 2 === 0) ? 18 : 7.5
                const x = 24 + Math.cos(a) * r, y = 25 + Math.sin(a) * r
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
            }
            c.closePath(); break }
        case "back":
            ln(c, 40, 24, 8, 24); c.moveTo(20, 12); c.lineTo(8, 24); c.lineTo(20, 36); break
        case "forward":
            ln(c, 8, 24, 40, 24); c.moveTo(28, 12); c.lineTo(40, 24); c.lineTo(28, 36); break
        case "plus":
            ln(c, 24, 8, 24, 40); ln(c, 8, 24, 40, 24); break
        case "close":
            ln(c, 10, 10, 38, 38); ln(c, 38, 10, 10, 38); break
        case "grid":
            for (let r = 0; r < 3; r++) for (let q = 0; q < 3; q++) rr(c, 8 + q * 11.5, 8 + r * 11.5, 8, 8, 1)
            break
        default:
            rr(c, 8, 8, 32, 32, 6)
        }
    }

    // filled accents drawn under the strokes (solid or tinted), 48x48 coordinates
    function fills(c, n) {
        c.fillStyle = root.color
        if (n === "mail") {
            c.globalAlpha = 0.3; c.beginPath(); rr(c, 5, 10, 38, 28, 2); c.fill()
            c.globalAlpha = 1; c.beginPath(); c.moveTo(5, 12); c.lineTo(24, 28); c.lineTo(43, 12); c.lineTo(43, 10); c.lineTo(5, 10); c.closePath(); c.fill()
        } else if (n === "store") {
            c.globalAlpha = 0.3; c.beginPath(); rr(c, 8, 15, 32, 27, 2); c.fill()
            c.globalAlpha = 1; c.beginPath(); c.rect(8, 15, 32, 5); c.fill()
        } else if (n === "calendar") {
            c.globalAlpha = 1; c.beginPath(); c.rect(6, 10, 36, 9); c.fill()
            c.globalAlpha = 0.3; c.beginPath(); c.rect(6, 19, 36, 23); c.fill()
        } else if (n === "people") {
            c.globalAlpha = 1; c.beginPath(); ell(c, 24, 16, 7.5, 7.5); c.fill()
            c.globalAlpha = 0.3; c.beginPath(); c.moveTo(9, 42); c.bezierCurveTo(9, 32, 16, 27, 24, 27); c.bezierCurveTo(32, 27, 39, 32, 39, 42); c.closePath(); c.fill()
        } else if (n === "star") {
            c.globalAlpha = 1; c.beginPath(); draw(c, "star"); c.fill()
        }
        c.globalAlpha = 1
    }

    onPaint: {
        const c = getContext("2d")
        c.reset()
        const s = Math.min(width, height) / 48
        if (s <= 0) return
        c.translate((width - 48 * s) / 2, (height - 48 * s) / 2)
        c.scale(s, s)
        c.strokeStyle = root.color
        c.lineWidth = root.stroke / s
        c.lineJoin = "round"; c.lineCap = "round"
        fills(c, root.name)
        c.beginPath()
        draw(c, root.name)
        c.stroke()
    }
}
