import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Rectangle {
    id: root

    required property var controller
    property bool embeddedInPopup: false
    property bool popupOpen: false

    Layout.fillWidth: true
    height: visible ? passContent.implicitHeight + 24 : 0
    radius: 18
    color: embeddedInPopup ? "transparent" : QS.popupSurfaceBg
    border.color: QS.popupSurfaceOutline
    border.width: embeddedInPopup ? 0 : 1
    clip: true

    Connections {
        function onPasswordClearRequested() {
            passField.text = "";
        }

        function onPasswordFocusRequested() {
            passField.forceActiveFocus();
        }

        target: root.controller
    }

    onPopupOpenChanged: {
        if (popupOpen)
            popupFocusDelay.restart();
    }

    Timer {
        id: popupFocusDelay

        interval: 40
        repeat: false
        onTriggered: passField.forceActiveFocus()
    }

    ColumnLayout {
        id: passContent

        spacing: 10

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14
            rightMargin: 14
            topMargin: 12
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: "Password Required"
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Text {
                Layout.fillWidth: true
                text: root.controller.connectSsid
                font.family: Theme.fontUi
                font.pixelSize: 11
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 14
            color: QS.cardBg
            border.color: passField.activeFocus ? QS.tileActiveBorderHover : QS.cardBorder
            border.width: 1

            TextInput {
                id: passField

                font.family: Theme.fontUi
                font.pixelSize: 13
                color: Theme.textPrimary
                selectionColor: Theme.accent
                selectedTextColor: Theme.textPrimary
                echoMode: root.controller.showPassword ? TextInput.Normal : TextInput.Password
                focus: root.controller.connectSsid !== "" && root.controller.connectSecure
                cursorVisible: activeFocus
                selectByMouse: true
                activeFocusOnPress: true
                clip: true
                onTextEdited: {
                    if (!root.controller.connecting)
                        root.controller.connectError = "";
                }
                Keys.onReturnPressed: {
                    event.accepted = true;
                    root.controller.doConnect(text);
                }
                Keys.onEnterPressed: {
                    event.accepted = true;
                    root.controller.doConnect(text);
                }
                Keys.onEscapePressed: {
                    event.accepted = true;
                    root.controller.cancel();
                }

                anchors {
                    left: parent.left
                    right: eyeButton.left
                    leftMargin: 12
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
            }

            Text {
                visible: passField.text.length === 0
                text: "Enter Wi-Fi password"
                font.family: Theme.fontUi
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.42)

                anchors {
                    left: passField.left
                    verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: eyeButton

                width: 28
                height: 28
                radius: 14
                color: eyeHover.hovered ? Theme.hoverBgStrong : "transparent"
                border.width: eyeHover.hovered ? 1 : 0
                border.color: QS.chipBorderHover

                anchors {
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.centerIn: parent
                    text: root.controller.showPassword ? "" : ""
                    font.family: Theme.fontIcons
                    font.pixelSize: 14
                    color: Theme.textDim
                }

                HoverHandler {
                    id: eyeHover

                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        root.controller.showPassword = !root.controller.showPassword;
                        passField.forceActiveFocus();
                    }
                }
            }
        }

        WifiStatusPill {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 28
            active: root.controller.showStatus
            connecting: root.controller.connecting
            message: root.controller.statusText()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 17
                color: cancelHover.hovered ? QS.cardBgHover : QS.cardBg
                border.width: 1
                border.color: cancelHover.hovered ? QS.cardBorderHover : QS.cardBorder

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }

                HoverHandler {
                    id: cancelHover

                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.controller.cancel()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 17
                opacity: root.controller.connecting ? 0.5 : 1
                color: connectHover.hovered && !root.controller.connecting ? QS.tileActiveBgHover : QS.tileActiveBg
                border.width: 1
                border.color: connectHover.hovered && !root.controller.connecting ? QS.tileActiveBorderHover : QS.tileActiveBorder

                Text {
                    anchors.centerIn: parent
                    text: root.controller.connecting ? "Connecting…" : "Connect"
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: "white"
                }

                HoverHandler {
                    id: connectHover

                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.controller.doConnect(passField.text)
                }
            }
        }
    }

}
