#!/usr/bin/env python3
import json, os, subprocess, sys

app_id = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
app_name = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
image = (sys.argv[3] if len(sys.argv) > 3 else "").strip()
cache_prefix = os.path.expanduser("~/.cache/ow-shell/notif-imgs/")

# 1. Real file attachment (e.g. Hyprshot screenshot) -> open directly
if image.startswith("file://"):
    fpath = image[7:]
    if os.path.isfile(fpath) and not fpath.startswith(cache_prefix):
        subprocess.Popen(["xdg-open", fpath], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        sys.exit(0)

tokens = []
for raw in (app_id, app_name):
    low = raw.lower().strip()
    if low and low not in tokens:
        tokens.append(low)
    if low.endswith(".desktop"):
        stem = low[:-8]
        if stem and stem not in tokens:
            tokens.append(stem)

# 2. Focus an existing Hyprland window
if tokens:
    try:
        out = subprocess.check_output(["hyprctl", "-j", "clients"], text=True, stderr=subprocess.DEVNULL)
        for c in json.loads(out):
            hay = " ".join(str(c.get(k, "") or "") for k in ("class", "initialClass", "title")).lower()
            if any(t in hay for t in tokens):
                addr = c.get("address")
                if addr:
                    subprocess.Popen(["hyprctl", "dispatch", "focuswindow", f"address:{addr}"],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    sys.exit(0)
    except Exception:
        pass

# 3. Fallback: launch via gtk-launch
def try_launch(desktop_id):
    if not desktop_id:
        return False
    return subprocess.run(["gtk-launch", desktop_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

if app_id and try_launch(app_id):
    sys.exit(0)

for d in (os.path.expanduser("~/.local/share/applications"), "/usr/share/applications"):
    if not os.path.isdir(d):
        continue
    for fn in os.listdir(d):
        if not fn.endswith(".desktop"):
            continue
        stem = fn[:-8].lower()
        if any(t == stem or t in stem for t in tokens) and try_launch(fn):
            sys.exit(0)
        try:
            with open(os.path.join(d, fn), "r", errors="ignore") as f:
                head = f.read(1500).lower()
            if any(f"name={t}" in head or f"startupwmclass={t}" in head for t in tokens) and try_launch(fn):
                sys.exit(0)
        except OSError:
            pass
