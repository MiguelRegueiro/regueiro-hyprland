import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var notificationStore
    property bool showLayer: true
    property bool notificationCenterVisible: false
    property bool quickSettingsVisible: false
    property bool forceOverlay: false
    readonly property bool notificationCenterHovered: notificationCenter.hovered
    readonly property real toastGap: Theme.borderSize + 28
    readonly property real quickSettingsReserveWidth: root.quickSettingsVisible ? (Theme.qsWidth + Theme.qsAttachRight + 16) : 0
    readonly property real toastX: Math.round(Math.max(root.toastGap, root.width - toastStack.width - root.toastGap - root.quickSettingsReserveWidth))
    readonly property real notificationCenterRegionX: notificationCenter.x + notificationCenter.inputRegion.x
    readonly property real notificationCenterRegionY: notificationCenter.y + notificationCenter.inputRegion.y
    readonly property real notificationCenterRegionWidth: notificationCenter.inputRegion.width
    readonly property real notificationCenterRegionHeight: notificationCenter.inputRegion.height

    signal outsidePressed()
    signal barPressed(real x, real y)

    function routeBarPress(mouse) {
        if (mouse.button !== Qt.LeftButton || mouse.y < 0 || mouse.y >= Theme.barHeight)
            return false;

        root.barPressed(mouse.x, mouse.y);
        return true;
    }


    screen: targetScreen
    visible: showLayer && (root.notificationCenterVisible || root.notificationStore.popups.length > 0)
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: root.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-notif"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }


    Item {
        visible: root.notificationCenterVisible
        anchors.fill: parent

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(root.notificationCenterRegionY))
            onPressed: (mouse) => {
                if (root.forceOverlay && root.routeBarPress(mouse))
                    return ;

                root.outsidePressed();
            }
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(root.notificationCenterRegionY))
            width: Math.max(0, Math.round(root.notificationCenterRegionX))
            height: Math.max(0, Math.round(root.notificationCenterRegionHeight))
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: Math.round(root.notificationCenterRegionX + root.notificationCenterRegionWidth)
            y: Math.max(0, Math.round(root.notificationCenterRegionY))
            width: Math.max(0, Math.round(parent.width - (root.notificationCenterRegionX + root.notificationCenterRegionWidth)))
            height: Math.max(0, Math.round(root.notificationCenterRegionHeight))
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: 0
            y: Math.round(root.notificationCenterRegionY + root.notificationCenterRegionHeight)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - (root.notificationCenterRegionY + root.notificationCenterRegionHeight)))
            onPressed: root.outsidePressed()
        }

    }

    NotificationCenterPanel {
        id: notificationCenter

        x: Math.round((parent.width - implicitWidth) / 2)
        y: Theme.barHeight - Theme.qsBarFuseOverlap - 2
        open: root.notificationCenterVisible
        notificationStore: root.notificationStore
    }

    Column {
        id: toastStack

        visible: !root.notificationCenterVisible && root.notificationStore.popups.length > 0
        x: root.toastX
        y: Theme.barHeight + Theme.borderSize + 12
        width: Theme.toastWidth
        spacing: 8

        Repeater {
            model: root.notificationStore.popups

            delegate: NotificationToast {
                required property var modelData

                width: toastStack.width
                item: modelData
                notificationStore: root.notificationStore
                onCloseRequested: root.notificationStore.dismissPopup(modelData)
            }

        }

        Behavior on x {
            NumberAnimation {
                duration: Theme.toastSlideDuration
                easing.type: Easing.OutCubic
            }

        }

    }

    mask: Region {
        Region {
            x: 0
            y: root.forceOverlay ? 0 : Theme.barHeight
            width: root.notificationCenterVisible ? Math.round(root.width) : 0
            height: root.notificationCenterVisible ? Math.max(0, Math.round(root.height - (root.forceOverlay ? 0 : Theme.barHeight))) : 0
        }

        Region {
            x: Math.round(toastStack.x)
            y: Math.round(toastStack.y)
            width: toastStack.visible ? Math.round(toastStack.width) : 0
            height: toastStack.visible ? Math.round(toastStack.height) : 0
        }

    }

}
