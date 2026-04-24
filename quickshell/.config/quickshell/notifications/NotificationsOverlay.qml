import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    required property var notificationStore

    signal outsidePressed()

    property bool showLayer: true
    property bool notificationCenterVisible: false
    property bool quickSettingsVisible: false
    property bool notificationCenterCursorInside: false
    readonly property bool notificationCenterHovered: notificationCenter.hovered || root.notificationCenterCursorInside
    readonly property real toastGap: Theme.borderSize + 8
    readonly property real quickSettingsReserveWidth: root.quickSettingsVisible ? (Theme.qsWidth + Theme.qsAttachRight + 16) : 0
    readonly property real toastX: Math.round(Math.max(root.toastGap, root.width - toastStack.width - root.toastGap - root.quickSettingsReserveWidth))
    readonly property real notificationCenterRegionX: notificationCenter.x + notificationCenter.inputRegion.x
    readonly property real notificationCenterRegionY: notificationCenter.y + notificationCenter.inputRegion.y
    readonly property real notificationCenterRegionWidth: notificationCenter.inputRegion.width
    readonly property real notificationCenterRegionHeight: notificationCenter.inputRegion.height

    function updateNotificationCenterCursor(rawText) {
        const match = rawText.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/)
        if (!match) {
            root.notificationCenterCursorInside = false
            return
        }

        const cursorX = Number(match[1])
        const cursorY = Number(match[2])
        const panelLeft = Number(root.targetScreen.x) + notificationCenter.x - 18
        const panelTop = Number(root.targetScreen.y) + notificationCenter.y - 18
        const panelRight = panelLeft + notificationCenter.width + 36
        const panelBottom = panelTop + notificationCenter.height + 36

        const ncBarLeft = Number(root.targetScreen.x) + Math.round((root.targetScreen.width - notificationCenter.width) / 2)
        const ncBarRight = ncBarLeft + notificationCenter.width
        const inBarTrigger = cursorY >= Number(root.targetScreen.y)
            && cursorY < Number(root.targetScreen.y) + Theme.barHeight
            && cursorX >= ncBarLeft && cursorX <= ncBarRight

        root.notificationCenterCursorInside = root.notificationCenterVisible
            && (inBarTrigger
                || (cursorX >= panelLeft && cursorX <= panelRight
                    && cursorY >= panelTop && cursorY <= panelBottom))
    }

    screen: targetScreen
    visible: showLayer && (root.notificationCenterVisible || root.notificationStore.popups.length > 0)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-notif"
    color: "transparent"

    Timer {
        interval: 40
        running: root.notificationCenterVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cursorPosProc.running)
                cursorPosProc.running = true
        }
    }

    Process {
        id: cursorPosProc

        command: ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            id: cursorPosOut

            onStreamFinished: root.updateNotificationCenterCursor(cursorPosOut.text.trim())
        }
    }

    Item {
        visible: root.notificationCenterVisible
        anchors.fill: parent

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(root.notificationCenterRegionY))
            onPressed: root.outsidePressed()
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

    mask: Region {
        Region {
            item: notificationCenter.inputRegion
        }

        Region {
            x: 0
            y: 0
            width: root.notificationCenterVisible ? Math.round(root.width) : 0
            height: root.notificationCenterVisible ? Math.max(0, Math.round(root.notificationCenterRegionY)) : 0
        }

        Region {
            x: 0
            y: Math.max(0, Math.round(root.notificationCenterRegionY))
            width: root.notificationCenterVisible ? Math.max(0, Math.round(root.notificationCenterRegionX)) : 0
            height: root.notificationCenterVisible ? Math.max(0, Math.round(root.notificationCenterRegionHeight)) : 0
        }

        Region {
            x: Math.round(root.notificationCenterRegionX + root.notificationCenterRegionWidth)
            y: Math.max(0, Math.round(root.notificationCenterRegionY))
            width: root.notificationCenterVisible
                ? Math.max(0, Math.round(root.width - (root.notificationCenterRegionX + root.notificationCenterRegionWidth)))
                : 0
            height: root.notificationCenterVisible ? Math.max(0, Math.round(root.notificationCenterRegionHeight)) : 0
        }

        Region {
            x: 0
            y: Math.round(root.notificationCenterRegionY + root.notificationCenterRegionHeight)
            width: root.notificationCenterVisible ? Math.round(root.width) : 0
            height: root.notificationCenterVisible
                ? Math.max(0, Math.round(root.height - (root.notificationCenterRegionY + root.notificationCenterRegionHeight)))
                : 0
        }

        Region {
            x: Math.round(toastStack.x)
            y: Math.round(toastStack.y)
            width: toastStack.visible ? Math.round(toastStack.width) : 0
            height: toastStack.visible ? Math.round(toastStack.height) : 0
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
        y: Theme.barHeight + 8
        width: Theme.toastWidth
        spacing: 8

        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

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
    }
}
