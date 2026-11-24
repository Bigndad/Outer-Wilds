#!/usr/bin/env python3
import argparse, json, os, re, time, urllib.parse, urllib.request

UA = {"User-Agent": "outerwilds-shell/1.0"}
GEO_CACHE = "/tmp/ow_weather_geo.json"

def get_json(url, timeout=6):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))

def auto_locate():
    try:
        if os.path.exists(GEO_CACHE) and (time.time() - os.path.getmtime(GEO_CACHE)) < 1800:
            c = json.load(open(GEO_CACHE))
            if "lat" in c and "lon" in c:
                return float(c["lat"]), float(c["lon"]), str(c.get("city", ""))
    except Exception:
        pass

    providers = [
        ("https://get.geojs.io/v1/ip/geo.json",
         lambda j: (float(j["latitude"]), float(j["longitude"]), j.get("city", ""))),
        ("http://ip-api.com/json/?fields=status,city,lat,lon",
         lambda j: (float(j["lat"]), float(j["lon"]), j.get("city", "")) if j.get("status") == "success" else None),
        ("https://ipwho.is/",
         lambda j: (float(j["latitude"]), float(j["longitude"]), j.get("city", "")) if j.get("success") else None),
        ("https://ipinfo.io/json",
         lambda j: (float(j["loc"].split(",")[0]), float(j["loc"].split(",")[1]), j.get("city", "")) if "," in str(j.get("loc", "")) else None),
    ]
    for url, parse in providers:
        try:
            res = parse(get_json(url, timeout=5))
            if res and res[0] == res[0] and res[1] == res[1]:
                lat, lon, city = res
                try:
                    json.dump({"lat": lat, "lon": lon, "city": city}, open(GEO_CACHE, "w"))
                except Exception:
                    pass
                return lat, lon, str(city or "")
        except Exception:
            continue
    return None

def resolve_manual(query):
    q = query.strip()
    m = re.match(r"^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$", q)
    if m:
        return float(m.group(1)), float(m.group(2)), f"{float(m.group(1)):.2f}, {float(m.group(2)):.2f}"
    url = "https://geocoding-api.open-meteo.com/v1/search?name=" + urllib.parse.quote(q) + "&count=1&language=en&format=json"
    j = get_json(url, timeout=6)
    results = j.get("results") or []
    if not results:
        return None
    r0 = results[0]
    return float(r0["latitude"]), float(r0["longitude"]), str(r0.get("name") or q)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--auto", action="store_true")
    ap.add_argument("--query", default="")
    ap.add_argument("--lat", type=float, default=None)
    ap.add_argument("--lon", type=float, default=None)
    args = ap.parse_args()

    lat = lon = None
    city = ""
    if args.query.strip():
        try:
            res = resolve_manual(args.query)
        except Exception:
            res = None
        if not res:
            print(json.dumps({"ok": False, "error": "LOCATION NOT FOUND"}))
            return
        lat, lon, city = res
    elif args.auto:
        res = auto_locate()
        if res:
            lat, lon, city = res
        elif args.lat is not None and args.lon is not None:
            lat, lon, city = args.lat, args.lon, ""
        else:
            print(json.dumps({"ok": False, "error": "GEO FAILED"}))
            return
    elif args.lat is not None and args.lon is not None:
        lat, lon, city = args.lat, args.lon, f"{args.lat:.2f}, {args.lon:.2f}"
    else:
        print(json.dumps({"ok": False, "error": "NO LOCATION"}))
        return

    try:
        wurl = (f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
                "¤t=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m")
        w = get_json(wurl, timeout=8)
        cur = w.get("current") or {}
        print(json.dumps({
            "ok": True,
            "city": city,
            "lat": lat,
            "lon": lon,
            "temp": cur.get("temperature_2m"),
            "feels": cur.get("apparent_temperature"),
            "humidity": cur.get("relative_humidity_2m"),
            "code": cur.get("weather_code"),
            "wind": cur.get("wind_speed_10m"),
        }))
    except Exception:
        print(json.dumps({"ok": False, "error": "FETCH FAILED", "city": city}))

if __name__ == "__main__":
    main()
