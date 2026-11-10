pragma Singleton
import QtQuick
QtObject {
    id: dt
    property bool hasSeconds: true
    property bool is12Hour: true
    property date now: new Date()
    readonly property int hour: now.getHours()
    readonly property int minute: now.getMinutes()
    property Timer tick: Timer { interval: 1000; running: true; repeat: true; onTriggered: dt.now = new Date() }
}
