import QtQuick
import "../shim"
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 30
    property real minHeight: 30
    property real maxWidth: 4000
    property real maxHeight: 4000
    property real minAspect: 0.02
    property real maxAspect: 50.0
    property bool isRound: false
    property bool cropImage: false

    property string imagePath: (typeof model !== "undefined" && model && model.wImagePath) ? model.wImagePath : (parent && parent.wImagePath ? parent.wImagePath : "")

    Rectangle {
        anchors.fill: parent
        color: root.imagePath === "" ? ThemeBackend.surface0 : "transparent"
        clip: true

        WallpaperMedia {
            id: srcImage
            anchors.fill: parent
            path: root.imagePath
            active: root.visible && root.imagePath !== ""
            crop: root.cropImage
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath === "" || !srcImage.ready

            Text {
                anchors.centerIn: parent
                text: "󰋩"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: Math.max(16, Math.min(root.width, root.height) * 0.35)
                color: ThemeBackend.subtext0
            }
        }
    }
}
