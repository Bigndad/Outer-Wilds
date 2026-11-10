import QtQuick
import ".."

// Orbiting card on Timber Hearth: shows how many signals are in range and equips / stows the signalscope.
// Only the button takes clicks; a double-click on the rest of the card still flies in (WidgetSlot handles that).
WidgetCard {
    id: w

    title: "SIGNALSCOPE"
    designW: 250
    designH: 112

    readonly property bool wantsHold: btnArea.containsMouse
    readonly property bool on: SignalscopeData.equipped
    readonly property int count: SignalscopeData.channels.length
    readonly property var tuned: SignalscopeData.lockedChannel

    Column {
        anchors.fill: parent
        spacing: 5 * w.ui

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: w.count === 0 ? "NO SIGNALS" : (w.count + (w.count === 1 ? " SIGNAL IN RANGE" : " SIGNALS IN RANGE"))
            color: w.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(12 * w.ui))
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: w.on ? (w.tuned ? ("TUNED: " + w.tuned.name) : "SCANNING...") : "STOWED"
            color: w.on && w.tuned ? w.cGold : w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(11 * w.ui))
        }
        Rectangle {
            width: Math.round(104 * w.ui)
            height: Math.round(26 * w.ui)
            color: btnArea.containsMouse ? "#33D4AF37" : "transparent"
            border.color: w.cGold
            border.width: Math.max(1, Math.round(w.ui))
            Text {
                anchors.centerIn: parent
                text: w.on ? "STOW" : "EQUIP"
                color: w.cGold
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(8, Math.round(12 * w.ui))
                font.letterSpacing: 2 * w.ui
            }
            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onClicked: SignalscopeData.dispatch("toggle")
            }
        }
    }
}
