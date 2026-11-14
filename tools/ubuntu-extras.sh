#!/bin/sh
# Power test (plan section 9): stop Ubuntu's background extras for 7 minutes, then start them again.
# Run as: sudo tools/ubuntu-extras.sh      (Ctrl+C also starts everything again)
# baseline.py measures "extras off" during the pause and "as is" after it.
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
user=${SUDO_USER:?run through sudo}
SYS="cups.path cups.socket cups.service cups-browsed.service snap.cups.cupsd.service snap.cups.cups-browsed.service
     fwupd.service unattended-upgrades.service snap.canonical-livepatch.canonical-livepatchd.service snapd.socket snapd.service"
USR="evolution-source-registry.service evolution-calendar-factory.service evolution-addressbook-factory.service
     app-org.gnome.Evolution\x2dalarm\x2dnotify@autostart.service"

restore() {
    systemctl start $SYS
    systemctl --user -M "$user@" start $USR
    echo "$(date +%H:%M:%S) everything started again"
}
trap 'restore; exit' INT TERM

systemctl stop $SYS
systemctl --user -M "$user@" stop $USR
echo "$(date +%H:%M:%S) extras stopped; starting them again in 7 minutes. You can walk away now."
sleep 420
restore
