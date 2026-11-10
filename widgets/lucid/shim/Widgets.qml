pragma Singleton
import QtQuick

QtObject {
    property string editUid: ""

    // what Lucid's own catalogue would have filled in for a fresh card
    function defaults(type) {
        switch (type) {
        case "clock": return { "hourMode": "auto", "seconds": false, "showDate": true, "zones": "mine", "shape": "cookie9", "dot": true, "tone": "auto" };
        case "calendar": return { "showMonthName": true, "tone": "auto" };
        case "weather": return { "tone": "auto" };
        case "battery": return { "showTime": true, "warnLow": true, "tone": "auto" };
        case "visualiser": return { "density": "normal", "flip": false, "rounded": true, "frost": false, "idleFade": false, "tint": "accent" };
        }
        return {};
    }
}
