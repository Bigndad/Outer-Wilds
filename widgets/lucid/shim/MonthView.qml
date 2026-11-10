import QtQuick

// Month grid: header, weekday letters, 6 rows of days, today in an accent pill.
// Day picking is not wired (pickFill/pickInk accepted, unused).
Item {
    id: mv
    property real cell: 32
    property bool mondayFirst: true
    property bool showHeader: true
    property bool showNav: false
    property color ink: Theme.text
    property color inkDim: Theme.subtext
    property color accent: Theme.accent
    property color fgAccent: Theme.fgAccent
    property color pickFill: Theme.alpha(Theme.text, 0.1)
    property color pickInk: Theme.text
    property color markColor: Theme.accent

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    readonly property real chromeHeight: (showHeader ? 28 : 0) + 22
    readonly property date today: new Date()
    readonly property int lead: (new Date(viewYear, viewMonth, 1).getDay() + (mondayFirst ? 6 : 0)) % 7

    width: cell * 7
    height: chromeHeight + cell * 6

    Item {
        id: head
        visible: mv.showHeader
        width: parent.width
        height: 28
        LText {
            anchors.verticalCenter: parent.verticalCenter
            x: mv.cell * 0.2
            role: "titleSmall"
            color: mv.accent
            text: new Date(mv.viewYear, mv.viewMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
        }
        Row {
            visible: mv.showNav
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: [-1, 1]
                Item {
                    required property int modelData
                    width: 22; height: 22
                    LText { anchors.centerIn: parent; text: parent.modelData < 0 ? "‹" : "›"; color: mv.ink; size: 18 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var d = new Date(mv.viewYear, mv.viewMonth + parent.modelData, 1);
                            mv.viewYear = d.getFullYear();
                            mv.viewMonth = d.getMonth();
                        }
                    }
                }
            }
        }
    }

    Row {
        y: mv.showHeader ? 28 : 0
        Repeater {
            model: 7
            LText {
                required property int index
                width: mv.cell
                height: 22
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                role: "labelSmall"
                color: mv.inkDim
                text: Qt.locale().dayName(((index + (mv.mondayFirst ? 1 : 0)) % 7), Locale.ShortFormat).charAt(0).toUpperCase()
            }
        }
    }

    Grid {
        y: mv.chromeHeight
        columns: 7
        Repeater {
            model: 42
            Item {
                id: day
                required property int index
                readonly property date d: new Date(mv.viewYear, mv.viewMonth, 1 - mv.lead + index)
                readonly property bool inMonth: d.getMonth() === mv.viewMonth
                readonly property bool isToday: d.getFullYear() === mv.today.getFullYear() && d.getMonth() === mv.today.getMonth() && d.getDate() === mv.today.getDate()
                readonly property bool marked: Agenda.hasOn(d.getFullYear(), d.getMonth(), d.getDate())
                width: mv.cell
                height: mv.cell
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 4
                    height: width
                    radius: width / 2
                    color: mv.accent
                    visible: day.isToday
                }
                LText {
                    anchors.centerIn: parent
                    size: mv.cell * 0.4
                    text: day.d.getDate()
                    color: day.isToday ? mv.fgAccent : (day.inMonth ? mv.ink : Theme.alpha(mv.inkDim, 0.45))
                }
                Rectangle {
                    visible: day.marked && !day.isToday
                    width: 4; height: 4; radius: 2
                    color: mv.markColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: mv.cell * 0.08
                }
            }
        }
    }
}
