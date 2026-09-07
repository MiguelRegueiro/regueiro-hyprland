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
    required property var networkService
    required property var inputService
    required property var externalDrivesService
    required property var sshSessionsService
    property bool externalConnected: false
    readonly property var externalDrives: externalDrivesService && externalDrivesService.drives ? externalDrivesService.drives : []
    property bool showBar: true
    property bool forceOverlay: false
    property bool quickSettingsOpen: false
    property bool notificationCenterOpen: false
    property bool cpuStatsOpen: false
    property bool ramStatsOpen: false
    property bool sshSessionsOpen: false
    property var routedHoverItem: null
    readonly property point routedHoverPosition: routedHoverItem ? routedHoverItem.mapToItem(barContent, 0, 0) : Qt.point(0, 0)

    signal quickSettingsClicked()
    signal notificationCenterClicked()
    signal clipboardClicked()
    signal externalDrivesClicked()
    signal cpuStatsClicked()
    signal ramStatsClicked()
    signal sshSessionsClicked()
    signal quickSettingsHoveredChanged(bool hovered)
    signal notificationCenterHoveredChanged(bool hovered)

    function containsBarPoint(item, pointX, pointY) {
        const localPoint = item.mapFromItem(barContent, pointX, pointY);
        return localPoint.x >= 0 && localPoint.x < item.width && localPoint.y >= 0 && localPoint.y < item.height;
    }

    function routeMenuPress(pointX, pointY) {
        if (containsBarPoint(dateTimeTrigger, pointX, pointY)) {
            notificationCenterClicked();
            return true;
        }
        if (containsBarPoint(quickSettingsTrigger, pointX, pointY)) {
            quickSettingsClicked();
            return true;
        }
        if (containsBarPoint(clipboardTrigger, pointX, pointY)) {
            clipboardClicked();
            return true;
        }
        if (containsBarPoint(sshSessionsTrigger, pointX, pointY)) {
            sshSessionsClicked();
            return true;
        }
        if (containsBarPoint(externalDrivesTrigger, pointX, pointY)) {
            externalDrivesClicked();
            return true;
        }
        if (containsBarPoint(systemStats, pointX, pointY)) {
            const statsPoint = systemStats.mapFromItem(barContent, pointX, pointY);
            return systemStats.routeMenuPress(statsPoint.x, statsPoint.y);
        }

        return false;
    }

    function routeMenuHover(pointX, pointY) {
        let target = null;
        if (containsBarPoint(dateTimeTrigger, pointX, pointY))
            target = dateTimeTrigger;
        else if (containsBarPoint(quickSettingsTrigger, pointX, pointY))
            target = quickSettingsTrigger;
        else if (containsBarPoint(clipboardTrigger, pointX, pointY))
            target = clipboardTrigger;
        else if (containsBarPoint(sshSessionsTrigger, pointX, pointY))
            target = sshSessionsTrigger;
        else if (containsBarPoint(externalDrivesTrigger, pointX, pointY))
            target = externalDrivesTrigger;
        else if (containsBarPoint(systemStats.cpuTriggerItem, pointX, pointY))
            target = systemStats.cpuTriggerItem;
        else if (containsBarPoint(systemStats.ramTriggerItem, pointX, pointY))
            target = systemStats.ramTriggerItem;

        routedHoverItem = target;
        return target !== null;
    }

    function clearMenuHover() {
        routedHoverItem = null;
    }

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
        id: barContent

        anchors.fill: parent

        Rectangle {
            x: Math.round(bar.routedHoverPosition.x)
            y: Math.round(bar.routedHoverPosition.y)
            width: bar.routedHoverItem ? Math.round(bar.routedHoverItem.width) : 0
            height: bar.routedHoverItem ? Math.round(bar.routedHoverItem.height) : 0
            visible: bar.routedHoverItem !== null
            radius: Theme.radiusSmall
            color: Theme.hoverBg
        }

        Row {
            id: leftRow

            spacing: 0

            anchors {
                left: parent.left
                top: parent.top
            }

            WorkspaceStrip {
                screenName: bar.targetScreen.name
                barHeight: Theme.barHeight
                externalConnected: bar.externalConnected
            }

            SystemStats {
                id: systemStats

                barHeight: Theme.barHeight
                cpuMenuOpen: bar.cpuStatsOpen
                ramMenuOpen: bar.ramStatsOpen
                onCpuClicked: bar.cpuStatsClicked()
                onRamClicked: bar.ramStatsClicked()
            }

        }

        DateTimeNotificationTrigger {
            id: dateTimeTrigger

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }

            barHeight: Theme.barHeight
            menuOpen: bar.notificationCenterOpen
            notificationStore: bar.notificationStore
            onNotificationCenterClicked: bar.notificationCenterClicked()
            onHoveredChanged: bar.notificationCenterHoveredChanged(hovered)
        }

        RowLayout {
            id: rightRow

            spacing: 0

            anchors {
                right: parent.right
                top: parent.top
            }

            ExternalDriveButton {
                id: externalDrivesTrigger

                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                onClicked: bar.externalDrivesClicked()
                onRightClicked: {
                    if (bar.externalDrivesService)
                        bar.externalDrivesService.refresh();

                }
            }

            SshSessionsButton {
                id: sshSessionsTrigger

                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                sshService: bar.sshSessionsService
                onClicked: bar.sshSessionsClicked()
                onRightClicked: {
                    if (bar.sshSessionsService)
                        bar.sshSessionsService.refresh();

                }
            }

            BarIconButton {
                id: clipboardTrigger

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
                menuOpen: bar.quickSettingsOpen
                audioService: bar.audioService
                networkService: bar.networkService
                onClicked: bar.quickSettingsClicked()
            }

        }

    }

}
