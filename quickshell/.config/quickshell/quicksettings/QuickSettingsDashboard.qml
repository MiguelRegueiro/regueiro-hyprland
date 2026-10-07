import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "widgets" as Widgets
import "../components" as Components
import "../theme/Theme.js" as Theme
import "QuickSettingsStyle.js" as QS

Item {
    id: root

    required property var notificationStore
    required property real popupSurfaceOriginX
    required property real popupSurfaceOriginY
    required property var audioService
    required property var brightnessService
    required property var networkService
    required property var targetScreen
    required property var wifiPage
    required property var bluetoothPage
    required property bool hasPerformanceProfile
    required property string powerMode
    required property real viewportHeight
    property Item popupParent: root
    property bool audioOutputPopupOpen: false
    property bool powerMenuOpen: false
    readonly property bool popupLayerOpen: root.powerMenuOpen || root.audioOutputPopupOpen
    readonly property real audioOutputPopupGap: 10
    readonly property real audioOutputPopupBottom: audioOutputPopup.y + audioOutputPopup.height
    readonly property real audioOutputPopupTopInViewport: mapToItem(null, 0, volumeRow.y + volumeRow.height + audioOutputPopupGap).y
    readonly property real audioOutputPopupMaxHeight: Math.max(180, viewportHeight - audioOutputPopupTopInViewport - Theme.borderSize - 12)
    readonly property real audioOutputPopupOverflow: root.audioOutputPopupOpen ? Math.max(0, audioOutputPopupBottom - root.implicitHeight + 12) : 0
    readonly property real audioOutputPopupSurfaceX: root.popupSurfaceOriginX + root.mapToItem(root.popupParent, audioOutputPopup.x, audioOutputPopup.y).x
    readonly property real audioOutputPopupSurfaceY: root.popupSurfaceOriginY + root.mapToItem(root.popupParent, audioOutputPopup.x, audioOutputPopup.y).y
    readonly property real powerMenuSurfaceX: root.popupSurfaceOriginX + root.mapToItem(root.popupParent, powerMenu.x, powerMenu.y).x
    readonly property real powerMenuSurfaceY: root.popupSurfaceOriginY + root.mapToItem(root.popupParent, powerMenu.x, powerMenu.y).y
    readonly property real appVolumeListTopInViewport: mapToItem(null, 0, controlsColumn.y + applicationVolumeList.y).y
    readonly property real appVolumeListMaxHeight: Math.min(Theme.qsApplicationVolumeMaxHeight, Math.max(56, viewportHeight - appVolumeListTopInViewport - Theme.qsContentPadding * 2 - Theme.barCornerRadius))

    signal wifiPageRequested
    signal bluetoothPageRequested
    signal powerModeChangeRequested(string mode)
    signal audioOutputPopupRequest(bool open)
    signal powerActionRequested(string actionId)

    function powerModeLabel() {
        if (powerMode === "power-saver")
            return "Power Saver";

        if (powerMode === "performance")
            return "Performance";

        if (powerMode === "balanced")
            return "Balanced";

        return "Unavailable";
    }

    function powerModeIcon() {
        if (powerMode === "power-saver")
            return "\uf06c";

        if (powerMode === "performance")
            return "󱐋";

        return "\uf24e";
    }

    function nextPowerMode() {
        if (powerMode === "balanced")
            return hasPerformanceProfile ? "performance" : "power-saver";

        if (powerMode === "performance")
            return "power-saver";

        return "balanced";
    }

    implicitHeight: contentLayout.implicitHeight

    ColumnLayout {
        id: contentLayout

        width: parent.width
        opacity: root.popupLayerOpen ? 0.72 : 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        RowLayout {
            id: headerRow

            Layout.fillWidth: true
            spacing: 8

            Item {
                id: headerStatus

                property var dev: UPower.displayDevice
                property bool hasBattery: dev && dev.percentage >= 0
                property int percent: hasBattery ? Math.min(100, Math.round(dev.percentage * 100)) : 0
                property bool charging: hasBattery && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
                property bool full: hasBattery && dev.state === UPowerDeviceState.FullyCharged
                property real secondsLeft: hasBattery && !charging ? dev.timeToEmpty : 0

                function batteryText() {
                    if (full)
                        return "Charged";

                    if (charging)
                        return "Charging";

                    const t = formatTime(secondsLeft);
                    return t || "Battery";
                }

                function formatTime(secs) {
                    if (secs <= 0)
                        return "";

                    const h = Math.floor(secs / 3600);
                    const m = Math.floor((secs % 3600) / 60);
                    if (h > 0 && m > 0)
                        return h + "h " + m + "m";

                    if (h > 0)
                        return h + "h";

                    return m + "m";
                }

                Layout.fillWidth: true
                Layout.preferredHeight: 38

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 38
                    radius: 19
                    visible: headerStatus.hasBattery
                    color: "transparent"
                    border.width: 0
                    width: Math.min(headerStatus.width, batteryRow.implicitWidth + 20)

                    RowLayout {
                        id: batteryRow

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        Components.BatteryIcon {
                            percent: headerStatus.percent
                            charging: headerStatus.charging
                            full: headerStatus.full
                        }

                        Text {
                            Layout.fillWidth: true
                            text: headerStatus.batteryText()
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item {
                visible: root.networkService.ethernetAvailable
                Layout.preferredWidth: visible ? 38 : 0
                Layout.preferredHeight: 38

                Rectangle {
                    id: ethernetButton

                    anchors.fill: parent
                    radius: 19
                    color: {
                        if (root.networkService.ethernetConnected)
                            return ethernetHover.hovered ? QS.tileActiveBgHover : QS.tileActiveBg;

                        return ethernetHover.hovered && root.networkService.ethernetCanToggle ? QS.cardBgHover : QS.cardBg;
                    }
                    border.width: 1
                    border.color: {
                        if (root.networkService.ethernetConnected)
                            return ethernetHover.hovered ? QS.tileActiveBorderHover : QS.tileActiveBorder;

                        return ethernetHover.hovered && root.networkService.ethernetCanToggle ? QS.cardBorderHover : QS.cardBorder;
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰌗"
                        font.family: Theme.fontIcons
                        font.pixelSize: 17
                        color: root.networkService.ethernetConnected ? "white" : (root.networkService.ethernetCanToggle ? Theme.textPrimary : Theme.textDisabled)
                    }

                    HoverHandler {
                        id: ethernetHover

                        enabled: root.networkService.ethernetAvailable && root.networkService.ethernetCanToggle
                        blocking: false
                        cursorShape: Qt.ArrowCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.networkService.ethernetAvailable && root.networkService.ethernetCanToggle
                        cursorShape: Qt.ArrowCursor
                        onClicked: root.networkService.toggleEthernet()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.hoverAnimDuration
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.hoverAnimDuration
                        }
                    }
                }
            }

            Item {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                Rectangle {
                    id: logoutButton

                    anchors.fill: parent
                    radius: 19
                    color: logoutButtonHover.hovered ? QS.cardBgHover : QS.cardBg
                    border.width: 1
                    border.color: logoutButtonHover.hovered ? QS.cardBorderHover : QS.cardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "\uf08b"
                        font.family: Theme.fontIcons
                        font.pixelSize: 16
                        color: Theme.textPrimary
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.qsPageFadeDuration
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.qsPageFadeDuration
                        }
                    }
                }

                HoverHandler {
                    id: logoutButtonHover

                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: {
                        root.powerMenuOpen = false;
                        root.audioOutputPopupRequest(false);
                        root.powerActionRequested("logout");
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
                    color: lockButtonHover.hovered ? QS.cardBgHover : QS.cardBg
                    border.width: 1
                    border.color: lockButtonHover.hovered ? QS.cardBorderHover : QS.cardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: Theme.fontIcons
                        font.pixelSize: 17
                        color: Theme.textPrimary
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.qsPageFadeDuration
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.qsPageFadeDuration
                        }
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
                        root.powerMenuOpen = false;
                        root.audioOutputPopupRequest(false);
                        root.powerActionRequested("lock");
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
                    color: root.powerMenuOpen ? QS.cardBgHover : (powerButtonHover.hovered ? QS.cardBgHover : QS.cardBg)
                    border.width: 1
                    border.color: root.powerMenuOpen ? QS.cardBorderHover : (powerButtonHover.hovered ? QS.cardBorderHover : QS.cardBorder)

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        text: "󰐥"
                        font.family: Theme.fontIcons
                        font.pixelSize: 17
                        color: Theme.textPrimary
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.qsPageFadeDuration
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.qsPageFadeDuration
                        }
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
                            root.audioOutputPopupRequest(false);

                        root.powerMenuOpen = !root.powerMenuOpen;
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
                sublabel: root.wifiPage.connectedSsid.length > 0 ? root.wifiPage.connectedSsid : (root.wifiPage.wifiOn ? "On" : "Off")
                iconOn: "󰤨"
                iconOff: "󰤭"
                toggled: root.wifiPage.wifiOn
                hasMenu: true
                pillShape: true
                showMenuIndicator: false
                onClicked: {
                    root.powerMenuOpen = false;
                    root.wifiPageRequested();
                }
                onMenuClicked: {
                    root.powerMenuOpen = false;
                    root.wifiPageRequested();
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
                    root.powerMenuOpen = false;
                    root.bluetoothPageRequested();
                }
                onMenuClicked: {
                    root.powerMenuOpen = false;
                    root.bluetoothPageRequested();
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
                    root.powerMenuOpen = false;
                    root.powerModeChangeRequested(root.nextPowerMode());
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
                    root.powerMenuOpen = false;
                    root.notificationStore.toggleDnd();
                }
            }
        }

        ColumnLayout {
            id: controlsColumn

            Layout.fillWidth: true
            spacing: 8

            Widgets.QuickSettingsSliderRow {
                id: brightnessRow

                Layout.fillWidth: true
                backgroundRadius: 18
                surfaceVisible: false
                visible: root.brightnessService.available
                label: ""
                value: root.brightnessService.percent / 100
                muted: false
                showMute: false
                onSliderMoved: value => {
                    return root.brightnessService.setPercent(Math.round(value * 100));
                }
                onDraggingChanged: {
                    if (!dragging)
                        root.brightnessService.refresh();
                }

                iconOverride: Component {
                    Components.BrightnessIcon {
                        iconColor: Theme.textDim
                        height: 16
                    }
                }
            }

            Widgets.QuickSettingsSliderRow {
                id: volumeRow

                Layout.fillWidth: true
                backgroundRadius: 18
                surfaceVisible: false
                z: root.audioOutputPopupOpen ? 100 : 0
                iconOverride: volIconComponent
                label: ""
                value: root.audioService.volumePercent / 100
                muted: root.audioService.muted
                showActionButton: true
                actionButtonActive: root.audioOutputPopupOpen
                actionIconText: "󰅂"
                actionIconOffsetX: 1
                stepSize: root.audioService.volumeStepPercent / 100
                emitInterval: 0
                onMuteClicked: root.audioService.toggleMute()
                onSliderMoved: value => {
                    return root.audioService.setVolumePercent(value * 100);
                }
                onDraggingChanged: {
                    if (!dragging)
                        root.audioService.refresh();
                }
                onActionClicked: {
                    root.powerMenuOpen = false;
                    root.audioOutputPopupRequest(!root.audioOutputPopupOpen);
                }
            }

            Widgets.MediaControlsRow {
                Layout.fillWidth: true
            }

            Widgets.ApplicationVolumeList {
                id: applicationVolumeList

                Layout.fillWidth: true
                maximumHeight: root.appVolumeListMaxHeight
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.qsPageFadeDuration
            }
        }
    }

    Component {
        id: volIconComponent

        Components.VolumeIcon {
            muted: root.audioService.muted
            volumePercent: root.audioService.volumePercent
            iconColor: root.audioService.muted ? Theme.textDisabled : Theme.textDim
            height: 16
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
            surfaceX: root.powerMenuSurfaceX
            surfaceY: root.powerMenuSurfaceY
            targetScreen: root.targetScreen
            open: root.powerMenuOpen
            onActionTriggered: root.powerMenuOpen = false
            onActionRequested: actionId => {
                return root.powerActionRequested(actionId);
            }
        }
    }

    Item {
        visible: root.audioOutputPopupOpen
        // The popup can extend below the dashboard. Keep it outside the
        // dashboard's stacked pages so its entire surface receives input.
        parent: root.popupParent
        x: root.mapToItem(parent, 0, 0).x
        y: root.mapToItem(parent, 0, 0).y
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
            surfaceX: root.audioOutputPopupSurfaceX
            surfaceY: root.audioOutputPopupSurfaceY
            targetScreen: root.targetScreen
            maxPopupHeight: root.audioOutputPopupMaxHeight
            x: Math.max(0, Math.round((root.width - width) / 2))
            y: volumeRow.y + volumeRow.height + root.audioOutputPopupGap
            open: root.audioOutputPopupOpen
            onSinkChosen: root.audioOutputPopupRequest(false)
        }
    }
}
