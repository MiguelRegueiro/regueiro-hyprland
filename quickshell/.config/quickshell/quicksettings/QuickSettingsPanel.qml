import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Io
import "pages" as Pages
import "../services" as Services
import "../components" as Components
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    required property var notificationStore
    required property var audioService
    required property var batteryService
    required property var brightnessService
    required property var networkService
    property bool open: false
    property real topOffset: 0
    property bool hovered: panelHover.hovered || boundsHover.hovered
    property string powerMode: ""
    property bool wifiPageOpen: false
    property bool bluetoothPageOpen: false
    property bool audioOutputPopupOpen: false
    property real reveal: 0
    readonly property alias inputRegion: inputRegion
    readonly property bool inputActive: reveal > 0.03
    readonly property real surfaceTopLeftRadius: Theme.qsSurfaceTopLeftRadius
    readonly property real surfaceTopRightRadius: Theme.qsSurfaceTopRightRadius
    readonly property real surfaceBottomLeftRadius: Theme.qsSurfaceBottomLeftRadius
    readonly property real surfaceBottomRightRadius: Theme.qsSurfaceBottomRightRadius
    readonly property real attachTop: Theme.qsAttachTop
    readonly property real attachRight: Theme.qsAttachRight
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
    readonly property real clipSurfaceWidth: root.bodyWidth + root.fuseLeftOverhang
    readonly property real clipSurfaceHeight: root.bodyHeight + root.fuseBottomOverhang
    readonly property real surfaceOffsetY: -(1 - root.reveal) * root.clipSurfaceHeight
    readonly property string powerProfileHelper: Qt.resolvedUrl("../scripts/freebsd-power-profile.sh").toString().replace("file://", "")

    signal powerActionRequested(string actionId)

    function applyPowerMode(nextMode) {
        powerMode = nextMode;
        setPowerProfile.command = [root.powerProfileHelper, "set", nextMode];
        setPowerProfile.running = true;
    }

    onOpenChanged: {
        if (!open) {
            wifiPageOpen = false;
            bluetoothPageOpen = false;
            audioOutputPopupOpen = false;
            dashboard.powerMenuOpen = false;
        }
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

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedDecel
                duration: Theme.panelOpenSpatialDuration
            }

        },
        Transition {
            from: "open"
            to: ""

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedAccel
                duration: Theme.panelCloseDuration
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
        height: Math.max(1, root.height)
        y: 0
        layer.enabled: true

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
                    transform: Translate {
                        y: root.surfaceOffsetY
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove {
                            x: 0
                            y: root.fuseTopInset
                        }

                        PathLine {
                            x: -root.fuseLeftOverhang
                            y: root.fuseTopInset
                        }

                        PathArc {
                            x: 0
                            y: root.topFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: 0
                            y: root.fuseTopInset
                        }

                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove {
                            x: frame.width - Theme.borderSize
                            y: frame.height
                        }

                        PathLine {
                            x: root.bottomFuseJoinX
                            y: frame.height
                        }

                        PathArc {
                            x: frame.width - Theme.borderSize
                            y: frame.height + Theme.barCornerRadius
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width - Theme.borderSize
                            y: frame.height
                        }

                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove {
                            x: root.mergedTopLeftRadius
                            y: 0
                        }

                        PathLine {
                            x: frame.width - root.animTopRightRadius
                            y: 0
                        }

                        PathArc {
                            x: frame.width
                            y: root.animTopRightRadius
                            radiusX: root.animTopRightRadius
                            radiusY: root.animTopRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width
                            y: frame.height - root.mergedBottomRightRadius
                        }

                        PathArc {
                            x: frame.width - root.mergedBottomRightRadius
                            y: frame.height
                            radiusX: root.mergedBottomRightRadius
                            radiusY: root.mergedBottomRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: root.surfaceBottomLeftRadius
                            y: frame.height
                        }

                        PathArc {
                            relativeX: -root.surfaceBottomLeftRadius
                            relativeY: -root.surfaceBottomLeftRadius
                            radiusX: root.surfaceBottomLeftRadius
                            radiusY: root.surfaceBottomLeftRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: 0
                            y: root.mergedTopLeftRadius
                        }

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

                        PathMove {
                            x: root.bottomFuseJoinX
                            y: frame.height
                        }

                        PathLine {
                            x: root.surfaceBottomLeftRadius
                            y: frame.height
                        }

                        PathArc {
                            relativeX: -root.surfaceBottomLeftRadius
                            relativeY: -root.surfaceBottomLeftRadius
                            radiusX: root.surfaceBottomLeftRadius
                            radiusY: root.surfaceBottomLeftRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: 0
                            y: root.topFuseJoinY
                        }

                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove {
                            x: frame.width
                            y: 0
                        }

                        PathLine {
                            x: frame.width - root.animTopRightRadius
                            y: 0
                        }

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

                        PathMove {
                            x: -root.fuseLeftOverhang
                            y: root.fuseTopInset
                        }

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

                        PathMove {
                            x: root.bottomFuseJoinX
                            y: frame.height
                        }

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
                                return wifiPageView.implicitHeight;

                            if (root.bluetoothPageOpen)
                                return bluetoothPageView.implicitHeight;

                            return dashboard.implicitHeight;
                        }

                        QuickSettingsDashboard {
                            id: dashboard

                            width: parent.width
                            viewportHeight: root.parent ? root.parent.height : root.height
                            audioOutputPopupOpen: root.audioOutputPopupOpen
                            onAudioOutputPopupRequest: (open) => {
                                return root.audioOutputPopupOpen = open;
                            }
                            x: root.submenuOpen ? -parent.width - 15 : 0
                            opacity: root.submenuOpen ? 0 : 1
                            notificationStore: root.notificationStore
                            audioService: root.audioService
                            batteryService: root.batteryService
                            brightnessService: root.brightnessService
                            networkService: root.networkService
                            wifiPage: wifiPageView
                            bluetoothPage: bluetoothPageView
                            powerMode: root.powerMode
                            onWifiPageRequested: {
                                root.audioOutputPopupOpen = false;
                                root.wifiPageOpen = true;
                                root.bluetoothPageOpen = false;
                            }
                            onBluetoothPageRequested: {
                                root.audioOutputPopupOpen = false;
                                root.bluetoothPageOpen = true;
                                root.wifiPageOpen = false;
                            }
                            onPowerModeChangeRequested: (mode) => {
                                return root.applyPowerMode(mode);
                            }
                            onPowerActionRequested: (actionId) => {
                                return root.powerActionRequested(actionId);
                            }

                            Behavior on x {
                                Components.Anim {
                                    duration: Theme.qsPageSlideDuration
                                    curve: Components.Anim.DefaultSpatial
                                }

                            }

                            Behavior on opacity {
                                Components.Anim {
                                    duration: Theme.qsPageFadeDuration
                                    curve: Components.Anim.DefaultEffects
                                }

                            }

                        }

                        Pages.WifiPage {
                            id: wifiPageView

                            width: parent.width
                            x: root.wifiPageOpen ? 0 : (root.bluetoothPageOpen ? -parent.width - 20 : parent.width + 20)
                            opacity: root.wifiPageOpen ? 1 : 0
                            menuOpen: root.wifiPageOpen
                            wifiService: wifiService
                            onBackClicked: root.wifiPageOpen = false

                            Behavior on x {
                                Components.Anim {
                                    duration: Theme.qsPageSlideDuration
                                    curve: Components.Anim.DefaultSpatial
                                }

                            }

                            Behavior on opacity {
                                Components.Anim {
                                    duration: Theme.qsPageFadeDuration
                                    curve: Components.Anim.DefaultEffects
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
                                Components.Anim {
                                    duration: Theme.qsPageSlideDuration
                                    curve: Components.Anim.DefaultSpatial
                                }

                            }

                            Behavior on opacity {
                                Components.Anim {
                                    duration: Theme.qsPageFadeDuration
                                    curve: Components.Anim.DefaultEffects
                                }

                            }

                        }

                        Behavior on implicitHeight {
                            Components.Anim {
                                duration: Theme.qsHeightDuration
                                curve: Components.Anim.DefaultEffects
                            }

                        }

                    }

                    Item {
                        height: 0
                    }

                }

            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.7)
            shadowBlur: 0.88
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            blurMax: 48
        }

    }

    Timer {
        interval: Theme.slowPollInterval
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: powerProfilePoll.running = true
    }

    Process {
        id: powerProfilePoll

        command: [root.powerProfileHelper, "get"]

        stdout: StdioCollector {
            id: powerProfileOut

            onStreamFinished: {
                const nextMode = powerProfileOut.text.trim();
                if (nextMode === "power-saver" || nextMode === "balanced" || nextMode === "performance")
                    root.powerMode = nextMode;

            }
        }

    }

    Process {
        id: setPowerProfile

        command: ["echo"]
        onExited: powerProfilePoll.running = true
    }

    Services.WifiConnectionService {
        id: wifiService
    }

    states: State {
        name: "open"

        PropertyChanges {
            root.reveal: 1
        }

    }

}
