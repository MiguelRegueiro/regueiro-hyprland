import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var driveService
    property bool open: false
    property bool fullscreenActive: false
    readonly property real reveal: externalPanel.reveal
    readonly property var drives: driveService && driveService.drives ? driveService.drives : []
    readonly property string lastError: driveService && driveService.lastError ? driveService.lastError : ""
    readonly property bool loading: driveService && driveService.loading
    readonly property bool mutating: driveService && driveService.mutating
    readonly property real menuWidth: 320
    readonly property real menuRightMargin: 176
    readonly property real menuY: Theme.barHeight + 24
    readonly property real attachTop: Theme.qsContentPadding
    readonly property real surfaceOffsetY: -(1 - root.reveal) * 12
    readonly property real surfaceHeight: Math.max(68, Math.min(root.height - root.menuY - 10, menuColumn.implicitHeight + root.attachTop + 14))
    readonly property int openDuration: Theme.topBarMenuOpenDuration
    readonly property int closeDuration: Theme.topBarMenuCloseDuration

    signal closeRequested()
    signal barPressed(real x, real y)

    function routeBarPress(mouse) {
        if (mouse.button !== Qt.LeftButton || mouse.y < 0 || mouse.y >= Theme.barHeight)
            return false;

        root.barPressed(mouse.x, mouse.y);
        return true;
    }

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

    mask: Region {
        x: 0
        y: root.fullscreenActive ? 0 : Theme.barHeight
        width: root.open ? Math.round(root.width) : 0
        height: root.open ? Math.max(0, Math.round(root.height - (root.fullscreenActive ? 0 : Theme.barHeight))) : 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.open
        onPressed: (mouse) => {
            if (root.fullscreenActive && root.routeBarPress(mouse))
                return ;

            root.closeRequested();
        }
    }

    Item {
        id: externalPanel

        property real reveal: 0
        property bool open: root.open

        visible: reveal > 0.001
        x: Math.max(8, root.width - root.menuWidth - root.menuRightMargin)
        y: root.menuY
        width: root.menuWidth
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
                externalPanel.reveal: 1
            }

        }

        Item {
            id: motionFrame

            width: externalPanel.width
            height: Math.max(1, externalPanel.height)
            y: 0
            layer.enabled: true

                Item {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(1, root.menuWidth)
                    height: Math.max(1, externalPanel.height)
                    clip: true

                    Item {
                        id: frame

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.menuWidth
                    height: externalPanel.height
                    transform: Translate {
                        y: root.surfaceOffsetY
                    }


                Rectangle {
                    anchors.fill: parent
                    radius: Theme.ncSurfaceBottomLeftRadius
                    color: Theme.qsSurfaceBg
                    border.width: 2
                    border.color: Theme.bottomPanelOutline
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
                                    Layout.fillWidth: true
                                    implicitHeight: 110
                                    radius: Theme.qsRadius + 1
                                    color: Theme.qsCardBg
                                    border.width: 1
                                    border.color: Theme.qsCardBorder

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: modelData.mounted ? Qt.rgba(1, 1, 1, 0.10) : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: modelData.mounted ? Qt.rgba(1, 1, 1, 0.12) : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: Theme.fontIcons
                                                    font.pixelSize: 17
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
                                                    font.pixelSize: 15
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
                                                    font.pixelSize: 12
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
                                                Layout.preferredHeight: 30
                                                radius: 10
                                                color: openHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: openHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Open"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 12
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
                                                Layout.preferredHeight: 30
                                                radius: 10
                                                color: mountHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: mountHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Mount"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 12
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
                                                Layout.preferredHeight: 30
                                                radius: 10
                                                color: unmountHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: unmountHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Unmount"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 12
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
                                                Layout.preferredHeight: 30
                                                radius: 10
                                                color: ejectHover.hovered ? Qt.rgba(1, 0.36, 0.32, 0.18) : Theme.qsCardChipBg
                                                border.width: 1
                                                border.color: ejectHover.hovered ? Qt.rgba(1, 0.48, 0.39, 0.20) : Theme.qsCardChipBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Eject"
                                                    font.family: Theme.fontUi
                                                    font.pixelSize: 12
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
            shadowColor: Qt.rgba(0, 0, 0, 0.96)
            shadowBlur: 0.72
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
            blurMax: 28
        }

    }

}

}
