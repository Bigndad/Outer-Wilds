import QtQuick
import "../shim"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 100
    property real maxWidth: 900
    property real maxHeight: 900
    property real minAspect: 0.7
    property real maxAspect: 1.3
    property bool isRound: false

    property var currentTime: new Date()
    property string colorAHex: ""
    property string colorBHex: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    readonly property string hoursStr: {
        if (typeof DateTime !== "undefined" && DateTime.hour !== undefined && String(DateTime.hour) !== "") {
            return String(DateTime.hour).padStart(2, "0");
        }
        return String(currentTime.getHours()).padStart(2, "0");
    }

    readonly property string minutesStr: {
        if (typeof DateTime !== "undefined" && DateTime.minute !== undefined && String(DateTime.minute) !== "") {
            return String(DateTime.minute).padStart(2, "0");
        }
        return String(currentTime.getMinutes()).padStart(2, "0");
    }

    MaterialDigitGrid {
        anchors.centerIn: parent
        hours: root.hoursStr
        minutes: root.minutesStr
        fitWidth: root.width * 0.94
        fitHeight: root.height * 0.94
        colorA: root.colorAHex !== "" ? root.colorAHex : (ThemeBackend.onSurface ?? ThemeBackend.text)
        colorB: root.colorBHex !== "" ? root.colorBHex : (ThemeBackend.primary ?? ThemeBackend.mauve)
    }
}
