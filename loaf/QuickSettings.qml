// Loaf quick settings: battery and watts, power menu, six tiles, volume and brightness.
// Layout from Personal/Loaf/demo/still-demo.html (.quick). Everything reads services that push
// changes (UPower, NetworkManager, BlueZ, PipeWire, power-profiles-daemon); nothing polls.
// Brightness and do-not-disturb have no event source, so they are read when the card opens.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

PanelWindow {
    id: win
    property bool open: false
    property bool powerMenu: false
    property string detail: "" // "", "bt" or "wifi": the list under the tiles (right-click a tile, or its arrow)
    visible: open
    onOpenChanged: { scan(); if (open) { powerMenu = false; detail = ""; brightRead.running = true; dndRead.running = true } }
    onDetailChanged: scan()
    // Wi-Fi scanning costs power: only while the network list is on screen
    function scan() { if (wifiDev) wifiDev.scannerEnabled = open && detail === "wifi" }
    function settings(panel) { open = false; run(["env", "XDG_CURRENT_DESKTOP=GNOME", "gnome-control-center", panel]) }
    readonly property var btList: bt ? bt.devices.values.filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name)) : []
    readonly property var wifiList: wifiDev ? wifiDev.networks.values.slice()
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)).slice(0, 6) : []

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ---- state from services ----
    readonly property var bat: UPower.displayDevice
    readonly property bool charging: bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged || bat.state === UPowerDeviceState.PendingCharge
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wifiNet: wifiDev ? (wifiDev.networks.values.find(n => n.connected) || null) : null
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDevice: bt ? (bt.devices.values.find(d => d.connected) || null) : null
    readonly property var sink: Pipewire.defaultAudioSink
    property int bright: 50
    property bool dnd: false

    PwObjectTracker { objects: [win.sink] }

    function hm(seconds) {
        const m = Math.round(seconds / 60)
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`
    }
    readonly property string bigText: {
        const pct = Math.round(bat.percentage * 100) + "%"
        if (!bat.isPresent) return "On power"
        if (bat.state === UPowerDeviceState.FullyCharged) return pct + " · full"
        if (charging) return pct + (bat.timeToFull > 0 ? " · full in " + hm(bat.timeToFull) : " · charging")
        return pct + (bat.timeToEmpty > 0 ? " · " + hm(bat.timeToEmpty) + " left" : "")
    }
    readonly property string smallText: charging ? "Plugged in" : (bat.changeRate > 0 ? `Drawing ${bat.changeRate.toFixed(1)} W right now` : "On battery")

    Process { id: brightRead; command: ["brightnessctl", "-m", "--class=backlight"]
        stdout: StdioCollector { onStreamFinished: { const p = text.split(","); if (p.length > 3) win.bright = parseInt(p[3]) } } }
    Process { id: dndRead; command: ["makoctl", "mode"]
        stdout: StdioCollector { onStreamFinished: win.dnd = text.includes("do-not-disturb") } }
    Process { id: mirror; command: ["mist-mirror"] } // runs as long as the mirror is up

    function run(cmd) { Quickshell.execDetached(cmd) }

    // ---- look ----
    MouseArea { anchors.fill: parent; onClicked: win.open = false } // click outside closes
    Item { focus: win.open; Keys.onEscapePressed: win.open = false }

    component Tile: Rectangle {
        id: t
        property string title; property string sub; property bool on
        property bool hasMore: false
        signal toggled()
        signal more()
        height: 56; radius: 14
        color: on ? Theme.ink : (area.containsMouse ? Theme.line : Theme.fill)
        Column {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: t.width - 28 - (t.hasMore ? 20 : 0)
            Text { width: parent.width; elide: Text.ElideRight; text: t.title; color: t.on ? Theme.inverse : Theme.ink; font { family: Theme.sans; pixelSize: 14; weight: Font.DemiBold } }
            Text { width: parent.width; elide: Text.ElideRight; text: t.sub; color: t.on ? Theme.inverse : Theme.mute; opacity: t.on ? 0.75 : 1; font { family: Theme.sans; pixelSize: 12 } }
        }
        Text { // arrow: this tile has a list
            visible: t.hasMore; text: "›"
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            color: t.on ? Theme.inverse : Theme.mute; font { family: Theme.sans; pixelSize: 20 }
        }
        MouseArea {
            id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => (m.button === Qt.RightButton || (t.hasMore && m.x > width - 40)) ? t.more() : t.toggled()
        }
    }
    component Line: Rectangle {
        id: l
        property string label; property string hint; property bool strong
        signal clicked()
        width: parent.width; height: 38; radius: 10
        color: la.containsMouse ? Theme.fill : "transparent"
        Text {
            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32 - lh.width; elide: Text.ElideRight
            text: l.label; color: Theme.ink; font { family: Theme.sans; pixelSize: 14; weight: l.strong ? Font.DemiBold : Font.Normal }
        }
        Text {
            id: lh; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: l.hint; color: Theme.mute; font { family: Theme.sans; pixelSize: 12 }
        }
        MouseArea { id: la; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: l.clicked() }
    }
    component Slider: Column {
        id: s
        property string label; property real value; property real minimum: 0
        signal moved(real v)
        spacing: 6; width: parent.width
        Text { text: s.label; color: Theme.mute; font { family: Theme.sans; pixelSize: 13 } }
        Item {
            width: parent.width; height: 20
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.fill }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * s.value; height: 4; radius: 2; color: Theme.ink }
            Rectangle { x: parent.width * s.value - 8; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8; color: Theme.ink }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                function set(x) { s.moved(Math.max(s.minimum, Math.min(1, x / width))) }
                onPressed: m => set(m.x); onPositionChanged: m => set(m.x)
            }
        }
    }
    component Btn: Rectangle {
        id: b
        property string label
        signal clicked()
        height: 44; radius: 12
        color: ba.containsMouse ? Theme.line : Theme.fill
        Text { anchors.centerIn: parent; text: b.label; color: Theme.ink; font { family: Theme.sans; pixelSize: 13 } }
        MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    Rectangle {
        id: card
        anchors { top: parent.top; right: parent.right; topMargin: 38; rightMargin: 10 }
        width: 380; height: col.height + 32; radius: 18
        color: Theme.sheet; border { width: 1; color: Theme.line }
        MouseArea { anchors.fill: parent } // clicks on the card do not close it

        Column {
            id: col
            x: 16; y: 16; width: parent.width - 32; spacing: 14

            Item {
                width: parent.width; height: 44
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.bigText; color: Theme.ink; font { family: Theme.sans; pixelSize: 22; weight: Font.Medium; letterSpacing: -0.4; features: { "tnum": 1 } } }
                    Text { text: win.smallText; color: Theme.mute; font { family: Theme.sans; pixelSize: 13; features: { "tnum": 1 } } }
                }
                Rectangle { // power button
                    anchors.right: parent.right; width: 44; height: 44; radius: 22
                    color: pa.containsMouse || win.powerMenu ? Theme.line : Theme.fill
                    Rectangle { anchors.centerIn: parent; anchors.verticalCenterOffset: 2; width: 16; height: 16; radius: 8; color: "transparent"; border { width: 2; color: Theme.ink } }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 6; height: 12; color: parent.color }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 2; height: 10; radius: 1; color: Theme.ink }
                    MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.powerMenu = !win.powerMenu }
                }
            }

            Grid {
                visible: win.powerMenu; columns: 3; spacing: 8; width: parent.width
                readonly property real w: (width - 16) / 3
                Btn { width: parent.w; label: "Lock"; onClicked: { win.open = false; win.run(["loginctl", "lock-session"]) } }
                Btn { width: parent.w; label: "Suspend"; onClicked: { win.open = false; win.run(["systemctl", "suspend"]) } }
                Btn { width: parent.w; label: "Log out"; onClicked: win.run(["niri", "msg", "action", "quit", "--skip-confirmation"]) }
            }
            Row {
                visible: win.powerMenu; spacing: 8; width: parent.width
                readonly property real w: (width - 8) / 2
                Btn { width: parent.w; label: "Restart"; onClicked: win.run(["systemctl", "reboot"]) }
                Btn { width: parent.w; label: "Power off"; onClicked: win.run(["systemctl", "poweroff"]) }
            }

            Grid {
                columns: 2; spacing: 8; width: parent.width
                readonly property real w: (width - 8) / 2
                Tile {
                    width: parent.w; title: "Wi-Fi"; on: Networking.wifiEnabled
                    sub: !Networking.wifiEnabled ? "Off" : (win.wifiNet ? win.wifiNet.name : "Not connected")
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    hasMore: true; onMore: win.detail = win.detail === "wifi" ? "" : "wifi"
                }
                Tile {
                    width: parent.w; title: "Bluetooth"; on: !!win.bt && win.bt.enabled
                    sub: !on ? "Off" : (win.btDevice ? win.btDevice.name : "On")
                    onToggled: if (win.bt) win.bt.enabled = !win.bt.enabled
                    hasMore: true; onMore: win.detail = win.detail === "bt" ? "" : "bt"
                }
                Tile {
                    width: parent.w; title: "Power saver"; on: PowerProfiles.profile === PowerProfile.PowerSaver
                    sub: on ? "On" : "Off"
                    onToggled: PowerProfiles.profile = on ? PowerProfile.Balanced : PowerProfile.PowerSaver
                }
                Tile {
                    width: parent.w; title: "Dark style"; on: Theme.dark
                    sub: on ? "On" : "Off"
                    onToggled: Theme.setDark(!Theme.dark)
                }
                Tile {
                    width: parent.w; title: "Do not disturb"; on: win.dnd
                    sub: on ? "On" : "Off"
                    onToggled: { win.dnd = !win.dnd; win.run(["makoctl", "mode", "-t", "do-not-disturb"]) }
                }
                Tile {
                    width: parent.w; title: "Screen"; on: mirror.running
                    sub: on ? "Mirroring" : "Extend"
                    onToggled: mirror.running = !mirror.running
                }
            }

            Column { // device or network list for the tile that was right-clicked
                visible: win.detail !== ""; width: parent.width; spacing: 2
                Text {
                    leftPadding: 12; bottomPadding: 4
                    text: win.detail === "bt" ? "Bluetooth devices" : "Wi-Fi networks"
                    color: Theme.mute; font { family: Theme.sans; pixelSize: 12 }
                }
                Repeater {
                    model: win.detail === "bt" ? win.btList : []
                    Line {
                        required property var modelData
                        label: modelData.name; strong: modelData.connected
                        hint: (modelData.state === BluetoothDeviceState.Connecting ? "Connecting" : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting" : modelData.connected ? "Connected" : "")
                            + (modelData.connected && modelData.batteryAvailable ? " · " + Math.round(modelData.battery <= 1 ? modelData.battery * 100 : modelData.battery) + "%" : "")
                        onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                    }
                }
                Repeater {
                    model: win.detail === "wifi" ? win.wifiList : []
                    Line {
                        required property var modelData
                        label: modelData.name; strong: modelData.connected
                        hint: modelData.stateChanging ? "Connecting" : modelData.connected ? "Connected" : modelData.known ? "Saved" : ""
                        // a new network needs its password typed: that stays in Settings
                        onClicked: modelData.connected ? modelData.disconnect() : modelData.known ? modelData.connect() : win.settings("wifi")
                    }
                }
                Line {
                    label: win.detail === "bt" ? "Pair a new device…" : "Wi-Fi settings…"
                    onClicked: win.settings(win.detail === "bt" ? "bluetooth" : "wifi")
                }
            }

            Slider {
                label: "Volume"; value: win.sink && win.sink.audio ? Math.min(1, win.sink.audio.volume) : 0
                onMoved: v => { if (win.sink && win.sink.audio) { win.sink.audio.muted = false; win.sink.audio.volume = v } }
            }
            Slider {
                label: "Brightness"; minimum: 0.05; value: win.bright / 100
                onMoved: v => { win.bright = Math.round(v * 100); win.run(["loaf-brightness", String(win.bright), "--no-osd"]) }
            }
        }
    }
}
