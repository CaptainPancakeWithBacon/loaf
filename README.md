# Loaf

A desktop that naps. Loaf is a quiet shell for [niri](https://github.com/YaLTeR/niri) on a laptop:
nothing moves when you are not looking, so the battery goes to your work instead of the desktop.
It is a second login session next to GNOME; GNOME stays one logout away.

Measured on a Framework 13 (Ryzen AI 300), idle, same conditions: GNOME 6.3 W, Loaf about 5.0 to 5.5 W.
The numbers and the method are in `measurements/` and `tools/baseline.py`.

## What is in it

- **Bar** (`loaf/Bar.qml`): the cat (opens the launcher), workspace dots, date and time, Wi-Fi, watts and battery.
  The clock ticks once a minute; everything else follows events, nothing polls.
- **Launcher** (Super+D): apps, settings and files in one search; focuses an app that is already open.
- **Quick settings** (click the right side of the bar): battery with time left, power menu, Wi-Fi and
  Bluetooth lists, power saver, dark style, do not disturb, screen mirroring, volume and brightness.
- **Lock screen** (`loaf/Lock.qml`): finger or password, on every screen. The fingerprint reader recovers
  by itself after a suspend (see `session/50-loaf-fprintd.rules.in`).
- **Volume and brightness** on the F-keys with a small on-screen card; brightness goes through logind,
  no root needed.
- **Light and dark** follow the system setting, and GTK3 apps and the login screen follow along.
- **Notifications** by mako in Loaf's colours; **boot screen** and **login screen** in Loaf's style.

## Install

User-level, nothing here touches the GNOME session:

```sh
./install.sh
```

The parts that need root (login entry, login screen theme, boot screen, the fingerprint rule) are one
script, with an undo:

```sh
sudo boot/install-system.sh
sudo boot/install-system.sh undo
```

Build first (sources go in `src/`, ignored): niri v26.04 and xwayland-satellite v0.8.3 with
`cargo build --release`, Quickshell 0.3.2 with
`cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF`.
Clone niri with the git-lfs filter disabled (its LFS files are screenshots).

## Keys

| Key | Does |
|---|---|
| Super+D | Launcher |
| Super+Shift+D | fuzzel, the fallback launcher |
| Super+X | Power menu |
| Super+P | Mirror to an external screen |
| Super+Shift+S | Screenshot of an area |
| Super+Alt+L | Lock |
| Super+T | Terminal (Ghostty) |
| Super+Shift+E | Log out |

## Layout

- `loaf/`: the Quickshell shell (bar, launcher, quick settings, lock, on-screen card, theme, logo files)
- `niri/make-config.py`: builds `~/.config/niri/config.kdl` from niri's own default config with a few exact
  substitutions; it fails loudly when one no longer matches
- `session/`: login wrapper (niri runs as `niri.service`, needed for the portals), helper scripts, units
- `boot/`: login entry, login screen theme (`boot/gdm/`), boot screen (`boot/plymouth/`), `install-system.sh`
- `mako/`, `fuzzel/`, `hypr/`: notifications, fallback launcher, idle and fallback lock
- `tests/`, `tools/`, `measurements/`: a small test, the power baseline tool and its results

Quickshell logs to `~/.cache/loaf/qs.log`.

## Credits

Loaf runs on [niri](https://github.com/YaLTeR/niri) (GPL-3.0) and
[Quickshell](https://quickshell.org) (LGPL-3.0). Loaf's own code is MIT, see `LICENSE`.
