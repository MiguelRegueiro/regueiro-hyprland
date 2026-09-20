import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme/Theme.js" as Theme
import "../quicksettings" as QuickSettings

PanelWindow {
    id: root

    required property var targetScreen
    required property var notificationStore
    required property var audioService
    required property var brightnessService
    required property var networkService
    property bool hasBar: true
    property bool quickSettingsVisible: false
    property bool forceOverlay: false
    readonly property bool quickSettingsHovered: quickSettingsPanel.hovered
    readonly property real topY: hasBar ? Theme.barHeight - Theme.frameTopOverlap : 0
    readonly property real innerTopY: hasBar ? Theme.barHeight - Theme.frameTopOverlap : Theme.borderSize
    readonly property real quickSettingsRegionX: quickSettingsPanel.x + quickSettingsPanel.inputRegion.x
    readonly property real quickSettingsRegionY: quickSettingsPanel.y + quickSettingsPanel.inputRegion.y
    readonly property real quickSettingsRegionWidth: quickSettingsPanel.inputRegion.width
    readonly property real quickSettingsRegionHeight: quickSettingsPanel.inputRegion.height

    signal outsidePressed()
    signal barPressed(real x, real y)
    signal powerActionRequested(string actionId)

    function routeBarPress(mouse) {
        if (mouse.button !== Qt.LeftButton || mouse.y < 0 || mouse.y >= Theme.barHeight)
            return false;

        root.barPressed(mouse.x, mouse.y);
        return true;
    }


    screen: targetScreen
    visible: root.quickSettingsVisible || root.forceOverlay || quickSettingsPanel.reveal > 0.001
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: root.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-border"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Registers a zwp_text_input_v3 context for this surface so fcitx5 keeps
    // ShareInputState=All active when this layer-shell window gets keyboard focus,
    // instead of deactivating the IM due to "no text-input client".
    // Real text fields (WiFi password etc.) steal focus from this when clicked.
    TextInput {
        width: 1
        height: 1
        opacity: 0
        focus: true
        cursorVisible: false
        color: "transparent"
        selectionColor: "transparent"
        onTextChanged: clear()
    }





    Item {
        visible: root.quickSettingsVisible
        anchors.fill: parent

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(root.quickSettingsRegionY))
            onPressed: (mouse) => {
                if (root.forceOverlay && root.routeBarPress(mouse))
                    return ;

                root.outsidePressed();
            }
        }

        MouseArea {
            x: 0
            y: Math.max(0, Math.round(root.quickSettingsRegionY))
            width: Math.max(0, Math.round(root.quickSettingsRegionX))
            height: Math.max(0, Math.round(root.quickSettingsRegionHeight))
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: Math.round(root.quickSettingsRegionX + root.quickSettingsRegionWidth)
            y: Math.max(0, Math.round(root.quickSettingsRegionY))
            width: Math.max(0, Math.round(parent.width - (root.quickSettingsRegionX + root.quickSettingsRegionWidth)))
            height: Math.max(0, Math.round(root.quickSettingsRegionHeight))
            onPressed: root.outsidePressed()
        }

        MouseArea {
            x: 0
            y: Math.round(root.quickSettingsRegionY + root.quickSettingsRegionHeight)
            width: parent.width
            height: Math.max(0, Math.round(parent.height - (root.quickSettingsRegionY + root.quickSettingsRegionHeight)))
            onPressed: root.outsidePressed()
        }

    }

    QuickSettings.QuickSettingsPanel {
        id: quickSettingsPanel

        open: root.quickSettingsVisible
        topOffset: Theme.barHeight + 22
        notificationStore: root.notificationStore
        audioService: root.audioService
        brightnessService: root.brightnessService
        networkService: root.networkService
        onPowerActionRequested: (actionId) => {
            return root.powerActionRequested(actionId);
        }
    }

    mask: Region {
        Region {
            x: 0
            y: root.forceOverlay ? 0 : Theme.barHeight
            width: root.quickSettingsVisible ? Math.round(root.width) : 0
            height: root.quickSettingsVisible ? Math.max(0, Math.round(root.height - (root.forceOverlay ? 0 : Theme.barHeight))) : 0
        }

    }

}
