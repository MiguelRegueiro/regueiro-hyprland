import QtQuick
import "../components" as Components
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

    Row {
        id: brightnessRow

        anchors.centerIn: parent
        spacing: 5

        Components.BrightnessIcon {
            iconColor: Theme.textDim
            height: 15
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.brightnessService.percent + "%"
            font.family: Theme.fontUi
            font.pixelSize: 13
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
        onWheel: (wheel) => {
            return root.brightnessService.adjust(wheel.angleDelta.y > 0 ? 5 : -5);
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }

    }

}
