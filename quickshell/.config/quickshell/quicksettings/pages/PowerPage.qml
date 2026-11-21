import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Item {
    id: root

    required property var powerService
    readonly property var policy: powerService || ({ screenOff: 0, lock: 20, suspend: 0, powerButton: "system", keepAwake: false, busy: true, lastError: "" })
    readonly property var timerOptions: [
        { label: "Never", value: "0" },
        { label: "2 minutes", value: "2" },
        { label: "5 minutes", value: "5" },
        { label: "10 minutes", value: "10" },
        { label: "15 minutes", value: "15" },
        { label: "20 minutes", value: "20" },
        { label: "30 minutes", value: "30" },
        { label: "45 minutes", value: "45" },
        { label: "1 hour", value: "60" },
        { label: "90 minutes", value: "90" },
        { label: "2 hours", value: "120" }
    ]
    readonly property var buttonOptions: [
        { label: "System default", value: "system" },
        { label: "Lock", value: "lock" },
        { label: "Suspend", value: "suspend" },
        { label: "Shut down", value: "shutdown" },
        { label: "Restart", value: "reboot" },
        { label: "Do nothing", value: "nothing" }
    ]

    function timerLabel(value) {
        const option = timerOptions.find(item => Number(item.value) === value);
        return option ? option.label : "Never";
    }

    function buttonLabel(value) {
        const option = buttonOptions.find(item => item.value === value);
        return option ? option.label : "System default";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: 16
            color: root.policy.keepAwake ? QS.tileActiveBg : QS.cardBg
            border.width: 1
            border.color: root.policy.keepAwake ? QS.tileActiveBorder : QS.cardBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 16
                spacing: 12
                Text {
                    text: "󰖙"
                    font.family: Theme.fontIcons
                    font.pixelSize: 23
                    color: Theme.textPrimary
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Keep awake"; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                    Text { text: "Pause idle actions until turned off"; font.family: Theme.fontUi; font.pixelSize: 11; color: Theme.textDim }
                }
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 28
                    radius: 14
                    color: root.policy.keepAwake ? "#e6efff" : QS.chipBg
                    Rectangle {
                        width: 20; height: 20; radius: 10
                        x: root.policy.keepAwake ? parent.width - width - 4 : 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.policy.keepAwake ? QS.tileActiveBg : Theme.textDim
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.powerService !== undefined && !root.policy.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerService.toggleKeepAwake()
            }
        }

        Text {
            Layout.topMargin: 12
            text: "WHEN IDLE"
            font.family: Theme.fontUi
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Theme.textDisabled
        }

        DisplayOptionRow {
            label: "Turn screens off"
            valueText: root.timerLabel(root.policy.screenOff)
            currentValue: String(root.policy.screenOff)
            options: root.timerOptions
            busy: root.policy.busy
            openBelow: true
            onChosen: value => root.powerService.setTimer("screenOff", value)
        }
        DisplayOptionRow {
            label: "Lock screen"
            valueText: root.timerLabel(root.policy.lock)
            currentValue: String(root.policy.lock)
            options: root.timerOptions
            busy: root.policy.busy
            openBelow: true
            onChosen: value => root.powerService.setTimer("lock", value)
        }
        DisplayOptionRow {
            label: "Suspend"
            valueText: root.timerLabel(root.policy.suspend)
            currentValue: String(root.policy.suspend)
            options: root.timerOptions
            busy: root.policy.busy
            openBelow: true
            onChosen: value => root.powerService.setTimer("suspend", value)
        }

        Text {
            Layout.topMargin: 16
            text: "HARDWARE"
            font.family: Theme.fontUi
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Theme.textDisabled
        }
        DisplayOptionRow {
            label: "Power button"
            valueText: root.buttonLabel(root.policy.powerButton)
            currentValue: root.policy.powerButton
            options: root.buttonOptions
            busy: root.policy.busy
            onChosen: value => root.powerService.setPowerButton(value)
        }

        Text {
            visible: root.policy.lastError !== ""
            Layout.fillWidth: true
            text: root.policy.lastError
            color: "#f2a6a6"
            font.family: Theme.fontUi
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }
}
