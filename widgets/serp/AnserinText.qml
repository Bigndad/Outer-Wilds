import QtQuick
import "."
import "shim"

SerpCard {
    face: "faces/TextFace.qml"
    designW: 320
    designH: 90
    brackets: false
    faceProps: ({ textContent: Config.getSetting("textWidget", "Outer Wilds") })
}
