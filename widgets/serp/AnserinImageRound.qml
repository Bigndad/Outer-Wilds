import QtQuick
import "."
import "shim"

SerpCard {
    face: "faces/ImageFaceRound.qml"
    designW: 200
    designH: 200
    brackets: false
    faceProps: ({ imagePath: Config.getSetting("imageWidgetPath", "") })
}
