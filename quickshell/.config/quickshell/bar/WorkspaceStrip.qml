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

    function workspaceLabel(workspace) {
        const number = Number(workspace.name);
        const numerals = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"];

        if (!Number.isInteger(number) || number < 1 || number > 99)
            return workspace.name;
        if (number < 10)
            return numerals[number];
        if (number === 10)
            return "十";

        const tens = Math.floor(number / 10);
        const ones = number % 10;
        return `${tens === 1 ? "" : numerals[tens]}十${ones === 0 ? "" : numerals[ones]}`;
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
                    return hovered ? Theme.workspaceActiveHoverBg : Theme.workspaceActiveBg;

                if (hovered)
                    return Theme.hoverBg;

                return "transparent";
            }
            border.width: modelData.active ? 1 : 0
            border.color: Theme.workspaceActiveBorder

            Text {
                id: wsLabel

                anchors.centerIn: parent
                text: wsRow.workspaceLabel(modelData)
                color: modelData.active ? "#ffffff" : Theme.textDim
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
