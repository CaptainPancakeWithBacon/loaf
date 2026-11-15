#!/bin/sh
# Builds loaf_<version>_amd64.deb from what ./install.sh --stage lays out (no root needed).
# Needs the programs built in src/ first (see README). Output in packaging/out/.
#   packaging/build-deb.sh [VERSION]     VERSION defaults to 0.1.0+git<date>.<commit>
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out="$here/packaging/out"
root="$out/root"
version=${1:-0.1.0+git$(git -C "$here" log -1 --format=%cd.%h --date=format:%Y%m%d)}
rm -rf "$root" && mkdir -p "$root/DEBIAN"

"$here/install.sh" --stage "$root" /usr

# libraries the three programs link against, as package names (dpkg-shlibdeps wants a debian/control nearby)
mkdir -p "$out/shlibs/debian" && printf 'Source: loaf\n\nPackage: loaf\nArchitecture: any\n' > "$out/shlibs/debian/control"
shlibs=$(cd "$out/shlibs" && dpkg-shlibdeps -O "$root/usr/bin/niri" "$root/usr/bin/quickshell" "$root/usr/bin/xwayland-satellite" | sed 's/^shlibs:Depends=//')

# everything Loaf calls or loads besides those libraries
needs="qml6-module-qtquick, qml6-module-qtquick-layouts, qt6-svg-plugins, fuzzel, mako-notifier, hypridle, hyprlock,
 brightnessctl, wireplumber, libnotify-bin, wl-mirror, gnome-settings-daemon, xdg-desktop-portal-gnome,
 xdg-desktop-portal-gtk, gdm3, plymouth-theme-spinner, polkitd, python3"

cat > "$root/DEBIAN/control" <<EOF
Package: loaf
Version: $version
Architecture: amd64
Maintainer: Loaf <loaf@users.noreply.github.com>
Installed-Size: $(du -sk --exclude=DEBIAN "$root" | cut -f1)
Depends: $shlibs, $(echo $needs)
Recommends: fprintd, libpam-fprintd, gnome-control-center, gnome-console | x-terminal-emulator
Conflicts: niri, quickshell
Section: x11
Priority: optional
Homepage: https://github.com/CaptainPancakeWithBacon/loaf
Description: a desktop that naps
 A quiet, low-power desktop on the niri compositor: a bar, launcher, quick settings, lock screen,
 login screen and boot screen. Nothing moves when you are not looking. Adds "Loaf" to the login
 screen next to GNOME; GNOME stays as it is.
EOF

# settings under /etc are the admin's to edit: dpkg keeps their changes on upgrade
(cd "$root" && find etc ! -type d | sed 's|^|/|') > "$root/DEBIAN/conffiles"

cat > "$root/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
    systemctl daemon-reload 2>/dev/null || true
    /usr/lib/loaf/loaf-system activate
fi
EOF
cat > "$root/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
# only when Loaf goes away, not on an upgrade
if [ "$1" = remove ]; then /usr/lib/loaf/loaf-system deactivate; fi
EOF
cat > "$root/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
systemctl daemon-reload 2>/dev/null || true
EOF
chmod 755 "$root/DEBIAN/postinst" "$root/DEBIAN/prerm" "$root/DEBIAN/postrm"

deb="$out/loaf_${version}_amd64.deb"
dpkg-deb --root-owner-group -Zxz --build "$root" "$deb" >/dev/null
rm -rf "$out/shlibs"
echo "$deb ($(du -h "$deb" | cut -f1))"
