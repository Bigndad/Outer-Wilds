pragma Singleton
import QtQuick

// MOCK UPower: the same names Quickshell.Services.UPower exposes.
// To go live on a real PC, point port.py's LIVE flag at the real import instead.
QtObject {
    id: up
    readonly property var displayDevice: ({
        "isPresent": true, "percentage": 0.72, "state": UPowerDeviceState.Discharging,
        "changeRate": 8.4, "healthSupported": true, "healthPercentage": 91,
        "energyCapacity": 42.0, "timeToEmpty": 19800, "timeToFull": 0,
        "type": UPowerDeviceType.Battery
    })
    readonly property var devices: ({
        "values": [
            { "isPresent": true, "type": UPowerDeviceType.Phone, "nativePath": "kdeconnect", "model": "Phone", "powerSupply": false, "percentage": 0.58, "state": UPowerDeviceState.Charging },
            { "isPresent": true, "type": UPowerDeviceType.Headset, "nativePath": "bt", "model": "Headset", "powerSupply": false, "percentage": 0.34, "state": UPowerDeviceState.Discharging },
            { "isPresent": true, "type": UPowerDeviceType.Mouse, "nativePath": "hid", "model": "Mouse", "powerSupply": false, "percentage": 0.85, "state": UPowerDeviceState.Discharging }
        ]
    })
}
