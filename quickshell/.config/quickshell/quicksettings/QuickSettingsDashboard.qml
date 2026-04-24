import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "widgets" as Widgets
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore
    required property var audioService
    required property var brightnessService
    required property var wifiPage
    required property var bluetoothPage
    required property string powerMode
    required property real viewportHeight

    signal wifiPageRequested()
    signal bluetoothPageRequested()
    signal powerModeChangeRequested(string mode)
    signal audioOutputPopupRequest(bool open)

    property bool audioOutputPopupOpen: false
    property bool powerMenuOpen: false
    readonly property real audioOutputPopupBottom: audioOutputPopup.y + audioOutputPopup.height
    readonly property real audioOutputPopupTopInViewport: mapToItem(null, 0, volumeRow.y + volumeRow.height - 14).y
    readonly property real audioOutputPopupMaxHeight: Math.max(180, viewportHeight - audioOutputPopupTopInViewport - Theme.borderSize - 12)
    readonly property real audioOutputPopupOverflow: root.audioOutputPopupOpen
        ? Math.max(0, audioOutputPopupBottom - root.implicitHeight + 12)
        : 0

    implicitHeight: contentLayout.implicitHeight

    function powerModeLabel() {
        if (powerMode === "power-saver")
            return "Power Saver"
        if (powerMode === "performance")
            return "Performance"
        if (powerMode === "balanced")
            return "Balanced"
        return "Unavailable"
    }

    function powerModeIcon() {
        if (powerMode === "power-saver")
            return "\uf06c"
        if (powerMode === "performance")
            return "󱐋"
        return "\uf24e"
    }

    function nextPowerMode() {
        if (powerMode === "balanced")
            return "performance"
        if (powerMode === "performance")
            return "power-saver"
        return "balanced"
    }

    ColumnLayout {
        id: contentLayout

        width: parent.width
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        RowLayout {
            id: headerRow

            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true

                visible: batteryInfo.hasBattery

                property var dev: UPower.displayDevice
                property bool hasBattery: dev && dev.percentage >= 0
                property int percent: hasBattery ? Math.min(100, Math.round(dev.percentage * 100)) : 0
                property bool charging: hasBattery && (dev.state === UPowerDeviceState.Charging
                    || dev.state === UPowerDeviceState.FullyCharged)
                property bool full: hasBattery && dev.state === UPowerDeviceState.FullyCharged
                property real secondsLeft: hasBattery && !charging ? dev.timeToEmpty : 0

                function formatTime(secs) {
                    if (secs <= 0) return ""
                    const h = Math.floor(secs / 3600)
                    const m = Math.floor((secs % 3600) / 60)
                    if (h > 0 && m > 0) return h + "h " + m + "m"
                    if (h > 0) return h + "h"
                    return m + "m"
                }

                id: batteryInfo
                Layout.preferredHeight: 38

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 38
                    radius: 19
                    color: Theme.qsRowBg
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    width: pillRow.implicitWidth + 20

                    RowLayout {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 6

                        Item {
                            width: 24
                            height: 12

                            // Body
                            Rectangle {
                                id: batteryBody
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 21
                                height: 12
                                radius: 3
                                color: "transparent"
                                border.width: 1.5
                                border.color: batteryInfo.percent <= 15 ? Theme.red : Qt.rgba(1, 1, 1, 0.55)

                                // Fill
                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        bottom: parent.bottom
                                        margins: 2.5
                                    }
                                    width: Math.max(0, (parent.width - 5) * batteryInfo.percent / 100)
                                    radius: 1.5
                                    color: batteryInfo.charging || batteryInfo.full ? Theme.green : batteryInfo.percent <= 15 ? Theme.red : Theme.textPrimary

                                    Behavior on width {
                                        NumberAnimation { duration: 200 }
                                    }
                                }

                                // Charging bolt
                                Text {
                                    anchors.centerIn: parent
                                    visible: batteryInfo.charging && !batteryInfo.full
                                    text: "󱐋"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 8
                                    color: "black"
                                }
                            }

                            // Terminal nub
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 5
                                radius: 1
                                color: batteryInfo.percent <= 15 ? Theme.red : Qt.rgba(1, 1, 1, 0.55)
                            }
                        }

                        Text {
                            text: {
                                if (batteryInfo.full) return "Charged"
                                if (batteryInfo.charging) return batteryInfo.percent + "% · Charging"
                                const t = batteryInfo.formatTime(batteryInfo.secondsLeft)
                                return batteryInfo.percent + "%" + (t ? " · " + t : "")
                            }
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            color: Theme.textDim
                        }
                    }
                }
            }

            Item {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                Rectangle {
                    id: lockButton

                    anchors.fill: parent
                    radius: 19
                    color: lockButtonHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color {
                        ColorAnimation { duration: 110 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: Theme.fontIcons
                        font.pixelSize: 17
                        color: Theme.textPrimary
                    }
                }

                HoverHandler {
                    id: lockButtonHover
                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: {
                        root.powerMenuOpen = false
                        root.audioOutputPopupRequest(false)
                        if (!lockProc.running)
                            lockProc.running = true
                    }
                }
            }

            Item {
                id: powerAnchor

                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                Rectangle {
                    id: powerButton

                    anchors.fill: parent
                    radius: 19
                    color: root.powerMenuOpen
                        ? Qt.rgba(0.208, 0.518, 0.894, 0.18)
                        : (powerButtonHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg)
                    border.width: 1
                    border.color: root.powerMenuOpen ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)

                    Behavior on color {
                        ColorAnimation { duration: 110 }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 110 }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        text: "󰐥"
                        font.family: Theme.fontIcons
                        font.pixelSize: 17
                        color: root.powerMenuOpen ? "white" : Theme.textPrimary
                    }
                }

                HoverHandler {
                    id: powerButtonHover
                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: {
                        if (!root.powerMenuOpen)
                            root.audioOutputPopupRequest(false)
                        root.powerMenuOpen = !root.powerMenuOpen
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Widgets.QuickSettingsTile {
                label: "Wi-Fi"
                sublabel: root.wifiPage.connectedSsid.length > 0 ? root.wifiPage.connectedSsid : (root.wifiPage.wifiOn ? "Connected" : "Off")
                iconOn: "󰤨"
                iconOff: "󰤭"
                toggled: root.wifiPage.wifiOn
                hasMenu: true
                pillShape: true
                showMenuIndicator: false
                onClicked: {
                    root.powerMenuOpen = false
                    root.wifiPageRequested()
                }
                onMenuClicked: {
                    root.powerMenuOpen = false
                    root.wifiPageRequested()
                }
            }

            Widgets.QuickSettingsTile {
                label: "Bluetooth"
                sublabel: root.bluetoothPage.connectedDevice.length > 0 ? root.bluetoothPage.connectedDevice : (root.bluetoothPage.btOn ? "On" : "Off")
                iconOn: "󰂯"
                iconOff: "󰂲"
                toggled: root.bluetoothPage.btOn
                hasMenu: true
                pillShape: true
                showMenuIndicator: false
                onClicked: {
                    root.powerMenuOpen = false
                    root.bluetoothPageRequested()
                }
                onMenuClicked: {
                    root.powerMenuOpen = false
                    root.bluetoothPageRequested()
                }
            }

            Widgets.QuickSettingsTile {
                label: "Power Mode"
                sublabel: root.powerModeLabel()
                iconOn: root.powerModeIcon()
                iconOff: root.powerModeIcon()
                toggled: root.powerMode === "performance"
                interactive: root.powerMode !== ""
                pillShape: true
                showIconChip: true
                iconCenterOffsetX: root.powerMode === "balanced" ? 1 : 0
                onClicked: {
                    root.powerMenuOpen = false
                    root.powerModeChangeRequested(root.nextPowerMode())
                }
            }

            Widgets.QuickSettingsTile {
                label: "Do Not Disturb"
                sublabel: root.notificationStore.dnd ? "On" : "Off"
                iconOn: "󰂛"
                iconOff: "󰂜"
                toggled: root.notificationStore.dnd
                pillShape: true
                showIconChip: true
                onClicked: {
                    root.powerMenuOpen = false
                    root.notificationStore.toggleDnd()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Widgets.QuickSettingsSliderRow {
                id: brightnessRow

                Layout.fillWidth: true
                backgroundRadius: 18
                visible: root.brightnessService.available
                iconText: root.brightnessService.iconText
                label: ""
                value: root.brightnessService.percent / 100
                muted: false
                showMute: false
                onSliderMoved: value => root.brightnessService.setPercent(Math.round(value * 100))
                onDraggingChanged: {
                    if (!dragging)
                        root.brightnessService.refresh()
                }
            }

            Widgets.QuickSettingsSliderRow {
                id: volumeRow

                Layout.fillWidth: true
                backgroundRadius: 18
                z: root.audioOutputPopupOpen ? 100 : 0
                iconText: root.audioService.volumeIcon
                label: root.audioService.currentSinkName.length > 0 ? root.audioService.currentSinkName : "Output device"
                value: root.audioService.volumePercent / 100
                muted: root.audioService.muted
                showActionButton: true
                actionButtonActive: root.audioOutputPopupOpen
                actionIconText: "󰅂"
                actionIconOffsetX: 1
                onMuteClicked: root.audioService.toggleMute()
                onSliderMoved: value => root.audioService.setVolumePercent(Math.round(value * 100))
                onDraggingChanged: {
                    if (!dragging)
                        root.audioService.refresh()
                }
                onActionClicked: {
                    root.powerMenuOpen = false
                    root.audioOutputPopupRequest(!root.audioOutputPopupOpen)
                }
            }

            Widgets.MediaControlsRow {
                Layout.fillWidth: true
            }

            Widgets.ApplicationVolumeList {
                Layout.fillWidth: true
            }
        }
    }

    Item {
        visible: root.powerMenuOpen
        anchors.fill: parent
        z: 200

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: root.powerMenuOpen = false
        }

        Widgets.PowerMenuPopup {
            id: powerMenu

            x: Math.max(12, Math.min(root.width - width - 6, powerAnchor.x + powerAnchor.width - width))
            y: headerRow.y + powerAnchor.height + 10
            opacity: root.powerMenuOpen ? 1 : 0

            onActionTriggered: root.powerMenuOpen = false

            Behavior on opacity {
                NumberAnimation {
                    duration: 110
                }
            }
        }
    }

    Item {
        visible: root.audioOutputPopupOpen
        x: 0
        y: 0
        width: root.width
        height: Math.max(root.implicitHeight, audioOutputPopupBottom + 12)
        z: 180

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(audioOutputPopup.y))
            cursorShape: Qt.ArrowCursor
            onClicked: root.audioOutputPopupRequest(false)
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(audioOutputPopup.y))
            width: Math.max(0, Math.round(audioOutputPopup.x))
            height: Math.max(0, Math.round(audioOutputPopup.height))
            cursorShape: Qt.ArrowCursor
            onClicked: root.audioOutputPopupRequest(false)
        }

        MouseArea {
            x: Math.round(audioOutputPopup.x + audioOutputPopup.width)
            y: Math.max(0, Math.round(audioOutputPopup.y))
            width: Math.max(0, Math.round(parent.width - (audioOutputPopup.x + audioOutputPopup.width)))
            height: Math.max(0, Math.round(audioOutputPopup.height))
            cursorShape: Qt.ArrowCursor
            onClicked: root.audioOutputPopupRequest(false)
        }

        MouseArea {
            x: 0
            y: Math.round(audioOutputPopupBottom)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - audioOutputPopupBottom))
            cursorShape: Qt.ArrowCursor
            onClicked: root.audioOutputPopupRequest(false)
        }

        Widgets.AudioOutputPopup {
            id: audioOutputPopup
            audioService: root.audioService
            maxPopupHeight: root.audioOutputPopupMaxHeight
            x: Math.max(0, root.width - width)
            y: volumeRow.y + volumeRow.height - 14
            onSinkChosen: root.audioOutputPopupRequest(false)
        }
    }

    Process {
        id: lockProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/power-menu", "lock"]
    }
}
