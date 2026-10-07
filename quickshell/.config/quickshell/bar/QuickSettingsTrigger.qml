import QtQuick
import Quickshell.Services.UPower
import "../components" as Components
import "../theme/Theme.js" as Theme

Rectangle {
    id: root

    required property var audioService
    required property var networkService
    property int barHeight: 34
    property bool menuOpen: false
    readonly property bool hovered: triggerHover.hovered
    property var batteryDevice: UPower.displayDevice
    property int batteryPercent: batteryDevice ? Math.min(100, Math.round(batteryDevice.percentage * 100)) : -1
    property bool batteryCharging: batteryDevice && (batteryDevice.state === UPowerDeviceState.Charging || batteryDevice.state === UPowerDeviceState.FullyCharged)
    property bool batteryFull: batteryDevice && batteryDevice.state === UPowerDeviceState.FullyCharged

    signal clicked()

    height: barHeight
    implicitWidth: contentRow.implicitWidth + 28
    radius: Theme.radiusSmall
    color: hovered || menuOpen ? Theme.hoverBg : "transparent"

    HoverHandler {
        id: triggerHover

        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    Row {
        id: contentRow

        anchors {
            verticalCenter: parent.verticalCenter
            // Keep the right edge of the status cluster close to the bar
            // edge; the wider left inset still gives the trigger a generous
            // click target.
            right: parent.right
            rightMargin: 6
        }
        spacing: 6

        Components.WifiIcon {
            visible: !root.networkService.ethernetConnected
            connected: root.networkService.wifiConnected
            iconColor: Theme.textPrimary
            inactiveColor: Theme.textDisabled
            height: 14.5
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            // Keep the dedicated wired mark when Ethernet is active; the
            // custom wave icon is only for Wi-Fi and its disconnected state.
            visible: root.networkService.ethernetConnected
            text: "󰌗"
            font.family: Theme.fontIcons
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 1
            height: 14
            color: Theme.barBorder
            anchors.verticalCenter: parent.verticalCenter
        }

        Components.VolumeIcon {
            muted: root.audioService.muted
            volumePercent: root.audioService.volumePercent
            iconColor: Theme.textPrimary
            height: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.audioService.volumePercent + "%"
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: root.audioService.muted ? Theme.textDisabled : Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            visible: root.batteryPercent >= 0
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 1
                height: 14
                color: Theme.barBorder
                anchors.verticalCenter: parent.verticalCenter
            }

            Components.BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                percent: root.batteryPercent
                charging: root.batteryCharging
                full: root.batteryFull
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: root.clicked()
        onWheel: (wheel) => {
            return root.audioService.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5);
        }
    }

    Behavior on color {
        enabled: !root.menuOpen

        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }

    }

}
