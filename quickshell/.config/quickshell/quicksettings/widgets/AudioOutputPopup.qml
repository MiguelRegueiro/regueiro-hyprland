import QtQuick
import QtQuick.Controls.Basic
import "../../theme/Theme.js" as Theme

Item {
    id: popupRoot

    required property var audioService
    property real maxPopupHeight: 560
    signal sinkChosen()
    readonly property real listSpacing: 8
    readonly property real listFooterHeight: 4

    readonly property real cardHeight: headerContent.height + resolvedListHeight + 38
    readonly property real availableListHeight: Math.max(44, maxPopupHeight - headerContent.height - 32)

    implicitWidth: 362
    implicitHeight: cardHeight
    width: implicitWidth
    height: implicitHeight

    readonly property real maxListHeight: Math.min(550, availableListHeight)
    readonly property real idealListHeight: {
        if (!audioService || !audioService.sinks || audioService.sinks.length === 0)
            return 44

        let total = listFooterHeight
        for (let i = 0; i < audioService.sinks.length; ++i) {
            const sink = audioService.sinks[i]
            total += audioService.sinkSecondaryName(sink).length > 0 ? 56 : 48
            if (i > 0)
                total += listSpacing
        }
        return Math.max(44, total)
    }
    readonly property real resolvedListHeight: Math.min(maxListHeight, idealListHeight)

    Rectangle {
        id: popup
        x: 0
        y: 0
        width: parent.width
        height: popupRoot.cardHeight
        radius: Theme.qsRadius
        color: Theme.menuBg
        border.color: Theme.qsEdge
        border.width: 1
        clip: true

        Column {
            id: headerContent
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10

            Text {
                text: "Output Device"
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: popupRoot.audioService.currentSinkName.length > 0 ? popupRoot.audioService.currentSinkName : "No active output"
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.qsEdgeSoft
            }
        }

        ListView {
            id: sinkList
            anchors {
                top: headerContent.bottom
                topMargin: 10
                left: parent.left
                right: parent.right
                leftMargin: 14
                rightMargin: 14
            }
            height: popupRoot.resolvedListHeight
            model: popupRoot.audioService.sinks
            spacing: popupRoot.listSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                background: null
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.2)
                }
            }

            delegate: Rectangle {
                id: sinkRow
                required property var modelData

                readonly property bool active: popupRoot.audioService.currentSink
                    && popupRoot.audioService.currentSink.id === modelData.id
                readonly property string secondaryText: popupRoot.audioService.sinkSecondaryName(modelData)

                width: sinkList.width
                height: secondaryText.length > 0 ? 56 : 48
                radius: height / 2
                color: active
                    ? Theme.hoverBgStrong
                    : (rowHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg)
                border.color: active
                    ? Qt.rgba(1, 1, 1, 0.14)
                    : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.width: 1

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 10

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: active
                            ? Qt.rgba(1, 1, 1, 0.12)
                            : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05))

                        Text {
                            anchors.centerIn: parent
                            text: popupRoot.audioService.sinkIconText(modelData)
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
                            text: popupRoot.audioService.sinkDisplayName(modelData)
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
                    cursorShape: Qt.ArrowCursor
                    onClicked: {
                        popupRoot.audioService.setAudioSink(modelData)
                        popupRoot.sinkChosen()
                    }
                }

                HoverHandler {
                    id: rowHover
                    blocking: false
                    cursorShape: Qt.PointingHandCursor
                }
            }

            footer: Item {
                width: parent.width
                height: popupRoot.listFooterHeight
            }
        }

        Text {
            visible: popupRoot.audioService.sinks.length === 0
            anchors.centerIn: sinkList
            text: "No output devices found"
            color: Theme.textDim
            font.family: Theme.fontUi
            font.pixelSize: 11
        }
    }
}
