import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// ATTLEROCK: the wallpaper you last applied from the picker. Click opens the full picker.
WidgetCard {
    id: w
    title: "WALLPAPER"
    designW: 260
    designH: 150

    property var cfg: ({ fillMode: "crop", showFilename: true, imageRadius: 0, pollSec: 4 })

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: Quickshell.env("WALLPAPER_DIR") || (home + "/Pictures/Wallpapers")
    property string current: ""

    Process {
        id: reader
        command: ["sh", "-c", 'f=$(ls -t "${XDG_CACHE_HOME:-$HOME/.cache}"/outerwilds/wallpaper/current_*_name 2>/dev/null | head -1); [ -n "$f" ] && cat "$f"']
        stdout: StdioCollector { onStreamFinished: w.current = text.trim() }
    }
    Timer {
        interval: Math.max(1000, Math.round((w.cfg.pollSec || 4) * 1000))
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: w.cfg.showFilename !== false ? 20 * w.ui : 0
        radius: Math.round((w.cfg.imageRadius || 0) * w.ui)
        color: "#0C0D12"
        clip: true
        Image {
            anchors.fill: parent
            visible: w.current !== ""
            source: w.current !== "" ? "file://" + encodeURI(w.dir + "/" + w.current) : ""
            fillMode: w.cfg.fillMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 500
            sourceSize.height: 300
        }
        Text {
            anchors.centerIn: parent
            visible: w.current === ""
            text: "OPEN PICKER"
            color: w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(12 * w.ui))
        }
    }
    Text {
        visible: w.cfg.showFilename !== false
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        text: w.current !== "" ? w.current : "no wallpaper chosen yet"
        elide: Text.ElideMiddle
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.max(7, Math.round(10 * w.ui))
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "wallpaper", "toggle"])
    }
}
