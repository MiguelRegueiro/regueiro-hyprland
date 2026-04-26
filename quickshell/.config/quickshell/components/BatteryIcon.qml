import QtQuick
import "../theme/Theme.js" as Theme

Item {
    id: root

    property int percent: 0
    property bool charging: false
    property bool full: false
    readonly property color stateColor: percent <= Theme.batteryLowThreshold ? Theme.red : (charging || full) ? Theme.green : Qt.rgba(1, 1, 1, 0.85)

    width: 24
    height: 12

    // Body outline
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 21
        height: 12
        radius: 3
        color: "transparent"
        border.width: 1.5
        border.color: root.stateColor

        Item {
            clip: true

            anchors {
                fill: parent
                margins: 2.5
            }

            Rectangle {
                anchors.fill: parent
                radius: 1
                visible: root.charging && !root.full
                color: Qt.rgba(0.18, 0.72, 0.36, 0.26)
            }

            Rectangle {
                width: Math.max(0, parent.width * root.percent / 100)
                radius: 1
                color: root.charging || root.full ? Theme.green : root.percent <= Theme.batteryLowThreshold ? Theme.red : Theme.textPrimary

                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.batteryFillDuration
                    }

                }

            }

        }

        Text {
            anchors.centerIn: parent
            visible: root.charging
            text: "󱐋"
            font.family: Theme.fontIcons
            font.pixelSize: 8
            color: Qt.rgba(0, 0, 0, 0.9)
        }

    }

    // Terminal nub
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 5
        radius: 1
        color: root.stateColor
    }

}
