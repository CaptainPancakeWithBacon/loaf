#!/bin/sh
# Loaf's system-wide bits (the only part that needs root). Run from the repo:
#   sudo boot/install-system.sh        install: fprintd restart rule, login entry "Loaf", Loaf login screen + logo,
#                                      Loaf boot screen (Framework logo, progress bar, Loaf at the bottom)
#   sudo boot/install-system.sh undo   back to: no rule, no Loaf entry, the previous login theme (Isobar's), Ubuntu's boot screen
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
    systemctl disable --now loaf-login-scheme.path 2>/dev/null || true
    rm -f /etc/systemd/system/loaf-login-scheme.path /etc/systemd/system/loaf-login-scheme.service /usr/local/libexec/loaf-login-scheme
    systemctl daemon-reload
    update-alternatives --remove gdm-theme.gresource /usr/share/gnome-shell/theme/Loaf/gnome-shell-theme.gresource || true
    rm -rf /usr/share/gnome-shell/theme/Loaf
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

# 2b. login screen theme: Yaru plus Loaf's colours, a light and a dark one (built as you, no root needed for that).
#     Takes precedence over Isobar's theme (priority 30 > 25); undo puts the highest other one back.
#     A root path unit watches ~/.local/state/loaf/login-scheme (written by loaf-gtk-theme on every switch)
#     and copies the matching theme over the active one; it accepts only "light" or "dark".
runuser -u "$SUDO_USER" -- "$here/boot/gdm/build.sh"
L=/usr/share/gnome-shell/theme/Loaf
install -d $L
install -m644 "$here/boot/gdm/build/light.gresource" "$here/boot/gdm/build/dark.gresource" $L/
install -D -m755 "$here/session/loaf-login-scheme" /usr/local/libexec/loaf-login-scheme
state="$user_home/.local/state/loaf/login-scheme"
[ -f "$state" ] || runuser -u "$SUDO_USER" -- sh -c "mkdir -p '$user_home/.local/state/loaf' && echo dark > '$state'"
cp -f $L/dark.gresource $L/gnome-shell-theme.gresource
/usr/local/libexec/loaf-login-scheme "$state"
for u in path service; do
    sed "s|@HOME@|$user_home|" "$here/session/loaf-login-scheme.$u.in" > /etc/systemd/system/loaf-login-scheme.$u
done
systemctl daemon-reload
systemctl enable --now loaf-login-scheme.path
update-alternatives --install /usr/share/gnome-shell/gdm-theme.gresource gdm-theme.gresource \
    /usr/share/gnome-shell/theme/Loaf/gnome-shell-theme.gresource 30
update-alternatives --set gdm-theme.gresource /usr/share/gnome-shell/theme/Loaf/gnome-shell-theme.gresource

# 3. boot screen: two-step like Ubuntu's own (firmware logo kept), with a progress bar and Loaf's watermark.
#    The password-prompt images come from Ubuntu's spinner theme; an empty 1-pixel throbber means no spinner.
rm -rf $T/loaf
install -d $T/loaf
install -m644 "$here/boot/plymouth/loaf/"* $T/loaf/
for f in bgrt-fallback.png bullet.png capslock.png entry.png keyboard.png keymap-render.png lock.png; do
    [ -f $T/spinner/$f ] && install -m644 $T/spinner/$f $T/loaf/
done
update-alternatives --install $T/default.plymouth default.plymouth $T/loaf/loaf.plymouth 150
update-alternatives --set default.plymouth $T/loaf/loaf.plymouth
update-initramfs -u

echo "Done. Log out to see the login logo and pick 'Loaf'; reboot to see the boot screen."
