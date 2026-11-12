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

sub(r'spawn-at-startup "waybar"',
    'spawn-at-startup "swaybg" "-c" "#DDE2E6"\n'
    'spawn-at-startup "sh" "-c" "mkdir -p ~/.cache/niri-mist && exec qs -p ~/.config/quickshell/mist > ~/.cache/niri-mist/qs.log 2>&1"')
sub(r'gaps 16', 'gaps 14')
sub(r'active-color "#7fc8ff"', 'active-color "#101418"')
sub(r'inactive-color "#505050"', 'inactive-color "#C6CFD6"')
sub(r'(focus-ring \{[^}]*?)(?<![/#])width 4', r'\1width 2')
sub(r'/-window-rule \{(\s*)geometry-corner-radius 12', r'window-rule {\1geometry-corner-radius 18')
sub(r'(\nhotkey-overlay \{)', r'\nprefer-no-csd\n\1')
sub(r'(hotkey-overlay \{)', r'\1\n    skip-at-startup')
sub(r'(\n    Mod\+D [^\n]*\n)', r'\1    Mod+X hotkey-overlay-title="Power menu" { spawn "mist-power"; }\n'
    r'    Mod+P hotkey-overlay-title="Mirror to external screen" { spawn "mist-mirror"; }\n')
sub(r'spawn "alacritty"', 'spawn "ghostty"')
sub(r'alacritty', 'ghostty')
# Lock through logind so hypridle runs hyprlock (fingerprint) for the key, idle and suspend alike.
sub(r'"Lock the Screen: swaylock" \{ spawn "swaylock"; \}', '"Lock the Screen" { spawn "loginctl" "lock-session"; }')
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
open(sys.argv[2], "w").write(src)
