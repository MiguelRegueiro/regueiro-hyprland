import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../components" as Components
import "../../theme/Theme.js" as Theme

Item {
    id: root

    property bool open: false
    property real reveal: 0
    required property real surfaceX
    required property real surfaceY
    required property var targetScreen
    readonly property color surfaceBg: Qt.rgba(0.115, 0.12, 0.135, 0.84)
    readonly property color outline: Theme.menuSurfaceOutline
    readonly property color rowBg: Qt.rgba(1, 1, 1, 0.065)
    readonly property color rowBgHover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color rowBorder: Qt.rgba(0.56, 0.58, 0.62, 0.22)
    readonly property color rowBorderHover: Qt.rgba(0.62, 0.64, 0.68, 0.35)
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
    visible: reveal > 0.001
    opacity: 1
    transform: Translate {
        y: -(1 - root.reveal) * 18
    }
    state: open ? "open" : ""
    transitions: [
        Transition {
            from: ""
            to: "open"

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedDecel
                duration: Theme.panelOpenDuration
            }
        },
        Transition {
            from: "open"
            to: ""

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedAccel
                duration: Theme.panelCloseDuration
            }
        }
    ]

    PanelWindow {
        id: popupSurface

        screen: root.targetScreen
        visible: root.visible
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-power-actions"
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        mask: Region {
            x: Math.round(root.surfaceX)
            y: Math.round(root.surfaceY)
            width: Math.round(root.width)
            height: Math.round(root.height)
        }

        Rectangle {
            id: popup

            x: Math.round(root.surfaceX)
            y: Math.round(root.surfaceY)
            width: root.width
            height: root.height
            radius: 24
            color: root.surfaceBg
            border.color: root.outline
            border.width: 1
            clip: true
            layer.enabled: true

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.46)
                shadowBlur: 1.04
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
                blurMax: 48
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

    states: State {
        name: "open"

        PropertyChanges {
            root.reveal: 1
        }
    }
}
