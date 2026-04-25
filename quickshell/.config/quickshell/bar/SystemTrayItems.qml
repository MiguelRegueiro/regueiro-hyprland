import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../theme/Theme.js" as Theme

Row {
    id: trayRow

    property int barHeight: 34

    spacing: 2
    leftPadding: 4
    rightPadding: 4

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: trayItem
            required property SystemTrayItem modelData

            readonly property string itemId: (modelData.id || "").toLowerCase()
            visible: !itemId.includes("blueman") && !itemId.includes("nm-applet")
                && !itemId.includes("fcitx")
                && (modelData.status !== Status.Passive || modelData.onlyMenu)

            height: trayRow.barHeight - 8
            width: height
            radius: Theme.radiusSmall

            readonly property bool hovered: hover.hovered
            color: hovered ? Theme.hoverBg : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

            Image {
                anchors.centerIn: parent
                width: 16; height: 16
                source: trayItem.modelData.icon
                smooth: true
                mipmap: true
                opacity: trayItem.modelData.status === Status.NeedsAttention ? 1.0 : 0.85
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                anchor.item: trayItem
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }

            HoverHandler {
                id: hover
                blocking: false
                cursorShape: Qt.ArrowCursor
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton) {
                        if (trayItem.modelData.hasMenu) menuAnchor.open()
                            else trayItem.modelData.activate()
                    } else {
                        if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                            menuAnchor.open()
                            else
                                trayItem.modelData.activate()
                    }
                }
            }
        }
    }
}
