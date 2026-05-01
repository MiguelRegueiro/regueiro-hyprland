import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme/Theme.js" as Theme

Item {
    id: root

    readonly property var actions: [{
        "actionId": "suspend",
        "label": "Suspend",
        "icon": "\udb81\udd94",
        "iconOffsetX": 0,
        "iconPixelSize": 15
    }, {
        "actionId": "reboot",
        "label": "Reboot",
        "icon": "\uf2f9",
        "iconOffsetX": 1,
        "iconPixelSize": 15
    }, {
        "actionId": "shutdown",
        "label": "Shut Down",
        "icon": "\uf011",
        "iconOffsetX": 0,
        "iconPixelSize": 15
    }]

    signal actionTriggered()
    signal actionRequested(string actionId)

    function actionChipFill(actionId, active, hovered) {
        return active ? Qt.rgba(1, 1, 1, 0.12) : (hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg);
    }

    function actionChipBorder(actionId, active, hovered) {
        return active ? Qt.rgba(1, 1, 1, 0.12) : (hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder);
    }

    function actionIconColor(actionId) {
        if (actionId === "reboot")
            return Qt.rgba(0.96, 0.96, 0.97, 0.86);

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
                color: actionRow.active ? Qt.rgba(0.122, 0.122, 0.122, 0.98) : (rowHover.hovered ? Theme.qsCardBgHover : Theme.qsCardBg)
                border.width: 1
                border.color: actionRow.active ? Qt.rgba(1, 1, 1, 0.14) : (rowHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder)

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
