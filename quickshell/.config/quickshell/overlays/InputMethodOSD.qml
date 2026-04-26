import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var inputService
    property bool active: true

    screen: targetScreen
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-im-osd"
    color: "transparent"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    mask: Region {}

    property bool osdVisible: false

    readonly property int itemW: 130
    readonly property int itemH: 96
    readonly property int itemGap: 8
    readonly property int pad: 14
    readonly property int methodCount: root.inputService.methods.length

    Connections {
        target: root.inputService
        function onImChanged(newIM) {
            root.osdVisible = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.osdTimeout
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Rectangle {
        id: osdCard
        anchors.centerIn: parent
        width: root.pad * 2 + (
            root.methodCount > 0
                ? root.itemW * root.methodCount + root.itemGap * (root.methodCount - 1)
                : root.itemW
        )
        height: root.pad * 2 + root.itemH
        radius: 18
        color: Theme.popupBg
        border.color: Theme.barBorder
        border.width: 1

        opacity: root.osdVisible && root.active ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: osdCard.opacity >= 1.0 ? 60 : 0
                easing.type: Easing.OutQuad
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.75
            shadowVerticalOffset: 8
            shadowHorizontalOffset: 0
            blurMax: 32
        }

        Rectangle {
            id: selector
            visible: root.methodCount > 0
            x: root.pad + root.inputService.activeIndex * (root.itemW + root.itemGap)
            y: root.pad
            width: root.itemW
            height: root.itemH
            radius: 10
            color: Theme.activeBg

            Behavior on x {
                NumberAnimation { duration: Theme.osdSelectorDuration; easing.type: Easing.OutCubic }
            }
        }

        Row {
            x: root.pad
            y: root.pad
            spacing: root.itemGap

            Repeater {
                model: root.inputService.methods
                delegate: Item {
                    required property var modelData
                    required property int index

                    width: root.itemW
                    height: root.itemH

                    readonly property bool isActive: root.inputService.activeIndex === index

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.family: Theme.fontUi
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            color: isActive ? Theme.textPrimary : Theme.textDim
                            Behavior on color { ColorAnimation { duration: Theme.osdTextColorDuration } }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: isActive ? Theme.textDim : Theme.textDisabled
                            Behavior on color { ColorAnimation { duration: Theme.osdTextColorDuration } }
                        }
                    }
                }
            }
        }
    }
}
