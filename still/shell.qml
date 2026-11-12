// Still: ground + bar on every screen. Screens come and go with the dock; Variants follows them.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    QuickSettings { id: quick } // one card, opened on the screen whose bar was clicked
    Launcher { id: launcher }

    // the screen niri has focused, for windows opened by key instead of by click
    function focusedScreen() {
        const out = (Niri.workspaces.find(w => w.is_focused) || {}).output
        return Quickshell.screens.find(s => s.name === out) || Quickshell.screens[0]
    }

    IpcHandler { // qs ipc -p ~/.config/quickshell/still call quick toggle
        target: "quick"
        function toggle(): void { quick.open = !quick.open }
    }
    IpcHandler { // Super+D: qs ipc -p ~/.config/quickshell/still call launcher toggle
        target: "launcher"
        function toggle(): void { if (!launcher.open) launcher.screen = focusedScreen(); launcher.open = !launcher.open }
        function search(q: string): void { launcher.screen = focusedScreen(); launcher.open = true; launcher.search(q) }
        function launchFirst(q: string): void { launcher.open = true; launcher.launchFirst(q) }
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
                onSearchClicked: { launcher.screen = s.modelData; launcher.open = !launcher.open }
                onQuickClicked: {
                    const same = quick.screen === s.modelData
                    quick.screen = s.modelData
                    quick.open = !(quick.open && same)
                }
            }
        }
    }
}
