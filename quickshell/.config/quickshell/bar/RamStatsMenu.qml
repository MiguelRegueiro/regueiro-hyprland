import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var detailsService
    property bool open: false
    readonly property real reveal: statsPanel.reveal
    readonly property real menuWidth: 430
    readonly property real menuLeft: 190
    readonly property real menuY: Theme.barHeight - Theme.qsBarFuseOverlap - 2
    readonly property real attachTop: Theme.ncAttachTop
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real bottomLeftRadius: Theme.ncSurfaceBottomLeftRadius
    readonly property real bottomRightRadius: Theme.ncSurfaceBottomRightRadius
    readonly property real surfaceOffsetY: -(1 - root.reveal) * statsPanel.height
    readonly property real surfaceHeight: Math.max(118, Math.min(root.height - root.menuY - 10, menuColumn.implicitHeight + root.attachTop + 14))
    readonly property real clipSurfaceWidth: root.menuWidth + root.fuseOverhang * 2

    signal closeRequested()

    function usedPercent() {
        if (root.detailsService.ramTotalGb <= 0)
            return 0;

        return Math.max(0, Math.min(100, Math.round(root.detailsService.ramUsedGb * 100 / root.detailsService.ramTotalGb)));
    }

    screen: targetScreen
    visible: root.open || root.reveal > 0.001
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-ram-stats"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onOpenChanged: {
        if (open && detailsService)
            detailsService.refreshRam();
    }

    Timer {
        interval: 3000
        running: root.open
        repeat: true
        onTriggered: root.detailsService.refreshRam()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.open
        onPressed: root.closeRequested()
    }

    Item {
        id: statsPanel

        property real reveal: 0
        property bool open: root.open

        visible: reveal > 0.001
        x: root.menuLeft - root.fuseOverhang
        y: root.menuY
        width: root.menuWidth + root.fuseOverhang * 2
        height: root.surfaceHeight
        state: open ? "open" : ""
        transitions: [
            Transition {
                from: ""
                to: "open"
                Components.Anim {
                    property: "reveal"
                    curve: Components.Anim.EmphasizedDecel
                    duration: Theme.topBarMenuOpenDuration
                }
            },
            Transition {
                from: "open"
                to: ""
                Components.Anim {
                    property: "reveal"
                    curve: Components.Anim.EmphasizedAccel
                    duration: Theme.topBarMenuCloseDuration
                }
            }
        ]

        states: State {
            name: "open"
            PropertyChanges {
                statsPanel.reveal: 1
            }
        }

        Item {
            id: motionFrame

            width: statsPanel.width
            height: Math.max(1, statsPanel.height)
            layer.enabled: true

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, root.clipSurfaceWidth)
                height: Math.max(1, statsPanel.height)
                clip: true

                Item {
                    id: frame

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.menuWidth
                    height: statsPanel.height
                    transform: Translate {
                        y: root.surfaceOffsetY
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.menuBg
                            strokeColor: "transparent"
                            strokeWidth: 0
                            capStyle: ShapePath.FlatCap
                            joinStyle: ShapePath.RoundJoin

                            PathMove { x: -root.fuseOverhang; y: root.fuseTopInset }
                            PathArc { x: 0; y: root.topFuseJoinY; radiusX: Theme.barCornerRadius; radiusY: Theme.barCornerRadius; direction: PathArc.Clockwise }
                            PathLine { x: 0; y: frame.height - root.bottomLeftRadius }
                            PathArc { x: root.bottomLeftRadius; y: frame.height; radiusX: root.bottomLeftRadius; radiusY: root.bottomLeftRadius; direction: PathArc.Counterclockwise }
                            PathLine { x: frame.width - root.bottomRightRadius; y: frame.height }
                            PathArc { x: frame.width; y: frame.height - root.bottomRightRadius; radiusX: root.bottomRightRadius; radiusY: root.bottomRightRadius; direction: PathArc.Counterclockwise }
                            PathLine { x: frame.width; y: root.topFuseJoinY }
                            PathArc { x: frame.width + root.fuseOverhang; y: root.fuseTopInset; radiusX: Theme.barCornerRadius; radiusY: Theme.barCornerRadius; direction: PathArc.Clockwise }
                            PathLine { x: frame.width + root.fuseOverhang; y: 0 }
                            PathLine { x: -root.fuseOverhang; y: 0 }
                        }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Theme.qsEdge
                            strokeWidth: 1
                            capStyle: ShapePath.FlatCap
                            joinStyle: ShapePath.RoundJoin

                            PathMove { x: -root.fuseOverhang; y: root.fuseTopInset }
                            PathArc { x: 0; y: root.topFuseJoinY; radiusX: Theme.barCornerRadius; radiusY: Theme.barCornerRadius; direction: PathArc.Clockwise }
                            PathLine { x: 0; y: frame.height - root.bottomLeftRadius }
                            PathArc { x: root.bottomLeftRadius; y: frame.height; radiusX: root.bottomLeftRadius; radiusY: root.bottomLeftRadius; direction: PathArc.Counterclockwise }
                            PathLine { x: frame.width - root.bottomRightRadius; y: frame.height }
                            PathArc { x: frame.width; y: frame.height - root.bottomRightRadius; radiusX: root.bottomRightRadius; radiusY: root.bottomRightRadius; direction: PathArc.Counterclockwise }
                            PathLine { x: frame.width; y: root.topFuseJoinY }
                            PathArc { x: frame.width + root.fuseOverhang; y: root.fuseTopInset; radiusX: Theme.barCornerRadius; radiusY: Theme.barCornerRadius; direction: PathArc.Clockwise }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                    }

                    ColumnLayout {
                        id: menuColumn

                        spacing: 0

                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            topMargin: root.attachTop
                            leftMargin: 14
                            rightMargin: 14
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 14
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.bottomMargin: 10
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Memory"
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: `${root.detailsService.formatGb(root.detailsService.ramUsedGb)} / ${root.detailsService.formatGb(root.detailsService.ramTotalGb)}`
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
                                        font.weight: Font.DemiBold
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: `${root.usedPercent()}%`
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
                                        color: Theme.textDim
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: Theme.qsCardChipBg

                                    Rectangle {
                                        width: parent.width * root.usedPercent() / 100
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.accent
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Swap"
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: `${root.detailsService.formatGb(root.detailsService.swapUsedGb)} / ${root.detailsService.formatGb(root.detailsService.swapTotalGb)}`
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
                                        font.weight: Font.DemiBold
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: `${Math.max(0, Math.min(100, root.detailsService.swapPct))}%`
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
                                        color: Theme.textDim
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: Theme.qsCardChipBg

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(100, root.detailsService.swapPct)) / 100
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.96)
                shadowBlur: 0.72
                shadowVerticalOffset: 2
                shadowHorizontalOffset: 0
                blurMax: 28
            }
        }
    }
}
