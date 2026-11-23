import QtQuick
import "."

// Round weather tile: dot icon, temperature in dots, condition + low/high. Data: GlyphWeatherData (Open-Meteo).
GlyphCard {
    id: w
    designW: 220
    designH: 220
    round: true

    readonly property var icons: ({
        sun:   ["....#.#....", "..#.....#..", "...#####...", "#..#####..#", "...#####...", "..#.....#..", "....#.#....", "...........", "..........."],
        moon:  ["....###....", "..###......", ".###.......", ".###.......", ".###.......", ".####.....#", "..######.#.", "....####...", "..........."],
        cloud: ["...........", "....###....", "..#######..", ".#########.", "###########", "###########", ".#########.", "...........", "..........."],
        rain:  ["....###....", "..#######..", ".#########.", "###########", ".#########.", "...........", ".#..#..#...", "#..#..#..#.", "..#..#..#.."],
        snow:  ["....###....", "..#######..", ".#########.", "###########", ".#########.", "...........", "..#...#...#", ".....#.....", "#...#...#.."],
        storm: ["....###....", "..#######..", ".#########.", "###########", ".#########.", "....RR.....", "...RR......", "..RRRR.....", "....R......"],
        fog:   ["...........", "..#######..", "...........", "#########..", "...........", "..#########", "...........", ".#######...", "..........."]
    })
    function iconFor(c, day) {
        if (c === 0) return day ? "sun" : "moon";
        if (c <= 3) return "cloud";
        if (c <= 48) return "fog";
        if (c <= 67 || (c >= 80 && c <= 82)) return "rain";
        if (c <= 77 || c <= 86) return "snow";
        return "storm";
    }

    readonly property bool ok: GlyphWeatherData.ok

    GlyphBitmap {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34
        rows: w.icons[w.ok ? w.iconFor(GlyphWeatherData.code, GlyphWeatherData.day) : "cloud"]
        cell: 7
        on: w.ok ? GlyphTheme.fg : GlyphTheme.mute
    }
    GlyphDots {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 110
        text: w.ok ? String(Math.round(GlyphWeatherData.temp)) + "\u00B0" : "--"
        cell: 7
    }
    GlyphLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 176
        width: 150
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: w.ok ? GlyphWeatherData.desc(GlyphWeatherData.code) + " " + Math.round(GlyphWeatherData.tmin) + "/" + Math.round(GlyphWeatherData.tmax) : "no sky"
    }
}
