#!/usr/bin/env python3
# Busiest processes, one "cpu% name" per line (used by AnserinBubbleCard.qml). Needs python-psutil.
import sys, time
try:
    import psutil
except ImportError:
    print("!psutil")
    sys.exit(0)
procs = []
for p in psutil.process_iter(["name"]):
    try:
        p.cpu_percent(None)
        procs.append(p)
    except Exception:
        pass
time.sleep(0.6)
out = []
for p in procs:
    try:
        out.append((p.cpu_percent(None), p.info["name"] or "?"))
    except Exception:
        pass
out.sort(reverse=True)
for c, n in out[:4]:
    print("%.1f %s" % (min(c, 999.0), n))
