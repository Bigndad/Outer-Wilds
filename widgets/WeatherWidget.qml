import QtQuick
import ".."

WidgetCard {
    id: card
    title: "WEATHER"
    designW: 280
    designH: 146

    property var cfg: ({ autoLocation: true, location: "", lat: 18.91, lon: 72.81, unit: "C",
                         windUnit: "km/h", showWind: true, refreshMin: 15, accentColor: "#FF6347" })

    accent: (cardStyle && cardStyle.accent) ? cardStyle.accent
          : ((cfg.accentColor && cfg.accentColor.toUpperCase() !== "#FF6347") ? cfg.accentColor : card.cGold)
    readonly property string effWeatherFont: card.effFont

    readonly property bool useShared: String(cfg.location || "").trim() === "" && cfg.autoLocation !== false

    property string _cCity: ""
    property real _cTempC: NaN
    property real _cFeelsC: NaN
    property real _cWindKmh: NaN
    property string _cCond: "SCANNING..."
    property string _lastReqKey: ""

    readonly property string cityName: useShared ? WeatherService.city.toUpperCase() : _cCity
    readonly property real rawTempC: useShared ? WeatherService.tempC : _cTempC
    readonly property real rawFeelsC: useShared ? WeatherService.feelsC : _cFeelsC
    readonly property real rawWindKmh: useShared ? WeatherService.windKmh : _cWindKmh
    readonly property string condText: useShared
        ? (WeatherService.ok ? wmoDesc(WeatherService.code) : (WeatherService.error !== "" ? WeatherService.error : "SCANNING..."))
        : _cCond

    readonly property string tempText: {
        if (!isFinite(rawTempC)) return "--°" + (cfg.unit || "C");
        const val = cfg.unit === "F" ? (rawTempC * 9 / 5 + 32) : rawTempC;
        return Math.round(val) + "°" + (cfg.unit || "C");
    }
    readonly property string feelsText: {
        if (!isFinite(rawFeelsC)) return "";
        const val = cfg.unit === "F" ? (rawFeelsC * 9 / 5 + 32) : rawFeelsC;
        return "FEELS " + Math.round(val) + "°";
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
        if (code <= 82) return "RAIN SHOWERS";
        if (code >= 95) return "ELECTRICAL STORM";
        return "CODE " + code;
    }

    function reqKey() {
        const q = String(cfg.location || "").trim();
        return (cfg.autoLocation !== false ? "1" : "0") + "|" + q + "|" + Number(cfg.lat) + "|" + Number(cfg.lon);
    }

    function startFetch() {
        _lastReqKey = reqKey();
        if (useShared) {
            WeatherService.refresh();
            return;
        }
        const q = String(cfg.location || "").trim();
        _cCond = "SCANNING...";
        if (q !== "") {
            WeatherService.fetchQuery(q, function(err, rep) {
                if (err) { card._cCond = err; return; }
                card._cCity = String(rep.city || q).toUpperCase();
                card._cTempC = rep.tempC;
                card._cFeelsC = rep.feelsC;
                card._cWindKmh = rep.windKmph;
                card._cCond = card.wmoDesc(rep.code);
            });
        } else if (isFinite(Number(cfg.lat)) && isFinite(Number(cfg.lon))) {
            WeatherService.fetchForecast(Number(cfg.lat), Number(cfg.lon), function(err, rep) {
                if (err) { card._cCond = err; return; }
                card._cCity = Number(cfg.lat).toFixed(2) + ", " + Number(cfg.lon).toFixed(2);
                card._cTempC = rep.tempC;
                card._cFeelsC = rep.feelsC;
                card._cWindKmh = rep.windKmph;
                card._cCond = card.wmoDesc(rep.code);
            });
        }
    }

    Timer { id: fetchDebounce; interval: 350; onTriggered: card.startFetch() }
    onCfgChanged: { if (reqKey() !== _lastReqKey) fetchDebounce.restart(); }
    Component.onCompleted: { if (!useShared) startFetch(); }

    Timer {
        interval: Math.max(60000, Math.round((card.cfg.refreshMin || 15) * 60000))
        running: !card.useShared
        repeat: true
        onTriggered: card.startFetch()
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

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * card.ui

                Rectangle {
                    visible: card.cityName !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(card.innerW * 0.45, cityLbl.implicitWidth + 10 * card.ui)
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

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * card.ui
                    height: 18 * card.ui
                    radius: 4 * card.ui
                    color: refMa.containsMouse ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.2) : "#1F000000"
                    border.width: Math.max(1, Math.round(card.ui))
                    border.color: Qt.rgba(card.cDim.r, card.cDim.g, card.cDim.b, 0.25)
                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: refMa.containsMouse ? card.accent : card.cDim
                        font.family: card.effWeatherFont
                        font.pixelSize: Math.max(8, Math.round(10 * card.ui))
                    }
                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.startFetch()
                    }
                }
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.condText + (card.feelsText !== "" ? ("  ·  " + card.feelsText) : "")
            color: card.accent
            font.family: card.effWeatherFont
            font.bold: true
            font.pixelSize: Math.max(8, Math.round(10.5 * card.ui))
            font.letterSpacing: 1.2 * card.ui
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
