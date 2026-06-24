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
    required property var sshService
    property bool open: false
    readonly property real reveal: sshPanel.reveal
    readonly property var sessions: sshService && sshService.sessions ? sshService.sessions : []
    readonly property string lastError: sshService && sshService.lastError ? sshService.lastError : ""
    readonly property bool mutating: sshService && sshService.mutating
    readonly property real menuWidth: 460
    readonly property real menuRightMargin: 108
    readonly property real menuY: Theme.barHeight - Theme.qsBarFuseOverlap - 2
    readonly property real attachTop: Theme.ncAttachTop
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseTopInset: Theme.qsBarFuseOverlap + 2
    readonly property real topFuseJoinY: root.fuseTopInset + Theme.barCornerRadius
    readonly property real bottomLeftRadius: Theme.ncSurfaceBottomLeftRadius
    readonly property real bottomRightRadius: Theme.ncSurfaceBottomRightRadius
    readonly property real surfaceOffsetY: -(1 - root.reveal) * sshPanel.height
    readonly property real surfaceHeight: Math.max(68, Math.min(root.height - root.menuY - 10, menuColumn.implicitHeight + root.attachTop + 14))
    readonly property real clipSurfaceWidth: root.menuWidth + root.fuseOverhang * 2
    readonly property int openDuration: Theme.topBarMenuOpenDuration
    readonly property int closeDuration: Theme.topBarMenuCloseDuration

    signal closeRequested()

    function remoteLabel(session) {
        const address = session.remoteAddress || session.remoteHost || "";
        const port = session.remotePort || "";
        if (address.length === 0)
            return "";

        return port.length > 0 ? `${address}:${port}` : address;
    }

    function hostLabel(session) {
        if (!session.remoteHost || session.remoteHost === session.remoteAddress)
            return "";

        return session.remoteHost;
    }

    screen: targetScreen
    visible: root.open || root.reveal > 0.001
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-ssh-sessions"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Timer {
        interval: 1000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.sshService)
                root.sshService.refresh();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.open
        onPressed: root.closeRequested()
    }

    Item {
        id: sshPanel

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
                    curve: Components.Anim.EmphasizedDecel
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
                sshPanel.reveal: 1
            }
        }

        Item {
            id: motionFrame

            width: sshPanel.width
            height: Math.max(1, sshPanel.height)
            y: 0
            layer.enabled: true

            Item {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, root.clipSurfaceWidth)
                height: Math.max(1, sshPanel.height)
                clip: true

                Item {
                    id: frame

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.menuWidth
                    height: sshPanel.height
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
                                spacing: 10

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: ""
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 16 + Theme.fontSizeDelta
                                    color: Theme.textPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.sessions.length === 1 ? "SSH session" : "SSH sessions"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 14 + Theme.fontSizeDelta
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
                                        text: String(root.sessions.length)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontUi
                                        font.pixelSize: 12 + Theme.fontSizeDelta
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
                            Layout.preferredHeight: root.sessions.length === 0 ? 64 : sessionsColumn.implicitHeight + 24
                            clip: true

                            ColumnLayout {
                                visible: root.sessions.length === 0
                                anchors.centerIn: parent
                                width: parent.width - 28
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.lastError.length > 0 ? root.lastError : "No active sessions"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 12 + Theme.fontSizeDelta
                                    font.weight: Font.DemiBold
                                    color: root.lastError.length > 0 ? Theme.red : Theme.textDim
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                            ColumnLayout {
                                id: sessionsColumn

                                visible: root.sessions.length > 0
                                spacing: 8

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 12
                                }

                                Repeater {
                                    model: root.sessions

                                    delegate: Rectangle {
                                        id: sessionRow

                                        required property var modelData
                                        readonly property bool hovered: rowHover.hovered
                                        readonly property bool canEnd: root.sshService && root.sshService.canTerminate(modelData)
                                        readonly property bool pending: root.sshService && root.sshService.pendingTty === modelData.tty
                                        readonly property bool terminating: root.sshService && root.sshService.terminatingTty === modelData.tty

                                        Layout.fillWidth: true
                                        implicitHeight: 70
                                        radius: Theme.qsRadius + 1
                                        color: hovered ? Qt.rgba(0.115, 0.115, 0.115, 1) : Theme.qsCardBg
                                        border.width: 1
                                        border.color: hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder

                                        HoverHandler {
                                            id: rowHover

                                            blocking: false
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 30
                                                Layout.preferredHeight: 30
                                                radius: 15
                                                color: Qt.rgba(1, 1, 1, 0.10)
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.12)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: Theme.fontIcons
                                                    font.pixelSize: 14 + Theme.fontSizeDelta
                                                    color: Theme.textPrimary
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: `${modelData.user}  ${modelData.tty}  ${root.remoteLabel(modelData)}`
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 13 + Theme.fontSizeDelta
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textPrimary
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: root.hostLabel(modelData).length > 0
                                                    text: root.hostLabel(modelData)
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11 + Theme.fontSizeDelta
                                                    color: Theme.textDim
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Rectangle {
                                                visible: !sessionRow.canEnd
                                                Layout.preferredWidth: 30
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: Theme.fontIcons
                                                    font.pixelSize: 12 + Theme.fontSizeDelta
                                                    color: Theme.textDim
                                                }
                                            }

                                            Rectangle {
                                                visible: sessionRow.canEnd && sessionRow.terminating
                                                Layout.preferredWidth: 72
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "ending..."
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11 + Theme.fontSizeDelta
                                                    font.weight: Font.DemiBold
                                                    color: Theme.textDim
                                                }
                                            }

                                            Rectangle {
                                                visible: sessionRow.canEnd && sessionRow.pending && !sessionRow.terminating
                                                Layout.preferredWidth: 70
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: confirmHover.hovered ? Qt.rgba(1, 0.36, 0.32, 0.18) : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: confirmHover.hovered ? Qt.rgba(1, 0.48, 0.39, 0.20) : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Confirm"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11 + Theme.fontSizeDelta
                                                    font.weight: Font.DemiBold
                                                    color: confirmHover.hovered ? Theme.red : Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: confirmHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.sshService.confirmTerminate(modelData)
                                                }
                                            }

                                            Rectangle {
                                                visible: sessionRow.canEnd && sessionRow.pending && !sessionRow.terminating
                                                Layout.preferredWidth: 30
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: cancelHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: cancelHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: Theme.fontIcons
                                                    font.pixelSize: 12 + Theme.fontSizeDelta
                                                    color: Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: cancelHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.sshService.cancelTerminate()
                                                }
                                            }

                                            Rectangle {
                                                visible: sessionRow.canEnd && !sessionRow.pending && !sessionRow.terminating
                                                Layout.preferredWidth: 52
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: endHover.hovered ? Qt.rgba(1, 0.36, 0.32, 0.18) : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: endHover.hovered ? Qt.rgba(1, 0.48, 0.39, 0.20) : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "End"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 11 + Theme.fontSizeDelta
                                                    font.weight: Font.DemiBold
                                                    color: endHover.hovered ? Theme.red : Theme.textPrimary
                                                }

                                                HoverHandler {
                                                    id: endHover

                                                    blocking: false
                                                    cursorShape: Qt.PointingHandCursor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: !root.mutating
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.sshService.requestTerminate(modelData)
                                                }
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.hoverAnimDuration }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: Theme.hoverAnimDuration }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.lastError.length > 0 && root.sessions.length > 0
                            text: root.lastError
                            font.family: Theme.fontUi
                            font.pixelSize: 11 + Theme.fontSizeDelta
                            color: Theme.red
                            wrapMode: Text.WordWrap
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
