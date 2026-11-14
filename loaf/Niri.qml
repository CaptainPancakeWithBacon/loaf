// niri state from its event stream (no polling): workspaces for the bar, windows for the launcher.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: niri
    // [{id, idx, output, is_active, is_focused, active_window_id}], sorted by idx
    property var workspaces: []
    // [{id, app_id, workspace_id, focus_timestamp, ...}]
    property var windows: []

    // The open window of a desktop entry (matched on desktop id or StartupWMClass), most recently focused first.
    function windowFor(entry) {
        const ids = [entry.id, entry.startupClass].filter(x => x).map(x => x.toLowerCase())
        const ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos : 0
        return windows.filter(w => w.app_id && ids.includes(w.app_id.toLowerCase())).sort((a, b) => ts(b) - ts(a))[0] || null
    }

    function on(output) { return workspaces.filter(w => w.output === output) }

    function focus(ws) {
        Quickshell.execDetached(["sh", "-c", `niri msg action focus-monitor ${ws.output} && niri msg action focus-workspace ${ws.idx}`])
    }

    // When a screen disappears (dock unplugged, lid closed), niri moves its workspaces to
    // another screen but keeps showing that screen's own workspace, so the windows look
    // gone (Phase 1, test 1). Decide which window to bring back into view.
    // prev, next: workspace lists before and after the change.
    // Return a window id to focus, or null to leave everything as it is.
    function windowToBringBack(prev, next) {
        const alive = new Set(next.map(w => w.output))
        if (prev.some(w => w.is_focused && alive.has(w.output)))
            return null // focus was on a screen that is still here: nothing to rescue
        const lost = prev.filter(w => w.is_active && !alive.has(w.output) && w.active_window_id !== null)
        const pick = lost.find(w => w.is_focused) || lost[0]
        return pick ? pick.active_window_id : null
    }

    function handle(e) {
        if (e.WorkspacesChanged) {
            const next = e.WorkspacesChanged.workspaces.sort((a, b) => a.idx - b.idx)
            const id = windowToBringBack(workspaces, next)
            workspaces = next
            if (id !== null && id !== undefined)
                Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)])
        } else if (e.WorkspaceActivated) {
            const { id, focused } = e.WorkspaceActivated
            const out = (workspaces.find(w => w.id === id) || {}).output
            workspaces = workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === out ? w.id === id : w.is_active,
                is_focused: focused ? w.id === id : w.is_focused
            }))
        } else if (e.WindowsChanged) {
            windows = e.WindowsChanged.windows
        } else if (e.WindowOpenedOrChanged) {
            const w = e.WindowOpenedOrChanged.window
            windows = windows.filter(x => x.id !== w.id).concat([w])
        } else if (e.WindowClosed) {
            windows = windows.filter(x => x.id !== e.WindowClosed.id)
        } else if (e.WorkspaceActiveWindowChanged) {
            const { workspace_id, active_window_id } = e.WorkspaceActiveWindowChanged
            workspaces = workspaces.map(w => w.id === workspace_id ? Object.assign({}, w, { active_window_id }) : w)
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser { onRead: l => { try { niri.handle(JSON.parse(l)) } catch (err) { console.warn("niri event:", err) } } }
        onRunningChanged: if (!running) running = true
    }
}
