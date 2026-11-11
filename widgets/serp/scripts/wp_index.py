#!/usr/bin/env python3
"""Wallpaper indexer standing in for `serpantinum-core wallpaper index`.
Usage: wp_index.py SRC_DIR CACHE_DIR RUN_DIR
Prints (and caches as CACHE_DIR/current_index.json) {"srcDir":..., "items":[{fileName,filePath,fileUrl,
posterPath,posterUrl,isVideo,hex,bucket}]}. Colours come from Pillow when installed (python-pillow); otherwise
every image is "Monochrome". Video posters need ffmpeg."""
import colorsys, json, os, shutil, subprocess, sys, urllib.parse, warnings
warnings.filterwarnings("ignore")

src, cache = sys.argv[1], sys.argv[2]
IMG = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp")
VID = (".mp4", ".mkv", ".mov", ".webm")
try:
    from PIL import Image
except Exception:
    Image = None
os.makedirs(cache, exist_ok=True)
posters = os.path.join(cache, "posters"); os.makedirs(posters, exist_ok=True)
memo_path = os.path.join(cache, "color_memo.json")
try: memo = json.load(open(memo_path))
except Exception: memo = {}

def bucket_of(path):
    """average colour of a 48px thumbnail, weighted toward saturated pixels -> (hex, bucket)"""
    if Image is None: return "#808080", "Monochrome"
    try:
        im = Image.open(path).convert("RGB"); im.thumbnail((48, 48))
        px = list(im.getdata())
    except Exception:
        return "#808080", "Monochrome"
    if not px: return "#808080", "Monochrome"
    r = sum(p[0] for p in px) / len(px); g = sum(p[1] for p in px) / len(px); b = sum(p[2] for p in px) / len(px)
    sx = sy = sw = 0.0
    import math
    for p in px:
        h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
        w = s * v
        sx += math.cos(h * 2 * math.pi) * w; sy += math.sin(h * 2 * math.pi) * w; sw += w
    hexv = "#%02x%02x%02x" % (int(r), int(g), int(b))
    if sw / len(px) < 0.06: return hexv, "Monochrome"
    hue = (math.atan2(sy, sx) / (2 * math.pi)) % 1.0 * 360
    if hue < 15 or hue >= 345: bk = "Red"
    elif hue < 45: bk = "Orange"
    elif hue < 70: bk = "Yellow"
    elif hue < 165: bk = "Green"
    elif hue < 255: bk = "Blue"
    elif hue < 300: bk = "Purple"
    else: bk = "Pink"
    return hexv, bk

items = []
try: names = sorted(os.listdir(src))
except Exception: names = []
for name in names:
    low = name.lower(); path = os.path.join(src, name)
    if not os.path.isfile(path): continue
    isvid = low.endswith(VID)
    if not (isvid or low.endswith(IMG)): continue
    st = os.stat(path); key = f"{name}:{st.st_size}:{int(st.st_mtime)}"
    it = {"fileName": name, "filePath": path, "fileUrl": "file://" + urllib.parse.quote(path),
          "posterPath": "", "posterUrl": "", "isVideo": isvid}
    if isvid:
        pp = os.path.join(posters, name + ".jpg")
        if not os.path.exists(pp) and shutil.which("ffmpeg"):
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", path, "-frames:v", "1", "-vf", "scale=640:-1", pp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(pp):
            it["posterPath"] = pp; it["posterUrl"] = "file://" + urllib.parse.quote(pp)
            if key not in memo: memo[key] = list(bucket_of(pp))
        it["hex"], it["bucket"] = (memo.get(key) or ["#808080", "Video"])[0], "Video"
    else:
        if key not in memo: memo[key] = list(bucket_of(path))
        it["hex"], it["bucket"] = memo[key]
    items.append(it)

json.dump(memo, open(memo_path, "w"))
out = json.dumps({"srcDir": src, "items": items})
open(os.path.join(cache, "current_index.json"), "w").write(out)
print(out)
