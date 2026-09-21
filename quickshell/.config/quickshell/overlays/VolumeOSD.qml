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
    property bool osdVisible: false
    property string currentMode: "volume"
    property int _lastVolume: -1
    readonly property string outputLabel: currentMode === "volume" ? audioService.currentSinkOsdLabel : ""
    readonly property bool showOutputLabel: outputLabel.length > 0

    function showMode(mode) {
        currentMode = mode;
        osdVisible = true;
        hideTimer.restart();
    }

    screen: targetScreen
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-volume-osd"
    color: "transparent"
    anchors.bottom: true
    margins.bottom: Theme.borderSize - 4
    implicitWidth: root.showOutputLabel ? 360 : 320
    implicitHeight: 100
    Component.onCompleted: {
        _lastVolume = audioService.volumePercent;
    }

    Connections {
        function onVolumeLimitReached() {
            root._lastVolume = root.audioService.volumePercent;
            root.showMode("volume");
        }

        function onVolumePercentChanged() {
            if (root._lastVolume !== audioService.volumePercent) {
                root._lastVolume = audioService.volumePercent;
                root.showMode("volume");
            }
        }

        function onMutedChanged() {
            root.showMode("volume");
        }

        target: audioService
    }

    Connections {
        function onAdjusted() {
            root.showMode("brightness");
        }

        target: brightnessService
    }

    Timer {
        id: hideTimer

        interval: Theme.osdTimeout
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Components.StatusOsd {
        anchors.centerIn: parent
        audioService: root.audioService
        brightnessService: root.brightnessService
        currentMode: root.currentMode
        osdVisible: root.osdVisible
        outputLabel: root.outputLabel
    }

    mask: Region {
    }

}
