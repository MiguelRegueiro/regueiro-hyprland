import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var batteryService
    property bool active: true
    readonly property bool hasBattery: batteryService && batteryService.hasBattery
    readonly property int percent: hasBattery ? batteryService.percent : -1
    readonly property bool discharging: hasBattery && !batteryService.charging && !batteryService.full
    readonly property bool warningVisible: active && discharging && percent <= Theme.batteryCriticalThreshold

    screen: targetScreen
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-battery-warning-osd"
    color: "transparent"
    anchors.bottom: true
    margins.bottom: 82
    implicitWidth: 430
    implicitHeight: 112

    Rectangle {
        id: warningRect

        anchors.centerIn: parent
        width: 390
        height: 72
        radius: 18
        color: Theme.popupBg
        border.color: Theme.red
        border.width: 2
        opacity: root.warningVisible ? 1 : 0
        scale: root.warningVisible ? 1 : 0.96
        transformOrigin: Item.Center
        layer.enabled: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 20
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: ""
                font.family: Theme.fontIcons
                font.pixelSize: 32 + Theme.fontSizeDelta
                color: Theme.red
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Battery critically low"
                    font.family: Theme.fontUi
                    font.pixelSize: 16 + Theme.fontSizeDelta
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }

                Text {
                    Layout.fillWidth: true
                    text: root.percent + "% remaining - Plug in your charger"
                    font.family: Theme.fontUi
                    font.pixelSize: 13 + Theme.fontSizeDelta
                    color: Theme.red
                }

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
            shadowColor: Qt.rgba(0, 0, 0, 0.65)
            shadowBlur: 0.8
            shadowVerticalOffset: 8
            shadowHorizontalOffset: 0
            blurMax: 32
        }

    }

    mask: Region {
    }

}
