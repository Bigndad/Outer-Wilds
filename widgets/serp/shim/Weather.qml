pragma Singleton
import QtQuick

// MOCK weather in Serpantinum's field names. Swap `data`/current* for a live source later.
QtObject {
    id: w
    function g(cp) { return String.fromCodePoint(cp); }
    property bool isReady: true
    property bool isLoading: false
    property string currentIcon: g(0xF0595)
    property string currentTemp: "31"
    property string currentHex: "#e8b54a"
    property var data: ({
        "city": "Mumbai",
        "current_feels_like": 35,
        "forecast": [{
            "desc": "Partly cloudy",
            "feels_like": 35,
            "hourly": [
                { "time": "00:00", "temp": 28, "icon": g(0xF0594), "hex": "#7fb7c9" },
                { "time": "03:00", "temp": 27, "icon": g(0xF0594), "hex": "#7fb7c9" },
                { "time": "06:00", "temp": 27, "icon": g(0xF0595), "hex": "#e8b54a" },
                { "time": "09:00", "temp": 30, "icon": g(0xF0599), "hex": "#e8b54a" },
                { "time": "12:00", "temp": 33, "icon": g(0xF0599), "hex": "#e8b54a" },
                { "time": "15:00", "temp": 33, "icon": g(0xF0595), "hex": "#e8b54a" },
                { "time": "18:00", "temp": 31, "icon": g(0xF0590), "hex": "#b5a783" },
                { "time": "21:00", "temp": 29, "icon": g(0xF0597), "hex": "#7fb7c9" }
            ]
        }]
    })
}
