import QtQuick
import QtQuick.Effects
import Quickshell.Services.Notifications
import "../theme/Theme.js" as Theme
import "../utils/DateUtils.js" as DateUtils

Item {
    id: root

    required property var notificationStore
    required property var item
    property int timeTick: 0

    readonly property var notif: item ? item.notif : null
    readonly property bool isCritical: notif !== null && notif.urgency === NotificationUrgency.Critical
    readonly property bool canActivate: notif !== null && notificationStore.hasDefaultAction(notif)
    property color cardColor: root.canActivate && cardHover.hovered
        ? Qt.rgba(0.115, 0.115, 0.115, 0.98)
        : Qt.rgba(0.098, 0.098, 0.098, 0.96)
    property color cardBorderColor: root.isCritical
        ? Qt.rgba(1, 0.48, 0.39, root.canActivate && cardHover.hovered ? 0.24 : 0.19)
        : (root.canActivate && cardHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.10))

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
        implicitHeight: content.implicitHeight + 26
        radius: Theme.qsRadius + 1
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorderColor
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, root.canActivate && cardHover.hovered ? 0.18 : 0.12)
            shadowBlur: 0.55
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
            blurMax: 24
        }

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

        NotificationContent {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 14
                topMargin: 14
            }
            width: parent.width - 28
            notificationStore: root.notificationStore
            notif: root.notif
            minimalChrome: true
            emphasizeCriticalSummary: true
            timestampText: {
                root.timeTick
                return root.item ? DateUtils.timeAgo(root.item.time) : ""
            }
            onDismissRequested: root.notificationStore.dismiss(root.item)
        }
    }
}
