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
    required property var driveService
    property bool open: false
    readonly property real reveal: externalPanel.reveal
    readonly property var drives: driveService && driveService.drives ? driveService.drives : []
    readonly property string lastError: driveService && driveService.lastError ? driveService.lastError : ""
    readonly property bool loading: driveService && driveService.loading
    readonly property bool mutating: driveService && driveService.mutating
    readonly property real menuWidth: 320
    readonly property real menuRightMargin: 176
    readonly property real menuY: Theme.barHeight - Theme.qsBarFuseOverlap - 2
    readonly property real attachTop: Theme.ncAttachTop
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real bottomLeftRadius: Theme.ncSurfaceBottomLeftRadius
    readonly property real bottomRightRadius: Theme.ncSurfaceBottomRightRadius
    readonly property real clipWidthProgress: 0.84 + root.reveal * 0.16
    readonly property real clipHeightProgress: 0.78 + root.reveal * 0.22
    readonly property real frameScale: 0.988 + root.reveal * 0.012
    readonly property real frameOpacity: 0.72 + root.reveal * 0.28
    readonly property real surfaceHeight: Math.max(68, Math.min(root.height - root.menuY - 10, menuColumn.implicitHeight + root.attachTop + 14))
    readonly property real clipSurfaceWidth: root.menuWidth * root.clipWidthProgress + root.fuseOverhang * 2 * root.reveal
    readonly property int openDuration: 260
    readonly property int closeDuration: 110

    signal closeRequested()

    screen: targetScreen
    visible: root.open || root.reveal > 0.001
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-external-drives"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.open
        onPressed: root.closeRequested()
    }

    Item {
        id: externalPanel

        property real reveal: 0
        property bool open: root.open

        visible: reveal > 0.001
        x: Math.max(8 - root.fuseOverhang, root.width - root.menuWidth - root.menuRightMargin - root.fuseOverhang)
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
                    curve: Components.Anim.FastSpatial
                    duration: root.openDuration
                }

            },
            Transition {
                from: "open"
                to: ""

                Components.Anim {
                    property: "reveal"
                    curve: Components.Anim.EmphasizedAccel
                    duration: root.closeDuration
                }

            }
        ]

        states: State {
            name: "open"

            PropertyChanges {
                externalPanel.reveal: 1
            }

        }

        Item {
            id: motionFrame

            width: externalPanel.width
            height: externalPanel.height
            y: (1 - root.reveal) * -4
            scale: root.frameScale
            transformOrigin: Item.Top
            opacity: root.frameOpacity
            layer.enabled: true

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, root.clipSurfaceWidth)
                height: Math.max(1, externalPanel.height * root.clipHeightProgress)
                clip: true

                Item {
                    id: frame

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.menuWidth
                    height: externalPanel.height

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: 0
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

                        PathLine {
                            x: 0
                            y: frame.height - root.bottomLeftRadius
                        }

                        PathArc {
                            x: root.bottomLeftRadius
                            y: frame.height
                            radiusX: root.bottomLeftRadius
                            radiusY: root.bottomLeftRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width - root.bottomRightRadius
                            y: frame.height
                        }

                        PathArc {
                            x: frame.width
                            y: frame.height - root.bottomRightRadius
                            radiusX: root.bottomRightRadius
                            radiusY: root.bottomRightRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width
                            y: root.topFuseJoinY
                        }

                        PathArc {
                            x: frame.width + root.fuseOverhang
                            y: root.fuseTopInset
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width + root.fuseOverhang
                            y: 0
                        }

                        PathLine {
                            x: -root.fuseOverhang
                            y: 0
                        }

                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.qsEdge
                        strokeWidth: 1
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

                        PathLine {
                            x: 0
                            y: frame.height - root.bottomLeftRadius
                        }

                        PathArc {
                            x: root.bottomLeftRadius
                            y: frame.height
                            radiusX: root.bottomLeftRadius
                            radiusY: root.bottomLeftRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width - root.bottomRightRadius
                            y: frame.height
                        }

                        PathArc {
                            x: frame.width
                            y: frame.height - root.bottomRightRadius
                            radiusX: root.bottomRightRadius
                            radiusY: root.bottomRightRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width
                            y: root.topFuseJoinY
                        }

                        PathArc {
                            x: frame.width + root.fuseOverhang
                            y: root.fuseTopInset
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Clockwise
                        }

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
                            spacing: 10

                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: ""
                                font.family: Theme.fontIcons
                                font.pixelSize: 16
                                color: Theme.textPrimary
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.drives.length === 1 ? "External drive" : "External drives"
                                font.family: Theme.fontUi
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: Math.max(24, countText.implicitWidth + 14)
                                height: 24
                                radius: 12
                                color: Theme.qsRowBg

                                Text {
                                    id: countText

                                    anchors.fill: parent
                                    text: root.loading || root.mutating ? "…" : String(root.drives.length)
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.qsEdgeSoft
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.drives.length === 0 ? 64 : drivesColumn.implicitHeight + 24
                        clip: true

                        ColumnLayout {
                            id: emptyState

                            visible: root.drives.length === 0
                            anchors.centerIn: parent
                            width: parent.width - 28
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.lastError.length > 0 ? root.lastError : "No external drives"
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: root.lastError.length > 0 ? Theme.red : Theme.textDim
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                        }

                        ColumnLayout {
                            id: drivesColumn

                            visible: root.drives.length > 0
                            spacing: 8

                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 12
                            }

                            Repeater {
                                model: root.drives

                                delegate: Rectangle {
                                    id: driveRow

                                    required property var modelData
                                    readonly property bool hovered: rowHover.hovered

                                    Layout.fillWidth: true
                                    implicitHeight: 92
                                    radius: Theme.qsRadius + 1
                                    color: hovered ? Qt.rgba(0.115, 0.115, 0.115, 1) : Theme.qsCardBg
                                    border.width: 1
                                    border.color: hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder
                                    layer.enabled: true

                                    HoverHandler {
                                        id: rowHover

                                        blocking: false
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 30
                                                Layout.preferredHeight: 30
                                                radius: 15
                                                color: modelData.mounted ? Qt.rgba(1, 1, 1, 0.10) : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: modelData.mounted ? Qt.rgba(1, 1, 1, 0.12) : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: Theme.fontIcons
                                                    font.pixelSize: 15
                                                    color: modelData.mounted ? Theme.textPrimary : Theme.textDim
                                                }

                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.label
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: {
                                                        const bits = [];
                                                        if (modelData.size.length > 0)
                                                            bits.push(modelData.size);
                                                        if (modelData.fstype.length > 0)
                                                            bits.push(modelData.fstype.toUpperCase());
                                                        bits.push(modelData.mounted ? modelData.mountPath : "Not mounted");
                                                        return bits.join(" · ");
                                                    }
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11
                                                    color: Theme.textDim
                                                    elide: Text.ElideRight
                                                }

                                            }

                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Rectangle {
                                                visible: modelData.mounted
                                                Layout.preferredWidth: 64
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: openHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: openHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Open"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: openHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.driveService.openDrive(modelData);
                                                        root.closeRequested();
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: !modelData.mounted
                                                Layout.preferredWidth: 64
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: mountHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: mountHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Mount"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: mountHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.driveService.mountDrive(modelData)
                                                }
                                            }

                                            Rectangle {
                                                visible: modelData.mounted
                                                Layout.preferredWidth: 80
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: unmountHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: unmountHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Unmount"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: unmountHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.driveService.unmountDrive(modelData)
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 58
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: ejectHover.hovered ? Qt.rgba(1, 0.36, 0.32, 0.18) : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: ejectHover.hovered ? Qt.rgba(1, 0.48, 0.39, 0.20) : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Eject"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: ejectHover.hovered ? Theme.red : Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: ejectHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.driveService.ejectDrive(modelData);
                                                        root.closeRequested();
                                                    }
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                        }

                                    }

                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Qt.rgba(0, 0, 0, driveRow.hovered ? 0.42 : 0.32)
                                        shadowBlur: 0.65
                                        shadowVerticalOffset: 1
                                        shadowHorizontalOffset: 0
                                        blurMax: 18
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.hoverAnimDuration
                                        }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Theme.hoverAnimDuration
                                        }
                                    }

                                }

                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.lastError.length > 0 && root.drives.length > 0
                        text: root.lastError
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                        color: Theme.red
                        wrapMode: Text.WordWrap
                    }

                }

            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.96 * root.reveal)
            shadowBlur: 0.72
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
            blurMax: 28
        }

    }

}

}
