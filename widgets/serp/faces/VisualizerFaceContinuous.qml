import QtQuick
import "../shim"
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 50
    property real minHeight: 50
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    property bool isVisVisible: visible

    property bool isSubscribed: false
    property int barCount: 64
    property real riseSpeed: 0.25
    property real fallSpeed: 0.12

    onIsVisVisibleChanged: updateSubscription()

    function updateSubscription() {
        if (isVisVisible && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Component.onCompleted: updateSubscription()

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Visualizer {
        anchors.fill: parent
        active: root.isSubscribed
        continuous: true
        count: root.barCount
        rise: root.riseSpeed
        fall: root.fallSpeed
        maxLength: height * 0.92
    }
}
