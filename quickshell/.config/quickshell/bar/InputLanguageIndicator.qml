import QtQuick
import "../theme/Theme.js" as Theme

Rectangle {
    id: langBtn

    required property var inputService

    property int barHeight: 34

    height: barHeight - 8
    implicitWidth: Math.max(langLabel.implicitWidth + 16, 36)
    radius: Theme.radiusSmall
    readonly property bool hovered: hover.hovered
    color: hovered ? Theme.hoverBg : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

    Text {
        id: langLabel
        anchors.centerIn: parent
        text: inputService.ready ? inputService.methods[inputService.activeIndex].label : "es"
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
        onClicked: inputService.toggle()
    }
}
