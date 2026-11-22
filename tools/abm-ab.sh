#!/bin/sh
# Idle watts at screen power saving (AMD ABM) levels 0, 1 and 3, then back to what it was. Run as root, on battery,
# hands off with the screen on and the same thing on it the whole time (ABM depends on the picture), ~9 minutes.
#   sudo tools/abm-ab.sh [seconds per level, default 150]
set -e
n=${1:-150}
bat=$(ls -d /sys/class/power_supply/BAT* | head -n1)
abm=$(ls /sys/class/drm/card*-eDP-*/amdgpu/panel_power_savings 2>/dev/null | head -n1)
[ -n "$abm" ] || { echo "no panel_power_savings: this screen or driver has no ABM"; exit 1; }
grep -qx Discharging "$bat/status" || { echo "unplug the charger first: ABM only works on battery"; exit 1; }
was=$(cat "$abm")
trap 'echo "$was" > "$abm"' EXIT   # always back to how it was

uw() { # microwatts now: power_now where the battery has it, else current x voltage (the Framework)
    if [ -r "$bat/power_now" ]; then cat "$bat/power_now"
    else echo "$(cat "$bat/current_now") $(cat "$bat/voltage_now")" | awk '{printf "%d", $1 * $2 / 1e6}'; fi
}
watts() { # average over $1 seconds, one sample a second
    s=0; i=0
    while [ $i -lt "$1" ]; do s=$((s + $(uw))); i=$((i + 1)); sleep 1; done
    echo "$s $1" | awk '{printf "%.2f", $1 / $2 / 1e6}'
}

echo "hands off for about $(( (n + 15) * 3 / 60 + 1 )) minutes; watch whether the screen looks different"
sleep 15
for level in 0 1 3; do
    echo "$level" > "$abm"; sleep 15
    w=$(watts "$n")
    echo "ABM $level: $w W"
    [ "$level" = 0 ] && base=$w
    [ "$level" = 0 ] || echo "$base $w" | awk '{printf "        %.2f W less than off (%.0f%%)\n", $1 - $2, ($1 - $2) / $1 * 100}'
done
echo "back to $was"
