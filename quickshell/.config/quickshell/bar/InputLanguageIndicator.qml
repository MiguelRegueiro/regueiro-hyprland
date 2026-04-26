import QtQuick
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var inputService
    property int barHeight: 34
    readonly property bool hovered: triggerHover.hovered
    readonly property bool backendError: inputService.hasBackendError
    readonly property bool configWarning: inputService.hasConfigurationWarning
    readonly property color triggerColor: {
        if (backendError)
            return Qt.rgba(1, 0.48, 0.39, hovered ? 0.18 : 0.1);

        if (configWarning)
            return Qt.rgba(0.97, 0.89, 0.36, hovered ? 0.18 : 0.1);

        return hovered ? Theme.hoverBg : "transparent";
    }
    readonly property color triggerBorderColor: {
        if (backendError)
            return Qt.rgba(1, 0.48, 0.39, hovered ? 0.3 : 0.2);

        if (configWarning)
            return Qt.rgba(0.97, 0.89, 0.36, hovered ? 0.28 : 0.18);

        return "transparent";
    }
    readonly property color labelColor: backendError ? Theme.red : (configWarning ? Theme.yellow : Theme.textPrimary)
    readonly property bool showTooltip: hovered && (inputService.statusTitle.length > 0 || inputService.statusDetail.length > 0)

    height: barHeight - 8
    implicitWidth: trigger.implicitWidth
    implicitHeight: height

    Rectangle {
        id: trigger

        height: parent.height
        implicitWidth: Math.max(label.implicitWidth + 16, 36)
        radius: Theme.radiusSmall
        color: root.triggerColor
        border.width: root.backendError || root.configWarning ? 1 : 0
        border.color: root.triggerBorderColor

        Text {
            id: label

            anchors.centerIn: parent
            text: inputService.indicatorLabel
            color: root.labelColor
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.Bold
            font.letterSpacing: 0.5
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

    HoverHandler {
        id: triggerHover

        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: {
            if (inputService.canCycle)
                inputService.cycleNext();
            else
                inputService.refresh();
        }
    }

    Rectangle {
        id: tooltip

        visible: opacity > 0.001 || root.showTooltip
        opacity: root.showTooltip ? 1 : 0
        z: 50
        y: root.height + 8
        width: 220
        radius: 10
        color: Theme.popupBg
        border.width: 1
        border.color: root.backendError ? Qt.rgba(1, 0.48, 0.39, 0.24) : (root.configWarning ? Qt.rgba(0.97, 0.89, 0.36, 0.22) : Theme.barBorder)
        anchors.right: trigger.right
        implicitHeight: tooltipContent.implicitHeight + 18

        Column {
            id: tooltipContent

            spacing: 4

            anchors {
                fill: parent
                margins: 10
            }

            Text {
                width: parent.width
                text: inputService.statusTitle
                color: root.backendError ? Theme.red : (root.configWarning ? Theme.yellow : Theme.textPrimary)
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                visible: inputService.statusDetail.length > 0
                text: inputService.statusDetail
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: 12
                lineHeight: 1.22
                wrapMode: Text.WordWrap
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }

        }

    }

}
