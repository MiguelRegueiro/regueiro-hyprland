import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
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
    property string currentIM: ""
    property string _lastIM: ""

    readonly property var methods: [
        { id: "keyboard-es", label: "es", name: "Español" },
        { id: "mozc",        label: "あ", name: "日本語" }
    ]

    readonly property int itemW: 130
    readonly property int itemH: 96
    readonly property int itemGap: 8
    readonly property int pad: 14

    readonly property int activeIndex: {
        for (var i = 0; i < methods.length; i++)
            if (methods[i].id === currentIM) return i
        return 0
    }

    Process {
        id: imProc
        command: ["bash", "-c",
            "if ! fcitx5-remote --check >/dev/null 2>&1; then echo keyboard-es; " +
            "else fcitx5-remote -n 2>/dev/null || echo keyboard-es; fi"]
        stdout: StdioCollector {
            id: imOut
            onStreamFinished: {
                var s = imOut.text.trim()
                if (!s) return
                if (root._lastIM === "") {
                    root._lastIM = s
                    root.currentIM = s
                    return
                }
                if (s !== root._lastIM) {
                    root._lastIM = s
                    root.currentIM = s
                    root.osdVisible = true
                    hideTimer.restart()
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.osdVisible ? 150 : 250
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!imProc.running) imProc.running = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Rectangle {
        id: osdCard
        anchors.centerIn: parent
        width:  root.pad * 2 + root.itemW * root.methods.length + root.itemGap * (root.methods.length - 1)
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

        // Sliding highlight — single rect that glides under the items
        Rectangle {
            id: selector
            x: root.pad + root.activeIndex * (root.itemW + root.itemGap)
            y: root.pad
            width: root.itemW
            height: root.itemH
            radius: 10
            color: Theme.activeBg

            Behavior on x {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
        }

        // Items on top of the sliding highlight
        Row {
            x: root.pad
            y: root.pad
            spacing: root.itemGap

            Repeater {
                model: root.methods
                delegate: Item {
                    required property var modelData
                    required property int index

                    width: root.itemW
                    height: root.itemH

                    readonly property bool isActive: root.activeIndex === index

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
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: isActive ? Theme.textDim : Theme.textDisabled
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }
    }
}
