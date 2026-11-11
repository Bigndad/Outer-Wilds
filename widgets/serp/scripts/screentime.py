#!/usr/bin/env python3
"""Screen-time tracker + stats, standing in for `serpantinum-core screentime`.

  screentime.py track [--db-dir DIR] [--live-dir DIR]     count the focused app once a second (Hyprland)
  screentime.py stats DATE [--app CLASS] [--db-dir DIR]   print the statistics JSON the wellbeing panel reads

Data: SQLite file DIR/screentime.db, table usage(date, slot, app, name, seconds); slot = half-hour of the day (0..47).
Only one tracker runs at a time (lock file). With no focused window the time counts as "desktop"."""
import datetime as dt, fcntl, json, os, socket, sqlite3, sys, time

def arg(flag, default=None):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default

state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
db_dir = arg("--db-dir", os.path.join(state, "outerwilds", "focustime"))
run = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
live_dir = arg("--live-dir", os.path.join(run, "outerwilds", "focustime"))
os.makedirs(db_dir, exist_ok=True)

def connect():
    c = sqlite3.connect(os.path.join(db_dir, "screentime.db"), timeout=10)
    c.execute("CREATE TABLE IF NOT EXISTS usage(date TEXT, slot INT, app TEXT, name TEXT, seconds INT, PRIMARY KEY(date, slot, app))")
    return c

def day_rows(c, d, app=None):
    q = "SELECT slot, app, name, seconds FROM usage WHERE date=?" + (" AND app=?" if app else "")
    return c.execute(q, (d, app) if app else (d,)).fetchall()

def day_total(c, d, app=None):
    q = "SELECT COALESCE(SUM(seconds),0) FROM usage WHERE date=?" + (" AND app=?" if app else "")
    return c.execute(q, (d, app) if app else (d,)).fetchone()[0]

def stats(date_s, app=None):
    c = connect()
    d = dt.date.fromisoformat(date_s)
    rows = day_rows(c, date_s, app)
    total = sum(r[3] for r in rows)
    apps = {}
    for _, a, n, s in day_rows(c, date_s):
        e = apps.setdefault(a, [n or a, 0]); e[1] += s
    top = sorted(apps.items(), key=lambda kv: -kv[1][1])[:12]
    day_all = sum(v[1] for v in apps.values())
    app_list = [{"class": k, "name": v[0], "seconds": v[1], "percent": round(v[1] * 100.0 / day_all, 1) if day_all else 0} for k, v in top]
    hourly = [0] * 48
    for slot, _, _, s in rows: hourly[slot] += s

    monday = d - dt.timedelta(days=d.weekday())
    sunday = monday + dt.timedelta(days=6)
    week, heat, wk_apps = [], [], {}
    for i in range(7):
        day = monday + dt.timedelta(days=i); ds = day.isoformat()
        week.append({"date": ds, "day": day.strftime("%a"), "total": day_total(c, ds, app), "is_target": ds == date_s})
        h = [0] * 24
        for slot, a, n, s in day_rows(c, ds, app): h[slot // 2] += s
        heat.append(h)
        for _, a, n, s in day_rows(c, ds):
            e = wk_apps.setdefault(a, [n or a, 0]); e[1] += s
    wk_total_all = sum(v[1] for v in wk_apps.values())
    week_apps = [{"class": k, "name": v[0], "seconds": v[1], "percent": round(v[1] * 100.0 / wk_total_all, 1) if wk_total_all else 0}
                 for k, v in sorted(wk_apps.items(), key=lambda kv: -kv[1][1])[:12]]
    nonzero = [w["total"] for w in week if w["total"] > 0]
    average = int(sum(nonzero) / len(nonzero)) if nonzero else 0

    first = d.replace(day=1)
    last = (first.replace(month=first.month % 12 + 1, day=1) if first.month < 12 else first.replace(year=first.year + 1, month=1, day=1)) - dt.timedelta(days=1)
    month = []
    cur = first - dt.timedelta(days=first.weekday())
    while cur <= last or cur.weekday() != 0:
        if cur.month == first.month and cur.year == first.year:
            ds = cur.isoformat(); month.append({"date": ds, "total": day_total(c, ds, app), "is_target": ds == date_s})
        else:
            month.append({"date": cur.isoformat(), "total": -1, "is_target": False})
        cur += dt.timedelta(days=1)
    known = [{"class": a, "name": n or a} for a, n in c.execute("SELECT app, MAX(name) FROM usage GROUP BY app")]
    fmt = lambda x: x.strftime("%b ") + str(x.day)
    live = ""
    try: live = open(os.path.join(live_dir, "current_app")).read().strip()
    except Exception: pass
    return {"selected_date": date_s, "total": total, "average": average,
            "yesterday": day_total(c, (d - dt.timedelta(days=1)).isoformat(), app),
            "week_range": f"{fmt(monday)} - {fmt(sunday)}", "current": live or "Desktop",
            "apps": app_list if not app else [], "week_apps": week_apps if not app else [], "all_known_apps": known,
            "week_heatmap": heat, "week": week, "month": month, "hourly": hourly}

def hypr_active():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    for base in (os.path.join(run, "hypr", his), os.path.join("/tmp/hypr", his)):
        p = os.path.join(base, ".socket.sock")
        if os.path.exists(p):
            try:
                s = socket.socket(socket.AF_UNIX); s.settimeout(1); s.connect(p); s.send(b"j/activewindow")
                data = b""
                while True:
                    b = s.recv(65536)
                    if not b: break
                    data += b
                s.close()
                w = json.loads(data.decode() or "{}")
                return (w.get("class") or w.get("initialClass") or "").strip()
            except Exception:
                return None
    return None

def track():
    os.makedirs(live_dir, exist_ok=True)
    lock = open(os.path.join(db_dir, "track.lock"), "w")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: return                       # another tracker is already running
    c = connect(); pending = {}; last_flush = last_live = 0.0
    while True:
        t0 = time.time(); now = dt.datetime.now()
        cls = hypr_active()
        if cls is None: cls = ""                  # compositor unreachable -> count as desktop
        app = cls.lower() if cls else "desktop"
        name = cls if cls else "Desktop"
        key = (now.date().isoformat(), now.hour * 2 + (1 if now.minute >= 30 else 0), app, name)
        pending[key] = pending.get(key, 0) + 1
        if t0 - last_flush >= 10:
            for (d, slot, a, n), s in pending.items():
                c.execute("INSERT INTO usage(date,slot,app,name,seconds) VALUES(?,?,?,?,?) ON CONFLICT(date,slot,app) DO UPDATE SET seconds=seconds+excluded.seconds, name=excluded.name", (d, slot, a, n, s))
            c.commit(); pending.clear(); last_flush = t0
        if t0 - last_live >= 2:
            try:
                open(os.path.join(live_dir, "current_app"), "w").write(name)
                tmp = os.path.join(live_dir, "focustime_state.json.tmp")
                open(tmp, "w").write(json.dumps(stats(now.date().isoformat()))); os.replace(tmp, os.path.join(live_dir, "focustime_state.json"))
            except Exception: pass
            last_live = t0
        time.sleep(max(0.0, 1.0 - (time.time() - t0)))

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "track": track()
    elif cmd == "stats": print(json.dumps(stats(sys.argv[2], arg("--app"))))
    else: print(__doc__); sys.exit(2)
