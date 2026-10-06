import QtQuick
import QtQuick.Controls.Basic
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Item {
    id: popupRoot

    required property var audioService
    required property real surfaceX
    required property real surfaceY
    required property var targetScreen
    property bool open: false
    property real maxPopupHeight: 560
    readonly property color rowBg: QS.cardBg
    readonly property color rowBgHover: QS.cardBgHover
    readonly property color rowBgActive: QS.cardActiveBg
    readonly property color rowBorder: QS.cardBorder
    readonly property color rowBorderHover: QS.cardBorderHover
    readonly property real listSpacing: 8
    readonly property real listFooterHeight: 8
    readonly property real cardHeight: resolvedListHeight + 24
    readonly property real availableListHeight: Math.max(44, maxPopupHeight - 24)
    readonly property real maxListHeight: Math.min(550, availableListHeight)
    readonly property real idealListHeight: {
        if (!audioService || !audioService.outputChoices || audioService.outputChoices.length === 0)
            return 44;

        let total = listFooterHeight;
        for (let i = 0; i < audioService.outputChoices.length; ++i) {
            const choice = audioService.outputChoices[i];
            total += audioService.outputSecondaryName(choice).length > 0 ? 56 : 48;
            if (i > 0)
                total += listSpacing;

        }
        return Math.max(44, total);
    }
    readonly property real resolvedListHeight: Math.min(maxListHeight, idealListHeight)

    signal sinkChosen()

    implicitWidth: 348
    implicitHeight: cardHeight
    width: implicitWidth
    height: implicitHeight
    QuickSettingsPopupSurface {
        id: popupSurface
        surfaceX: popupRoot.surfaceX
        surfaceY: popupRoot.surfaceY
        targetScreen: popupRoot.targetScreen
        surfaceNamespace: "qs-audio-output"
        open: popupRoot.open
        width: popupRoot.width
        height: popupRoot.cardHeight

        ListView {
            id: sinkList

            height: popupRoot.resolvedListHeight
            contentHeight: popupRoot.idealListHeight
            model: popupRoot.audioService.outputChoices
            spacing: popupRoot.listSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    // Match the launcher's immediate scrolling, scaled to these rows.
                    const delta = event.pixelDelta.y !== 0 ? -event.pixelDelta.y * 3.2 : -event.angleDelta.y / 120 * 64 * 0.9;
                    sinkList.cancelFlick();
                    const minY = sinkList.originY;
                    const maxY = minY + Math.max(0, sinkList.contentHeight - sinkList.height);
                    sinkList.contentY = Math.max(minY, Math.min(maxY, sinkList.contentY + delta));
                    event.accepted = true;
                }
            }

                anchors {
                    top: parent.top
                    topMargin: 12
                left: parent.left
                right: parent.right
                leftMargin: 14
                rightMargin: 14
            }

            ScrollBar.vertical: ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                background: null

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Qt.rgba(0.62, 0.64, 0.68, 0.48)
                }

            }

            delegate: Rectangle {
                id: sinkRow

                required property var modelData
                readonly property bool active: popupRoot.audioService.outputIsActive(modelData)
                readonly property bool selectable: popupRoot.audioService.outputSelectable(modelData)
                readonly property string secondaryText: popupRoot.audioService.outputSecondaryName(modelData)

                width: sinkList.width
                height: secondaryText.length > 0 ? 56 : 48
                radius: height / 2
                color: active ? popupRoot.rowBgActive : (rowHover.hovered ? popupRoot.rowBgHover : popupRoot.rowBg)
                border.color: active ? popupRoot.rowBorderHover : (rowHover.hovered ? popupRoot.rowBorderHover : popupRoot.rowBorder)
                border.width: 1
                opacity: selectable || active ? 1 : 0.48

                Row {
                    spacing: 10

                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: active ? popupRoot.rowBgActive : (rowHover.hovered ? popupRoot.rowBgHover : popupRoot.rowBg)
                        border.width: 1
                        border.color: active ? popupRoot.rowBorderHover : (rowHover.hovered ? popupRoot.rowBorderHover : popupRoot.rowBorder)

                        Text {
                            anchors.centerIn: parent
                            text: popupRoot.audioService.outputIconText(modelData)
                            font.family: Theme.fontIcons
                            font.pixelSize: 15
                            color: active ? Theme.textPrimary : Theme.textDim
                        }

                    }

                    Column {
                        width: parent.width - 72
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: secondaryText.length > 0 ? 2 : 0

                        Text {
                            width: parent.width
                            text: popupRoot.audioService.outputDisplayName(modelData)
                            color: active ? Theme.textPrimary : Theme.textPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: active ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: secondaryText.length > 0
                            width: parent.width
                            text: secondaryText
                            color: Theme.textDim
                            font.family: Theme.fontUi
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }

                    }

                }

                Rectangle {
                    visible: active
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.accent

                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    enabled: sinkRow.selectable
                    cursorShape: sinkRow.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    scrollGestureEnabled: false
                    onWheel: wheel => { wheel.accepted = false; }
                    onClicked: {
                        popupRoot.audioService.setAudioOutput(modelData);
                        popupRoot.sinkChosen();
                    }
                }

                HoverHandler {
                    id: rowHover

                    blocking: false
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.outputItemColorDuration
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.outputItemColorDuration
                    }

                }

            }

            footer: Item {
                width: parent.width
                height: popupRoot.listFooterHeight
            }

        }

        Text {
            visible: popupRoot.audioService.outputChoices.length === 0
            anchors.centerIn: sinkList
            text: "No output devices found"
            color: Theme.textDim
            font.family: Theme.fontUi
            font.pixelSize: 11
        }

    }
}
