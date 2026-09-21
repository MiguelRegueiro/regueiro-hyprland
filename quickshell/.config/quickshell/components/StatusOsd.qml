import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "." as Components
import "../theme/Theme.js" as Theme

Rectangle {
        id: root

    required property var audioService
    required property var brightnessService
    property string currentMode: "volume"
    property bool osdVisible: false
    property string outputLabel: ""
    readonly property bool showOutputLabel: outputLabel.length > 0


        width: root.showOutputLabel ? 320 : 280
        height: 60
        radius: 30
        color: Theme.osdSurfaceBg
        border.color: Theme.osdSurfaceBorder
        border.width: 1
        opacity: root.osdVisible ? 1 : 0
        scale: root.osdVisible ? 1 : 0.96
        transformOrigin: Item.Center
        layer.enabled: true

        RowLayout {
            id: controlsRow

            spacing: 3
            x: 16
            y: root.showOutputLabel ? 27 : Math.round((parent.height - height) / 2)
            width: parent.width - 32
            height: 20

            Item {
                implicitWidth: 30
                implicitHeight: 20
                Layout.alignment: Qt.AlignVCenter

                Components.VolumeIcon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.currentMode === "volume"
                    muted: audioService.muted
                    volumePercent: audioService.volumePercent
                    iconColor: Theme.osdTextPrimary
                    height: 20
                }

                Components.BrightnessIcon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.currentMode === "brightness"
                    iconColor: Theme.osdTextPrimary
                    height: 20
                }

            }

            Rectangle {
                property real fillFraction: root.currentMode === "brightness" ? Math.min(1, brightnessService.percent / 100) : (audioService.muted ? 0 : Math.min(1, audioService.volumePercent / 100))

                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.hoverBg

                Rectangle {
                    width: parent.width * parent.fillFraction
                    height: parent.height
                    radius: parent.radius
                    color: Theme.osdTextPrimary
                }

            }

            Text {
                text: root.currentMode === "brightness" ? brightnessService.percent + "%" : (audioService.muted ? "Muted" : audioService.volumePercent + "%")
                font.family: Theme.fontUi
                font.pixelSize: 13
                color: Theme.osdTextSecondary
                Layout.leftMargin: 6
                horizontalAlignment: Text.AlignRight
            }

        }

        Text {
            visible: root.showOutputLabel
            x: 16
            y: 8
            width: parent.width - 32
            height: 18
            text: root.outputLabel
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.osdTextSecondary
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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
