import QtQuick
import "../theme/Theme.js" as Theme

Item {
    id: root

    property int percent: 0
    property bool charging: false
    property bool full: false
    readonly property real fillFraction: Math.max(0, Math.min(1, root.percent / 100))
    readonly property color outlineColor: Qt.rgba(1, 1, 1, 0.9)

    width: 24
    height: 12

    // Body outline
    Rectangle {
        id: batteryBody

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 21
        height: 12
        radius: 3
        color: "transparent"
        border.width: 1.5
        border.color: root.outlineColor

        Item {
            id: chargeArea

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
                width: chargeArea.width * root.fillFraction
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
            id: chargeBoltBase

            anchors.centerIn: parent
            visible: root.charging
            text: "󱐋"
            font.family: Theme.fontIcons
            font.pixelSize: 8 + Theme.fontSizeDelta
            color: root.outlineColor
        }

        Item {
            id: chargedBoltClip

            x: chargeArea.x
            y: 0
            width: chargeArea.width * root.fillFraction
            height: parent.height
            visible: root.charging
            clip: true

            Text {
                x: (batteryBody.width - implicitWidth) / 2 - chargedBoltClip.x
                y: (batteryBody.height - implicitHeight) / 2
                text: "󱐋"
                font.family: Theme.fontIcons
                font.pixelSize: 8 + Theme.fontSizeDelta
                color: Qt.rgba(0, 0, 0, 0.9)
            }

            Behavior on width {
                NumberAnimation {
                    duration: Theme.batteryFillDuration
                }

            }

        }

    }

    // Terminal nub
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 5
        radius: 1
        color: root.outlineColor
    }

}
