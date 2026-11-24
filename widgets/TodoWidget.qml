import QtQuick
import ".."

WidgetCard {
    id: w
    title: "TO-DO"
    designW: 280
    designH: 200

    property var cfg: ({ showDone: true, font: "monospace" })
    readonly property bool wantsHold: taskIn.activeFocus
    readonly property string _typingKey: "todo_" + Math.random().toString(36).slice(2)
    Keys.onPressed: (event) => { if (taskIn.activeFocus) event.accepted = true; }
    Keys.onReleased: (event) => { if (taskIn.activeFocus) event.accepted = true; }
    Component.onDestruction: WidgetConfig.setWidgetTyping(_typingKey, false)
    readonly property string effTodoFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont
    property var tasks: [
        { text: "Check ship log", done: false },
        { text: "Calibrate signalscope", done: true }
    ]
    readonly property int doneCount: {
        let c = 0;
        for (let i = 0; i < tasks.length; i++) if (tasks[i].done) c++;
        return c;
    }
    readonly property real progress: tasks.length > 0 ? doneCount / tasks.length : 0
    readonly property string progressLabel: doneCount + "/" + tasks.length

    function addTask(t) {
        const clean = String(t || "").trim();
        if (!clean) return;
        const next = tasks.slice();
        next.push({ text: clean, done: false });
        tasks = next;
    }
    function toggleTask(i) {
        const next = tasks.slice();
        next[i] = { text: next[i].text, done: !next[i].done };
        tasks = next;
    }
    function removeTask(i) {
        const next = tasks.slice();
        next.splice(i, 1);
        tasks = next;
    }

    Column {
        anchors.fill: parent
        spacing: 6 * w.ui

        Row {
            width: parent.width
            spacing: 5 * w.ui
            Rectangle {
                width: parent.width - addBtn.width - 5 * w.ui
                height: 24 * w.ui
                radius: 4 * w.ui
                color: "#26000000"
                border.width: Math.max(1, Math.round(w.ui))
                border.color: taskIn.activeFocus ? w.accent : Qt.rgba(w.cDim.r, w.cDim.g, w.cDim.b, 0.3)

                Text {
                    x: 7 * w.ui; anchors.verticalCenter: parent.verticalCenter
                    visible: taskIn.text === "" && !taskIn.activeFocus
                    text: "add task..."; color: w.cDim; opacity: 0.65
                    font.family: w.effTodoFont; font.pixelSize: Math.max(8, Math.round(10 * w.ui))
                }
                TextInput {
                    id: taskIn
                    anchors.fill: parent; anchors.leftMargin: 7 * w.ui; anchors.rightMargin: 7 * w.ui
                    verticalAlignment: TextInput.AlignVCenter; clip: true
                    color: w.cCream; font.family: w.effTodoFont; font.pixelSize: Math.max(8, Math.round(10 * w.ui))
                    onActiveFocusChanged: WidgetConfig.setWidgetTyping(w._typingKey, activeFocus)
                    onAccepted: { w.addTask(text); text = ""; }
                    Keys.onEscapePressed: (event) => {
                        event.accepted = true;
                        focus = false;
                        WidgetConfig.setWidgetTyping(w._typingKey, false);
                        if (w.rig) w.rig.forceActiveFocus();
                    }
                }
            }
            Rectangle {
                id: addBtn
                width: 26 * w.ui; height: 24 * w.ui; radius: 4 * w.ui
                color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.2)
                border.width: Math.max(1, Math.round(w.ui)); border.color: w.accent
                Text { anchors.centerIn: parent; text: "+"; color: w.accent; font.family: w.effTodoFont; font.bold: true; font.pixelSize: Math.max(10, Math.round(13 * w.ui)) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { w.addTask(taskIn.text); taskIn.text = ""; } }
            }
        }

        ListView {
            width: parent.width
            height: parent.height - 30 * w.ui
            clip: true
            spacing: 4 * w.ui
            model: w.tasks
            delegate: Rectangle {
                required property var modelData
                required property int index
                visible: w.cfg.showDone !== false || !modelData.done
                width: ListView.view.width
                height: visible ? 24 * w.ui : 0
                radius: 4 * w.ui
                color: "#1F000000"
                border.width: Math.max(1, Math.round(w.ui))
                border.color: Qt.rgba(w.cDim.r, w.cDim.g, w.cDim.b, 0.16)

                Rectangle {
                    x: 6 * w.ui; anchors.verticalCenter: parent.verticalCenter
                    width: 12 * w.ui; height: 12 * w.ui; radius: 3 * w.ui
                    color: modelData.done ? w.accent : "transparent"
                    border.width: Math.max(1, Math.round(w.ui)); border.color: w.accent
                    Text { visible: modelData.done; anchors.centerIn: parent; text: "✓"; color: "#0B0C10"; font.bold: true; font.pixelSize: Math.max(7, Math.round(9 * w.ui)) }
                }
                Text {
                    x: 24 * w.ui; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46 * w.ui; elide: Text.ElideRight
                    text: modelData.text
                    color: modelData.done ? w.cDim : w.cCream
                    font.strikeout: modelData.done
                    font.family: w.effTodoFont; font.pixelSize: Math.max(8, Math.round(10 * w.ui))
                }
                MouseArea { anchors.fill: parent; anchors.rightMargin: 22 * w.ui; cursorShape: Qt.PointingHandCursor; onClicked: w.toggleTask(index) }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 7 * w.ui; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: w.cDim; font.pixelSize: Math.max(8, Math.round(9 * w.ui))
                    MouseArea { anchors.fill: parent; anchors.margins: -4 * w.ui; cursorShape: Qt.PointingHandCursor; onClicked: w.removeTask(index) }
                }
            }
        }
    }
}
