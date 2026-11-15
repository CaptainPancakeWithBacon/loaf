#!/usr/bin/env python3
"""Loaf's niri config = niri's own default config with a few exact substitutions.
Fails loudly if a substitution no longer matches (e.g. after a niri update).
Usage: make-config.py DEFAULT_CONFIG OUT
Personal settings (screens, app rules, extra autostarts) go in ~/.config/loaf/niri.kdl, which the
generated config includes if it exists; this file stays the same for everyone."""
import re, sys
src = open(sys.argv[1]).read()

def sub(pattern, repl, flags=0):
    global src
    src, n = re.subn(pattern, repl, src, count=1, flags=flags)
    if n != 1:
        sys.exit(f"no match for: {pattern}")

# The shell is found by name (qs -c loaf): ~/.config/quickshell/loaf if the user has one, else /etc/xdg/quickshell/loaf.
QS = "qs ipc -c loaf call"
# Loaf draws its own ground (follows dark style), so no swaybg.
sub(r'spawn-at-startup "waybar"',
    'spawn-at-startup "sh" "-c" "mkdir -p ~/.cache/loaf && exec qs -c loaf > ~/.cache/loaf/qs.log 2>&1"\n'
    # GNOME Settings' Bluetooth page (pairing new devices) asks gsd-rfkill, which only GNOME starts. Costs ~0 CPU.
    'spawn-at-startup "/usr/libexec/gsd-rfkill"')
sub(r'gaps 16', 'gaps 14')
sub(r'active-color "#7fc8ff"', 'active-color "#151515"')
sub(r'inactive-color "#505050"', 'inactive-color "#DED8CC"')
sub(r'(focus-ring \{[^}]*?)(?<![/#])width 4', r'\1width 2')
sub(r'/-window-rule \{(\s*)geometry-corner-radius 12', r'window-rule {\1geometry-corner-radius 18')
sub(r'(\nhotkey-overlay \{)', r'\nprefer-no-csd\n\1')
sub(r'(hotkey-overlay \{)', r'\1\n    skip-at-startup')
sub(r'(\n    Mod\+D [^\n]*\n)', r'\1    Mod+X hotkey-overlay-title="Power menu" { spawn "loaf-power"; }\n'
    r'    Mod+P hotkey-overlay-title="Mirror to external screen" { spawn "loaf-mirror"; }\n'
    # people reach for the GNOME/Windows shortcut; Print, Ctrl+Print and Alt+Print stay as niri ships them.
    r'    Mod+Shift+S hotkey-overlay-title="Screenshot: select an area" { screenshot; }\n')
# the terminal is whatever loaf-terminal finds ($TERMINAL first)
sub(r'spawn "alacritty"', 'spawn "loaf-terminal"')
sub(r'alacritty', 'loaf-terminal')
# Super+D opens Loaf's launcher; fuzzel stays on Super+Shift+D as a fallback.
sub(r'Mod\+D hotkey-overlay-title="Run an Application: fuzzel" \{ spawn "fuzzel"; \}',
    f'Mod+D hotkey-overlay-title="Search apps, files and settings" {{ spawn "sh" "-c" "{QS} launcher toggle"; }}\n'
    '    Mod+Shift+D hotkey-overlay-title="Run an Application: fuzzel (fallback)" { spawn "fuzzel"; }')
# Lock through logind so hypridle runs Loaf's lock (finger or password) for the key, idle and suspend alike.
sub(r'"Lock the Screen: swaylock" \{ spawn "swaylock"; \}', '"Lock the Screen" { spawn "loginctl" "lock-session"; }')
# Volume keys also show Loaf's OSD. Brightness goes through logind (brightnessctl needs root or the video group).
osd = f'; {QS} osd volume'
sub(r'(wpctl set-volume @DEFAULT_AUDIO_SINK@ 0\.1\+ -l 1\.0)"', r'\1' + osd + '"')
sub(r'(wpctl set-volume @DEFAULT_AUDIO_SINK@ 0\.1-)"', r'\1' + osd + '"')
sub(r'(wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle)"', r'\1' + osd + '"')
sub(r'spawn "brightnessctl" "--class=backlight" "set" "\+10%"', 'spawn "loaf-brightness" "+10"')
sub(r'spawn "brightnessctl" "--class=backlight" "set" "10%-"', 'spawn "loaf-brightness" "-10"')
# Games started through Proton/umu (Lutris, Steam) open fullscreen instead of as a tiled column.
# Leave with Super+Shift+F; the game keeps running on its own column.
src += '''
window-rule {
    match app-id="^steam_app_"
    open-fullscreen true
}
'''
# Personal settings last, so they can override anything above: screens and their modes, rules for your own
# apps, extra autostarts. Relative to this file (~/.config/niri/). Skipped when it does not exist.
src += '''
include optional=true "../loaf/niri.kdl"
'''
open(sys.argv[2], "w").write(src)
