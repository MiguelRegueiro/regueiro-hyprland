import QtQuick
import QtQuick.Layouts
import "../../components" as Components
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS
import "../widgets" as Widgets

FocusScope {
    id: root

    property bool wifiOn: wifiCtrl.wifiOn
    property string connectedSsid: wifiCtrl.connectedSsid
    property bool needsFocus: wifiCtrl.needsFocus
    required property var wifiService
    required property real popupSurfaceOriginX
    required property real popupSurfaceOriginY
    required property var targetScreen
    property bool menuOpen: false
    property real bottomViewportInset: 0
    property bool passwordPopupReady: false

    signal backClicked

    Layout.fillWidth: true
    implicitHeight: 460 + bottomViewportInset
    onMenuOpenChanged: {
        wifiCtrl.onMenuOpen(menuOpen);
        if (menuOpen)
            passwordPopupDelay.restart();
        else {
            passwordPopupDelay.stop();
            passwordPopupReady = false;
        }
    }

    WifiController {
        id: wifiCtrl

        wifiService: root.wifiService
    }

    Timer {
        id: passwordPopupDelay

        interval: Theme.qsPageSlideDuration + 30
        repeat: false
        onTriggered: root.passwordPopupReady = true
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
            color: QS.cardBg
            border.width: 1
            border.color: QS.cardBorder
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
                    color: hovered ? QS.chipBgHover : "transparent"
                    border.width: hovered ? 1 : 0
                    border.color: QS.chipBorderHover

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

                Components.WifiIcon {
                    height: 18
                    connected: wifiCtrl.wifiOn
                    iconColor: Theme.accent
                    inactiveColor: Theme.textDim
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 18
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
                    color: wifiCtrl.wifiOn ? QS.tileActiveBg : QS.chipBg
                    border.width: 1
                    border.color: wifiCtrl.wifiOn ? QS.tileActiveBorder : QS.chipBorder

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
            Layout.preferredHeight: 8
            z: 3
        }

        WifiStatusPill {
            id: outerPill

            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(col.width - 24, outerPill.implicitWidth)
            Layout.preferredHeight: active ? 28 : 0
            active: !wifiCtrl.promptOpen() && wifiCtrl.showStatus
            visible: active
            connecting: wifiCtrl.connecting
            message: wifiCtrl.statusText()
        }

        Item {
            Layout.preferredHeight: outerPill.active ? 8 : 0
            z: 3
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            WifiNetworkList {
                id: networkList

                width: parent.width
                height: Math.max(0, Math.floor((parent.height + rowSpacing) / (rowHeight + rowSpacing)) * (rowHeight + rowSpacing) - rowSpacing)
                controller: wifiCtrl
                z: 1
            }
        }
    }

    Widgets.QuickSettingsPopupSurface {
        id: passwordSurface

        readonly property bool promptOpen: wifiCtrl.connectSsid !== "" && wifiCtrl.connectSecure
        surfaceX: root.popupSurfaceOriginX + 26
        surfaceY: root.popupSurfaceOriginY + 72
        targetScreen: root.targetScreen
        surfaceNamespace: "qs-wifi-password"
        open: root.menuOpen && root.passwordPopupReady && promptOpen
        keyboardFocus: open
        width: 348
        height: passwordPrompt.height

        WifiPasswordPrompt {
            id: passwordPrompt

            width: parent.width
            controller: wifiCtrl
            embeddedInPopup: true
            popupOpen: passwordSurface.open
        }
    }
}
