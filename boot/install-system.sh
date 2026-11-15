#!/bin/sh
# Loaf's system-wide bits (the only part that needs root). Run from the repo:
#   sudo boot/install-system.sh        install: fprintd restart rule, login entry "Loaf", login logo, Loaf boot screen
#   sudo boot/install-system.sh undo   back to: no rule, no Loaf entry, no login logo, Ubuntu's boot screen (bgrt)
# The old "Niri (Mist)" entry is left alone; remove it once Loaf has logged in fine:
#   sudo rm /usr/share/wayland-sessions/niri-mist.desktop
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
here=$(cd "$(dirname "$0")/.." && pwd)
user_home=$(getent passwd "${SUDO_USER:?run through sudo}" | cut -d: -f6)
T=/usr/share/plymouth/themes
G=/etc/gdm3/greeter.dconf-defaults

if [ "$1" = undo ]; then
    rm -f /etc/polkit-1/rules.d/50-loaf-fprintd.rules
    rm -f /usr/share/wayland-sessions/loaf.desktop
    sed -i "s|^logo='/usr/share/pixmaps/loaf-login.png'|#logo='/usr/share/images/vendor-logos/logo-text-version-64.png'|" "$G"
    rm -f /usr/share/pixmaps/loaf-login.png
    update-alternatives --set default.plymouth $T/bgrt/bgrt.plymouth
    update-alternatives --remove default.plymouth $T/loaf/loaf.plymouth || true
    rm -rf $T/loaf
    update-initramfs -u
    echo "Undone. Reboot to see Ubuntu's boot screen again."
    exit 0
fi

# 0. the lock may restart fprintd after a suspend broke it (only that unit, only that verb, only you)
sed "s|@USER@|$SUDO_USER|" "$here/session/50-loaf-fprintd.rules.in" > /etc/polkit-1/rules.d/50-loaf-fprintd.rules
chmod 644 /etc/polkit-1/rules.d/50-loaf-fprintd.rules

# 1. login entry
sed "s|@HOME@|$user_home|" "$here/session/loaf.desktop.in" > /usr/share/wayland-sessions/loaf.desktop
chmod 644 /usr/share/wayland-sessions/loaf.desktop

# 2. logo under the user list on the login screen (Ubuntu's own setting, commented out by default)
install -m644 "$here/boot/loaf-login.png" /usr/share/pixmaps/loaf-login.png
cp -n "$G" "$G.before-loaf"
sed -i "s|^#logo=.*|logo='/usr/share/pixmaps/loaf-login.png'|" "$G"
grep -q "^logo='/usr/share/pixmaps/loaf-login.png'" "$G" || echo "warning: logo line not found in $G"

# 3. boot screen
install -d $T/loaf
install -m644 "$here/boot/plymouth/loaf/"* $T/loaf/
update-alternatives --install $T/default.plymouth default.plymouth $T/loaf/loaf.plymouth 150
update-alternatives --set default.plymouth $T/loaf/loaf.plymouth
update-initramfs -u

echo "Done. Log out to see the login logo and pick 'Loaf'; reboot to see the boot screen."
