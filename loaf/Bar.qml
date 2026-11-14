// Loaf bar, one per screen: search, workspace dots | clock | wifi, watts, battery.
// Idle rules: clock ticks per minute (SystemClock), everything else follows events.
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import QtQuick

PanelWindow {
    id: bar
    required property var modelData
    signal quickClicked()
    signal searchClicked()
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    color: "transparent" // the ground layer sits underneath

    readonly property var dots: Niri.on(screen.name)
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var battery: UPower.displayDevice
    readonly property bool discharging: battery.isPresent && battery.state === UPowerDeviceState.Discharging

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

    Row { // date, quiet, next to the time; the minute tick also rolls the date over at midnight
        anchors.centerIn: parent
        spacing: 8
        Label { text: Qt.formatDate(clock.date, "ddd d MMM"); color: Theme.mute }
        Label { text: Qt.formatTime(clock.date, "HH:mm"); font.weight: Font.Medium }
    }

    Btn {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        onClicked: bar.quickClicked()
        Label { text: bar.wifiDev && bar.wifiDev.connected ? "wifi" : "offline"; opacity: bar.wifiDev && bar.wifiDev.connected ? 1 : 0.55 }
        Label { visible: bar.discharging && bar.battery.changeRate > 0; text: bar.battery.changeRate.toFixed(1) + " W"; color: Theme.mute }
        Label { visible: bar.battery.isPresent; text: Math.round(bar.battery.percentage * 100) + "%" }
    }
}
