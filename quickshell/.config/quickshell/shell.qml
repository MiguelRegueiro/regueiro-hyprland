//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import "bar" as Bar
import "notifications" as Notifications
import "overlays" as Overlays
import "services" as Services
import "theme/Theme.js" as Theme

ShellRoot {
    id: root

    property bool externalConnected: Quickshell.screens.length > 1
    readonly property bool quickSettingsVisible: qsController.open
    readonly property bool notificationCenterVisible: ncController.open

    function closeAllPanels() {
        qsController.pinned = false
        ncController.pinned = false
        qsController.closeImmediately()
        ncController.closeImmediately()
    }

    Services.HoverOverlayController { id: qsController }

    Services.HoverOverlayController {
        id: ncController
        extraHoldCondition: notificationStoreService.holdOpen
    }

    Connections {
        target: notificationStoreService
        function onAllDismissed() {
            ncController.pinned = false
            ncController.closeImmediately()
        }
    }

    Services.NotificationStore {
        id: notificationStoreService
        popupSuppressed: root.notificationCenterVisible
    }

    Services.AudioService    { id: audioServiceState }
    Services.BrightnessService { id: brightnessServiceState }
    Services.InputService    { id: inputServiceState }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar.BarWindow {
                required property var modelData

                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                showBar: activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                brightnessService: brightnessServiceState
                inputService: inputServiceState

                onQuickSettingsClicked: qsController.togglePinned()
                onNotificationCenterClicked: ncController.togglePinned()
                onQuickSettingsHoveredChanged: hovered => qsController.triggerHovered = hovered
                onNotificationCenterHoveredChanged: hovered => ncController.triggerHovered = hovered
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Overlays.ScreenFrameOverlay {
                required property var modelData

                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                hasBar: activeScreen
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                brightnessService: brightnessServiceState
                onOutsidePressed: root.closeAllPanels()
                onQuickSettingsHoveredChanged: {
                    if (activeScreen)
                        qsController.panelHovered = quickSettingsHovered
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
                active: modelData.name !== Theme.primaryScreen || !root.externalConnected
                inputService: inputServiceState
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Notifications.NotificationsOverlay {
                required property var modelData

                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                showLayer: activeScreen
                notificationStore: notificationStoreService
                notificationCenterVisible: root.notificationCenterVisible && activeScreen
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                onOutsidePressed: root.closeAllPanels()
                onNotificationCenterHoveredChanged: {
                    if (activeScreen)
                        ncController.panelHovered = notificationCenterHovered
                }
            }
        }
    }
}
