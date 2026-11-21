import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
pragma ComponentBehavior: Bound
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Rectangle {
    id: root

    required property string label
    required property string valueText
    required property var options
    property string currentValue: ""
    property bool busy: false
    property bool openBelow: false
    signal chosen(string value)

    Layout.fillWidth: true
    Layout.preferredHeight: 56
    color: QS.cardBg
    radius: 16
    border.width: 1
    border.color: QS.cardBorder

    onVisibleChanged: if (!visible) menu.close()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: root.label
            color: Theme.textPrimary
            font.family: Theme.fontUi
            font.pixelSize: 13
        }
        Rectangle {
            Layout.preferredWidth: 194
            Layout.preferredHeight: 38
            radius: 10
            color: hover.hovered ? QS.chipBgHover : QS.chipBg
            border.width: 1
            border.color: hover.hovered ? QS.chipBorderHover : QS.chipBorder

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 48
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.valueText
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Canvas {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 8
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.strokeStyle = Theme.textDim;
                    ctx.lineWidth = 1.7;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(1.5, 2);
                    ctx.lineTo(6, 6);
                    ctx.lineTo(10.5, 2);
                    ctx.stroke();
                }
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                enabled: !root.busy && root.options.length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.open()
            }
        }
    }

    Controls.Popup {
        id: menu
        parent: root
        x: root.width - width - 10
        y: root.openBelow ? root.height + 6 : -height - 6
        width: 210
        height: Math.min(288, root.options.length * 40 + 12)
        padding: 6
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: "#282c34"
            border.width: 1
            border.color: QS.cardBorderHover
        }
        contentItem: ListView {
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                readonly property bool selected: String(modelData.value) === root.currentValue
                width: ListView.view.width
                height: 40
                radius: 8
                color: selected ? Qt.rgba(0.24, 0.39, 0.69, 0.68)
                                : optionHover.hovered ? QS.chipBgHover : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.selected
                    text: "✓"
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }
                HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menu.close();
                        if (!parent.selected)
                            root.chosen(String(parent.modelData.value));
                    }
                }
            }
        }
    }
}
