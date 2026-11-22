#!/bin/sh
# Before/after: idle watts with USB autosuspend off (as booted) and on. Run as root, on battery, hands off
# for about 7 minutes with the screen on. Turning it on lasts until the next boot (that is the undo).
#   sudo tools/usb-autosuspend-ab.sh [seconds per half, default 180]
set -e
n=${1:-180}
bat=$(ls -d /sys/class/power_supply/BAT* | head -n1)
grep -qx Discharging "$bat/status" || { echo "unplug the charger first: the battery has to be discharging"; exit 1; }

uw() { # microwatts now: power_now where the battery has it, else current x voltage (the Framework)
    if [ -r "$bat/power_now" ]; then cat "$bat/power_now"
    else echo "$(cat "$bat/current_now") $(cat "$bat/voltage_now")" | awk '{printf "%d", $1 * $2 / 1e6}'; fi
}
watts() { # average over $1 seconds, one sample a second
    s=0; i=0
    while [ $i -lt "$1" ]; do s=$((s + $(uw))); i=$((i + 1)); sleep 1; done
    echo "$s $1" | awk '{printf "%.2f", $1 / $2 / 1e6}'
}

echo "hands off for about $((n * 2 / 60 + 1)) minutes"
sleep 20
before=$(watts "$n")
echo "autosuspend off: $before W"

# every USB device may sleep after 2 s idle, except those set to stay on (the NuPhy dongle)
for d in /sys/bus/usb/devices/*/power; do
    [ -w "$d/autosuspend_delay_ms" ] && echo 2000 > "$d/autosuspend_delay_ms" || true
done
sleep 30
after=$(watts "$n")
echo "autosuspend on:  $after W"
echo "$before $after" | awk '{printf "difference:      %.2f W (%.0f%%)\n", $1 - $2, ($1 - $2) / $1 * 100}'
for d in /sys/bus/usb/devices/*; do
    [ -f "$d/product" ] && printf '  %-12s %s\n' "$(cat "$d/power/runtime_status")" "$(cat "$d/product")"
done
echo "stays like this until the next boot"
