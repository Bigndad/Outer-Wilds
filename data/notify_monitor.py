#!/usr/bin/env python3
import hashlib, json, os, re, struct, subprocess, sys, zlib

CACHE_DIR = os.path.expanduser("~/.cache/ow-shell/notif-imgs")
os.makedirs(CACHE_DIR, exist_ok=True)
IMG_PATH_RE = re.compile(r'(/[^\s"\x27<>]+\.(?:png|jpe?g|webp|bmp))', re.I)

def _unwrap(v):
    while isinstance(v, dict) and "data" in v and "type" in v:
        v = v["data"]
    return v

def _hint(h, key):
    if not h:
        return None
    if isinstance(h, dict):
        return _unwrap(h.get(key))
    if isinstance(h, list):
        for e in h:
            if isinstance(e, list) and len(e) >= 2 and e[0] == key:
                return _unwrap(e[1])
            if isinstance(e, dict) and e.get("key") == key:
                return _unwrap(e.get("value"))
    return None

def _png_chunk(tag, data):
    return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)

def _save_image_data(img_data):
    if not isinstance(img_data, list) or len(img_data) < 7:
        return ""
    w, h, rowstride, has_alpha, bps, channels, raw = img_data[:7]
    raw = _unwrap(raw)
    if not (isinstance(w, int) and isinstance(h, int) and 0 < w <= 2048 and 0 < h <= 2048):
        return ""
    if bps != 8 or channels not in (3, 4) or not isinstance(raw, list):
        return ""
    need = rowstride * (h - 1) + w * channels
    if len(raw) < need:
        return ""
    raw_bytes = bytes(b & 0xFF for b in raw[:need])
    digest = hashlib.sha1(struct.pack("!III", w, h, channels) + raw_bytes).hexdigest()[:16]
    out_path = os.path.join(CACHE_DIR, f"{digest}.png")
    if not os.path.exists(out_path):
        rows = bytearray()
        row_len = w * channels
        for y in range(h):
            start = y * rowstride
            rows.append(0)
            rows.extend(raw_bytes[start:start + row_len])
        ctype = 6 if channels == 4 else 2
        ihdr = struct.pack("!IIBBBBB", w, h, 8, ctype, 0, 0, 0)
        png = b"\x89PNG\r\n\x1a\n" + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", zlib.compress(bytes(rows), 6)) + _png_chunk(b"IEND", b"")
        tmp = out_path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(png)
        os.replace(tmp, out_path)
        try:
            files = sorted((os.path.join(CACHE_DIR, x) for x in os.listdir(CACHE_DIR) if x.endswith(".png")), key=os.path.getmtime)
            for old in files[:-200]:
                os.remove(old)
        except OSError:
            pass
    return "file://" + out_path

def _to_file_url(val):
    if not val:
        return ""
    s = str(val).strip()
    if s.startswith("file://"):
        path = s[7:]
        return s if os.path.isfile(path) else ""
    if s.startswith("/") and os.path.isfile(s):
        return "file://" + s
    return ""

proc = subprocess.Popen(
    ["busctl", "--user", "--json=short",
     "--match=type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
     "monitor"],
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1
)

for line in proc.stdout:
    try:
        m = json.loads(line)
    except Exception:
        continue
    if not isinstance(m, dict) or m.get("member") != "Notify":
        continue
    payload = m.get("payload") or {}
    d = payload.get("data")
    if not isinstance(d, list) or len(d) < 7:
        continue
    hints = d[6]
    if _hint(hints, "x-canonical-private-synchronous") is not None or _hint(hints, "synchronous") is not None:
        continue
    app = str(d[0] or "")
    app_icon = str(d[2] or "")
    summary = str(d[3] or "")
    body = str(d[4] or "")
    if summary == "" and body == "":
        continue

    img = ""
    # 1. Explicit image-path / image_path file
    img = _to_file_url(_hint(hints, "image-path") or _hint(hints, "image_path"))
    # 2. Raw pixel image-data / icon_data (Zen Browser / Firefox / Discord avatars & favicons)
    if not img:
        img = _save_image_data(_hint(hints, "image-data") or _hint(hints, "image_data") or _hint(hints, "icon_data"))
    # 3. File path passed directly as app_icon (e.g. hyprshot / notify-send -i /path/to/shot.png)
    if not img:
        img = _to_file_url(app_icon)
    # 4. File path mentioned in body (fallback for screenshot tools)
    if not img:
        mpath = IMG_PATH_RE.search(body) or IMG_PATH_RE.search(summary)
        if mpath and os.path.isfile(mpath.group(1)):
            img = "file://" + mpath.group(1)

    u = _hint(hints, "urgency")
    out = {
        "app": app if app else "Unknown",
        "appId": str(_hint(hints, "desktop-entry") or ""),
        "appIcon": "" if img else app_icon,
        "summary": summary,
        "body": body,
        "urgency": "critical" if u == 2 else ("low" if u == 0 else "normal"),
        "image": img,
    }
    sys.stdout.write(json.dumps(out) + "\n")
    sys.stdout.flush()
