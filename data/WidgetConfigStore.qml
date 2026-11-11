import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Reads / writes widgets.json (next to shell.qml) for WidgetConfig. The ONLY file that touches the disk for widget settings.
// Put ONE of these in shell.qml. Delete widgets.json to go back to the defaults in WidgetLayer.baseDefs.
Scope {
    id: root

    readonly property string path: decodeURIComponent(Qt.resolvedUrl("../widgets.json").toString().replace("file://", ""))

    FileView {
        id: file
        path: root.path
        watchChanges: true                    // edit the file by hand and the scene follows
        onFileChanged: reload()
        onLoaded: WidgetConfig.load(file.text())
        onLoadFailed: (error) => WidgetConfig.load("")      // no file yet: defaults; the first edit creates it
    }

    Connections {
        target: WidgetConfig
        function onSaveRequested(text) { file.setText(text); }
    }
}
