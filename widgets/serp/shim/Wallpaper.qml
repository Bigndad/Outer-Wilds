pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Serpantinum's wallpaper engine API, applied through Noctalia v5:  noctalia msg wallpaper-set [<output>] <path>
// (Noctalia draws the wallpaper; it re-themes from it when [theme].source = "wallpaper").
Singleton {
    id: root
    property var names: ({})        // output (or "all") -> file name currently set
    readonly property string cacheDir: Caching.getCacheDir("wallpaper")

    function getWallpaper(screenName) {
        return names[screenName] || names["all"] || "";
    }
    function getWallpaperPath(screenName) { return ""; }
    function setPlayback(screenName, state) {}
    function clearWallpaper(screenName) {}
    function shuffle(screenName, transition) { runner.exec(["noctalia", "msg", "wallpaper-random"]); }

    function setWallpaper(screenName, path, transition) {
        const base = String(path).split("/").pop();
        const n = Object.assign({}, names);
        n[screenName] = base;
        if (screenName === "all") { for (const k in n) if (k !== "all") n[k] = base; }
        names = n;
        const cmd = screenName === "all" ? ["noctalia", "msg", "wallpaper-set", path]
                                         : ["noctalia", "msg", "wallpaper-set", screenName, path];
        runner.exec(cmd);
        // remember it for the picker (current_*_name, history.txt)
        const dir = cacheDir, nm = screenName === "all" ? "default" : screenName;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$1"; printf %s "$2" > "$1/current_$3_name"; grep -vxF -- "$2" "$1/history.txt" 2>/dev/null > "$1/history.tmp"; printf "%s\\n" "$2" >> "$1/history.tmp"; mv "$1/history.tmp" "$1/history.txt"',
            "sh", dir, base, nm]);
    }

    QtObject {
        id: runner
        function exec(cmd) { Quickshell.execDetached(cmd); }
    }
}
