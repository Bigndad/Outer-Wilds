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
        function onBackupRequested() { backup.running = true; }
    }

    // BACKUP button: a timestamped copy of widgets.json in widgets-backups/ (restore = copy it back over widgets.json)
    Process {
        id: backup
        command: ["sh", "-c", "d=\"$1/widgets-backups\"; mkdir -p \"$d\" && f=\"$d/widgets-$(date +%Y%m%d-%H%M%S).json\" && cp \"$2\" \"$f\" && echo \"saved $f\" || echo \"backup failed (is there a widgets.json yet?)\"", "sh", root.dir, root.path]
        stdout: StdioCollector { onStreamFinished: WidgetConfig.backupMsg = String(text).trim() }
    }

    // ---- drop-in widgets: widgets/user/<name>/{Main.qml, widget.json}  (see WIDGETS.md) ----
    readonly property string dir: root.path.replace(/\/[^\/]*$/, "")
    readonly property var settingTypes: ["toggle", "number", "text", "choice", "color", "font", "file"]

    function _parseManifests(out) {
        const list = [];
        const chunks = out.split("@@@");
        for (let i = 1; i < chunks.length; i++) {
            const nl = chunks[i].indexOf("\n");
            const folder = chunks[i].substring(0, nl).trim();
            let m;
            try { m = JSON.parse(chunks[i].substring(nl + 1)); }
            catch (e) { console.warn("widgets/user/" + folder + "/widget.json is not valid JSON, skipped: " + e); continue; }
            const settings = [];
            if (Array.isArray(m.settings)) {
                for (const s of m.settings) {
                    if (!s || typeof s.key !== "string" || settingTypes.indexOf(s.type) < 0) {
                        console.warn("widgets/user/" + folder + ": a setting needs a key and one of the types " + settingTypes.join(", ")); continue;
                    }
                    settings.push(s);
                }
            }
            const e = { source: "user/" + folder + "/Main.qml", name: m.name || folder, group: m.group || "Custom",
                        designW: m.designW > 0 ? m.designW : 240, settings: settings, user: true };
            if (m.title !== undefined) e.title = m.title;
            if (m.default && typeof m.default === "object") e.default = m.default;
            list.push(e);
        }
        return list;
    }

    function rescan() { scan.running = true; }
    Component.onCompleted: rescan()

    Process {
        id: scan
        command: ["sh", "-c", "for f in \"$1\"/widgets/user/*/widget.json; do [ -f \"$f\" ] || continue; echo \"@@@$(basename \"$(dirname \"$f\")\")\"; cat \"$f\"; echo; done", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: WidgetConfig.setUserCatalog(root._parseManifests(text))
        }
    }

    IpcHandler {
        target: "widgets"
        function rescan(): void { root.rescan(); }
    }
}
