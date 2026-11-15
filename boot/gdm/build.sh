#!/bin/sh
# Builds Loaf's login-screen themes: Yaru's own gnome-shell theme plus loaf-login-{light,dark}.css appended to gdm.css.
# Needs nothing from root. Output: boot/gdm/build/{light,dark}.gresource (install-system.sh installs them).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${LOAF_YARU_GRESOURCE:-/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource}
OUT="$HERE/build"
PREFIX=/org/gnome/shell/theme
rm -rf "$OUT" && mkdir -p "$OUT"
for scheme in light dark; do
    root="$OUT/$scheme"
    mkdir -p "$root"
    for res in $(gresource list "$SRC"); do
        dest="$root${res#$PREFIX}"
        mkdir -p "$(dirname "$dest")"
        gresource extract "$SRC" "$res" > "$dest"
    done
    cat "$HERE/loaf-login-$scheme.css" >> "$root/gdm.css"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?><gresources><gresource prefix="'$PREFIX'">'
        (cd "$root" && find . -type f | sed 's|^\./||' | sort) | while read -r f; do echo "<file>$f</file>"; done
        echo '</gresource></gresources>'
    } > "$OUT/$scheme.xml"
    glib-compile-resources --sourcedir="$root" --target="$OUT/$scheme.gresource" "$OUT/$scheme.xml"
done
echo "built $OUT/light.gresource and $OUT/dark.gresource"
