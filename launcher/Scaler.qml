import QtQuick

// stand-in for ilyamiro's Scaler: s(px) scales a 1080p design size to the current width
QtObject {
    property real currentWidth: 1920
    function s(val) {
        return Math.round(val * (currentWidth > 0 ? currentWidth / 1920 : 1));
    }
}
