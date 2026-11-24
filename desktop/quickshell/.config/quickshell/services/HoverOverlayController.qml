import QtQuick
import "../theme/Theme.js" as Theme

QtObject {
    id: controller

    property bool open: false
    property bool pinned: false
    property bool triggerHovered: false
    property bool panelHovered: false
    property bool extraHoldCondition: false
    property bool inhibited: false
    property bool suppressVisibilitySync: false
    property bool transientOpen: false
    property int closeDelayMs: Theme.hoverCloseDelay
    property Timer hoverClose

    function togglePinned() {
        transientOpen = false;
        pinned = !pinned;
    }

    function closeImmediately() {
        suppressVisibilitySync = true;
        hoverClose.stop();
        transientOpen = false;
        pinned = false;
        triggerHovered = false;
        panelHovered = false;
        open = false;
        suppressVisibilitySync = false;
    }

    function openTransient() {
        suppressVisibilitySync = true;
        hoverClose.stop();
        transientOpen = true;
        pinned = false;
        open = true;
        suppressVisibilitySync = false;
        syncVisibility(false);
    }

    function syncVisibility(immediateClose) {
        if (suppressVisibilitySync || inhibited) {
            hoverClose.stop();
            if (inhibited)
                transientOpen = false;

            open = false;
            return ;
        }
        if (pinned || triggerHovered || panelHovered || extraHoldCondition) {
            if (pinned)
                transientOpen = false;

            hoverClose.stop();
            open = true;
            return ;
        }
        if (immediateClose) {
            hoverClose.stop();
            transientOpen = false;
            open = false;
            return ;
        }
        if (open)
            hoverClose.restart();

    }

    onPinnedChanged: syncVisibility(!pinned)
    onTriggerHoveredChanged: syncVisibility(false)
    onPanelHoveredChanged: syncVisibility(false)
    onExtraHoldConditionChanged: syncVisibility(false)
    onInhibitedChanged: {
        if (inhibited)
            closeImmediately();
        else
            syncVisibility(false);
    }

    hoverClose: Timer {
        interval: controller.closeDelayMs
        repeat: false
        onTriggered: {
            if (!controller.inhibited && !controller.pinned && !controller.triggerHovered && !controller.panelHovered && !controller.extraHoldCondition) {
                controller.transientOpen = false;
                controller.open = false;
            }

        }
    }

}
