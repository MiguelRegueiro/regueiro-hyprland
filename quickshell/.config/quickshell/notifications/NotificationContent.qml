import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore
    required property var notif
    property bool compact: false
    property bool emphasizeCriticalSummary: false
    property string timestampText: ""
    signal dismissRequested()

    readonly property bool isCritical: notif !== null && notif.urgency === NotificationUrgency.Critical
    readonly property int iconSize: root.compact ? 28 : 34
    readonly property int closeSize: root.compact ? 24 : 28

    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: root.compact ? 8 : 10

        RowLayout {
            width: parent.width
            spacing: root.compact ? 8 : 10

            Rectangle {
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignTop
                radius: root.compact ? 10 : 12
                color: root.isCritical ? Qt.rgba(1, 0.48, 0.39, 0.12) : Theme.hoverBg
                border.width: 1
                border.color: root.isCritical ? Qt.rgba(1, 0.48, 0.39, 0.24) : Theme.qsEdgeSoft

                readonly property string iconOverride: root.notif
                    ? root.notificationStore.iconOverride(root.notif.appName, root.notif.appIcon) : ""

                Text {
                    anchors.centerIn: parent
                    visible: parent.iconOverride.length > 0 || !iconImage.visible
                    text: parent.iconOverride.length > 0 ? parent.iconOverride : "󰂚"
                    font.family: Theme.fontIcons
                    font.pixelSize: root.compact ? 12 : 15
                    color: root.isCritical ? Theme.red : Theme.textDim
                }

                Image {
                    id: iconImage
                    anchors.fill: parent
                    anchors.margins: 4
                    source: parent.iconOverride.length === 0 && root.notif && root.notif.appIcon.length > 0
                        ? ("image://icon/" + root.notif.appIcon) : ""
                    fillMode: Image.PreserveAspectFit
                    visible: parent.iconOverride.length === 0 && status === Image.Ready && source.toString().length > 0
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notif ? (root.notif.appName || "Notification") : ""
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: root.compact ? 11 : 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.timestampText.length > 0
                text: root.timestampText
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: root.compact ? 11 : 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: root.closeSize
                height: width
                radius: width / 2
                color: closeHover.hovered ? Theme.hoverBgStrong : Theme.hoverBg
                border.width: 1
                border.color: closeHover.hovered ? Theme.qsEdge : Theme.qsEdgeSoft

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: Theme.fontIcons
                    font.pixelSize: root.compact ? 9 : 10
                    color: Theme.textDim
                }

                HoverHandler {
                    id: closeHover
                    blocking: false
                }

                TapHandler {
                    onTapped: root.dismissRequested()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.notif ? root.notif.summary : ""
            color: root.emphasizeCriticalSummary && root.isCritical ? Theme.red : Theme.textPrimary
            font.family: Theme.fontUi
            font.pixelSize: root.compact ? 14 : 15
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: root.compact ? 2 : 3
            elide: Text.ElideRight
            visible: text.length > 0
        }

        Text {
            Layout.fillWidth: true
            text: root.notif ? root.notif.body : ""
            color: Theme.textDim
            font.family: Theme.fontUi
            font.pixelSize: root.compact ? 12 : 13
            wrapMode: Text.WordWrap
            maximumLineCount: root.compact ? 4 : 6
            elide: Text.ElideRight
            visible: text.length > 0
            textFormat: Text.StyledText
            lineHeight: 1.28
        }
    }
}
