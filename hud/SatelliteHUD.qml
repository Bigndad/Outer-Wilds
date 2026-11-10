import QtQuick
import QtQuick.Shapes
import ".."

// =====================================================================
//  SatelliteHUD: Outer Wilds style HUD overlay (stage 3).
//   top-left     : RAM / CPU / battery gauge cluster (mirrors the game layout)
//   middle-left  : audio-visualiser globe
//   bottom-left  : movement (thrust) indicator
//   top-right    : contextual key prompts
//  Input-transparent; never takes focus. Data comes from HudData.
// =====================================================================
Item {
    id: hud

    // CameraRig instance (reads targetedPlanetId, lockedPlanetId, camX/Y/Z, camYaw, camPitch)
    property var rig: null

    // Safe reference to HudData singleton so standalone previewing never throws ReferenceErrors
    readonly property var dataSrc: typeof HudData !== "undefined" ? HudData : null

    // ---- tuning knobs -------------------------------------------------
    readonly property real u: Math.max(0.6, height / 1080.0)   // HUD scale: 1.0 at 1080p
    readonly property real margin: 48 * u
    readonly property real gaugeSize: 320 * u
    readonly property real globeSize: 168 * u
    readonly property real thrustSize: 150 * u
    readonly property real maxSpeed: 700.0                     // camera speed that pegs the indicator
    readonly property string fontFamily: "monospace"
    readonly property color cCyan: "#6FEAEE"
    readonly property color cGold: "#EBAE4E"
    readonly property color cOrange: "#E98B55"
    readonly property color cText: "#F2EBDD"
    readonly property color cDim: "#99F2EBDD"

    // key prompts shown top-right. Add a row = add one line.
    // fields: label, key (key cap text, "" for none), mouse (bool), clicks (0 = none)
    readonly property var prompts: [
        { label: "Teleport", key: "", mouse: true, clicks: 2 }
    ]
    readonly property bool promptsShown: rig !== null && rig.targetedPlanetId !== "" && rig.lockedPlanetId === "" && !(typeof SignalscopeData !== "undefined" && SignalscopeData.equipped)

    readonly property string assets: "hud_assets/"

    enabled: false          // no mouse/keyboard handling at all, clicks fall through to the rig
    z: 26000

    // ---- sprite: PNG + tint + optional arc mask ----------------------
    component HudSprite: ShaderEffect {
        property string spriteUrl: ""
        property color tint: "white"
        property real fill: 1.0
        property real startAng: 0.0
        property real sweepAng: 0.0
        property variant src: spriteImage
        fragmentShader: Qt.resolvedUrl("../shaders/hud_sprite.frag.qsb")
        Image {
            id: spriteImage
            visible: false
            source: parent.spriteUrl
            smooth: true
            mipmap: true
        }
    }

    // one arm of the thrust cross: clips the shared axis sprite to a rectangle
    component ArmClip: Item {
        property string spriteUrl: ""
        property color tint: "white"
        property real fullSize: 100
        clip: true
        HudSprite {
            x: -parent.x
            y: -parent.y
            width: parent.fullSize
            height: parent.fullSize
            spriteUrl: parent.spriteUrl
            tint: parent.tint
        }
    }

    component MouseIcon: Item {
        property real s: 20
        property int clicks: 0
        property color col: "#F2EBDD"
        width: s * 0.72
        height: s
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: parent.col
            border.width: Math.max(1, parent.s * 0.07)
        }
        Rectangle {
            x: parent.width * 0.5 - width
            y: parent.s * 0.06
            width: parent.width * 0.47
            height: parent.s * 0.40
            radius: width * 0.5
            color: parent.col
            opacity: 0.9
        }
        Rectangle {
            x: parent.width * 0.5 - width / 2
            y: parent.s * 0.46
            width: Math.max(1, parent.s * 0.06)
            height: parent.s * 0.14
            color: parent.col
        }
    }

    component Chevron: Shape {
        id: chev
        property color col: "white"
        property real sc: 1.0
        scale: sc
        transformOrigin: Item.TopLeft
        ShapePath {
            fillColor: chev.col
            strokeWidth: -1
            PathSvg { path: "M 0 0 L 10 -6 L 7 0 L 10 6 Z" }
        }
    }

    // =================================================================
    //  1. GAUGE CLUSTER  (top-left)
    // =================================================================
    Item {
        id: gauges
        x: hud.margin
        y: hud.margin * 0.85
        width: hud.gaugeSize
        height: hud.gaugeSize

        // smoothed display values
        property real dRam: hud.dataSrc ? hud.dataSrc.ram : 0.42
        property real dCpu: hud.dataSrc ? hud.dataSrc.cpu : 0.18
        property real dBat: hud.dataSrc ? hud.dataSrc.battery : 0.85
        Behavior on dRam { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        Behavior on dCpu { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        Behavior on dBat { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        // screen-space angle (clockwise from 12 o'clock) of each fill end
        readonly property real aRam: 2 * Math.PI - dRam * Math.PI / 2   // 12 -> 9 o'clock
        readonly property real aCpu: Math.PI - dCpu * Math.PI / 2       // 6 -> 3 o'clock
        readonly property real aBat: Math.PI - dBat * Math.PI / 2       // 6 -> 3 o'clock
        readonly property real innerR: 0.25 * width    // chevrons for RAM/CPU sit inside the ring
        readonly property real outerR: 0.535 * width   // battery chevron sits outside the outer arc

        // arcs, mirrored vertically. Mask angles below are in the PNG's own (unmirrored) space.
        Item {
            anchors.fill: parent
            transform: Scale { origin.x: gauges.width / 2; origin.y: gauges.height / 2; yScale: -1 }
            HudSprite { anchors.fill: parent; spriteUrl: hud.assets + "gauges_frame.png"; opacity: 0.85 }
            HudSprite { anchors.fill: parent; spriteUrl: hud.assets + "gauge_boost_track.png"; opacity: 0.85 }
            HudSprite {
                anchors.fill: parent
                spriteUrl: hud.assets + "gauge_o2_full.png"
                fill: gauges.dRam; startAng: Math.PI; sweepAng: Math.PI / 2
            }
            HudSprite {
                anchors.fill: parent
                spriteUrl: hud.assets + "gauge_fuel_full.png"
                fill: gauges.dCpu; startAng: 0; sweepAng: Math.PI / 2
            }
            HudSprite {
                anchors.fill: parent
                spriteUrl: hud.assets + "gauge_boost_full.png"
                fill: gauges.dBat; startAng: 0; sweepAng: Math.PI / 2
            }
        }

        // astronaut: upright, smaller than the frame so it clears the arcs and markers
        Item {
            anchors.centerIn: parent
            width: parent.width * 0.73
            height: parent.height * 0.73
            HudSprite { anchors.fill: parent; spriteUrl: hud.assets + "health_vignette.png"; tint: hud.cCyan; opacity: 0.10 }
            HudSprite { anchors.fill: parent; spriteUrl: hud.assets + "health_outline.png"; opacity: 0.92 }
        }

        // RAM chevron + label
        Chevron {
            col: hud.cText; sc: hud.u
            x: gauges.width / 2 + gauges.innerR * Math.sin(gauges.aRam)
            y: gauges.height / 2 - gauges.innerR * Math.cos(gauges.aRam)
            rotation: gauges.aRam * 180 / Math.PI + 90
        }
        Text {
            x: gauges.width / 2 - 0.30 * gauges.width - implicitWidth / 2
            y: gauges.height / 2 + 0.13 * gauges.width - implicitHeight / 2
            color: hud.cText
            font.family: hud.fontFamily
            font.pixelSize: Math.round(14 * hud.u)
            text: "RAM " + Math.round(gauges.dRam * 100) + "%"
        }

        // CPU chevron + label
        Chevron {
            col: hud.cText; sc: hud.u
            x: gauges.width / 2 + gauges.innerR * Math.sin(gauges.aCpu)
            y: gauges.height / 2 - gauges.innerR * Math.cos(gauges.aCpu)
            rotation: gauges.aCpu * 180 / Math.PI + 90
        }
        Text {
            x: gauges.width / 2 + 0.28 * gauges.width - implicitWidth / 2
            y: gauges.height / 2 - 0.13 * gauges.width - implicitHeight / 2
            color: hud.cText
            font.family: hud.fontFamily
            font.pixelSize: Math.round(14 * hud.u)
            text: "CPU " + Math.round(gauges.dCpu * 100) + "%"
        }

        // battery chevron outside the outer arc + percentage
        Chevron {
            id: batChevron
            col: hud.cText; sc: hud.u
            x: gauges.width / 2 + gauges.outerR * Math.sin(gauges.aBat)
            y: gauges.height / 2 - gauges.outerR * Math.cos(gauges.aBat)
            rotation: gauges.aBat * 180 / Math.PI - 90
        }
        Text {
            x: batChevron.x + 16 * hud.u
            y: batChevron.y - implicitHeight / 2
            color: hud.cText
            font.family: hud.fontFamily
            font.pixelSize: Math.round(14 * hud.u)
            text: (gauges.dBat * 100).toFixed(1) + " %"
        }
    }

    // =================================================================
    //  2. AUDIO GLOBE  (middle-left)
    // =================================================================
    Item {
        id: globe
        x: gauges.x + (gauges.width - hud.globeSize) / 2
        y: hud.height * 0.45
        width: hud.globeSize
        height: hud.globeSize

        property real spin: 0.0

        Timer {
            id: spinTimer
            interval: 33
            repeat: true
            running: (hud.dataSrc ? hud.dataSrc.audioActive : false) && hud.visible
            property real last: 0
            onRunningChanged: last = Date.now()
            onTriggered: {
                const now = Date.now();
                const dt = Math.min(0.2, (now - last) / 1000.0);
                last = now;
                const bA = hud.dataSrc ? hud.dataSrc.bandsA : Qt.vector4d(0, 0, 0, 0);
                const bB = hud.dataSrc ? hud.dataSrc.bandsB : Qt.vector4d(0, 0, 0, 0);
                const energy = (bA.x + bA.y + bB.w) / 3.0;
                globe.spin += dt * (0.30 + 0.9 * energy);
            }
        }

        ShaderEffect {
            anchors.fill: parent
            property color tint: hud.cCyan
            property vector4d bandsA: hud.dataSrc ? hud.dataSrc.bandsA : Qt.vector4d(0, 0, 0, 0)
            property vector4d bandsB: hud.dataSrc ? hud.dataSrc.bandsB : Qt.vector4d(0, 0, 0, 0)
            property real spin: globe.spin
            property real tilt: 0.38
            property variant src: globeImage
            fragmentShader: Qt.resolvedUrl("../shaders/hud_globe.frag.qsb")
            Image {
                id: globeImage
                visible: false
                source: hud.assets + "minimap_surface.png"
                smooth: true
                mipmap: true
            }
        }
        // stand under the globe
        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height + 2 * hud.u
            width: Math.max(2, 3 * hud.u)
            height: 54 * hud.u
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#8A6FA8F0" }
                GradientStop { position: 1.0; color: "#006FA8F0" }
            }
        }
    }

    // =================================================================
    //  3. MOVEMENT INDICATOR  (bottom-left)
    // =================================================================
    Item {
        id: thrust
        x: gauges.x + (gauges.width - hud.thrustSize) / 2 + 24 * hud.u
        y: hud.height - hud.thrustSize - hud.margin * 1.5
        width: hud.thrustSize
        height: hud.thrustSize

        readonly property color cAxis: "#C6F6F1"
        readonly property real diagAng: 42
        readonly property real diagC: Math.cos(diagAng * Math.PI / 180)
        readonly property real diagS: Math.sin(diagAng * Math.PI / 180)

        property real velF: 0.0
        property real velR: 0.0
        property real velU: 0.0
        property real ringRot: 0.0
        property int speedInt: 0

        function norm(v) {
            const n = Math.max(-1.0, Math.min(1.0, v / hud.maxSpeed));
            return (n < 0 ? -1 : 1) * Math.pow(Math.abs(n), 0.7);
        }
        readonly property real nF: norm(velF)
        readonly property real nR: norm(velR)
        readonly property real nU: norm(velU)

        Timer {
            interval: 33
            repeat: true
            running: hud.rig !== null && hud.visible
            property real lx: 0
            property real ly: 0
            property real lz: 0
            property real lt: 0
            property bool primed: false
            onTriggered: {
                const r = hud.rig;
                const now = Date.now();
                if (!primed) {
                    lx = r.camX; ly = r.camY; lz = r.camZ; lt = now; primed = true;
                    return;
                }
                let dt = (now - lt) / 1000.0;
                if (dt < 0.005) return;
                dt = Math.min(dt, 0.2);

                // Use direct velocity in free flight; finite-difference when locked to an orbiting body
                const isLocked = r.lockedPlanetId !== "";
                const vx = isLocked ? (r.camX - lx) / dt : r.velX;
                const vy = isLocked ? (r.camY - ly) / dt : r.velY;
                const vz = isLocked ? (r.camZ - lz) / dt : r.velZ;
                lx = r.camX; ly = r.camY; lz = r.camZ; lt = now;

                const sY = Math.sin(r.camYaw), cY = Math.cos(r.camYaw);
                const sP = Math.sin(r.camPitch), cP = Math.cos(r.camPitch);
                const f = vx * (-sY * cP) + vy * sP + vz * (-cY * cP);
                const rt = vx * cY + vz * (-sY);
                const up = vx * (sY * sP) + vy * cP + vz * (cY * sP);

                const k = 0.35;
                let nf = thrust.velF + (f - thrust.velF) * k;
                let nr = thrust.velR + (rt - thrust.velR) * k;
                let nu = thrust.velU + (up - thrust.velU) * k;
                if (Math.abs(nf) < 2) nf = 0;
                if (Math.abs(nr) < 2) nr = 0;
                if (Math.abs(nu) < 2) nu = 0;
                thrust.velF = nf; thrust.velR = nr; thrust.velU = nu;
                thrust.speedInt = Math.round(Math.hypot(nf, nr, nu));
                if (nf !== 0) thrust.ringRot = (thrust.ringRot + thrust.nF * dt * 70) % 360;
            }
        }

        // dotted ring in the horizontal plane
        Item {
            anchors.centerIn: parent
            width: parent.width * 1.1
            height: parent.height * 1.1
            rotation: -9
            Item {
                id: ringSquash
                anchors.fill: parent
                transform: Scale { origin.x: ringSquash.width / 2; origin.y: ringSquash.height / 2; yScale: 0.48 }
                Item {
                    anchors.fill: parent
                    rotation: thrust.ringRot
                    HudSprite {
                        anchors.fill: parent
                        spriteUrl: hud.assets + "thrust_ticks.png"
                        tint: thrust.cAxis
                        opacity: 0.55 + 0.4 * Math.abs(thrust.nF)
                    }
                }
            }
        }

        // left/right and up/down arms from the axis sprite
        ArmClip {
            x: thrust.width * 0.40; y: 0; width: thrust.width * 0.20; height: thrust.height * 0.5
            fullSize: thrust.width; spriteUrl: hud.assets + "thrust_axis.png"; tint: thrust.cAxis
            opacity: 0.30 + 0.70 * Math.max(0, thrust.nU)
        }
        ArmClip {
            x: thrust.width * 0.40; y: thrust.height * 0.5; width: thrust.width * 0.20; height: thrust.height * 0.5
            fullSize: thrust.width; spriteUrl: hud.assets + "thrust_axis.png"; tint: thrust.cAxis
            opacity: 0.30 + 0.70 * Math.max(0, -thrust.nU)
        }
        ArmClip {
            x: 0; y: thrust.height * 0.40; width: thrust.width * 0.5; height: thrust.height * 0.20
            fullSize: thrust.width; spriteUrl: hud.assets + "thrust_axis.png"; tint: thrust.cAxis
            opacity: 0.30 + 0.70 * Math.max(0, -thrust.nR)
        }
        ArmClip {
            x: thrust.width * 0.5; y: thrust.height * 0.40; width: thrust.width * 0.5; height: thrust.height * 0.20
            fullSize: thrust.width; spriteUrl: hud.assets + "thrust_axis.png"; tint: thrust.cAxis
            opacity: 0.30 + 0.70 * Math.max(0, thrust.nR)
        }
        // forward (up-right) and back (down-left) diagonal arms
        Rectangle {
            readonly property real len: thrust.width * 0.21
            readonly property real mid: thrust.width * 0.205
            width: len; height: Math.max(2, thrust.width * 0.034)
            x: thrust.width / 2 + mid * thrust.diagC - width / 2
            y: thrust.height / 2 - mid * thrust.diagS - height / 2
            rotation: -thrust.diagAng
            color: thrust.cAxis
            opacity: 0.30 + 0.70 * Math.max(0, thrust.nF)
        }
        Rectangle {
            readonly property real len: thrust.width * 0.21
            readonly property real mid: thrust.width * 0.21
            width: len; height: Math.max(2, thrust.width * 0.034)
            x: thrust.width / 2 - mid * thrust.diagC - width / 2
            y: thrust.height / 2 + mid * thrust.diagS - height / 2
            rotation: -thrust.diagAng
            color: thrust.cAxis
            opacity: 0.30 + 0.70 * Math.max(0, -thrust.nF)
        }
        // drift dot
        Rectangle {
            readonly property real reach: thrust.width * 0.30
            width: 7 * hud.u; height: width
            x: thrust.width / 2 + reach * (thrust.nR + thrust.nF * thrust.diagC) - width / 2
            y: thrust.height / 2 - reach * (thrust.nU + thrust.nF * thrust.diagS) - height / 2
            color: thrust.cAxis
            opacity: Math.min(1.0, Math.hypot(thrust.nR, thrust.nU, thrust.nF) * 3.0)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - 14 * hud.u
            color: hud.cText
            font.family: hud.fontFamily
            font.pixelSize: Math.round(13 * hud.u)
            text: "SPEED  " + thrust.speedInt
        }
    }

    // =================================================================
    //  4. KEY PROMPTS  (top-right)
    // =================================================================
    Column {
        id: promptColumn
        anchors.right: parent.right
        anchors.rightMargin: hud.margin
        y: hud.margin * 0.85
        spacing: 10 * hud.u
        opacity: hud.promptsShown ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Repeater {
            model: hud.prompts
            Row {
                id: promptRow
                required property var modelData
                anchors.right: parent.right
                spacing: 12 * hud.u

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: hud.cText
                    font.family: hud.fontFamily
                    font.pixelSize: Math.round(17 * hud.u)
                    text: parent.modelData.label
                }
                Rectangle {
                    visible: parent.modelData.key !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: capText.width + 14 * hud.u
                    height: 24 * hud.u
                    radius: 4 * hud.u
                    color: "transparent"
                    border.color: hud.cText
                    border.width: Math.max(1, 1.5 * hud.u)
                    Text {
                        id: capText
                        anchors.centerIn: parent
                        color: hud.cText
                        font.family: hud.fontFamily
                        font.pixelSize: Math.round(13 * hud.u)
                        text: promptRow.modelData.key
                    }
                }
                MouseIcon {
                    visible: parent.modelData.mouse
                    anchors.verticalCenter: parent.verticalCenter
                    s: 26 * hud.u
                    clicks: parent.modelData.clicks
                    col: hud.cText
                }
                Text {
                    visible: parent.modelData.mouse && parent.modelData.clicks > 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: hud.cText
                    font.family: hud.fontFamily
                    font.pixelSize: Math.round(15 * hud.u)
                    text: "×" + parent.modelData.clicks
                }
            }
        }
    }
}
