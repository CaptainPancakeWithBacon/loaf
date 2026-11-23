#!/bin/sh
# sudo ./install.sh --system        Loaf for every user on this computer, with its login entry, login screen and
#                                   boot screen: programs in /usr/local, settings in /etc
# sudo ./install.sh --system-undo   takes all of that off again
# ./install.sh --stage DIR [PREFIX] lays the same files out under DIR (for the .deb; PREFIX defaults to /usr)
# ./install.sh                      for working on Loaf: links the repo into your home folder (no sudo). Needs the
#                                   system install once for the login entry; the home folder wins over /etc.
set -e
here=$(cd "$(dirname "$0")" && pwd)
scripts="loaf-session loaf-power loaf-mirror loaf-brightness loaf-gtk-theme loaf-terminal loaf-fetch"
# Ubuntu's login autostarts Loaf skips (systemd runs them as app-<name>@autostart.service; GNOME keeps them).
# Your own ones in ~/.config/autostart are untouched.
skip='update-notifier org.gnome.Evolution-alarm-notify print-applet org.kde.kdeconnect.daemon geoclue-demo-agent'
skip_autostarts() { # $1 = systemd user unit folder
    for a in $skip; do
        install -D -m644 "$here/session/autostart-skip.conf" "$1/app-$(systemd-escape "$a")@autostart.service.d/loaf-skip.conf"
    done
}

# Everything for a system-wide install, laid out under folder $1 with programs under prefix $2.
# The .deb (packaging/build-deb.sh) packs exactly this folder; --system copies it onto /.
stage() {
    S=$1 P=$2 X=$1/etc/xdg/xdg-loaf U=$1/etc/systemd
    install -d $S$P/bin $S$P/lib/loaf $U/user $U/system $S/etc/niri $S/etc/polkit-1/rules.d \
        $S/usr/share/wayland-sessions $S/usr/share/pixmaps $S/usr/share/gnome-shell/theme/Loaf $S/usr/share/plymouth/themes/loaf
    install -s -m755 "$here/src/niri/target/release/niri" "$here/src/xwayland-satellite/target/release/xwayland-satellite" \
        "$here/src/quickshell/build/src/quickshell" $S$P/bin/
    ln -sf quickshell $S$P/bin/qs
    for s in $scripts; do install -m755 "$here/session/$s" $S$P/bin/; done
    install -m755 "$here/session/loaf-system" "$here/session/loaf-login-scheme" $S$P/lib/loaf/

    # session: niri as a user service, idle/lock only in Loaf, no mako (Loaf shows notifications), fewer autostarts
    sed "s|%h/.local/bin/niri|$P/bin/niri|" "$here/session/niri.service" > $U/user/niri.service
    install -m644 "$here/session/niri-shutdown.target" $U/user/
    install -D -m644 "$here/session/hypridle-niri-only.conf" $U/user/hypridle.service.d/niri-only.conf
    install -D -m644 "$here/session/mako-loaf.conf" $U/user/mako.service.d/loaf.conf
    skip_autostarts $U/user
    sed "s|@BIN@|$P/bin|" "$here/session/loaf.desktop.in" > $S/usr/share/wayland-sessions/loaf.desktop

    # niri reads ~/.config/niri/config.kdl if it exists, else this one
    python3 "$here/niri/make-config.py" "$here/src/niri/resources/default-config.kdl" $S/etc/niri/config.kdl
    $S$P/bin/niri validate -c $S/etc/niri/config.kdl 2>/dev/null || { echo "niri config invalid"; exit 1; }

    # Loaf's own settings layer: GDM puts /etc/xdg/xdg-loaf in XDG_CONFIG_DIRS for a Loaf login (loaf-session
    # makes sure), so these apply in Loaf only, never in GNOME, and never clash with other packages' files
    install -d $X/quickshell && tar -C "$here" --exclude='.*' -cf - loaf | tar -C $X/quickshell -xf - --no-same-owner
    install -D -m644 "$here/fuzzel/fuzzel.ini" $X/fuzzel/fuzzel.ini
    install -D -m644 "$here/hypr/hypridle.conf" $X/hypr/hypridle.conf
    install -D -m644 "$here/hypr/hyprlock.conf" $X/hypr/hyprlock.conf
    install -D -m644 "$here/src/niri/resources/niri-portals.conf" $X/xdg-desktop-portal/niri-portals.conf

    # fingerprint restart and login light/dark for the person at the computer (inert without fprintd)
    install -m644 "$here/session/50-loaf-fprintd.rules" "$here/session/50-loaf-login-scheme.rules" $S/etc/polkit-1/rules.d/
    sed "s|@PREFIX@|$P|" "$here/session/loaf-login-scheme@.service" > $U/system/loaf-login-scheme@.service

    # login screen (logo, Yaru plus Loaf's colours, light and dark) and boot screen; loaf-system switches them on
    install -m644 "$here/boot/loaf-login.svg" $S/usr/share/pixmaps/
    ${SUDO_USER:+runuser -u "$SUDO_USER" --} "$here/boot/gdm/build.sh" >/dev/null
    install -m644 "$here/boot/gdm/build/light.gresource" "$here/boot/gdm/build/dark.gresource" $S/usr/share/gnome-shell/theme/Loaf/
    install -m644 "$here/boot/plymouth/loaf/"* $S/usr/share/plymouth/themes/loaf/
}

