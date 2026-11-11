import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// ATTLEROCK: the wallpaper you last applied from the picker. Click opens the full picker.
WidgetCard {
    id: w
    title: "WALLPAPER"
    designW: 250
    designH: 150

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: Quickshell.env("WALLPAPER_DIR") || (home + "/Pictures/Wallpapers")
    property string current: ""

    Process {
        id: reader
        command: ["sh", "-c", 'f=$(ls -t "${XDG_CACHE_HOME:-$HOME/.cache}"/outerwilds/wallpaper/current_*_name 2>/dev/null | head -1); [ -n "$f" ] && cat "$f"']
        stdout: StdioCollector { onStreamFinished: w.current = text.trim() }
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: reader.running = true }

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 20 * w.ui
        color: "#0C0D12"
        clip: true
        Image {
            anchors.fill: parent
            visible: w.current !== ""
            source: w.current !== "" ? "file://" + encodeURI(w.dir + "/" + w.current) : ""
            fillMode: Image.PreserveAspectCrop
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
            font.pixelSize: Math.round(12 * w.ui)
        }
    }
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        text: w.current !== "" ? w.current : "no wallpaper chosen yet"
        elide: Text.ElideMiddle
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.round(10 * w.ui)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "wallpaper", "toggle"])
    }
}
