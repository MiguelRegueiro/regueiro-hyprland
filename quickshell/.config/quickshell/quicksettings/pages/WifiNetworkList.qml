import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "../../components" as Components
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Flickable {
    id: root

    required property var controller
    readonly property real rowHeight: 50
    readonly property real rowSpacing: 3
    readonly property real bottomInset: 12
    // Signal is deliberately bucketed: a network must cross a 10% boundary
    // before its row moves, avoiding churn from normal RSSI fluctuations.
    readonly property int signalOrderStep: 10

    readonly property var orderedNetworks: {
        const source = root.controller.networks;
        if (!source)
            return [];

        const networks = source.values.slice();
        networks.sort((left, right) => {
            // Match the old presentation rule: the active network first,
            // then every other network from strongest to weakest.
            const leftGroup = left.connected ? 0 : 1;
            const rightGroup = right.connected ? 0 : 1;
            if (leftGroup !== rightGroup)
                return leftGroup - rightGroup;

            const leftSignal = Math.floor(root.controller.signalPercent(left) / root.signalOrderStep);
            const rightSignal = Math.floor(root.controller.signalPercent(right) / root.signalOrderStep);
            if (leftSignal !== rightSignal)
                return rightSignal - leftSignal;

            return left.name.localeCompare(right.name);
        });
        return networks;
    }

    contentHeight: listCol.implicitHeight + bottomInset
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: listCol

        width: parent.width
        spacing: root.rowSpacing

        Repeater {
            // Identity comparison retains each native WifiNetwork delegate
            // when order changes, instead of rebuilding the visible list.
            model: ScriptModel {
                values: root.controller.wifiOn ? root.orderedNetworks : []
                comparisonMode: ObjectComparison.Identity
            }

            delegate: Rectangle {
                id: wifiRow

                required property var modelData
                readonly property bool secureNetwork: root.controller.isSecureNetwork(modelData)
                readonly property bool selectedForPrompt: root.controller.connectSsid === modelData.name && root.controller.connectSecure
                readonly property bool rememberedProfile: root.controller.hasSavedProfile(modelData)
                readonly property bool savedProfile: !modelData.connected && rememberedProfile
                readonly property bool showSecurityIcon: secureNetwork && !rememberedProfile && !modelData.connected
                readonly property bool forgetPending: root.controller.forgetConfirmSsid === modelData.name
                readonly property bool forgetBusy: root.controller.forgetBusySsid === modelData.name
                readonly property bool forgetHasResult: root.controller.forgetResultSsid === modelData.name
                readonly property bool forgetOk: forgetHasResult && root.controller.forgetResultOk
                readonly property bool forgetActionVisible: rememberedProfile && (wifiHover.hovered || forgetPending || forgetBusy || forgetHasResult)

                Layout.fillWidth: true
                height: root.rowHeight
                radius: 18
                color: modelData.connected ? QS.cardActiveBg : (selectedForPrompt ? QS.cardBgHover : (wifiHover.hovered ? QS.cardBgHover : QS.cardBg))
                border.width: 1
                border.color: modelData.connected ? QS.cardActiveBorder : (selectedForPrompt ? QS.tileActiveBorder : (wifiHover.hovered ? QS.cardBorderHover : QS.cardBorder))

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    enabled: root.controller.forgetBusySsid === "" && !wifiRow.forgetPending && !wifiRow.forgetBusy && !wifiRow.forgetHasResult
                    onClicked: {
                        root.controller.forgetConfirmSsid = "";
                        if (root.controller.connecting)
                            return;

                        if (modelData.connected)
                            return;

                        if (root.controller.isSecureNetwork(modelData)) {
                            if (root.controller.hasSavedProfile(modelData))
                                root.controller.connectSavedSecureNetwork(modelData);
                            else
                                root.controller.openPasswordPrompt(modelData);
                        } else {
                            root.controller.connectOpenNetwork(modelData);
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
                        color: modelData.connected ? Qt.rgba(1, 1, 1, 0.12) : (wifiHover.hovered ? QS.chipBgHover : QS.chipBg)
                        border.width: 1
                        border.color: modelData.connected ? Qt.rgba(1, 1, 1, 0.12) : (wifiHover.hovered ? QS.chipBorderHover : QS.chipBorder)

                        Components.WifiIcon {
                            anchors.centerIn: parent
                            height: 16
                            // A listed network is available; row emphasis is
                            // conveyed by its colour, while the common icon
                            // keeps this page visually consistent with the bar.
                            connected: true
                            signal: root.controller.signalPercent(modelData)
                            iconColor: "#ffffff"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || ""
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: modelData.connected ? Font.DemiBold : Font.Medium
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
                                color: QS.chipBg
                                border.width: 1
                                border.color: QS.chipBorder

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
                                    onClicked: root.controller.cancelForget(wifiRow.modelData)
                                }
                            }

                            Rectangle {
                                implicitWidth: wifiRow.forgetBusy ? 84 : (wifiRow.forgetPending ? 62 : 68)
                                implicitHeight: 30
                                radius: 15
                                color: {
                                    if (wifiRow.forgetHasResult)
                                        return wifiRow.forgetOk ? QS.chipBgHover : Qt.rgba(1, 0.35, 0.35, 0.14);

                                    if (wifiRow.forgetPending)
                                        return Qt.rgba(1, 0.35, 0.35, 0.16);

                                    if (wifiRow.forgetBusy)
                                        return QS.chipBg;

                                    return wifiHover.hovered ? QS.chipBgHover : QS.chipBg;
                                }
                                border.width: 1
                                border.color: wifiRow.forgetPending ? Qt.rgba(1, 0.45, 0.45, 0.22) : (wifiHover.hovered ? QS.chipBorderHover : QS.chipBorder)

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
                                            root.controller.forgetNetwork(wifiRow.modelData);
                                        else
                                            root.controller.confirmForget(wifiRow.modelData);
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
                            color: QS.chipBg
                            border.width: 1
                            border.color: QS.chipBorderHover

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
                        visible: !!modelData.connected
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
