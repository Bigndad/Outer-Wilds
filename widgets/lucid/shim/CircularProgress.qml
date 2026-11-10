import QtQuick
import QtQuick.Shapes

Item {
    id: p
    property real value: 0
    property real thickness: 6
    property color color: Theme.accent
    property color trackColor: Theme.alpha(Theme.text, 0.12)

    readonly property real r: Math.max(1, Math.min(width, height) / 2 - thickness / 2)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: p.trackColor
            strokeWidth: p.thickness
            PathAngleArc { centerX: p.width / 2; centerY: p.height / 2; radiusX: p.r; radiusY: p.r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: p.color
            strokeWidth: p.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: p.width / 2; centerY: p.height / 2; radiusX: p.r; radiusY: p.r
                startAngle: -90
                sweepAngle: 360 * Math.max(0.001, Math.min(1, p.value))
            }
        }
    }
}
