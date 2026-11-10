pragma Singleton
import QtQuick
QtObject {
    property bool metric: true
    function deg(c, f) { return Math.round(metric ? c : f) + "°"; }
    function temp(c, f) { return Math.round(metric ? c : f) + "°"; }
    function wind(kmph, mph) { return metric ? Math.round(kmph) + " km/h" : Math.round(mph) + " mph"; }
}
