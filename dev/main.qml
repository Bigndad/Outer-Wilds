import QtQuick
import QtQuick.Window
import ".."

Window {
    id: win
    width: 1280; height: 720; visible: true
    color: "#07080C"

    CameraRig { id: rig; anchors.fill: parent }

    property int frames: 0
    Connections { target: rig; function onFrameUpdated() { win.frames++ } }
    property var log: []
    function slots() {
        let out = [];
        let layer = null;
        function walk(it) {
            for (let i = 0; i < it.children.length; i++) {
                let c = it.children[i];
                if (c.def !== undefined && c.presence !== undefined) out.push(c);
                walk(c);
            }
        }
        walk(rig);
        return out;
    }
    function report(tag) {
        let s = slots();
        let lines = [];
        for (let i = 0; i < s.length; i++) {
            let c = s[i];
            lines.push(`${c.def.id}: vis=${c.visible} op=${c.opacity.toFixed(2)} pres=${c.presence.toFixed(2)} occ=${c.occlusion.toFixed(2)} at=(${Math.round(c.x)},${Math.round(c.y)}) size=${Math.round(c.width)}x${Math.round(c.height)} scale=${c.scale.toFixed(3)}`);
        }
        console.log("== " + tag + " frames=" + frames + " active=" + rig.active + " lastDt=" + rig.lastDt + " sunP=" + JSON.stringify(rig.projectedMap["sun"]) + " keys=" + Object.keys(rig.projectedMap).length + "\n" + lines.join("\n"));
    }
    property int step: 0
    Timer {
        interval: 1200; running: true; repeat: true
        onTriggered: {
            win.step++;
            if (win.step === 1) { win.report("home view"); }
            else if (win.step === 2) { rig.targetedPlanetId = "sun"; }
            else if (win.step === 3) { win.report("sun targeted"); win.contentItem.grabToImage(function(r){ r.saveToFile("/tmp/qt/sun.png"); }); rig.targetedPlanetId = "timber_hearth"; }
            else if (win.step === 4) { rig.lockedPlanetId = "timber_hearth"; rig.targetedPlanetId = "timber_hearth"; rig.targetLockDist = 260; }
            else if (win.step === 6) { win.report("timber hearth locked"); win.contentItem.grabToImage(function(r){ r.saveToFile("/tmp/qt/th.png"); }); rig.lockedPlanetId = "attlerock"; rig.targetedPlanetId = "attlerock"; rig.targetLockDist = 220; }
            else if (win.step === 8) { win.report("attlerock locked"); win.contentItem.grabToImage(function(r){ r.saveToFile("/tmp/qt/att.png"); }); }
            else if (win.step === 9) { Qt.quit(); }
        }
    }
}
