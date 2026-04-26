import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme

Rectangle {
    id: pill

    required property bool active
    required property bool connecting
    required property string message

    property color fillColor: connecting ? Theme.qsRowBgHover : Theme.qsRowBg
    property color strokeColor: connecting ? Theme.qsEdge : Theme.qsEdgeSoft
    property color labelColor: connecting ? Theme.textPrimary : Theme.red

    implicitWidth: statusRow.implicitWidth + 24
    implicitHeight: 28
    radius: 14
    color: fillColor
    border.width: 1
    border.color: strokeColor
    opacity: active ? 1 : 0
    clip: true

    Behavior on opacity {
        NumberAnimation { duration: 90 }
    }

    Behavior on fillColor {
        ColorAnimation { duration: 110 }
    }

    Behavior on strokeColor {
        ColorAnimation { duration: 110 }
    }

    RowLayout {
        id: statusRow
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 8

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: pill.connecting ? Theme.accent : Theme.red
            opacity: 0.95

            SequentialAnimation on opacity {
                running: pill.active && pill.connecting
                loops: Animation.Infinite
                NumberAnimation { from: 0.95; to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.35; to: 0.95; duration: 650; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            Layout.fillWidth: true
            text: pill.active ? pill.message : " "
            font.family: Theme.fontUi
            font.pixelSize: 11
            font.weight: Font.Medium
            color: pill.labelColor
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
