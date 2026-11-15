// Loaf lock screen (layout from the demo's .lock): big clock, date, fingerprint circle, password field,
// on every screen. Two PAM conversations run side by side, so a finger or a password unlocks, whichever
// comes first (pam/loaf-finger, pam/loaf-password). niri keeps the session locked if this process dies;
// hypridle then falls back to hyprlock (see hypr/hypridle.conf).
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import QtQuick

Scope {
    id: root
    property alias locked: session.locked
    property string message: "Touch the sensor or type your password"
    property bool error: false
    property string pending: ""
    property bool busy: false
    readonly property string pamDir: Quickshell.shellPath("pam")

    // The sensor breaks if the laptop suspends while fprintd is listening ("Cannot run while suspended",
    // then PAM code 9 on every try). hypridle calls sleep()/wake() around every suspend, but closing the lid
    // suspends in the same second, so sleep() can lose that race. fprintd only recovers once it exits, which
    // it does ~30 s after its last client: so after 3 failures the lock stays quiet for 35 s, then tries again.
    property bool asleep: false
    property int fingerFails: 0
    // first fix after a failure: restart fprintd (allowed by session/50-loaf-fprintd.rules.in), then try again
    property bool restartTried: false
    Process {
        id: restartFprintd
        command: ["systemctl", "restart", "--no-ask-password", "fprintd.service"]
        onExited: code => { root.log("fprintd restart exit " + code); if (session.locked && !root.asleep) retry.restart() }
    }

    function log(what) { console.log(new Date().toISOString() + " lock: " + what) }
    function lock() { session.locked = true }
    function done() { finger.abort(); retry.stop(); asleep = false; session.locked = false; message = "Touch the sensor or type your password"; error = false }
    function sleep() { log("sleep, finger off"); asleep = true; retry.stop(); finger.abort() }
    function wake() { log("wake, finger back in 1.5 s"); asleep = false; fingerFails = 0; restartTried = false; if (session.locked) retry.restart() }
    function tryPassword(text) {
        if (!text || busy) return
        pending = text; busy = true; error = false; message = "Checking"
        password.start()
    }

    WlSessionLock {
        id: session
        onLockedChanged: {
            if (locked) { root.error = false; root.fingerFails = 0; root.restartTried = false; if (!root.asleep) finger.start() }
            // Tell logind (hypridle waits for this before letting the laptop suspend)
            Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                                     "org.freedesktop.login1.Session", "SetLockedHint", "b", locked ? "true" : "false"])
        }

        WlSessionLockSurface {
            color: Theme.soft
            SystemClock { id: clock; precision: SystemClock.Minutes }
            Image { // quiet wordmark at the bottom
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
                width: 66; height: 34
                sourceSize { width: 132; height: 68 }
                source: Theme.logo("wordmark")
            }

            Column {
                anchors.centerIn: parent
                spacing: 44

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Image { // the Loaf cat, asleep, like the laptop
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64; height: 64
                        sourceSize { width: 128; height: 128 }
                        source: Theme.logo("mark")
                    }
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
        configDirectory: root.pamDir; config: "loaf-finger"
        onPamMessage: if (message && !root.busy) { root.message = message.includes("finger") ? "Touch the sensor or type your password" : message; root.error = messageIsError }
        onCompleted: result => {
            if (result === PamResult.Success) root.done()
            else if (session.locked) { root.error = true; root.message = "Finger not recognised"; retry.start() }
        }
        onError: {
            if (!session.locked || root.asleep) return
            root.log("finger error " + (root.fingerFails + 1))
            if (!root.restartTried) {   // most likely a suspend broke fprintd: restart it once, right away
                root.restartTried = true
                if (!root.busy) root.message = "Waking up the fingerprint reader"
                restartFprintd.running = true
                return
            }
            root.fingerFails++
            if (root.fingerFails >= 3 && !root.busy) { root.error = true; root.message = "Fingerprint is restarting, type your password or wait half a minute" }
            retry.start()
        }
    }
    // after 3 failures in a row, leave fprintd alone for 35 s so it can exit and start fresh
    Timer {
        id: retry; interval: root.fingerFails >= 3 ? 35000 : 1500
        onTriggered: if (session.locked && !root.asleep && !finger.active) { root.log("finger start"); finger.start() }
    }

    // Password: started when Enter is pressed, answers PAM's prompt with what was typed.
    PamContext {
        id: password
        configDirectory: root.pamDir; config: "loaf-password"
        onResponseRequiredChanged: if (responseRequired) { respond(root.pending); root.pending = "" }
        onCompleted: result => {
            root.busy = false
            if (result === PamResult.Success) root.done()
            else { root.error = true; root.message = "Wrong password" }
        }
        onError: { root.busy = false; root.error = true; root.message = "Could not check the password" }
    }
}
