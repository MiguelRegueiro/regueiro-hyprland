import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Services.UPower
import Quickshell.Io
import "pages" as Pages
import "../services" as Services
import "../components" as Components
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    required property var notificationStore
    required property var audioService
    required property var brightnessService
    required property var networkService
    property bool open: false
    property real topOffset: 0
    property bool hovered: panelHover.hovered || boundsHover.hovered
    readonly property string powerMode: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver: return "power-saver";
        case PowerProfile.Balanced: return "balanced";
        case PowerProfile.Performance: return "performance";
        default: return "";
        }
    }
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
    readonly property real attachRight: 0
    readonly property bool submenuOpen: root.wifiPageOpen || root.bluetoothPageOpen
    readonly property real audioOutputPopupOverflow: root.audioOutputPopupOpen ? dashboard.audioOutputPopupOverflow : 0
    readonly property real revealProgress: reveal
    readonly property real bodyWidth: Theme.qsWidth
    readonly property real bodyHeight: contentLayout.implicitHeight + (root.wifiPageOpen ? 0 : Theme.qsContentPadding * 2) + root.attachTop
    readonly property real fuseLeftOverhang: 0
    readonly property real fuseBottomOverhang: 0
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real mergedTopLeftRadius: 0.001
    readonly property real mergedBottomRightRadius: Theme.qsSurfaceBottomRightRadius
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real bottomFuseJoinX: root.bodyWidth - root.surfaceBottomRightRadius
    readonly property real clipSurfaceWidth: root.bodyWidth + root.fuseLeftOverhang
    readonly property real clipSurfaceHeight: root.bodyHeight + root.fuseBottomOverhang
    readonly property real visibleBodyHeight: root.bodyHeight
    readonly property real revealFrontY: root.visibleBodyHeight
    readonly property real revealFrontLeftRadius: Math.min(root.surfaceBottomLeftRadius, root.visibleBodyHeight / 2)
    readonly property real revealFrontRightRadius: Math.min(root.mergedBottomRightRadius, root.visibleBodyHeight / 2)
    readonly property real contentRevealProgress: root.reveal

    signal powerActionRequested(string actionId)

    function applyPowerMode(nextMode) {
        if (nextMode === "power-saver")
            PowerProfiles.profile = PowerProfile.PowerSaver;
        else if (nextMode === "balanced")
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (nextMode === "performance" && PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance;
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
                curve: Components.Anim.StandardDecel
                duration: Theme.topBarMenuOpenDuration
            }

        },
        Transition {
            from: "open"
            to: ""

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.StandardAccel
                duration: Theme.topBarMenuCloseDuration
            }

        }
    ]

    anchors {
        top: parent.top
        right: parent.right
        topMargin: root.topOffset
        rightMargin: 20
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
        y: (1 - root.reveal) * 6
        opacity: root.reveal
        layer.enabled: true

            HoverHandler {
                id: boundsHover

                blocking: false
            }

            Item {
                anchors.top: parent.top
                anchors.right: parent.right
                width: Math.max(1, root.clipSurfaceWidth)
                height: Math.max(1, root.bodyHeight + root.fuseBottomOverhang)
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
                        visible: false
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.qsSurfaceBg
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
                        fillColor: Theme.qsSurfaceBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove {
                            x: root.mergedTopLeftRadius
                            y: 0
                        }

                        PathLine {
                            x: frame.width - root.surfaceTopRightRadius
                            y: 0
                        }

                        PathArc {
                            x: frame.width
                            y: root.surfaceTopRightRadius
                            radiusX: root.surfaceTopRightRadius
                            radiusY: root.surfaceTopRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width
                            y: root.revealFrontY - root.revealFrontRightRadius
                        }

                        PathArc {
                            x: frame.width - root.revealFrontRightRadius
                            y: root.revealFrontY
                            radiusX: root.revealFrontRightRadius
                            radiusY: root.revealFrontRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: root.revealFrontLeftRadius
                            y: root.revealFrontY
                        }

                        PathArc {
                            relativeX: -root.revealFrontLeftRadius
                            relativeY: -root.revealFrontLeftRadius
                            radiusX: root.revealFrontLeftRadius
                            radiusY: root.revealFrontLeftRadius
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
                            y: root.revealFrontY
                        }

                        PathLine {
                            x: root.revealFrontLeftRadius
                            y: root.revealFrontY
                        }

                        PathArc {
                            relativeX: -root.revealFrontLeftRadius
                            relativeY: -root.revealFrontLeftRadius
                            radiusX: root.revealFrontLeftRadius
                            radiusY: root.revealFrontLeftRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: 0
                            y: root.topFuseJoinY
                        }

                    }

                    ShapePath {
                        fillColor: Theme.qsSurfaceBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove {
                            x: frame.width
                            y: 0
                        }

                        PathLine {
                            x: frame.width - root.surfaceTopRightRadius
                            y: 0
                        }

                        PathArc {
                            x: frame.width
                            y: root.surfaceTopRightRadius
                            radiusX: root.surfaceTopRightRadius
                            radiusY: root.surfaceTopRightRadius
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

                }

                Rectangle {
                    x: frame.x
                    y: frame.y
                    width: frame.width
                    height: root.visibleBodyHeight
                    radius: Theme.qsSurfaceBottomLeftRadius
                    color: Theme.qsSurfaceBg
                    border.width: 2
                    border.color: Theme.bottomPanelOutline
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                    }
                }

                ColumnLayout {
                    id: contentLayout

                    spacing: 0
                    opacity: root.contentRevealProgress

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
                            brightnessService: root.brightnessService
                            networkService: root.networkService
                            wifiPage: wifiPageView
                            bluetoothPage: bluetoothPageView
                            powerMode: root.powerMode
                            hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
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
                            bottomViewportInset: Theme.qsContentPadding * 2
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
            shadowEnabled: false
            shadowColor: Qt.rgba(0, 0, 0, 0.7)
            shadowBlur: 0.88
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            blurMax: 48
        }

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
