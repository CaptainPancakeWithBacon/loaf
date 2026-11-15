// Low-battery warning (GNOME's comes from gnome-settings-daemon, which Loaf does not run).
// While discharging: a normal notification at 20%, an urgent one that stays at 10% and 5%.
// Each level once per discharge; plugging in resets it. Follows UPower, nothing polls.
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Scope {
    id: root
    readonly property var bat: UPower.displayDevice
    readonly property bool discharging: bat.isPresent && bat.state === UPowerDeviceState.Discharging
    readonly property int pct: Math.round(bat.percentage * 100)
    property int warned: 101 // lowest level already warned about in this discharge

    onDischargingChanged: { if (discharging) check(); else warned = 101 }
    onPctChanged: check()
    Component.onCompleted: check()

    function check() {
        if (!discharging) return
        for (const level of [5, 10, 20])
            if (pct <= level && level < warned) { warned = level; warn(level, pct); return }
    }

    function warn(level, now) {
        const text = level > 10 ? "Plug in soon."
                   : level > 5  ? "Plug in now."
                   : "Below 5% the laptop shuts down to protect the battery. Plug in now."
        Quickshell.execDetached(["notify-send", "-a", "Loaf", "-i", "battery-caution",
                                 "-u", level > 10 ? "normal" : "critical", "Battery at " + now + "%", text])
    }
}
