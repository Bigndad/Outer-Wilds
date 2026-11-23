pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cache / runtime folders in Serpantinum's API, rooted in our own config's names.
Singleton {
    id: root
    // folder that contains assets/ and scripts/ (the parent of shim/)
    readonly property string serpantinumDir: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/+$/, "")
    readonly property string qsDir: serpantinumDir
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string cacheRoot: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/outerwilds"
    readonly property string runRoot: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/outerwilds"
    readonly property string stateRoot: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/outerwilds"
    readonly property string runDir: runRoot
    readonly property string logDir: runRoot + "/log"
    function getCacheDir(name) { return name ? cacheRoot + "/" + name : cacheRoot; }
    function getRunDir(name) { return name ? runRoot + "/" + name : runRoot; }
    function getStateDir(name) { return name ? stateRoot + "/" + name : stateRoot; }

    Process {
        running: true
        command: ["mkdir", "-p", root.cacheRoot + "/wallpaper", root.runRoot + "/wallpaper", root.runRoot + "/focustime",
                  root.runRoot + "/music", root.runRoot + "/log", root.stateRoot + "/focustime"]
    }
}
