import QtQuick
import ".."

// Interloper widget: a small Outer Wilds card that opens the Rumor Map when clicked.
// Used by WidgetLayer.qml as the source of "in_a". Everything it shows comes from RumorData:
// the unread count, and a scrolling line with the newest notification.
WidgetCard {
    id: w
    title: "SHIP LOG"
    designW: 250
    designH: 132

    // mini rumor map glyph: three linked cards
    Item {
        id: glyph
        width: Math.round(64 * w.ui)
        height: Math.round(48 * w.ui)
        y: Math.round(2 * w.ui)

        readonly property int cw: Math.round(20 * w.ui)
        readonly property int ch: Math.round(14 * w.ui)
        readonly property int lw: Math.max(1, Math.round(w.ui))

        Rectangle { x: glyph.cw - 2; y: Math.round(glyph.ch / 2); width: Math.round(14 * w.ui); height: glyph.lw; color: "#668A7F66" }
        Rectangle { x: Math.round(glyph.width / 2); y: glyph.ch; width: glyph.lw; height: Math.round(13 * w.ui); color: "#668A7F66" }
        Rectangle { x: 0; y: 0; width: glyph.cw; height: glyph.ch; color: "#0A0B10"; border.width: glyph.lw; border.color: "#3FBF6A" }
        Rectangle { x: glyph.width - glyph.cw; y: Math.round(glyph.ch / 2) - Math.round(4 * w.ui); width: glyph.cw; height: glyph.ch; color: "#0A0B10"; border.width: glyph.lw; border.color: "#E8883A" }
        Rectangle { x: Math.round(glyph.width / 2) - Math.round(glyph.cw / 2); y: glyph.height - glyph.ch; width: glyph.cw; height: glyph.ch; color: "#0A0B10"; border.width: glyph.lw; border.color: w.cGold }
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: Math.round(14 * w.ui)
        anchors.right: parent.right
        y: 0
        spacing: Math.round(2 * w.ui)

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: RumorData.unreadCount
            color: RumorData.unreadCount > 0 ? w.cGold : w.cDim
            font.family: "monospace"
            font.bold: true
            font.pixelSize: Math.max(10, Math.round(26 * w.ui))
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: RumorData.unreadCount === 1 ? "UNREAD RUMOR" : "UNREAD RUMORS"
            color: w.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(10 * w.ui))
            font.letterSpacing: 2 * w.ui
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: "OPEN  [" + RumorData.toggleKey + "]"
            color: w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(9 * w.ui))
            font.letterSpacing: 1 * w.ui
        }
    }

    // newest notification, scrolling when it is longer than the card. The animation only runs while the card is visible
    // (WidgetSlot hides the card when its planet is off-focus), so it costs nothing otherwise.
    Rectangle {
        id: tickerBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(16 * w.ui)
        color: "#26E6D5B8"
        clip: true

        Text {
            id: tickerText
            property real off: 0
            readonly property real overflow: Math.max(0, implicitWidth - (tickerBox.width - Math.round(12 * w.ui)))
            x: Math.round(6 * w.ui - off)
            anchors.verticalCenter: parent.verticalCenter
            text: RumorData.latestLine
            color: w.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(10 * w.ui))
            onTextChanged: off = 0

            SequentialAnimation {
                loops: Animation.Infinite
                running: tickerText.overflow > 0 && w.visible
                onRunningChanged: if (!running) tickerText.off = 0
                PauseAnimation { duration: 1600 }
                NumberAnimation { target: tickerText; property: "off"; to: tickerText.overflow; duration: Math.max(400, tickerText.overflow * 28) }
                PauseAnimation { duration: 1400 }
                NumberAnimation { target: tickerText; property: "off"; to: 0; duration: 450 }
            }
        }
    }

    // a gold outline flashes once when a new notification arrives (a colour flash, so text stays crisp)
    Rectangle {
        id: flash
        objectName: "rumorFlash"
        anchors.fill: parent
        anchors.margins: -Math.round(8 * w.ui)
        color: "transparent"
        border.color: w.cGold
        border.width: Math.max(1, Math.round(2 * w.ui))
        opacity: 0
        NumberAnimation {
            id: flashAnim
            target: flash
            property: "opacity"
            from: 1
            to: 0
            duration: 900
            easing.type: Easing.OutQuad
        }
    }
    Connections {
        target: RumorData
        function onArrived(n) { flashAnim.restart(); }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: RumorData.toggle()
    }
}
