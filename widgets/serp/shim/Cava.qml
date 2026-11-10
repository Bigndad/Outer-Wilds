pragma Singleton
import QtQuick

// Forwards to the real cava-backed Spectrum singleton, so everything that still says Cava.* (Visualizer,
// the older visualiser faces) gets real audio. Replaces the old fake spectrum.
QtObject {
    readonly property int barCount: Spectrum.barCount
    readonly property var barLevels: Spectrum.barLevels
    readonly property int activeConsumers: Spectrum.activeConsumers
    function registerConsumer() { Spectrum.registerConsumer(); }
    function unregisterConsumer() { Spectrum.unregisterConsumer(); }
}
