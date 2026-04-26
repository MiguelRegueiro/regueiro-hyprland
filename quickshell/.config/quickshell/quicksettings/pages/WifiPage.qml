import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme

FocusScope {
    id: root

    property bool wifiOn: wifiCtrl.wifiOn
    property string connectedSsid: wifiCtrl.connectedSsid
    property bool needsFocus: wifiCtrl.needsFocus
    required property var wifiService
    property bool menuOpen: false

    signal backClicked()

    Layout.fillWidth: true
    implicitHeight: 460
    onMenuOpenChanged: wifiCtrl.onMenuOpen(menuOpen)

    WifiController {
        id: wifiCtrl

        wifiService: root.wifiService
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: header

            Layout.fillWidth: true
            height: 52
            radius: 18
            color: Theme.qsCardBg
            border.width: 1
            border.color: Theme.qsCardBorder
            z: 3

            RowLayout {
                spacing: 0

                anchors {
                    fill: parent
                    leftMargin: 4
                    rightMargin: 8
                }

                Rectangle {
                    readonly property bool hovered: backHover.hovered

                    width: 44
                    height: 44
                    radius: 22
                    color: hovered ? Theme.qsCardChipBgHover : "transparent"
                    border.width: hovered ? 1 : 0
                    border.color: Theme.qsCardChipBorderHover

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: Theme.fontIcons
                        font.pixelSize: 18
                        color: Theme.textPrimary
                    }

                    HoverHandler {
                        id: backHover

                        blocking: false
                        cursorShape: Qt.ArrowCursor
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.backClicked()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }

                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 110
                        }

                    }

                }

                Item {
                    width: 8
                }

                Text {
                    text: wifiCtrl.wifiOn ? "󰤨" : "󰤭"
                    font.family: Theme.fontIcons
                    font.pixelSize: 18
                    color: wifiCtrl.wifiOn ? Theme.accent : Theme.textDim
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Item {
                    width: 6
                }

                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                Rectangle {
                    width: 48
                    height: 26
                    radius: 13
                    color: wifiCtrl.wifiOn ? Theme.tileActiveBg : Theme.qsCardChipBg
                    border.width: 1
                    border.color: wifiCtrl.wifiOn ? Theme.tileActiveBorder : Theme.qsCardChipBorder

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: wifiCtrl.wifiOn ? parent.width - width - 3 : 3

                        Behavior on x {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.ArrowCursor
                        z: 2
                        onClicked: wifiCtrl.toggle()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }

                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 80
                        }

                    }

                }

            }

        }

        Item {
            height: 8
            z: 3
        }

        WifiStatusPill {
            id: outerPill

            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(col.width - 24, outerPill.implicitWidth)
            Layout.preferredHeight: 28
            active: !wifiCtrl.promptOpen() && wifiCtrl.showStatus
            connecting: wifiCtrl.connecting
            message: wifiCtrl.statusText()
        }

        Item {
            height: 8
            z: 3
        }

        WifiPasswordPrompt {
            visible: wifiCtrl.connectSsid !== "" && wifiCtrl.connectSecure
            controller: wifiCtrl
            z: 5
        }

        Item {
            height: wifiCtrl.connectSsid !== "" && wifiCtrl.connectSecure ? 12 : 0
            z: 3
        }

        WifiNetworkList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            controller: wifiCtrl
            z: 1
        }

    }

}
