import QtQuick
import QtQuick.Effects
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
    readonly property color toastSurfaceColor: Theme.popupBg
    readonly property color toastSurfaceHoverColor: Qt.rgba(0.088, 0.088, 0.088, 1.0)

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
        duration: Theme.toastOpenDuration
        easing.type: Easing.OutExpo
    }

    SequentialAnimation {
        id: exitAnimation
        NumberAnimation {
            target: root
            property: "revealProgress"
            to: 0
            duration: Theme.toastCloseDuration
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
        implicitHeight: body.implicitHeight
        radius: Theme.qsRadius + 1
        color: "transparent"
        border.width: 0

        HoverHandler {
            id: toastHover
            blocking: false
        }

        Rectangle {
            id: body
            anchors {
                fill: parent
            }
            implicitHeight: content.implicitHeight + 34
            radius: Theme.qsRadius + 3
            color: toastHover.hovered && root.canActivate
                ? root.toastSurfaceHoverColor
                : root.toastSurfaceColor
            border.width: 1
            border.color: root.isCritical
                ? Qt.rgba(1, 0.48, 0.39, toastHover.hovered && root.canActivate ? 0.30 : 0.26)
                : (toastHover.hovered && root.canActivate ? Qt.rgba(1, 1, 1, 0.11) : Theme.barBorder)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.52 * root.revealProgress)
                shadowBlur: 0.96
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
                blurMax: 42
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

            MouseArea {
                anchors.fill: parent
                enabled: root.canActivate
                hoverEnabled: root.canActivate
                cursorShape: root.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                    topMargin: 1
                    bottomMargin: 1
                }
                color: Theme.red
            }

            NotificationContent {
                id: content
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                    leftMargin: root.isCritical ? 20 : 16
                    topMargin: 14
                    bottomMargin: 18
                }
                width: parent.width - (root.isCritical ? 36 : 32)
                notificationStore: root.notificationStore
                notif: root.notif
                emphasizeCriticalSummary: true
                onDismissRequested: root.dismiss()
            }
        }
    }
}
