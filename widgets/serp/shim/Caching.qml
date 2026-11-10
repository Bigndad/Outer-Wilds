pragma Singleton
import QtQuick
QtObject {
    // folder that contains assets/shaders (the parent of shim/)
    readonly property string serpantinumDir: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/+$/, "")
    function getCacheDir() { return "/tmp"; }
}
