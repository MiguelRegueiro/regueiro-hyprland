import QtQuick
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore
    required property var item
    property int listIndex: -1
    property int timeTick: 0

    readonly property var notif: item ? item.notif : null
    readonly property bool canActivate: notif !== null && notificationStore.hasDefaultAction(notif)
    readonly property int resolvedIndex: {
        if (!root.item || !root.notif)
            return -1

        for (let i = 0; i < root.notificationStore.notifications.length; ++i) {
            const entry = root.notificationStore.notifications[i]
            if (entry.notif.id === root.notif.id)
                return i
        }

        return root.listIndex
    }

    width: ListView.view ? ListView.view.width : 0
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width

        Rectangle {
            visible: root.resolvedIndex > 0
            width: parent.width
            height: 1
            color: Theme.qsEdgeSoft
        }

        Rectangle {
            width: parent.width
            height: content.implicitHeight + 20
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                enabled: root.canActivate
                cursorShape: Qt.ArrowCursor
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
                    topMargin: 10
                }
                width: parent.width - 28
                notificationStore: root.notificationStore
                notif: root.notif
                compact: true
                timestampText: {
                    root.timeTick
                    return root.item ? root.notificationStore.timeAgo(root.item.time) : ""
                }
                onDismissRequested: root.notificationStore.dismiss(root.item)
            }
        }
    }
}
