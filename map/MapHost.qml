import QtQuick
import ".."

// Map View (ship log map) overlay host. Put ONE of these inside CameraRig, after RumorMap:
//
//     MapHost { anchors.fill: parent; rig: root }
//
// What it does (same pattern as RumorMap.qml):
//   * z 29500: above WidgetLayer (29000), below the Signalscope (30000) and the Rumor Map (40000).
//   * Open/close state lives in MapData.open; this item reacts to it. Anything can toggle it: the N shortcut below, a
//     Hyprland global shortcut, IPC, another widget.
//   * Opening pauses the solar system through rig.active (stops the FrameAnimation, hides the widget layer) and takes the
//     keyboard focus. Closing restores rig.active to what it was and hands the focus back to the rig.
//   * Input: every key goes to this item and is accepted (none bubbles up to the rig); the view's full-screen MouseArea takes
//     every button, move and wheel event (none reaches the rig's MouseArea).
//   * The Signalscope is stowed while the map is open (it would draw over the map) and re-equipped when it closes.
//   * The heavy part (MapView) is created by a Loader only while open: idle cost with the map closed is this one empty Item
//     and one Shortcut.
//   * Rumor Mode: the Rumor Map opens on top (it is the existing RumorMap, untouched) and this map hides, not closes. The
//     "Back to Map" chip (MapReturnChip.qml) or N returns; L / Esc in the Rumor Map close both.
Item {
    id: host

    property var rig: null                  // the CameraRig
    property bool shown: false              // the view exists (open, or still fading out)
    property bool _paused: false
    property bool _savedActive: true
    property bool _scopeWas: false

    z: 29500

    Shortcut {
        // Window-wide key; does not fire while a text field is being typed in. Inside Rumor Mode it means "Back to Map".
        sequence: MapData.toggleKey
        enabled: !RumorData.typing && (!RumorData.open || MapData.rumorMode)
        autoRepeat: false
        onActivated: { if (MapData.rumorMode) MapData.backToMap(); else MapData.toggle(); }
    }

    function regrab() { if (MapData.open && !MapData.rumorMode) forceActiveFocus(); }

    function applyOpen() {
        if (MapData.open) {
            if (rig && !_paused) {
                _savedActive = rig.active;
                rig.active = false;                 // stage-5 mechanism: stops the frame loop, hides the widgets
                rig.hoveredPlanetId = "";           // no stale hover ring left behind the overlay
                rig.isInteracting = false;
                rig.keysDown = ({});                // no thrust key stays "held" across the pause
                _paused = true;
                _scopeWas = SignalscopeData.equipped;
                if (_scopeWas) SignalscopeData.dispatch("unequip");
            }
            shown = true;
            forceActiveFocus();
        } else if (_paused && rig) {
            const restore = _savedActive;
            rig.active = restore;
            // The Rumor Map restores rig.active to what IT saw when it opened (false, because this map had paused the rig).
            // Whichever of the two handlers runs last would win, so set it once more after both are done.
            Qt.callLater(function () { if (!MapData.open && !RumorData.open && host.rig) host.rig.active = restore; });
            _paused = false;
            if (_scopeWas) { SignalscopeData.dispatch("equip"); _scopeWas = false; }
            rig.forceActiveFocus();
        }
    }

    Connections {
        target: MapData
        function onOpenChanged() { host.applyOpen(); }
    }
    Component.onCompleted: applyOpen()

    // Rumor Mode bookkeeping: the Rumor Map opened (button, or its own L key) / closed
    Connections {
        target: RumorData
        function onOpenChanged() {
            if (RumorData.open) {
                if (MapData.open && !MapData.rumorMode) MapData.rumorMode = true;
            } else if (MapData.rumorMode) {
                if (MapData.returning) {
                    MapData.returning = false;
                    MapData.rumorMode = false;
                    Qt.callLater(host.regrab);      // after the Rumor Map has handed the focus to the rig
                } else {
                    // L / Esc inside the Rumor Map: leave both. Deferred so the Rumor Map has finished its own close
                    // (it hands the focus to the rig and restores rig.active) before this map restores them.
                    Qt.callLater(function () { if (MapData.rumorMode && !RumorData.open) MapData.hide(); });
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (ld.item) ld.item.handleKey(event);
        event.accepted = true;                      // never let a key bubble up to the rig
    }
    Keys.onReleased: (event) => { event.accepted = true; }

    Loader {
        id: ld
        anchors.fill: parent
        active: host.shown
        source: "MapView.qml"
    }
    Connections {
        target: ld.item
        function onFaded() { host.shown = false; }
    }
}