if [ "$1" = --stage ]; then stage "${2:?folder}" "${3:-/usr}"; exit 0; fi

L=/usr/local/lib/loaf/files
if [ "$1" = --system ] || [ "$1" = --system-undo ]; then
    [ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
    if [ "$1" = --system-undo ]; then
        [ -f $L ] || { echo "no system install recorded in $L"; exit 1; }
        /usr/local/lib/loaf/loaf-system deactivate
    fi
    if [ -f $L ]; then # remove the previous files first, so files Loaf no longer ships go too
        sed 's|^\.||' $L | while read -r f; do rm -f "$f"; done
        rm -rf /etc/xdg/xdg-loaf/quickshell/loaf
    fi
    [ "$1" = --system-undo ] && { systemctl daemon-reload; echo "Removed."; exit 0; }
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    stage "$tmp" /usr/local
    # left over from before this script recorded its files (fuzzel.ini: only if it is Loaf's copy, fuzzel owns that path)
    rm -f /usr/local/share/dbus-1/services/fr.emersion.mako.service /usr/local/libexec/loaf-login-scheme
    rm -rf /etc/xdg/quickshell/loaf /etc/xdg/mako /etc/xdg/hypr /etc/xdg/xdg-desktop-portal/niri-portals.conf
    cmp -s /etc/xdg/fuzzel/fuzzel.ini "$here/fuzzel/fuzzel.ini" && rm /etc/xdg/fuzzel/fuzzel.ini &&
        echo "fuzzel's own settings file was replaced by Loaf's before; put it back with:" &&
        echo "  sudo apt install --reinstall -o Dpkg::Options::=--force-confmiss fuzzel"
    # tar, not cp -a: existing folders keep their owner and mode (/etc/polkit-1/rules.d is locked down)
    tar -C "$tmp" -cf - . | tar -C / -xf - --no-overwrite-dir --no-same-owner
    (cd "$tmp" && find . ! -type d) > $L
    systemctl daemon-reload
    /usr/local/lib/loaf/loaf-system activate
    echo "Done: Loaf for every user, with its login and boot screen. 'sudo $0 --system-undo' takes it off."
    exit 0
fi

mkdir -p ~/.local/bin ~/.config/niri ~/.config/xdg-desktop-portal ~/.config/systemd/user
install -m755 "$here/src/niri/target/release/niri" ~/.local/bin/niri
install -m755 "$here/src/xwayland-satellite/target/release/xwayland-satellite" ~/.local/bin/
cmake --install "$here/src/quickshell/build" >/dev/null
for s in $scripts; do install -m755 "$here/session/$s" ~/.local/bin/; done
install -m644 "$here/session/niri.service" "$here/session/niri-shutdown.target" ~/.config/systemd/user/

python3 "$here/niri/make-config.py" "$here/src/niri/resources/default-config.kdl" ~/.config/niri/config.kdl
niri validate || { echo "niri config invalid"; exit 1; }

link() { rm -rf "$2"; ln -s "$1" "$2"; }
mkdir -p ~/.config/quickshell
link "$here/loaf"             ~/.config/quickshell/loaf
# Loaf shows notifications itself: keep mako out of Loaf sessions (GNOME is unaffected)
[ -L ~/.config/mako ] && rm ~/.config/mako
install -D -m644 "$here/session/mako-loaf.conf" ~/.config/systemd/user/mako.service.d/loaf.conf
install -D -m644 "$here/session/fr.emersion.mako.service" ~/.local/share/dbus-1/services/fr.emersion.mako.service
link "$here/fuzzel"            ~/.config/fuzzel
link "$here/hypr"              ~/.config/hypr
# hypridle/hyprlock come from apt; this keeps hypridle out of GNOME.
mkdir -p ~/.config/systemd/user/hypridle.service.d
install -m644 "$here/session/hypridle-niri-only.conf" ~/.config/systemd/user/hypridle.service.d/niri-only.conf
skip_autostarts ~/.config/systemd/user
cp "$here/src/niri/resources/niri-portals.conf" ~/.config/xdg-desktop-portal/niri-portals.conf

echo "Done. If Loaf is not on the login screen yet: sudo $here/install.sh --system"
