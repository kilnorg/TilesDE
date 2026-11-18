import QtQuick
import FlowShell

// Mail app. OFFLINE: a demo mailbox plus locally stored sent mail. No network.
// `provider` is the only mailbox source; replace its functions with a real backend later.
Item {
    id: root
    property real topInset: 36
    signal closeRequested

    // ---- state (persisted under AppStore "mail") ----
    property var msgs: []       // inbox: {id, from, subject, body, ts, read, flag}
    property var sent: []       // {id, to, subject, body, ts}
    property int trash: 0
    property int nextId: 1000

    // views
    property int openId: -1     // message being read (-1 none)
    property bool openSent: false
    property bool composing: false

    readonly property var openMsg: {
        var list = openSent ? sent : msgs
        for (var i = 0; i < list.length; ++i) if (list[i].id === openId) return list[i]
        return null
    }
    readonly property var unreadList: msgs.filter(function(m) { return !m.read })
    readonly property var flaggedList: msgs.filter(function(m) { return m.flag })

    function save() { AppStore.save("mail", { msgs: msgs, sent: sent, trash: trash, nextId: nextId }) }
    Component.onCompleted: {
        var s = AppStore.load("mail", null)
        if (s && s.msgs) { msgs = s.msgs; sent = s.sent || []; trash = s.trash || 0; nextId = s.nextId || 1000 }
        else { msgs = provider.seed(); save() }
    }
    function patch(id, props) {
        msgs = msgs.map(function(m) {
            if (m.id !== id) return m
            var n = {}
            for (var k in m) n[k] = m[k]
            for (var p in props) n[p] = props[p]
            return n
        })
        save()
    }
    function openMessage(id, isSent) {
        openId = id; openSent = isSent
        if (!isSent) patch(id, { read: true })
    }
    function closeMessage() { openId = -1; openSent = false }
    function deleteOpen() {
        if (openMsg === null) return
        var id = openId
        if (openSent) sent = sent.filter(function(m) { return m.id !== id })
        else msgs = msgs.filter(function(m) { return m.id !== id })
        trash += 1
        closeMessage()
        save()
    }
    function startCompose(to, subject) {
        toField.text = to || ""
        subjField.text = subject || ""
        bodyEdit.text = ""
        composing = true
    }
    function sendCompose() {
        if (toField.text.trim() === "") return
        var m = { id: nextId++, to: toField.text.trim(), subject: subjField.text.trim() || "(no subject)", body: bodyEdit.text, ts: Date.now() }
        sent = [m].concat(sent)
        composing = false
        closeMessage()
        save()
    }
    function timeStr(ts) {
        var d = new Date(ts), n = new Date()
        if (d.toDateString() === n.toDateString()) return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
        return ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"][d.getMonth()] + " " + d.getDate()
    }
    function fullTime(ts) { var d = new Date(ts); return timeStr(ts) + "  " + d.getFullYear() }
    function preview(b) { return String(b).replace(/\s+/g, " ").substring(0, 120) }

    // ---- data provider (offline demo mailbox) ----
    QtObject {
        id: provider
        function seed() {
            var H = 3600000, now = Date.now()
            var raw = [
                ["Ada Lovelace", "Notes on the engine", "I have finished the annotations you asked for. The third note runs longer than planned, but I think the extra length is justified.\n\nCome by on Thursday and we can go through them together.\n\nAda", 1, 0, 0],
                ["Grace Hopper", "Compiler lunch", "A few of us are meeting at noon to argue about compilers again. Bring your strongest opinion about nanoseconds.\n\nGrace", 3, 0, 1],
                ["Demo Team", "Welcome to TilesDE mail", "This mailbox is offline demo data. Messages you read, flag or delete here are stored locally only; nothing is sent over the network.\n\nWhen a real backend exists it will replace this list.", 5, 0, 0],
                ["Alan Turing", "Re: halting question", "Short answer: no. Longer answer attached in my next message, once I stop being distracted by the tea.\n\nA.", 9, 1, 0],
                ["Katherine Johnson", "Trajectory check", "The numbers match to the fourth decimal. I would still like a second pair of eyes before we sign off.\n\nKatherine", 20, 0, 1],
                ["Linus Pauling", "Weekend hike", "Forecast looks clear on Saturday. Meet at the trailhead at eight? Bring water and the good boots.", 27, 1, 0],
                ["Hedy Lamarr", "Frequency hopping draft", "Attached is the second draft of the writeup. The diagrams still need work, so be kind about the arrows.\n\nHedy", 31, 0, 0],
                ["Margaret Hamilton", "Review request", "Could you review the checklist before Friday? Every line matters, especially the ones that look boring.\n\nMargaret", 50, 1, 1],
                ["Tim Berners-Lee", "Links", "Quick idea: what if every document could point at every other document? Probably nothing. Thoughts?\n\nTim", 72, 1, 0],
                ["Radia Perlman", "Spanning tree poem", "Algorithm, I think that I shall never see\nA graph more lovely than a tree.\n\nStill my favourite way to start a meeting.", 96, 1, 0],
                ["Dennis Ritchie", "Hello, world", "Remember to free what you malloc. Also: hello.\n\nD.", 120, 1, 0],
                ["Barbara Liskov", "Substitutability", "A subtype should behave like the type it replaces. Please do not write that on a mug; I have seen enough mugs.\n\nBarbara", 150, 1, 0]
            ]
            return raw.map(function(r, i) {
                return { id: i + 1, from: r[0], subject: r[1], body: r[2], ts: now - r[3] * H, read: !!r[4], flag: !!r[5] }
            })
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.pageBg }

    // mail list row
    component MailRow: Item {
        id: mr
        property string who: ""
        property string subject: ""
        property string body: ""
        property string when: ""
        property bool unread: false
        property bool flagged: false
        signal clicked
        width: parent ? parent.width : 360
        height: 92
        opacity: ma.pressed ? 0.6 : 1
        Rectangle { visible: mr.unread; x: -10; y: 10; width: 4; height: 72; color: Theme.accent }
        Text {
            x: 0; y: 4; width: parent.width - 80; text: mr.who; elide: Text.ElideRight
            color: mr.unread ? Theme.accent : Theme.text
            font.family: Theme.font; font.pixelSize: 24; font.weight: mr.unread ? Font.Normal : Theme.fontLight
        }
        Text {
            anchors.right: parent.right; y: 8; text: mr.when; color: Theme.textDim
            font.family: Theme.font; font.pixelSize: 17
        }
        Text {
            x: 0; y: 34; width: parent.width - (mr.flagged ? 36 : 0); text: mr.subject; elide: Text.ElideRight
            color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.weight: mr.unread ? Font.Normal : Theme.fontLight
        }
        Text {
            x: 0; y: 60; width: parent.width; text: root.preview(mr.body); elide: Text.ElideRight
            color: Theme.textDim; font.family: Theme.font; font.pixelSize: 17
        }
        TileGlyph { visible: mr.flagged; anchors.right: parent.right; y: 34; name: "star"; size: 26; color: Theme.accent; stroke: 2 }
        MouseArea { id: ma; anchors.fill: parent; onClicked: mr.clicked() }
    }

    component EmptyNote: Text {
        width: parent ? parent.width : 300
        wrapMode: Text.Wrap
        color: Theme.textDim; font.family: Theme.font; font.pixelSize: 22
    }

    Pivot {
        id: pivot
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: root.topInset
        anchors.bottom: mainBar.top
        caption: "mail"

        PivotPage {
            title: "inbox"
            EmptyNote { visible: root.msgs.length === 0; text: "inbox is empty." }
            Repeater {
                model: root.msgs
                MailRow {
                    required property var modelData
                    who: modelData.from; subject: modelData.subject; body: modelData.body
                    when: root.timeStr(modelData.ts); unread: !modelData.read; flagged: modelData.flag
                    onClicked: root.openMessage(modelData.id, false)
                }
            }
            Item { width: 1; height: 10 }
            Text { text: "demo mailbox, offline · trash: " + root.trash; color: Theme.textDim
                font.family: Theme.font; font.pixelSize: 16 }
        }
        PivotPage {
            title: "unread"
            EmptyNote { visible: root.unreadList.length === 0; text: "no unread mail." }
            Repeater {
                model: root.unreadList
                MailRow {
                    required property var modelData
                    who: modelData.from; subject: modelData.subject; body: modelData.body
                    when: root.timeStr(modelData.ts); unread: true; flagged: modelData.flag
                    onClicked: root.openMessage(modelData.id, false)
                }
            }
        }
        PivotPage {
            title: "flagged"
            EmptyNote { visible: root.flaggedList.length === 0; text: "nothing flagged." }
            Repeater {
                model: root.flaggedList
                MailRow {
                    required property var modelData
                    who: modelData.from; subject: modelData.subject; body: modelData.body
                    when: root.timeStr(modelData.ts); unread: !modelData.read; flagged: true
                    onClicked: root.openMessage(modelData.id, false)
                }
            }
        }
        PivotPage {
            title: "sent"
            EmptyNote { visible: root.sent.length === 0; text: "nothing sent yet." }
            Repeater {
                model: root.sent
                MailRow {
                    required property var modelData
                    who: "to " + modelData.to; subject: modelData.subject; body: modelData.body
                    when: root.timeStr(modelData.ts)
                    onClicked: root.openMessage(modelData.id, true)
                }
            }
            Item { width: 1; height: 10 }
            Text { text: "offline: stored locally"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }
    }

    AppBar {
        id: mainBar
        anchors.bottom: parent.bottom
        items: [{ glyph: "plus", label: "compose" }]
        menuItems: ["mark all read"]
        onActivated: (i) => root.startCompose("", "")
        onMenuActivated: (i) => {
            root.msgs = root.msgs.map(function(m) { var n = {}; for (var k in m) n[k] = m[k]; n.read = true; return n })
            root.save()
        }
    }

    // ---- message view (slides over) ----
    Item {
        id: view
        width: parent.width; height: parent.height
        x: root.openMsg !== null && !root.composing ? 0 : parent.width
        visible: x < parent.width
        Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Flickable {
            id: vflick
            x: 18; y: root.topInset + 8; width: parent.width - 36
            height: parent.height - y - vbar.height
            contentWidth: width; contentHeight: vcol.implicitHeight + 24
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: vcol
                width: vflick.width
                spacing: 8
                Text {
                    width: parent.width; wrapMode: Text.Wrap
                    text: root.openMsg ? root.openMsg.subject : ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: root.openMsg ? (root.openSent ? "to " + root.openMsg.to : root.openMsg.from) : ""
                    color: Theme.accent; font.family: Theme.font; font.pixelSize: 24
                }
                Text {
                    text: root.openMsg ? root.fullTime(root.openMsg.ts) : ""
                    color: Theme.textDim; font.family: Theme.font; font.pixelSize: 18
                }
                Item { width: 1; height: 8 }
                Text {
                    width: parent.width; wrapMode: Text.Wrap
                    text: root.openMsg ? root.openMsg.body : ""
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                }
            }
        }
        AppBar {
            id: vbar
            anchors.bottom: parent.bottom
            items: root.openSent
                ? [{ glyph: "back", label: "close" }, { glyph: "close", label: "delete" }]
                : [{ glyph: "back", label: "reply" }, { glyph: "star", label: root.openMsg && root.openMsg.flag ? "unflag" : "flag" },
                   { glyph: "close", label: "delete" }, { glyph: "mail", label: "mark unread" }]
            onActivated: (i) => {
                if (root.openSent) { if (i === 0) root.closeMessage(); else root.deleteOpen(); return }
                if (i === 0) { var m = root.openMsg; root.startCompose(m.from, "Re: " + m.subject.replace(/^Re: /, "")) }
                else if (i === 1) root.patch(root.openId, { flag: !root.openMsg.flag })
                else if (i === 2) root.deleteOpen()
                else { root.patch(root.openId, { read: false }); root.closeMessage() }
            }
        }
    }

    // ---- compose view ----
    Item {
        id: comp
        width: parent.width; height: parent.height
        x: root.composing ? 0 : parent.width
        visible: x < parent.width
        Behavior on x { enabled: !Theme.reduceMotion; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Rectangle { anchors.fill: parent; color: Theme.pageBg }
        MouseArea { anchors.fill: parent }
        Text {
            x: 18; y: root.topInset + 16; text: "new message"; color: Theme.text
            font.family: Theme.font; font.pixelSize: 44; font.weight: Theme.fontLight
        }
        Column {
            x: 18; y: root.topInset + 80; width: parent.width - 36
            spacing: 10
            MetroTextField { id: toField; width: parent.width; label: "to"; placeholder: "name@example.com"
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText }
            MetroTextField { id: subjField; width: parent.width; label: "subject" }
            Text { text: "message"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 21 }
            Rectangle {
                width: parent.width; height: 200
                color: bodyEdit.activeFocus ? Theme.text : "transparent"
                border.width: 2; border.color: bodyEdit.activeFocus ? Theme.accent : Theme.text
                Flickable {
                    id: bflick
                    anchors.fill: parent; anchors.margins: 10
                    contentWidth: width; contentHeight: bodyEdit.implicitHeight
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    TextEdit {
                        id: bodyEdit
                        width: bflick.width
                        wrapMode: TextEdit.Wrap
                        color: activeFocus ? Theme.pageBg : Theme.text
                        selectionColor: Theme.accent
                        font.family: Theme.font; font.pixelSize: 22; font.weight: Theme.fontLight
                    }
                }
            }
            Text { text: "offline: stored locally"; color: Theme.textDim; font.family: Theme.font; font.pixelSize: 16 }
        }
        AppBar {
            id: cbar
            anchors.bottom: parent.bottom
            items: [{ glyph: "forward", label: "send" }, { glyph: "close", label: "discard" }]
            onActivated: (i) => { if (i === 0) root.sendCompose(); else root.composing = false }
        }
    }

    focus: true
    function back() {
        if (root.composing) root.composing = false
        else if (root.openId >= 0) root.closeMessage()
        else closeRequested()
    }
    Keys.onEscapePressed: back()
    Keys.onBackPressed: back()
}
