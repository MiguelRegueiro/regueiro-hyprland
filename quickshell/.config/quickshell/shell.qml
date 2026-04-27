//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "bar" as Bar
import "clipboard" as Clipboard
import "notifications" as Notifications
import "overlays" as Overlays
import "services" as Services
import "theme/Theme.js" as Theme

ShellRoot {
    id: root

    property bool externalConnected: Quickshell.screens.length > 1
    readonly property bool quickSettingsVisible: qsController.open
    readonly property bool notificationCenterVisible: ncController.open
    property bool clipboardVisible: false

    function closeClipboard() {
        clipboardVisible = false;
    }

    function openClipboard() {
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        clipboardVisible = true;
    }

    function toggleClipboard() {
        if (clipboardVisible)
            closeClipboard();
        else
            openClipboard();
    }

    function toggleQuickSettings() {
        closeClipboard();
        qsController.togglePinned();
    }

    function closeAllPanels() {
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        closeClipboard();
    }

    IpcHandler {
        target: "quicksettings"

        function toggle() {
            root.toggleQuickSettings();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            root.toggleClipboard();
        }

        function open() {
            root.openClipboard();
        }

        function close() {
            root.closeClipboard();
        }
    }

    Services.HoverOverlayController {
        id: qsController
    }

    Services.HoverOverlayController {
        id: ncController

        extraHoldCondition: notificationStoreService.holdOpen
    }

    Connections {
        function onAllDismissed() {
            ncController.pinned = false;
            ncController.closeImmediately();
        }

        target: notificationStoreService
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

    Services.ClipboardService {
        id: clipboardServiceState
    }

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
                onQuickSettingsClicked: root.toggleQuickSettings()
                onNotificationCenterClicked: {
                    root.closeClipboard();
                    ncController.togglePinned();
                }
                onClipboardClicked: root.toggleClipboard()
                onQuickSettingsHoveredChanged: (hovered) => {
                    return qsController.triggerHovered = hovered;
                }
                onNotificationCenterHoveredChanged: (hovered) => {
                    return ncController.triggerHovered = hovered;
                }
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
                        qsController.panelHovered = quickSettingsHovered;

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
                        ncController.panelHovered = notificationCenterHovered;

                }
            }

        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Clipboard.ClipboardOverlay {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                showLayer: activeScreen
                clipboardVisible: root.clipboardVisible && activeScreen
                clipboardService: clipboardServiceState
                onOutsidePressed: root.closeClipboard()
            }

        }

    }

}
