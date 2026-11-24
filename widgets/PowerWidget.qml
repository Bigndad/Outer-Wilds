import QtQuick
import Quickshell
import ".."

WidgetCard {
    id: w
    title: "POWER"
    designW: 276
    designH: 160

    property var cfg: ({ requireConfirm: true, showLabels: true, dangerColor: "#E85D3F",
                         lockCmd: "", font: "monospace" })

    readonly property string effPowerFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont
    readonly property color effDanger: cfg.dangerColor || "#E85D3F"
    property string armedId: ""

    FontLoader {
        id: nfFont
        source: Qt.resolvedUrl("serp/assets/fonts/SymbolsNerdFontMono-Regular.ttf")
    }

    readonly property var actions: [
        { id: "lock",      label: "LOCK",      icon: String.fromCodePoint(0xF033E), danger: false },
        { id: "suspend",   label: "SUSPEND",   icon: String.fromCodePoint(0xF0904), danger: false },
        { id: "hibernate", label: "HIBERNATE", icon: String.fromCodePoint(0xF0717), danger: false },
        { id: "logout",    label: "LOGOUT",    icon: String.fromCodePoint(0xF0343), danger: true  },
        { id: "reboot",    label: "REBOOT",    icon: String.fromCodePoint(0xF0709), danger: true  },
        { id: "shutdown",  label: "SHUTDOWN",  icon: String.fromCodePoint(0xF0425), danger: true  }
    ]

    Timer {
        id: disarmTimer
        interval: 4000
        onTriggered: w.armedId = ""
    }

    function executeAction(id) {
        w.armedId = "";
        disarmTimer.stop();
        if (id === "lock") {
            const custom = String(w.cfg.lockCmd || "").trim();
            if (custom !== "") { Quickshell.execDetached(["sh", "-c", custom]); return; }
            Quickshell.execDetached(["sh", "-c",
                'if command -v hyprlock >/dev/null 2>&1; then pidof hyprlock >/dev/null 2>&1 || hyprlock; ' +
                'elif command -v noctalia >/dev/null 2>&1; then noctalia msg lockScreen lock; ' +
                'elif command -v swaylock >/dev/null 2>&1; then swaylock; ' +
                'else loginctl lock-session; fi'
            ]);
        } else if (id === "suspend") {
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else if (id === "hibernate") {
            Quickshell.execDetached(["systemctl", "hibernate"]);
        } else if (id === "logout") {
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        } else if (id === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (id === "shutdown") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    function trigger(id) {
        if (w.cfg.requireConfirm !== false && w.armedId !== id) {
            w.armedId = id;
            disarmTimer.restart();
            return;
        }
        executeAction(id);
    }

    Column {
        anchors.fill: parent
        spacing: 6 * w.ui

        Grid {
            width: parent.width
            height: parent.height - 20 * w.ui
            columns: 3
            rowSpacing: 5 * w.ui
            columnSpacing: 5 * w.ui
            readonly property real bw: (width - 10 * w.ui) / 3
            readonly property real bh: (height - 5 * w.ui) / 2

            Repeater {
                model: w.actions
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool armed: w.armedId === modelData.id
                    readonly property color col: (armed || modelData.danger) ? w.effDanger : w.accent
                    width: parent.bw
                    height: parent.bh
                    radius: 4 * w.ui
                    color: armed ? Qt.rgba(col.r, col.g, col.b, 0.30)
                         : (btnMa.containsMouse ? Qt.rgba(col.r, col.g, col.b, 0.16) : "#22000000")
                    border.width: Math.max(1, Math.round(w.ui))
                    border.color: armed ? col
                                : (btnMa.containsMouse ? Qt.rgba(col.r, col.g, col.b, 0.65) : Qt.rgba(w.cDim.r, w.cDim.g, w.cDim.b, 0.22))

                    Column {
                        anchors.centerIn: parent
                        spacing: 2 * w.ui

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            color: armed ? w.cCream : (modelData.danger ? w.effDanger : (btnMa.containsMouse ? w.accent : w.cCream))
                            font.family: nfFont.status === FontLoader.Ready ? nfFont.name : w.effPowerFont
                            font.pixelSize: Math.max(11, Math.round((w.cfg.showLabels !== false ? 16 : 20) * w.ui))
                        }
                        Text {
                            visible: w.cfg.showLabels !== false
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: armed ? "SURE?" : modelData.label
                            color: armed ? w.cCream : w.cDim
                            font.family: w.effPowerFont
                            font.bold: armed
                            font.pixelSize: Math.max(7, Math.round(8 * w.ui))
                            font.letterSpacing: 0.8 * w.ui
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: w.trigger(modelData.id)
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 14 * w.ui
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: w.armedId !== "" ? ("CLICK AGAIN TO " + w.armedId.toUpperCase()) : "POWER CONTROLS"
                color: w.armedId !== "" ? w.effDanger : w.cDim
                font.family: w.effPowerFont
                font.bold: w.armedId !== ""
                font.pixelSize: Math.max(7, Math.round(8.5 * w.ui))
                font.letterSpacing: 1.2 * w.ui
            }
            Text {
                visible: w.armedId !== ""
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "CANCEL"
                color: w.cCream
                font.family: w.effPowerFont
                font.pixelSize: Math.max(7, Math.round(8.5 * w.ui))
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4 * w.ui
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { w.armedId = ""; disarmTimer.stop(); }
                }
            }
        }
    }
}
