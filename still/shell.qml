// Still: ground + bar on every screen. Screens come and go with the dock; Variants follows them.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    QuickSettings { id: quick } // one card, opened on the screen whose bar was clicked
    Launcher { id: launcher }
    Lock { id: stillLock }
    Osd { id: osd }
    Timer { id: safety; interval: 45000; onTriggered: stillLock.done() } // only armed by "lock test"

    // the screen niri has focused, for windows opened by key instead of by click
    function focusedScreen() {
        const out = (Niri.workspaces.find(w => w.is_focused) || {}).output
        return Quickshell.screens.find(s => s.name === out) || Quickshell.screens[0]
    }

    IpcHandler { // qs ipc -p ~/.config/quickshell/still call quick toggle
        target: "quick"
        function toggle(): void { quick.open = !quick.open }
        function list(which: string): void { quick.open = true; quick.detail = which } // "bt", "wifi" or ""; not named "show": qs ipc reads that as its own subcommand
    }
    IpcHandler { // hypridle: qs ipc -p ~/.config/quickshell/still call lock lock
        target: "lock"
        function lock(): void { stillLock.lock() }
        function test(): void { stillLock.lock(); safety.restart() } // unlocks itself after 45 s, for trying it out
    }
    IpcHandler { // volume and brightness keys: qs ipc -p ~/.config/quickshell/still call osd volume | brightness 40
        target: "osd"
        function volume(): void { osd.screen = focusedScreen(); osd.flash("volume") }
        function brightness(pct: int): void { osd.bright = pct; osd.screen = focusedScreen(); osd.flash("brightness") }
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
