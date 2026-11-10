import QtQuick

// Minimal stand-in for Serpantinum's ClickButton (only the lyrics face's "select a local file" button uses it).
Rectangle {
    id: root
    property string buttonText: ""
    property string buttonIcon: ""
    property real horizontalPadding: 12
    property real cornerRadius: 8
    property real iconFontSize: 14
    property real textFontSize: 11
    property color accentColor: ThemeBackend.surface0
    property real bgOpacity: 1.0
    property color textColor: ThemeBackend.text
    signal clicked()

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: 28
    radius: cornerRadius
    color: Qt.alpha(area.containsMouse ? ThemeBackend.surface1 : accentColor, bgOpacity)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.buttonIcon !== ""
            text: root.buttonIcon
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.iconFontSize
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.buttonText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.textFontSize
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
