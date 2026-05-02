import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "." as Clipboard
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var clipboardService
    property bool showLayer: true
    property bool clipboardVisible: false
    property bool forceOverlay: false
    readonly property real clipboardRegionX: clipboardPanel.x + clipboardPanel.inputRegion.x
    readonly property real clipboardRegionY: clipboardPanel.y + clipboardPanel.inputRegion.y
    readonly property real clipboardRegionWidth: clipboardPanel.inputRegion.width
    readonly property real clipboardRegionHeight: clipboardPanel.inputRegion.height

    signal outsidePressed()

    onClipboardVisibleChanged: {
        if (root.clipboardVisible) {
            Qt.callLater(function() {
                if (root.clipboardVisible)
                    clipboardFocusGrab.active = true;

            });
        } else {
            clipboardFocusGrab.active = false;
        }
    }

    screen: targetScreen
    visible: showLayer && (root.clipboardVisible || clipboardPanel.visible)
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: root.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.keyboardFocus: root.clipboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    HyprlandFocusGrab {
        id: clipboardFocusGrab

        windows: [root]
        onCleared: {
            if (root.clipboardVisible)
                root.outsidePressed();

        }
    }

    Item {
        visible: root.clipboardVisible
        anchors.fill: parent

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(root.clipboardRegionY))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(root.clipboardRegionY))
            width: Math.max(0, Math.round(root.clipboardRegionX))
            height: Math.max(0, Math.round(root.clipboardRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: Math.round(root.clipboardRegionX + root.clipboardRegionWidth)
            y: Math.max(0, Math.round(root.clipboardRegionY))
            width: Math.max(0, Math.round(parent.width - (root.clipboardRegionX + root.clipboardRegionWidth)))
            height: Math.max(0, Math.round(root.clipboardRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: 0
            y: Math.round(root.clipboardRegionY + root.clipboardRegionHeight)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - (root.clipboardRegionY + root.clipboardRegionHeight)))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed()
        }
    }

    Clipboard.ClipboardPanel {
        id: clipboardPanel

        x: Math.round((parent.width - implicitWidth) / 2)
        y: Math.round(parent.height - Theme.borderSize - bodyHeight)
        open: root.clipboardVisible
        clipboardService: root.clipboardService
        onRequestClose: root.outsidePressed()
    }

    mask: Region {
        Region {
            item: clipboardPanel.inputRegion
        }

        Region {
            x: 0
            y: 0
            width: root.clipboardVisible ? Math.round(root.width) : 0
            height: root.clipboardVisible ? Math.max(0, Math.round(root.clipboardRegionY)) : 0
        }

        Region {
            x: 0
            y: Math.max(0, Math.round(root.clipboardRegionY))
            width: root.clipboardVisible ? Math.max(0, Math.round(root.clipboardRegionX)) : 0
            height: root.clipboardVisible ? Math.max(0, Math.round(root.clipboardRegionHeight)) : 0
        }

        Region {
            x: Math.round(root.clipboardRegionX + root.clipboardRegionWidth)
            y: Math.max(0, Math.round(root.clipboardRegionY))
            width: root.clipboardVisible ? Math.max(0, Math.round(root.width - (root.clipboardRegionX + root.clipboardRegionWidth))) : 0
            height: root.clipboardVisible ? Math.max(0, Math.round(root.clipboardRegionHeight)) : 0
        }

        Region {
            x: 0
            y: Math.round(root.clipboardRegionY + root.clipboardRegionHeight)
            width: root.clipboardVisible ? Math.round(root.width) : 0
            height: root.clipboardVisible ? Math.max(0, Math.round(root.height - (root.clipboardRegionY + root.clipboardRegionHeight))) : 0
        }
    }

}
