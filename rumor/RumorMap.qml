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
                rig.keysDown = ({});                // no thrust key stays "held" across the pause
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
    // Input-transparent (no MouseArea). Hidden, and its animation idle, except for ~3 s after an arrival.
    Rectangle {
        id: toast
        objectName: "rumorToast"
        readonly property real bu: Math.max(0.75, Math.round(host.height / 1080 * 16) / 16)
        property string detail: ""
        property bool critical: false
        opacity: 0
        visible: opacity > 0.005
        width: Math.round(Math.max(tTitle.implicitWidth, tDetail.implicitWidth) + 44 * bu)
        height: Math.round(tTitle.implicitHeight + tDetail.implicitHeight + 24 * bu)
        x: Math.round((host.width - width) / 2)
        y: Math.round(48 * bu)
        color: "#EA07080C"
        border.width: Math.max(1, Math.round(bu))
        border.color: critical ? "#E2554C" : "#D4AF37"

        Column {
            anchors.centerIn: parent
            spacing: Math.round(4 * toast.bu)
            Text {
                id: tTitle
                anchors.horizontalCenter: parent.horizontalCenter
                text: toast.critical ? "SHIP LOG UPDATED  -  CRITICAL" : "SHIP LOG UPDATED"
                color: toast.critical ? "#E2554C" : "#D4AF37"
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(14 * toast.bu))
                font.letterSpacing: 4 * toast.bu
            }
            Text {
                id: tDetail
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, Math.round(520 * toast.bu))
                text: toast.detail
                elide: Text.ElideRight
                color: "#E6D5B8"
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(11 * toast.bu))
            }
        }

        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 2400 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 700; easing.type: Easing.InQuad }
        }
    }
    Connections {
        target: RumorData
        function onArrived(n) {
            if (RumorData.open) return;             // the card appears on the map you are looking at
            toast.detail = n.app + ": " + n.summary;
            toast.critical = n.urgency === "critical";
            toastAnim.restart();
        }
    }
}
