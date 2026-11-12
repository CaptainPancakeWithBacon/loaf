// Still design tokens (light set: warm cream, chosen 2026-11-12), based on Personal/Still/demo/still-demo.html (:root and dark set).
// Dark follows org.gnome.desktop.interface color-scheme, so GTK/libadwaita apps switch with it.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: t
    property bool dark: false
    // mako has no colour-scheme support: its config has a "dark" mode that we switch along
    onDarkChanged: Quickshell.execDetached(["makoctl", "mode", dark ? "-a" : "-r", "dark"])

    readonly property color ground: dark ? "#121212" : "#F1EDE4"
    readonly property color sheet:  dark ? "#1C1C1B" : "#FBF8F1"
    readonly property color soft:   dark ? "#222221" : "#F4F0E8"
    readonly property color line:   dark ? "#2E2E2C" : "#DED8CC"
    readonly property color ink:    dark ? "#ECECEA" : "#151515"
    readonly property color mute:   dark ? "#A3A39E" : "#6E6A62"
    readonly property color faint:  dark ? "#5A5A57" : "#A09A8F"
    readonly property color fill:   dark ? "#2A2A28" : "#E9E4D9"
    // text on an ink surface (not "onInk": QML reads on+Capital as a signal handler)
    readonly property color inverse: dark ? "#121212" : "#FBF8F1"

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
