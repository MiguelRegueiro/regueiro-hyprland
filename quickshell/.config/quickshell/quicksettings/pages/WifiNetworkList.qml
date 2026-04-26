import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../theme/Theme.js" as Theme

Flickable {
    id: root

    required property var controller

    contentHeight: listCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: listCol

        width: parent.width
        spacing: 4

        Repeater {
            model: root.controller.wifiOn ? root.controller.networks : []

            delegate: Rectangle {
                id: wifiRow

                required property var modelData
                readonly property bool secureNetwork: (modelData.security || "") !== ""
                readonly property bool selectedForPrompt: root.controller.connectSsid === modelData.ssid && root.controller.connectSecure
                readonly property bool rememberedProfile: root.controller.hasSavedProfile(modelData.ssid)
                readonly property bool savedProfile: !modelData.active && rememberedProfile
                readonly property bool showSecurityIcon: secureNetwork && !rememberedProfile && !modelData.active
                readonly property bool forgetPending: root.controller.forgetConfirmSsid === modelData.ssid
                readonly property bool forgetBusy: root.controller.forgetBusySsid === modelData.ssid
                readonly property bool forgetHasResult: root.controller.forgetResultSsid === modelData.ssid
                readonly property bool forgetOk: forgetHasResult && root.controller.forgetResultOk
                readonly property bool forgetActionVisible: rememberedProfile && (wifiHover.hovered || forgetPending || forgetBusy || forgetHasResult)

                Layout.fillWidth: true
                height: 52
                radius: 18
                color: modelData.active ? Qt.rgba(0.122, 0.122, 0.122, 0.98) : (selectedForPrompt ? Theme.qsCardBgHover : (wifiHover.hovered ? Theme.qsCardBgHover : Theme.qsCardBg))
                border.width: 1
                border.color: modelData.active ? Qt.rgba(1, 1, 1, 0.14) : (selectedForPrompt ? Theme.tileActiveBorder : (wifiHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder))

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    enabled: root.controller.forgetBusySsid === "" && !wifiRow.forgetPending && !wifiRow.forgetBusy && !wifiRow.forgetHasResult
                    onClicked: {
                        root.controller.forgetConfirmSsid = "";
                        if (root.controller.connecting)
                            return ;

                        if (modelData.active)
                            return ;

                        if ((modelData.security || "") !== "") {
                            if (root.controller.hasSavedProfile(modelData.ssid))
                                root.controller.connectSavedSecureNetwork(modelData);
                            else
                                root.controller.openPasswordPrompt(modelData.ssid, modelData.security);
                        } else {
                            root.controller.connectOpenNetwork(modelData.ssid);
                        }
                    }
                }

                RowLayout {
                    spacing: 10

                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: modelData.active ? Qt.rgba(1, 1, 1, 0.12) : (wifiHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg)
                        border.width: 1
                        border.color: modelData.active ? Qt.rgba(1, 1, 1, 0.12) : (wifiHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder)

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 0.5
                            anchors.verticalCenterOffset: 1
                            text: root.controller.sigIcon(modelData.signal || 0)
                            font.family: Theme.fontIcons
                            font.pixelSize: 15
                            color: modelData.active ? Theme.textPrimary : Theme.textDim
                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: modelData.ssid || ""
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: modelData.active ? Font.DemiBold : Font.Medium
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.controller.networkStatusText(modelData)
                            font.family: Theme.fontUi
                            font.pixelSize: 10
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }

                    }

                    Item {
                        z: 1
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: forgetActions.visible ? forgetActions.implicitWidth : (savedChip.visible ? savedChip.implicitWidth : 0)
                        implicitHeight: forgetActions.visible ? forgetActions.implicitHeight : (savedChip.visible ? savedChip.implicitHeight : 0)

                        RowLayout {
                            id: forgetActions

                            anchors.centerIn: parent
                            visible: wifiRow.forgetActionVisible
                            spacing: 6

                            Rectangle {
                                visible: wifiRow.forgetPending
                                implicitWidth: 60
                                implicitHeight: 30
                                radius: 15
                                color: Theme.qsCardChipBg
                                border.width: 1
                                border.color: Theme.qsCardChipBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.textPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    cursorShape: Qt.ArrowCursor
                                    onClicked: root.controller.cancelForget(wifiRow.modelData.ssid)
                                }

                            }

                            Rectangle {
                                implicitWidth: wifiRow.forgetBusy ? 84 : (wifiRow.forgetPending ? 62 : 68)
                                implicitHeight: 30
                                radius: 15
                                color: {
                                    if (wifiRow.forgetHasResult)
                                        return wifiRow.forgetOk ? Theme.qsCardChipBgHover : Qt.rgba(1, 0.35, 0.35, 0.14);

                                    if (wifiRow.forgetPending)
                                        return Qt.rgba(1, 0.35, 0.35, 0.16);

                                    if (wifiRow.forgetBusy)
                                        return Theme.qsCardChipBg;

                                    return wifiHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg;
                                }
                                border.width: 1
                                border.color: wifiRow.forgetPending ? Qt.rgba(1, 0.45, 0.45, 0.22) : (wifiHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder)

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (wifiRow.forgetHasResult)
                                            return wifiRow.forgetOk ? "Forgot" : "Failed";

                                        if (wifiRow.forgetBusy)
                                            return "Forgetting…";

                                        return "Forget";
                                    }
                                    font.family: Theme.fontUi
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: {
                                        if (wifiRow.forgetHasResult)
                                            return wifiRow.forgetOk ? Theme.textPrimary : Theme.red;

                                        if (wifiRow.forgetBusy)
                                            return Theme.textDisabled;

                                        if (wifiRow.forgetPending)
                                            return Theme.red;

                                        return Theme.textPrimary;
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    cursorShape: Qt.ArrowCursor
                                    enabled: root.controller.forgetBusySsid === "" && !wifiRow.forgetHasResult
                                    onClicked: {
                                        if (wifiRow.forgetPending)
                                            root.controller.forgetNetwork(wifiRow.modelData.ssid);
                                        else
                                            root.controller.confirmForget(wifiRow.modelData.ssid);
                                    }
                                }

                            }

                        }

                        Rectangle {
                            id: savedChip

                            anchors.centerIn: parent
                            visible: wifiRow.savedProfile && !wifiRow.forgetActionVisible
                            implicitWidth: savedLabel.implicitWidth + 14
                            implicitHeight: 22
                            radius: 11
                            color: Theme.qsCardChipBg
                            border.width: 1
                            border.color: Theme.qsCardChipBorderHover

                            Text {
                                id: savedLabel

                                anchors.centerIn: parent
                                text: "Saved"
                                font.family: Theme.fontUi
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                            }

                        }

                    }

                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: wifiRow.showSecurityIcon ? 12 : 0
                        Layout.preferredHeight: 14
                        visible: wifiRow.showSecurityIcon

                        Text {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.family: Theme.fontIcons
                            font.pixelSize: 12
                            color: Theme.textDim
                        }

                    }

                    Text {
                        visible: !!modelData.active
                        text: "󰄬"
                        font.family: Theme.fontIcons
                        font.pixelSize: 14
                        color: Theme.green
                    }

                }

                HoverHandler {
                    id: wifiHover

                    blocking: false
                    cursorShape: Qt.ArrowCursor
                }

            }

        }

    }

    ScrollBar.vertical: ScrollBar {
        width: 4
        policy: ScrollBar.AsNeeded
        background: null

        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.2)
        }

    }

}
