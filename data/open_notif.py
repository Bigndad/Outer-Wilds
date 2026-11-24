#!/usr/bin/env python3
"""Open the app / window behind a notification.
args: app_id app_name image summary body   (the last two are optional)
Every decision is logged to ~/.cache/ow-shell/open_notif.log so a failing app can be diagnosed.
"""
import glob, json, os, re, subprocess, sys, time

LOG = os.path.expanduser("~/.cache/ow-shell/open_notif.log")


def log(msg):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(time.strftime("%H:%M:%S ") + msg + "\n")
    except OSError:
        pass


def arg(i):
    return (sys.argv[i] if len(sys.argv) > i else "").strip()


def hypr_env():
    env = os.environ.copy()
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        rt = env.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
        socks = sorted(glob.glob(os.path.join(rt, "hypr", "*", ".socket.sock")), key=os.path.getmtime, reverse=True)
        if socks:
            env["HYPRLAND_INSTANCE_SIGNATURE"] = os.path.basename(os.path.dirname(socks[0]))
    return env


app_id, app_name, image, summary, body = arg(1), arg(2), arg(3), arg(4), arg(5)
home = os.path.expanduser("~")
log(f"open app_id={app_id!r} app={app_name!r} summary={summary!r} image={image[:80]!r}")


def done(how):
    log("-> " + how)
    sys.exit(0)


def norm(s):
    return re.sub(r"[^a-z0-9]+", "", s.lower())


