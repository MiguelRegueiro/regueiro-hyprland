import QtQuick
import Quickshell.Services.Notifications
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore
    required property var item

    signal closeRequested()

    readonly property var notif: item ? item.notif : null
    readonly property bool isCritical: notif !== null && notif.urgency === NotificationUrgency.Critical
    readonly property bool canActivate: notif !== null && notificationStore.hasDefaultAction(notif)

    property real revealProgress: 0
    property bool exiting: false

    implicitWidth: Theme.toastWidth
    implicitHeight: card.implicitHeight

    opacity: revealProgress
    transform: Translate { x: (1 - root.revealProgress) * 22 }

    NumberAnimation {
        id: entryAnimation
        target: root
        property: "revealProgress"
        to: 1
        duration: 220
        easing.type: Easing.OutExpo
    }

    SequentialAnimation {
        id: exitAnimation
        NumberAnimation {
            target: root
            property: "revealProgress"
            to: 0
            duration: 150
            easing.type: Easing.InQuart
        }

        ScriptAction {
            script: root.closeRequested()
        }
    }

    Component.onCompleted: entryAnimation.start()

    function dismiss() {
        if (exiting)
            return

        exiting = true
        autoClose.stop()
        entryAnimation.stop()
        exitAnimation.start()
    }

    Timer {
        id: autoClose
        interval: root.notif && root.notif.expireTimeout > 0 ? root.notif.expireTimeout : 5000
        running: root.revealProgress > 0.5 && !root.exiting
        onTriggered: root.dismiss()
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 24 + 2
        radius: Theme.qsRadius
        color: Theme.menuBg
        border.color: root.isCritical ? Qt.rgba(1, 0.48, 0.39, 0.55) : Theme.qsEdge
        border.width: 1.1

        MouseArea {
            anchors.fill: parent
            enabled: root.canActivate
            cursorShape: Qt.ArrowCursor
            onClicked: {
                if (root.notif && root.notificationStore.invokeDefault(root.notif))
                    root.dismiss()
            }
        }

        Rectangle {
            visible: root.isCritical
            width: 3
            radius: 2
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: 1
            }
            color: Theme.red
        }

        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: 1
                bottomMargin: 1
            }
            height: 2
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.05)

            Rectangle {
                id: progressFill
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width
                radius: 1
                color: root.isCritical ? Theme.red : Theme.accent

                NumberAnimation on width {
                    from: progressFill.parent.width
                    to: 0
                    duration: autoClose.interval
                    running: true
                }
            }
        }

        NotificationContent {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
                leftMargin: root.isCritical ? 18 : 12
                topMargin: 12
            }
            width: parent.width - (root.isCritical ? 30 : 24)
            notificationStore: root.notificationStore
            notif: root.notif
            emphasizeCriticalSummary: true
            onDismissRequested: root.dismiss()
        }
    }
}
