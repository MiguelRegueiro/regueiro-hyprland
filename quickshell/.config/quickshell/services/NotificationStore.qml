import QtCore
import QtQuick
import Quickshell
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

    signal allDismissed()

    Timer {
        id: holdOpenTimer
        interval: Theme.notificationHoldDelay
        repeat: false
    }

    Settings {
        id: notificationTimes
        category: "NotificationTimes"
        location: Qt.resolvedUrl("../notification-times.ini")
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

    function toggleDnd() {
        dnd = !dnd
    }

    function hasDefaultAction(notif) {
        if (!notif || !notif.actions)
            return false

        return notif.actions.some(action => action.identifier === "default")
    }

    function invokeDefault(notif) {
        if (!notif || !notif.actions)
            return false

        for (const action of notif.actions) {
            if (action.identifier === "default") {
                action.invoke()
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