# 1. Open real file attachments (e.g. Hyprshot screenshots), but skip any cached icons/avatars/favicons.
SKIP_IMG_PREFIXES = (
    "/tmp/", "/run/", "/var/tmp/", "/usr/share/icons/", "/usr/share/pixmaps/",
    os.path.join(home, ".cache/"),
    os.path.join(home, ".zen/"),
    os.path.join(home, ".mozilla/"),
    os.path.join(home, ".local/share/icons/"),
)
if image.startswith("file://"):
    fpath = image[7:]
    if os.path.isfile(fpath) and not fpath.startswith(SKIP_IMG_PREFIXES):
        subprocess.Popen(["xdg-open", fpath], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        done("xdg-open " + fpath)

# 2. Tokens that identify the app + explicit browser/app aliases
GENERIC = {"browser", "desktop", "app", "the", "google", "web", "org", "com", "gnome", "kde", "client", "stable", "unknown"}
ALIASES = {
    "zen": ["zen", "zenbrowser", "zenalpha", "zenbeta", "zenbin", "appzenbrowserzen"],
    "zenbrowser": ["zen", "zenbrowser", "zenalpha", "zenbeta", "zenbin", "appzenbrowserzen"],
    "firefox": ["firefox", "firefoxesr", "librewolf"],
    "librewolf": ["librewolf", "firefox"],
    "discord": ["discord", "vesktop", "webcord"],
    "vesktop": ["vesktop", "discord"],
}
BROWSER_CLASSES = ("zen", "librewolf", "firefox", "chromium", "brave", "chrome")

full, words = [], []
for raw in (app_id, app_name):
    low = raw.lower().strip()
    if low.endswith(".desktop"):
        low = low[:-8]
    if not low:
        continue
    for t in {low, norm(low), low.split(".")[-1]}:
        if t and t not in full:
            full.append(t)
        for al in ALIASES.get(norm(t), []):
            if al not in full:
                full.append(al)
    for w in re.split(r"[^a-z0-9]+", low):
        if len(w) >= 3 and w not in GENERIC and w not in words:
            words.append(w)
            for al in ALIASES.get(w, []):
                if al not in words:
                    words.append(al)

text_all = f"{summary} {body}".lower()
hints = [w for w in set(re.findall(r"[a-z0-9]{4,}", text_all))]
url_match = re.search(r"https?://[^\s<>\"']+", f"{summary} {body}")
domain_match = re.search(r"\b([a-z0-9-]+\.(?:com|ai|org|net|io|dev|app|gg|in))\b", text_all)
if domain_match:
    dom_root = domain_match.group(1).split(".")[0]
    if len(dom_root) >= 3 and dom_root not in hints:
        hints.append(dom_root)

env = hypr_env()


def get_clients():
    try:
        out = subprocess.check_output(["hyprctl", "-j", "clients"], text=True, stderr=subprocess.DEVNULL, env=env)
        return [c for c in json.loads(out) if c.get("mapped", True)]
    except Exception as e:
        log(f"hyprctl clients failed: {e}")
        return []


def pick_window(clients):
    best, best_key = None, None
    for c in clients:
        cls = norm(str(c.get("class", "")) + " " + str(c.get("initialClass", "")))
        title = str(c.get("title", "") or "").lower()
        ntitle = norm(title)
        score = 0
        for t in full:
            nt = norm(t)
            if nt and (nt == cls or nt in cls):
                score = max(score, 4)
            elif t in title or (nt and nt in ntitle):
                score = max(score, 2)
        for w in words:
            if w in cls:
                score = max(score, 3)
        if score == 0:
            continue
        bonus = sum(1 for h in hints if h in title)
        key = (score + min(bonus, 4) * 2, -int(c.get("focusHistoryID", 99)))
        if best_key is None or key > best_key:
            best, best_key = c, key
    return best


def focus_client(c, reason):
    addr = c.get("address")
    if not addr:
        return False
    res = subprocess.run(
        ["hyprctl", "dispatch", "focuswindow", f"address:{addr}"],
        capture_output=True, text=True, env=env
    )
    if res.returncode != 0:
        log(f"focuswindow failed ({res.returncode}): {res.stderr.strip()}")
        return False
    done(f"{reason} {c.get('class')!r} / {str(c.get('title'))[:50]!r}")


clients = get_clients()
if full or words:
    c = pick_window(clients)
    if c:
        focus_client(c, "focus")
    log("no direct app window match")

# 2b. If notification looks like a web notification (domain/URL or known web app), focus matching browser window
if clients and (url_match or domain_match or any(k in text_all for k in ("gemini", "claude", "chatgpt", "github", "gmail", "youtube", "whatsapp"))):
    best_b, best_bk = None, None
    for c in clients:
        cls = norm(str(c.get("class", "")) + " " + str(c.get("initialClass", "")))
        if not any(b in cls for b in BROWSER_CLASSES):
            continue
        title = str(c.get("title", "") or "").lower()
        bonus = sum(1 for h in hints if h in title)
        key = (bonus, -int(c.get("focusHistoryID", 99)))
        if best_bk is None or key > best_bk:
            best_b, best_bk = c, key
    if best_b:
        focus_client(best_b, "focus-browser")

# 2c. Explicit URL in notification text -> open in default browser
if url_match:
    subprocess.Popen(["xdg-open", url_match.group(0)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    done("xdg-open url " + url_match.group(0))


# 3. Fallback: launch the desktop entry
def try_launch(desktop_id):
    if not desktop_id:
        return False
    return subprocess.run(["gtk-launch", desktop_id], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


if app_id and try_launch(app_id):
    done("gtk-launch " + app_id)

tokens = full + words
for d in (os.path.expanduser("~/.local/share/applications"), "/usr/share/applications"):
    if not os.path.isdir(d):
        continue
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".desktop"):
            continue
        stem = fn[:-8].lower()
        if any(t == stem or (len(t) >= 3 and t in stem) for t in tokens) and try_launch(fn):
            done("gtk-launch " + fn)
        try:
            with open(os.path.join(d, fn), "r", errors="ignore") as f:
                head = f.read(1500).lower()
            if any(f"name={t}" in head or f"startupwmclass={t}" in head for t in tokens) and try_launch(fn):
                done("gtk-launch " + fn + " (Name/StartupWMClass)")
        except OSError:
            pass
log("nothing worked")
