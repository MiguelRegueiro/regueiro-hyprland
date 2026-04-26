import QtQuick
import "../theme/Theme.js" as Theme

Rectangle {
    id: langBtn

    required property var inputService
    property int barHeight: 34
    readonly property bool hovered: hover.hovered

    height: barHeight - 8
    implicitWidth: Math.max(langLabel.implicitWidth + 16, 36)
    radius: Theme.radiusSmall
    color: hovered ? Theme.hoverBg : "transparent"

    Text {
        id: langLabel

        anchors.centerIn: parent
        text: inputService.currentLabel
        color: Theme.textPrimary
        font.family: Theme.fontUi
        font.pixelSize: 15
        font.weight: Font.Bold
        font.letterSpacing: 0.5
    }

    HoverHandler {
        id: hover

        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: inputService.cycleNext()
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }

    }

}
