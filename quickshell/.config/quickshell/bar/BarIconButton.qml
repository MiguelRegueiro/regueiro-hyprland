import QtQuick
import "../theme/Theme.js" as Theme

Rectangle {
    id: btn

    property int barHeight: 34
    property int padH: 10
    property string iconText: ""
    property color iconColor: Theme.textPrimary
    property int iconSize: 13

    signal clicked()
    signal rightClicked()
    signal scrollUp()
    signal scrollDown()

    readonly property bool hovered: hover.hovered

    height: barHeight - 8
    implicitWidth: lbl.implicitWidth + padH * 2
    radius: Theme.radiusSmall
    color: hovered ? Theme.hoverBg : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

    Text {
        id: lbl
        anchors.centerIn: parent
        text: btn.iconText
        color: btn.iconColor
        font.family: Theme.fontIcons
        font.pixelSize: btn.iconSize
        font.weight: Font.DemiBold
    }

    HoverHandler {
        id: hover
        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? btn.rightClicked() : btn.clicked()
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) btn.scrollUp()
            else btn.scrollDown()
        }
    }
}
