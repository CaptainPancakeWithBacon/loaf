#!/usr/bin/env python3
"""Loaf's colours for the Claude app: prints hooks/colors.ts, the `colors` of $.theme.set.

The app paints itself from a grey ramp gray-0 (lightest) .. gray-900 (darkest) and colour roles. Loaf pins
its own colours to the stops the app reads (page, cards, text) and fills the stops between in OKLab.
The accent role is the grey ramp itself: monochrome, ink on paper.
    python3 claude-theme/make-colors.py > claude-theme/hooks/colors.ts
"""
import json, sys

STOPS = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600,
         650, 700, 750, 800, 810, 820, 830, 840, 850, 860, 870, 880, 890, 900]

# stop -> colour; the app reads: surfaces 20 10 0 (light) and 900 850 830 800 (dark), text 900/50,
# secondary 600/200, muted 400/400
LIGHT = {0: "#FBF8F1", 10: "#F6F2EA", 20: "#F1EDE4", 250: "#DED8CC", 400: "#6E6A62", 600: "#55524C",
         900: "#151515"}
DARK = {0: "#FFFFFF", 50: "#ECECEA", 200: "#A3A39E", 400: "#93938E", 700: "#2E2E2C", 800: "#2A2A28",
        830: "#222221", 850: "#1C1C1B", 900: "#121212"}
# the accent: filled buttons in ink, text on them in paper (dark mode the other way round)
ACCENT = {"light": ("#151515", "#2E2E2C", "#FBF8F1"), "dark": ("#ECECEA", "#D4D4D1", "#121212")}
ACCENT_STOPS = [50, 100, 250, 300, 400, 450, 600, 700, 800, 850]


def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def gam(c): return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def to_lab(h):
    r, g, b = (lin(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))
    l, m, s = (x ** (1 / 3) for x in (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
                                      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
                                      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def to_hex(lab):
    L, a, b = lab
    l, m, s = ((L + 0.3963377774 * a + 0.2158037573 * b) ** 3, (L - 0.1055613458 * a - 0.0638541728 * b) ** 3,
               (L - 0.0894841775 * a - 1.2914855480 * b) ** 3)
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return "#" + "".join(f"{round(min(1, max(0, gam(c))) * 255):02X}" for c in rgb)


def ramp(pins):
    keys = sorted(pins)
    out = {}
    for s in STOPS:
        lo = max([k for k in keys if k <= s], default=keys[0])
        hi = min([k for k in keys if k >= s], default=keys[-1])
        t = 0 if hi == lo else (s - lo) / (hi - lo)
        a, b = to_lab(pins[lo]), to_lab(pins[hi])
        out[f"gray-{s}"] = to_hex(tuple(x + (y - x) * t for x, y in zip(a, b)))
    return out


def contrast(x, y):
    def lum(h): return sum(w * lin(int(h[i:i + 2], 16) / 255) for w, i in ((0.2126, 1), (0.7152, 3), (0.0722, 5)))
    hi, lo = sorted((lum(x), lum(y)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def mode(name, pins, surfaces, text_stops):
    grays = ramp(pins)
    fill, hover, on = ACCENT[name]
    accent = {f"role-accent-{s}": grays[f"gray-{s}"] for s in ACCENT_STOPS}
    accent.update({"role-accent-fill": fill, "role-accent-fill-hover": hover, "role-accent-on": on})
    for s in text_stops:  # every text colour on every surface: 4.5, the app's own floor
        r = min(contrast(grays[f"gray-{s}"], grays[f"gray-{p}"]) for p in surfaces)
        print(f"{name} gray-{s}: at least {r:.2f}", file=sys.stderr)
        assert r >= 4.5, f"{name} gray-{s} too faint on a surface ({r:.2f})"
    return {**grays, **accent}


print("// Made by make-colors.py, do not edit.\nimport type { ThemeColors } from 'claude-code'\n\nexport const colors: ThemeColors = " + json.dumps({"v": 1, "id": "loaf", "label": "Loaf",
                  "inputs": {"light": mode("light", LIGHT, (20, 10, 0), (900, 600, 400)),
                             "dark": mode("dark", DARK, (900, 850, 830, 800), (50, 200, 400))}}, indent=1))
