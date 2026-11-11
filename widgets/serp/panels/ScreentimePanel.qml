import QtQuick
import QtQuick.Layouts
import "../shim"
import "screentime"

// ilyamiro's Digital Wellbeing tab (day + week views), without the limits / app-exclusion settings.
WellbeingState {
    id: tabRoot

    ColumnLayout {
        width: Math.min(parent.width - 24, 1000)
        height: parent.height - 24
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12
        spacing: 8

        WellbeingHeader { tab: tabRoot }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WellbeingDailyView { tab: tabRoot }
            WellbeingWeekView { tab: tabRoot }
        }
    }
}
