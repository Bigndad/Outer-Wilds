import QtQuick

Item {
    id: l
    property color color: Theme.accent
    implicitWidth: 28
    implicitHeight: 28
    width: 28
    height: 28
    MaterialShape {
        anchors.centerIn: parent
        width: 22
        height: 22
        shape: "cookie9"
        color: l.color
        RotationAnimation on rotation { from: 0; to: 360; duration: 2400; loops: Animation.Infinite; running: l.visible }
    }
}
