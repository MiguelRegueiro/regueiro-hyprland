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
    readonly property real clipSurfaceWidth: root.bodyWidth * root.clipWidthProgress + root.fuseOverhang * 2 * root.reveal

    implicitWidth: root.bodyWidth + root.fuseOverhang * 2
    implicitHeight: contentColumn.implicitHeight + root.attachTop
    width: implicitWidth
    height: implicitHeight
    visible: reveal > 0.001
    state: open ? "open" : ""
    transitions: [
        Transition {
            from: ""
            to: "open"

            NumberAnimation {
                property: "reveal"
                duration: Theme.panelOpenDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }

        },
        Transition {
            from: "open"
            to: ""

            NumberAnimation {
                property: "reveal"
                duration: Theme.panelCloseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.4, 0, 0.85, 0.3, 1, 1]
            }

        }
    ]

    Timer {
        interval: Theme.slowPollInterval
        running: true
        repeat: true
        onTriggered: root.timeTick += 1
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
        transformOrigin: Item.Top
        opacity: root.frameOpacity
        layer.enabled: true

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

                        PathMove {
                            x: 0
                            y: root.fuseTopInset
                        }

                        PathLine {
                            x: -root.fuseOverhang
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
                            x: frame.width
                            y: root.fuseTopInset
                        }

                        PathLine {
                            x: frame.width + root.fuseOverhang
                            y: root.fuseTopInset
                        }

                        PathArc {
                            x: frame.width
                            y: root.topFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width
                            y: root.fuseTopInset
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
                            x: frame.width - root.mergedTopRightRadius
                            y: 0
                        }

                        PathArc {
                            x: frame.width
                            y: root.mergedTopRightRadius
                            radiusX: root.mergedTopRightRadius
                            radiusY: root.mergedTopRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width
                            y: frame.height - root.bottomRightRadius
                        }

                        PathArc {
                            x: frame.width - root.bottomRightRadius
                            y: frame.height
                            radiusX: root.bottomRightRadius
                            radiusY: root.bottomRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: root.bottomLeftRadius
                            y: frame.height
                        }

                        PathArc {
                            relativeX: -root.bottomLeftRadius
                            relativeY: -root.bottomLeftRadius
                            radiusX: root.bottomLeftRadius
                            radiusY: root.bottomLeftRadius
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

                        // Left edge
                        PathMove {
                            x: 0
                            y: root.topFuseJoinY
                        }

                        PathLine {
                            x: 0
                            y: frame.height - root.bottomLeftRadius
                        }

                        // Bottom-left corner
                        PathArc {
                            x: root.bottomLeftRadius
                            y: frame.height
                            radiusX: root.bottomLeftRadius
                            radiusY: root.bottomLeftRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Bottom edge
                        PathLine {
                            x: frame.width - root.bottomRightRadius
                            y: frame.height
                        }

                        // Bottom-right corner
                        PathArc {
                            x: frame.width
                            y: frame.height - root.bottomRightRadius
                            radiusX: root.bottomRightRadius
                            radiusY: root.bottomRightRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Right edge
                        PathLine {
                            x: frame.width
                            y: root.topFuseJoinY
                        }

                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: Theme.menuBg
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: 0
                            y: 0
                        }

                        PathLine {
                            x: root.animTopLeftRadius
                            y: 0
                        }

                        PathArc {
                            x: 0
                            y: root.animTopLeftRadius
                            radiusX: root.animTopLeftRadius
                            radiusY: root.animTopLeftRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: 0
                            y: 0
                        }

                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: Theme.menuBg
                        strokeWidth: 1.6
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

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

                        PathLine {
                            x: frame.width
                            y: 0
                        }

                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.qsEdge
                        strokeWidth: 1.1
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: -root.fuseOverhang
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
                            x: frame.width + root.fuseOverhang
                            y: root.fuseTopInset
                        }

                        PathArc {
                            x: frame.width
                            y: root.topFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

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
                        height: 48

                        RowLayout {
                            spacing: 10

                            anchors {
                                left: parent.left
                                leftMargin: 16
                                verticalCenter: parent.verticalCenter
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
                                    color: Theme.qsRowBg
                                    border.width: 0

                                    Text {
                                        id: countText

                                        anchors.fill: parent
                                        text: String(root.notificationStore.count)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                }

                            }

                        }

                        Item {
                            visible: root.notificationStore.count > 0
                            width: clearText.implicitWidth + 8
                            height: clearText.implicitHeight + 4

                            anchors {
                                right: parent.right
                                rightMargin: 16
                                verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: clearText

                                anchors.centerIn: parent
                                text: "Clear"
                                color: clearHover.hovered ? Theme.textPrimary : Theme.textDim
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
                        implicitHeight: root.notificationStore.count === 0 ? emptyState.implicitHeight + 40 : Math.min(notificationList.contentHeight + 26, 526)
                        clip: true

                        Column {
                            id: emptyState

                            visible: root.notificationStore.count === 0
                            width: parent.width - 48
                            spacing: 12

                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰂜"
                                font.family: Theme.fontIcons
                                font.pixelSize: 28
                                color: Theme.textDisabled
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

                            visible: root.notificationStore.count > 0
                            model: root.notificationStore.notifications
                            spacing: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                                topMargin: 12
                                bottomMargin: 14
                            }

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

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.7 * root.reveal)
            shadowBlur: 0.88
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            blurMax: 48
        }

    }

    states: State {
        name: "open"

        PropertyChanges {
            root.reveal: 1
        }

    }

}
