import QtQuick
import QtQuick.Window

// Same interface as Anserin's WallpaperMedia (path, active, crop, ready, failed, painted size),
// pictures and gifs only (no QtMultimedia needed).
Item {
    id: root
    property string path: ""
    property bool active: visible
    property bool crop: true
    readonly property url mediaUrl: {
        if (!path) return "";
        if (path.startsWith("file://")) return path;
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    readonly property bool isGif: /\.gif$/i.test(path)
    readonly property bool failed: loader.item ? loader.item.status === Image.Error : false
    readonly property bool ready: loader.item ? loader.item.status === Image.Ready : false
    readonly property real paintedWidth: loader.item ? loader.item.paintedWidth : 0
    readonly property real paintedHeight: loader.item ? loader.item.paintedHeight : 0

    Loader {
        id: loader
        anchors.fill: parent
        active: root.active && root.path !== ""
        sourceComponent: root.isGif ? gifC : imgC
    }
    Component {
        id: imgC
        Image {
            source: root.mediaUrl
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            asynchronous: true
            cache: false
            mipmap: true
        }
    }
    Component {
        id: gifC
        AnimatedImage {
            source: root.mediaUrl
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: false
            playing: root.active
        }
    }
}
