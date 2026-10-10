import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var ttsService
    property bool active: true
    property bool osdVisible: false
    readonly property bool generating: ttsService.status === "generating"
    readonly property bool paused: ttsService.status === "paused"
    readonly property bool replayReady: ttsService.replayReady
    readonly property bool error: ttsService.status === "error"
    // A provider rejection (for example, Edge returning HTTP 403) is not the
    // same thing as the local service being unavailable.
    readonly property string message: error ? "Text-to-speech error" : (generating ? "Preparing speech" : (paused ? "Paused" : "Reading"))

    screen: targetScreen
    visible: active && osdVisible
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-tts-osd"
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitWidth: 230
    // Include the bar offset, card, and a little breathing room.  This panel
    // sits below the bar like dictation, rather than at the volume OSD edge.
    implicitHeight: Theme.borderSize + Theme.barHeight + 12 + 60 + 12

    function showBriefly() {
        osdVisible = true;
        hideTimer.restart();
    }

    function syncVisibility() {
        if (ttsService.status === "idle" || replayReady) {
            osdVisible = false;
            hideTimer.stop();
        } else if (generating) {
            osdVisible = true;
            hideTimer.stop();
        } else {
            showBriefly();
        }
    }

    Connections {
        target: root.ttsService
        function onStatusChanged() {
            root.syncVisibility();
        }
        function onDetailChanged() {
            root.syncVisibility();
        }
    }

    Timer {
        id: hideTimer
        interval: root.error ? 4000 : 1600
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: Theme.borderSize + Theme.barHeight + 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: 230
        height: 60
        radius: 30
        color: Theme.osdSurfaceBg
        border.color: root.error ? Qt.rgba(1, 0.48, 0.39, 0.55) : Theme.osdSurfaceBorder
        border.width: 1
        opacity: root.osdVisible ? 1 : 0
        scale: root.osdVisible ? 1 : 0.96
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.75
            shadowVerticalOffset: 8
            blurMax: 32
        }

        Row {
            anchors.centerIn: parent
            spacing: 11
            Text {
                text: "󰔊"
                font.family: Theme.fontIcons
                font.pixelSize: 20
                color: root.error ? Theme.red : Theme.osdTextPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.message
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.osdTextSecondary
                anchors.verticalCenter: parent.verticalCenter
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
    }

    mask: Region {}
}
