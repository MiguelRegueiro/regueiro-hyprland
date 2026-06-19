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
    readonly property bool launcherRequested: launcherVisible
    property bool externalDrivesMenuVisible: false
    property bool sshSessionsMenuVisible: false
    property bool cpuStatsMenuVisible: false
    property bool ramStatsMenuVisible: false
    readonly property bool panelChromeRequested: launcherRequested || clipboardRequested || quickSettingsVisible || notificationCenterVisible || externalDrivesMenuVisible || sshSessionsMenuVisible || cpuStatsMenuVisible || ramStatsMenuVisible
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

        if (actionId === "suspend")
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
        launcherVisible = false;
    }

    function openClipboard() {
        if (powerMenuVisible)
            return ;

        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
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

        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeClipboard();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        launcherVisible = true;
    }

    function toggleLauncher() {
        if (powerMenuVisible)
            return ;

        if (launcherVisible)
            closeLauncher();
        else
            openLauncher();
    }

    function closeExternalDrivesMenu() {
        externalDrivesMenuVisible = false;
    }

    function closeSshSessionsMenu() {
        sshSessionsMenuVisible = false;
    }

    function closeCpuStatsMenu() {
        cpuStatsMenuVisible = false;
    }

    function closeRamStatsMenu() {
        ramStatsMenuVisible = false;
    }

    function toggleExternalDrivesMenu() {
        if (powerMenuVisible)
            return ;

        if (externalDrivesMenuVisible) {
            closeExternalDrivesMenu();
            return ;
        }
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        externalDrivesServiceState.refresh();
        externalDrivesMenuVisible = true;
    }

    function toggleSshSessionsMenu() {
        if (powerMenuVisible)
            return ;

        if (sshSessionsMenuVisible) {
            closeSshSessionsMenu();
            return ;
        }
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        sshSessionsServiceState.refresh();
        sshSessionsMenuVisible = true;
    }

    function toggleCpuStatsMenu() {
        if (powerMenuVisible)
            return ;

        if (cpuStatsMenuVisible) {
            closeCpuStatsMenu();
            return ;
        }
        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeRamStatsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        systemDetailsServiceState.refreshCpu();
        cpuStatsMenuVisible = true;
    }

    function toggleRamStatsMenu() {
        if (powerMenuVisible)
            return ;

        if (ramStatsMenuVisible) {
            closeRamStatsMenu();
            return ;
        }
        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        systemDetailsServiceState.refreshRam();
        ramStatsMenuVisible = true;
    }

    function toggleQuickSettings() {
        if (powerMenuVisible)
            return ;

        const shouldClose = qsController.open;
        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeLauncher();
        closeClipboard();
        ncController.closeImmediately();
        if (shouldClose) {
            qsController.closeImmediately();
        } else {
            qsController.pinned = true;
            qsController.syncVisibility(false);
        }
    }

    function toggleNotificationCenter() {
        if (powerMenuVisible)
            return ;

        const shouldClose = ncController.open;
        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeLauncher();
        closeClipboard();
        qsController.closeImmediately();
        if (shouldClose) {
            ncController.closeImmediately();
        } else {
            ncController.pinned = true;
            ncController.syncVisibility(false);
        }
    }

    function closeAllPanels() {
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        closeClipboard();
        closeLauncher();
        closeExternalDrivesMenu();
        closeSshSessionsMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
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

        command: ["sh", "-lc", "if command -v hyprlock >/dev/null 2>&1; then exec hyprlock --config \"$HOME/.config/hypr/hyprlock.conf\"; elif command -v swaylock >/dev/null 2>&1; then exec swaylock; else exit 0; fi"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("lock");

        }
    }

    Process {
        id: suspendProc

        command: ["false"]
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

        command: ["sh", "-lc", "if command -v doas >/dev/null 2>&1; then exec doas -n /sbin/reboot; else exec /sbin/reboot; fi"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("reboot");

        }
    }

    Process {
        id: shutdownProc

        command: ["sh", "-lc", "if command -v doas >/dev/null 2>&1; then exec doas -n /sbin/shutdown -p now; else exec /sbin/shutdown -p now; fi"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("shutdown");

        }
    }

    Services.HoverOverlayController {
        id: qsController

        inhibited: root.launcherRequested || root.clipboardRequested || root.powerMenuVisible
    }

    Services.HoverOverlayController {
        id: ncController

        inhibited: root.launcherRequested || root.clipboardRequested || root.powerMenuVisible
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

    Services.BatteryService {
        id: batteryServiceState
    }

    Services.BrightnessService {
        id: brightnessServiceState
    }

    Services.ClipboardService {
        id: clipboardServiceState
    }

    Services.ExternalDrivesService {
        id: externalDrivesServiceState
    }

    Services.SshSessionsService {
        id: sshSessionsServiceState
    }

    Services.SystemDetailsService {
        id: systemDetailsServiceState
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
                readonly property bool fullscreenPanelChromeActive: activeScreen && root.panelChromeRequested && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                showBar: activeScreen
                externalConnected: root.externalConnected
                forceOverlay: fullscreenPanelChromeActive
                quickSettingsOpen: root.quickSettingsVisible
                notificationCenterOpen: root.notificationCenterVisible
                cpuStatsOpen: root.cpuStatsMenuVisible
                ramStatsOpen: root.ramStatsMenuVisible
                notificationStore: notificationStoreService
                audioService: audioServiceState
                batteryService: batteryServiceState
                brightnessService: brightnessServiceState
                externalDrivesService: externalDrivesServiceState
                sshSessionsService: sshSessionsServiceState
                onQuickSettingsClicked: root.toggleQuickSettings()
                onNotificationCenterClicked: root.toggleNotificationCenter()
                onClipboardClicked: root.toggleClipboard()
                onExternalDrivesClicked: root.toggleExternalDrivesMenu()
                onSshSessionsClicked: root.toggleSshSessionsMenu()
                onCpuStatsClicked: root.toggleCpuStatsMenu()
                onRamStatsClicked: root.toggleRamStatsMenu()
                onQuickSettingsHoveredChanged: (hovered) => {
                    qsController.triggerHovered = false;
                }
                onNotificationCenterHoveredChanged: (hovered) => {
                    ncController.triggerHovered = false;
                }
            }

        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.CpuStatsMenu {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                detailsService: systemDetailsServiceState
                open: root.cpuStatsMenuVisible && activeScreen
                onCloseRequested: root.closeCpuStatsMenu()
            }

        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.RamStatsMenu {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                detailsService: systemDetailsServiceState
                open: root.ramStatsMenuVisible && activeScreen
                onCloseRequested: root.closeRamStatsMenu()
            }

        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.SshSessionsMenu {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                sshService: sshSessionsServiceState
                open: root.sshSessionsMenuVisible && activeScreen
                onCloseRequested: root.closeSshSessionsMenu()
            }

        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.ExternalDrivesMenu {
                required property var modelData
                readonly property bool activeScreen: modelData.name !== Theme.primaryScreen || !root.externalConnected

                targetScreen: modelData
                driveService: externalDrivesServiceState
                open: root.externalDrivesMenuVisible && activeScreen
                onCloseRequested: root.closeExternalDrivesMenu()
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
                readonly property bool fullscreenPanelChromeActive: activeScreen && root.panelChromeRequested && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                hasBar: activeScreen
                forceOverlay: fullscreenPanelChromeActive
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                batteryService: batteryServiceState
                brightnessService: brightnessServiceState
                onOutsidePressed: root.closeAllPanels()
                onQuickSettingsRequested: root.toggleQuickSettings()
                onNotificationCenterRequested: root.toggleNotificationCenter()
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
                readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
                readonly property var activeWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
                readonly property bool notificationOverlayActive: activeScreen && root.notificationCenterVisible && activeWorkspace && activeWorkspace.hasFullscreen

                targetScreen: modelData
                showLayer: activeScreen
                forceOverlay: notificationOverlayActive
                notificationStore: notificationStoreService
                notificationCenterVisible: root.notificationCenterVisible && activeScreen
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                onOutsidePressed: root.closeAllPanels()
                onQuickSettingsRequested: root.toggleQuickSettings()
                onNotificationCenterRequested: root.toggleNotificationCenter()
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
                onQuickSettingsRequested: root.toggleQuickSettings()
                onNotificationCenterRequested: root.toggleNotificationCenter()
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
                onQuickSettingsRequested: root.toggleQuickSettings()
                onNotificationCenterRequested: root.toggleNotificationCenter()
            }

        }

    }

}
