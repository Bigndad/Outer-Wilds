import QtQuick
import Quickshell.Io
import ".."

WidgetCard {
    id: card
    title: "WEATHER"
    designW: 280
    designH: 132

    property var cfg: ({ lat: 18.91, lon: 72.81, unit: "C", windUnit: "km/h",
                         showWind: true, refreshMin: 15, accentColor: "#FF6347" })

    accent: (cardStyle && cardStyle.accent) ? cardStyle.accent : (cfg.accentColor || "#FF6347")

    property real rawTempC: NaN
    property real rawWindKmh: NaN
    property string condText: "SCANNING..."
    property real _fetchedLat: NaN
    property real _fetchedLon: NaN

    readonly property string tempText: {
        if (!isFinite(rawTempC)) return "--°" + (cfg.unit || "C");
        const val = cfg.unit === "F" ? (rawTempC * 9 / 5 + 32) : rawTempC;
        return Math.round(val) + "°" + (cfg.unit || "C");
    }
    readonly property string windText: {
        if (!isFinite(rawWindKmh)) return "-- " + (cfg.windUnit || "km/h");
        const u = cfg.windUnit || "km/h";
        const val = u === "m/s" ? (rawWindKmh / 3.6) : (u === "mph" ? (rawWindKmh * 0.621371) : rawWindKmh);
        return Math.round(val) + " " + u + " WIND";
    }

    function wmoDesc(code) {
        if (code === 0) return "CLEAR SKY";
        if (code <= 3) return "PARTLY CLOUDY";
        if (code <= 48) return "ATMOSPHERIC FOG";
        if (code <= 67) return "PRECIPITATION";
        if (code <= 82) return "HEAVY RAIN SHOWERS";
        if (code >= 95) return "ELECTRICAL STORM";
        return "CODE " + code;
    }

    function fetchWeather() {
        const lat = Number(card.cfg.lat), lon = Number(card.cfg.lon);
        if (!isFinite(lat) || !isFinite(lon)) return;
        card._fetchedLat = lat;
        card._fetchedLon = lon;
        weatherProc.running = false;
        weatherProc.running = true;
    }

    onCfgChanged: {
        const lat = Number(cfg.lat), lon = Number(cfg.lon);
        if (isFinite(lat) && isFinite(lon) && (!isFinite(_fetchedLat) || Math.abs(lat - _fetchedLat) > 0.001 || Math.abs(lon - _fetchedLon) > 0.001)) {
            fetchWeather();
        }
    }

    Timer {
        interval: Math.max(60000, Math.round((card.cfg.refreshMin || 15) * 60000))
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: card.fetchWeather()
    }

    Process {
        id: weatherProc
        command: [
            "curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + card.cfg.lat + "&longitude=" + card.cfg.lon + "¤t=temperature_2m,weather_code,wind_speed_10m"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const tMatch = text.match(/"temperature_2m"\s*:\s*([0-9.-]+)/);
                const cMatch = text.match(/"weather_code"\s*:\s*(\d+)/);
                const wMatch = text.match(/"wind_speed_10m"\s*:\s*([0-9.-]+)/);
                if (tMatch) card.rawTempC = parseFloat(tMatch[1]);
                if (cMatch) card.condText = card.wmoDesc(parseInt(cMatch[1]));
                if (wMatch) card.rawWindKmh = parseFloat(wMatch[1]);
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 4 * card.ui

        Text {
            text: card.tempText
            color: card.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(10, Math.round(30 * card.ui))
            font.bold: true
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.condText
            color: card.accent
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(12 * card.ui))
            font.letterSpacing: 1 * card.ui
        }
        Text {
            visible: card.cfg.showWind !== false
            text: card.windText
            color: "#99E6D5B8"
            font.family: "monospace"
            font.pixelSize: Math.max(7, Math.round(11 * card.ui))
        }
    }
}
