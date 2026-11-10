pragma Singleton
import QtQuick

// MOCK events, placed relative to today so the widget always has something to show.
QtObject {
    id: ag
    property int checkedDay: 0
    property int minuteKey: 0

    function _d(offsetDays, h, m) {
        var n = new Date();
        return new Date(n.getFullYear(), n.getMonth(), n.getDate() + offsetDays, h, m);
    }
    readonly property var events: [
        { "name": "Ship log review", "at": _d(0, 18, 30), "allDay": false },
        { "name": "Loop restarts", "at": _d(1, 9, 0), "allDay": false },
        { "name": "Campfire night", "at": _d(2, 21, 0), "allDay": false },
        { "name": "Probe launch window", "at": _d(4, 0, 0), "allDay": true },
        { "name": "Hearthian meetup", "at": _d(6, 17, 0), "allDay": false },
        { "name": "Observatory visit", "at": _d(9, 11, 0), "allDay": false }
    ]

    function _same(a, y, m, d) { return a.getFullYear() === y && a.getMonth() === m && a.getDate() === d; }
    function forDay(y, m, d) {
        var out = [];
        for (var i = 0; i < events.length; i++) if (_same(events[i].at, y, m, d)) out.push(events[i]);
        return out;
    }
    function hasOn(y, m, d) { return forDay(y, m, d).length > 0; }
    function upcoming(n) {
        var now = new Date(), out = [];
        for (var i = 0; i < events.length && out.length < n; i++)
            if (events[i].at >= new Date(now.getFullYear(), now.getMonth(), now.getDate()))
                out.push({ "at": events[i].at, "item": events[i] });
        return out;
    }
    function timeText(item) {
        return item.allDay ? "All day" : Qt.formatTime(item.at, "h:mm AP");
    }
}
