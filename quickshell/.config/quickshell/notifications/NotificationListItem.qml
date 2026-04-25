import QtQuick
import Quickshell.Services.Notifications
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore
    required property var item
    property int timeTick: 0

    readonly property var notif: item ? item.notif : null
    readonly property bool isCritical: notif !== null && notif.urgency === NotificationUrgency.Critical
    readonly property bool canActivate: notif !== null && notificationStore.hasDefaultAction(notif)
    property color cardColor: cardHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg
    property color cardBorderColor: root.isCritical
        ? Qt.rgba(1, 0.48, 0.39, 0.26)
        : (cardHover.hovered ? Theme.qsEdge : Theme.qsEdgeSoft)

    width: ListView.view ? ListView.view.width : 0
    implicitHeight: card.implicitHeight

    Behavior on cardColor {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }
    }

    Behavior on cardBorderColor {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }
    }

    HoverHandler {
        id: cardHover
        blocking: false
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 30
        radius: Theme.qsRadius + 2
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorderColor
        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: root.canActivate
            hoverEnabled: root.canActivate
            cursorShape: root.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.notif)
                    root.notificationStore.invokeDefault(root.notif)
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
                margins: 1
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
            }
            width: parent.width - (root.isCritical ? 36 : 32)
            notificationStore: root.notificationStore
            notif: root.notif
            timestampText: {
                root.timeTick
                return root.item ? root.notificationStore.timeAgo(root.item.time) : ""
            }
            onDismissRequested: root.notificationStore.dismiss(root.item)
        }
    }
}
