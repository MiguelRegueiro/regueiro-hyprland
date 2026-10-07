import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme/Theme.js" as Theme

Row {
    id: wsRow

    property var targetScreen: null
    property string screenName: ""
    property int barHeight: 34
    property bool externalConnected: false
    readonly property var hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    readonly property int activeWorkspaceId: hyprMonitor && hyprMonitor.activeWorkspace ? Number(hyprMonitor.activeWorkspace.id) : -1
    readonly property var pinnedWorkspaceIds: externalConnected && screenName === Theme.primaryScreen ? [10] : [1, 2, 3, 4, 5]

    function dispatchWorkspace(workspace) {
        if (typeof workspace === "number")
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace + " })");
        else
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + workspace + "\" })");
    }

    function belongsToScreen(workspace) {
        return workspace.monitor !== null && workspace.monitor !== undefined && workspace.monitor.name === screenName;
    }

    function workspaceForId(id) {
        const workspaces = Hyprland.workspaces.values;

        for (let index = 0; index < workspaces.length; index++) {
            if (Number(workspaces[index].id) === id)
                return workspaces[index];
        }

        return null;
    }

    function workspaceLabel(workspace) {
        const name = workspace !== null && typeof workspace === "object" ? workspace.name : workspace;
        const number = Number(name);
        const numerals = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"];

        if (!Number.isInteger(number) || number < 1 || number > 99)
            return name;
        if (number < 10)
            return numerals[number];
        if (number === 10)
            return "十";

        const tens = Math.floor(number / 10);
        const ones = number % 10;
        return `${tens === 1 ? "" : numerals[tens]}十${ones === 0 ? "" : numerals[ones]}`;
    }

    spacing: 0
    // Match the 10px inner edge of the CPU and RAM status controls so the
    // workspace-to-CPU gap reads the same as the CPU-to-RAM gap.
    rightPadding: 10

    component WorkspaceButton: Rectangle {
        id: wsBtn

        required property int workspaceId
        property var workspace: null
        readonly property bool hovered: hover.hovered
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool active: workspaceId === wsRow.activeWorkspaceId

        height: barHeight
        width: visible ? Math.max(wsLabel.implicitWidth + 14, 28) : 0
        radius: Theme.radiusSmall
        color: {
            if (active)
                return hovered ? Theme.workspaceActiveHoverBg : Theme.workspaceActiveBg;

            if (hovered)
                return Theme.hoverBg;

            return "transparent";
        }
        border.width: active ? 1 : 0
        border.color: Theme.workspaceActiveBorder

        Text {
            id: wsLabel

            anchors.centerIn: parent
            text: wsRow.workspaceLabel(workspace !== null ? workspace : workspaceId)
            color: active || wsBtn.occupied ? "#ffffff" : Qt.rgba(0.965, 0.961, 0.957, 0.5)
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        HoverHandler {
            id: hover

            blocking: false
            cursorShape: Qt.ArrowCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: wsRow.dispatchWorkspace(wsBtn.workspaceId)
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0)
                    wsRow.dispatchWorkspace("e-1");
                else
                    wsRow.dispatchWorkspace("e+1");
            }
        }

        Behavior on color {
            ColorAnimation {
                // Drop the old workspace immediately; only the new one gets
                // a short emphasis transition.
                duration: wsBtn.active ? 75 : 0
                easing.type: Easing.OutCubic
            }
        }
    }

    // The primary workspaces are part of the UI contract, not merely a view of
    // Hyprland's currently-created workspace objects. In a standalone session,
    // Hyprland only creates workspace 1 until another workspace is selected.
    Repeater {
        model: wsRow.pinnedWorkspaceIds

        delegate: WorkspaceButton {
            required property var modelData

            workspaceId: Number(modelData)
            workspace: wsRow.workspaceForId(workspaceId)
        }
    }

    Repeater {
        model: Hyprland.workspaces

        delegate: WorkspaceButton {
            required property var modelData

            workspaceId: Number(modelData.id)
            workspace: modelData
            visible: wsRow.pinnedWorkspaceIds.indexOf(workspaceId) === -1 && wsRow.belongsToScreen(modelData)
        }
    }

}
