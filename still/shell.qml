// Still: ground + bar on every screen. Screens come and go with the dock; Variants follows them.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    QuickSettings { // ponytail: niri-mist's card (symlink) until Still's quick settings (step 3)
        id: quick
        palette: ({ ink: Theme.ink, slate: Theme.mute, mute: Theme.faint, bg: Theme.sheet })
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
            Bar { modelData: s.modelData; onQuickClicked: quick.open = !quick.open }
        }
    }
}
