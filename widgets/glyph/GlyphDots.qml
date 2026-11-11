import QtQuick
import "."

// Dot-matrix text drawn from a built-in 5x7 bitmap font (no font file, no shader, any Qt 6).
// Characters: 0-9 : . % - ° and space. `cell` = pitch in px, `dot` = lit/unlit dot diameter.
Item {
    id: root
    property string text: ""
    property real cell: 8
    property real dot: cell * 0.72
    property color on: GlyphTheme.fg
    property color off: GlyphTheme.s3
    property bool showOff: true

    readonly property var glyphs: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11110","00001","00001","01110","00001","00001","11110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["0","0","1","0","1","0","0"],
        ".": ["0","0","0","0","0","0","1"],
        "%": ["11001","11010","00010","00100","01000","01011","10011"],
        "-": ["000","000","000","111","000","000","000"],
        "\u00B0": ["010","101","010","000","000","000","000"],
        " ": ["000","000","000","000","000","000","000"]
    })

    function build(t) {
        let cols = 0;
        const parts = [];
        for (let i = 0; i < t.length; i++) {
            const g = glyphs[t[i]] || glyphs[" "];
            parts.push(g);
            cols += g[0].length + (i > 0 ? 1 : 0);
        }
        const lit = new Array(cols * 7).fill(false);
        let x = 0;
        for (let p = 0; p < parts.length; p++) {
            const g = parts[p];
            for (let r = 0; r < 7; r++)
                for (let c = 0; c < g[r].length; c++)
                    if (g[r][c] === "1") lit[r * cols + x + c] = true;
            x += g[0].length + 1;
        }
        return { cols: cols, lit: lit };
    }
    readonly property var layout: build(text)

    width: layout.cols * cell
    height: 7 * cell

    Repeater {
        model: root.layout.cols * 7
        Rectangle {
            required property int index
            readonly property bool isOn: root.layout.lit[index] === true
            visible: isOn || root.showOff
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            x: (index % root.layout.cols) * root.cell + (root.cell - root.dot) / 2
            y: Math.floor(index / root.layout.cols) * root.cell + (root.cell - root.dot) / 2
            color: isOn ? root.on : root.off
        }
    }
}
