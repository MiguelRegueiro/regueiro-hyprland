import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme

Rectangle {
    id: root

    required property var controller

    Layout.fillWidth: true
    height: visible ? passContent.implicitHeight + 24 : 0
    radius: 18
    color: Theme.popupBg
    border.color: Qt.rgba(1, 1, 1, 0.11)
    border.width: 1
    clip: true

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Connections {
        target: root.controller
        function onPasswordClearRequested() { passField.text = "" }
        function onPasswordFocusRequested() { passField.forceActiveFocus() }
    }

    ColumnLayout {
        id: passContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14
            rightMargin: 14
            topMargin: 12
        }
        spacing: 10

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
            color: Theme.qsCardBg
            border.color: passField.activeFocus ? Theme.tileActiveBorderHover : Theme.qsCardBorder
            border.width: 1

            TextInput {
                id: passField
                anchors {
                    left: parent.left
                    right: eyeButton.left
                    leftMargin: 12
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
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
                onTextEdited: if (!root.controller.connecting) root.controller.connectError = ""
                Keys.onReturnPressed: { event.accepted = true; root.controller.doConnect(text) }
                Keys.onEnterPressed:  { event.accepted = true; root.controller.doConnect(text) }
                Keys.onEscapePressed: { event.accepted = true; root.controller.cancel() }
            }

            Text {
                anchors {
                    left: passField.left
                    verticalCenter: parent.verticalCenter
                }
                visible: passField.text.length === 0
                text: "Enter Wi-Fi password"
                font.family: Theme.fontUi
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.42)
            }

            Rectangle {
                id: eyeButton
                width: 28
                height: 28
                radius: 14
                anchors {
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                color: eyeHover.hovered ? Theme.hoverBgStrong : "transparent"
                border.width: eyeHover.hovered ? 1 : 0
                border.color: Theme.qsCardChipBorderHover

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
                        root.controller.showPassword = !root.controller.showPassword
                        passField.forceActiveFocus()
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
                color: cancelHover.hovered ? Theme.qsCardBgHover : Theme.qsCardBg
                border.width: 1
                border.color: cancelHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder

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
                opacity: root.controller.connecting ? 0.5 : 1.0
                color: connectHover.hovered && !root.controller.connecting ? Theme.tileActiveBgHover : Theme.tileActiveBg
                border.width: 1
                border.color: connectHover.hovered && !root.controller.connecting ? Theme.tileActiveBorderHover : Theme.tileActiveBorder

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
