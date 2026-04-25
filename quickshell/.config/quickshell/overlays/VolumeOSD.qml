import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var audioService

    screen: targetScreen
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-volume-osd"
    color: "transparent"

    anchors.bottom: true
    margins.bottom: Theme.borderSize + 16

    implicitWidth: 280
    implicitHeight: 60

    mask: Region {}

    property bool osdVisible: false
    property int _lastVolume: -1

    Component.onCompleted: {
        _lastVolume = audioService.volumePercent
    }

    Connections {
        target: audioService
        function onVolumePercentChanged() {
            if (root._lastVolume !== audioService.volumePercent) {
                root._lastVolume = audioService.volumePercent
                root.show()
            }
        }
        function onMutedChanged() {
            root.show()
        }
    }

    function show() {
        osdVisible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Rectangle {
        id: osdRect
        anchors.centerIn: parent
        width: 280
        height: 60
        radius: Theme.barCornerRadius
        color: Theme.barBg
        border.color: Theme.barBorder
        border.width: 1

        opacity: root.osdVisible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: osdRect.opacity >= 1.0 ? 220 : 0
                easing.type: Easing.OutQuad
            }
        }

        layer.enabled: true

        RowLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            Components.VolumeIcon {
                muted: audioService.muted
                volumePercent: audioService.volumePercent
                iconColor: Theme.textPrimary
                height: 20
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 2
                color: Theme.hoverBg

                property real fillFraction: audioService.muted ? 0 : Math.min(1, audioService.volumePercent / 100)

                Rectangle {
                    width: parent.width * parent.fillFraction
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            Text {
                text: audioService.muted ? "Muted" : audioService.volumePercent + "%"
                font.family: Theme.fontUi
                font.pixelSize: 13
                color: Theme.textDim
                Layout.minimumWidth: 42
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
