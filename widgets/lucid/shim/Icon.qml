import QtQuick

// Stand-in for Lucid's Icon. Uses Material Symbols when installed, otherwise a
// plain unicode glyph so nothing renders as an empty box.
Text {
    id: ic
    property string name: ""
    property real size: 20
    property real fill: 0

    readonly property string family: Qt.fontFamilies().indexOf("Material Symbols Rounded") >= 0 ? "Material Symbols Rounded"
        : (Qt.fontFamilies().indexOf("Material Symbols Outlined") >= 0 ? "Material Symbols Outlined" : "")
    readonly property var fallback: ({
        "bolt": "⚡", "battery_alert": "!", "battery_full": "▮", "battery_charging_full": "⚡",
        "battery_0_bar": "▯", "battery_1_bar": "▯", "battery_2_bar": "▮", "battery_3_bar": "▮",
        "battery_4_bar": "▮", "battery_5_bar": "▮", "battery_6_bar": "▮",
        "mouse": "◍", "keyboard": "⌨", "headphones": "♫", "smartphone": "▯", "tablet": "▭",
        "stadia_controller": "◎", "speaker": "♪", "event_available": "✓", "check": "✓",
        "remove": "–", "delete": "✕", "search_off": "∅", "auto_awesome": "✦", "widgets": "▦"
    })

    color: Theme.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.family: ic.family !== "" ? ic.family : Theme.fontFamily
    font.pixelSize: Math.round(ic.size)
    text: ic.family !== "" ? ic.name : (ic.fallback[ic.name] || "•")
}
