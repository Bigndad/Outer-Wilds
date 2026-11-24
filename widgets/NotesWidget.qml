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
    readonly property string _typingKey: "notes_" + Math.random().toString(36).slice(2)
    readonly property color effTextCol: (cfg.textColor && cfg.textColor.toUpperCase() !== "#E6D5B8") ? cfg.textColor : w.cCream
    readonly property string effNotesFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont
    readonly property string countText: {
        const s = WidgetData.notesText || "";
        if (w.cfg.countMode === "words") {
            const n = s.trim() === "" ? 0 : s.trim().split(/\s+/).length;
            return n + (n === 1 ? " WORD" : " WORDS");
        }
        return s.length + " CHARS";
    }

    // Swallow any unconsumed keys (Shift, Ctrl, etc.) so nothing bubbles to CameraRig while typing
    Keys.onPressed: (event) => { if (area.activeFocus) event.accepted = true; }
    Keys.onReleased: (event) => { if (area.activeFocus) event.accepted = true; }
    Component.onDestruction: WidgetConfig.setWidgetTyping(_typingKey, false)

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: w.cfg.showFooter !== false ? 22 * w.ui : 0
        radius: 4 * w.ui
        color: "#22000000"
        border.width: Math.max(1, Math.round(w.ui))
        border.color: area.activeFocus ? w.accent : Qt.rgba(w.cDim.r, w.cDim.g, w.cDim.b, 0.2)

        ScrollView {
            anchors.fill: parent
            anchors.margins: 4 * w.ui
            clip: true

            TextArea {
                id: area
                text: WidgetData.notesText
                wrapMode: TextEdit.Wrap
                color: w.effTextCol
                selectByMouse: true
                font.family: w.effNotesFont
                font.pixelSize: Math.max(8, Math.round((w.cfg.fontSize || 14) * w.ui))
                placeholderText: w.cfg.placeholder !== undefined ? w.cfg.placeholder : "quick notes..."
                placeholderTextColor: w.cDim
                background: null
                onActiveFocusChanged: WidgetConfig.setWidgetTyping(w._typingKey, activeFocus)
                onTextChanged: if (activeFocus) WidgetData.setNotes(text)
                Keys.onEscapePressed: (event) => {
                    event.accepted = true;
                    focus = false;
                    WidgetConfig.setWidgetTyping(w._typingKey, false);
                    if (w.rig) w.rig.forceActiveFocus();
                }
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
            text: area.activeFocus ? "TYPING  ·  ESC TO EXIT" : w.countText
            color: area.activeFocus ? w.accent : w.cDim
            font.family: w.effNotesFont
            font.pixelSize: Math.max(7, Math.round(9 * w.ui))
        }
        Text {
            id: clearTxt
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "CLEAR"
            color: clearHover.containsMouse ? w.accent : w.cDim
            font.family: w.effNotesFont
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
