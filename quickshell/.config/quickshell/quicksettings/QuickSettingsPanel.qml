import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Io
import "pages" as Pages
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    required property var notificationStore
    required property var audioService
    required property var brightnessService

    property bool open: false
    property real topOffset: 0
    property bool hovered: panelHover.hovered || boundsHover.hovered
    property string powerMode: ""
    property bool wifiPageOpen: false
    property bool bluetoothPageOpen: false
    property bool audioOutputPopupOpen: false
    property real reveal: 0

    onOpenChanged: {
        if (!open) {
            wifiPageOpen = false
            bluetoothPageOpen = false
            audioOutputPopupOpen = false
            dashboard.powerMenuOpen = false
        }
    }

    readonly property alias inputRegion: inputRegion
    readonly property bool inputActive: reveal > 0.03
    readonly property real surfaceTopLeftRadius: Theme.qsSurfaceTopLeftRadius
    readonly property real surfaceTopRightRadius: Theme.qsSurfaceTopRightRadius
    readonly property real surfaceBottomLeftRadius: Theme.qsSurfaceBottomLeftRadius
    readonly property real surfaceBottomRightRadius: Theme.qsSurfaceBottomRightRadius
    readonly property real attachTop: Theme.qsAttachTop
    readonly property real attachRight: Theme.qsAttachRight
    readonly property real clipWidthProgress: 0.84 + root.reveal * 0.16
    readonly property real clipHeightProgress: 0.78 + root.reveal * 0.22
    readonly property real frameScale: 0.988 + root.reveal * 0.012
    readonly property real frameOpacity: 0.72 + root.reveal * 0.28
    readonly property bool submenuOpen: root.wifiPageOpen || root.bluetoothPageOpen
    readonly property real audioOutputPopupOverflow: root.audioOutputPopupOpen ? dashboard.audioOutputPopupOverflow : 0
    readonly property real revealProgress: reveal
    readonly property real animTopLeftRadius: root.surfaceTopLeftRadius * root.reveal
    readonly property real animTopRightRadius: root.surfaceTopRightRadius * root.reveal
    readonly property real bodyWidth: Theme.qsWidth + Theme.qsAttachRight
    readonly property real bodyHeight: contentLayout.implicitHeight + Theme.qsContentPadding * 2 + root.attachTop
    readonly property real fuseLeftOverhang: Theme.barCornerRadius
    readonly property real fuseBottomOverhang: Theme.barCornerRadius
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real mergedTopLeftRadius: 0.001
    readonly property real mergedBottomRightRadius: Theme.borderSize
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real bottomFuseJoinX: root.bodyWidth - Theme.borderSize - Theme.barCornerRadius
    readonly property real clipSurfaceWidth: root.bodyWidth * root.clipWidthProgress
        + root.fuseLeftOverhang * root.reveal
    readonly property real clipSurfaceHeight: root.bodyHeight * root.clipHeightProgress
        + root.fuseBottomOverhang * root.reveal

    function applyPowerMode(nextMode) {
        powerMode = nextMode
        setPowerProfile.command = ["powerprofilesctl", "set", nextMode]
        setPowerProfile.running = true
    }

    state: open ? "open" : ""
    implicitWidth: root.bodyWidth + root.fuseLeftOverhang
    implicitHeight: root.bodyHeight + root.fuseBottomOverhang + root.audioOutputPopupOverflow
    width: implicitWidth
    height: implicitHeight
    visible: reveal > 0.001
    z: 30

    transitions: [
        Transition {
            from: ""
            to: "open"
            NumberAnimation {
                target: root
                property: "reveal"
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            }
        },
        Transition {
            from: "open"
            to: ""
            NumberAnimation {
                target: root
                property: "reveal"
                duration: 145
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.4, 0, 0.85, 0.3, 1.0, 1.0]
            }
        }
    ]

    anchors {
        top: parent.top
        right: parent.right
        topMargin: root.topOffset
    }

    Item {
        id: inputRegion
        x: motionFrame.x
        y: motionFrame.y
        width: root.inputActive ? root.width : 0
        height: root.inputActive ? root.height : 0
        visible: false
    }

    Item {
        id: motionFrame
        width: root.width
        height: root.height
        y: (1 - root.reveal) * -4
        scale: root.frameScale
        transformOrigin: Item.TopRight
        opacity: root.frameOpacity
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.70 * root.reveal)
            shadowBlur: 0.88
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            blurMax: 48
        }

        HoverHandler {
            id: boundsHover
            blocking: false
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            width: Math.max(1, root.clipSurfaceWidth)
            height: Math.max(1, root.clipSurfaceHeight)
            clip: !root.audioOutputPopupOpen

            HoverHandler {
                id: panelHover
                blocking: false
            }

            Item {
                id: frame
                anchors.top: parent.top
                anchors.right: parent.right
                width: root.bodyWidth
                height: root.bodyHeight

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1
                        PathMove { x: 0; y: root.fuseTopInset }
                        PathLine { x: -root.fuseLeftOverhang; y: root.fuseTopInset }
                        PathArc {
                            x: 0
                            y: root.topFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: 0; y: root.fuseTopInset }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1
                        PathMove { x: frame.width - Theme.borderSize; y: frame.height }
                        PathLine { x: root.bottomFuseJoinX; y: frame.height }
                        PathArc {
                            x: frame.width - Theme.borderSize
                            y: frame.height + Theme.barCornerRadius
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: frame.width - Theme.borderSize; y: frame.height }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove { x: root.mergedTopLeftRadius; y: 0 }
                        PathLine { x: frame.width - root.animTopRightRadius; y: 0 }
                        PathArc {
                            x: frame.width
                            y: root.animTopRightRadius
                            radiusX: root.animTopRightRadius
                            radiusY: root.animTopRightRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: frame.width; y: frame.height - root.mergedBottomRightRadius }
                        PathArc {
                            x: frame.width - root.mergedBottomRightRadius
                            y: frame.height
                            radiusX: root.mergedBottomRightRadius
                            radiusY: root.mergedBottomRightRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: root.surfaceBottomLeftRadius; y: frame.height }
                        PathArc {
                            relativeX: -root.surfaceBottomLeftRadius
                            relativeY: -root.surfaceBottomLeftRadius
                            radiusX: root.surfaceBottomLeftRadius
                            radiusY: root.surfaceBottomLeftRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: 0; y: root.mergedTopLeftRadius }
                        PathArc {
                            x: root.mergedTopLeftRadius
                            y: 0
                            radiusX: root.mergedTopLeftRadius
                            radiusY: root.mergedTopLeftRadius
                            direction: PathArc.Clockwise
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.qsEdge
                        strokeWidth: 1.1
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove { x: root.bottomFuseJoinX; y: frame.height }
                        PathLine { x: root.surfaceBottomLeftRadius; y: frame.height }
                        PathArc {
                            relativeX: -root.surfaceBottomLeftRadius
                            relativeY: -root.surfaceBottomLeftRadius
                            radiusX: root.surfaceBottomLeftRadius
                            radiusY: root.surfaceBottomLeftRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: 0; y: root.topFuseJoinY }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1
                        PathMove { x: frame.width; y: 0 }
                        PathLine { x: frame.width - root.animTopRightRadius; y: 0 }
                        PathArc {
                            x: frame.width
                            y: root.animTopRightRadius
                            radiusX: root.animTopRightRadius
                            radiusY: root.animTopRightRadius
                            direction: PathArc.Counterclockwise
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.qsEdge
                        strokeWidth: 1.1
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin
                        PathMove { x: -root.fuseLeftOverhang; y: root.fuseTopInset }
                        PathArc {
                            x: 0
                            y: root.topFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.qsEdge
                        strokeWidth: 1.1
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin
                        PathMove { x: root.bottomFuseJoinX; y: frame.height }
                        PathArc {
                            x: frame.width - Theme.borderSize
                            y: frame.height + Theme.barCornerRadius
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                    }
                }

                ColumnLayout {
                    id: contentLayout
                    spacing: 0
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: root.attachTop
                        leftMargin: root.attachRight + Theme.qsContentPadding
                        rightMargin: root.attachRight + Theme.qsContentPadding
                    }

                    Item {
                        height: 0
                    }

                    Item {
                        id: stackContainer
                        Layout.fillWidth: true
                        clip: !root.audioOutputPopupOpen
                        implicitHeight: {
                            if (root.wifiPageOpen)
                                return wifiPageView.implicitHeight
                            if (root.bluetoothPageOpen)
                                return bluetoothPageView.implicitHeight
                            return dashboard.implicitHeight
                        }

                        QuickSettingsDashboard {
                            id: dashboard
                            width: parent.width
                            viewportHeight: root.parent ? root.parent.height : root.height
                            audioOutputPopupOpen: root.audioOutputPopupOpen
                            onAudioOutputPopupRequest: open => root.audioOutputPopupOpen = open
                            x: root.submenuOpen ? -parent.width - 15 : 0
                            opacity: root.submenuOpen ? 0 : 1
                            notificationStore: root.notificationStore
                            audioService: root.audioService
                            brightnessService: root.brightnessService
                            wifiPage: wifiPageView
                            bluetoothPage: bluetoothPageView
                            powerMode: root.powerMode
                            onWifiPageRequested: {
                                root.audioOutputPopupOpen = false
                                root.wifiPageOpen = true
                                root.bluetoothPageOpen = false
                            }
                            onBluetoothPageRequested: {
                                root.audioOutputPopupOpen = false
                                root.bluetoothPageOpen = true
                                root.wifiPageOpen = false
                            }
                            onPowerModeChangeRequested: mode => root.applyPowerMode(mode)

                            Behavior on x {
                                NumberAnimation {
                                    duration: 130
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 110
                                }
                            }
                        }

                        Pages.WifiPage {
                            id: wifiPageView
                            width: parent.width
                            x: root.wifiPageOpen ? 0 : (root.bluetoothPageOpen ? -parent.width - 20 : parent.width + 20)
                            opacity: root.wifiPageOpen ? 1 : 0
                            menuOpen: root.wifiPageOpen
                            onBackClicked: root.wifiPageOpen = false

                            Behavior on x {
                                NumberAnimation {
                                    duration: 130
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 110
                                }
                            }
                        }

                        Pages.BluetoothPage {
                            id: bluetoothPageView
                            width: parent.width
                            x: root.bluetoothPageOpen ? 0 : parent.width + 20
                            opacity: root.bluetoothPageOpen ? 1 : 0
                            menuOpen: root.bluetoothPageOpen
                            onBackClicked: root.bluetoothPageOpen = false

                            Behavior on x {
                                NumberAnimation {
                                    duration: 130
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 110
                                }
                            }
                        }

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutExpo
                            }
                        }
                    }

                    Item {
                        height: 0
                    }
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: powerProfilePoll.running = true
    }

    Process {
        id: powerProfilePoll
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            id: powerProfileOut
            onStreamFinished: {
                const nextMode = powerProfileOut.text.trim()
                if (nextMode === "power-saver" || nextMode === "balanced" || nextMode === "performance")
                    root.powerMode = nextMode
            }
        }
    }

    Process {
        id: setPowerProfile
        command: ["echo"]
    }

    states: State {
        name: "open"
        PropertyChanges { root.reveal: 1 }
    }
}
