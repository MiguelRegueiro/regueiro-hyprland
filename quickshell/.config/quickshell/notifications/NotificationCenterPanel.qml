import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore

    property bool open: false
    property real reveal: 0
    property int timeTick: 0

    readonly property alias inputRegion: inputRegion
    readonly property bool inputActive: reveal > 0.03
    readonly property bool hovered: hoverArea.hovered || boundsHover.hovered
    readonly property real attachTop: Theme.ncAttachTop
    readonly property real topLeftRadius: Theme.ncSurfaceTopLeftRadius
    readonly property real topRightRadius: Theme.ncSurfaceTopRightRadius
    readonly property real bottomLeftRadius: Theme.ncSurfaceBottomLeftRadius
    readonly property real bottomRightRadius: Theme.ncSurfaceBottomRightRadius
    readonly property real revealProgress: reveal
    readonly property real animTopLeftRadius: root.topLeftRadius * root.reveal
    readonly property real animTopRightRadius: root.topRightRadius * root.reveal
    readonly property real clipWidthProgress: 0.84 + root.reveal * 0.16
    readonly property real clipHeightProgress: 0.78 + root.reveal * 0.22
    readonly property real frameScale: 0.988 + root.reveal * 0.012
    readonly property real frameOpacity: 0.72 + root.reveal * 0.28
    readonly property real bodyWidth: Theme.ncWidth
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real mergedTopLeftRadius: 0.001
    readonly property real mergedTopRightRadius: 0.001
    readonly property real clipSurfaceWidth: root.bodyWidth * root.clipWidthProgress
        + root.fuseOverhang * 2 * root.reveal

    implicitWidth: root.bodyWidth + root.fuseOverhang * 2
    implicitHeight: contentColumn.implicitHeight + root.attachTop
    width: implicitWidth
    height: implicitHeight
    visible: reveal > 0.001

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.timeTick += 1
    }

    state: open ? "open" : ""

    states: State {
        name: "open"
        PropertyChanges { root.reveal: 1 }
    }

    transitions: [
        Transition {
            from: ""
            to: "open"
            NumberAnimation {
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
                property: "reveal"
                duration: 165
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1.0, 1.0]
            }
        }
    ]

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
        transformOrigin: Item.Top
        opacity: root.frameOpacity
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5 * root.reveal)
            shadowBlur: 0.75
            shadowVerticalOffset: 8
            shadowHorizontalOffset: 0
            blurMax: 32
        }

        HoverHandler {
            id: boundsHover
            blocking: false
        }

        Item {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, root.clipSurfaceWidth)
            height: Math.max(1, root.height * root.clipHeightProgress)
            clip: true

            HoverHandler {
                id: hoverArea
                blocking: false
            }

            Shape {
                id: fusedSurface
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.width
                height: root.height
                preferredRendererType: Shape.CurveRenderer

                readonly property real panelLeftX: root.fuseOverhang
                readonly property real panelRightX: width - root.fuseOverhang
                readonly property real junctionY: root.fuseTopInset

                ShapePath {
                    fillColor: Theme.menuBg
                    strokeColor: Theme.menuBg
                    strokeWidth: 1.6
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathMove { x: fusedSurface.panelLeftX; y: fusedSurface.junctionY }
                    PathLine { x: 0; y: fusedSurface.junctionY }
                    PathArc {
                        x: fusedSurface.panelLeftX
                        y: fusedSurface.junctionY + Theme.barCornerRadius
                        radiusX: Theme.barCornerRadius
                        radiusY: Theme.barCornerRadius
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: fusedSurface.panelLeftX; y: fusedSurface.junctionY }
                }

                ShapePath {
                    fillColor: Theme.menuBg
                    strokeColor: Theme.menuBg
                    strokeWidth: 1.6
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathMove { x: fusedSurface.panelRightX; y: fusedSurface.junctionY }
                    PathLine { x: fusedSurface.width; y: fusedSurface.junctionY }
                    PathArc {
                        x: fusedSurface.panelRightX
                        y: fusedSurface.junctionY + Theme.barCornerRadius
                        radiusX: Theme.barCornerRadius
                        radiusY: Theme.barCornerRadius
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: fusedSurface.panelRightX; y: fusedSurface.junctionY }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Theme.qsEdge
                    strokeWidth: 1.1
                    capStyle: ShapePath.FlatCap
                    joinStyle: ShapePath.RoundJoin
                    PathMove { x: 0; y: fusedSurface.junctionY }
                    PathArc {
                        x: fusedSurface.panelLeftX
                        y: fusedSurface.junctionY + Theme.barCornerRadius
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
                    PathMove { x: fusedSurface.width; y: fusedSurface.junctionY }
                    PathArc {
                        x: fusedSurface.panelRightX
                        y: fusedSurface.junctionY + Theme.barCornerRadius
                        radiusX: Theme.barCornerRadius
                        radiusY: Theme.barCornerRadius
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Item {
                id: frame
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.bodyWidth
                height: root.height

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1

                        PathMove { x: root.mergedTopLeftRadius; y: 0 }
                        PathLine { x: frame.width - root.mergedTopRightRadius; y: 0 }
                        PathArc {
                            x: frame.width
                            y: root.mergedTopRightRadius
                            radiusX: root.mergedTopRightRadius
                            radiusY: root.mergedTopRightRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: frame.width; y: frame.height - root.bottomRightRadius }
                        PathArc {
                            x: frame.width - root.bottomRightRadius
                            y: frame.height
                            radiusX: root.bottomRightRadius
                            radiusY: root.bottomRightRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: root.bottomLeftRadius; y: frame.height }
                        PathArc {
                            relativeX: -root.bottomLeftRadius
                            relativeY: -root.bottomLeftRadius
                            radiusX: root.bottomLeftRadius
                            radiusY: root.bottomLeftRadius
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

                        // Left edge
                        PathMove { x: 0; y: root.topFuseJoinY }
                        PathLine { x: 0; y: frame.height - root.bottomLeftRadius }

                        // Bottom-left corner
                        PathArc {
                            x: root.bottomLeftRadius
                            y: frame.height
                            radiusX: root.bottomLeftRadius
                            radiusY: root.bottomLeftRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Bottom edge
                        PathLine { x: frame.width - root.bottomRightRadius; y: frame.height }

                        // Bottom-right corner
                        PathArc {
                            x: frame.width
                            y: frame.height - root.bottomRightRadius
                            radiusX: root.bottomRightRadius
                            radiusY: root.bottomRightRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Right edge
                        PathLine { x: frame.width; y: root.topFuseJoinY }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: Theme.menuBg
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathMove { x: 0; y: 0 }
                        PathLine { x: root.animTopLeftRadius; y: 0 }
                        PathArc {
                            x: 0
                            y: root.animTopLeftRadius
                            radiusX: root.animTopLeftRadius
                            radiusY: root.animTopLeftRadius
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: 0; y: 0 }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: Theme.menuBg
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathMove { x: frame.width; y: 0 }
                        PathLine { x: frame.width - root.animTopRightRadius; y: 0 }
                        PathArc {
                            x: frame.width
                            y: root.animTopRightRadius
                            radiusX: root.animTopRightRadius
                            radiusY: root.animTopRightRadius
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: frame.width; y: 0 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                    }
                }

                Column {
                    id: contentColumn
                    width: parent.width
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: Math.max(0, root.attachTop - 6)
                    }

                    Item {
                        width: parent.width
                        height: 54

                        RowLayout {
                            anchors {
                                left: parent.left
                                leftMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 12

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 10
                                color: Theme.qsRowBg
                                border.width: 1
                                border.color: Theme.qsEdgeSoft

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂚"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 14
                                    color: Theme.textDim
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: "Notifications"
                                    color: Theme.textPrimary
                                    font.family: Theme.fontUi
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    width: Math.max(24, countText.implicitWidth + 14)
                                    height: 24
                                    radius: 12
                                    color: Theme.hoverBg
                                    border.width: 1
                                    border.color: Theme.qsEdgeSoft

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: String(root.notificationStore.count)
                                        color: Theme.textDim
                                        font.family: Theme.fontUi
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            visible: root.notificationStore.count > 0
                            width: clearText.implicitWidth + 24
                            height: 34
                            radius: 11
                            color: clearHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg
                            border.width: 1
                            border.color: Theme.qsEdgeSoft

                            Text {
                                id: clearText
                                anchors.centerIn: parent
                                text: "Clear"
                                color: Theme.textDim
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            HoverHandler {
                                id: clearHover
                                blocking: false
                            }

                            TapHandler {
                                onTapped: root.notificationStore.dismissAll()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 28
                        height: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.qsEdgeSoft
                    }

                    Item {
                        width: parent.width
                        implicitHeight: root.notificationStore.count === 0
                            ? emptyState.implicitHeight + 40
                            : Math.min(notificationList.contentHeight + 26, 526)
                        clip: true

                        Column {
                            id: emptyState
                            visible: root.notificationStore.count === 0
                            width: parent.width - 48
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 12

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 68
                                height: 68
                                radius: 20
                                color: Theme.qsRowBg
                                border.width: 1
                                border.color: Theme.qsEdgeSoft

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂜"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 30
                                    color: Theme.textDisabled
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No notifications"
                                color: Theme.textPrimary
                                font.family: Theme.fontUi
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                        }

                        ListView {
                            id: notificationList
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                                topMargin: 12
                                bottomMargin: 14
                            }
                            visible: root.notificationStore.count > 0
                            model: root.notificationStore.notifications
                            spacing: 10
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: NotificationListItem {
                                required property var modelData

                                notificationStore: root.notificationStore
                                item: modelData
                                timeTick: root.timeTick
                            }
                        }
                    }
                }
            }
        }
    }
}
