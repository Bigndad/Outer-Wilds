import QtQuick
import QtQuick.Controls
import ".."

// ATTLEROCK: quick notes / scratchpad
WidgetCard {
    id: w
    title: "SCRATCHPAD"
    designW: 280
    designH: 214

    // the slot freezes the orbit while this is true
    readonly property bool wantsHold: area.activeFocus

    ScrollView {
        anchors.fill: parent
        anchors.bottomMargin: 22 * w.ui
        clip: true

        TextArea {
            id: area
            text: WidgetData.notesText
            wrapMode: TextEdit.Wrap
            color: w.cCream
            selectByMouse: true
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(14 * w.ui))
            placeholderText: "quick notes..."
            placeholderTextColor: "#6A634F"
            background: null
            onTextChanged: if (activeFocus) WidgetData.setNotes(text)
            Keys.onEscapePressed: {
                if (w.rig) w.rig.forceActiveFocus();
                else focus = false;
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 18 * w.ui
        spacing: 10 * w.ui

        Text {
            text: WidgetData.notesText.length + " CHARS"
            color: w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(7, Math.round(10 * w.ui))
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: parent.width - clearTxt.width - 100 * w.ui; height: 1 }
        Text {
            id: clearTxt
            text: "CLEAR"
            color: clearHover.containsMouse ? w.cGold : w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(7, Math.round(10 * w.ui))
            font.letterSpacing: 1 * w.ui
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                id: clearHover
                anchors.fill: parent
                anchors.margins: -4 * w.ui
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { WidgetData.setNotes(""); area.text = ""; }
            }
        }
    }
}
