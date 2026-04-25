import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import "../../theme/Theme.js" as Theme

Item {
    id: root

    signal actionTriggered()

    implicitWidth: 248
    implicitHeight: popupColumn.implicitHeight + 20
    width: implicitWidth
    height: implicitHeight

    readonly property var actions: [
        {
            actionId: "suspend",
            label: "Suspend",
            icon: "\udb81\udd94",
            iconOffsetX: 0,
            iconPixelSize: 15
        },
        {
            actionId: "reboot",
            label: "Reboot",
            icon: "\uf2f9",
            iconOffsetX: 1,
            iconPixelSize: 15
        },
        {
            actionId: "shutdown",
            label: "Shut Down",
            icon: "\uf011",
            iconOffsetX: 0,
            iconPixelSize: 15
        }
    ]

    property string pendingAction: ""

    function actionChipFill(actionId, active, hovered) {
        return active
            ? Qt.rgba(1, 1, 1, 0.12)
            : (hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg)
    }

    function actionChipBorder(actionId, active, hovered) {
        return active
            ? Qt.rgba(1, 1, 1, 0.12)
            : (hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder)
    }

    function actionIconColor(actionId) {
        if (actionId === "reboot")
            return Qt.rgba(0.96, 0.96, 0.97, 0.86)
        return Theme.textPrimary
    }

    function runAction(actionId) {
        if (root.pendingAction !== "")
            return

        root.pendingAction = actionId
        root.actionTriggered()

        if (actionId === "suspend")
            suspendProc.running = true
        else if (actionId === "reboot")
            rebootProc.running = true
        else if (actionId === "shutdown")
            shutdownProc.running = true
        else
            root.pendingAction = ""
    }

    function clearPending(actionId) {
        if (root.pendingAction === actionId)
            root.pendingAction = ""
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.popupBg
        border.color: Qt.rgba(1, 1, 1, 0.11)
        border.width: 1
        radius: Theme.qsRadius + 5
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.48)
            shadowBlur: 1.08
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
            blurMax: 52
        }
    }

    ColumnLayout {
        id: popupColumn

        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
            topMargin: 10
            bottomMargin: 10
        }
        spacing: 8

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: actionRow

                required property var modelData

                Layout.fillWidth: true
                height: 50
                radius: height / 2
                color: actionRow.active
                    ? Qt.rgba(0.122, 0.122, 0.122, 0.98)
                    : (rowHover.hovered ? Theme.qsCardBgHover : Theme.qsCardBg)
                border.width: 1
                border.color: actionRow.active
                    ? Qt.rgba(1, 1, 1, 0.14)
                    : (rowHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder)

                readonly property bool active: root.pendingAction === modelData.actionId

                Behavior on color {
                    ColorAnimation { duration: 90 }
                }

                Behavior on border.color {
                    ColorAnimation { duration: 90 }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 15
                        color: root.actionChipFill(modelData.actionId, actionRow.active, rowHover.hovered)
                        border.width: 1
                        border.color: root.actionChipBorder(modelData.actionId, actionRow.active, rowHover.hovered)

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: modelData.iconOffsetX || 0
                            text: modelData.icon
                            font.family: Theme.fontIcons
                            font.pixelSize: modelData.iconPixelSize || 15
                            color: root.actionIconColor(modelData.actionId)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.preferredWidth: 8
                    }
                }

                HoverHandler {
                    id: rowHover
                    blocking: false
                    cursorShape: actionRow.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    enabled: !actionRow.active && root.pendingAction === ""
                    onTapped: root.runAction(modelData.actionId)
                }
            }
        }
    }

    Process {
        id: suspendProc
        command: [
            "sh", "-lc",
            "if ! pgrep -x hyprlock >/dev/null 2>&1; then " +
            "  hyprlock --config $HOME/.config/hypr/hyprlock.conf >/dev/null 2>&1 & " +
            "  sleep 1; " +
            "fi; " +
            "systemctl suspend"
        ]
        onRunningChanged: {
            if (!running)
                root.clearPending("suspend")
        }
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
        onRunningChanged: {
            if (!running)
                root.clearPending("reboot")
        }
    }

    Process {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
        onRunningChanged: {
            if (!running)
                root.clearPending("shutdown")
        }
    }
}
