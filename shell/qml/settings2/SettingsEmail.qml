import QtQuick
import FlowShell

// Settings > email+accounts. Pivot: "email" (sync options) and "accounts" (list plus a circled-plus add row).
// Accounts and options are local to this page (no mail backend yet). Adding an account needs a non-empty address.
Item {
    id: root
    property string title: "email+accounts"
    property bool adding: false
    property int syncIndex: 0
    readonly property var syncModel: ["as items arrive", "every 15 minutes", "hourly", "manually"]

    ListModel {
        id: accounts
        ListElement { addr: "you@example.com"; kind: "mail" }
    }

    Pivot {
        anchors.fill: parent
        caption: root.title

        PivotPage {
            title: "email"

            MetroSectionHeader { text: "sync" }
            MetroDropdown {
                width: parent.width
                label: "download new mail"
                model: root.syncModel
                currentIndex: root.syncIndex
                onActivated: (i) => root.syncIndex = i
            }
            Item { width: 1; height: 24 }
            MetroTextField {
                width: parent.width
                label: "signature"
                placeholder: "sent from tilesde"
            }
        }

        PivotPage {
            title: "accounts"

            MetroSectionHeader { text: "accounts" }
            Repeater {
                model: accounts
                delegate: MetroListRow {
                    width: parent.width
                    glyph: "mail"
                    title: model.addr
                    subtitle: "mail"
                }
            }

            // circled-plus row: outlined circle with a plus, toggles the add form
            Item {
                width: parent.width
                height: 80
                opacity: plusArea.pressed ? 0.6 : 1
                Rectangle {
                    id: circle
                    x: 6; y: 12; width: 56; height: 56; radius: 28
                    color: "transparent"; border.width: 2; border.color: Theme.text
                    Rectangle { x: 26; y: 14; width: 4; height: 28; color: Theme.text }
                    Rectangle { x: 14; y: 26; width: 28; height: 4; color: Theme.text }
                }
                Text {
                    x: circle.x + circle.width + 18; y: 26
                    text: "add account"
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 24; font.weight: Theme.fontLight
                }
                MouseArea { id: plusArea; anchors.fill: parent; onClicked: root.adding = !root.adding }
            }

            MetroTextField {
                visible: root.adding
                width: parent.width
                label: "email address"
                placeholder: "name@example.com"
                onAccepted: {
                    const a = text.trim()
                    if (a.indexOf("@") > 0) { accounts.append({ addr: a, kind: "mail" }); text = ""; root.adding = false }
                }
            }
        }
    }
}
