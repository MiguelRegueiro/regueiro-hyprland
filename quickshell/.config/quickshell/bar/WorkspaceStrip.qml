import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme/Theme.js" as Theme

Row {
    id: wsRow

    property string screenName: ""
    property int barHeight: 34

    spacing: 0
    leftPadding: 4
    rightPadding: 4

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: wsBtn

            required property var modelData
            readonly property bool hovered: hover.hovered

            // Only show workspaces belonging to this bar's screen
            visible: modelData.monitor !== null && modelData.monitor.name === screenName
            height: barHeight - 8
            width: visible ? Math.max(wsLabel.implicitWidth + 14, 28) : 0
            radius: Theme.radiusSmall
            color: {
                if (modelData.active)
                    return Theme.activeBg;

                if (hovered)
                    return Theme.hoverBg;

                return "transparent";
            }

            Text {
                id: wsLabel

                anchors.centerIn: parent
                text: modelData.name
                color: modelData.active ? Theme.textPrimary : Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: modelData.active ? Font.Bold : Font.Normal
            }

            // Urgent indicator — small dot at bottom
            Rectangle {
                visible: modelData.urgent
                width: 4
                height: 4
                radius: 2
                color: Theme.red

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 2
                }

            }

            HoverHandler {
                id: hover

                blocking: false
                cursorShape: Qt.ArrowCursor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + wsBtn.modelData.id)
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0)
                        Hyprland.dispatch("workspace e-1");
                    else
                        Hyprland.dispatch("workspace e+1");
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverAnimDuration
                }

            }

        }

    }

}
