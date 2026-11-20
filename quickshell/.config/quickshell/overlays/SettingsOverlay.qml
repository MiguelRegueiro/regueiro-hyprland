import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../quicksettings/pages" as Pages
import "../theme/Theme.js" as Theme
import "../quicksettings/QuickSettingsStyle.js" as QS

PanelWindow {
    id: root

    required property var displayService
    required property var targetScreen
    property bool open: false
    signal closeRequested

    screen: targetScreen
    visible: open
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }

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

    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            // Rectangle and layout backgrounds do not consume mouse events.
            // Only a click outside the actual settings window dismisses it.
            if (mouse.x < window.x || mouse.x >= window.x + window.width ||
                mouse.y < window.y || mouse.y >= window.y + window.height)
                root.closeRequested();
        }
    }

    Rectangle {
        id: window

        width: Math.min(1060, parent.width - 64)
        height: Math.min(760, parent.height - 72)
        anchors.centerIn: parent
        radius: 24
        color: Qt.rgba(0.095, 0.105, 0.125, 0.94)
        border.width: 1
        border.color: QS.edge

        RowLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 238
                radius: 24
                color: Qt.rgba(0.04, 0.05, 0.07, 0.54)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Settings"; font.family: Theme.fontUi; font.pixelSize: 20; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Item { Layout.fillWidth: true }
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
