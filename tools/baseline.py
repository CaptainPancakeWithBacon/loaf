#!/usr/bin/env python3
"""Idle power baseline for Loaf (plan section 5). Stdlib only, no sudo.

Measures, in the session it runs in:
  1. as is (Coucou running)
  2. Coucou frozen (SIGSTOP on its whole process tree)
  3. niri only: Coucou AND Quickshell frozen ("niri with no bar")
Frozen processes are always resumed (SIGCONT), brightness and power profile restored.

Usage: tools/baseline.py [seconds_per_case=300] [settle=60]
Run it detached so the Claude window is idle, with the screen kept on:
  systemd-run --user --on-active=20 --unit=loaf-baseline \
      systemd-inhibit --what=idle:sleep:handle-lid-switch --who=loaf --why=baseline \
      ~/Documents/De-Werkplaats/personal/loaf/tools/baseline.py
(in GNOME use gnome-session-inhibit --inhibit idle:suspend instead of systemd-inhibit)
Results are appended to measurements/baseline.tsv.
"""
import glob, os, signal, subprocess, sys, time, datetime, pathlib

BAT = "/sys/class/power_supply/BAT1"
# looked up, not fixed: the numbers change between boots and kernels (card0/amdgpu_bl0 became card1/amdgpu_bl1)
GPU = sorted(glob.glob("/sys/class/drm/card*/device/gpu_busy_percent"))[0]
BL = sorted(os.listdir("/sys/class/backlight"))[0]
BL_DIR = f"/sys/class/backlight/{BL}"
HZ = os.sysconf("SC_CLK_TCK")
OUT = pathlib.Path(__file__).resolve().parent.parent / "measurements" / "baseline.tsv"

GROUPS = {  # comm prefixes (comm is cut at 15 chars)
    "compositor": ("gnome-shell", "niri"),
    "quickshell": ("quickshell", ".quickshell-wra", "qs"),
    "xwayland": ("Xwayland", "xwayland-satel"),
}


def read(p):
    with open(p) as f:
        return f.read().strip()


def procs():
    """pid -> (comm, ppid, cpu ticks)"""
    out = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            s = read(f"/proc/{d}/stat")
        except OSError:
            continue
        comm = s[s.index("(") + 1 : s.rindex(")")]
        f = s[s.rindex(")") + 2 :].split()
        out[int(d)] = (comm, int(f[1]), int(f[11]) + int(f[12]))
    return out


def tree(ps, roots):
    """roots plus all their descendants"""
    keep, changed = set(roots), True
    while changed:
        changed = False
        for pid, (_, ppid, _) in ps.items():
            if ppid in keep and pid not in keep:
                keep.add(pid)
                changed = True
    return keep


def coucou_pids(ps):
    return tree(ps, [p for p, (c, _, _) in ps.items() if c.startswith("coucou")])


def qs_pids(ps):
    return {p for p, (c, _, _) in ps.items() if c.startswith(GROUPS["quickshell"])}


def machine_ticks():
    f = [int(x) for x in read("/proc/stat").splitlines()[0].split()[1:]]
    return sum(f) - f[3] - f[4], sum(f)  # busy, total


def watts():
    try:
        return int(read(f"{BAT}/power_now")) / 1e6
    except OSError:
        return int(read(f"{BAT}/current_now")) * int(read(f"{BAT}/voltage_now")) / 1e12


def set_brightness(raw):
    subprocess.run(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                    "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", BL, str(raw)],
                   check=False)


def measure(label, secs):
    p0, (b0, t0) = procs(), machine_ticks()
    w, g = [], []
    end = time.time() + secs
    while time.time() < end:
        w.append(watts())
        g.append(int(read(GPU)))
        time.sleep(2)
    p1, (b1, t1) = procs(), machine_ticks()
    wall = secs * HZ / 100  # ticks per 1% of one core

    def pct(pids):
        return sum(p1[p][2] - p0[p][2] for p in pids if p in p0 and p in p1) / wall

    row = {
        "date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "session": os.environ.get("XDG_CURRENT_DESKTOP", "?"),
        "case": label,
    }
    for name, pre in GROUPS.items():
        row[name] = pct({p for p, (c, _, _) in p1.items() if c.startswith(pre)})
    row["coucou"] = pct(coucou_pids(p1))
    row["machine_busy"] = 100 * (b1 - b0) / (t1 - t0)
    row["gpu_busy"] = sum(g) / len(g)
    row["watts"] = sum(w) / len(w)
    row["brightness"] = round(100 * int(read(f"{BL_DIR}/brightness")) / int(read(f"{BL_DIR}/max_brightness")))
    row["profile"] = subprocess.run(["powerprofilesctl", "get"], capture_output=True, text=True).stdout.strip()
    return row


def write(row):
    OUT.parent.mkdir(exist_ok=True)
    new = not OUT.exists()
    with open(OUT, "a") as f:
        if new:
            f.write("\t".join(row) + "\n")
        f.write("\t".join(f"{v:.2f}" if isinstance(v, float) else str(v) for v in row.values()) + "\n")
    print(row, flush=True)


def main():
    # systemctl stop sends SIGTERM: turn it into an exception so `finally` resumes Coucou
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    secs = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    settle = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    while read(f"{BAT}/status") != "Discharging":
        print("waiting for the charger to be unplugged", flush=True)
        time.sleep(5)

    old_bl = int(read(f"{BL_DIR}/brightness"))
    old_prof = subprocess.run(["powerprofilesctl", "get"], capture_output=True, text=True).stdout.strip()
    frozen = set()

    def freeze(pids):
        for p in pids:
            try:
                os.kill(p, signal.SIGSTOP)
                frozen.add(p)
            except ProcessLookupError:
                pass

    try:
        set_brightness(int(read(f"{BL_DIR}/max_brightness")) // 2)
        subprocess.run(["powerprofilesctl", "set", "power-saver"], check=False)
        time.sleep(settle)
        write(measure(os.environ.get("BASELINE_LABEL", "as is"), secs))
        if os.environ.get("BASELINE_ONLY_FIRST"):
            return
        ps = procs()
        if coucou_pids(ps):
            freeze(coucou_pids(ps))
            time.sleep(10)
            write(measure("no coucou", secs))
        if qs_pids(ps):  # niri session: also freeze the bar
            freeze(qs_pids(ps))
            time.sleep(10)
            write(measure("no coucou, no bar", secs))
    finally:
        for p in frozen:
            try:
                os.kill(p, signal.SIGCONT)
            except ProcessLookupError:
                pass
        set_brightness(old_bl)
        subprocess.run(["powerprofilesctl", "set", old_prof], check=False)


if __name__ == "__main__":
    main()
