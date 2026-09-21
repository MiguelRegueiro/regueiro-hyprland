import QtQuick
import "../components" as Components
import "../theme/Theme.js" as Theme

// Display-only items inside the lock surface, using the normal bar's styling.
Item {
    id: root
    required property var status

    QtObject {
        id: audio
        readonly property int volumePercent: root.status ? Math.max(0, root.status.volume) : 0
        readonly property bool muted: root.status ? root.status.muted : false
    }
    QtObject {
        id: brightness
        readonly property int percent: root.status ? Math.max(0, root.status.brightness) : 0
    }

    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 18
        height: Theme.barHeight * 1.15
        width: indicators.width * 1.15
        Row {
            id: indicators
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            scale: 1.15
            transformOrigin: Item.Right
            spacing: 6
            Components.VolumeIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.status && root.status.volume >= 0
                muted: audio.muted
                volumePercent: audio.volumePercent
                iconColor: Theme.textPrimary
                height: 13
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.status && root.status.volume >= 0
                text: audio.volumePercent + "%"
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: audio.muted ? Theme.textDisabled : Theme.textPrimary
            }
            Row {
                visible: root.status && root.status.batteryPercent >= 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Rectangle {
                    width: 1
                    height: 14
                    color: Theme.barBorder
                    anchors.verticalCenter: parent.verticalCenter
                }
                Components.BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    percent: root.status ? root.status.batteryPercent : 0
                    charging: root.status ? root.status.charging : false
                    full: root.status ? root.status.full : false
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.status ? root.status.batteryPercent : 0) + "%"
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }
        }
    }

    Components.StatusOsd {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Match the centered 60px card in the normal 100px OSD window.
        anchors.bottomMargin: Theme.borderSize - 4 + 20
        audioService: audio
        brightnessService: brightness
        currentMode: root.status && root.status.osdMode === "brightness" ? "brightness" : "volume"
        osdVisible: root.status && root.status.osdMode !== ""
    }
}
