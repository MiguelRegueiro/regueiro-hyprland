//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "bar" as Bar
import "clipboard" as Clipboard
import "launcher" as Launcher
import "notifications" as Notifications
import "overlays" as Overlays
import "services" as Services
import "theme/Theme.js" as Theme
import "wallpaper" as Wallpaper

ShellRoot {
    id: root

    readonly property string shellScreenName: {
        const screens = Quickshell.screens;
        const selected = displayServiceState.primary;
        if (selected && screens.some(screen => screen.name === selected))
            return selected;
        const external = screens.find(screen => screen.name.indexOf("eDP-") !== 0);
        return external ? external.name : screens.length > 0 ? screens[0].name : "";
    }

    function isShellScreen(screen) {
        return screen && screen.name === shellScreenName;
    }
    readonly property bool quickSettingsVisible: qsController.open
    readonly property bool notificationCenterVisible: ncController.open
    property bool clipboardVisible: false
    property bool clipboardOpening: false
    readonly property bool clipboardRequested: clipboardVisible || clipboardOpening
    // Capture the monitor before the layer-shell surface takes focus. Keeping
    // this separate from the compositor's focused monitor prevents the menu from
    // hopping monitors while it is open.
    property var clipboardTargetMonitor: null
    property bool launcherVisible: false
    readonly property bool launcherRequested: launcherVisible
    property var launcherTargetMonitor: null
    property bool wallpaperPickerVisible: false
    property bool settingsVisible: false
    property bool focusSettingsPending: false
    property var settingsTargetScreen: null
    property bool externalDrivesMenuVisible: false
    property bool cpuStatsMenuVisible: false
    property bool ramStatsMenuVisible: false
    property bool sshSessionsMenuVisible: false
    property bool ttsMenuVisible: false
    readonly property bool panelChromeRequested: launcherRequested || clipboardRequested || quickSettingsVisible || notificationCenterVisible || externalDrivesMenuVisible || cpuStatsMenuVisible || ramStatsMenuVisible || sshSessionsMenuVisible || ttsMenuVisible
    property bool powerMenuVisible: false
    property string powerMenuMode: "menu"
    property string powerMenuAction: ""
    property string powerBusyAction: ""
    property int batteryWarningPreviewPercent: -1
    readonly property var battery: batteryServiceState.device
    readonly property bool hasBattery: batteryServiceState.present
    readonly property int batteryPercent: batteryServiceState.percent
    readonly property bool batteryDischarging: batteryServiceState.discharging
    readonly property bool batteryWarningRequested: batteryServiceState.onBattery && batteryDischarging && batteryPercent <= Theme.batteryCriticalThreshold
    property bool batteryWarningConfirmed: false
    readonly property bool batteryWarningPreviewActive: batteryWarningPreviewPercent >= 0
    readonly property bool batteryWarningVisible: batteryWarningPreviewActive || (batteryWarningRequested && batteryWarningConfirmed)
    readonly property int batteryWarningDisplayPercent: batteryWarningPreviewActive ? batteryWarningPreviewPercent : batteryPercent
    readonly property bool dictationOsdVisible: dictationServiceState.hasStatus && dictationServiceState.status !== "ready"
    readonly property bool ttsOsdVisible: ttsServiceState.hasStatus && !ttsServiceState.replayReady
    readonly property int dictationOsdStackIndex: batteryWarningVisible ? 1 : 0
    readonly property int ttsOsdStackIndex: (batteryWarningVisible ? 1 : 0) + (dictationOsdVisible ? 1 : 0)

    onBatteryWarningRequestedChanged: {
        batteryWarningConfirmed = false;
        if (batteryWarningRequested)
            batteryWarningDelay.restart();
        else
            batteryWarningDelay.stop();
    }
    Component.onCompleted: {
        if (batteryWarningRequested)
            batteryWarningDelay.restart();
    }

    function previewBatteryWarning(percentText) {
        const parsed = Number(percentText);
        batteryWarningPreviewPercent = !isNaN(parsed) ? Math.max(0, Math.min(100, Math.round(parsed))) : Theme.batteryCriticalThreshold;
        batteryWarningPreviewTimer.restart();
    }

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
            return;

        if (actionId === "toggle") {
            togglePowerMenu();
            return;
        }
        if (actionId === "open" || actionId === "menu") {
            openPowerMenu();
            return;
        }
        if (actionId === "close") {
            closePowerMenu();
            return;
        }
        if (powerActionNeedsConfirmation(actionId)) {
            closeAllPanels();
            powerMenuMode = "confirm";
            powerMenuAction = actionId;
            powerMenuVisible = true;
            return;
        }
        runPowerAction(actionId);
    }

    function confirmPowerAction() {
        if (!powerActionNeedsConfirmation(powerMenuAction))
            return;

        runPowerAction(powerMenuAction);
    }

    function clearPowerBusy(actionId) {
        if (powerBusyAction === actionId)
            powerBusyAction = "";
    }

    function runPowerAction(actionId) {
        if (powerBusyAction !== "")
            return;
        if ((actionId === "reboot" || actionId === "shutdown")
                && platformServiceState.systemPowerCommandPath.length === 0)
            return;

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

    function retainActiveWorkspaceFocus() {
        const workspace = compositorServiceState.focusedWorkspace;
        if (workspace)
            compositorServiceState.focusWorkspace(compositorServiceState.workspaceId(workspace));
    }

    function closeClipboard(restoreWorkspaceFocus = true) {
        if (restoreWorkspaceFocus && (clipboardVisible || clipboardOpening))
            retainActiveWorkspaceFocus();
        clipboardOpenTimer.stop();
        clipboardOpening = false;
        clipboardVisible = false;
    }

    function closeLauncher(restoreWorkspaceFocus = true) {
        if (restoreWorkspaceFocus && launcherVisible)
            retainActiveWorkspaceFocus();
        launcherVisible = false;
    }

    function closeWallpaperPicker() {
        wallpaperPickerVisible = false;
    }

    function toggleWallpaperPicker() {
        if (powerMenuVisible)
            return;

        const shouldClose = wallpaperPickerVisible;
        closeAllPanels();
        wallpaperPickerVisible = !shouldClose;
    }

    function openClipboard() {
        if (powerMenuVisible)
            return;

        clipboardTargetMonitor = compositorServiceState.focusedMonitor;
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
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
            return;

        if (clipboardVisible || clipboardOpening)
            closeClipboard();
        else
            openClipboard();
    }

    function openLauncher() {
        if (powerMenuVisible)
            return;

        launcherTargetMonitor = compositorServiceState.focusedMonitor;
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
        closeClipboard();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        launcherVisible = true;
    }

    function toggleLauncher() {
        if (powerMenuVisible)
            return;

        if (launcherVisible)
            closeLauncher();
        else
            openLauncher();
    }

    function closeExternalDrivesMenu() {
        externalDrivesMenuVisible = false;
    }

    function closeCpuStatsMenu() {
        cpuStatsMenuVisible = false;
    }

    function closeRamStatsMenu() {
        ramStatsMenuVisible = false;
    }

    function closeSshSessionsMenu() {
        sshSessionsMenuVisible = false;
    }

    function closeTtsMenu() {
        ttsMenuVisible = false;
    }

    function toggleTtsMenu() {
        if (ttsMenuVisible) {
            closeTtsMenu();
            return;
        }
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        ttsMenuVisible = true;
    }

    function toggleExternalDrivesMenu() {
        if (powerMenuVisible)
            return;

        if (externalDrivesMenuVisible) {
            closeExternalDrivesMenu();
            return;
        }
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
        closeClipboard();
        closeLauncher();
        closeWallpaperPicker();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        externalDrivesServiceState.refresh();
        externalDrivesMenuVisible = true;
    }

    function toggleCpuStatsMenu() {
        if (powerMenuVisible)
            return;

        if (cpuStatsMenuVisible) {
            closeCpuStatsMenu();
            return;
        }
        closeExternalDrivesMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
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
            return;

        if (ramStatsMenuVisible) {
            closeRamStatsMenu();
            return;
        }
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        systemDetailsServiceState.refreshRam();
        ramStatsMenuVisible = true;
    }

    function toggleSshSessionsMenu() {
        if (powerMenuVisible)
            return;

        if (sshSessionsMenuVisible) {
            closeSshSessionsMenu();
            return;
        }
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeTtsMenu();
        closeClipboard();
        closeLauncher();
        qsController.pinned = false;
        ncController.pinned = false;
        qsController.closeImmediately();
        ncController.closeImmediately();
        sshSessionsServiceState.refresh();
        sshSessionsMenuVisible = true;
    }

    function toggleQuickSettings() {
        if (powerMenuVisible)
            return;

        const shouldClose = qsController.open;
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
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

    function openSettings(targetScreen) {
        closeAllPanels();
        if (settingsVisible) {
            focusSettingsPending = true;
            compositorServiceState.requestClients();
            return;
        }
        settingsTargetScreen = targetScreen || Quickshell.screens.find(screen =>
            compositorServiceState.focusedMonitor && screen.name === compositorServiceState.monitorName(compositorServiceState.focusedMonitor)) || Quickshell.screens[0];
        settingsVisible = true;
    }

    function closeSettings() {
        settingsVisible = false;
    }

    function toggleNotificationCenter() {
        if (powerMenuVisible)
            return;

        const shouldClose = ncController.open;
        closeExternalDrivesMenu();
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
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
        closeCpuStatsMenu();
        closeRamStatsMenu();
        closeSshSessionsMenu();
        closeTtsMenu();
        closePowerMenu();
    }

    function routeBarMenuPress(targetScreen, pointX, pointY) {
        for (let i = 0; i < barWindows.instances.length; ++i) {
            const barWindow = barWindows.instances[i];
            if (barWindow.targetScreen === targetScreen)
                return barWindow.routeMenuPress(pointX, pointY);
        }

        return false;
    }

    function routeBarMenuHover(targetScreen, pointX, pointY) {
        for (let i = 0; i < barWindows.instances.length; ++i) {
            const barWindow = barWindows.instances[i];
            if (barWindow.targetScreen === targetScreen)
                return barWindow.routeMenuHover(pointX, pointY);
        }

        return false;
    }

    function clearBarMenuHover(targetScreen) {
        for (let i = 0; i < barWindows.instances.length; ++i) {
            const barWindow = barWindows.instances[i];
            if (barWindow.targetScreen === targetScreen) {
                barWindow.clearMenuHover();
                return;
            }
        }
    }

    IpcHandler {
        function toggle() {
            root.toggleQuickSettings();
        }

        target: "quicksettings"
    }

    IpcHandler {
        function open() {
            root.openSettings();
        }

        function close() {
            root.closeSettings();
        }

        target: "settings"
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

    IpcHandler {
        function toggle() {
            root.toggleWallpaperPicker();
        }

        function close() {
            root.closeWallpaperPicker();
        }

        target: "wallpaper"
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

    IpcHandler {
        function preview() {
            root.previewBatteryWarning(Theme.batteryCriticalThreshold);
        }

        function previewAt(percent: string) {
            root.previewBatteryWarning(percent);
        }

        target: "battery-warning"
    }

    Timer {
        id: batteryWarningPreviewTimer

        // The live warning remains visible until the battery state clears.
        // Give the development preview enough time for visual inspection.
        interval: 10000
        repeat: false
        onTriggered: root.batteryWarningPreviewPercent = -1
    }

    Timer {
        id: batteryWarningDelay

        interval: 3000
        repeat: false
        onTriggered: root.batteryWarningConfirmed = root.batteryWarningRequested
    }

    Process {
        id: lockProc

        command: ["sh", "-c", "exec \"$HOME/.local/bin/triton-lock\""]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("lock");
        }
    }

    Process {
        id: suspendProc

        command: [compositorServiceState.powerMenuCommandPath, "suspend"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("suspend");
        }
    }

    Process {
        id: logoutProc

        command: [compositorServiceState.logoutCommandPath]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("logout");
        }
    }

    Process {
        id: rebootProc

        command: [platformServiceState.systemPowerCommandPath, "reboot"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("reboot");
        }
    }

    Process {
        id: shutdownProc

        command: [platformServiceState.systemPowerCommandPath, "poweroff"]
        onRunningChanged: {
            if (!running)
                root.clearPowerBusy("shutdown");
        }
    }

    Process {
        id: ttsClipboardProc

        command: [compositorServiceState.ttsCommandPath, "speak-clipboard"]
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

        function onDefaultActionInvoked() {
            ncController.pinned = false;
            ncController.closeImmediately();
        }

        target: notificationStoreService
    }

    Services.CompositorService {
        id: compositorServiceState
    }

    Services.NotificationStore {
        id: notificationStoreService

        compositorService: compositorServiceState
        popupSuppressed: root.notificationCenterVisible
    }

    Connections {
        function onClientsListed(clients) {
            if (!root.focusSettingsPending)
                return;
            root.focusSettingsPending = false;
            const client = clients.find(entry => entry.title === "Quickshell Settings"
                && entry.class === "org.quickshell" && entry.mapped && !entry.hidden);
            if (client)
                compositorServiceState.focusWindow(client.address);
        }

        target: compositorServiceState
    }

    Services.AudioService {
        id: audioServiceState
    }

    Services.BrightnessService {
        id: brightnessServiceState

        platformService: platformServiceState
    }

    Services.DisplayService {
        id: displayServiceState

        compositorService: compositorServiceState
    }

    Services.PowerService {
        id: powerServiceState

        compositorService: compositorServiceState
    }

    Services.DictationService {
        id: dictationServiceState
    }

    Services.TtsService {
        id: ttsServiceState

        compositorService: compositorServiceState
    }

    Services.PlatformService {
        id: platformServiceState
    }

    Services.BatteryService {
        id: batteryServiceState

        platformService: platformServiceState
    }

    Services.PowerProfileService {
        id: powerProfileServiceState

        platformService: platformServiceState
    }

    Services.NetworkService {
        id: networkServiceState

        platformService: platformServiceState
    }

    Services.InputService {
        id: inputServiceState

        platformService: platformServiceState
    }

    Services.ClipboardService {
        id: clipboardServiceState
    }

    Services.ExternalDrivesService {
        id: externalDrivesServiceState

        platformService: platformServiceState
    }

    Services.SystemDetailsService {
        id: systemDetailsServiceState

        platformService: platformServiceState
    }

    Services.SshSessionsService {
        id: sshSessionsServiceState
    }

    Services.LauncherService {
        id: launcherServiceState
    }

    Overlays.SettingsWindow {
        targetScreen: root.settingsTargetScreen
        displayService: displayServiceState
        powerService: powerServiceState
        open: root.settingsVisible
        onCloseRequested: root.closeSettings()
    }

    Variants {
        id: barWindows

        model: Quickshell.screens

        delegate: Component {
            Bar.BarWindow {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)
                readonly property bool fullscreenPanelChromeActive: activeScreen && root.panelChromeRequested && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)

                targetScreen: modelData
                compositorService: compositorServiceState
                showBar: activeScreen
                forceOverlay: fullscreenPanelChromeActive
                quickSettingsOpen: root.quickSettingsVisible
                notificationCenterOpen: root.notificationCenterVisible
                clipboardOpen: root.clipboardRequested
                externalDrivesOpen: root.externalDrivesMenuVisible
                cpuStatsOpen: root.cpuStatsMenuVisible
                ramStatsOpen: root.ramStatsMenuVisible
                sshSessionsOpen: root.sshSessionsMenuVisible
                ttsOpen: root.ttsMenuVisible
                notificationStore: notificationStoreService
                audioService: audioServiceState
                batteryService: batteryServiceState
                brightnessService: brightnessServiceState
                networkService: networkServiceState
                platformService: platformServiceState
                inputService: inputServiceState
                externalDrivesService: externalDrivesServiceState
                sshSessionsService: sshSessionsServiceState
                onQuickSettingsClicked: root.toggleQuickSettings()
                onNotificationCenterClicked: root.toggleNotificationCenter()
                onClipboardClicked: root.toggleClipboard()
                onExternalDrivesClicked: root.toggleExternalDrivesMenu()
                onCpuStatsClicked: root.toggleCpuStatsMenu()
                onRamStatsClicked: root.toggleRamStatsMenu()
                onSshSessionsClicked: root.toggleSshSessionsMenu()
                onTtsClicked: root.toggleTtsMenu()
                onQuickSettingsHoveredChanged: hovered => {
                    qsController.triggerHovered = false;
                }
                onNotificationCenterHoveredChanged: hovered => {
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
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)

                targetScreen: modelData
                detailsService: systemDetailsServiceState
                open: root.cpuStatsMenuVisible && activeScreen
                fullscreenActive: activeScreen && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)
                onCloseRequested: root.closeCpuStatsMenu()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar.TtsMenu {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)

                targetScreen: modelData
                ttsService: ttsServiceState
                open: root.ttsMenuVisible && activeScreen
                fullscreenActive: activeScreen && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)
                onCloseRequested: root.closeTtsMenu()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Overlays.TtsOSD {
                required property var modelData

                targetScreen: modelData
                active: root.isShellScreen(modelData)
                ttsService: ttsServiceState
                stackIndex: root.ttsOsdStackIndex
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Overlays.DictationOSD {
                required property var modelData

                targetScreen: modelData
                active: root.isShellScreen(modelData)
                dictationService: dictationServiceState
                stackIndex: root.dictationOsdStackIndex
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.RamStatsMenu {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)

                targetScreen: modelData
                detailsService: systemDetailsServiceState
                open: root.ramStatsMenuVisible && activeScreen
                fullscreenActive: activeScreen && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)
                onCloseRequested: root.closeRamStatsMenu()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.SshSessionsMenu {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)

                targetScreen: modelData
                sshService: sshSessionsServiceState
                open: root.sshSessionsMenuVisible && activeScreen
                fullscreenActive: activeScreen && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)
                onCloseRequested: root.closeSshSessionsMenu()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar.ExternalDrivesMenu {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)

                targetScreen: modelData
                driveService: externalDrivesServiceState
                open: root.externalDrivesMenuVisible && activeScreen
                fullscreenActive: activeScreen && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)
                onCloseRequested: root.closeExternalDrivesMenu()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Overlays.ScreenFrameOverlay {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)
                readonly property bool fullscreenPanelChromeActive: activeScreen && root.panelChromeRequested && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)

                targetScreen: modelData
                hasBar: activeScreen
                forceOverlay: fullscreenPanelChromeActive
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                notificationStore: notificationStoreService
                audioService: audioServiceState
                batteryService: batteryServiceState
                powerProfileService: powerProfileServiceState
                platformService: platformServiceState
                brightnessService: brightnessServiceState
                displayService: displayServiceState
                networkService: networkServiceState
                onOutsidePressed: root.closeAllPanels()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
                onPowerActionRequested: actionId => {
                    return root.requestPowerAction(actionId);
                }
                onSettingsRequested: root.openSettings(modelData)
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
            Overlays.BatteryWarningOSD {
                required property var modelData

                targetScreen: modelData
                active: root.isShellScreen(modelData)
                warningVisible: root.batteryWarningVisible
                displayedPercent: root.batteryWarningDisplayPercent
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Overlays.InputMethodOSD {
                required property var modelData

                targetScreen: modelData
                active: root.isShellScreen(modelData)
                inputService: inputServiceState
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Overlays.PowerMenuOSD {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)

                targetScreen: modelData
                active: activeScreen
                open: root.powerMenuVisible && activeScreen
                mode: root.powerMenuMode
                actionId: root.powerMenuAction
                busyAction: root.powerBusyAction
                onActionRequested: actionId => {
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
                readonly property bool activeScreen: root.isShellScreen(modelData)
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)
                readonly property bool notificationOverlayActive: activeScreen && root.notificationCenterVisible && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)

                targetScreen: modelData
                showLayer: activeScreen
                forceOverlay: notificationOverlayActive
                notificationStore: notificationStoreService
                notificationCenterVisible: root.notificationCenterVisible && activeScreen
                quickSettingsVisible: root.quickSettingsVisible && activeScreen
                onOutsidePressed: root.closeAllPanels()
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
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
            Wallpaper.WallpaperOverlay {
                required property var modelData
                readonly property bool activeScreen: root.isShellScreen(modelData)

                targetScreen: modelData
                compositorService: compositorServiceState
                open: root.wallpaperPickerVisible && activeScreen
                onRequestClose: root.closeWallpaperPicker()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Launcher.LauncherOverlay {
                required property var modelData
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)
                // Use the configured primary while compositor's initial monitor
                // list is loading. Normal openings use the monitor that held
                // focus when the shortcut was pressed.
                readonly property bool legacyMenuScreen: root.isShellScreen(modelData)
                readonly property bool menuScreen: root.launcherTargetMonitor ? compositorServiceState.sameMonitor(compositorMonitor, root.launcherTargetMonitor) : legacyMenuScreen
                readonly property bool launcherOverlayActive: menuScreen && root.launcherRequested && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)

                targetScreen: modelData
                showLayer: true
                launcherVisible: root.launcherVisible && menuScreen
                dismissOnOutsideClick: root.launcherVisible && !menuScreen
                forceOverlay: launcherOverlayActive
                launcherService: launcherServiceState
                onOutsidePressed: restoreWorkspaceFocus => root.closeLauncher(restoreWorkspaceFocus)
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
                onBarHovered: (x, y) => root.routeBarMenuHover(modelData, x, y)
                onBarHoverCleared: root.clearBarMenuHover(modelData)
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Clipboard.ClipboardOverlay {
                required property var modelData
                readonly property var compositorMonitor: compositorServiceState.monitorFor(modelData)
                readonly property var activeWorkspace: compositorServiceState.activeWorkspaceFor(modelData)
                readonly property bool legacyMenuScreen: root.isShellScreen(modelData)
                readonly property bool menuScreen: root.clipboardTargetMonitor ? compositorServiceState.sameMonitor(compositorMonitor, root.clipboardTargetMonitor) : legacyMenuScreen
                readonly property bool clipboardOverlayActive: menuScreen && root.clipboardRequested && activeWorkspace && compositorServiceState.workspaceHasFullscreen(activeWorkspace)

                targetScreen: modelData
                showLayer: true
                clipboardVisible: root.clipboardVisible && menuScreen
                dismissOnOutsideClick: root.clipboardVisible && !menuScreen
                forceOverlay: clipboardOverlayActive
                clipboardService: clipboardServiceState
                onOutsidePressed: restoreWorkspaceFocus => root.closeClipboard(restoreWorkspaceFocus)
                onBarPressed: (x, y) => root.routeBarMenuPress(modelData, x, y)
                onBarHovered: (x, y) => root.routeBarMenuHover(modelData, x, y)
                onBarHoverCleared: root.clearBarMenuHover(modelData)
            }
        }
    }
}
