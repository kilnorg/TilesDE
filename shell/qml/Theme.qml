pragma Singleton
import QtQuick
import FlowShell

// Design tokens. Default: "Tiles" (Windows-Phone-style flat black/white with solid accent tiles, see docs/tiles-spec.md).
// Previous default: "AnthropicGlassIcons" (alias anthropic-glass-icons): flat Kiln cut-paper wallpaper,
// flat paper surfaces with hairline strokes, serif clock, Liquid-Glass ICONS only.
// Others stay selectable: LiquidGlass (full-surface glass), Minimalist, MaterialYou, AnthropicDesign.
// Runtime: Theme.select("minimalist"); Theme.dark = true.
QtObject {
    id: t
    property string name: "Tiles"
    // Scheme: bound to Personalise.scheme (dark | amoled | light). `dark` is true for dark and amoled.
    // Legacy writes (Theme.dark = x) are accepted: they are forwarded to Personalise.scheme and the binding is restored.
    // Prefer Personalise.scheme or Theme.setDark(b).
    property bool dark: Personalise.scheme !== "light"
    property bool reduceTransparency: false
    // Effective reduce-motion: system flag (Services) or Personalise.motion === "off". Legacy writes (Theme.reduceMotion = x)
    // are taken as the system flag. Prefer Theme.systemReduceMotion = x.
    property bool systemReduceMotion: false
    property bool reduceMotion: systemReduceMotion || Personalise.motion === "off"
    function setDark(b) { Personalise.scheme = b ? (Personalise.scheme === "light" ? "dark" : Personalise.scheme) : "light" }
    function _bindDark() { dark = Qt.binding(function() { return Personalise.scheme !== "light" }) }
    function _bindMotion() { reduceMotion = Qt.binding(function() { return t.systemReduceMotion || Personalise.motion === "off" }) }
    function _bindAccent() { userAccent = Qt.binding(function() { return Personalise.accent }) }
    onDarkChanged: {
        const want = dark ? (Personalise.scheme === "light" ? "dark" : Personalise.scheme) : "light"
        if (Personalise.scheme !== want) { Personalise.scheme = want; _bindDark() }
    }
    onReduceMotionChanged: {
        const expect = systemReduceMotion || Personalise.motion === "off"
        if (reduceMotion !== expect) { systemReduceMotion = reduceMotion; _bindMotion() }
    }
    onUserAccentChanged: {
        if (Qt.color(Personalise.accent).toString() !== userAccent.toString()) { Personalise.accent = userAccent.toString(); _bindAccent() }
    }
    // a same-value legacy write drops a binding without a change signal: restore all three whenever the store changes
    readonly property Connections _store: Connections {
        target: Personalise
        function onSchemeChanged() { t._bindDark() }
        function onMotionChanged() { t._bindMotion() }
        function onAccentChanged() { t._bindAccent() }
    }
    property string glass: "full"          // power ladder: full | blur | flat
    property var backdrop: null            // shared downsampled wallpaper source (set by Main)
    property var backdropItem: null
    property int scrollTick: 0              // bumped while pages scroll so lens origins re-evaluate
    readonly property var names: ["Tiles", "AnthropicGlassIcons", "LiquidGlass", "Minimalist", "MaterialYou", "AnthropicDesign"]

    function select(n) {
        const k = String(n).toLowerCase().replace(/[-_ ]/g, "")
        for (const x of names) if (x.toLowerCase() === k) { name = x; console.log("theme ->", x); return true }
        console.log("theme unknown:", n)
        return false
    }

    readonly property var sets: ({
        Tiles: {
            surfGlass: false, iconGlass: false, radius: 0, tileRadius: 0, blur: 0, refraction: 0, bezel: 1, rim: 0, wall: null,
            light: { text: "#000000", dim: "#5f5f5f", accent: "#D97757", tint: "#ffffff", tintA: 0.0, rim: "#000000", flat: "#ffffff", hair: "#000000",
                     onWall: "#000000", w0: "#ffffff", w1: "#ffffff", w2: "#ffffff", w3: "#ffffff", icon: "#000000", card: "#f0f0f0",
                     glassTint: "#ffffff", glyph: "dark" },
            dark:  { text: "#ffffff", dim: "#9a9a9a", accent: "#D97757", tint: "#000000", tintA: 0.0, rim: "#ffffff", flat: "#0a0a0a", hair: "#ffffff",
                     onWall: "#ffffff", w0: "#1c0e0a", w1: "#6e3a29", w2: "#d97757", w3: "#0a0503", icon: "#ffffff", card: "#1b1b1b",
                     glassTint: "#1b1b1b", glyph: "light" } },
        AnthropicGlassIcons: {
            surfGlass: false, iconGlass: true, radius: 14, tileRadius: 17, blur: 0, refraction: 0, bezel: 1, rim: 0,
            wall: { light: "qrc:/FlowShell/assets/wallpapers/kiln-light.png", dark: "qrc:/FlowShell/assets/wallpapers/night-paper-dark.png" },
            light: { text: "#141413", dim: "#6b6a64", accent: "#D97757", tint: "#FAF9F5", tintA: 0.0, rim: "#ffffff", flat: "#FAF9F5F7",
                     hair: "#3d3929", onWall: "#FAF9F5", w0: "#D97757", w1: "#D97757", w2: "#D97757", w3: "#D97757", icon: "#2B2A26", card: "#FAF9F5",
                     glassTint: "#FAF9F5", glyph: "dark" },
            dark:  { text: "#FAF9F5", dim: "#b0aea5", accent: "#D97757", tint: "#262624", tintA: 0.0, rim: "#ffffff", flat: "#262624F7",
                     hair: "#FAF9F5", onWall: "#FAF9F5", w0: "#1d1c1a", w1: "#1d1c1a", w2: "#1d1c1a", w3: "#1d1c1a", icon: "#FAF9F5", card: "#262624",
                     glassTint: "#3a3835", glyph: "light" } },
        LiquidGlass: {
            surfGlass: true, iconGlass: true, radius: 28, tileRadius: 16, blur: 22, refraction: 20, bezel: 26, rim: 0.85,
            wall: null,
            light: { text: "#12151c", dim: "#5c6272", accent: "#2f7bff", tint: "#ffffff", tintA: 0.14, rim: "#ffffff", flat: "#d8dfeaE6", hair: "#12151c",
                     onWall: "#12151c", w0: "#bcd3ff", w1: "#ffd6e8", w2: "#6ea8ff", w3: "#ffb48a", icon: "#2b3040", card: "#ffffff", glassTint: "#ffffff", glyph: "dark" },
            dark:  { text: "#f4f6fb", dim: "#a2a9ba", accent: "#5ea0ff", tint: "#10131c", tintA: 0.22, rim: "#ffffff", flat: "#1c2130E6", hair: "#f4f6fb",
                     onWall: "#f4f6fb", w0: "#0b1030", w1: "#2a1040", w2: "#2459c8", w3: "#c4457a", icon: "#e8ecf6", card: "#141824", glassTint: "#20263a", glyph: "light" } },
        Minimalist: {
            surfGlass: false, iconGlass: false, radius: 14, tileRadius: 10, blur: 0, refraction: 0, bezel: 1, rim: 0, wall: null,
            light: { text: "#111111", dim: "#777777", accent: "#111111", tint: "#ffffff", tintA: 0.0, rim: "#000000", flat: "#f6f6f6F2", hair: "#111111",
                     onWall: "#111111", w0: "#fafafa", w1: "#ececec", w2: "#f2f2f2", w3: "#e4e4e4", icon: "#111111", card: "#ffffff", glassTint: "#ffffff", glyph: "dark" },
            dark:  { text: "#f2f2f2", dim: "#8a8a8a", accent: "#f2f2f2", tint: "#000000", tintA: 0.0, rim: "#ffffff", flat: "#141414F2", hair: "#f2f2f2",
                     onWall: "#f2f2f2", w0: "#050505", w1: "#101010", w2: "#0a0a0a", w3: "#1a1a1a", icon: "#f2f2f2", card: "#161616", glassTint: "#222222", glyph: "light" } },
        MaterialYou: {
            surfGlass: false, iconGlass: false, radius: 32, tileRadius: 26, blur: 0, refraction: 0, bezel: 1, rim: 0, wall: null,
            light: { text: "#1d1b20", dim: "#49454f", accent: "#6750a4", tint: "#ffffff", tintA: 0.0, rim: "#ffffff", flat: "#ece6f0FF", hair: "#1d1b20",
                     onWall: "#1d1b20", w0: "#f7f2fa", w1: "#e8def8", w2: "#d0bcff", w3: "#efb8c8", icon: "#4a4458", card: "#f3edf7", glassTint: "#ffffff", glyph: "dark" },
            dark:  { text: "#e6e0e9", dim: "#cac4d0", accent: "#d0bcff", tint: "#000000", tintA: 0.0, rim: "#ffffff", flat: "#2b2930FF", hair: "#e6e0e9",
                     onWall: "#e6e0e9", w0: "#141218", w1: "#211f26", w2: "#381e72", w3: "#4a2532", icon: "#e8def8", card: "#211f26", glassTint: "#2b2930", glyph: "light" } },
        AnthropicDesign: {
            surfGlass: false, iconGlass: false, radius: 20, tileRadius: 14, blur: 0, refraction: 0, bezel: 1, rim: 0, wall: null,
            light: { text: "#141413", dim: "#6b6a64", accent: "#d97757", tint: "#ffffff", tintA: 0.0, rim: "#ffffff", flat: "#faf9f5F5", hair: "#141413",
                     onWall: "#141413", w0: "#f0eee6", w1: "#e8e6dc", w2: "#ebdbbc", w3: "#e4b8a4", icon: "#141413", card: "#faf9f5", glassTint: "#faf9f5", glyph: "dark" },
            dark:  { text: "#faf9f5", dim: "#b0aea5", accent: "#d97757", tint: "#141413", tintA: 0.0, rim: "#ffffff", flat: "#262624F5", hair: "#faf9f5",
                     onWall: "#faf9f5", w0: "#141413", w1: "#1f1e1d", w2: "#3a2a22", w3: "#5a2f22", icon: "#faf9f5", card: "#262624", glassTint: "#262624", glyph: "light" } }
    })
    readonly property var cur: sets[name] || sets.AnthropicGlassIcons
    readonly property var c: tiles ? tilesC : (dark ? cur.dark : cur.light)

    readonly property color text: c.text
    readonly property color textDim: c.dim
    readonly property color iconInk: c.icon
    readonly property color card: c.card
    readonly property color flatSurface: c.flat
    readonly property color hairline: Qt.rgba(Qt.color(c.hair).r, Qt.color(c.hair).g, Qt.color(c.hair).b, dark ? 0.22 : 0.20)
    readonly property color onWall: c.onWall
    readonly property color wall0: c.w0
    readonly property color wall1: c.w1
    readonly property color wall2: c.w2
    readonly property color wall3: c.w3
    readonly property string wallpaperSource: cur.wall ? (dark ? cur.wall.dark : cur.wall.light) : ""
    readonly property real radius: cur.radius
    readonly property real tileRadius: tiles ? Personalise.tileRadius : cur.tileRadius

    // surface glass level: 0 full lensing, 1 blur only, 2 flat. Forced flat by reduce-transparency or flat-surface themes.
    property bool animPause: false      // screen off or an app covers the home screen: idle/live animations stop
    readonly property int quality: (reduceTransparency || !cur.surfGlass) ? 2 : glass === "flat" ? 2 : glass === "blur" ? 1 : 0
    // icon glass level: same ladder, but only for themes with glass icons.
    readonly property int iconQuality: (reduceTransparency || !cur.iconGlass) ? 2 : glass === "flat" ? 2 : glass === "blur" ? 1 : 0
    readonly property color tint: c.tint
    readonly property color glassTint: c.glassTint
    readonly property string glyphInk: c.glyph          // "dark" ink glyphs on light glass, "light" on dark glass
    readonly property real tintA: c.tintA
    readonly property color rimColor: c.rim
    readonly property real blurPx: cur.blur
    readonly property real refractPx: cur.refraction
    readonly property real bezelPx: cur.bezel
    readonly property real rim: cur.rim
    readonly property int animMs: Math.round(280 * (tiles ? motionScale : (reduceMotion ? 0 : 1)))
    readonly property bool paper: name === "AnthropicGlassIcons" || name === "AnthropicDesign" || name === "Minimalist"
    readonly property string font: "Inter"
    readonly property string serif: (name === "AnthropicGlassIcons" || name === "AnthropicDesign") ? "Noto Serif" : "Inter"

    // ---- Tiles theme (see docs/tiles-spec.md, section Personalisation) ----
    // Everything below reads the persisted store `Personalise` (shell/src/Personalise.h) and applies live.
    // Accent: other themes use their own; "Tiles" uses the user-selectable accent. Theme.userAccent (writable, forwarded to
    // Personalise.accent), Theme.setAccent(i) picks from `accents`.
    readonly property var accents: Personalise.accentColours
    readonly property var accentNames: Personalise.accentNames
    property color userAccent: Personalise.accent
    function setAccent(i) { if (i >= 0 && i < accents.length) Personalise.accent = accents[i] }
    readonly property color accent: tiles ? userAccent : c.accent
    readonly property bool tiles: name === "Tiles"

    // preset and scheme
    readonly property string preset: Personalise.preset
    readonly property var presetDef: Personalise.currentPreset
    readonly property string scheme: Personalise.scheme          // dark | amoled | light
    readonly property bool amoled: Personalise.scheme === "amoled"
    readonly property bool light: !dark
    readonly property color presetAccent: Qt.color(presetDef.accent || "#D97757")
    // base colours of the Tiles theme for the current preset and scheme (feeds `c`, so text/textDim/card/flatSurface follow)
    readonly property var tilesC: {
        const p = presetDef, base = dark ? sets.Tiles.dark : sets.Tiles.light
        const o = { accent: Personalise.accent }
        if (dark) {
            o.text = p.textDark || base.text; o.dim = p.dimDark || base.dim
            o.card = amoled ? "#121212" : (p.cardDark || base.card)
            o.flat = amoled ? "#000000" : (p.bgDark || base.flat)
            o.glassTint = o.card
        } else {
            o.card = p.cardLight || base.card; o.flat = p.bgLight || base.flat
        }
        return Object.assign({}, base, o)
    }
    readonly property color pageBg: !tiles ? (dark ? "#000000" : "#ffffff")
                                    : amoled ? "#000000" : dark ? Qt.color(presetDef.bgDark || "#000000") : Qt.color(presetDef.bgLight || "#ffffff")

    // tile palette: preset palette with the preset's own accent swatch replaced by the live accent
    readonly property var tilePalette: {
        const pal = presetDef.palette || [], pa = presetAccent.toString(), out = []
        for (let i = 0; i < pal.length; i++) out.push(Qt.color(pal[i]).toString() === pa ? userAccent : Qt.color(pal[i]))
        if (!out.length) out.push(userAccent)
        return out
    }
    // fill colour of tile `id`: per-tile override, else palette[defaultIndex mod size]
    function tileColor(id, defaultIndex) {
        const m = Personalise.tileColors
        if (id !== undefined && m && m[id]) return Qt.color(m[id])
        const pal = tilePalette
        return pal[((defaultIndex | 0) % pal.length + pal.length) % pal.length]
    }
    function hasTileColor(id) { const m = Personalise.tileColors; return !!(m && m[id]) }
    // ink for a fill: white unless white would drop under 3:1 (large text), then black. terracotta keeps white (3.12:1).
    function _lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    function luminance(col) { const q = Qt.color(col); return 0.2126 * _lin(q.r) + 0.7152 * _lin(q.g) + 0.0722 * _lin(q.b) }
    function contrast(a, b) { const x = luminance(a), y = luminance(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) }
    function onColor(fill) { return contrast("#ffffff", fill) >= 3.0 ? "#ffffff" : "#000000" }
    // swatches for a preset picker (does not apply it): { bg, card, text, accent, palette[] } for the current scheme
    function presetInfo(pname) {
        const _dep = Personalise.customPresets      // re-evaluate when custom presets change
        const p = Personalise.presetData(pname), pal = [], pa = Qt.color(p.accent || "#D97757").toString()
        const pp = p.palette || []
        for (let i = 0; i < pp.length; i++) pal.push(Qt.color(pp[i]))
        return { name: pname, custom: !!p.custom, accent: Qt.color(p.accent || "#D97757"), palette: pal,
                 bg: amoled ? Qt.color("#000000") : Qt.color(dark ? (p.bgDark || "#000000") : (p.bgLight || "#ffffff")),
                 card: Qt.color(dark ? (p.cardDark || "#1b1b1b") : (p.cardLight || "#f0f0f0")),
                 text: Qt.color(dark ? (p.textDark || "#ffffff") : "#000000") }
    }

    readonly property color tileText: "#ffffff"          // default glyph and label on a solid accent fill (use onColor(fill) for palette tiles)
    readonly property color tileBack: Qt.darker(accent, 1.18)   // flip back face
    function tileBackOf(fill) { return Qt.darker(fill, 1.18) }
    readonly property color tileDisabled: dark ? "#2a2a2a" : "#cfcfcf"

    // tile look
    readonly property real tileOpacity: tiles ? Personalise.tileOpacity : 1.0
    readonly property bool tilesOverWallpaper: tiles && Personalise.tilesOverWallpaper
    readonly property real grain: tiles ? Personalise.grain : 0.0       // paper-grain strength 0..1 for the page background
    readonly property bool showLabels: Personalise.labels
    readonly property bool showBadges: Personalise.badges
    readonly property string startPhoto: Personalise.startPhoto
    readonly property var groups: Personalise.groups                    // [{name, collapsed}]

    // layout
    readonly property int tileGap: tiles ? Personalise.gap : 6
    readonly property int gap: tileGap
    readonly property int pageMargin: 12
    readonly property int tileCols: tiles ? Personalise.columns : 4
    readonly property real glyphStroke: 3.6
    // edge of one small tile for a screen of given width: tileCols columns, inner gaps, margin on both sides
    function tileUnit(w) { return Math.floor((w - 2 * pageMargin - (tileCols - 1) * tileGap) / tileCols) }
    // width of one full row of tiles (wide / large tiles span it)
    function rowWidth(w) { return tileCols * tileUnit(w) + (tileCols - 1) * tileGap }
    // pixel size (w, h) of a tile size name on a screen of width w. small 1x1, medium 2x2, wide = row x 2u, large = row x row.
    function tileW(size, w) { const u = tileUnit(w); return size === "small" ? u : size === "medium" ? 2 * u + tileGap : rowWidth(w) }
    function tileH(size, w) { const u = tileUnit(w); return size === "small" ? u : size === "wide" || size === "medium" ? 2 * u + tileGap : rowWidth(w) }

    // typography
    readonly property int fontLight: tiles ? Personalise.fontWeight : Font.Light     // weight of titles and big numbers (100..900)
    readonly property int fontWeightTitle: fontLight
    readonly property string titleCase: Personalise.titleCase                        // lower | upper
    function title(s) { return Personalise.titleCase === "upper" ? String(s).toUpperCase() : String(s).toLowerCase() }

    // motion. motionScale: off 0, low 0.6, normal 1, high 1.4. All durations are 0 under reduceMotion.
    readonly property real motionScale: reduceMotion ? 0 : ({ off: 0, low: 0.6, normal: 1.0, high: 1.4 })[Personalise.motion]
    readonly property real tiltScale: ({ off: 0, low: 0.5, normal: 1.0, high: 1.5 })[Personalise.motion]
    readonly property int flipSpeed: Personalise.flipSpeed                        // 0 off, 1 normal, 2 fast
    readonly property bool flipEnabled: !reduceMotion && flipSpeed > 0
    readonly property int flipMs: flipEnabled ? Math.round((flipSpeed === 2 ? 650 : 1000) * Math.max(0.6, motionScale)) : 0
    readonly property int flipPeriodMs: flipSpeed === 2 ? 5000 : 8000
    readonly property int flipStaggerMs: 140
    readonly property int pressMs: Math.round(140 * motionScale)
    readonly property int turnstileMs: Math.round(320 * motionScale)
}
