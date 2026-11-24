import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Item {
    id: root

    property bool open: false
    required property real surfaceX
    required property real surfaceY
    required property var targetScreen
    readonly property color rowBg: QS.cardBg
    readonly property color rowBgHover: QS.cardBgHover
    readonly property color rowBorder: QS.cardBorder
    readonly property color rowBorderHover: QS.cardBorderHover
    readonly property var actions: [
        {
            "actionId": "suspend",
            "label": "Suspend",
            "icon": "\udb81\udd94",
            "iconOffsetX": 0,
            "iconPixelSize": 15
        },
        {
            "actionId": "reboot",
            "label": "Reboot",
            "icon": "\uf2f9",
            "iconOffsetX": 1,
            "iconPixelSize": 15
        },
        {
            "actionId": "shutdown",
            "label": "Shut Down",
            "icon": "\uf011",
            "iconOffsetX": 0,
            "iconPixelSize": 15
        }
    ]

    signal actionTriggered
    signal actionRequested(string actionId)

    function actionChipFill(actionId, active, hovered) {
        return active ? rowBgHover : (hovered ? rowBgHover : rowBg);
    }

    function actionChipBorder(actionId, active, hovered) {
        return active ? rowBorderHover : (hovered ? rowBorderHover : rowBorder);
    }

    function actionIconColor(actionId) {
        return Theme.textPrimary;
    }

    function runAction(actionId) {
        root.actionRequested(actionId);
        root.actionTriggered();
    }

    implicitWidth: 248
    implicitHeight: popupColumn.implicitHeight + 20
    width: implicitWidth
    height: implicitHeight
    QuickSettingsPopupSurface {
        id: popupSurface

        surfaceX: root.surfaceX
        surfaceY: root.surfaceY
        targetScreen: root.targetScreen
        surfaceNamespace: "qs-power-actions"
        open: root.open
        width: root.width
        height: root.height

        ColumnLayout {
                id: popupColumn

                spacing: 8

                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                    topMargin: 10
                    bottomMargin: 10
                }

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: actionRow

                        required property var modelData
                        readonly property bool active: false

                        Layout.fillWidth: true
                        height: 50
                        radius: height / 2
                        color: actionRow.active ? root.rowBgHover : (rowHover.hovered ? root.rowBgHover : root.rowBg)
                        border.width: 1
                        border.color: actionRow.active ? root.rowBorderHover : (rowHover.hovered ? root.rowBorderHover : root.rowBorder)

                        RowLayout {
                            spacing: 10

                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }

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
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.runAction(modelData.actionId)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.popupButtonColorDuration
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.popupButtonColorDuration
                            }
                        }
                    }
                }
        }
    }
}
