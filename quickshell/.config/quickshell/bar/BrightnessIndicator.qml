import QtQuick
import "../theme/Theme.js" as Theme

Rectangle {
    id: root

    required property var brightnessService

    property int barHeight: 34
    readonly property bool hovered: hover.hovered

    height: barHeight - 8
    implicitWidth: brightnessRow.implicitWidth + 20
    radius: Theme.radiusSmall
    color: hovered ? Theme.hoverBg : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }
    }

    Row {
        id: brightnessRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.brightnessService.iconText
            font.family: Theme.fontIcons
            font.pixelSize: 14
            color: Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.brightnessService.percent + "%"
            font.family: Theme.fontUi
            font.pixelSize: 12
            color: Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => root.brightnessService.adjust(wheel.angleDelta.y > 0 ? 5 : -5)
    }
}
