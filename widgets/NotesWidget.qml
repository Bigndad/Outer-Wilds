import QtQuick
import QtQuick.Controls
import ".."

// ATTLEROCK: quick notes / scratchpad
WidgetCard {
    id: w
    title: "SCRATCHPAD"
    designW: 280
    designH: 214

    property var cfg: ({ placeholder: "quick notes...", fontSize: 14, textColor: "#E6D5B8",
                         font: "monospace", showFooter: true, countMode: "chars" })

    readonly property bool wantsHold: area.activeFocus
    readonly property string countText: {
        const s = WidgetData.notesText || "";
        if (w.cfg.countMode === "words") {
            const n = s.trim() === "" ? 0 : s.trim().split(/\s+/).length;
            return n + (n === 1 ? " WORD" : " WORDS");
        }
        return s.length + " CHARS";
    }

    ScrollView {
        anchors.fill: parent
        anchors.bottomMargin: w.cfg.showFooter !== false ? 22 * w.ui : 0
        clip: true

        TextArea {
            id: area
            text: WidgetData.notesText
            wrapMode: TextEdit.Wrap
            color: w.cfg.textColor || w.cCream
            selectByMouse: true
            font.family: w.cfg.font || "monospace"
            font.pixelSize: Math.max(8, Math.round((w.cfg.fontSize || 14) * w.ui))
            placeholderText: w.cfg.placeholder !== undefined ? w.cfg.placeholder : "quick notes..."
            placeholderTextColor: "#6A634F"
            background: null
            onTextChanged: if (activeFocus) WidgetData.setNotes(text)
            Keys.onEscapePressed: {
                if (w.rig) w.rig.forceActiveFocus();
                else focus = false;
            }
        }
    }

    Item {
        visible: w.cfg.showFooter !== false
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 18 * w.ui

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: w.countText
            color: w.cDim
            font.family: w.cfg.font || "monospace"
            font.pixelSize: Math.max(7, Math.round(10 * w.ui))
        }
        Text {
            id: clearTxt
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "CLEAR"
            color: clearHover.containsMouse ? w.cGold : w.cDim
            font.family: w.cfg.font || "monospace"
            font.pixelSize: Math.max(7, Math.round(10 * w.ui))
            font.letterSpacing: 1 * w.ui
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
