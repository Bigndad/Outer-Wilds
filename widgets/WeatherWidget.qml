import QtQuick
import Quickshell.Io
import ".."

WidgetCard {
    id: card
    title: "SURFACE TELEMETRY // MUMBAI"
    accent: "#FF6347"
    implicitWidth: 210
    implicitHeight: 112

    property string tempText: "--°C"
    property string condText: "SCANNING..."
    property string windText: "-- km/h"

    function wmoDesc(code) {
        if (code === 0) return "CLEAR SKY";
        if (code <= 3) return "PARTLY CLOUDY";
        if (code <= 48) return "ATMOSPHERIC FOG";
        if (code <= 67) return "PRECIPITATION";
        if (code <= 82) return "HEAVY RAIN SHOWERS";
        if (code >= 95) return "ELECTRICAL STORM";
        return "CODE " + code;
    }

    Timer {
        interval: 900000 // 15 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: [
            "curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=18.91&longitude=72.81¤t=temperature_2m,weather_code,wind_speed_10m"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const tMatch = text.match(/"temperature_2m"\s*:\s*([0-9.-]+)/);
                const cMatch = text.match(/"weather_code"\s*:\s*(\d+)/);
                const wMatch = text.match(/"wind_speed_10m"\s*:\s*([0-9.-]+)/);
                if (tMatch) card.tempText = Math.round(parseFloat(tMatch[1])) + "°C";
                if (cMatch) card.condText = card.wmoDesc(parseInt(cMatch[1]));
                if (wMatch) card.windText = Math.round(parseFloat(wMatch[1])) + " km/h WIND";
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: 26
        anchors.margins: 12
        spacing: 4

        Text {
            text: card.tempText
            color: "#E6D5B8"
            font.family: "monospace"
            font.pixelSize: 24
            font.bold: true
        }
        Text {
            text: card.condText
            color: "#FF6347"
            font.family: "monospace"
            font.pixelSize: 11
        }
        Text {
            text: card.windText
            color: "#99E6D5B8"
            font.family: "monospace"
            font.pixelSize: 10
        }
    }
}