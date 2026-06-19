import QtQuick
import QtQuick.Layouts
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var sshService
    property int barHeight: Theme.barHeight
    signal clicked()
    signal rightClicked()

    implicitWidth: 32
    implicitHeight: barHeight

    readonly property int sessionCount: sshService && sshService.sessions ? sshService.sessions.length : 0

    Rectangle {
        anchors.centerIn: parent
        width: 28
        height: 26
        radius: 13
        color: hover.hovered ? Theme.hoverBg : "transparent"

        Text {
            anchors.centerIn: parent
            text: ""
            font.family: Theme.fontIcons
            font.pixelSize: 14 + Theme.fontSizeDelta
            font.weight: Font.DemiBold
            color: root.sessionCount > 0 ? Theme.textPrimary : Theme.textDim
        }

        Rectangle {
            visible: root.sessionCount > 0
            width: Math.max(14, countText.implicitWidth + 6)
            height: 14
            radius: 7
            color: Theme.accent

            anchors {
                right: parent.right
                top: parent.top
                rightMargin: -2
                topMargin: 1
            }

            Text {
                id: countText

                anchors.centerIn: parent
                text: root.sessionCount > 9 ? "9+" : String(root.sessionCount)
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 9 + Theme.fontSizeDelta
                font.weight: Font.DemiBold
            }
        }
    }

    HoverHandler {
        id: hover

        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
