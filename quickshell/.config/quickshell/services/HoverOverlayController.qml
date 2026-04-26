import QtQuick
import "../theme/Theme.js" as Theme

QtObject {
    id: controller

    property bool open: false
    property bool pinned: false
    property bool triggerHovered: false
    property bool panelHovered: false
    property bool extraHoldCondition: false
    property int closeDelayMs: Theme.hoverCloseDelay

    function togglePinned() {
        pinned = !pinned
    }

    function closeImmediately() {
        syncVisibility(true)
    }

    function syncVisibility(immediateClose) {
        if (pinned || triggerHovered || panelHovered || extraHoldCondition) {
            hoverClose.stop()
            open = true
            return
        }

        if (immediateClose) {
            hoverClose.stop()
            open = false
            return
        }

        if (open)
            hoverClose.restart()
    }

    property Timer hoverClose: Timer {
        interval: controller.closeDelayMs
        repeat: false
        onTriggered: {
            if (!controller.pinned && !controller.triggerHovered && !controller.panelHovered && !controller.extraHoldCondition)
                controller.open = false
        }
    }

    onPinnedChanged: syncVisibility(!pinned)
    onTriggerHoveredChanged: syncVisibility(false)
    onPanelHoveredChanged: syncVisibility(false)
    onExtraHoldConditionChanged: syncVisibility(false)
}
