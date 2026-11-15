#!/bin/sh
# ./install.sh            user-level: links Loaf's configs into your home folder, nothing needs sudo
# sudo ./install.sh --system   for every user on this computer: copies into /usr/local and /etc
# sudo ./install.sh --system-undo   removes that again
# Either way, the login entry, login screen and boot screen come from boot/install-system.sh.
# A user install wins over the system one (home folder first), so both can live side by side.
set -e
here=$(cd "$(dirname "$0")" && pwd)
scripts="loaf-session loaf-power loaf-mirror loaf-brightness loaf-gtk-theme loaf-terminal loaf-mako"

if [ "$1" = --system-undo ]; then
    [ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
    for f in niri xwayland-satellite quickshell qs $scripts; do rm -f /usr/local/bin/$f; done
    rm -f /etc/systemd/user/niri.service /etc/systemd/user/niri-shutdown.target
    rm -rf /etc/systemd/user/hypridle.service.d /etc/systemd/user/mako.service.d /etc/niri /etc/xdg/quickshell/loaf /etc/xdg/mako /etc/xdg/fuzzel /etc/xdg/hypr
    rm -f /etc/xdg/xdg-desktop-portal/niri-portals.conf
    echo "Removed."
    exit 0
fi

if [ "$1" = --system ]; then
    [ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
    B=/usr/local/bin X=/etc/xdg
    install -m755 "$here/src/niri/target/release/niri" "$here/src/xwayland-satellite/target/release/xwayland-satellite" $B/
    # not cmake --install: as root it would leave a root-owned file in the build folder
    install -m755 "$here/src/quickshell/build/src/quickshell" $B/ && ln -sf quickshell $B/qs
    for s in $scripts; do install -m755 "$here/session/$s" $B/; done
    sed "s|%h/.local/bin/niri|$B/niri|" "$here/session/niri.service" > /etc/systemd/user/niri.service
    install -m644 "$here/session/niri-shutdown.target" /etc/systemd/user/
    install -D -m644 "$here/session/hypridle-niri-only.conf" /etc/systemd/user/hypridle.service.d/niri-only.conf
    install -D -m644 "$here/session/mako-loaf.conf" /etc/systemd/user/mako.service.d/loaf.conf

    # niri reads ~/.config/niri/config.kdl if it exists, else this one
    install -d /etc/niri
    python3 "$here/niri/make-config.py" "$here/src/niri/resources/default-config.kdl" /etc/niri/config.kdl
    $B/niri validate -c /etc/niri/config.kdl || { echo "niri config invalid"; exit 1; }

    # each found through XDG_CONFIG_DIRS (/etc/xdg) when the user has no own copy
    rm -rf $X/quickshell/loaf; install -d $X/quickshell; cp -r "$here/loaf" $X/quickshell/loaf
    install -D -m644 "$here/mako/config" $X/mako/config
    install -D -m644 "$here/fuzzel/fuzzel.ini" $X/fuzzel/fuzzel.ini
    install -D -m644 "$here/hypr/hypridle.conf" $X/hypr/hypridle.conf
    install -D -m644 "$here/hypr/hyprlock.conf" $X/hypr/hyprlock.conf
    install -D -m644 "$here/src/niri/resources/niri-portals.conf" $X/xdg-desktop-portal/niri-portals.conf
    echo "Done. Now: sudo $here/boot/install-system.sh   (login entry, login screen, boot screen)"
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
link "$here/mako"              ~/.config/mako
link "$here/fuzzel"            ~/.config/fuzzel
link "$here/hypr"              ~/.config/hypr
# hypridle/hyprlock come from apt; this keeps hypridle out of GNOME.
mkdir -p ~/.config/systemd/user/hypridle.service.d
install -m644 "$here/session/hypridle-niri-only.conf" ~/.config/systemd/user/hypridle.service.d/niri-only.conf
cp "$here/src/niri/resources/niri-portals.conf" ~/.config/xdg-desktop-portal/niri-portals.conf

echo "Done. For the login entry, login screen and boot screen, run:"
echo "  sudo $here/boot/install-system.sh   ('undo' reverses it)"
