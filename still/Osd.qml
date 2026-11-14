// Still OSD: a small card at the bottom of the screen when volume or brightness changes by key.
// The key binds call it over IPC (wpctl, still-brightness); it hides after 1.5 s. Nothing runs at rest.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: osd
    property string kind: "volume" // "volume" or "brightness"
    property int bright: 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: kind === "volume" && !!sink && !!sink.audio && sink.audio.muted
    readonly property real value: kind === "brightness" ? bright / 100
        : (sink && sink.audio ? Math.min(1, sink.audio.volume) : 0)

    function flash(k) { kind = k; visible = true; hide.restart() }

    visible: false
    anchors.bottom: true
    margins.bottom: 72
    implicitWidth: 300; implicitHeight: 56
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "still-osd"
    mask: Region {} // clicks go through to the window below

    PwObjectTracker { objects: [osd.sink] }
    Timer { id: hide; interval: 1500; onTriggered: osd.visible = false }

    Rectangle {
        anchors.fill: parent; radius: 18
        color: Theme.sheet; border { width: 1; color: Theme.line }
        Text {
            id: label; x: 18; width: 82; anchors.verticalCenter: parent.verticalCenter
            text: osd.kind === "brightness" ? "Brightness" : osd.muted ? "Muted" : "Volume"
            color: Theme.mute; font { family: Theme.sans; pixelSize: 13 }
        }
        Item {
            anchors { left: label.right; right: pct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            height: 4
            Rectangle { anchors.fill: parent; radius: 2; color: Theme.fill }
            Rectangle { width: parent.width * (osd.muted ? 0 : osd.value); height: 4; radius: 2; color: Theme.ink }
        }
        Text {
            id: pct; width: 40; horizontalAlignment: Text.AlignRight
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            text: Math.round(osd.value * 100) + "%"
            color: osd.muted ? Theme.faint : Theme.ink; font { family: Theme.mono; pixelSize: 13 }
        }
    }
}
