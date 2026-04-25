import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../theme/Theme.js" as Theme

// Slider row: [icon]  [label]  [slider]  [mute button]
Item {
    id: row

    Layout.fillWidth: true
    height: 56

    property string iconText: "󰕾"
    property Component iconOverride: null
    property string label: ""
    property real value: 1.0       // 0.0–1.0
    property bool muted: false
    property bool showMute: true
    property bool showActionButton: false
    property bool actionButtonActive: false
    property string actionIconText: "󰅂"
    property real actionIconOffsetX: 0
    property real backgroundRadius: Theme.radiusSmall
    property int emitInterval: 36
    readonly property bool showLabel: label.length > 0
    readonly property bool dragging: slider.pressed
    readonly property bool hovered: rowHover.hovered
    property real _displayValue: 0
    property real _pendingValue: 0

    signal sliderMoved(real val)
    signal muteClicked()
    signal actionClicked()

    function clampValue(val) {
        return Math.max(0, Math.min(1, val));
    }

    function syncFromSource() {
        if (!slider.pressed)
            row._displayValue = row.muted ? 0 : row.clampValue(row.value);
    }

    onValueChanged: syncFromSource()
    onMutedChanged: syncFromSource()

    Component.onCompleted: syncFromSource()

    Timer {
        id: emitTimer

        interval: row.emitInterval
        repeat: false
        onTriggered: row.sliderMoved(row._pendingValue)
    }

    Rectangle {
        anchors.fill: parent
        radius: row.backgroundRadius
        color: row.dragging || row.hovered ? Theme.qsCardBgHover : Theme.qsCardBg
        border.width: 1
        border.color: row.dragging || row.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder

        Behavior on color {
            ColorAnimation { duration: Theme.hoverAnimDuration }
        }

        Behavior on border.color {
            ColorAnimation { duration: Theme.hoverAnimDuration }
        }
    }

    HoverHandler {
        id: rowHover
        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 12

        // Icon / mute button
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: muteBtnMouse.containsMouse && row.showMute
                ? Theme.qsCardChipBgHover
                : Theme.qsCardChipBg
            border.width: 1
            border.color: muteBtnMouse.containsMouse && row.showMute
                ? Theme.qsCardChipBorderHover
                : Theme.qsCardChipBorder

            Behavior on color {
                ColorAnimation { duration: Theme.hoverAnimDuration }
            }

            Behavior on border.color {
                ColorAnimation { duration: Theme.hoverAnimDuration }
            }

            Loader {
                anchors.centerIn: parent
                sourceComponent: row.iconOverride !== null ? row.iconOverride : defaultIcon
            }

            Component {
                id: defaultIcon
                Text {
                    text: row.iconText
                    font.family: Theme.fontIcons
                    font.pixelSize: 16
                    color: row.muted ? Theme.textDisabled : Theme.textPrimary
                }
            }

            MouseArea {
                id: muteBtnMouse
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                visible: row.showMute
                hoverEnabled: true
                onClicked: row.muteClicked()
            }
        }

        // Label + slider
        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: contentCol.implicitHeight

            Column {
                id: contentCol

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: row.showLabel ? 4 : 0

                Text {
                    visible: row.showLabel
                    text: row.label
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: parent.width
                }

                Slider {
                    id: slider
                    width: parent.width
                    height: 24
                    from: 0; to: 1
                    live: true
                    value: row._displayValue
                    enabled: !row.muted

                    background: Rectangle {
                        x: slider.leftPadding
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: slider.availableWidth
                        height: 8
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.14)

                        Rectangle {
                            width: slider.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: row.muted ? Qt.rgba(1, 1, 1, 0.25) : Theme.accent
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }

                    handle: Rectangle {
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: 18; height: 18; radius: 9
                        color: "white"
                        opacity: 1.0
                    }

                    onMoved: {
                        row._displayValue = row.clampValue(value);
                        row._pendingValue = row._displayValue;
                        emitTimer.restart();
                    }

                    onValueChanged: {
                        if (!slider.pressed)
                            return;

                        row._displayValue = row.clampValue(value);
                        row._pendingValue = row._displayValue;
                        emitTimer.restart();
                    }

                    onPressedChanged: {
                        if (slider.pressed)
                            return;

                        emitTimer.stop();
                        row.sliderMoved(row._displayValue);
                    }
                }
            }
        }

        Rectangle {
            visible: row.showActionButton
            Layout.preferredWidth: row.showActionButton ? 30 : 0
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: row.actionButtonActive
                ? Theme.qsCardChipBgHover
                : (actionHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg)
            border.width: 1
            border.color: row.actionButtonActive
                ? Theme.qsCardChipBorderHover
                : (actionHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder)

            Behavior on color {
                ColorAnimation { duration: Theme.hoverAnimDuration }
            }

            Behavior on border.color {
                ColorAnimation { duration: Theme.hoverAnimDuration }
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: row.actionIconOffsetX
                text: row.actionIconText
                font.family: Theme.fontIcons
                font.pixelSize: 15
                color: row.actionButtonActive ? Theme.textPrimary : Theme.textDim
            }

            HoverHandler {
                id: actionHover
                blocking: false
                cursorShape: Qt.ArrowCursor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onClicked: row.actionClicked()
            }
        }
    }
}
