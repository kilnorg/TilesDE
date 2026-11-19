.pragma library
// Default Start tile layouts (data only, no Theme access). Shared by StartScreen and the Settings start+theme preview.
// Tile fields: id (key for Personalise.tileColors and Theme.tileColor), label, glyph (TileGlyph name),
// size small|medium|wide|large, group (name in Personalise.groups, "" = top block above the first group header),
// color (index into Theme.tilePalette, wrapped), live (flips), picture (true = photo tile, uses Personalise.startPhoto
// or a built-in photo), badge (count, 0 = none; WP8-style number in the tile corner).
// Colour indices: palette order is glaze [terracotta, ink, paper], classic [yellow, blue, green, red], mono [4 greys].
// Indices cycle 0..3 so 3-colour palettes still alternate (index 3 wraps to 0).

var tiles = [
    { id: "phone",    label: "Phone",    glyph: "phone",    size: "small",  group: "",             color: 0, live: false, picture: false, badge: 0 },
    { id: "message",  label: "Messages", glyph: "message",  size: "small",  group: "",             color: 1, live: false, picture: false, badge: 4 },
    { id: "camera",   label: "Camera",   glyph: "camera",   size: "small",  group: "",             color: 2, live: false, picture: false, badge: 0 },
    { id: "music",    label: "Music",    glyph: "music",    size: "small",  group: "",             color: 3, live: false, picture: false, badge: 0 },
    { id: "calendar", label: "Calendar", glyph: "calendar", size: "medium", group: "Productivity", color: 0, live: true,  picture: false, badge: 0 },
    { id: "mail",     label: "Mail",     glyph: "mail",     size: "medium", group: "Productivity", color: 1, live: true,  picture: false, badge: 3 },
    { id: "notes",    label: "Notes",    glyph: "notes",    size: "small",  group: "Productivity", color: 2, live: false, picture: false, badge: 0 },
    { id: "files",    label: "Files",    glyph: "files",    size: "small",  group: "Productivity", color: 3, live: false, picture: false, badge: 0 },
    { id: "clock",    label: "Clock",    glyph: "clock",    size: "small",  group: "Productivity", color: 1, live: false, picture: false, badge: 0 },
    { id: "terminal", label: "Terminal", glyph: "terminal", size: "small",  group: "Productivity", color: 0, live: false, picture: false, badge: 0 },
    { id: "weather",  label: "Weather",  glyph: "weather",  size: "wide",   group: "Explore",      color: 0, live: true,  picture: false, badge: 0 },
    { id: "photos",   label: "Photos",   glyph: "photos",   size: "medium", group: "Explore",      color: 2, live: true,  picture: true,  badge: 0 },
    { id: "people",   label: "People",   glyph: "people",   size: "medium", group: "Explore",      color: 1, live: true,  picture: true,  badge: 0 },
    { id: "maps",     label: "Maps",     glyph: "maps",     size: "small",  group: "Explore",      color: 3, live: false, picture: false, badge: 0 },
    { id: "browser",  label: "Browser",  glyph: "browser",  size: "small",  group: "Explore",      color: 0, live: false, picture: false, badge: 0 },
    { id: "store",    label: "Store",    glyph: "store",    size: "medium", group: "Explore",      color: 2, live: true,  picture: false, badge: 5 },
    { id: "settings", label: "Settings", glyph: "settings", size: "small",  group: "Explore",      color: 1, live: false, picture: false, badge: 0 },
    { id: "wallet",   label: "Wallet",   glyph: "wallet",   size: "small",  group: "Explore",      color: 3, live: false, picture: false, badge: 0 },
    { id: "noxal",    label: "Noxal",    glyph: "noxal",    size: "small",  group: "Explore",      color: 0, live: false, picture: false, badge: 0 }
]

// compact layout for the Settings live preview (fits a ~1/2-scale phone)
var previewIds = ["phone", "message", "camera", "music", "calendar", "mail", "weather", "photos", "people", "store"]

function copy(t) { var o = {}; for (var k in t) o[k] = t[k]; return o }

// all default tiles (fresh copies, safe to mutate / append to a ListModel)
function defaultTiles() { var r = []; for (var i = 0; i < tiles.length; i++) r.push(copy(tiles[i])); return r }

// preview tiles; with 3 columns wide tiles stay wide (they span the 3-column row, see Theme.tileW)
function previewTiles() {
    var r = []
    for (var i = 0; i < previewIds.length; i++) { var t = find(previewIds[i]); if (t) r.push(t) }
    return r
}

function find(id) { for (var i = 0; i < tiles.length; i++) if (tiles[i].id === id) return copy(tiles[i]); return null }

// default palette index of a tile id (0 for unknown ids)
function colorIndex(id) { var t = find(id); return t ? t.color : 0 }

// tiles of one group, in order. groupName "" = top block
function tilesInGroup(list, groupName) {
    var r = []
    for (var i = 0; i < list.length; i++) if ((list[i].group || "") === groupName) r.push(list[i])
    return r
}

// group names used by the default layout, in order (matches Personalise defaults: Productivity, Explore)
function defaultGroups() {
    var seen = [], r = []
    for (var i = 0; i < tiles.length; i++) {
        var g = tiles[i].group
        if (g && seen.indexOf(g) < 0) { seen.push(g); r.push({ name: g, collapsed: false }) }
    }
    return r
}
