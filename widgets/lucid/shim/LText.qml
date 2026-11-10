import QtQuick

// Stand-in for Lucid's LText: a Text with M3-style roles.
Text {
    id: t
    property string role: "bodyMedium"
    property real size: 0
    property int weight: -1
    property var rounded: false      // accepted and ignored
    property bool tabular: false     // accepted and ignored

    readonly property var roleSizes: ({
        "displayLarge": 57, "displayMedium": 45, "displaySmall": 36,
        "headlineLarge": 32, "headlineMedium": 28, "headlineSmall": 24,
        "titleLarge": 22, "titleMedium": 16, "titleSmall": 14,
        "bodyLarge": 16, "bodyMedium": 14, "bodySmall": 12,
        "labelLarge": 14, "labelMedium": 12, "labelSmall": 11
    })
    readonly property int roleWeight: (role.indexOf("title") === 0 || role.indexOf("label") === 0) ? 500 : 400

    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Math.round(t.size > 0 ? t.size : (roleSizes[role] || 14))
    font.weight: t.weight > 0 ? t.weight : t.roleWeight
}
