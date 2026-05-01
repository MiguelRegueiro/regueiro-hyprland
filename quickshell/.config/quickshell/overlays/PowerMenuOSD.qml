import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    property bool active: true
    property bool open: false
    property string mode: "menu"
    property string actionId: ""
    property string busyAction: ""
    property int selectedIndex: 0
    property int selectedConfirmIndex: 0
    readonly property var actions: [{
        "actionId": "lock",
        "label": "Lock",
        "icon": "\uf023",
        "iconOffsetX": 0,
        "iconPixelSize": 21
    }, {
        "actionId": "suspend",
        "label": "Suspend",
        "icon": "\udb81\udd94",
        "iconOffsetX": 0,
        "iconPixelSize": 21
    }, {
        "actionId": "logout",
        "label": "Log Out",
        "icon": "\uf08b",
        "iconOffsetX": 1,
        "iconPixelSize": 22
    }, {
        "actionId": "reboot",
        "label": "Reboot",
        "icon": "\uf2f9",
        "iconOffsetX": 1,
        "iconPixelSize": 21
    }, {
        "actionId": "shutdown",
        "label": "Shut Down",
        "icon": "\uf011",
        "iconOffsetX": 0,
        "iconPixelSize": 21
    }]
    readonly property int pad: 14
    readonly property int itemGap: 8
    readonly property int itemW: Math.max(58, Math.min(92, Math.floor((Math.max(360, root.width) - 48 - root.pad * 2 - root.itemGap * (root.actions.length - 1)) / root.actions.length)))
    readonly property int itemH: 94
    readonly property int menuW: root.pad * 2 + root.itemW * root.actions.length + root.itemGap * (root.actions.length - 1)
    readonly property int menuH: root.pad * 2 + root.itemH
    readonly property int confirmW: Math.min(292, Math.max(268, root.width - 64))
    readonly property int confirmH: 136
    readonly property int confirmButtonW: 112
    readonly property int confirmButtonH: 42
    readonly property int confirmButtonGap: 8

    signal actionRequested(string actionId)
    signal confirmRequested()
    signal cancelRequested()

    function actionLabel(id) {
        if (id === "lock")
            return "Lock";

        if (id === "suspend")
            return "Suspend";

        if (id === "logout")
            return "Log Out";

        if (id === "reboot")
            return "Reboot";

        if (id === "shutdown")
            return "Shut Down";

        return "System";
    }

    function actionIcon(id) {
        for (let i = 0; i < root.actions.length; ++i) {
            if (root.actions[i].actionId === id)
                return root.actions[i].icon;

        }
        return "\uf011";
    }

    function actionIconSize(id) {
        for (let i = 0; i < root.actions.length; ++i) {
            if (root.actions[i].actionId === id)
                return root.actions[i].iconPixelSize;

        }
        return 21;
    }

    function actionIconOffset(id) {
        for (let i = 0; i < root.actions.length; ++i) {
            if (root.actions[i].actionId === id)
                return root.actions[i].iconOffsetX || 0;

        }
        return 0;
    }

    function selectedAction() {
        const index = Math.max(0, Math.min(root.actions.length - 1, root.selectedIndex));
        return root.actions[index];
    }

    function moveSelection(delta) {
        if (root.mode === "confirm") {
            root.selectedConfirmIndex = (root.selectedConfirmIndex + delta + 2) % 2;
            return ;
        }
        root.selectedIndex = (root.selectedIndex + delta + root.actions.length) % root.actions.length;
    }

    function activateSelection() {
        if (root.busyAction !== "")
            return ;

        if (root.mode === "confirm") {
            if (root.selectedConfirmIndex === 0)
                root.cancelRequested();
            else
                root.confirmRequested();
            return ;
        }
        const action = root.selectedAction();
        if (action)
            root.actionRequested(action.actionId);

    }

    onOpenChanged: {
        if (open) {
            if (mode === "confirm")
                selectedConfirmIndex = 0;
            else
                selectedIndex = 0;
            Qt.callLater(function() {
                keyScope.forceActiveFocus();
            });
        }
    }
    onModeChanged: {
        if (mode === "confirm")
            selectedConfirmIndex = 0;

    }
    screen: targetScreen
    visible: root.active && root.open
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-power-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.open

        Shortcut {
            sequence: "Left"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.moveSelection(-1)
        }

        Shortcut {
            sequence: "Right"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.moveSelection(1)
        }

        Shortcut {
            sequence: "Up"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.moveSelection(-1)
        }

        Shortcut {
            sequence: "Down"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.moveSelection(1)
        }

        Shortcut {
            sequence: "Tab"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.moveSelection(1)
        }

        Shortcut {
            sequence: "Backtab"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.moveSelection(-1)
        }

        Shortcut {
            sequence: "Return"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.activateSelection()
        }

        Shortcut {
            sequence: "Enter"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.activateSelection()
        }

        Shortcut {
            sequence: "Space"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.activateSelection()
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: root.open
            onActivated: root.cancelRequested()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.cancelRequested()
        }

        Rectangle {
            id: osdCard

            anchors.centerIn: parent
            width: root.mode === "confirm" ? root.confirmW : root.menuW
            height: root.mode === "confirm" ? root.confirmH : root.menuH
            radius: 22
            color: Theme.popupBg
            border.color: Theme.barBorder
            border.width: 1
            layer.enabled: true

            Item {
                id: menuView

                anchors.fill: parent
                visible: root.mode === "menu"

                Rectangle {
                    id: selector

                    x: root.pad + root.selectedIndex * (root.itemW + root.itemGap)
                    y: root.pad
                    width: root.itemW
                    height: root.itemH
                    radius: 12
                    color: Theme.activeBg
                }

                Row {
                    x: root.pad
                    y: root.pad
                    spacing: root.itemGap

                    Repeater {
                        model: root.actions

                        delegate: Item {
                            id: actionTile

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.selectedIndex === index
                            readonly property bool busy: root.busyAction === modelData.actionId

                            width: root.itemW
                            height: root.itemH

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                spacing: 7

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.horizontalCenterOffset: modelData.iconOffsetX || 0
                                    text: actionTile.busy ? "\uf110" : modelData.icon
                                    font.family: Theme.fontIcons
                                    font.pixelSize: modelData.iconPixelSize || 21
                                    color: actionTile.selected ? Theme.textPrimary : Theme.textDim
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    text: modelData.label
                                    font.family: Theme.fontUi
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: actionTile.selected ? Theme.textPrimary : Theme.textDisabled
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.busyAction === "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    if (root.busyAction === "")
                                        root.actionRequested(modelData.actionId);

                                }
                            }

                        }

                    }

                }

            }

            Item {
                id: confirmView

                anchors.fill: parent
                visible: root.mode === "confirm"

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 28
                    spacing: 18

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.confirmButtonW * 2 + root.confirmButtonGap
                        text: root.actionLabel(root.actionId)
                        font.family: Theme.fontUi
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.confirmButtonW * 2 + root.confirmButtonGap
                        Layout.preferredHeight: root.confirmButtonH

                        Rectangle {
                            x: root.selectedConfirmIndex * (root.confirmButtonW + root.confirmButtonGap)
                            width: root.confirmButtonW
                            height: root.confirmButtonH
                            radius: root.confirmButtonH / 2
                            color: Theme.activeBg
                        }

                        Row {
                            spacing: root.confirmButtonGap

                            Repeater {
                                model: [{
                                    "label": "Cancel",
                                    "confirm": false
                                }, {
                                    "label": "Confirm",
                                    "confirm": true
                                }]

                                delegate: Rectangle {
                                    id: confirmButton

                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: root.selectedConfirmIndex === index

                                    width: root.confirmButtonW
                                    height: root.confirmButtonH
                                    radius: height / 2
                                    color: confirmMouse.containsMouse && !confirmButton.selected ? Theme.hoverBg : "transparent"
                                    border.width: 1
                                    border.color: confirmButton.selected ? Qt.rgba(1, 1, 1, 0.12) : Theme.barBorder

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontUi
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: confirmButton.selected ? Theme.textPrimary : Theme.textDim
                                    }

                                    MouseArea {
                                        id: confirmMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.confirm)
                                                root.confirmRequested();
                                            else
                                                root.cancelRequested();
                                        }
                                    }

                                }

                            }

                        }

                    }

                }

            }

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.82)
                shadowBlur: 0.7
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
                blurMax: 56
            }

        }

    }

    mask: Region {
        Region {
            x: 0
            y: 0
            width: root.open ? Math.round(root.width) : 0
            height: root.open ? Math.round(root.height) : 0
        }

    }

}
