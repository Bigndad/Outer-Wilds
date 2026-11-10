pragma Singleton
import QtQuick

QtObject {
    readonly property var strings: ({
        "calendar.weather.feels": "Feels",
        "syspanel.battery.charging": "Charging",
        "syspanel.battery.charging_time": "Charging \u2022 {hours}h {mins}m",
        "syspanel.battery.discharging": "Discharging",
        "syspanel.battery.fully_charged": "Fully charged",
        "syspanel.battery.left_time": "{hours}h {mins}m left",
        "music.nothing_playing": "Nothing is playing",
        "music.searching_lyrics": "Searching lyrics...",
        "music.no_lyrics": "No lyrics found",
        "music.select_local_file": "Select a local file"
})
    function t(key, params) {
        var s = strings[key] !== undefined ? strings[key] : key;
        if (params) for (var p in params) s = s.split("{" + p + "}").join(params[p]);
        return s;
    }
}
