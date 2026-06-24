import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "." as Launcher
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var launcherService
    property bool showLayer: true
    property bool launcherVisible: false
    property bool forceOverlay: false
    property bool layerMapped: false
    property bool openingGuard: false
    readonly property real launcherRegionX: launcherPanel.x + launcherPanel.inputRegion.x
    readonly property real launcherRegionY: launcherPanel.y + launcherPanel.inputRegion.y
    readonly property real launcherRegionWidth: launcherPanel.inputRegion.width
    readonly property real launcherRegionHeight: launcherPanel.inputRegion.height

    signal outsidePressed()
    signal quickSettingsRequested()
    signal notificationCenterRequested()

    function routeBarPress(mouse) {
        if (mouse.button !== Qt.LeftButton || mouse.y < 0 || mouse.y >= Theme.barHeight)
            return false;

        const ncLeft = Math.round((root.width - Theme.ncBarTriggerWidth) / 2);
        const ncRight = ncLeft + Theme.ncBarTriggerWidth;
        if (mouse.x >= ncLeft && mouse.x <= ncRight) {
            root.notificationCenterRequested();
            return true;
        }

        const qsLeft = Math.max(0, root.width - Theme.qsBarTriggerWidth);
        if (mouse.x >= qsLeft) {
            root.quickSettingsRequested();
            return true;
        }

        return false;
    }

    function closeFromOutside() {
        // With the layer kept mapped for icon-cache warmth, the same click that
        // opens the launcher can also hit this overlay. Ignore the initial press
        // and focus churn so the drawer does not close before the reveal appears.
        if (root.openingGuard)
            return;

        root.outsidePressed();
    }

    onLauncherVisibleChanged: {
        if (root.launcherVisible) {
            root.layerMapped = true;
            closeUnmountTimer.stop();
            root.openingGuard = true;
            openingGuardTimer.restart();
            Qt.callLater(function() {
                if (root.launcherVisible)
                    launcherFocusGrab.active = true;

            });
        } else {
            root.openingGuard = false;
            openingGuardTimer.stop();
            launcherFocusGrab.active = false;
            closeUnmountTimer.restart();
        }
    }

    Timer {
        id: openingGuardTimer

        interval: 180
        repeat: false
        onTriggered: root.openingGuard = false
    }

    Timer {
        id: closeUnmountTimer

        interval: Theme.panelCloseDuration + 40
        repeat: false
        onTriggered: {
            if (!root.launcherVisible)
                root.layerMapped = false;

        }
    }

    screen: targetScreen
    // Keep the layer mapped through the close animation, then unmap it so
    // Hyprland can return pointer-follow focus to the underlying client.
    visible: showLayer && root.layerMapped
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: root.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: root.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    HyprlandFocusGrab {
        id: launcherFocusGrab

        windows: [root]
        onCleared: {
            if (root.launcherVisible)
                root.closeFromOutside();

        }
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
            onPressed: (mouse) => {
                if (root.forceOverlay && root.routeBarPress(mouse))
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
