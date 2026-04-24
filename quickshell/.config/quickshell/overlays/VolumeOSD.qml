import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
    implicitHeight: 56

    mask: Region {}

    property bool osdVisible: false

    Component.onCompleted: {
        _lastVolume = audioService.volumePercent
        _lastMuted = audioService.muted
    }

    property int _lastVolume: -1
    property bool _lastMuted: false

    Connections {
        target: audioService
        function onVolumePercentChanged() {
            if (root._lastVolume !== audioService.volumePercent) {
                root._lastVolume = audioService.volumePercent
                root.show()
            }
        }
        function onMutedChanged() {
            root._lastMuted = audioService.muted
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
        anchors.centerIn: parent
        width: 280
        height: 56
        radius: Theme.barCornerRadius
        color: Theme.barBg
        border.color: Theme.barBorder
        border.width: 1

        opacity: root.osdVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        layer.enabled: true

        RowLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            Text {
                text: audioService.volumeIcon
                font.family: Theme.fontIcons
                font.pixelSize: 20
                color: Theme.textPrimary
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Theme.hoverBg

                Rectangle {
                    width: parent.width * (audioService.muted ? 0 : Math.min(1, audioService.volumePercent / 100))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation { duration: 100 }
                    }
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
