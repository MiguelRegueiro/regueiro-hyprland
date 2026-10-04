import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var dictationService
    property bool active: true
    // Finished text is delivered directly to the focused app and clipboard,
    // so the OSD is reserved for the active recording/transcription states.
    readonly property bool shown: active && dictationService.hasStatus && dictationService.status !== "ready"
    readonly property bool listening: dictationService.status === "listening"
    readonly property bool error: dictationService.status === "error"
    readonly property string title: error ? "Dictation unavailable" : (listening ? "Listening" : (dictationService.status === "transcribing" ? "Transcribing" : "Dictation"))
    readonly property string message: dictationService.text.length > 0 ? dictationService.text : dictationService.detail
    readonly property bool busy: listening || dictationService.status === "transcribing"
    readonly property string displayText: listening ? "Listening" : (dictationService.status === "transcribing" ? "Transcribing" : message)

    screen: targetScreen
    visible: shown
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-dictation-osd"
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    // Leave room for the pill below the bar so the layer surface never clips
    // its own content into the panel chrome.
    implicitHeight: Theme.borderSize + Theme.barHeight + 12 + card.height + 12

    Item {
        anchors.fill: parent

        Rectangle {
            id: card

            anchors.top: parent.top
            anchors.topMargin: Theme.borderSize + Theme.barHeight + 12
            anchors.horizontalCenter: parent.horizontalCenter
            // Keep the active state steady, but let finished text use only
            // the room it needs instead of leaving a huge empty pill.
            width: root.busy
                ? (root.listening ? 180 : 210)
                : Math.min(root.width - 24, Math.max(220, textMeasure.implicitWidth + 56))
            height: 60
            radius: 30
            // Use the exact same translucent surface as the volume OSD so
            // Hyprland's blur is visible behind this pill too.
            color: Theme.osdSurfaceBg
            border.color: root.error ? Qt.rgba(1, 0.48, 0.39, 0.55) : Theme.osdSurfaceBorder
            border.width: 1
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.97
            layer.enabled: true

            Row {
                id: content

                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    width: 10
                    height: 10
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.error ? Theme.red : (root.listening ? Theme.red : Theme.green)

                    SequentialAnimation on opacity {
                        running: root.listening
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.35; duration: 720 }
                        NumberAnimation { from: 0.35; to: 1; duration: 720 }
                    }
                }

                Text {
                    id: transcript

                    width: Math.min(textMeasure.implicitWidth, card.width - 54)
                    text: root.displayText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: root.busy ? Font.DemiBold : Font.Normal
                    color: Theme.osdTextSecondary
                }
            }

            // Measures result text without participating in the layout.
            Text {
                id: textMeasure

                visible: false
                text: root.displayText
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: root.busy ? Font.DemiBold : Font.Normal
            }

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.5)
                shadowBlur: 0.75
                shadowVerticalOffset: 8
                blurMax: 32
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
    }

    mask: Region {
    }
}
