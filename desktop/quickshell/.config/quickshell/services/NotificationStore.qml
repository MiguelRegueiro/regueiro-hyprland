import QtCore
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "../theme/Theme.js" as Theme

// Keep this file manually formatted. Forcing qmlformat on it caused notification regressions.
Item {
    id: root

    property bool dnd: false
    property bool popupSuppressed: false
    property var notifications: []
    property var popups: []
    readonly property int count: notifications.length
    readonly property bool holdOpen: holdOpenTimer.running
    property string clickedDesktopEntry: ""
    property string clickedAppName: ""

    signal allDismissed()
    signal defaultActionInvoked()

    Timer {
        id: holdOpenTimer
        interval: Theme.notificationHoldDelay
        repeat: false
    }

    // A notification click is an explicit request to visit its app. Resolve
    // that window directly; ordinary app activation requests remain disabled.
    Timer {
        id: focusClickedAppDelay
        interval: 80
        onTriggered: {
            if (!focusClickedApp.running)
                focusClickedApp.running = true;
        }
    }

    Process {
        id: focusClickedApp
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const target = root.findClickedApp(JSON.parse(text), root.clickedDesktopEntry, root.clickedAppName);
                    if (target && /^0x[0-9a-f]+$/i.test(target.address))
                        Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:" + target.address) + " })");
                } catch (error) {
                    console.warn("Could not focus notification app:", error);
                }
            }
        }
    }

    Settings {
        id: notificationTimes
        category: "NotificationTimes"
        location: Qt.resolvedUrl("../notification-times.ini")
    }

    Settings {
        id: notificationPrefs
        category: "NotificationPreferences"
        location: Qt.resolvedUrl(Quickshell.statePath("notification-preferences.ini"))
    }

    onPopupSuppressedChanged: {
        if (popupSuppressed)
            popups = []
    }

    function itemTimeKey(id) {
        return "notif_" + id
    }

    function storedTime(id) {
        const value = Number(notificationTimes.value(itemTimeKey(id), 0))
        return Number.isFinite(value) && value > 0 ? value : 0
    }

    function rememberTime(id, ms) {
        notificationTimes.setValue(itemTimeKey(id), ms)
    }

    function clearTime(id) {
        notificationTimes.setValue(itemTimeKey(id), 0)
    }

    function removeById(id) {
        notifications = notifications.filter(item => item.notif.id !== id)
        popups = popups.filter(item => item.notif.id !== id)
    }

    function attachLifecycle(item) {
        item.notif.closed.connect(function() {
            root.clearTime(item.notif.id)
            root.removeById(item.notif.id)
        })
    }

    function dismiss(item) {
        holdOpenTimer.restart()
        item.notif.dismiss()
        clearTime(item.notif.id)
        removeById(item.notif.id)
    }

    function dismissPopup(item) {
        popups = popups.filter(entry => entry.notif.id !== item.notif.id)
    }

    function dismissAll() {
        holdOpenTimer.stop()
        for (const item of notifications) {
            item.notif.dismiss()
            clearTime(item.notif.id)
        }
        notifications = []
        popups = []
        root.allDismissed()
    }

    function storedBool(key, fallback) {
        const value = notificationPrefs.value(key, fallback)
        if (typeof value === "boolean")
            return value

        if (typeof value === "number")
            return value !== 0

        const normalized = String(value).toLowerCase()
        if (normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on")
            return true

        if (normalized === "false" || normalized === "0" || normalized === "no" || normalized === "off")
            return false

        return fallback
    }

    function setDnd(enabled) {
        const next = !!enabled
        if (dnd === next)
            return

        dnd = next
        notificationPrefs.setValue("dnd", next)

        // Do Not Disturb affects visible banners as well as incoming ones.
        // Keep the notification history intact for the notification center.
        if (next)
            popups = []
    }

    function toggleDnd() {
        root.setDnd(!dnd)
    }

    function hasDefaultAction(notif) {
        if (!notif || !notif.actions)
            return false

        return notif.actions.some(action => action.identifier === "default")
    }

    function appKey(value) {
        return String(value || "").replace(/\.desktop$/i, "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function findClickedApp(clients, desktopEntry, appName) {
        if (!Array.isArray(clients))
            return null;
        const entry = appKey(desktopEntry);
        const name = appKey(appName);
        if (!entry && !name)
            return null;
        let best = null;
        let bestScore = 0;
        for (const client of clients) {
            const app = appKey(client.class);
            if (!app || !/^0x[0-9a-f]+$/i.test(String(client.address || "")))
                continue;
            let score = 0;
            if (entry && (app === entry || entry.endsWith(app) || app.endsWith(entry)))
                score = 4;
            else if (name && (app === name || app.endsWith(name)))
                score = 2;
            if (score === 0)
                continue;
            if (client.urgent)
                score += 1;
            if (score > bestScore || (score === bestScore && Number(client.focusHistoryID) < Number(best.focusHistoryID))) {
                best = client;
                bestScore = score;
            }
        }
        return best;
    }

    function invokeDefault(notif) {
        if (!notif || !notif.actions)
            return false

        for (const action of notif.actions) {
            if (action.identifier === "default") {
                clickedDesktopEntry = notif.desktopEntry || "";
                clickedAppName = notif.appName || "";
                action.invoke()
                root.defaultActionInvoked();
                if (clickedDesktopEntry || clickedAppName)
                    focusClickedAppDelay.restart();
                return true
            }
        }

        return false
    }

    function iconOverride(appName, appIcon) {
        const icon = (appIcon || "").toLowerCase()
        const name = (appName || "").toLowerCase()

        if (icon === "blueman" || name.includes("blueman") || name.includes("bluetooth"))
            return "󰂯"

        return ""
    }

    Component.onCompleted: {
        dnd = root.storedBool("dnd", false)
    }

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        persistenceSupported: true

        onNotification: notif => {
            const body = (notif.body || "").toLowerCase()
            const summary = (notif.summary || "").toLowerCase()
            if (body.includes("0%") || summary.includes("0%")) {
                notif.tracked = false
                return
            }

            notif.tracked = true

            const seenAt = notif.lastGeneration ? (root.storedTime(notif.id) || Date.now()) : Date.now()
            root.rememberTime(notif.id, seenAt)

            const item = { notif: notif, time: seenAt }
            root.attachLifecycle(item)
            root.notifications = [item, ...root.notifications.filter(entry => entry.notif.id !== notif.id)]

            if (!notif.lastGeneration && !root.popupSuppressed && (!root.dnd || notif.urgency === NotificationUrgency.Critical))
                root.popups = [item, ...root.popups.filter(entry => entry.notif.id !== notif.id)]
        }
    }
}
