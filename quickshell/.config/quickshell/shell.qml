//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import "bar" as Bar
import "notifications" as Notifications
import "overlays" as Overlays
import "services" as Services

ShellRoot {
    id: root

    property bool quickSettingsVisible: false
    property bool quickSettingsPinned: false
    property bool quickSettingsTriggerHovered: false
    property bool quickSettingsPanelHovered: false
    property bool externalConnected: Quickshell.screens.length > 1
    property bool notificationCenterVisible: false
    property bool notificationCenterPinned: false
    property bool notificationCenterTriggerHovered: false
    property bool notificationCenterPanelHovered: false

    function syncQuickSettingsVisibility(immediateClose = false) {
        if (root.quickSettingsPinned || root.quickSettingsTriggerHovered || root.quickSettingsPanelHovered) {
            quickSettingsCloseTimer.stop()
            root.quickSettingsVisible = true
            return
        }

        if (immediateClose) {
            quickSettingsCloseTimer.stop()
            root.quickSettingsVisible = false
            return
        }

        if (root.quickSettingsVisible)
            quickSettingsCloseTimer.restart()
    }

    function syncNotificationCenterVisibility(immediateClose = false) {
        if (root.notificationCenterPinned || root.notificationCenterTriggerHovered || root.notificationCenterPanelHovered || notificationStoreService.holdOpen) {
            notificationCenterCloseTimer.stop()
            root.notificationCenterVisible = true
            return
        }

        if (immediateClose) {
            notificationCenterCloseTimer.stop()
            root.notificationCenterVisible = false
            return
        }

        if (root.notificationCenterVisible)
            notificationCenterCloseTimer.restart()
    }

    Timer {
        id: quickSettingsCloseTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (!root.quickSettingsPinned && !root.quickSettingsTriggerHovered && !root.quickSettingsPanelHovered)
                root.quickSettingsVisible = false
        }
    }

    Timer {
        id: notificationCenterCloseTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (!root.notificationCenterPinned && !root.notificationCenterTriggerHovered && !root.notificationCenterPanelHovered)
                root.notificationCenterVisible = false
        }
    }

    onQuickSettingsPinnedChanged: root.syncQuickSettingsVisibility(!root.quickSettingsPinned)
    onQuickSettingsTriggerHoveredChanged: root.syncQuickSettingsVisibility(false)
    onQuickSettingsPanelHoveredChanged: root.syncQuickSettingsVisibility(false)
    onNotificationCenterPinnedChanged: root.syncNotificationCenterVisibility(!root.notificationCenterPinned)
    onNotificationCenterTriggerHoveredChanged: root.syncNotificationCenterVisibility(false)
    onNotificationCenterPanelHoveredChanged: root.syncNotificationCenterVisibility(false)

    Connections {
        target: notificationStoreService
        function onHoldOpenChanged() { root.syncNotificationCenterVisibility(false) }
        function onAllDismissed() {
            root.notificationCenterPinned = false
            root.syncNotificationCenterVisibility(true)
        }
    }

    Services.NotificationStore {
        id: notificationStoreService
        popupSuppressed: root.notificationCenterVisible
    }

    Services.AudioService {
        id: audioServiceState
    }

    Services.BrightnessService {
        id: brightnessServiceState
    }

    Services.InputService {
        id: inputServiceState
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar.BarWindow {
                required property var modelData

                readonly property bool activeScreen: modelData.name !== "eDP-1" || !root.externalConnected

                targetScreen: modelData
                showBar: activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                brightnessService: brightnessServiceState
                inputService: inputServiceState

                onQuickSettingsClicked: root.quickSettingsPinned = !root.quickSettingsPinned
                onNotificationCenterClicked: root.notificationCenterPinned = !root.notificationCenterPinned
                onQuickSettingsHoveredChanged: hovered => root.quickSettingsTriggerHovered = hovered
                onNotificationCenterHoveredChanged: hovered => root.notificationCenterTriggerHovered = hovered
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Overlays.ScreenFrameOverlay {
                required property var modelData

                readonly property bool activeScreen: modelData.name !== "eDP-1" || !root.externalConnected

                targetScreen: modelData
                hasBar: activeScreen
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                brightnessService: brightnessServiceState
                onOutsidePressed: {
                    root.quickSettingsPinned = false
                    root.notificationCenterPinned = false
                    root.syncQuickSettingsVisibility(true)
                    root.syncNotificationCenterVisibility(true)
                }
                onQuickSettingsHoveredChanged: {
                    if (activeScreen)
                        root.quickSettingsPanelHovered = quickSettingsHovered
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Overlays.VolumeOSD {
                required property var modelData

                targetScreen: modelData
                audioService: audioServiceState
                brightnessService: brightnessServiceState
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Overlays.InputMethodOSD {
                required property var modelData
                targetScreen: modelData
                active: modelData.name !== "eDP-1" || !root.externalConnected
                inputService: inputServiceState
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Notifications.NotificationsOverlay {
                required property var modelData

                readonly property bool activeScreen: modelData.name !== "eDP-1" || !root.externalConnected

                targetScreen: modelData
                showLayer: activeScreen
                notificationStore: notificationStoreService
                notificationCenterVisible: root.notificationCenterVisible && activeScreen
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                onOutsidePressed: {
                    root.quickSettingsPinned = false
                    root.notificationCenterPinned = false
                    root.syncQuickSettingsVisibility(true)
                    root.syncNotificationCenterVisibility(true)
                }
                onNotificationCenterHoveredChanged: {
                    if (activeScreen)
                        root.notificationCenterPanelHovered = notificationCenterHovered
                }
            }
        }
    }
}
