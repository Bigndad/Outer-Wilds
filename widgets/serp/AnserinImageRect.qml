import QtQuick
import "."
import "shim"

SerpCard {
    face: "faces/ImageFaceRect.qml"
    designW: 300
    designH: 200
    brackets: false
    faceProps: ({ imagePath: Config.getSetting("imageWidgetPath", "") })
}
