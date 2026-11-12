// Still: ground + bar on every screen. Screens come and go with the dock; Variants follows them.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    QuickSettings { id: quick } // one card, opened on the screen whose bar was clicked

    IpcHandler { // qs ipc -p ~/.config/quickshell/still call quick toggle
        target: "quick"
        function toggle(): void { quick.open = !quick.open }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            PanelWindow { // solid ground, replaces swaybg and follows dark style
                screen: s.modelData
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                anchors { top: true; bottom: true; left: true; right: true }
                color: Theme.ground
            }
            Bar {
                modelData: s.modelData
                onQuickClicked: {
                    const same = quick.screen === s.modelData
                    quick.screen = s.modelData
                    quick.open = !(quick.open && same)
                }
            }
        }
    }
}
