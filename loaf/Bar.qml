// Loaf bar, one per screen: search, workspace dots | date and time (opens the notifications) | network,
// watts and time left, battery (opens quick settings); left of that the tray, for apps that keep running
// without a window (Steam, Teams): click opens the app, right click its own menu (Quit), middle click its second action.
// Idle rules: clock ticks per minute (SystemClock), everything else follows events.
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: bar
    required property var modelData
    property var notifs: null
    signal quickClicked()
    signal searchClicked()
    signal clockClicked()
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    color: "transparent" // the ground layer sits underneath

    readonly property var dots: Niri.on(screen.name)
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wifiNet: wifiDev ? wifiDev.networks.values.find(n => n.connected) || null : null
    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
    // the dock's cable wins over Wi-Fi, like NetworkManager's own route
    readonly property string net: wired ? "cable" : wifiDev && wifiDev.connected ? "wifi" : "none"
    readonly property var battery: UPower.displayDevice
    readonly property bool discharging: battery.isPresent && battery.state === UPowerDeviceState.Discharging
    readonly property bool charging: battery.isPresent && battery.state === UPowerDeviceState.Charging
    // UPower's estimate: time to empty on battery, to full while charging ("" until it has one)
    readonly property string timeLeft: hm(discharging ? battery.timeToEmpty : charging ? battery.timeToFull : 0)
    function hm(sec) {
        if (!(sec > 0)) return ""
        const m = Math.round(sec / 60)
        return m < 60 ? m + "m" : Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m"
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    component Btn: Rectangle {
        id: b
        signal clicked()
        default property alias content: row.children
        width: row.width + 20; height: 26; radius: 13
        color: area.containsMouse ? Theme.fill : "transparent"
        Row { id: row; anchors.centerIn: parent; spacing: 10 }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
    component Label: Text {
        font { family: Theme.sans; pixelSize: 13; features: { "tnum": 1 } }
        color: Theme.ink
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 10
        Btn {
            onClicked: bar.searchClicked()
            Image { // the Loaf cat opens the launcher (small cut: no eyes at this size)
                width: 18; height: 18
                sourceSize { width: 36; height: 36 }
                source: Theme.logo("mark-small")
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: bar.dots
                Item {
                    width: 22; height: 22
                    Rectangle {
                        anchors.centerIn: parent
                        width: modelData.is_active ? 18 : 6; height: 6; radius: 3
                        color: modelData.is_active ? Theme.ink : Theme.faint
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focus(modelData) }
                }
            }
        }
    }

    Btn { // date, quiet, next to the time (the minute tick also rolls the date over at midnight);
          // a dot when notifications came in since the list was last opened. Click: the list.
        anchors.centerIn: parent
        onClicked: bar.clockClicked()
        Label { text: Qt.formatDate(clock.date, "ddd d MMM"); color: Theme.mute }
        Label { text: Qt.formatTime(clock.date, "HH:mm"); font.weight: Font.Medium }
        Rectangle {
            visible: !!bar.notifs && bar.notifs.unseen > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5; color: Theme.ink
        }
    }

    Row {
        anchors { right: quickBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
        Repeater {
            model: SystemTray.items
            Rectangle {
                id: tray
                required property var modelData
                width: 26; height: 26; radius: 13
                color: trayArea.containsMouse ? Theme.fill : "transparent"
                IconImage { anchors.centerIn: parent; implicitSize: 16; source: tray.modelData.icon }
                MouseArea {
                    id: trayArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: e => {
                        const it = tray.modelData
                        if (e.button === Qt.MiddleButton) it.secondaryActivate()
                        else if ((e.button === Qt.RightButton || it.onlyMenu) && it.hasMenu) {
                            trayMenu.x0 = tray.mapToItem(null, tray.width, 0).x
                            opener.menu = it.menu
                            trayMenu.visible = true
                        } else it.activate()
                    }
                }
            }
        }
    }

    Btn {
        id: quickBtn
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        onClicked: bar.quickClicked()
        NetIcon {
            anchors.verticalCenter: parent.verticalCenter
            kind: bar.net
            strength: bar.wifiNet ? bar.wifiNet.signalStrength : 0
        }
        Label { // power in or out, then the time left (to full while charging)
            visible: (bar.discharging || bar.charging) && bar.battery.changeRate > 0
            text: (bar.charging ? "+" : "") + bar.battery.changeRate.toFixed(1) + " W" + (bar.timeLeft ? " · " + bar.timeLeft : "")
            color: Theme.mute
        }
        Row {
            visible: bar.battery.isPresent
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                level: bar.battery.percentage
                charging: bar.charging
            }
            Label { text: Math.round(bar.battery.percentage * 100) + "%" }
        }
    }

    // A tray app's menu, drawn by Loaf (Qt's platform menus would need QtWidgets). Opens under the icon,
    // right edge on the icon's right edge; a click outside closes it. A submenu replaces the list in place.
    PopupWindow {
        id: trayMenu
        property real x0: 0
        visible: false
        grabFocus: true
        color: "transparent"
        anchor.window: bar
        anchor.rect.x: x0 - implicitWidth
        anchor.rect.y: bar.height
        implicitWidth: 240
        implicitHeight: menuCol.height + 12
        QsMenuOpener { id: opener }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius; color: Theme.sheet; border.color: Theme.line
            Column {
                id: menuCol
                x: 6; y: 6; width: parent.width - 12
                Repeater {
                    model: opener.children
                    Rectangle {
                        id: entry
                        required property var modelData
                        width: menuCol.width
                        height: modelData.isSeparator ? 9 : 30
                        radius: 8
                        color: entryArea.containsMouse && modelData.enabled && !modelData.isSeparator ? Theme.fill : "transparent"
                        Rectangle { visible: entry.modelData.isSeparator; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.line }
                        Label {
                            visible: !entry.modelData.isSeparator
                            x: 10; width: parent.width - 20; elide: Text.ElideRight
                            text: (entry.modelData.checkState === Qt.Checked ? "\u2713 " : "")
                                  + entry.modelData.text.replace(/_(?!_)/g, "") + (entry.modelData.hasChildren ? "  \u203a" : "")
                            color: entry.modelData.enabled ? Theme.ink : Theme.faint
                        }
                        MouseArea {
                            id: entryArea
                            anchors.fill: parent; hoverEnabled: true
                            enabled: entry.modelData.enabled && !entry.modelData.isSeparator
                            onClicked: {
                                if (entry.modelData.hasChildren) { opener.menu = entry.modelData; return }
                                entry.modelData.triggered()
                                trayMenu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
