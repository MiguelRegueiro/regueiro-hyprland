import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as Launcher
import "../theme/Theme.js" as Theme

Scope {
    id: root

    required property var targetScreen
    required property var launcherService
    property bool showLayer: true
    property bool launcherVisible: false
    // A transparent, input-only instance on every non-target monitor lets a
    // click there dismiss the drawer instead of leaking through unchanged.
    property bool dismissOnOutsideClick: false
    property bool forceOverlay: false
    property bool openingGuard: false
    readonly property real launcherRegionX: launcherPanel.x + launcherPanel.inputRegion.x
    readonly property real launcherRegionY: launcherPanel.y + launcherPanel.inputRegion.y
    readonly property real launcherRegionWidth: launcherPanel.inputRegion.width
    readonly property real launcherRegionHeight: launcherPanel.inputRegion.height

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

    function closeFromOutside() {
        // With the layer kept mapped for icon-cache warmth, the same click that
        // opens the launcher can also hit this overlay. Ignore the initial press
        // and focus churn so the drawer does not close before the reveal appears.
        if (root.openingGuard)
            return;

        root.outsidePressed(true);
    }

    onLauncherVisibleChanged: {
        if (root.launcherVisible) {
            root.openingGuard = true;
            openingGuardTimer.restart();
        } else {
            root.openingGuard = false;
            openingGuardTimer.stop();
            root.barHoverCleared();
        }
    }

    Timer {
        id: openingGuardTimer

        interval: 180
        repeat: false
        onTriggered: root.openingGuard = false
    }

    PanelWindow {
        id: overlay

    screen: targetScreen
    // Match clipboard focus behavior: unmap the layer after the close animation
    // so Hyprland immediately returns typing to the client under the cursor.
    visible: showLayer && (root.launcherVisible || root.dismissOnOutsideClick || launcherPanel.reveal > 0.001)
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Keep interactive panels below transient OSDs. The panel background is a
    // child of this surface, so it cannot cover the content as a separate
    // same-layer backdrop did.
    WlrLayershell.layer: (root.forceOverlay || root.dismissOnOutsideClick) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: root.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        x: launcherPanel.x
        y: launcherPanel.y
        width: launcherPanel.width
        height: launcherPanel.height
        radius: Theme.launcherSurfaceTopLeftRadius
        color: Qt.rgba(0.09, 0.095, 0.11, 0.84)
        opacity: launcherPanel.surfaceOpacity
        border.width: 1
        border.color: Theme.menuSurfaceOutline
        z: -1
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
            hoverEnabled: true
            onPositionChanged: (mouse) => root.routeBarHover(mouse)
            onExited: root.barHoverCleared()
            onPressed: (mouse) => {
                if (root.routeBarPress(mouse))
                    return ;

                root.closeFromOutside();
            }
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(root.launcherRegionY))
            width: Math.max(0, Math.round(root.launcherRegionX))
            height: Math.max(0, Math.round(root.launcherRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.closeFromOutside()
        }

        MouseArea {
            x: Math.round(root.launcherRegionX + root.launcherRegionWidth)
            y: Math.max(0, Math.round(root.launcherRegionY))
            width: Math.max(0, Math.round(parent.width - (root.launcherRegionX + root.launcherRegionWidth)))
            height: Math.max(0, Math.round(root.launcherRegionHeight))
            acceptedButtons: Qt.AllButtons
            onPressed: root.closeFromOutside()
        }

        MouseArea {
            x: 0
            y: Math.round(root.launcherRegionY + root.launcherRegionHeight)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - (root.launcherRegionY + root.launcherRegionHeight)))
            acceptedButtons: Qt.AllButtons
            onPressed: root.closeFromOutside()
        }
    }

    MouseArea {
        // This is intentionally above every non-target-monitor surface. Its
        // only job is to turn the first outside click into a dismissal; it must
        // not restore focus to the monitor that originally opened the drawer.
        anchors.fill: parent
        visible: root.dismissOnOutsideClick
        acceptedButtons: Qt.AllButtons
        onPressed: root.outsidePressed(false)
    }

    Launcher.LauncherPanel {
        id: launcherPanel

        x: Math.round((parent.width - implicitWidth) / 2)
        y: Math.round(parent.height - Theme.borderSize - bodyHeight - 70 + surfaceOffsetY)
        open: root.launcherVisible
        launcherService: root.launcherService
        onRequestClose: root.outsidePressed(true)
    }

    mask: Region {
        Region {
            x: 0
            y: root.dismissOnOutsideClick || root.forceOverlay ? 0 : Theme.barHeight
            width: (root.launcherVisible || root.dismissOnOutsideClick) ? Math.round(overlay.width) : 0
            height: (root.launcherVisible || root.dismissOnOutsideClick) ? Math.max(0, Math.round(overlay.height - (root.dismissOnOutsideClick || root.forceOverlay ? 0 : Theme.barHeight))) : 0
        }
    }
    }
}
