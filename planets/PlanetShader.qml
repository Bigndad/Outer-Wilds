import QtQuick
import ".."

Item {
    id: planetNode
    property string bodyId: ""
    property string bodyName: ""
    property string bodyRole: ""
    property color baseColor: "#4E8B57"
    property color accentColor: "#2E5B88"
    property vector4d lightDir: Qt.vector4d(1, 0, 0, 0)
    property vector4d shaderParams: Qt.vector4d(0, 0, 0, 0)
    property vector4d camAngles: Qt.vector4d(0, 0, 0, 0)
    property real screenRadius: 20
    property real bodyDepth: 500
    property bool isSun: false
    property bool isLocked: false
    property int bodyType: 4

    readonly property real quadMultiplier: {
        if (bodyType === 0) return 2.95;  // Sun + Corona
        if (bodyType === 10) return 4.2;  // Interloper + Comet Tail
        if (bodyType === 1) return 3.2;   // Sun Station (+aura room)
        if (bodyType === 4) return 3.0;   // Timber Hearth: tall mountains
        if (bodyType === 7) return 3.0;   // Hollow's Lantern: tall volcanoes
        if (bodyType === 2 || bodyType === 3) return 3.0;   // Ash / Ember Twin
        if (bodyType === 11) return 2.7;  // Quantum Moon Fog Quad (+aura room)
        return 2.6;   // Attlerock, Brittle Hollow, Giant's Deep, Dark Bramble (+aura room)
    }

    readonly property bool usesBake: bodyType >= 2 && bodyType <= 10
    readonly property int bakeW: 1024

    readonly property real sphereRadiusPx: bodyType === 10 ? screenRadius * 0.79
                                         : (bodyType === 4 || bodyType === 7 || bodyType === 2 || bodyType === 3) ? screenRadius * 0.999
                                         : screenRadius * 0.999

    width: screenRadius * quadMultiplier
    height: width
    x: -width / 2
    y: -height / 2

    Loader {
        id: bakeLoader
        active: planetNode.usesBake
        sourceComponent: Component {
            ShaderEffectSource {
                sourceItem: bakeFx
                hideSource: true
                live: false
                smooth: true
                mipmap: true
                format: ShaderEffectSource.RGBA16F
                wrapMode: ShaderEffectSource.RepeatHorizontally
                textureSize: Qt.size(planetNode.bakeW, planetNode.bakeW / 2)

                ShaderEffect {
                    id: bakeFx
                    width: planetNode.bakeW
                    height: planetNode.bakeW / 2
                    blending: false
                    property vector4d bakeParams: Qt.vector4d(planetNode.bodyType, planetNode.bodyType * 7.31, 0, 0)
                    fragmentShader: "../shaders/bake.frag.qsb"
                }

                Component.onCompleted: scheduleUpdate()
            }
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property color baseColor: planetNode.baseColor
        property color accentColor: planetNode.accentColor
        property vector4d lightDir: planetNode.lightDir
        property vector4d params: planetNode.shaderParams
        property vector4d bakeInfo: Qt.vector4d(planetNode.sphereRadiusPx, planetNode.bakeW, planetNode.quadMultiplier, 0)
        property vector4d camAngles: planetNode.camAngles
        property variant bakeTex: bakeLoader.item
        fragmentShader: "../shaders/planet.frag.qsb"
    }

    Column {
        anchors.left: parent.horizontalCenter
        anchors.leftMargin: planetNode.screenRadius + 8
        anchors.verticalCenter: parent.verticalCenter
        visible: planetNode.isSun || planetNode.isLocked || planetNode.bodyDepth < 1500

        Text {
            color: planetNode.isLocked ? "#55E6FF" : (planetNode.isSun ? "#FFCC66" : (planetNode.bodyType === 11 ? "#B886FF" : "#E6D5B8"))
            font.family: "monospace"
            font.pixelSize: planetNode.isLocked ? 12 : 11
            font.bold: planetNode.isLocked || planetNode.isSun
            text: planetNode.isLocked
                ? `${planetNode.bodyName.toUpperCase()} [${Math.round(planetNode.bodyDepth)}m]`
                : planetNode.bodyName
        }

        Text {
            visible: planetNode.isLocked || planetNode.isSun || planetNode.bodyType === 11
            color: "#CCE6D5B8"
            font.family: "monospace"
            font.pixelSize: 10
            text: `ROLE: ${planetNode.bodyRole}`
        }
    }
}
