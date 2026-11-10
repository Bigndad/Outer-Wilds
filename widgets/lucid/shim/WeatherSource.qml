pragma Singleton
import QtQuick

// MOCK. Replace `report` with a live source later; field names are Lucid's.
QtObject {
    id: src
    property string place: "Mumbai, India"
    property bool busy: false
    property string lastError: ""
    property var report: ({
        "code": 2, "tempC": 31, "tempF": 88, "feelsC": 35, "feelsF": 95, "humidity": 72,
        "windKmph": 14, "windMph": 9, "uv": 7, "isDay": Loc.now().getHours() >= 6 && Loc.now().getHours() < 19,
        "pop": 10, "windDir": "W",
        "days": [
            { "date": "", "code": 2, "maxC": 32, "maxF": 90, "minC": 25, "minF": 77, "pop": 10 },
            { "date": "", "code": 1, "maxC": 33, "maxF": 91, "minC": 25, "minF": 77, "pop": 0 },
            { "date": "", "code": 61, "maxC": 30, "maxF": 86, "minC": 24, "minF": 75, "pop": 60 },
            { "date": "", "code": 3, "maxC": 31, "maxF": 88, "minC": 25, "minF": 77, "pop": 30 },
            { "date": "", "code": 0, "maxC": 33, "maxF": 91, "minC": 26, "minF": 79, "pop": 0 },
            { "date": "", "code": 80, "maxC": 29, "maxF": 84, "minC": 24, "minF": 75, "pop": 55 }
        ],
        "hours": [31, 31, 30, 30, 29, 28, 28, 27, 27, 28, 30, 32, 33, 33, 32, 31, 30, 29, 28].map(function (t, i) {
            return { "time": "", "code": i > 6 && i < 12 ? 0 : 2, "tempC": t, "tempF": Math.round(t * 1.8 + 32), "pop": 10, "day": i < 5 || i > 12 };
        })
    })

    function ensure() { }

    function kindFor(code, night) {
        if (code === 0 || code === 1) return night ? "clear-night" : "clear";
        if (code === 2) return night ? "partly-night" : "partly";
        if (code === 3) return "cloudy";
        if (code === 45 || code === 48) return "fog";
        if (code >= 51 && code <= 57) return "drizzle";
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
        if (code >= 95) return "storm";
        return "cloudy";
    }

    function descFor(code) {
        var m = { "0": "Clear", "1": "Mostly clear", "2": "Partly cloudy", "3": "Overcast", "45": "Fog", "48": "Rime fog",
                  "51": "Light drizzle", "53": "Drizzle", "55": "Heavy drizzle", "61": "Light rain", "63": "Rain", "65": "Heavy rain",
                  "71": "Light snow", "73": "Snow", "75": "Heavy snow", "80": "Showers", "81": "Showers", "82": "Heavy showers",
                  "95": "Thunderstorm", "96": "Thunderstorm", "99": "Thunderstorm" };
        return m[String(code)] || "Cloudy";
    }
}
