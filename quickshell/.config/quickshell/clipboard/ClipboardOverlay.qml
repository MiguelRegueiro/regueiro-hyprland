import QtQuick
import Quickshell
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
    signal barPressed(real x, real y)
    signal barHovered(real x, real y)
    signal barHoverCleared()

    function routeBarPress(mouse) {
        if (mouse.button !== Qt.LeftButton || mouse.y < 0 || mouse.y >= Theme.barHeight)
            return false;

        root.barPressed(mouse.x, mouse.y);
        return true;
    }

    function routeBarHover(mouse) {
        if (mouse.y >= 0 && mouse.y < Theme.barHeight)
            root.barHovered(mouse.x, mouse.y);
        else
            root.barHoverCleared();
    }

    onClipboardVisibleChanged: {
        if (!root.clipboardVisible)
            root.barHoverCleared();
    }

    screen: targetScreen
    visible: showLayer && (root.clipboardVisible || clipboardPanel.visible)
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: root.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.keyboardFocus: root.clipboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
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
            hoverEnabled: true
            onPositionChanged: (mouse) => root.routeBarHover(mouse)
            onExited: root.barHoverCleared()
            onPressed: (mouse) => {
                if (root.routeBarPress(mouse))
                    return ;

                root.outsidePressed();
            }
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
            x: 0
            y: root.forceOverlay ? 0 : Theme.barHeight
            width: root.clipboardVisible ? Math.round(root.width) : 0
            height: root.clipboardVisible ? Math.max(0, Math.round(root.height - (root.forceOverlay ? 0 : Theme.barHeight))) : 0
        }
    }

}
