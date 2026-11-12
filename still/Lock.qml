// Still lock screen (layout from the demo's .lock): big clock, date, fingerprint circle, password field,
// on every screen. Two PAM conversations run side by side, so a finger or a password unlocks, whichever
// comes first (pam/still-finger, pam/still-password). niri keeps the session locked if this process dies;
// hypridle then falls back to hyprlock (see hypr/hypridle.conf).
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

Scope {
    id: root
    property alias locked: session.locked
    property string message: "Touch the sensor or type your password"
    property bool error: false
    property string pending: ""
    property bool busy: false
    readonly property string pamDir: Quickshell.shellPath("pam")

    function lock() { session.locked = true }
    function done() { finger.abort(); retry.stop(); session.locked = false; message = "Touch the sensor or type your password"; error = false }
    function tryPassword(text) {
        if (!text || busy) return
        pending = text; busy = true; error = false; message = "Checking"
        password.start()
    }

    WlSessionLock {
        id: session
        onLockedChanged: {
            if (locked) { root.error = false; finger.start() }
            // Tell logind (hypridle waits for this before letting the laptop suspend)
            Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                                     "org.freedesktop.login1.Session", "SetLockedHint", "b", locked ? "true" : "false"])
        }

        WlSessionLockSurface {
            color: Theme.soft
            SystemClock { id: clock; precision: SystemClock.Minutes }

            Column {
                anchors.centerIn: parent
                spacing: 44

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, "HH:mm"); color: Theme.ink
                        font { family: Theme.sans; pixelSize: 128; letterSpacing: -6; features: { "tnum": 1 } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(clock.date, "dddd d MMMM"); color: Theme.mute
                        font { family: Theme.sans; pixelSize: 18 }
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Rectangle { // fingerprint circle: ink ring, filled while PAM is listening
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 84; height: 84; radius: 42
                        color: Theme.sheet; border { width: 1.5; color: root.error ? "#B4534B" : Theme.ink }
                        Repeater { // three arcs as a simple fingerprint mark
                            model: [30, 22, 14]
                            Rectangle {
                                anchors.centerIn: parent
                                width: modelData; height: modelData; radius: modelData / 2
                                color: "transparent"; border { width: 1.5; color: Theme.ink }
                                opacity: finger.active ? 1 : 0.35
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.message; color: root.error ? "#B4534B" : Theme.ink
                        font { family: Theme.sans; pixelSize: 15 }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 300; height: 44; radius: 12
                        color: Theme.sheet; border { width: 1; color: Theme.line }
                        TextInput {
                            id: field
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password; passwordCharacter: "•"
                            color: Theme.ink; font { family: Theme.sans; pixelSize: 15 }
                            focus: true; enabled: !root.busy
                            Component.onCompleted: forceActiveFocus()
                            Text { visible: !field.text; text: "Password"; color: Theme.mute; font: field.font; anchors.verticalCenter: parent.verticalCenter }
                            onAccepted: { root.tryPassword(text); text = "" }
                            Keys.onEscapePressed: text = ""
                        }
                    }
                }
            }
        }
    }

    // Finger: restarts after a timeout or 3 misses for as long as the screen is locked.
    PamContext {
        id: finger
        configDirectory: root.pamDir; config: "still-finger"
        onPamMessage: if (message && !root.busy) { root.message = message.includes("finger") ? "Touch the sensor or type your password" : message; root.error = messageIsError }
        onCompleted: result => {
            if (result === PamResult.Success) root.done()
            else if (session.locked) { root.error = true; root.message = "Finger not recognised"; retry.start() }
        }
        onError: if (session.locked) retry.start()
    }
    Timer { id: retry; interval: 1500; onTriggered: if (session.locked && !finger.active) finger.start() }

    // Password: started when Enter is pressed, answers PAM's prompt with what was typed.
    PamContext {
        id: password
        configDirectory: root.pamDir; config: "still-password"
        onResponseRequiredChanged: if (responseRequired) { respond(root.pending); root.pending = "" }
        onCompleted: result => {
            root.busy = false
            if (result === PamResult.Success) root.done()
            else { root.error = true; root.message = "Wrong password" }
        }
        onError: { root.busy = false; root.error = true; root.message = "Could not check the password" }
    }
}
