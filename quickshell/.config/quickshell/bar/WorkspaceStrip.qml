import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme/Theme.js" as Theme

Row {
    id: wsRow

    property string screenName: ""
    property int barHeight: 34
    property bool externalConnected: false
    readonly property var pinnedWorkspaceIds: externalConnected && screenName === Theme.primaryScreen ? [10] : [1, 2, 3, 4, 5]

    function dispatchWorkspace(workspace) {
        if (typeof workspace === "number")
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace + " })");
        else
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + workspace + "\" })");
    }

    function belongsToScreen(workspace) {
        const id = Number(workspace.id);

        if (pinnedWorkspaceIds.indexOf(id) !== -1)
            return true;

        return workspace.monitor !== null && workspace.monitor !== undefined && workspace.monitor.name === screenName;
    }

    spacing: 0
    rightPadding: 4

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: wsBtn

            required property var modelData
            readonly property bool hovered: hover.hovered

            visible: wsRow.belongsToScreen(modelData)
            height: barHeight
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

            HoverHandler {
                id: hover

                blocking: false
                cursorShape: Qt.ArrowCursor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: wsRow.dispatchWorkspace(wsBtn.modelData.id)
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0)
                        wsRow.dispatchWorkspace("e-1");
                    else
                        wsRow.dispatchWorkspace("e+1");
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
