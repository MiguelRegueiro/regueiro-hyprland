//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "bar" as Bar
import "clipboard" as Clipboard
import "launcher" as Launcher
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
    property bool clipboardOpening: false
    readonly property bool clipboardRequested: clipboardVisible || clipboardOpening
    property bool launcherVisible: false
    property bool launcherOpening: false
    readonly property bool launcherRequested: launcherVisible || launcherOpening
    property bool powerMenuVisible: false
    property string powerMenuMode: "menu"
    property string powerMenuAction: ""
    property string powerBusyAction: ""

    function powerActionNeedsConfirmation(actionId) {
        return actionId === "logout" || actionId === "reboot" || actionId === "shutdown";
    }

    function closePowerMenu() {
        powerMenuVisible = false;
        powerMenuMode = "menu";
        powerMenuAction = "";
    }

    function openPowerMenu() {
        closeAllPanels();
        powerMenuMode = "menu";
        powerMenuAction = "";
        powerMenuVisible = true;
    }

    function togglePowerMenu() {
        if (powerMenuVisible)
            closePowerMenu();
        else
            openPowerMenu();
    }

    function requestPowerAction(actionId) {
        if (powerBusyAction !== "")
            return ;

        if (actionId === "toggle") {
            togglePowerMenu();
            return ;
        }
        if (actionId === "open" || actionId === "menu") {
            openPowerMenu();
            return ;
        }
        if (actionId === "close") {
            closePowerMenu();
            return ;
        }
        if (powerActionNeedsConfirmation(actionId)) {
            closeAllPanels();
            powerMenuMode = "confirm";
            powerMenuAction = actionId;
            powerMenuVisible = true;
            return ;
        }
        runPowerAction(actionId);
    }

    function confirmPowerAction() {
        if (!powerActionNeedsConfirmation(powerMenuAction))
            return ;

        runPowerAction(powerMenuAction);
    }

    function clearPowerBusy(actionId) {
        if (powerBusyAction === actionId)
            powerBusyAction = "";

    }

    function runPowerAction(actionId) {
        if (powerBusyAction !== "")
            return ;

        closeAllPanels();
        powerBusyAction = actionId;
        if (actionId === "lock" && !lockProc.running)
            lockProc.running = true;
        else if (actionId === "suspend" && !suspendProc.running)
            suspendProc.running = true;
        else if (actionId === "logout" && !logoutProc.running)
            logoutProc.running = true;
        else if (actionId === "reboot" && !rebootProc.running)
            rebootProc.running = true;
        else if (actionId === "shutdown" && !shutdownProc.running)
            shutdownProc.running = true;
        else
            powerBusyAction = "";
    }

    function closeClipboard() {
        clipboardOpenTimer.stop();
        clipboardOpening = false;
        clipboardVisible = false;
    }

    function closeLauncher() {
        launcherOpenTimer.stop();
        launcherOpening = false;
        launcherVisible = false;
    }

    function openClipboard() {
        if (powerMenuVisible)
            return ;

        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        clipboardOpening = true;
        clipboardOpenTimer.restart();
    }

    function toggleClipboard() {
        if (powerMenuVisible)
            return ;

        if (clipboardVisible || clipboardOpening)
            closeClipboard();
        else
            openClipboard();
    }

    function openLauncher() {
        if (powerMenuVisible)
            return ;

        closeClipboard();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        launcherOpening = true;
        launcherOpenTimer.restart();
    }

    function toggleLauncher() {
        if (powerMenuVisible)
            return ;

        if (launcherVisible || launcherOpening)
            closeLauncher();
        else
            openLauncher();
    }

    function toggleQuickSettings() {
        if (powerMenuVisible)
            return ;

        closeLauncher();
        closeClipboard();
        qsController.togglePinned();
    }

    function closeAllPanels() {
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        closeClipboard();
        closeLauncher();
        closePowerMenu();
    }

    IpcHandler {
        function toggle() {
            root.toggleQuickSettings();
        }

        target: "quicksettings"
    }

    IpcHandler {
        function toggle() {
            root.toggleClipboard();
        }

        function open() {
            root.openClipboard();
        }

        function close() {
            root.closeClipboard();
        }

        target: "clipboard"
    }

    IpcHandler {
        function toggle() {
            root.toggleLauncher();
        }

        function open() {
            root.openLauncher();
        }

        function close() {
            root.closeLauncher();
        }

        target: "launcher"
    }

    Timer {
        id: launcherOpenTimer

        interval: 16
        repeat: false
        onTriggered: {
            root.launcherVisible = true;
            root.launcherOpening = false;
        }
    }

    Timer {
        id: clipboardOpenTimer

        interval: 16
        repeat: false
        onTriggered: {
            root.clipboardVisible = true;
            root.clipboardOpening = false;
        }
    }

    IpcHandler {
        function toggle() {
            root.togglePowerMenu();
        }

        function open() {
            root.openPowerMenu();
        }

        function close() {
            root.closePowerMenu();
        }

        function action(actionId: string) {
            root.requestPowerAction(actionId);
        }

        function lock() {
            root.requestPowerAction("lock");
        }

        function suspend() {
            root.requestPowerAction("suspend");
        }

        function logout() {
            root.requestPowerAction("logout");
        }

        function reboot() {
            root.requestPowerAction("reboot");
        }

        function shutdown() {
            root.requestPowerAction("shutdown");
        }

        target: "powermenu"
    }

    Process {
        id: lockProc

        command: ["sh", "-lc", "if command -v hyprlock >/dev/null 2>&1; then hyprlock --config \"$HOME/.config/hypr/hyprlock.conf\"; elif command -v swaylock >/dev/null 2>&1; then swaylock; else loginctl lock-session; fi"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("lock");

        }
    }

    Process {
        id: suspendProc

        command: ["sh", "-lc", "if command -v hyprlock >/dev/null 2>&1 && ! pgrep -x hyprlock >/dev/null 2>&1; then hyprlock --config \"$HOME/.config/hypr/hyprlock.conf\" >/dev/null 2>&1 & sleep 1; elif command -v swaylock >/dev/null 2>&1 && ! pgrep -x swaylock >/dev/null 2>&1; then swaylock >/dev/null 2>&1 & sleep 1; else loginctl lock-session >/dev/null 2>&1 || true; fi; systemctl suspend"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("suspend");

        }
    }

    Process {
        id: logoutProc

        command: ["hyprctl", "dispatch", "exit"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("logout");

        }
    }

    Process {
        id: rebootProc

        command: ["systemctl", "reboot"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("reboot");

        }
    }

    Process {
        id: shutdownProc

        command: ["systemctl", "poweroff"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("shutdown");

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

    Services.LauncherService {
        id: launcherServiceState
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.BarWindow {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected
                readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
                readonly property var activeWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
                readonly property bool fullscreenPanelChromeActive: activeScreen && (root.launcherRequested || root.clipboardRequested) && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                showBar: activeScreen
                forceOverlay: fullscreenPanelChromeActive
                notificationStore: notificationStoreService
                audioService: audioServiceState
                brightnessService: brightnessServiceState
                inputService: inputServiceState
                onQuickSettingsClicked: root.toggleQuickSettings()
                onNotificationCenterClicked: {
                    root.closeLauncher();
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
                readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
                readonly property var activeWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
                readonly property bool fullscreenPanelChromeActive: activeScreen && (root.launcherRequested || root.clipboardRequested) && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                hasBar: activeScreen
                forceOverlay: fullscreenPanelChromeActive
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                brightnessService: brightnessServiceState
                onOutsidePressed: root.closeAllPanels()
                onPowerActionRequested: (actionId) => {
                    return root.requestPowerAction(actionId);
                }
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
            Overlays.PowerMenuOSD {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                active: activeScreen
                open: root.powerMenuVisible && activeScreen
                mode: root.powerMenuMode
                actionId: root.powerMenuAction
                busyAction: root.powerBusyAction
                onActionRequested: (actionId) => {
                    return root.requestPowerAction(actionId);
                }
                onConfirmRequested: root.confirmPowerAction()
                onCancelRequested: root.closePowerMenu()
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
            Launcher.LauncherOverlay {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected
                readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
                readonly property var activeWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
                readonly property bool launcherOverlayActive: activeScreen && root.launcherRequested && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                showLayer: activeScreen
                launcherVisible: root.launcherVisible && activeScreen
                forceOverlay: launcherOverlayActive
                launcherService: launcherServiceState
                onOutsidePressed: root.closeLauncher()
            }

        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Clipboard.ClipboardOverlay {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected
                readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
                readonly property var activeWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
                readonly property bool clipboardOverlayActive: activeScreen && root.clipboardRequested && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                showLayer: activeScreen
                clipboardVisible: root.clipboardVisible && activeScreen
                forceOverlay: clipboardOverlayActive
                clipboardService: clipboardServiceState
                onOutsidePressed: root.closeClipboard()
            }

        }

    }

}
