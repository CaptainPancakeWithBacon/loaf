#!/bin/sh
# User-level install only: nothing here touches GNOME or needs sudo.
# Prints the one sudo line that adds the login-screen entry.
set -e
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/.local/bin ~/.config/niri ~/.config/xdg-desktop-portal ~/.config/systemd/user

install -m755 "$here/src/niri/target/release/niri" ~/.local/bin/niri
install -m755 "$here/src/xwayland-satellite/target/release/xwayland-satellite" ~/.local/bin/
cmake --install "$here/src/quickshell/build" >/dev/null
install -m755 "$here/session/loaf-session" "$here/session/loaf-power" "$here/session/loaf-mirror" "$here/session/loaf-brightness" "$here/session/loaf-gtk-theme" "$here/session/loaf-terminal" ~/.local/bin/
install -m644 "$here/session/niri.service" "$here/session/niri-shutdown.target" ~/.config/systemd/user/

python3 "$here/niri/make-config.py" "$here/src/niri/resources/default-config.kdl" ~/.config/niri/config.kdl
niri validate || { echo "niri config invalid"; exit 1; }

link() { rm -rf "$2"; ln -s "$1" "$2"; }
mkdir -p ~/.config/quickshell
link "$here/loaf"             ~/.config/quickshell/loaf
link "$here/mako"              ~/.config/mako
link "$here/fuzzel"            ~/.config/fuzzel
link "$here/hypr"              ~/.config/hypr
# hypridle/hyprlock come from apt (sudo, Gijs's part); this keeps hypridle out of GNOME.
mkdir -p ~/.config/systemd/user/hypridle.service.d
install -m644 "$here/session/hypridle-niri-only.conf" ~/.config/systemd/user/hypridle.service.d/niri-only.conf
cp "$here/src/niri/resources/niri-portals.conf" ~/.config/xdg-desktop-portal/niri-portals.conf

sed "s|@HOME@|$HOME|" "$here/session/loaf.desktop.in" > "$here/session/loaf.desktop"
echo "Done. To get the login entry, run:"
echo "  sudo $here/boot/install-system.sh   (login entry, login logo, boot screen; 'undo' reverses it)"
