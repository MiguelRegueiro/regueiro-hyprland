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
    required property var audioService
    required property var brightnessService

    screen: targetScreen
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-volume-osd"
    color: "transparent"

    anchors.bottom: true
    margins.bottom: Theme.borderSize - 4

    implicitWidth: 320
    implicitHeight: 100

    mask: Region {}

    property bool osdVisible: false
    property string currentMode: "volume"
    property int _lastVolume: -1

    Component.onCompleted: {
        _lastVolume = audioService.volumePercent
    }

    Connections {
        target: audioService
        function onVolumePercentChanged() {
            if (root._lastVolume !== audioService.volumePercent) {
                root._lastVolume = audioService.volumePercent
                root.showMode("volume")
            }
        }
        function onMutedChanged() {
            root.showMode("volume")
        }
    }

    Connections {
        target: brightnessService
        function onAdjusted() {
            root.showMode("brightness")
        }
    }

    function showMode(mode) {
        currentMode = mode
        osdVisible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: Theme.osdTimeout
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Rectangle {
        id: osdRect
        anchors.centerIn: parent
        width: 280
        height: 60
        radius: 30
        color: Theme.popupBg
        border.color: Theme.barBorder
        border.width: 1

        opacity: root.osdVisible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: osdRect.opacity >= 1.0 ? 110 : 0
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

        RowLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 3

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
                    iconColor: Theme.textPrimary
                    height: 20
                }

                Components.BrightnessIcon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.currentMode === "brightness"
                    iconColor: Theme.textPrimary
                    height: 20
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Theme.hoverBg

                property real fillFraction: root.currentMode === "brightness"
                    ? Math.min(1, brightnessService.percent / 100)
                    : (audioService.muted ? 0 : Math.min(1, audioService.volumePercent / 100))

                Rectangle {
                    width: parent.width * parent.fillFraction
                    height: parent.height
                    radius: parent.radius
                    color: Theme.textPrimary
                }
            }

            Text {
                text: root.currentMode === "brightness"
                    ? brightnessService.percent + "%"
                    : (audioService.muted ? "Muted" : audioService.volumePercent + "%")
                font.family: Theme.fontUi
                font.pixelSize: 13
                color: Theme.textDim
                Layout.leftMargin: 6
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
