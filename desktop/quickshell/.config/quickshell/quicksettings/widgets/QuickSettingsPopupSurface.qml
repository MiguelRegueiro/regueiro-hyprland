import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../components" as Components
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Item {
    id: root

    required property real surfaceX
    required property real surfaceY
    required property var targetScreen
    property string surfaceNamespace: "qs-popup"
    property bool open: false
    property bool keyboardFocus: false
    property real reveal: 0
    property real cornerRadius: QS.popupSurfaceRadius
    property real revealOffset: QS.popupSurfaceRevealOffset
    default property alias content: contentHost.data

    visible: reveal > 0.001
    opacity: 1
    transform: Translate {
        y: -(1 - root.reveal) * root.revealOffset
    }
    state: open ? "open" : ""
    transitions: [
        Transition {
            from: ""
            to: "open"
            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedDecel
                duration: Theme.panelOpenDuration
            }
        },
        Transition {
            from: "open"
            to: ""
            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedAccel
                duration: Theme.panelCloseDuration
            }
        }
    ]

    PanelWindow {
        id: popupSurface

        screen: root.targetScreen
        visible: root.visible
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: root.surfaceNamespace
        WlrLayershell.keyboardFocus: root.keyboardFocus && root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }

        mask: Region {
            x: Math.round(root.surfaceX)
            y: Math.round(root.surfaceY)
            width: Math.round(root.width)
            height: Math.round(root.height)
        }

        Rectangle {
            x: Math.round(root.surfaceX)
            y: Math.round(root.surfaceY)
            width: root.width
            height: root.height
            radius: root.cornerRadius
            color: QS.popupSurfaceBg
            border.color: QS.popupSurfaceOutline
            border.width: 1
            clip: true
            layer.enabled: true

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: QS.popupSurfaceShadow
                shadowBlur: QS.popupSurfaceShadowBlur
                shadowVerticalOffset: QS.popupSurfaceShadowOffsetY
                shadowHorizontalOffset: 0
                blurMax: QS.popupSurfaceBlurMax
            }

            Item {
                id: contentHost
                anchors.fill: parent
            }
        }
    }

    states: State {
        name: "open"
        PropertyChanges {
            root.reveal: 1
        }
    }
}
