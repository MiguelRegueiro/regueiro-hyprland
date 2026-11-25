import QtQuick
import Quickshell.Services.UPower

Item {
    readonly property var device: UPower.displayDevice
    readonly property bool present: device && device.isPresent && device.percentage >= 0
    readonly property int percent: present ? Math.min(100, Math.round(device.percentage * 100)) : -1
    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged)
    readonly property bool full: present && device.state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: present && device.state === UPowerDeviceState.Discharging
    readonly property bool onBattery: UPower.onBattery
    readonly property real secondsLeft: present && discharging ? device.timeToEmpty : 0
}
