import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var notificationStore
    required property var notif
    property bool compact: false
    property bool minimalChrome: false
    property string timestampText: ""
    readonly property bool isCritical: notif !== null && notif.urgency === NotificationUrgency.Critical
    readonly property string imageSource: notificationImageSource()
    readonly property bool hasImage: imageSource.length > 0
    readonly property int imageSize: !hasImage ? 0 : (root.minimalChrome ? Theme.notificationImageMinimalSize : (root.compact ? Theme.notificationImageCompactSize : Theme.notificationImageSize))
    readonly property int iconSize: root.minimalChrome ? 26 : (root.compact ? 28 : 34)
    readonly property int closeSize: root.minimalChrome ? 18 : (root.compact ? 24 : 28)

    signal dismissRequested()

    function notificationImageSource() {
        if (!root.notif || !root.notif.image)
            return "";

        const source = String(root.notif.image);
        if (source.length === 0)
            return "";

        if (source.startsWith("/") || source.startsWith("~"))
            return "file://" + source;

        return source;
    }

    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn

        width: parent.width
        spacing: root.minimalChrome ? 8 : (root.compact ? 8 : 10)

        RowLayout {
            width: parent.width
            spacing: root.minimalChrome ? 8 : (root.compact ? 8 : 10)

            Rectangle {
                readonly property string iconOverride: root.notif ? root.notificationStore.iconOverride(root.notif.appName, root.notif.appIcon) : ""

                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignTop
                radius: root.minimalChrome ? 8 : (root.compact ? 10 : 12)
                color: root.minimalChrome ? "transparent" : (root.isCritical ? Theme.urgentBg : Theme.hoverBg)
                border.width: root.minimalChrome ? 0 : 1
                border.color: root.isCritical ? Theme.urgentBorder : Theme.qsEdgeSoft

                Text {
                    anchors.centerIn: parent
                    visible: parent.iconOverride.length > 0 || !iconImage.visible
                    text: parent.iconOverride.length > 0 ? parent.iconOverride : "󰂚"
                    font.family: Theme.fontIcons
                    font.pixelSize: root.minimalChrome ? 14 : (root.compact ? 12 : 15)
                    color: root.isCritical ? Theme.urgentAccent : Theme.textDim
                }

                Image {
                    id: iconImage

                    anchors.fill: parent
                    anchors.margins: 4
                    source: parent.iconOverride.length === 0 && root.notif && root.notif.appIcon.length > 0 ? ("image://icon/" + root.notif.appIcon) : ""
                    fillMode: Image.PreserveAspectFit
                    visible: parent.iconOverride.length === 0 && status === Image.Ready && source.toString().length > 0
                }

            }

            Text {
                Layout.fillWidth: true
                text: root.notif ? (root.notif.appName || "Notification") : ""
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: root.minimalChrome ? 12 : (root.compact ? 11 : 12)
                font.weight: Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: root.timestampText.length > 0
                text: root.timestampText
                color: Theme.textDim
                font.family: Theme.fontUi
                font.pixelSize: root.minimalChrome ? 12 : (root.compact ? 11 : 12)
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            Item {
                width: root.closeSize
                height: width
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: "󰅖"
                    font.family: Theme.fontIcons
                    font.pixelSize: root.minimalChrome ? 11 : (root.compact ? 9 : 10)
                    color: closeHover.hovered ? Theme.textPrimary : Theme.textDim
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

        RowLayout {
            Layout.fillWidth: true
            spacing: root.hasImage ? (root.minimalChrome ? 10 : 12) : 0

            Rectangle {
                id: imagePreview

                Layout.preferredWidth: root.hasImage ? root.imageSize : 0
                Layout.preferredHeight: root.hasImage ? root.imageSize : 0
                Layout.alignment: Qt.AlignTop
                visible: root.hasImage
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.imageSource
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: root.minimalChrome ? 6 : 7

                Text {
                    Layout.fillWidth: true
                    text: root.notif ? root.notif.summary : ""
                    color: Theme.textPrimary
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
                    maximumLineCount: root.compact ? 3 : 5
                    elide: Text.ElideRight
                    visible: text.length > 0
                    textFormat: Text.StyledText
                    lineHeight: 1.28
                }

            }

        }

    }

}
