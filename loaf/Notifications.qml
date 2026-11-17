// Loaf's notifications (replaces mako): cards in the top right of the focused screen, and under the clock a
// list of the ones you missed (click the date and time), with do not disturb. The clock gets a dot for unseen ones.
// Event-driven: nothing runs until an app sends a notification.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root
    property var screen: null           // where cards appear: the focused screen, set by shell.qml
    property bool dnd: false            // do not disturb: only urgent ones show, everything goes to history
    property int unseen: 0              // arrived since the list was last opened (the dot next to the clock)
    property bool listOpen: false       // the list under the clock
    property var listScreen: null       // the screen whose clock was clicked
    onListOpenChanged: if (listOpen) unseen = 0
    property var history: []            // newest first: plain copies, they outlive the notification itself
    property var live: []               // cards on screen now
    readonly property int keep: 50

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false      // plain text: no surprises from app markup
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.arrived(n)
    }

    function arrived(n) {
        n.tracked = true
        const urgent = n.urgency === NotificationUrgency.Critical
        if (!n.transient) {
            root.history = [{ key: n.id + ":" + Date.now(), n: n, app: n.appName, summary: n.summary, body: n.body,
                              icon: root.iconFor(n),
                              entry: n.desktopEntry, time: new Date(), urgent: urgent }]
                .concat(root.history).slice(0, root.keep)
            root.unseen++
        }
        if (root.dnd && !urgent) { n.expire(); return }
        root.live = [n].concat(root.live.filter(x => x !== n))
        n.closed.connect(() => root.live = root.live.filter(x => x !== n))
    }

    // The best picture for a notification, or "" (then no icon, never Quickshell's missing-image block):
    // pixels or a file the app sent, else its icon name in the theme, else the icon of its launcher entry
    // (snap apps such as Discord keep their icon inside the snap, not in the theme).
    function iconFor(n) {
        const raw = n.image || n.appIcon || ""
        if (raw.startsWith("/")) return "file://" + raw
        if (raw.startsWith("file://") || (raw.startsWith("image://") && !raw.startsWith("image://icon/"))) return raw
        const name = raw.startsWith("image://icon/") ? raw.slice(13) : raw
        const themed = name ? Quickshell.iconPath(name, true) : ""
        if (themed) return themed
        const e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null
        if (!e || !e.icon) return ""
        return e.icon.startsWith("/") ? "file://" + e.icon : Quickshell.iconPath(e.icon, true)
    }

    // Click: the app's own default action if it has one, else open or focus the app. Works from history too.
    function open(n, entry) {
        const act = n && n.actions ? n.actions.find(a => a.identifier === "default") || n.actions[0] : null
        if (act) act.invoke()
        else if (entry) Quickshell.execDetached(["gtk-launch", entry])
        if (n) n.dismiss()
    }
    function clear() { root.history = []; root.unseen = 0 }

    // ---- the list under the clock ----
    PanelWindow {
        screen: root.listScreen
        visible: root.listOpen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea { anchors.fill: parent; onClicked: root.listOpen = false } // click outside closes
        Item { focus: root.listOpen; Keys.onEscapePressed: root.listOpen = false }

        Rectangle {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 38 }
            width: 400; height: lc.height + 28; radius: 18
            color: Theme.sheet; border { width: 1; color: Theme.line }
            MouseArea { anchors.fill: parent } // clicks on the card do not close it

            Column {
                id: lc
                x: 14; y: 14; width: parent.width - 28; spacing: 6
                Text {
                    leftPadding: 4; text: "Notifications"; color: Theme.mute
                    font { family: Theme.sans; pixelSize: 12 }
                }
                Text {
                    visible: root.history.length === 0
                    leftPadding: 4; topPadding: 6; bottomPadding: 10
                    text: "Nothing missed"; color: Theme.faint; font { family: Theme.sans; pixelSize: 14 }
                }
                ListView { // newest first; scrolls once there are more than fit
                    id: list
                    width: parent.width
                    height: Math.min(contentHeight, (root.listScreen ? root.listScreen.height : 900) * 0.6)
                    clip: true; spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.history
                    delegate: Rectangle {
                        id: h
                        required property var modelData
                        width: list.width; height: hc.implicitHeight + 16; radius: 10
                        color: ha.containsMouse ? Theme.fill : "transparent"
                        Row {
                            id: hc
                            x: 10; y: 8; width: parent.width - 20; spacing: 10
                            Image {
                                visible: h.modelData.icon !== ""
                                width: 28; height: 28; sourceSize { width: 56; height: 56 }
                                fillMode: Image.PreserveAspectFit; source: h.modelData.icon
                            }
                            Column {
                                width: parent.width - (h.modelData.icon !== "" ? 38 : 0)
                                Text {
                                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                    text: (h.modelData.app ? h.modelData.app + " · " : "") + Qt.formatTime(h.modelData.time, "HH:mm")
                                    color: Theme.mute; font { family: Theme.sans; pixelSize: 11; features: { "tnum": 1 } }
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                    text: h.modelData.summary; color: Theme.ink
                                    font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
                                }
                                Text {
                                    visible: text !== ""; width: parent.width; textFormat: Text.PlainText
                                    wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                                    text: h.modelData.body; color: Theme.mute; font { family: Theme.sans; pixelSize: 12 }
                                }
                            }
                        }
                        MouseArea {
                            id: ha; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.listOpen = false; root.open(h.modelData.n, h.modelData.entry) }
                        }
                    }
                }
                Item { // do not disturb on the left, Clear on the right
                    width: parent.width; height: 36
                    Row {
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Rectangle { // switch
                            width: 34; height: 20; radius: 10
                            color: root.dnd ? Theme.ink : Theme.fill
                            border { width: 1; color: root.dnd ? Theme.ink : Theme.line }
                            Rectangle {
                                x: root.dnd ? parent.width - width - 3 : 3; anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7; color: root.dnd ? Theme.inverse : Theme.mute
                            }
                        }
                        Text { text: "Do not disturb"; color: Theme.ink; anchors.verticalCenter: parent.verticalCenter; font { family: Theme.sans; pixelSize: 13 } }
                    }
                    MouseArea { // the whole left half toggles
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width / 2
                        cursorShape: Qt.PointingHandCursor; onClicked: root.dnd = !root.dnd
                    }
                    Rectangle {
                        visible: root.history.length > 0
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 72; height: 30; radius: 10
                        color: cl.containsMouse ? Theme.line : Theme.fill
                        Text { anchors.centerIn: parent; text: "Clear"; color: Theme.ink; font { family: Theme.sans; pixelSize: 13 } }
                        MouseArea { id: cl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clear() }
                    }
                }
            }
        }
    }

    PanelWindow {
        screen: root.screen
        visible: root.live.length > 0
        anchors { top: true; right: true }
        margins { top: 40; right: 10 }
        implicitWidth: 360
        implicitHeight: cards.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay   // above fullscreen windows too
        WlrLayershell.namespace: "loaf-notifications"
        mask: Region { item: cards }            // clicks between and around cards go to the windows below

        Column {
            id: cards
            width: parent.width
            spacing: 8
            Repeater {
                model: root.live
                Card {
                    required property var modelData
                    n: modelData
                    width: cards.width
                    onActivated: root.open(modelData, modelData.desktopEntry)
                    onClose: modelData.dismiss()
                }
            }
        }
    }

    component Card: Rectangle {
        id: card
        property var n
        signal activated()
        signal close()
        readonly property bool urgent: n.urgency === NotificationUrgency.Critical
        readonly property string icon: root.iconFor(n)
        implicitHeight: content.implicitHeight + 28
        radius: 14
        color: Theme.sheet
        border { width: urgent ? 2 : 1; color: urgent ? Theme.ink : Theme.line }

        Timer { // urgent ones stay until clicked; the rest follow the app's wish, 6 s if it has none
            running: !card.urgent && card.n.expireTimeout !== 0 && !hover.containsMouse
            interval: card.n.expireTimeout > 0 ? Math.max(3000, card.n.expireTimeout) : 6000
            onTriggered: card.n.expire()
        }
        Row {
            id: content
            x: 16; y: 14; width: parent.width - 32; spacing: 12
            Image {
                visible: card.icon !== ""
                width: 40; height: 40; sourceSize { width: 80; height: 80 }
                fillMode: Image.PreserveAspectFit
                source: card.icon
            }
            Column {
                width: parent.width - (card.icon !== "" ? 52 : 0); spacing: 2
                Text {
                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                    text: card.n.summary || card.n.appName; color: Theme.ink
                    font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold }
                }
                Text {
                    visible: text !== ""; width: parent.width; textFormat: Text.PlainText
                    wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                    text: card.n.body; color: Theme.ink
                    font { family: Theme.sans; pixelSize: 13 }
                }
            }
        }
        MouseArea { // left: open, right: just close; hovering keeps it on screen
            id: hover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? card.close() : card.activated()
        }
    }
}
