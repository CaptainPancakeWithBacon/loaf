#!/usr/bin/env python3
"""Mist niri config = niri's own default config with a few exact substitutions.
Fails loudly if a substitution no longer matches (e.g. after a niri update)."""
import os, re, sys
src = open(sys.argv[1]).read()

def sub(pattern, repl, flags=0):
    global src
    src, n = re.subn(pattern, repl, src, count=1, flags=flags)
    if n != 1:
        sys.exit(f"no match for: {pattern}")

# Still draws its own ground (follows dark style), so no swaybg.
sub(r'spawn-at-startup "waybar"',
    'spawn-at-startup "sh" "-c" "mkdir -p ~/.cache/still && exec qs -p ~/.config/quickshell/still > ~/.cache/still/qs.log 2>&1"\n'
    # GNOME Settings' Bluetooth page (pairing new devices) asks gsd-rfkill, which only GNOME starts. Costs ~0 CPU.
    'spawn-at-startup "/usr/libexec/gsd-rfkill"\n'
    # Apps keep their stock look in niri: drop Isobar's import (Isobar adds it back when GNOME starts).
    'spawn-at-startup "sh" "-c" "sed -i \'/@import url(\\"mist.css\\");/d\' ~/.config/gtk-4.0/gtk.css"')
sub(r'gaps 16', 'gaps 14')
sub(r'active-color "#7fc8ff"', 'active-color "#101418"')
sub(r'inactive-color "#505050"', 'inactive-color "#C6CFD6"')
sub(r'(focus-ring \{[^}]*?)(?<![/#])width 4', r'\1width 2')
sub(r'/-window-rule \{(\s*)geometry-corner-radius 12', r'window-rule {\1geometry-corner-radius 18')
sub(r'(\nhotkey-overlay \{)', r'\nprefer-no-csd\n\1')
sub(r'(hotkey-overlay \{)', r'\1\n    skip-at-startup')
sub(r'(\n    Mod\+D [^\n]*\n)', r'\1    Mod+X hotkey-overlay-title="Power menu" { spawn "mist-power"; }\n'
    r'    Mod+P hotkey-overlay-title="Mirror to external screen" { spawn "mist-mirror"; }\n'
    # Gijs reaches for the GNOME/Windows key; Print, Ctrl+Print and Alt+Print stay as niri ships them.
    r'    Mod+Shift+S hotkey-overlay-title="Screenshot: select an area" { screenshot; }\n')
sub(r'spawn "alacritty"', 'spawn "ghostty"')
sub(r'alacritty', 'ghostty')
# Super+D opens Still's launcher; fuzzel stays on Super+Shift+D as a fallback while the launcher is new.
sub(r'Mod\+D hotkey-overlay-title="Run an Application: fuzzel" \{ spawn "fuzzel"; \}',
    'Mod+D hotkey-overlay-title="Search apps, files and settings" { spawn "sh" "-c" "qs ipc -p ~/.config/quickshell/still call launcher toggle"; }\n'
    '    Mod+Shift+D hotkey-overlay-title="Run an Application: fuzzel (fallback)" { spawn "fuzzel"; }')
# Lock through logind so hypridle runs hyprlock (fingerprint) for the key, idle and suspend alike.
sub(r'"Lock the Screen: swaylock" \{ spawn "swaylock"; \}', '"Lock the Screen" { spawn "loginctl" "lock-session"; }')
# Volume keys also show Still's OSD. Brightness goes through logind (brightnessctl needs root or the video group).
osd = '; qs ipc -p ~/.config/quickshell/still call osd volume'
sub(r'(wpctl set-volume @DEFAULT_AUDIO_SINK@ 0\.1\+ -l 1\.0)"', r'\1' + osd + '"')
sub(r'(wpctl set-volume @DEFAULT_AUDIO_SINK@ 0\.1-)"', r'\1' + osd + '"')
sub(r'(wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle)"', r'\1' + osd + '"')
sub(r'spawn "brightnessctl" "--class=backlight" "set" "\+10%"', 'spawn "still-brightness" "+10"')
sub(r'spawn "brightnessctl" "--class=backlight" "set" "10%-"', 'spawn "still-brightness" "-10"')
# Coucou's island (X11 via xwayland-satellite, GDK_BACKEND=x11) floats at the top, never tiled.
# Native Wayland Coucou idled at 23% of a core here; X11 + floating at 1.6% (measurements/baseline.tsv).
src += '''
window-rule {
    match app-id="^Coucou-sys$"
    open-floating true
    open-focused false
    default-floating-position x=0 y=0 relative-to="top"
    border { off; }
    focus-ring { off; }
    shadow { off; }
}
'''
# Games started through Proton/umu (Lutris, Steam) open fullscreen instead of as a tiled column.
# Leave with Super+Shift+F; the game keeps running on its own column.
src += '''
window-rule {
    match app-id="^steam_app_"
    open-fullscreen true
}
'''
# The desk screens run at 144 Hz (their preferred mode is 60). niri only matches a screen by connector or by
# its full "Make Model Serial" name, and the dock hands out different connectors, so the names live in a local
# file outside the repo: ~/.config/loaf/144hz-outputs, one name per line. Docked means charging, no battery cost.
_hz = os.path.expanduser("~/.config/loaf/144hz-outputs")
for _name in (open(_hz).read().splitlines() if os.path.exists(_hz) else []):
    if _name.strip():
        src += f'''
output "{_name.strip()}" {{
    mode "2560x1440@144.001"
}}
'''
open(sys.argv[2], "w").write(src)
