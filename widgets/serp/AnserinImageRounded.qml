import QtQuick
import "."
import "shim"

SerpCard {
    face: "faces/ImageFaceRounded.qml"
    designW: 300
    designH: 200
    brackets: false
    faceProps: ({ imagePath: Config.getSetting("imageWidgetPath", "") })
}
