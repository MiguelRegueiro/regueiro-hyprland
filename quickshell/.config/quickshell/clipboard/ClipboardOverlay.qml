import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as Clipboard
import "../theme/Theme.js" as Theme

Scope {
    id: root

    required property var targetScreen
    required property var clipboardService
    property bool showLayer: true
    property bool clipboardVisible: false
    // Non-target monitors keep an invisible click-away surface while the
    // clipboard is open on its captured target monitor.
    property bool dismissOnOutsideClick: false
    property bool forceOverlay: false
    readonly property real clipboardRegionX: clipboardPanel.x + clipboardPanel.inputRegion.x
    readonly property real clipboardRegionY: clipboardPanel.y + clipboardPanel.inputRegion.y
    readonly property real clipboardRegionWidth: clipboardPanel.inputRegion.width
    readonly property real clipboardRegionHeight: clipboardPanel.inputRegion.height

    signal outsidePressed(bool restoreWorkspaceFocus)
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

    PanelWindow {
        id: overlay

    screen: targetScreen
    visible: showLayer && (root.clipboardVisible || root.dismissOnOutsideClick || clipboardPanel.visible)
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Keep interactive panels below transient OSDs. The panel background is a
    // child of this surface, so it cannot cover the content as a separate
    // same-layer backdrop did.
    WlrLayershell.layer: (root.forceOverlay || root.dismissOnOutsideClick) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.keyboardFocus: root.clipboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        x: clipboardPanel.x
        y: clipboardPanel.y
        width: clipboardPanel.width
        height: clipboardPanel.height
        radius: Theme.clipboardSurfaceTopLeftRadius
        color: Qt.rgba(0.09, 0.095, 0.11, 0.84)
        opacity: clipboardPanel.surfaceOpacity
        border.width: 1
        border.color: Theme.menuSurfaceOutline
        z: -1
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

                root.outsidePressed(true);
            }
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(root.clipboardRegionY))
            width: Math.max(0, Math.round(root.clipboardRegionX))
            height: Math.max(0, Math.round(root.clipboardRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed(true)
        }

        MouseArea {
            x: Math.round(root.clipboardRegionX + root.clipboardRegionWidth)
            y: Math.max(0, Math.round(root.clipboardRegionY))
            width: Math.max(0, Math.round(parent.width - (root.clipboardRegionX + root.clipboardRegionWidth)))
            height: Math.max(0, Math.round(root.clipboardRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed(true)
        }

        MouseArea {
            x: 0
            y: Math.round(root.clipboardRegionY + root.clipboardRegionHeight)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - (root.clipboardRegionY + root.clipboardRegionHeight)))
            acceptedButtons: Qt.AllButtons
            onPressed: root.outsidePressed(true)
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.dismissOnOutsideClick
        acceptedButtons: Qt.AllButtons
        onPressed: root.outsidePressed(false)
    }

    Clipboard.ClipboardPanel {
        id: clipboardPanel

        x: Math.round((parent.width - implicitWidth) / 2)
        y: Math.round(parent.height - Theme.borderSize - bodyHeight - 70 + surfaceOffsetY)
        open: root.clipboardVisible
        clipboardService: root.clipboardService
        onRequestClose: root.outsidePressed(true)
    }

    mask: Region {
        Region {
            x: 0
            y: root.dismissOnOutsideClick || root.forceOverlay ? 0 : Theme.barHeight
            width: (root.clipboardVisible || root.dismissOnOutsideClick) ? Math.round(overlay.width) : 0
            height: (root.clipboardVisible || root.dismissOnOutsideClick) ? Math.max(0, Math.round(overlay.height - (root.dismissOnOutsideClick || root.forceOverlay ? 0 : Theme.barHeight))) : 0
        }
    }

    }
}
