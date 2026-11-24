#!/usr/bin/env python3
"""Live data for the 3D Bubble Monitor: system metrics, per-process stats, and Hyprland open apps."""
import glob
import json
import os
import re
import socket
import subprocess
import sys
import time

import psutil

TOP_N = 64


def cpu_model():
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "CPU"


def read_temp(temps):
    for chip in ("k10temp", "coretemp", "zenpower", "cpu_thermal", "acpitz"):
        for t in temps.get(chip, []):
            if t.current:
                return float(t.current)
    for entries in temps.values():
        for t in entries:
            if t.current:
                return float(t.current)
    return None


SENSOR_NAMES = {"coretemp": "", "k10temp": "", "nvme": "SSD", "acpitz": "Board", "iwlwifi_1": "Wi-Fi"}


def read_sensors(temps):
    out = []
    for chip, entries in temps.items():
        for t in entries:
            if not t.current:
                continue
            label = t.label or ""
            if chip in ("coretemp", "k10temp"):
                label = "Package" if label.startswith("Package") or label in ("Tctl", "Tdie") else label
            elif chip in SENSOR_NAMES:
                label = SENSOR_NAMES[chip]
            else:
                label = (chip + " " + label).strip()
            out.append({"label": label or chip, "c": float(t.current)})
    return out


def proc_detail(p):
    out = {"threads": None, "started": None, "cpuSec": None, "readMB": None, "writeMB": None}
    try:
        with p.oneshot():
            out["threads"] = p.num_threads()
            out["started"] = int(p.create_time())
            ct = p.cpu_times()
            out["cpuSec"] = ct.user + ct.system
            try:
                io = p.io_counters()
                out["readMB"], out["writeMB"] = io.read_bytes / 1048576, io.write_bytes / 1048576
            except (psutil.AccessDenied, AttributeError):
                pass
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass
    return out


def _hypr_env():
    env = os.environ.copy()
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        rt = env.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
        socks = sorted(glob.glob(os.path.join(rt, "hypr", "*", ".socket.sock")), key=os.path.getmtime, reverse=True)
        if socks:
            env["HYPRLAND_INSTANCE_SIGNATURE"] = os.path.basename(os.path.dirname(socks[0]))
    return env


def open_windows():
    """Windows open in Hyprland: [{"pid", "cls", "title", "ws"}]"""
    try:
        out = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True, text=True, timeout=2, env=_hypr_env()
        ).stdout
        clients = json.loads(out)
        res = []
        for c in clients:
            if not c.get("mapped", True):
                continue
            cls = (c.get("class") or c.get("initialClass") or "").strip()
            if not cls:
                continue
            res.append({
                "pid": int(c.get("pid") or -1),
                "cls": cls,
                "title": c.get("title", ""),
                "ws": (c.get("workspace") or {}).get("name", ""),
            })
        return res
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


CLASS_ALIASES = {
    "zen": ["zen", "zen-bin", "zen-alpha", "isolated web co", "webextensions", "rdd process", "utility process", "privileged cont"],
    "firefox": ["firefox", "firefox-bin", "isolated web co", "webextensions", "rdd process"],
    "brave-browser": ["brave", "chrome_crashpad"],
    "chromium": ["chromium", "chrome"],
    "google-chrome": ["chrome", "google-chrome"],
    "spotify": ["spotify"],
    "discord": ["discord", "discordptb", "discordcanary", "vesktop", "electron"],
    "vesktop": ["vesktop", "electron"],
    "code": ["code", "code-oss", "electron"],
    "kitty": ["kitty"],
    "steam": ["steam", "steamwebhelper"],
}


def app_name(cls):
    last = cls.split(".")[-1] if "." in cls else cls
    low = last.lower()
    if low in ("zen", "zen-alpha", "zen-bin"):
        return "Zen Browser"
    return " ".join(w[:1].upper() + w[1:] for w in last.replace("_", "-").split("-") if w) or cls


