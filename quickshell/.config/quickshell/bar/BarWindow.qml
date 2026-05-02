import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: bar

    required property var targetScreen
    required property var notificationStore
    required property var audioService
    required property var brightnessService
    required property var inputService
    property bool showBar: true
    property bool forceOverlay: false

    signal quickSettingsClicked()
    signal notificationCenterClicked()
    signal clipboardClicked()
    signal quickSettingsHoveredChanged(bool hovered)
    signal notificationCenterHoveredChanged(bool hovered)

    screen: targetScreen
    visible: showBar
    exclusiveZone: Theme.barHeight - Theme.borderSize
    WlrLayershell.layer: bar.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    implicitHeight: Theme.barHeight
    color: Theme.barBg

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        anchors.fill: parent

        Row {
            id: leftRow

            spacing: 0

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 4
            }

            WorkspaceStrip {
                screenName: bar.targetScreen.name
                barHeight: Theme.barHeight
            }

            SystemStats {
                barHeight: Theme.barHeight
            }

        }

        DateTimeNotificationTrigger {
            id: dateTimeTrigger

            anchors.centerIn: parent
            barHeight: Theme.barHeight
            notificationStore: bar.notificationStore
            onNotificationCenterClicked: bar.notificationCenterClicked()
        }

        Item {
            id: notificationHotZone

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.ncWidth + Theme.barCornerRadius * 2
            x: Math.round((parent.width - width) / 2)

            HoverHandler {
                blocking: false
                onHoveredChanged: bar.notificationCenterHoveredChanged(hovered)
            }

        }

        RowLayout {
            id: rightRow

            spacing: 0

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 4
            }

            BarIconButton {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                iconText: "󰅌"
                onClicked: bar.clipboardClicked()
            }

            SystemTrayItems {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
            }

            InputLanguageIndicator {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                inputService: bar.inputService
            }

            QuickSettingsTrigger {
                id: quickSettingsTrigger

                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                audioService: bar.audioService
                onClicked: bar.quickSettingsClicked()
            }

        }

        Item {
            id: quickSettingsHotZone

            x: rightRow.x + quickSettingsTrigger.x
            width: parent.width - x
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 20

            HoverHandler {
                blocking: false
                onHoveredChanged: bar.quickSettingsHoveredChanged(hovered)
            }

        }

    }

}
