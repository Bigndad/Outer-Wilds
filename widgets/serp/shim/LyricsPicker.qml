import QtQuick
import Quickshell.Io

// Stand-in for Serpantinum's file-picker popup: opens the system file dialog (zenity, else kdialog)
// and reports the chosen .lrc/.txt file. Nothing happens if neither tool is installed.
Item {
    id: root
    property var targetScreen: null
    signal lyricsSelected(string filePath, string fileName)

    function openPicker() { if (!picker.running) picker.running = true; }

    Process {
        id: picker
        command: ["sh", "-c",
            "zenity --file-selection --title='Select lyrics file' --file-filter='Lyrics | *.lrc *.txt *.json' 2>/dev/null"
            + " || kdialog --getopenfilename \"$HOME\" '*.lrc *.txt *.json' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p !== "") root.lyricsSelected(p, p.split("/").pop());
            }
        }
    }
}
