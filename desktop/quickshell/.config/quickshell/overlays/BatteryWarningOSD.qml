import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property bool warningVisible
    required property int displayedPercent
    property bool active: true
    property int stackIndex: 0
    readonly property bool shown: active && warningVisible
    property real cardTopMargin: Theme.borderSize + Theme.barHeight + 12 + stackIndex * (60 + Theme.topOsdStackGap)

    screen: targetScreen
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-battery-warning-osd"
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    // A critical warning is persistent, so place it with the other status
    // pills below the bar instead of leaving it detached at the bottom edge.
    implicitWidth: 242
    implicitHeight: cardTopMargin + 60 + 12

    Rectangle {
        id: warningRect

        anchors.top: parent.top
        anchors.topMargin: root.cardTopMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: 242
        height: 60
        radius: 30
        color: Theme.osdSurfaceBg
        border.color: Theme.osdSurfaceBorder
        border.width: 1
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transformOrigin: Item.Center
        layer.enabled: true

        Row {
            anchors.centerIn: parent
            spacing: 11

            Item {
                width: 44
                height: 22

                Components.BatteryIcon {
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    scale: 1.3
                    percent: root.displayedPercent
                    alert: true
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Battery critically low"
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.osdTextPrimary
            }

        }

        Behavior on anchors.topMargin {
            Components.Anim {
                curve: Components.Anim.DefaultSpatial
                duration: Theme.animDurDefaultSpatial
            }
        }
        Behavior on opacity {
            Components.Anim {
                curve: Components.Anim.DefaultEffects
                duration: Theme.animDurDefaultEffects
            }
        }
        Behavior on scale {
            Components.Anim {
                curve: Components.Anim.DefaultEffects
                duration: Theme.animDurDefaultEffects
            }
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.75
            shadowVerticalOffset: 8
            shadowHorizontalOffset: 0
            blurMax: 32
        }

    }

    mask: Region {
    }

}
