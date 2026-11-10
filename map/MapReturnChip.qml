import QtQuick
import ".."

// "Back to Map" chip, shown only while the Rumor Map was entered from the Map View ("Rumor Mode").
// Put ONE of these inside CameraRig, after RumorMap and MapHost:
//
//     MapReturnChip { anchors.fill: parent }
//
// It lives in its own item because MapHost (z 29500) sits below the Rumor Map (z 40000) and this must sit above it.
// Input-transparent except for the chip itself. N also returns (MapHost's shortcut).
Item {
    id: chip

    readonly property real bu: Math.max(0.75, Math.round(height / 1080 * 16) / 16)
    readonly property bool on: MapData.open && MapData.rumorMode && RumorData.open

    z: 40500

    MapButton {
        visible: chip.on
        bu: chip.bu
        primary: true
        label: "Back to Map"
        hint: "N"
        x: chip.width - width - Math.round(48 * chip.bu)        // bottom-right; move it if the Rumor Map uses that corner
        y: chip.height - height - Math.round(40 * chip.bu)
        onClicked: MapData.backToMap()
    }
}
