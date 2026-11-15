// Loaf: ground + bar on every screen. Screens come and go with the dock; Variants follows them.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    QuickSettings { id: quick } // one card, opened on the screen whose bar was clicked
    Launcher { id: launcher }
    Lock { id: loafLock }
    Osd { id: osd }
    Timer { id: safety; interval: 45000; onTriggered: loafLock.done() } // only armed by "lock test"

    // the screen niri has focused, for windows opened by key instead of by click
    function focusedScreen() {
        const out = (Niri.workspaces.find(w => w.is_focused) || {}).output
        return Quickshell.screens.find(s => s.name === out) || Quickshell.screens[0]
    }

    IpcHandler { // qs ipc -p ~/.config/quickshell/loaf call quick toggle
        target: "quick"
        function toggle(): void { quick.open = !quick.open }
        function list(which: string): void { quick.open = true; quick.detail = which } // "bt", "wifi" or ""; not named "show": qs ipc reads that as its own subcommand
    }
    IpcHandler { // hypridle: qs ipc -p ~/.config/quickshell/loaf call lock lock
        target: "lock"
        function lock(): void { loafLock.lock() }
        function test(): void { loafLock.lock(); safety.restart() } // unlocks itself after 45 s, for trying it out
        function sleep(): void { loafLock.sleep() } // hypridle before_sleep_cmd: stop the finger sensor
        function wake(): void { loafLock.wake() }   // hypridle after_sleep_cmd: start it again
    }
    IpcHandler { // volume and brightness keys: qs ipc -p ~/.config/quickshell/loaf call osd volume | brightness 40
        target: "osd"
        function volume(): void { osd.screen = focusedScreen(); osd.flash("volume") }
        function brightness(pct: int): void { osd.bright = pct; osd.screen = focusedScreen(); osd.flash("brightness") }
    }
    IpcHandler { // Super+D: qs ipc -p ~/.config/quickshell/loaf call launcher toggle
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
                Image { // one faint cat asleep in the corner, only seen on an empty workspace
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 22; bottomMargin: 18 }
                    width: 44; height: 44
                    sourceSize { width: 88; height: 88 }
                    source: Theme.logo("ground-cat")
                }
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
