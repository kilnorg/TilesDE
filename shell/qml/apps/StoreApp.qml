import QtQuick
import FlowShell

// Store: read-only apt front end. Curated built-in package list; install/upgrade runs in a foot terminal with sudo.
// Only package names from `catalog` are ever passed to a command, never user input.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    readonly property var catalog: [
        { name: "Firefox ESR", pkg: "firefox-esr", cat: "internet", desc: "Web browser with extended support releases." },
        { name: "Chromium", pkg: "chromium", cat: "internet", desc: "Open source web browser." },
        { name: "Thunderbird", pkg: "thunderbird", cat: "internet", desc: "Email, calendar and news client." },
        { name: "Transmission", pkg: "transmission-gtk", cat: "internet", desc: "Simple BitTorrent client." },
        { name: "Newsboat", pkg: "newsboat", cat: "internet", desc: "Terminal RSS and Atom feed reader." },
        { name: "VLC", pkg: "vlc", cat: "media", desc: "Plays almost any audio or video format." },
        { name: "mpv", pkg: "mpv", cat: "media", desc: "Minimal, scriptable media player." },
        { name: "cmus", pkg: "cmus", cat: "media", desc: "Fast terminal music player." },
        { name: "Audacity", pkg: "audacity", cat: "media", desc: "Record and edit audio." },
        { name: "FFmpeg", pkg: "ffmpeg", cat: "media", desc: "Convert and process audio and video." },
        { name: "GIMP", pkg: "gimp", cat: "graphics", desc: "Full-featured image editor." },
        { name: "Inkscape", pkg: "inkscape", cat: "graphics", desc: "Vector graphics editor." },
        { name: "Krita", pkg: "krita", cat: "graphics", desc: "Digital painting and illustration." },
        { name: "ImageMagick", pkg: "imagemagick", cat: "graphics", desc: "Command line image conversion and editing." },
        { name: "LibreOffice", pkg: "libreoffice", cat: "office", desc: "Documents, spreadsheets and presentations." },
        { name: "Evince", pkg: "evince", cat: "office", desc: "PDF and document viewer." },
        { name: "Calcurse", pkg: "calcurse", cat: "office", desc: "Terminal calendar and to-do manager." },
        { name: "KeePassXC", pkg: "keepassxc", cat: "utilities", desc: "Offline password manager." },
        { name: "htop", pkg: "htop", cat: "utilities", desc: "Interactive process viewer." },
        { name: "Midnight Commander", pkg: "mc", cat: "utilities", desc: "Two-pane terminal file manager." },
        { name: "tmux", pkg: "tmux", cat: "utilities", desc: "Terminal multiplexer." },
        { name: "Neofetch", pkg: "neofetch", cat: "utilities", desc: "Show system information in the terminal." },
        { name: "Git", pkg: "git", cat: "development", desc: "Distributed version control." },
        { name: "Geany", pkg: "geany", cat: "development", desc: "Small and fast text editor / IDE." },
        { name: "Vim", pkg: "vim", cat: "development", desc: "Modal text editor." },
        { name: "Python 3", pkg: "python3", cat: "development", desc: "Python interpreter." },
        { name: "Node.js", pkg: "nodejs", cat: "development", desc: "JavaScript runtime." },
        { name: "SuperTux", pkg: "supertux", cat: "games", desc: "Classic 2D jump and run platformer." },
        { name: "Extreme Tux Racer", pkg: "extremetuxracer", cat: "games", desc: "Race a penguin down snowy slopes." },
        { name: "GNU Chess", pkg: "gnuchess", cat: "games", desc: "Chess engine for the terminal." }
    ]
    readonly property var categories: ["all", "internet", "media", "graphics", "office", "utilities", "development", "games"]
    readonly property var featuredPkgs: ["firefox-esr", "vlc", "gimp"]

    property var installed: ({})      // pkg -> bool
    property string query: ""
    property string category: "all"
    property string curPkg: ""
    property bool detailOpen: false

    property var upgradable: []       // [{name, text}]
    property string updStatus: "tap check to look for updates"
    property bool updChecking: false

    function entry(pkg) { for (var i = 0; i < catalog.length; ++i) if (catalog[i].pkg === pkg) return catalog[i]; return null }
    function isInstalled(pkg) { return installed[pkg] === true }
    function refreshInstalled() {
        var m = {}
        for (var i = 0; i < catalog.length; ++i) {
            var r = Sys.run("dpkg-query", ["-W", "-f=${Status}", catalog[i].pkg], 3000)
            m[catalog[i].pkg] = !!r && String(r.out).indexOf("install ok installed") >= 0
        }
        installed = m
    }
    function visibleApps(q, cat) {
        q = q.trim().toLowerCase()
        return catalog.filter(function(a) {
            if (cat !== "all" && a.cat !== cat) return false
            return q === "" || a.name.toLowerCase().indexOf(q) >= 0 || a.pkg.indexOf(q) >= 0 || a.desc.toLowerCase().indexOf(q) >= 0
        })
    }
    property var shown: visibleApps(query, category)

    function installCmd(pkg) { return "sudo apt install -y " + pkg }
    function runInTerminal(cmd) {
        // cmd is built only from catalog package names or fixed strings
        if (!Sys.launch("foot", ["-e", "sh", "-c", cmd + "; echo; printf 'done. press enter to close'; read _x"]))
            updStatus = "could not start foot terminal"
    }
    function openDetail(pkg) { curPkg = pkg; detailOpen = true }

    function checkUpdates() {
        updChecking = true
        updStatus = "checking..."
        checkTimer.start()
    }
    function doCheck() {
        var r = Sys.run("apt", ["list", "--upgradable"], 8000)
        updChecking = false
        if (!r || r.code !== 0) { upgradable = []; updStatus = "could not read updates (apt unavailable or timed out)"; return }
        var out = [], lines = String(r.out).split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var l = lines[i].trim()
            if (l === "" || l.indexOf("Listing") === 0 || l.indexOf("WARNING") === 0 || l.indexOf("/") < 0) continue
            var name = l.split("/")[0]
            var parts = l.split(" ")
            var ver = parts.length > 1 ? parts[1] : ""
            var from = l.indexOf("[upgradable from:") >= 0 ? l.substring(l.indexOf("from:") + 5).replace("]", "").trim() : ""
            out.push({ name: name, text: from !== "" ? from + " > " + ver : ver })
        }
        upgradable = out
        updStatus = out.length === 0 ? "everything is up to date" : out.length + (out.length === 1 ? " update available" : " updates available")
    }

    Component.onCompleted: startTimer.start()
    Timer { id: startTimer; interval: 60; onTriggered: root.refreshInstalled() }
    Timer { id: checkTimer; interval: 80; onTriggered: root.doCheck() }

    focus: true
    function back() { if (detailOpen) detailOpen = false; else closeRequested() }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()

    Pivot {
        id: pivot
        y: root.topInset
        width: parent.width
        height: parent.height - root.topInset
        caption: "store"

        PivotPage {
            title: "featured"
            Repeater {
                model: root.featuredPkgs
                Item {
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property var e: root.entry(modelData)
                    readonly property color tint: index === 0 ? Theme.accent : (index === 1 ? Qt.darker(Theme.accent, 1.5) : Qt.darker(Theme.accent, 2.2))
                    width: parent.width; height: 188
                    Rectangle {
                        width: parent.width; height: 180; color: parent.tint
                        opacity: fma.pressed ? 0.7 : 1
                        Column {
                            x: 16; y: 14; width: parent.width - 32; spacing: 4
                            Text {
                                width: parent.width; elide: Text.ElideRight; text: tile.e ? tile.e.name.toLowerCase() : ""
                                color: Theme.onColor(tile.tint)
                                font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                text: tile.e ? tile.e.desc : ""
                                color: Theme.onColor(tile.tint); opacity: 0.85
                                font.family: Theme.font; font.pixelSize: 22
                            }
                        }
                        Text {
                            x: 16; y: parent.height - 36
                            text: root.isInstalled(tile.modelData) ? "installed" : "not installed"
                            color: Theme.onColor(tile.tint); opacity: 0.85
                            font.family: Theme.font; font.pixelSize: 20
                        }
                        MouseArea { id: fma; anchors.fill: parent; onClicked: root.openDetail(tile.modelData) }
                    }
                }
            }
            Text {
                width: parent.width; topPadding: 8; wrapMode: Text.WordWrap
                text: "Kiln Store backend (repo.mandrusia.tech) is coming. for now this lists a curated set of apt packages."
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
            }
        }

        PivotPage {
            title: "apps"
            MetroTextField {
                width: parent.width
                placeholder: "search apps"
                onEdited: root.query = text
            }
            Item { width: 1; height: 10 }
            Flickable {
                width: parent.width; height: 48
                contentWidth: chips.width; contentHeight: 48
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds; clip: true
                Row {
                    id: chips
                    spacing: 8
                    Repeater {
                        model: root.categories
                        Rectangle {
                            required property string modelData
                            readonly property bool sel: root.category === modelData
                            width: chipText.width + 32; height: 48
                            color: sel ? Theme.accent : "transparent"
                            border.width: 2; border.color: sel ? Theme.accent : Theme.text
                            opacity: cha.pressed ? 0.6 : 1
                            Text {
                                id: chipText
                                anchors.centerIn: parent; text: parent.modelData
                                color: parent.sel ? Theme.onColor(Theme.accent) : Theme.text
                                font.family: Theme.font; font.pixelSize: 21; font.weight: Theme.fontLight
                            }
                            MouseArea { id: cha; anchors.fill: parent; onClicked: root.category = parent.modelData }
                        }
                    }
                }
            }
            Item { width: 1; height: 12 }
            Text {
                visible: root.shown.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "no matching apps"
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Repeater {
                model: root.shown
                MetroListRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: modelData.cat + "  ·  " + modelData.desc
                    trailing: root.isInstalled(modelData.pkg) ? "installed" : ""
                    onClicked: root.openDetail(modelData.pkg)
                }
            }
        }

        PivotPage {
            title: "updates"
            Text {
                width: parent.width; wrapMode: Text.WordWrap; bottomPadding: 12
                text: root.updStatus
                color: Theme.textDim; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
            }
            Row {
                spacing: 12
                MetroButton { text: "check"; enabled2: !root.updChecking; onClicked: root.checkUpdates() }
                MetroButton { text: "upgrade all"; accentFill: true; enabled2: root.upgradable.length > 0
                    onClicked: root.runInTerminal("sudo apt upgrade") }
            }
            Item { width: 1; height: 14 }
            Repeater {
                model: root.upgradable
                MetroListRow {
                    required property var modelData
                    title: modelData.name
                    subtitle: modelData.text
                }
            }
        }
    }

    // ---- detail sheet
    Item {
        id: sheet
        anchors.fill: parent
        visible: root.detailOpen
        property var e: root.entry(root.curPkg)
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Flickable {
            x: 18; y: root.topInset + 12
            width: parent.width - 36; height: parent.height - root.topInset - 12
            contentWidth: width; contentHeight: dcol.height + 32
            boundsBehavior: Flickable.StopAtBounds; clip: true
            Column {
                id: dcol
                width: parent.width; spacing: 14
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: sheet.e ? sheet.e.name.toLowerCase() : ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 52; font.weight: Theme.fontLight
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: root.isInstalled(root.curPkg) ? "installed" : "not installed"
                    color: root.isInstalled(root.curPkg) ? Theme.accent : Theme.textDim
                    font.family: Theme.font; font.pixelSize: 26; font.weight: Theme.fontLight
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: sheet.e ? sheet.e.desc : ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: sheet.e ? "package: " + sheet.e.pkg + "  ·  " + sheet.e.cat : ""
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 20
                }
                Text { text: "command"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21 }
                Text {
                    width: parent.width; wrapMode: Text.WrapAnywhere
                    text: root.installCmd(root.curPkg)
                    color: Theme.text; font.family: "monospace"; font.pixelSize: 22
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "opens a terminal and asks for your sudo password there."
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
                }
                MetroButton {
                    width: parent.width
                    text: root.isInstalled(root.curPkg) ? "reinstall / upgrade" : "install"
                    accentFill: true
                    onClicked: { if (root.entry(root.curPkg)) root.runInTerminal(root.installCmd(root.curPkg)) }
                }
                Row {
                    spacing: 12
                    MetroButton { text: "refresh status"; onClicked: root.refreshInstalled() }
                    MetroButton { text: "close"; onClicked: root.detailOpen = false }
                }
            }
        }
    }
}
