import QtQuick
import QtQuick.Layouts
import Quickshell
import "../quicksettings/pages" as Pages
import "../quicksettings/QuickSettingsStyle.js" as QS
import "../theme/Theme.js" as Theme

FloatingWindow {
    id: root

    required property var displayService
    required property var powerService
    property var targetScreen: null
    property bool open: false
    property string page: "displays"
    signal closeRequested

    screen: targetScreen
    visible: open
    title: "Quickshell Settings"
    implicitWidth: 1060
    implicitHeight: 720
    minimumSize: Qt.size(900, 650)
    color: "transparent"

    onClosed: closeRequested()

    onOpenChanged: {
        if (open)
            Qt.callLater(() => escapeInput.forceActiveFocus());
    }

    TextInput {
        id: escapeInput
        width: 1
        height: 1
        opacity: 0
        focus: root.open
        inputMethodHints: Qt.ImhNoPredictiveText
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }
        onTextChanged: clear()
    }

    Rectangle {
        id: window

        anchors.fill: parent
        color: QS.surfaceBg

        RowLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 238
                color: Qt.rgba(0.06, 0.07, 0.09, 0.90)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Settings"
                            font.family: Theme.fontUi
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: root.startSystemMove()
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.preferredHeight: 44
                        radius: 10
                        color: root.page === "displays" ? Qt.rgba(0.20, 0.40, 0.74, displayNavHover.hovered ? 0.58 : 0.48)
                                                        : displayNavHover.hovered ? QS.cardBgHover : QS.cardBg
                        border.width: 1
                        border.color: root.page === "displays" ? Qt.rgba(0.40, 0.59, 0.89, 0.46)
                                                               : displayNavHover.hovered ? QS.cardBorderHover : QS.cardBorder
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; spacing: 10
                            Text { text: "󰍹"; font.family: Theme.fontIcons; font.pixelSize: 18; color: Theme.textPrimary }
                            Text { text: "Displays"; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                        }
                        HoverHandler { id: displayNavHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "displays" }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: root.page === "power" ? Qt.rgba(0.20, 0.40, 0.74, powerNavHover.hovered ? 0.58 : 0.48)
                                                     : powerNavHover.hovered ? QS.cardBgHover : QS.cardBg
                        border.width: 1
                        border.color: root.page === "power" ? Qt.rgba(0.40, 0.59, 0.89, 0.46)
                                                            : powerNavHover.hovered ? QS.cardBorderHover : QS.cardBorder
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; spacing: 10
                            Text { text: "󰂄"; font.family: Theme.fontIcons; font.pixelSize: 18; color: Theme.textPrimary }
                            Text { text: "Power"; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                        }
                        HoverHandler { id: powerNavHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "power" }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                Layout.topMargin: 24
                Layout.bottomMargin: 24
                spacing: root.page === "power" ? 0 : 6

                Text { text: root.page === "power" ? "Power" : "Displays"; font.family: Theme.fontUi; font.pixelSize: 25; font.weight: Font.DemiBold; color: Theme.textPrimary }
                Pages.DisplaysPage {
                    visible: root.page === "displays"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    displayService: root.displayService
                    showHeader: false
                    showAdvanced: true
                    onBackClicked: root.closeRequested()
                }
                Pages.PowerPage {
                    visible: root.page === "power"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    powerService: root.powerService
                }
            }
        }
    }
}
