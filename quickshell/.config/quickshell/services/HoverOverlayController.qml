import QtQuick

Item {
    id: controller

    property bool pinned: false
    property bool triggerHovered: false
    property bool panelHovered: false
    property int closeDelayMs: 140

    visible: false

    function togglePinned() {
        pinned = !pinned
    }

    function closeImmediately() {
        syncVisibility(true)
    }

    function syncVisibility(immediateClose) {
        if (pinned || triggerHovered || panelHovered) {
            hoverClose.stop()
            visible = true
            return
        }

        if (immediateClose) {
            hoverClose.stop()
            visible = false
            return
        }

        if (visible)
            hoverClose.restart()
    }

    Timer {
        id: hoverClose
        interval: controller.closeDelayMs
        repeat: false
        onTriggered: {
            if (!controller.pinned && !controller.triggerHovered && !controller.panelHovered)
                controller.visible = false
        }
    }

    onPinnedChanged: syncVisibility(!pinned)
    onTriggerHoveredChanged: syncVisibility(false)
    onPanelHoveredChanged: syncVisibility(false)
}
