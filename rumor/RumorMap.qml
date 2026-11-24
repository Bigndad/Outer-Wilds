import QtQuick
import ".."

// Rumor Map (ship log) overlay host. Put ONE of these inside CameraRig, above everything else:
//
//     RumorMap { anchors.fill: parent; rig: root }
//
// What it does:
//   * z 40000: above WidgetLayer (29000), the HUD (26000) and the debug panel (32000).
//   * Open/close state lives in RumorData.open; this item reacts to it. Anything can toggle it:
//     the window shortcut below, the Interloper widget (RumorWidget.qml), a Hyprland global shortcut, IPC.
//   * Opening pauses the solar system through the existing rig.active (it stops the FrameAnimation and hides the
//     widget layer) and gives THIS item the keyboard focus. Closing restores rig.active to what it was and hands the
//     focus back to the rig.
//   * Input: every key goes to this item and is accepted (so none bubbles up to the rig's Keys handler), and the
//     view's full-screen MouseArea takes every button, move and wheel event (so none reaches the rig's MouseArea).
//   * The heavy part (RumorMapView) is created by a Loader only while open: idle cost with the map closed is this
//     one empty Item, one Shortcut and a hidden toast (its animation only runs for ~3 s after a notification arrives).
//   * "SHIP LOG UPDATED" toast: shown when a new notification arrives while the map is closed.
Item {
    id: host

    property var rig: null                  // the CameraRig
    property bool shown: false              // the view exists (open, or still fading out)
    property bool _paused: false
    property bool _savedActive: true

    z: 40000

    Shortcut {
        // Window-wide key. It does not fire while a text field (e.g. the Notes widget) is being typed in.
        sequence: RumorData.toggleKey
        enabled: !RumorData.typing              // typing a search must not toggle the map
        autoRepeat: false
        onActivated: RumorData.toggle()
    }

    function applyOpen() {
        if (RumorData.open) {
            if (rig && !_paused) {
                _savedActive = rig.active;
                rig.active = false;                 // stage-5 mechanism: stops the frame loop, hides the widgets
                rig.hoveredPlanetId = "";           // no stale hover ring left behind the overlay
                rig.isInteracting = false;
                rig.actDown = ({});                 // no thrust key stays "held" across the pause
                rig.heldBy = ({});
                _paused = true;
            }
            shown = true;
            forceActiveFocus();
        } else if (_paused && rig) {
            rig.active = _savedActive;
            _paused = false;
            rig.forceActiveFocus();
        }
    }

    Connections {
        target: RumorData
        function onOpenChanged() { host.applyOpen(); }
    }
    Component.onCompleted: applyOpen()

    Keys.onPressed: (event) => {
        if (ld.item) ld.item.handleKey(event);
        event.accepted = true;                      // never let a key bubble up to the rig
    }
    Keys.onReleased: (event) => { event.accepted = true; }

    Loader {
        id: ld
        anchors.fill: parent
        active: host.shown
        source: "RumorMapView.qml"
    }
    Connections {
        target: ld.item
        function onFaded() { host.shown = false; }
    }

    // ---------------- "SHIP LOG UPDATED" toast ----------------
    // Input-transparent while hidden. Auto-hides when WidgetConfig.notifAutoHide is true,
    // or stays visible until clicked / dismissed / Ship Log opened.
    Rectangle {
        id: toast
        objectName: "rumorToast"
        readonly property real bu: Math.max(0.75, Math.round(host.height / 1080 * 16) / 16)
        readonly property color accent: critical ? "#E2554C" : "#D4AF37"
        property string detail: ""
        property bool critical: false
        property bool sticky: false
        opacity: 0
        visible: opacity > 0.005
        width: Math.round(Math.max(tTitle.implicitWidth, tDetail.implicitWidth, sticky ? tHint.implicitWidth : 0) + (sticky ? 72 : 48) * bu)
        height: Math.round(tCol.implicitHeight + 22 * bu)
        x: Math.round((host.width - width) / 2)
        y: Math.round(48 * bu - (1 - opacity) * 14 * bu)
        radius: Math.round(4 * bu)
        color: toastMa.containsMouse ? "#F40C101B" : "#EA07080C"
        border.width: Math.max(1, Math.round(bu))
        border.color: accent

        // Left urgency accent strip
        Rectangle {
            x: parent.border.width
            y: parent.border.width
            width: Math.max(3, Math.round(3 * toast.bu))
            height: parent.height - parent.border.width * 2
            color: toast.accent
        }

        // Subtle Outer Wilds corner brackets
        Repeater {
            model: 4
            delegate: Item {
                required property int index
                readonly property bool atR: index === 1 || index === 3
                readonly property bool atB: index === 2 || index === 3
                readonly property int arm: Math.round(8 * toast.bu)
                readonly property int th: Math.max(1, Math.round(1.5 * toast.bu))
                width: arm; height: arm
                x: atR ? toast.width - arm + Math.round(3 * toast.bu) : -Math.round(3 * toast.bu)
                y: atB ? toast.height - arm + Math.round(3 * toast.bu) : -Math.round(3 * toast.bu)
                Rectangle { width: parent.width; height: parent.th; y: parent.atB ? parent.height - height : 0; color: toast.accent }
                Rectangle { height: parent.height; width: parent.th; x: parent.atR ? parent.width - width : 0; color: toast.accent }
            }
        }

        Column {
            id: tCol
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(22 * toast.bu)
            spacing: Math.round(4 * toast.bu)
            Text {
                id: tTitle
                text: toast.critical ? "SHIP LOG UPDATED  -  CRITICAL" : "SHIP LOG UPDATED"
                color: toast.accent
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(13 * toast.bu))
                font.letterSpacing: 3.5 * toast.bu
            }
            Text {
                id: tDetail
                width: Math.min(implicitWidth, Math.round(520 * toast.bu))
                text: toast.detail
                elide: Text.ElideRight
                color: "#E6D5B8"
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(11 * toast.bu))
            }
            Text {
                id: tHint
                visible: toast.sticky
                text: "CLICK TO OPEN SHIP LOG"
                color: "#8A7F66"
                font.family: "monospace"
                font.pixelSize: Math.max(7, Math.round(9 * toast.bu))
                font.letterSpacing: 1.5 * toast.bu
            }
        }

        MouseArea {
            id: toastMa
            anchors.fill: parent
            enabled: toast.visible
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                toast.hideNow();
                RumorData.show();
            }
        }

        // Manual close button when auto-hide is off
        Rectangle {
            visible: toast.sticky
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(8 * toast.bu)
            width: Math.round(20 * toast.bu)
            height: width
            radius: Math.round(3 * toast.bu)
            color: closeMa.containsMouse ? "#33D4AF37" : "transparent"
            border.width: 1
            border.color: closeMa.containsMouse ? toast.accent : "#44D4AF37"
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeMa.containsMouse ? toast.accent : "#8A7F66"
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(10 * toast.bu))
            }
            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    toast.sticky = false;
                    toastAutoAnim.stop();
                    toastInAnim.stop();
                    toastOutAnim.restart();
                }
            }
        }

        function hideNow() {
            sticky = false;
            toastAutoAnim.stop();
            toastInAnim.stop();
            toastOutAnim.stop();
            opacity = 0;
        }

        SequentialAnimation {
            id: toastAutoAnim
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
            PauseAnimation { duration: Math.round(WidgetConfig.notifHideSec * 1000) }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 700; easing.type: Easing.InQuad }
        }
        NumberAnimation { id: toastInAnim; target: toast; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { id: toastOutAnim; target: toast; property: "opacity"; to: 0; duration: 350; easing.type: Easing.InQuad }
    }
    Connections {
        target: RumorData
        function onArrived(n) {
            if (RumorData.open) return;             // the card appears on the map you are looking at
            toast.detail = n.app + ": " + n.summary;
            toast.critical = n.urgency === "critical";
            toastAutoAnim.stop(); toastInAnim.stop(); toastOutAnim.stop();
            if (WidgetConfig.notifAutoHide) {
                toast.sticky = false;
                toastAutoAnim.restart();
            } else {
                toast.sticky = true;
                toastInAnim.restart();
            }
        }
        function onOpenChanged() { if (RumorData.open) toast.hideNow(); }
        function onCleared() { toast.hideNow(); }
    }
    Connections {
        target: WidgetConfig
        function onNotifAutoHideChanged() {
            if (WidgetConfig.notifAutoHide && toast.sticky) {
                toast.sticky = false;
                toastOutAnim.restart();
            }
        }
    }
}
