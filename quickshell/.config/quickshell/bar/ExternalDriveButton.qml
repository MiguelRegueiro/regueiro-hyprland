import QtQuick
import QtQuick.Shapes
import "../theme/Theme.js" as Theme

Rectangle {
    id: btn

    property int barHeight: 34
    readonly property bool hovered: hover.hovered

    signal clicked()
    signal rightClicked()

    height: barHeight - 8
    implicitWidth: 34
    radius: Theme.radiusSmall
    color: hovered ? Theme.hoverBg : "transparent"

    Item {
        id: glyph

        width: 16
        height: 16
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.textPrimary
                strokeColor: "transparent"
                strokeWidth: 0

                PathMove {
                    x: 8
                    y: 4.5
                }

                PathLine {
                    x: 13.5
                    y: 10
                }

                PathLine {
                    x: 2.5
                    y: 10
                }

                PathLine {
                    x: 8
                    y: 4.5
                }
            }
        }

        Rectangle {
            x: 2.5
            y: 12.5
            width: 11
            height: 2
            radius: 1
            color: Theme.textPrimary
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
        onClicked: (mouse) => {
            return mouse.button === Qt.RightButton ? btn.rightClicked() : btn.clicked();
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }
    }
}
