pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Serpantinum's settings store. Optional overrides live in ~/.config/outerwilds/settings.json, e.g.
//   { "wallpaperDir": "/home/you/Pictures/Wallpapers" }
Singleton {
    id: root
    property var rawSettings: ({})
    signal settingsLoaded()
    function getSetting(key, fallback) {
        const v = rawSettings ? rawSettings[key] : undefined;
        return (v === undefined || v === null) ? fallback : v;
    }
    function setSetting(key, value) {      // in memory only (the wellbeing limits UI is not ported)
        const n = Object.assign({}, rawSettings); n[key] = value; rawSettings = n;
    }
    FileView {
        path: (Quickshell.env("HOME") || "") + "/.config/outerwilds/settings.json"
        printErrors: false
        onLoaded: {
            try { root.rawSettings = JSON.parse(text()); } catch (e) { root.rawSettings = ({}); }
            root.settingsLoaded();
        }
    }
}
