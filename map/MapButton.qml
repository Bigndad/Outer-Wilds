import QtQuick
import ".."

// Small bracketed button in the WidgetCard palette: "<label>  [KEY]".
Item {
    id: btn

    property string label: ""
    property string hint: ""            // key shown in brackets, "" = none
    property real bu: 1.0
    property bool primary: false        // gold text instead of cream
    signal clicked()

    readonly property color cCream: "#E6D5B8"
    readonly property color cGold: "#D4AF37"
    readonly property color cDim: "#8A7F66"
    readonly property bool lit: ma.containsMouse && enabled

    implicitWidth: Math.round(txt.implicitWidth + 36 * bu)
    implicitHeight: Math.round(40 * bu)
    width: implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : 0.7

    Rectangle {
        anchors.fill: parent
        radius: 4 * btn.bu
        color: btn.lit ? "#30D4AF37" : "#B007080C"
        border.width: Math.max(1, Math.round(btn.bu))
        border.color: btn.lit ? btn.cGold : "#66D4AF37"
    }
    Text {
        id: txt
        anchors.centerIn: parent
        text: btn.label + (btn.hint !== "" ? "   [" + btn.hint + "]" : "")
        color: !btn.enabled ? btn.cDim : (btn.primary || btn.lit ? btn.cGold : btn.cCream)
        font.family: "monospace"
        font.pixelSize: Math.max(10, Math.round(16 * btn.bu))
        font.letterSpacing: 1 * btn.bu
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: btn.clicked()
    }
}
