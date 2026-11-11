import QtQuick

// Stand-in for Serpantinum's settings-window tab base: supplies rootObj (scaling + folders) and builds all stages at once.
Item {
    id: guideTabRoot
    property var rootObj: QtObject {
        function s(v) { return v; }
        property var appPaths: QtObject {
            function getRunDir(name) { return Caching.getRunDir(name); }
            function getStateDir(name) { return Caching.getStateDir(name); }
        }
        property int currentTab: 0
        property int currentSubTab: 0
        property var pendingHighlightItem: null
        property string highlightedSettingId: ""
        property int deferredBuilds: 0
    }
    property int tabIndex: 0
    property int subTabIndex: -1
    readonly property bool isCurrent: true
    property bool revealed: visible
    anchors.fill: parent
    property int deferredStages: 0
    property int deferredStage: deferredStages
    readonly property bool deferredBuilding: false
}
