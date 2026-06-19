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
    readonly property real menuLeft: 124
    readonly property real menuY: Theme.barHeight - Theme.qsBarFuseOverlap - 2
    readonly property real attachTop: Theme.ncAttachTop
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real bottomLeftRadius: Theme.ncSurfaceBottomLeftRadius
    readonly property real bottomRightRadius: Theme.ncSurfaceBottomRightRadius
    readonly property real surfaceOffsetY: -(1 - root.reveal) * statsPanel.height
    readonly property real surfaceHeight: Math.max(180, Math.min(root.height - root.menuY - 10, menuColumn.implicitHeight + root.attachTop + 14))
    readonly property real clipSurfaceWidth: root.menuWidth + root.fuseOverhang * 2

    signal closeRequested()

    function shortCpuModel(model) {
        return String(model || "").replace(/\s+CPU\s+@.*$/, "").replace(/\(R\)|\(TM\)/g, "").trim();
    }

    screen: targetScreen
    visible: root.open || root.reveal > 0.001
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-cpu-stats"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onOpenChanged: {
        if (open && detailsService)
            detailsService.refreshCpu();
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        onTriggered: root.detailsService.refreshCpu()
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

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Text {
                                    text: "󰍛"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 16 + Theme.fontSizeDelta
                                    color: Theme.textPrimary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.shortCpuModel(root.detailsService.cpuModel)
                                        font.family: Theme.fontUi
                                        font.pixelSize: 14 + Theme.fontSizeDelta
                                        font.weight: Font.DemiBold
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.detailsService.cpuTemp.length > 0 ? `${root.detailsService.cpuCores} threads · ${root.detailsService.cpuTemp}` : `${root.detailsService.cpuCores} threads`
                                        font.family: Theme.fontUi
                                        font.pixelSize: 13 + Theme.fontSizeDelta
                                        color: Theme.textDim
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.qsEdgeSoft
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.bottomMargin: 12
                            spacing: 10

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 5

                                Repeater {
                                    model: root.detailsService.cpuCorePcts

                                    delegate: RowLayout {
                                        required property int modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            Layout.preferredWidth: 18
                                            text: `C${index + 1}`
                                            font.family: Theme.fontUi
                                            font.pixelSize: 12 + Theme.fontSizeDelta
                                            color: Theme.textDim
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: Theme.qsCardChipBg

                                            Rectangle {
                                                width: parent.width * Math.max(0, Math.min(100, modelData)) / 100
                                                height: parent.height
                                                radius: parent.radius
                                                color: Theme.accent
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth: 32
                                            text: `${modelData}%`
                                            font.family: Theme.fontUi
                                            font.pixelSize: 12 + Theme.fontSizeDelta
                                            color: Theme.textDim
                                            horizontalAlignment: Text.AlignRight
                                        }
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
