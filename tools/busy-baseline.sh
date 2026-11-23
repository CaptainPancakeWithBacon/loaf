#!/bin/sh
# Power in use: tools/busy.mjs keeps a browser busy (scrolling, video, tab switches) while tools/baseline.py measures
# 5 minutes after 1 minute of settling. Same work in any desktop. Hands off for about 7 minutes, on battery.
# Start it detached, like baseline.py (in GNOME: gnome-session-inhibit --inhibit idle:suspend instead):
#   systemd-run --user --unit=loaf-busy systemd-inhibit --what=idle:sleep:handle-lid-switch --who=loaf --why=busy \
#       ~/Documents/De-Werkplaats/personal/loaf/tools/busy-baseline.sh
here=$(dirname "$(readlink -f "$0")")
node "$here/busy.mjs" 420 &
busy=$!
trap 'kill $busy 2>/dev/null' EXIT
sleep 10  # chrome up and its tabs open
BASELINE_LABEL="busy: browser scroll + 1080p video + tab switch every 15 s" BASELINE_ONLY_FIRST=1 "$here/baseline.py" 300 60
