pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Shared Open-Meteo poll (no key) for the glyph weather widget: one curl every 15 min, only while the scene is visible.
// Place: Mumbai (same coordinates as WeatherWidget.qml); change lat/lon here.
Singleton {
    id: root
    property real lat: 18.91
    property real lon: 72.81
    property bool ok: false
    property real temp: 0
    property real tmin: 0
    property real tmax: 0
    property int code: 0
    property bool day: true

    function desc(c) {
        if (c === 0) return "clear";
        if (c <= 3) return "cloudy";
        if (c <= 48) return "fog";
        if (c <= 67) return "rain";
        if (c <= 77) return "snow";
        if (c <= 82) return "showers";
        if (c <= 86) return "snow";
        return "storm";
    }

    Timer {
        interval: 900000
        running: NoctaliaBridge.desktopVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
    Process {
        id: proc
        command: ["curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.temp = j.current.temperature_2m;
                    root.code = j.current.weather_code;
                    root.day = j.current.is_day === 1;
                    root.tmin = j.daily.temperature_2m_min[0];
                    root.tmax = j.daily.temperature_2m_max[0];
                    root.ok = true;
                } catch (e) { /* keep the last good values */ }
            }
        }
    }
}
