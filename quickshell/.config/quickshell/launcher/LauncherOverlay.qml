import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as Launcher
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var launcherService
    property bool showLayer: true
    property bool launcherVisible: false
    readonly property real launcherRegionX: launcherPanel.x + launcherPanel.inputRegion.x
    readonly property real launcherRegionY: launcherPanel.y + launcherPanel.inputRegion.y
    readonly property real launcherRegionWidth: launcherPanel.inputRegion.width
    readonly property real launcherRegionHeight: launcherPanel.inputRegion.height

    signal outsidePressed()

    screen: targetScreen
    visible: showLayer && (root.launcherVisible || launcherPanel.visible)
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        visible: root.launcherVisible
        anchors.fill: parent

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(root.launcherRegionY))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(root.launcherRegionY))
            width: Math.max(0, Math.round(root.launcherRegionX))
            height: Math.max(0, Math.round(root.launcherRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: Math.round(root.launcherRegionX + root.launcherRegionWidth)
            y: Math.max(0, Math.round(root.launcherRegionY))
            width: Math.max(0, Math.round(parent.width - (root.launcherRegionX + root.launcherRegionWidth)))
            height: Math.max(0, Math.round(root.launcherRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: 0
            y: Math.round(root.launcherRegionY + root.launcherRegionHeight)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - (root.launcherRegionY + root.launcherRegionHeight)))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }
    }

    Launcher.LauncherPanel {
        id: launcherPanel

        x: Math.round((parent.width - implicitWidth) / 2)
        y: Math.round(parent.height - Theme.borderSize - bodyHeight)
        open: root.launcherVisible
        launcherService: root.launcherService
        onRequestClose: root.outsidePressed()
    }

    mask: Region {
        Region {
            item: launcherPanel.inputRegion
        }

        Region {
            x: 0
            y: 0
            width: root.launcherVisible ? Math.round(root.width) : 0
            height: root.launcherVisible ? Math.max(0, Math.round(root.launcherRegionY)) : 0
        }

        Region {
            x: 0
            y: Math.max(0, Math.round(root.launcherRegionY))
            width: root.launcherVisible ? Math.max(0, Math.round(root.launcherRegionX)) : 0
            height: root.launcherVisible ? Math.max(0, Math.round(root.launcherRegionHeight)) : 0
        }

        Region {
            x: Math.round(root.launcherRegionX + root.launcherRegionWidth)
            y: Math.max(0, Math.round(root.launcherRegionY))
            width: root.launcherVisible ? Math.max(0, Math.round(root.width - (root.launcherRegionX + root.launcherRegionWidth))) : 0
            height: root.launcherVisible ? Math.max(0, Math.round(root.launcherRegionHeight)) : 0
        }

        Region {
            x: 0
            y: Math.round(root.launcherRegionY + root.launcherRegionHeight)
            width: root.launcherVisible ? Math.round(root.width) : 0
            height: root.launcherVisible ? Math.max(0, Math.round(root.height - (root.launcherRegionY + root.launcherRegionHeight))) : 0
        }
    }
}
