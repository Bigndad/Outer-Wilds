pragma Singleton
import QtQuick
// MOCK laptop battery. Real data: see README.
QtObject {
    readonly property var displayDevice: ({
        "ready": true, "isLaptopBattery": true, "percentage": 0.72,
        "state": UPowerDeviceState.Discharging, "changeRate": 8.4,
        "timeToEmpty": 19800, "timeToFull": 0
    })
}
