pragma Singleton
import QtQuick

QtObject {
    id: svc

    property bool ok: false
    property bool busy: false
    property string error: ""
    property string city: ""
    property string country: ""
    property string place: city !== "" ? (country !== "" ? city + ", " + country : city) : "Locating..."
    property real lat: NaN
    property real lon: NaN

    property real tempC: NaN
    property real feelsC: NaN
    property int humidity: 0
    property real windKmh: NaN
    property string windDir: ""
    property real uv: 0
    property int code: 0
    property bool isDay: true
    property int pop: 0
    property real tmin: NaN
    property real tmax: NaN
    property var days: []
    property var hours: []
    property var report: ({
        "code": 0, "tempC": 0, "tempF": 32, "feelsC": 0, "feelsF": 32, "humidity": 0,
        "windKmph": 0, "windMph": 0, "uv": 0, "isDay": true, "pop": 0, "windDir": "",
        "days": [], "hours": []
    })

    function _cToF(c) { return Math.round(c * 9 / 5 + 32); }
    function _degToDir(d) {
        const dirs = ["N","NE","E","SE","S","SW","W","NW"];
        return dirs[Math.round((((d % 360) + 360) % 360) / 45) % 8];
    }

    function _getJson(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status >= 200 && xhr.status < 300) {
                try { cb(null, JSON.parse(xhr.responseText)); }
                catch (e) { cb("PARSE ERROR", null); }
            } else {
                cb("HTTP " + xhr.status, null);
            }
        };
        xhr.send();
    }

    function _parseForecast(j) {
        const cur = j.current || {};
        const d = j.daily || {};
        const h = j.hourly || {};

        const tC = Number(cur.temperature_2m);
        const fC = Number(cur.apparent_temperature);
        const wK = Number(cur.wind_speed_10m);
        const hum = Math.round(Number(cur.relative_humidity_2m || 0));
        const cCode = parseInt(cur.weather_code || 0);
        const dayFlag = cur.is_day !== 0;
        const wDir = _degToDir(Number(cur.wind_direction_10m || 0));

        const daysOut = [];
        const dTimes = d.time || [];
        for (let i = 0; i < dTimes.length; i++) {
            const mx = Number((d.temperature_2m_max || [])[i] || 0);
            const mn = Number((d.temperature_2m_min || [])[i] || 0);
            daysOut.push({
                "date": dTimes[i],
                "code": parseInt((d.weather_code || [])[i] || 0),
                "maxC": Math.round(mx), "maxF": _cToF(mx),
                "minC": Math.round(mn), "minF": _cToF(mn),
                "pop": Math.round(Number((d.precipitation_probability_max || [])[i] || 0))
            });
        }

        const nowIso = cur.time || "";
        let startIdx = 0;
        const hTimes = h.time || [];
        for (let i = 0; i < hTimes.length; i++) {
            if (hTimes[i] >= nowIso) { startIdx = i; break; }
        }
        const hoursOut = [];
        for (let i = startIdx; i < Math.min(hTimes.length, startIdx + 24); i++) {
            const ht = Number((h.temperature_2m || [])[i] || 0);
            hoursOut.push({
                "time": hTimes[i],
                "code": parseInt((h.weather_code || [])[i] || 0),
                "tempC": Math.round(ht), "tempF": _cToF(ht),
                "pop": Math.round(Number((h.precipitation_probability || [])[i] || 0)),
                "day": ((h.is_day || [])[i] !== 0)
            });
        }

        const uvMax = Number((d.uv_index_max || [0])[0] || 0);
        const todayPop = daysOut.length > 0 ? daysOut[0].pop : 0;

        return {
            "code": cCode,
            "tempC": tC, "tempF": _cToF(tC),
            "feelsC": fC, "feelsF": _cToF(fC),
            "humidity": hum,
            "windKmph": wK, "windMph": Math.round(wK * 0.621371),
            "uv": Math.round(uvMax),
            "isDay": dayFlag,
            "pop": todayPop,
            "windDir": wDir,
            "tmin": daysOut.length > 0 ? daysOut[0].minC : tC,
            "tmax": daysOut.length > 0 ? daysOut[0].maxC : tC,
            "days": daysOut,
            "hours": hoursOut
        };
    }

    function fetchForecast(la, lo, cb) {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + encodeURIComponent(la)
            + "&longitude=" + encodeURIComponent(lo)
            + "¤t=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m,wind_direction_10m"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"
            + "&timezone=auto&forecast_days=6";
        _getJson(url, function(err, j) {
            if (err || !j || !j.current) { cb(err || "NO FORECAST", null); return; }
            cb(null, _parseForecast(j));
        });
    }

    function fetchQuery(query, cb) {
        const url = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=1&language=en&format=json";
        _getJson(url, function(err, j) {
            if (err || !j || !j.results || j.results.length === 0) { cb("LOCATION NOT FOUND", null); return; }
            const r = j.results[0];
            fetchForecast(r.latitude, r.longitude, function(ferr, rep) {
                if (ferr) { cb(ferr, null); return; }
                rep.city = r.name || query;
                cb(null, rep);
            });
        });
    }

    function _applyShared(rep) {
        tempC = rep.tempC;
        feelsC = rep.feelsC;
        humidity = rep.humidity;
        windKmh = rep.windKmph;
        windDir = rep.windDir;
        uv = rep.uv;
        code = rep.code;
        isDay = rep.isDay;
        pop = rep.pop;
        tmin = rep.tmin;
        tmax = rep.tmax;
        days = rep.days;
        hours = rep.hours;
        report = rep;
        ok = true;
        error = "";
        busy = false;
    }

    function refresh() {
        if (busy) return;
        busy = true;
        error = "";
        const doForecast = function() {
            fetchForecast(lat, lon, function(err, rep) {
                if (err) { error = err; busy = false; return; }
                _applyShared(rep);
            });
        };
        if (isFinite(lat) && isFinite(lon)) {
            doForecast();
            return;
        }
        _getJson("https://ipwho.is/", function(err, j) {
            if (!err && j && j.success !== false && isFinite(Number(j.latitude))) {
                city = j.city || "";
                country = j.country || "";
                lat = Number(j.latitude);
                lon = Number(j.longitude);
                doForecast();
            } else {
                _getJson("http://ip-api.com/json/?fields=status,city,country,lat,lon", function(err2, j2) {
                    if (!err2 && j2 && j2.status === "success") {
                        city = j2.city || "";
                        country = j2.country || "";
                        lat = Number(j2.lat);
                        lon = Number(j2.lon);
                        doForecast();
                    } else {
                        error = "LOCATE FAILED";
                        busy = false;
                    }
                });
            }
        });
    }

    property Timer _timer: Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: svc.refresh()
    }

    Component.onCompleted: refresh()
}
