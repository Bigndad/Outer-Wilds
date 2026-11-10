import QtQuick
import ".."

// Hosts ONE Noctalia plugin desktop widget (DesktopWidget.qml) inside an orbiting slot.
//
//  - Gives the plugin the `pluginApi` object Noctalia would inject (pluginId, pluginDir,
//    pluginSettings, manifest, saveSettings(), tr(), panel stubs).
//  - Sets widgetScale from the slot, so plugins that scale with `widgetScale` stay crisp.
//  - The plugin's own imports (qs.Commons, qs.Widgets, qs.Modules.DesktopWidgets, qs.Services.*)
//    must resolve: either run inside a config that has Noctalia's folders, or use the optional
//    shims in noctalia-compat/ (see its README). Bar widgets / panels / Main.qml / launcher
//    providers are NOT hosted here, only desktop widgets.
Item {
    id: host

    property var rig: null
    property real ui: 1.0
    property string pluginId: ""
    property string pluginDir: ""
    property string entry: "DesktopWidget.qml"
    property var pluginSettings: ({})
    property var widgetData: ({})

    signal settingsSaved()

    readonly property bool wantsHold: inner.item !== null && inner.item.wantsHold === true
    readonly property real designW: (inner.item && inner.item.implicitWidth > 0) ? inner.item.implicitWidth : 240
    readonly property real designH: (inner.item && inner.item.implicitHeight > 0) ? inner.item.implicitHeight : 120

    width: inner.item ? Math.max(1, inner.item.width) : Math.round(designW * ui)
    height: inner.item ? Math.max(1, inner.item.height) : Math.round(designH * ui)

    readonly property var api: QtObject {
        property string pluginId: host.pluginId
        property string pluginDir: host.pluginDir
        property var pluginSettings: host.pluginSettings
        property var manifest: ({ id: host.pluginId, name: host.pluginId, version: "0.0.0", metadata: { defaultSettings: ({}) } })
        property string currentLanguage: "en"
        property var mainInstance: null
        property var barWidget: null
        property var desktopWidget: null
        function saveSettings() { host.settingsSaved(); }
        function openPanel(screen, buttonItem) { }
        function closePanel(screen) { }
        function togglePanel(screen, buttonItem) { }
        function tr(key, interpolations) { return key; }
        function trp(key, count, interpolations) { return key; }
        function hasTranslation(key) { return false; }
    }

    Loader {
        id: inner
        active: host.pluginDir !== ""
        source: host.pluginDir !== "" ? "file://" + host.pluginDir + "/" + host.entry : ""
        onLoaded: {
            item.pluginApi = host.api;
            if (item.widgetData !== undefined) item.widgetData = host.widgetData;
            if (item.widgetScale !== undefined) item.widgetScale = Qt.binding(function() { return host.ui; });
        }
    }

    // visible hint instead of a silent blank card if the plugin fails to load
    Rectangle {
        visible: inner.status === Loader.Error
        anchors.fill: parent
        implicitWidth: 240
        implicitHeight: 70
        radius: 6
        color: "#E007080C"
        border.color: "#FF7A45"
        Text {
            anchors.fill: parent
            anchors.margins: 8
            wrapMode: Text.Wrap
            color: "#FF7A45"
            font.pixelSize: 11
            font.family: "monospace"
            text: "Noctalia plugin failed to load:\n" + host.pluginDir + "/" + host.entry
        }
    }
}
