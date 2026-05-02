import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme/Theme.js" as Theme
import "../quicksettings" as QuickSettings

PanelWindow {
    id: root

    required property var targetScreen
    required property var notificationStore
    required property var audioService
    required property var brightnessService
    property bool hasBar: true
    property bool quickSettingsVisible: false
    property bool quickSettingsCursorInside: false
    property bool forceOverlay: false
    readonly property bool quickSettingsHovered: quickSettingsPanel.hovered || root.quickSettingsCursorInside
    readonly property real topY: hasBar ? Theme.barHeight : 0
    readonly property real innerTopY: hasBar ? Theme.barHeight : Theme.borderSize
    readonly property real quickSettingsRegionX: quickSettingsPanel.x + quickSettingsPanel.inputRegion.x
    readonly property real quickSettingsRegionY: quickSettingsPanel.y + quickSettingsPanel.inputRegion.y
    readonly property real quickSettingsRegionWidth: quickSettingsPanel.inputRegion.width
    readonly property real quickSettingsRegionHeight: quickSettingsPanel.inputRegion.height

    signal outsidePressed()
    signal powerActionRequested(string actionId)

    function updateQuickSettingsCursor(rawText) {
        const match = rawText.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
        if (!match) {
            root.quickSettingsCursorInside = false;
            return ;
        }
        const cursorX = Number(match[1]);
        const cursorY = Number(match[2]);
        const panelLeft = Number(root.targetScreen.x) + quickSettingsPanel.x - 18;
        const panelTop = Number(root.targetScreen.y) + quickSettingsPanel.y - 18;
        const panelRight = panelLeft + quickSettingsPanel.width + 36;
        const panelBottom = panelTop + quickSettingsPanel.height + 36;
        const barTriggerLeft = Number(root.targetScreen.x) + quickSettingsPanel.x;
        const inBarTrigger = cursorY >= Number(root.targetScreen.y) && cursorY < Number(root.targetScreen.y) + Theme.barHeight && cursorX >= barTriggerLeft;
        root.quickSettingsCursorInside = root.quickSettingsVisible && (inBarTrigger || (cursorX >= panelLeft && cursorX <= panelRight && cursorY >= panelTop && cursorY <= panelBottom));
    }

    screen: targetScreen
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
        id: shadowSource

        anchors.fill: parent
        visible: false

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: "transparent"
                strokeColor: "black"
                strokeWidth: 4
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin

                PathMove {
                    x: Theme.borderSize + Theme.barCornerRadius
                    y: root.innerTopY
                }

                PathLine {
                    x: root.width - Theme.borderSize - Theme.barCornerRadius
                    y: root.innerTopY
                }

                PathQuad {
                    x: root.width - Theme.borderSize
                    y: root.innerTopY + Theme.barCornerRadius
                    controlX: root.width - Theme.borderSize
                    controlY: root.innerTopY
                }

                PathLine {
                    x: root.width - Theme.borderSize
                    y: root.height - Theme.borderSize - Theme.barCornerRadius
                }

                PathQuad {
                    x: root.width - Theme.borderSize - Theme.barCornerRadius
                    y: root.height - Theme.borderSize
                    controlX: root.width - Theme.borderSize
                    controlY: root.height - Theme.borderSize
                }

                PathLine {
                    x: Theme.borderSize + Theme.barCornerRadius
                    y: root.height - Theme.borderSize
                }

                PathQuad {
                    x: Theme.borderSize
                    y: root.height - Theme.borderSize - Theme.barCornerRadius
                    controlX: Theme.borderSize
                    controlY: root.height - Theme.borderSize
                }

                PathLine {
                    x: Theme.borderSize
                    y: root.innerTopY + Theme.barCornerRadius
                }

                PathQuad {
                    x: Theme.borderSize + Theme.barCornerRadius
                    y: root.innerTopY
                    controlX: Theme.borderSize
                    controlY: root.innerTopY
                }

            }

        }

    }

    Timer {
        interval: Theme.panelTickInterval
        running: root.quickSettingsVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cursorPosProc.running)
                cursorPosProc.running = true;

        }
    }

    Process {
        id: cursorPosProc

        command: ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            id: cursorPosOut

            onStreamFinished: root.updateQuickSettingsCursor(cursorPosOut.text.trim())
        }

    }

    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        horizontalOffset: 0
        verticalOffset: 0
        radius: 28
        samples: 57
        color: Qt.rgba(0, 0, 0, 0.5)
        spread: 0
        transparentBorder: true
        cached: true
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: Theme.screenFrameBg
            strokeColor: "transparent"
            strokeWidth: 0

            PathMove {
                x: 0
                y: root.topY
            }

            PathLine {
                x: root.width
                y: root.topY
            }

            PathLine {
                x: root.width
                y: root.height
            }

            PathLine {
                x: 0
                y: root.height
            }

            PathLine {
                x: 0
                y: root.topY
            }

            PathMove {
                x: Theme.borderSize + Theme.barCornerRadius
                y: root.innerTopY
            }

            PathLine {
                x: root.width - Theme.borderSize - Theme.barCornerRadius
                y: root.innerTopY
            }

            PathQuad {
                x: root.width - Theme.borderSize
                y: root.innerTopY + Theme.barCornerRadius
                controlX: root.width - Theme.borderSize
                controlY: root.innerTopY
            }

            PathLine {
                x: root.width - Theme.borderSize
                y: root.height - Theme.borderSize - Theme.barCornerRadius
            }

            PathQuad {
                x: root.width - Theme.borderSize - Theme.barCornerRadius
                y: root.height - Theme.borderSize
                controlX: root.width - Theme.borderSize
                controlY: root.height - Theme.borderSize
            }

            PathLine {
                x: Theme.borderSize + Theme.barCornerRadius
                y: root.height - Theme.borderSize
            }

            PathQuad {
                x: Theme.borderSize
                y: root.height - Theme.borderSize - Theme.barCornerRadius
                controlX: Theme.borderSize
                controlY: root.height - Theme.borderSize
            }

            PathLine {
                x: Theme.borderSize
                y: root.innerTopY + Theme.barCornerRadius
            }

            PathQuad {
                x: Theme.borderSize + Theme.barCornerRadius
                y: root.innerTopY
                controlX: Theme.borderSize
                controlY: root.innerTopY
            }

        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 1, 1, 0.08)
            strokeWidth: 1.2
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin

            // Top edge: shrinks toward fillet start as QS panel reveals
            PathMove {
                x: Theme.borderSize + Theme.barCornerRadius
                y: root.innerTopY
            }

            PathLine {
                x: (root.width - Theme.borderSize - Theme.barCornerRadius) * (1 - quickSettingsPanel.revealProgress) + quickSettingsPanel.x * quickSettingsPanel.revealProgress
                y: root.innerTopY
            }

            PathQuad {
                x: root.width - Theme.borderSize
                y: root.innerTopY + Theme.barCornerRadius
                controlX: root.width - Theme.borderSize
                controlY: root.innerTopY
            }
            // Right edge: first segment ends at panel bottom when QS reveals, then jumps over fillet

            PathLine {
                x: root.width - Theme.borderSize
                y: (root.height - Theme.borderSize - Theme.barCornerRadius) * (1 - quickSettingsPanel.revealProgress) + (quickSettingsPanel.y + quickSettingsPanel.bodyHeight) * quickSettingsPanel.revealProgress
            }

            PathMove {
                x: root.width - Theme.borderSize
                y: (root.height - Theme.borderSize - Theme.barCornerRadius) * (1 - quickSettingsPanel.revealProgress) + (quickSettingsPanel.y + quickSettingsPanel.bodyHeight + Theme.barCornerRadius) * quickSettingsPanel.revealProgress
            }

            PathLine {
                x: root.width - Theme.borderSize
                y: root.height - Theme.borderSize - Theme.barCornerRadius
            }

            PathQuad {
                x: root.width - Theme.borderSize - Theme.barCornerRadius
                y: root.height - Theme.borderSize
                controlX: root.width - Theme.borderSize
                controlY: root.height - Theme.borderSize
            }

            PathLine {
                x: Theme.borderSize + Theme.barCornerRadius
                y: root.height - Theme.borderSize
            }

            PathQuad {
                x: Theme.borderSize
                y: root.height - Theme.borderSize - Theme.barCornerRadius
                controlX: Theme.borderSize
                controlY: root.height - Theme.borderSize
            }

            PathLine {
                x: Theme.borderSize
                y: root.innerTopY + Theme.barCornerRadius
            }

            PathQuad {
                x: Theme.borderSize + Theme.barCornerRadius
                y: root.innerTopY
                controlX: Theme.borderSize
                controlY: root.innerTopY
            }

        }

    }

    Item {
        visible: root.quickSettingsVisible
        anchors.fill: parent

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, Math.round(root.quickSettingsRegionY))
            onPressed: root.outsidePressed()
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
        topOffset: root.innerTopY - Theme.qsBarFuseOverlap - 2
        notificationStore: root.notificationStore
        audioService: root.audioService
        brightnessService: root.brightnessService
        onPowerActionRequested: (actionId) => {
            return root.powerActionRequested(actionId);
        }
    }

    mask: Region {
        Region {
            item: quickSettingsPanel.inputRegion
        }

        Region {
            x: 0
            y: 0
            width: root.quickSettingsVisible ? Math.round(root.width) : 0
            height: root.quickSettingsVisible ? Math.max(0, Math.round(root.quickSettingsRegionY)) : 0
        }

        Region {
            x: 0
            y: Math.max(0, Math.round(root.quickSettingsRegionY))
            width: root.quickSettingsVisible ? Math.max(0, Math.round(root.quickSettingsRegionX)) : 0
            height: root.quickSettingsVisible ? Math.max(0, Math.round(root.quickSettingsRegionHeight)) : 0
        }

        Region {
            x: Math.round(root.quickSettingsRegionX + root.quickSettingsRegionWidth)
            y: Math.max(0, Math.round(root.quickSettingsRegionY))
            width: root.quickSettingsVisible ? Math.max(0, Math.round(root.width - (root.quickSettingsRegionX + root.quickSettingsRegionWidth))) : 0
            height: root.quickSettingsVisible ? Math.max(0, Math.round(root.quickSettingsRegionHeight)) : 0
        }

        Region {
            x: 0
            y: Math.round(root.quickSettingsRegionY + root.quickSettingsRegionHeight)
            width: root.quickSettingsVisible ? Math.round(root.width) : 0
            height: root.quickSettingsVisible ? Math.max(0, Math.round(root.height - (root.quickSettingsRegionY + root.quickSettingsRegionHeight))) : 0
        }

    }

}
