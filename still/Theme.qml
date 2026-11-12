// Still design tokens, taken from Personal/Still/demo/still-demo.html (:root and dark set).
// Dark follows org.gnome.desktop.interface color-scheme, so GTK/libadwaita apps switch with it.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: t
    property bool dark: false

    readonly property color ground: dark ? "#121212" : "#E9E9E5"
    readonly property color sheet:  dark ? "#1C1C1B" : "#FFFFFF"
    readonly property color soft:   dark ? "#222221" : "#F2F2EF"
    readonly property color line:   dark ? "#2E2E2C" : "#DEDED9"
    readonly property color ink:    dark ? "#ECECEA" : "#151515"
    readonly property color mute:   dark ? "#A3A39E" : "#6B6B66"
    readonly property color faint:  dark ? "#5A5A57" : "#9C9C96"
    readonly property color fill:   dark ? "#2A2A28" : "#ECECE8"
    readonly property color onInk:  dark ? "#121212" : "#FFFFFF"

    // ponytail: Instrument Sans is not installed; Inter until the font is added
    readonly property string sans: "Inter"
    readonly property string mono: "JetBrains Mono"
    readonly property int radius: 14

    function setDark(on) {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", on ? "prefer-dark" : "default"])
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector { onStreamFinished: t.dark = text.includes("dark") }
    }
    Process { // event-driven: prints one line per change
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        stdout: SplitParser { onRead: l => t.dark = l.includes("dark") }
    }
}
