#!/usr/bin/env python3
"""Wallpaper indexer standing in for `serpantinum-core wallpaper index`."""
import colorsys, hashlib, json, math, os, shutil, subprocess, sys, urllib.parse, warnings
warnings.filterwarnings("ignore")

src, cache = sys.argv[1], sys.argv[2]
IMG = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp")
VID = (".mp4", ".mkv", ".mov", ".webm")
try:
    from PIL import Image
except Exception:
    Image = None

os.makedirs(cache, exist_ok=True)
posters = os.path.join(cache, "posters")
os.makedirs(posters, exist_ok=True)
memo_path = os.path.join(cache, "color_memo.json")
try:
    memo = json.load(open(memo_path))
except Exception:
    memo = {}

def bucket_of(path):
    if Image is None:
        return "#808080", "Monochrome"
    try:
        im = Image.open(path).convert("RGB")
        im.thumbnail((48, 48))
        px = list(im.getdata())
    except Exception:
        return "#808080", "Monochrome"
    if not px:
        return "#808080", "Monochrome"
    r = sum(p[0] for p in px) / len(px)
    g = sum(p[1] for p in px) / len(px)
    b = sum(p[2] for p in px) / len(px)
    sx = sy = sw = 0.0
    for p in px:
        h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
        w = s * v
        sx += math.cos(h * 2 * math.pi) * w
        sy += math.sin(h * 2 * math.pi) * w
        sw += w
    hexv = "#%02x%02x%02x" % (int(r), int(g), int(b))
    if sw / len(px) < 0.06:
        return hexv, "Monochrome"
    hue = (math.atan2(sy, sx) / (2 * math.pi)) % 1.0 * 360
    if hue < 15 or hue >= 345: bk = "Red"
    elif hue < 45: bk = "Orange"
    elif hue < 70: bk = "Yellow"
    elif hue < 165: bk = "Green"
    elif hue < 255: bk = "Blue"
    elif hue < 300: bk = "Purple"
    else: bk = "Pink"
    return hexv, bk

def ensure_poster(path, name, create=True):
    tag = hashlib.md5(path.encode("utf-8", "ignore")).hexdigest()[:8]
    pp = os.path.join(posters, f"{tag}_{name}.jpg")
    legacy = os.path.join(posters, name + ".jpg")
    if os.path.exists(pp):
        return pp
    if os.path.exists(legacy) and os.path.dirname(path) == src:
        return legacy
    if create and shutil.which("ffmpeg"):
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", path, "-frames:v", "1", "-vf", "scale=640:-1", pp],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    return pp if os.path.exists(pp) else ""

def scan_subdir(folder_path):
    count = 0
    cover_path = ""
    cover_url = ""
    sub_entries = []
    for root_dir, dirs, files in os.walk(folder_path):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for fn in sorted(files):
            if fn.startswith("."):
                continue
            low = fn.lower()
            isvid = low.endswith(VID)
            if not (isvid or low.endswith(IMG)):
                continue
            fp = os.path.join(root_dir, fn)
            count += 1
            pp = ensure_poster(fp, fn, create=(isvid and not cover_url)) if isvid else ""
            pu = ("file://" + urllib.parse.quote(pp)) if pp else ""
            if not cover_url:
                if isvid and pu:
                    cover_path, cover_url = pp, pu
                elif not isvid:
                    cover_path, cover_url = fp, "file://" + urllib.parse.quote(fp)
            sub_entries.append({
                "fileName": fn, "filePath": fp, "fileUrl": "file://" + urllib.parse.quote(fp),
                "posterPath": pp, "posterUrl": pu, "isVideo": isvid,
                "hex": "#808080", "bucket": "Video" if isvid else "Monochrome"
            })
    return count, cover_path, cover_url, sub_entries

items, folders, sub_lookup = [], [], []
try:
    names = sorted(os.listdir(src))
except Exception:
    names = []

for name in names:
    if name.startswith("."):
        continue
    path = os.path.join(src, name)
    if os.path.isdir(path):
        cnt, cpath, curl, subs = scan_subdir(path)
        folders.append({"name": name, "path": path, "itemCount": cnt, "coverPath": cpath, "coverUrl": curl})
        sub_lookup.extend(subs)
        continue
    if not os.path.isfile(path):
        continue
    low = name.lower()
    isvid = low.endswith(VID)
    if not (isvid or low.endswith(IMG)):
        continue
    st = os.stat(path)
    key = f"{path}:{st.st_size}:{int(st.st_mtime)}"
    it = {"fileName": name, "filePath": path, "fileUrl": "file://" + urllib.parse.quote(path),
          "posterPath": "", "posterUrl": "", "isVideo": isvid}
    if isvid:
        pp = ensure_poster(path, name, create=True)
        if pp:
            it["posterPath"], it["posterUrl"] = pp, "file://" + urllib.parse.quote(pp)
            if key not in memo:
                memo[key] = list(bucket_of(pp))
        it["hex"], it["bucket"] = (memo.get(key) or ["#808080", "Video"])[0], "Video"
    else:
        if key not in memo:
            memo[key] = list(bucket_of(path))
        it["hex"], it["bucket"] = memo[key]
    items.append(it)

json.dump(memo, open(memo_path, "w"))
out = json.dumps({"srcDir": src, "folders": folders, "items": items, "subLookup": sub_lookup})
open(os.path.join(cache, "current_index.json"), "w").write(out)
print(out)