def _tokens_for_class(cls):
    low = cls.lower().strip()
    last = low.split(".")[-1] if "." in low else low
    toks = set(CLASS_ALIASES.get(last, []))
    for part in re.split(r"[-_.\s]+", last):
        if len(part) >= 3 and part not in ("org", "com", "net", "app", "bin", "desktop", "browser"):
            toks.add(part)
    return toks


def group_apps(rows_by_pid, children):
    """Group open Hyprland windows + descendant & class-matched processes into App bubbles."""
    apps = {}
    for w in open_windows():
        a = apps.setdefault(w["cls"], {
            "cls": w["cls"],
            "name": app_name(w["cls"]),
            "windows": 0,
            "ws": [],
            "titles": [],
            "pids": set(),
            "tokens": _tokens_for_class(w["cls"]),
        })
        a["windows"] += 1
        if w["ws"] and w["ws"] not in a["ws"]:
            a["ws"].append(w["ws"])
        if w["title"]:
            a["titles"].append(w["title"])
        if w["pid"] > 0:
            stack = [w["pid"]]
            while stack:
                pid = stack.pop()
                if pid in a["pids"]:
                    continue
                a["pids"].add(pid)
                stack.extend(children.get(pid, ()))

    # Secondary match for reparented workers (Electron, Gecko/Zen, Flatpak, wrapper scripts)
    all_rows = list(rows_by_pid.values())
    for a in apps.values():
        toks = a["tokens"]
        if not toks:
            continue
        for r in all_rows:
            pid = r["pid"]
            if pid in a["pids"]:
                continue
            nm = r["name"].lower()
            cmd = r["cmd"].lower()
            if any(t in nm or (len(t) >= 4 and t in cmd) for t in toks):
                a["pids"].add(pid)
                stack = list(children.get(pid, ()))
                while stack:
                    cpid = stack.pop()
                    if cpid not in a["pids"]:
                        a["pids"].add(cpid)
                        stack.extend(children.get(cpid, ()))

    out = []
    for a in apps.values():
        procs = [rows_by_pid[p] for p in a["pids"] if p in rows_by_pid]
        procs.sort(key=lambda r: (r["cpu"], r["memMB"]), reverse=True)
        out.append({
            "cls": a["cls"],
            "name": a["name"],
            "windows": a["windows"],
            "ws": a["ws"],
            "titles": a["titles"][:4],
            "pids": [r["pid"] for r in procs],
            "cpu": min(100.0, sum(r["cpu"] for r in procs)),
            "memMB": sum(r["memMB"] for r in procs),
            "procCount": len(procs),
            "procs": [{"pid": r["pid"], "name": r["name"], "cpu": r["cpu"], "memMB": r["memMB"]} for r in procs[:10]],
        })
    out.sort(key=lambda a: (a["cpu"], a["memMB"]), reverse=True)
    return out


def disks():
    out, seen = [], set()
    for part in psutil.disk_partitions(all=False):
        if part.device in seen or part.fstype in ("squashfs", "tmpfs") or part.mountpoint.startswith(("/boot", "/snap")):
            continue
        seen.add(part.device)
        try:
            u = psutil.disk_usage(part.mountpoint)
        except OSError:
            continue
        out.append({"mount": part.mountpoint, "usedGB": u.used / 1024 ** 3, "totalGB": u.total / 1024 ** 3})
    return out


