import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// ATTLEROCK: the wallpaper you last applied from the picker. Click opens the full picker.
WidgetCard {
    id: w
    title: "WALLPAPER"
    designW: 260
    designH: 158

    property var cfg: ({ fillMode: "crop", showFilename: true, imageRadius: 4, pollSec: 4 })

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: Quickshell.env("WALLPAPER_DIR") || (home + "/Pictures/Wallpapers")
    property string currentPath: ""
    readonly property string currentLabel: {
        if (!currentPath) return "";
        const prefix = dir.endsWith("/") ? dir : (dir + "/");
        if (currentPath.startsWith(prefix)) return currentPath.substring(prefix.length);
        const idx = currentPath.lastIndexOf("/");
        return idx >= 0 ? currentPath.substring(idx + 1) : currentPath;
    }

    Process {
        id: reader
        command: [
            "sh", "-c",
            'dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"; ' +
            'f=$(ls -t "${XDG_CACHE_HOME:-$HOME/.cache}"/outerwilds/wallpaper/current_*_name 2>/dev/null | head -1); ' +
            '[ -z "$f" ] && exit 0; ' +
            'val=$(tr -d "\r\n" < "$f"); [ -z "$val" ] && exit 0; ' +
            'if [ -f "$val" ]; then printf "%s\n" "$val"; ' +
            'elif [ -f "$dir/$val" ]; then printf "%s\n" "$dir/$val"; ' +
            'else found=$(find "$dir" -maxdepth 6 -type f -name "$(basename "$val")" 2>/dev/null | head -1); ' +
            '[ -n "$found" ] && printf "%s\n" "$found" || printf "%s\n" "$dir/$val"; fi'
        ]
        stdout: StdioCollector { onStreamFinished: w.currentPath = text.trim() }
    }
    Timer {
        interval: Math.max(1000, Math.round((w.cfg.pollSec || 4) * 1000))
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.bottomMargin: w.cfg.showFilename !== false ? 22 * w.ui : 0
        radius: Math.round((w.cfg.imageRadius !== undefined ? w.cfg.imageRadius : 4) * w.ui)
        color: "#090A0E"
        border.width: Math.max(1, Math.round(w.ui))
        border.color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.25)
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: Math.max(1, Math.round(w.ui))
            visible: w.currentPath !== ""
            source: w.currentPath !== "" ? "file://" + encodeURI(w.currentPath) : ""
            fillMode: w.cfg.fillMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 500
            sourceSize.height: 300
        }
        Text {
            anchors.centerIn: parent
            visible: w.currentPath === ""
            text: "OPEN PICKER"
            color: w.cDim
            font.family: w.effFont
            font.pixelSize: Math.max(8, Math.round(11 * w.ui))
            font.letterSpacing: 1.5 * w.ui
        }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 5 * w.ui
            width: badgeTxt.implicitWidth + 10 * w.ui
            height: badgeTxt.implicitHeight + 4 * w.ui
            radius: 3 * w.ui
            color: "#CC090B10"
            border.width: Math.max(1, Math.round(w.ui))
            border.color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.45)

            Text {
                id: badgeTxt
                anchors.centerIn: parent
                text: "PICKER ↗"
                color: w.accent
                font.family: w.effFont
                font.bold: true
                font.pixelSize: Math.max(7, Math.round(8 * w.ui))
                font.letterSpacing: 1 * w.ui
            }
        }
    }

    Rectangle {
        visible: w.cfg.showFilename !== false
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 18 * w.ui
        radius: 3 * w.ui
        color: "#1F000000"

        Text {
            anchors.fill: parent
            anchors.leftMargin: 6 * w.ui
            anchors.rightMargin: 6 * w.ui
            verticalAlignment: Text.AlignVCenter
            text: w.currentLabel !== "" ? w.currentLabel : "no wallpaper chosen yet"
            elide: Text.ElideMiddle
            color: w.cDim
            font.family: w.effFont
            font.pixelSize: Math.max(7, Math.round(9 * w.ui))
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "wallpaper", "toggle"])
    }
}
