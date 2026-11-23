#!/usr/bin/env python3
"""The README's battery chart (docs/battery-light.svg and -dark.svg): hours on a full battery, in use and idle.
Numbers from measurements/baseline.tsv (2026-11-23, same evening, both desktops with USB autosuspend on and
unused services off, 50% brightness, power saver). Run: tools/battery-chart.py"""
import pathlib

WH = 57
ROWS = [  # group, desktop, watts
    ("In use: browser scrolling, a video, switching tabs", "GNOME", 6.38),
    (None, "Loaf", 5.88),
    ("Idle: nothing open, after settling", "GNOME", 4.43),
    (None, "Loaf", 4.41),
]
MAX_H = 15
THEMES = {
    "light": dict(ink="#151515", mute="#6E6A62", faint="#A09A8F", line="#DED8CC", ground="#F1EDE4"),
    "dark": dict(ink="#ECECEA", mute="#A3A39E", faint="#5A5A57", line="#2E2E2C", ground="#121212"),
}
SANS = "font-family:Inter,Segoe UI,Helvetica,Arial,sans-serif"
MONO = "font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"


def hours(w):
    h = WH / w
    q = round(h * 2) / 2  # to the half hour: closer than that is within the measuring noise
    whole, frac = int(q), "½" if q % 1 else ""
    return f"about {whole}{frac} hours at {w:.1f} W"


def svg(c):
    W, x0, span = 720, 16, 688
    out, y = [], 6
    for group, who, w in ROWS:
        if group:
            y += 18
            out.append(f'<text x="{x0}" y="{y}" style="{SANS};font-size:13px" fill="{c["mute"]}">{group}</text>')
            y += 10
        bw = span * (WH / w) / MAX_H
        loaf = who == "Loaf"
        if loaf:
            out.append(f'<rect x="{x0}" y="{y}" width="{bw:.1f}" height="40" rx="20" fill="{c["ink"]}"/>')
        else:
            out.append(f'<rect x="{x0 + 0.75}" y="{y + 0.75}" width="{bw - 1.5:.1f}" height="38.5" rx="19.25" fill="none" stroke="{c["faint"]}" stroke-width="1.5"/>')
        fg = c["ground"] if loaf else c["mute"]
        out.append(f'<text x="{x0 + 18}" y="{y + 25}" style="{SANS};font-size:15px;font-weight:600" fill="{fg}">{who}</text>')
        out.append(f'<text x="{x0 + bw - 18:.1f}" y="{y + 25}" text-anchor="end" style="{MONO};font-size:13px" fill="{fg}">{hours(w)}</text>')
        y += 48
    y += 6
    out.append(f'<line x1="{x0}" y1="{y}" x2="{x0 + span}" y2="{y}" stroke="{c["line"]}" stroke-width="1.5"/>')
    for h in range(0, MAX_H + 1, 3):
        x = x0 + span * h / MAX_H
        anchor = "start" if h == 0 else "end" if h == MAX_H else "middle"
        out.append(f'<text x="{x:.1f}" y="{y + 20}" text-anchor="{anchor}" style="{MONO};font-size:12px" fill="{c["faint"]}">{h} h</text>')
    y += 44
    out.append(f'<text x="{x0}" y="{y}" style="{SANS};font-size:12px" fill="{c["mute"]}">Framework 13 (Ryzen AI 300), 57 Wh battery, 50% brightness</text>')
    label = ("Hours on a full 57 Wh battery. In use: GNOME " + hours(ROWS[0][2]) + ", Loaf " + hours(ROWS[1][2])
             + ". Idle: GNOME " + hours(ROWS[2][2]) + ", Loaf " + hours(ROWS[3][2]) + ".")
    H = y + 8
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="{label}">\n'
            + "\n".join(out) + "\n</svg>\n")


if __name__ == "__main__":
    docs = pathlib.Path(__file__).resolve().parent.parent / "docs"
    for name, c in THEMES.items():
        (docs / f"battery-{name}.svg").write_text(svg(c))
    print(svg(THEMES["light"]).split('aria-label="')[1].split('"')[0])