class Sampler:
    def __init__(self):
        self.procs = {}
        self.model = cpu_model()
        self.boot = psutil.boot_time()
        self.last_net = psutil.net_io_counters()
        self.last_disk = psutil.disk_io_counters()
        self.last_t = time.time()
        psutil.cpu_percent(percpu=True)

    @staticmethod
    def busiest_iface():
        try:
            per = psutil.net_io_counters(pernic=True)
            return max((n for n in per if n != "lo"), key=lambda n: per[n].bytes_recv + per[n].bytes_sent)
        except ValueError:
            return "net"

    def collect(self):
        now = time.time()
        dt = max(0.001, now - self.last_t)
        cores = psutil.cpu_percent(percpu=True)
        vm, sw = psutil.virtual_memory(), psutil.swap_memory()
        net = psutil.net_io_counters()
        up = (net.bytes_sent - self.last_net.bytes_sent) / dt / 1e6
        down = (net.bytes_recv - self.last_net.bytes_recv) / dt / 1e6
        disk = psutil.disk_io_counters()
        d_read = (disk.read_bytes - self.last_disk.read_bytes) / dt / 1e6 if disk and self.last_disk else 0
        d_write = (disk.write_bytes - self.last_disk.write_bytes) / dt / 1e6 if disk and self.last_disk else 0
        self.last_net, self.last_disk, self.last_t = net, disk, now
        freq = psutil.cpu_freq()
        try:
            load = list(os.getloadavg())
        except OSError:
            load = [0, 0, 0]

        rows, alive, children = [], set(), {}
        for p in psutil.process_iter(["pid", "ppid", "name", "username", "cmdline", "memory_info", "status"]):
            pid = p.info["pid"]
            alive.add(pid)
            children.setdefault(p.info["ppid"], []).append(pid)
            proc = self.procs.setdefault(pid, p)
            try:
                cpu = proc.cpu_percent(None)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
            mem = p.info["memory_info"]
            rows.append({
                "pid": pid,
                "name": p.info["name"] or "?",
                "cmd": " ".join(p.info["cmdline"] or []) or p.info["name"] or "",
                "user": (p.info["username"] or "?").split("\\")[-1],
                "cpu": min(100.0, cpu),
                "memMB": (mem.rss / 1048576) if mem else 0,
                "state": "T" if p.info["status"] == psutil.STATUS_STOPPED else ("R" if cpu > 5 else "S"),
            })
        self.procs = {k: v for k, v in self.procs.items() if k in alive}
        rows.sort(key=lambda r: (r["cpu"], r["memMB"]), reverse=True)
        rows_by_pid = {r["pid"]: r for r in rows}
        apps = group_apps(rows_by_pid, children)
        top = rows[:TOP_N]
        for r in top:
            r.update(proc_detail(self.procs[r["pid"]]))

        gb = 1024 ** 3
        apps_gb, free_gb = (vm.total - vm.available) / gb, vm.free / gb
        cache = max(0.0, vm.total / gb - apps_gb - free_gb)
        try:
            bat = psutil.sensors_battery()
        except (AttributeError, OSError):
            bat = None
        try:
            temps = psutil.sensors_temperatures()
        except (AttributeError, OSError):
            temps = {}
        temp = read_temp(temps)
        return {
            "t": int(now * 1000),
            "host": socket.gethostname(),
            "uptimeSec": int(now - self.boot),
            "cpu": {"model": self.model, "threads": len(cores),
                    "freqGHz": (freq.current / 1000) if freq else 0, "load": load, "cores": cores,
                    "procCount": len(alive)},
            "mem": {"totalGB": round(vm.total / gb), "appsGB": apps_gb, "cacheGB": cache, "freeGB": free_gb,
                    "swapGB": sw.used / gb, "swapTotalGB": sw.total / gb, "totalExactGB": vm.total / gb},
            "tempC": temp if temp is not None else 30 + sum(cores) / max(1, len(cores)) * 0.5,
            "sensors": read_sensors(temps),
            "battery": {"pct": min(100.0, bat.percent), "plugged": bool(bat.power_plugged)} if bat else None,
            "net": {"iface": self.busiest_iface(), "upMBs": max(0.0, up), "downMBs": max(0.0, down),
                    "sentGB": net.bytes_sent / gb, "recvGB": net.bytes_recv / gb},
            "disk": {"readMBs": max(0.0, d_read), "writeMBs": max(0.0, d_write),
                     "readGB": disk.read_bytes / gb if disk else 0, "writtenGB": disk.write_bytes / gb if disk else 0,
                     "drives": disks()},
            "procs": top,
            "apps": apps,
        }


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    sampler = Sampler()
    time.sleep(min(interval, 0.5))
    while True:
        try:
            print(json.dumps(sampler.collect()), flush=True)
        except BrokenPipeError:
            return
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)
        time.sleep(interval)


if __name__ == "__main__":
    main()
