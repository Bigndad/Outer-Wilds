import QtQuick
import "."

// Round weather tile: dot icon, temperature in dots, condition + low/high.
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
    function cvt(c) { return w.cfg.unit === "F" ? Math.round(c * 9 / 5 + 32) : Math.round(c); }

    readonly property bool ok: GlyphWeatherData.ok
    readonly property color dotCol: (cfg.dotColor && cfg.dotColor !== "") ? cfg.dotColor : GlyphTheme.fg

    GlyphBitmap {
        visible: w.cfg.showIcon !== false
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34
        rows: w.icons[w.ok ? w.iconFor(GlyphWeatherData.code, GlyphWeatherData.day) : "cloud"]
        cell: 7
        on: w.ok ? w.dotCol : GlyphTheme.mute
    }
    GlyphDots {
        anchors.horizontalCenter: parent.horizontalCenter
        y: w.cfg.showIcon !== false ? 110 : 82
        text: w.ok ? String(w.cvt(GlyphWeatherData.temp)) + "\u00B0" : "--"
        cell: 7
        on: w.dotCol
    }
    GlyphLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 176
        width: 150
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: w.ok ? (GlyphWeatherData.desc(GlyphWeatherData.code) + (w.cfg.showRange !== false ? (" " + w.cvt(GlyphWeatherData.tmin) + "/" + w.cvt(GlyphWeatherData.tmax)) : "")) : "no sky"
    }
}
