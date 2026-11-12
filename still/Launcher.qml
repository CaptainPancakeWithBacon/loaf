// Still launcher: one search over apps, settings and files (layout from the demo's .launcher).
// Apps come from Quickshell's desktop entries, files from GNOME's indexer (localsearch, only while
// typing), settings open GNOME Settings panels. Up/Down choose, Enter opens, Esc closes.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    property bool open: false
    property string query: ""
    property var files: []
    property int sel: 0
    visible: open
    onOpenChanged: if (open) { input.text = ""; sel = 0; files = []; input.forceActiveFocus() }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Quickshell's entries ignore OnlyShowIn, so tools made for other desktops (LXQt, KDE, MATE screensavers)
    // would show up. ponytail: matched by id; read OnlyShowIn from the files if more of these appear.
    readonly property var otherDesktop: /^(lxqt-|screensavers-|systemsettings$|im-config$|org\.gnome\.Extensions$|com\.mattjakeman\.ExtensionManager$)/

    // GNOME Settings panels worth reaching by name (Displays left out: it only works in GNOME).
    readonly property var settings: [
        ["Wi-Fi", "wifi"], ["Network", "network"], ["Bluetooth", "bluetooth"], ["Sound", "sound"],
        ["Power", "power"], ["Appearance", "background"], ["Notifications", "notifications"],
        ["Apps", "applications"], ["Mouse & Touchpad", "mouse"], ["Keyboard", "keyboard"],
        ["Printers", "printers"], ["Accessibility", "universal-access"], ["Privacy & Security", "privacy"],
        ["Online Accounts", "online-accounts"], ["Users", "system"]
    ]

    // Best match first: name starts with the query, then a word in the name does, then it appears anywhere
    // in name, generic name or keywords. Ties keep alphabetical order.
    function score(q, name, extra) {
        const n = name.toLowerCase()
        if (n.startsWith(q)) return 3
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 2
        if (n.includes(q) || extra.toLowerCase().includes(q)) return 1
        return 0
    }
    readonly property var items: {
        const q = query.trim().toLowerCase()
        if (!q) return [] // empty search = just the field, nothing to scan
        const apps = DesktopEntries.applications.values
            .filter(a => !a.noDisplay && !win.otherDesktop.test(a.id))
            .map(a => ({ kind: "app", label: a.name, icon: a.icon, entry: a,
                         s: score(q, a.name, (a.genericName || "") + " " + (a.keywords || []).join(" ")) }))
            .filter(a => a.s > 0)
            .sort((a, b) => b.s - a.s || a.label.localeCompare(b.label))
            .slice(0, 6)
        const sets = settings.map(([name, panel]) => ({ kind: "setting", label: name, hint: "Setting", panel, s: score(q, name, panel) }))
            .filter(x => x.s > 0).sort((a, b) => b.s - a.s).slice(0, 3)
        const fs = files.map(u => ({ kind: "file", label: decodeURIComponent(u.split("/").pop()),
                                     hint: decodeURIComponent(u.replace("file://" + Quickshell.env("HOME"), "~").split("/").slice(0, -1).join("/")), uri: u }))
        return apps.concat(sets, fs)
    }
    onItemsChanged: sel = Math.min(sel, Math.max(0, items.length - 1))

    function search(q) { input.text = q } // for qs ipc tests
    function launchFirst(q) { input.text = q; launch(items[0], false) }

    // An app that is already open gets its window focused (also when it sits out of view);
    // Shift+Enter starts a new one anyway.
    function launch(it, fresh) {
        if (!it) return
        open = false
        const w = it.kind === "app" && !fresh ? Niri.windowFor(it.entry) : null
        if (w) Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(w.id)])
        else if (it.kind === "app" && it.entry.runInTerminal) // Quickshell's execute() ignores Terminal=true
            Quickshell.execDetached(["ghostty", "-e"].concat(it.entry.command))
        else if (it.kind === "app") it.entry.execute()
        else if (it.kind === "setting") Quickshell.execDetached(["env", "XDG_CURRENT_DESKTOP=GNOME", "gnome-control-center", it.panel])
        else Quickshell.execDetached(["xdg-open", it.uri])
    }

    // File search: only for 3+ characters, 250 ms after the last key, newest query wins.
    Timer { id: debounce; interval: 250; onTriggered: if (win.query.trim().length >= 3) { find.running = false; find.running = true } }
    Process {
        id: find
        command: ["localsearch", "search", "--limit", "40", win.query.trim()]
        // the indexer also covers code checkouts: skip dependency, build and hidden folders, keep 5
        readonly property var junk: /\/(node_modules|site-packages|vendor|__pycache__|target|build|dist|venv|\.[^\/]+)\//
        stdout: StdioCollector { onStreamFinished: win.files = text.split("\n").map(l => l.trim())
            .filter(l => l.startsWith("file://") && !find.junk.test(l)).slice(0, 5) }
    }
    onQueryChanged: { files = []; debounce.restart() }

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    Rectangle {
        id: card
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.14 }
        width: 520; height: col.height + 20; radius: 16
        color: Theme.sheet; border { width: 1; color: Theme.line }
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 10; y: 10; width: parent.width - 20

            Item {
                width: parent.width; height: 50
                Item { // search glyph
                    x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18
                    Rectangle { x: 1; y: 1; width: 12; height: 12; radius: 6; color: "transparent"; border { width: 2; color: Theme.mute } }
                    Rectangle { x: 12; y: 13; width: 6; height: 2; radius: 1; rotation: 45; color: Theme.mute }
                }
                TextInput {
                    id: input
                    x: 42; width: parent.width - 54; anchors.verticalCenter: parent.verticalCenter
                    color: Theme.ink; selectionColor: Theme.ink; selectedTextColor: Theme.inverse
                    font { family: Theme.sans; pixelSize: 18 }
                    onTextChanged: win.query = text
                    Text {
                        visible: !input.text; text: "Search apps, files and settings"
                        color: Theme.mute; font: input.font
                    }
                    Keys.onEscapePressed: win.open = false
                    Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
                    Keys.onDownPressed: win.sel = Math.min(win.items.length - 1, win.sel + 1)
                    Keys.onReturnPressed: e => win.launch(win.items[win.sel], e.modifiers & Qt.ShiftModifier)
                    Keys.onEnterPressed: e => win.launch(win.items[win.sel], e.modifiers & Qt.ShiftModifier)
                }
            }

            Rectangle { visible: win.items.length > 0; width: parent.width; height: 1; color: Theme.line }
            Item { visible: win.items.length > 0; width: 1; height: 6 }

            Repeater {
                model: win.open ? win.items : []
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === win.sel
                    width: col.width; height: 44; radius: 10
                    color: chosen ? Theme.ink : (ra.containsMouse ? Theme.fill : "transparent")
                    Item {
                        id: ic
                        x: 12; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24
                        // iconPath(name, true) gives "" when the theme has no such icon: show the plain tile instead
                        readonly property string path: modelData.kind === "app" ? Quickshell.iconPath(modelData.icon, true) : ""
                        IconImage { anchors.fill: parent; visible: ic.path !== ""; source: ic.path }
                        Rectangle { anchors.fill: parent; visible: ic.path === ""; radius: 7; color: chosen ? Theme.inverse : Theme.fill }
                    }
                    Text {
                        x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60 - hint.width
                        text: modelData.label; elide: Text.ElideRight
                        color: chosen ? Theme.inverse : Theme.ink; font { family: Theme.sans; pixelSize: 15 }
                    }
                    Text {
                        id: hint
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, 200); elide: Text.ElideLeft
                        text: modelData.hint || ""; color: chosen ? Theme.inverse : Theme.mute; opacity: chosen ? 0.7 : 1
                        font { family: Theme.sans; pixelSize: 12 }
                    }
                    MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = index; onClicked: win.launch(modelData) }
                }
            }
        }
    }
}
