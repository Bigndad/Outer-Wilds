pragma Singleton
import QtQuick

// Fixed UTC offsets in hours (no DST table in plain QML), right for November.
QtObject {
    readonly property var cities: ["Asia/Kolkata", "Asia/Tokyo", "Europe/London"]
    readonly property var offsets: ({
        "Asia/Kolkata": 5.5, "Asia/Tokyo": 9, "Asia/Dubai": 4, "Australia/Sydney": 11,
        "Europe/London": 0, "Europe/Paris": 1, "Europe/Moscow": 3,
        "America/New_York": -5, "America/Chicago": -6, "America/Los_Angeles": -8
    })

    function watch(list) { }

    function cityOf(z) {
        var s = String(z).split("/").pop();
        return s.replace("_", " ");
    }

    // a Date whose local fields read as the clock time in that zone
    function timeIn(z) {
        var off = offsets[z] === undefined ? 0 : offsets[z];
        var n = new Date();
        return new Date(n.getTime() + (off * 60 + n.getTimezoneOffset()) * 60000);
    }

    function localOffsetHours() { return -new Date().getTimezoneOffset() / 60; }

    function dayText(z) {
        var t = timeIn(z), n = new Date();
        var a = new Date(t.getFullYear(), t.getMonth(), t.getDate()).getTime();
        var b = new Date(n.getFullYear(), n.getMonth(), n.getDate()).getTime();
        var d = Math.round((a - b) / 86400000);
        return d === 0 ? "Today" : (d > 0 ? "Tomorrow" : "Yesterday");
    }

    function offsetText(z) {
        var off = offsets[z] === undefined ? 0 : offsets[z];
        var d = off - localOffsetHours();
        if (Math.abs(d) < 0.01) return "";
        var s = Math.abs(d) % 1 === 0 ? String(Math.abs(d)) : Math.abs(d).toFixed(1);
        return (d > 0 ? "+" : "-") + s + "h";
    }
}
