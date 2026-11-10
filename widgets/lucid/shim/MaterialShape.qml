import QtQuick
import QtQuick.Shapes

// Stand-in for Lucid's MaterialShape: "circle" and "cookieN" (a scalloped disc).
Item {
    id: s
    property string shape: "circle"
    property color color: "white"

    readonly property int lobes: {
        if (s.shape === "circle") return 0;
        var m = /(\d+)/.exec(s.shape);
        return m ? parseInt(m[1]) : 8;
    }
    readonly property var pts: {
        var out = [], n = 180, R = 0.5, depth = s.lobes > 0 ? (s.lobes >= 12 ? 0.045 : 0.07) : 0;
        for (var i = 0; i <= n; i++) {
            var a = i / n * Math.PI * 2;
            var r = R * (1 - depth + depth * Math.cos(a * s.lobes));
            out.push(Qt.point(0.5 + r * Math.cos(a), 0.5 + r * Math.sin(a)));
        }
        return out;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: s.color
            strokeColor: "transparent"
            scale: Qt.size(s.width, s.height)
            PathPolyline { path: s.pts }
        }
    }
}
