pragma Singleton
import QtQuick
import Quickshell

QtObject {
    property bool isDesktop: false
    // added by port_anserin.py
    property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    // set "avatarPath" in ~/.config/outerwilds/settings.json to show a picture on the user card
    property string avatarPath: (Config.rawSettings && Config.rawSettings.avatarPath) ? String(Config.rawSettings.avatarPath) : ""
}
