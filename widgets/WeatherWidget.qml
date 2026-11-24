import QtQuick
import Quickshell.Io
import ".."

WidgetCard {
    id: card
    title: "WEATHER"
    designW: 280
    designH: 142

    property var cfg: ({ autoLocation: true, lat: 18.91, lon: 72.81, unit: "C", windUnit: "km/h",
                         showWind: true, refreshMin: 15, accentColor: "#FF6347" })

    accent: (cardStyle && cardStyle.accent) ? cardStyle.accent
          : ((cfg.accentColor && cfg.accentColor.toUpperCase() !== "#FF6347") ? cfg.accentColor : card.cGold)
    readonly property string effWeatherFont: card.effFont

    property real autoLat: NaN
    property real autoLon: NaN
    property string cityName: ""
    property real rawTempC: NaN
    property real rawWindKmh: NaN
    property string condText: "SCANNING..."
    property real _fetchedLat: NaN
    property real _fetchedLon: NaN

    readonly property real effLat: (cfg.autoLocation !== false && isFinite(autoLat)) ? autoLat : Number(cfg.lat)
    readonly property real effLon: (cfg.autoLocation !== false && isFinite(autoLon)) ? autoLon : Number(cfg.lon)

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
        const lat = card.effLat, lon = card.effLon;
        if (!isFinite(lat) || !isFinite(lon)) return;
        card._fetchedLat = lat;
        card._fetchedLon = lon;
        weatherProc.running = false;
        weatherProc.command = [
            "curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon + "¤t=temperature_2m,weather_code,wind_speed_10m"
        ];
        weatherProc.running = true;
    }

    onCfgChanged: {
        if (cfg.autoLocation !== false && !isFinite(autoLat)) geoProc.running = true;
        else if (isFinite(effLat) && isFinite(effLon) && (!isFinite(_fetchedLat) || Math.abs(effLat - _fetchedLat) > 0.001 || Math.abs(effLon - _fetchedLon) > 0.001)) {
            fetchWeather();
        }
    }

    Component.onCompleted: {
        if (cfg.autoLocation !== false) geoProc.running = true;
        else fetchWeather();
    }

    Timer {
        interval: Math.max(60000, Math.round((card.cfg.refreshMin || 15) * 60000))
        running: true
        repeat: true
        onTriggered: card.fetchWeather()
    }

    Process {
        id: geoProc
        command: ["sh", "-c", 'curl -s --max-time 6 "https://ipwho.is/" || curl -s --max-time 6 "https://ipapi.co/json/"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const lat = Number(j.latitude);
                    const lon = Number(j.longitude);
                    if (isFinite(lat) && isFinite(lon)) {
                        card.autoLat = lat;
                        card.autoLon = lon;
                        if (j.city) card.cityName = String(j.city).toUpperCase();
                    }
                } catch (e) {}
                card.fetchWeather();
            }
        }
    }

    Process {
        id: weatherProc
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
        spacing: 6 * card.ui

        Item {
            width: parent.width
            height: tempLbl.implicitHeight

            Text {
                id: tempLbl
                anchors.left: parent.left
                text: card.tempText
                color: card.cCream
                font.family: card.effWeatherFont
                font.pixelSize: Math.max(10, Math.round(30 * card.ui))
                font.bold: true
            }

            Rectangle {
                visible: card.cityName !== ""
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width * 0.48, cityLbl.implicitWidth + 10 * card.ui)
                height: cityLbl.implicitHeight + 6 * card.ui
                radius: 4 * card.ui
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.14)
                border.width: Math.max(1, Math.round(card.ui))
                border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.32)

                Text {
                    id: cityLbl
                    anchors.centerIn: parent
                    width: parent.width - 8 * card.ui
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: card.cityName
                    color: card.accent
                    font.family: card.effWeatherFont
                    font.bold: true
                    font.pixelSize: Math.max(7, Math.round(9 * card.ui))
                    font.letterSpacing: 1 * card.ui
                }
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.condText
            color: card.accent
            font.family: card.effWeatherFont
            font.bold: true
            font.pixelSize: Math.max(8, Math.round(11 * card.ui))
            font.letterSpacing: 1.4 * card.ui
        }

        Rectangle {
            visible: card.cfg.showWind !== false
            width: windLbl.implicitWidth + 12 * card.ui
            height: windLbl.implicitHeight + 5 * card.ui
            radius: 3 * card.ui
            color: "#1F000000"
            border.width: Math.max(1, Math.round(card.ui))
            border.color: Qt.rgba(card.cDim.r, card.cDim.g, card.cDim.b, 0.22)

            Text {
                id: windLbl
                anchors.centerIn: parent
                text: card.windText
                color: card.cDim
                font.family: card.effWeatherFont
                font.pixelSize: Math.max(7, Math.round(10 * card.ui))
            }
        }
    }
}
