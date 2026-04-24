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

    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: root.compact ? 3 : 4

        RowLayout {
            width: parent.width
            spacing: 6

            Item {
                Layout.preferredWidth: root.compact ? 16 : 18
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter

                readonly property string iconOverride: root.notif
                    ? root.notificationStore.iconOverride(root.notif.appName, root.notif.appIcon) : ""

                Text {
                    anchors.centerIn: parent
                    visible: parent.iconOverride.length > 0 || !iconImage.visible
                    text: parent.iconOverride.length > 0 ? parent.iconOverride : "󰂚"
                    font.family: Theme.fontIcons
                    font.pixelSize: root.compact ? 12 : 14
                    color: Theme.textDim
                }

                Image {
                    id: iconImage
                    anchors.fill: parent
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
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                visible: root.timestampText.length > 0
                text: root.timestampText
                color: Theme.textDisabled
                font.family: Theme.fontUi
                font.pixelSize: 10
            }

            Rectangle {
                width: root.compact ? 20 : 22
                height: width
                radius: width / 2
                color: closeHover.hovered ? Theme.hoverBgStrong : "transparent"

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
            font.pixelSize: 14
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: text.length > 0
        }

        Text {
            Layout.fillWidth: true
            text: root.notif ? root.notif.body : ""
            color: Theme.textDim
            font.family: Theme.fontUi
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            maximumLineCount: 5
            elide: Text.ElideRight
            visible: text.length > 0
            textFormat: Text.StyledText
            lineHeight: 1.25
        }
    }
}
