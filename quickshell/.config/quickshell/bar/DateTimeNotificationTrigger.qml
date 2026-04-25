import QtQuick
import Quickshell
import "../theme/Theme.js" as Theme

Row {
    id: root

    required property var notificationStore

    property int barHeight: 34
    readonly property bool hovered: triggerHover.hovered

    signal notificationCenterClicked()

    readonly property bool hasNotification: notificationStore.count > 0
    readonly property bool doNotDisturb: notificationStore.dnd

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverHandler {
        id: triggerHover
        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        height: root.barHeight - 8
        width: pillContent.implicitWidth + 20
        radius: Theme.radiusSmall
        color: Theme.barBg

        Row {
            id: pillContent
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.doNotDisturb ? "󰂛" : root.hasNotification ? "󰂚" : "󰂜"
                color: root.doNotDisturb ? Theme.textDisabled
                     : root.hasNotification ? Theme.textPrimary
                     : Theme.textDim
                font.family: Theme.fontIcons
                font.pixelSize: 14
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: parent.height - 4
                color: Theme.barBorder
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const date = clock.date
                    if (!date)
                        return ""

                    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                    const hours = String(date.getHours()).padStart(2, "0")
                    const minutes = String(date.getMinutes()).padStart(2, "0")
                    return months[date.getMonth()] + " " + date.getDate() + "  " + hours + ":" + minutes
                }
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width / 2
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.notificationStore.toggleDnd()
                else
                    root.notificationCenterClicked()
            }
        }

        MouseArea {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width / 2
            cursorShape: Qt.ArrowCursor
            onClicked: root.notificationCenterClicked()
        }
    }
}
