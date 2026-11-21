import QtQuick
import QtQuick.Layouts
import Quickshell
import "../quicksettings/pages" as Pages
import "../theme/Theme.js" as Theme

FloatingWindow {
    id: root

    required property var displayService
    property var targetScreen: null
    property bool open: false
    signal closeRequested

    screen: targetScreen
    visible: open
    title: "Quickshell Settings"
    implicitWidth: 1060
    implicitHeight: 760
    minimumSize: Qt.size(900, 700)
    color: "#181b20"

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
        color: "#181b20"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 238
                color: Qt.rgba(0.04, 0.05, 0.07, 0.54)

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
                    Text { text: "SYSTEM"; font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.textDisabled }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: Qt.rgba(0.28, 0.45, 0.79, 0.42)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; spacing: 10
                            Text { text: "󰍹"; font.family: Theme.fontIcons; font.pixelSize: 18; color: "white" }
                            Text { text: "Displays"; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: "white" }
                        }
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
                spacing: 6

                Text { text: "Displays"; font.family: Theme.fontUi; font.pixelSize: 25; font.weight: Font.DemiBold; color: Theme.textPrimary }
                Text { text: "Arrange and configure connected displays"; font.family: Theme.fontUi; font.pixelSize: 12; color: Theme.textDim }
                Pages.DisplaysPage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    displayService: root.displayService
                    showHeader: false
                    onBackClicked: root.closeRequested()
                }
            }
        }
    }
}
