import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Item {
    id: root

    required property var displayService
    property bool menuOpen: false
    property bool showHeader: true
    property string selectedOutput: ""
    property var dragPosition: null
    property var dropPreview: null
    property var pendingPositions: null
    readonly property var selectedMonitor: displayService.monitors.find(m => m.name === (selectedOutput || displayService.primary)) || displayService.monitors[0] || null
    readonly property real layoutMinX: displayService.monitors.length > 0 ? Math.min.apply(null, displayService.monitors.map(monitor => monitorX(monitor))) : 0
    readonly property real layoutMinY: displayService.monitors.length > 0 ? Math.min.apply(null, displayService.monitors.map(monitor => monitorY(monitor))) : 0
    readonly property real layoutMaxX: displayService.monitors.length > 0 ? Math.max.apply(null, displayService.monitors.map(monitor => monitorX(monitor) + monitor.width / Math.max(1, monitor.scale))) : 1
    readonly property real layoutMaxY: displayService.monitors.length > 0 ? Math.max.apply(null, displayService.monitors.map(monitor => monitorY(monitor) + monitor.height / Math.max(1, monitor.scale))) : 1
    readonly property real stackedHeight: displayService.monitors.reduce((sum, monitor) => sum + monitor.height / Math.max(1, monitor.scale), 0)
    readonly property real layoutScale: Math.min(0.14, (layoutCanvas.width - 64) / Math.max(1, layoutMaxX - layoutMinX), (layoutCanvas.height - 86) / Math.max(1, layoutMaxY - layoutMinY, displayService.monitors.length === 2 ? stackedHeight : 1))
    readonly property real layoutOffsetX: Math.max(16, (layoutCanvas.width - (layoutMaxX - layoutMinX) * layoutScale) / 2)
    readonly property real layoutOffsetY: 36 + Math.max(8, (layoutCanvas.height - 44 - (layoutMaxY - layoutMinY) * layoutScale) / 2)
    readonly property var orientations: [
        { transform: 0, label: "Landscape (0°)" },
        { transform: 2, label: "Landscape (180°)" },
        { transform: 1, label: "Portrait (90°)" },
        { transform: 3, label: "Portrait (270°)" }
    ]

    signal backClicked

    function monitorX(monitor) {
        return pendingPositions && pendingPositions[monitor.name] ? pendingPositions[monitor.name].x : monitor.x;
    }

    function monitorY(monitor) {
        return pendingPositions && pendingPositions[monitor.name] ? pendingPositions[monitor.name].y : monitor.y;
    }

    function workspaceLabel(output) {
        if (!output)
            return "";
        if (displayService.monitors.length === 1)
            return "Workspaces 1+";
        if (output === displayService.primary)
            return "Workspaces 1–9";
        if (output.indexOf("eDP-") === 0)
            return displayService.monitors.length > 2 ? "Workspaces 20+" : "Workspaces 10+";
        return "Workspaces 10–19";
    }

    function orientationLabel(transform) {
        const option = orientations.find(item => item.transform === transform);
        if (option)
            return option.label;
        if (transform >= 4 && transform <= 7)
            return "Flipped (" + [0, 90, 180, 270][transform - 4] + "°)";
        return "Orientation";
    }

    function alignedOffset(desired, start, otherSize, movedSize) {
        const alignments = [start, start + (otherSize - movedSize) / 2, start + otherSize - movedSize];
        return alignments.reduce((nearest, value) => Math.abs(value - desired) < Math.abs(nearest - desired) ? value : nearest, alignments[0]);
    }

    function placementForDrag(moved, dragX, dragY) {
        if (Math.max(Math.abs(dragX), Math.abs(dragY)) < 30)
            return null;
        const monitors = displayService.monitors;
        const width = moved.width / Math.max(1, moved.scale);
        const height = moved.height / Math.max(1, moved.scale);
        const desiredX = moved.x + dragX / layoutScale;
        const desiredY = moved.y + dragY / layoutScale;
        const others = monitors.filter(monitor => monitor.name !== moved.name);
        others.sort((a, b) => {
            function distance(monitor) {
                const cx = monitor.x + monitor.width / Math.max(1, monitor.scale) / 2;
                const cy = monitor.y + monitor.height / Math.max(1, monitor.scale) / 2;
                return (cx - desiredX - width / 2) ** 2 + (cy - desiredY - height / 2) ** 2;
            }
            return distance(a) - distance(b);
        });
        for (const other of others) {
            const ow = other.width / Math.max(1, other.scale);
            const oh = other.height / Math.max(1, other.scale);
            const centerX = desiredX + width / 2 - (other.x + ow / 2);
            const centerY = desiredY + height / 2 - (other.y + oh / 2);
            const horizontalScore = Math.abs(centerX) / ((width + ow) / 2);
            const verticalScore = Math.abs(centerY) / ((height + oh) / 2);
            const direction = horizontalScore >= verticalScore
                ? (centerX < 0 ? "left" : "right")
                : (centerY < 0 ? "above" : "below");
            const x = direction === "left" ? other.x - width
                    : direction === "right" ? other.x + ow
                    : alignedOffset(desiredX, other.x, ow, width);
            const y = direction === "above" ? other.y - height
                    : direction === "below" ? other.y + oh
                    : alignedOffset(desiredY, other.y, oh, height);
            const collides = others.some(monitor => {
                const mw = monitor.width / Math.max(1, monitor.scale);
                const mh = monitor.height / Math.max(1, monitor.scale);
                return x < monitor.x + mw - 1 && monitor.x < x + width - 1 &&
                       y < monitor.y + mh - 1 && monitor.y < y + height - 1;
            });
            if (!collides)
                return { x: x, y: y, direction: direction, target: other.name };
        }
        return null;
    }

    function snapLayout(moved, best) {
        if (!best)
            return;
        const monitors = displayService.monitors;
        const positions = {};
        const pending = {};
        const minX = Math.min(best.x, ...monitors.filter(m => m.name !== moved.name).map(m => m.x));
        const minY = Math.min(best.y, ...monitors.filter(m => m.name !== moved.name).map(m => m.y));
        for (const monitor of monitors) {
            const x = monitor.name === moved.name ? best.x : monitor.x;
            const y = monitor.name === moved.name ? best.y : monitor.y;
            pending[monitor.name] = { x: x, y: y };
            positions[monitor.name] = Math.round(x - minX) + "x" + Math.round(y - minY);
        }
        pendingPositions = pending;
        displayService.setLayout(positions);
    }

    Connections {
        target: root.displayService
        function onMonitorsChanged() {
            if (root.pendingPositions && !root.displayService.busy)
                root.pendingPositions = null;
        }
    }

    implicitHeight: 620

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Rectangle {
            visible: root.showHeader
            Layout.fillWidth: true
            border.color: QS.cardBorder
            border.width: 1
            color: QS.cardBg
            Layout.preferredHeight: 52
            radius: 18

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 12
                spacing: 8

                Rectangle {
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 44
                    radius: 22
                    color: backHover.hovered ? QS.chipBgHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        color: Theme.textPrimary
                        font.family: Theme.fontIcons
                        font.pixelSize: 18
                        text: "󰁍"
                    }
                    HoverHandler { id: backHover; blocking: false; cursorShape: Qt.ArrowCursor }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; onClicked: root.backClicked() }
                }
                Text {
                    Layout.fillWidth: true
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    text: "Settings"
                }
                Text {
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    text: root.displayService.displayCount + " connected"
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        label: "Extend",
                        mode: "extend",
                        icon: "󰹑"
                    },
                    {
                        label: "Duplicate",
                        mode: "duplicate",
                        icon: "󰌢"
                    }
                ]

                delegate: Rectangle {
                    readonly property bool active: root.displayService.mode === modelData.mode
                    required property var modelData

                    Layout.fillWidth: true
                    border.color: active ? QS.tileActiveBorder : QS.cardBorder
                    border.width: 1
                    color: active ? QS.tileActiveBg : QS.cardBg
                    height: 54
                    radius: 16

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            color: parent.parent.active ? "white" : Theme.textPrimary
                            font.family: Theme.fontIcons
                            font.pixelSize: 17
                            text: parent.parent.modelData.icon
                        }
                        Text {
                            color: parent.parent.active ? "white" : Theme.textPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            text: parent.parent.modelData.label
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.ArrowCursor
                        enabled: !root.displayService.busy

                        onClicked: root.displayService.setMode(parent.modelData.mode)
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            border.color: QS.cardBorder
            border.width: 1
            color: QS.cardBg
            Layout.preferredHeight: 44
            radius: 14

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8

                Text {
                    Layout.fillWidth: true
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    text: "Blackout displays"
                }
                Text {
                    color: Theme.textDim
                font.family: Theme.fontUi
                    font.pixelSize: 10
                    text: "Super+Shift+S"
                }
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: blackoutHover.hovered ? QS.chipBgHover : QS.chipBg

                    Text {
                        anchors.centerIn: parent
                        color: Theme.textPrimary
                        font.family: Theme.fontIcons
                        font.pixelSize: 15
                        text: "󰖨"
                    }
                    HoverHandler { id: blackoutHover; blocking: false; cursorShape: Qt.ArrowCursor }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; onClicked: root.displayService.toggleDpms() }
                }
            }
        }
        Rectangle {
            id: layoutCanvas

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 300
            clip: true
            color: QS.cardBg
            radius: 16
            border.width: 1
            border.color: QS.cardBorder

            Text {
                visible: root.displayService.mode === "extend"
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.topMargin: 10
                text: "Arrange displays"
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Theme.textDim
            }

            Text {
                visible: root.displayService.mode === "extend"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 12
                anchors.topMargin: 10
                text: "Drag to arrange · Release to snap"
                font.family: Theme.fontUi
                font.pixelSize: 10
                color: Theme.textDisabled
            }

            Repeater {
                model: root.displayService.monitors

                delegate: Rectangle {
                    id: layoutMonitor

                    required property int index
                    required property var modelData
                    readonly property bool primary: modelData.name === root.displayService.primary
                    readonly property bool selected: root.selectedMonitor && modelData.name === root.selectedMonitor.name
                    readonly property real logicalWidth: modelData.width / Math.max(1, modelData.scale)
                    readonly property real logicalHeight: modelData.height / Math.max(1, modelData.scale)
                    readonly property real baseX: root.layoutOffsetX + (root.monitorX(modelData) - root.layoutMinX) * root.layoutScale
                    readonly property real baseY: root.layoutOffsetY + (root.monitorY(modelData) - root.layoutMinY) * root.layoutScale

                    x: Math.round(baseX + (root.dragPosition && root.dragPosition.name === modelData.name ? root.dragPosition.dx : 0))
                    y: Math.round(baseY + (root.dragPosition && root.dragPosition.name === modelData.name ? root.dragPosition.dy : 0))
                    visible: root.displayService.mode === "extend"
                    width: Math.max(80, Math.round(logicalWidth * root.layoutScale))
                    height: Math.max(72, Math.round(logicalHeight * root.layoutScale))
                    radius: 12
                    color: selected ? Qt.rgba(0.24, 0.39, 0.69, 0.83) : Qt.rgba(0.19, 0.21, 0.25, 0.95)
                    border.width: selected ? 2 : 1
                    border.color: selected ? Theme.blue : QS.cardBorderHover
                    z: dragArea.pressed ? 2 : 1

                    Behavior on x { enabled: !dragArea.pressed; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !dragArea.pressed; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                    Text {
                        visible: layoutMonitor.primary
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 9
                        anchors.rightMargin: 11
                        text: "Primary"
                        color: layoutMonitor.selected ? Theme.textPrimary : Theme.blue
                        font.family: Theme.fontUi
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: layoutMonitor.index + 1
                            font.family: Theme.fontUi
                            font.pixelSize: 29
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: layoutMonitor.modelData.name
                            font.family: Theme.fontUi
                            font.pixelSize: 10
                            color: Theme.textDim
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        width: workspaceText.implicitWidth + 14
                        height: 18
                        radius: 9
                        color: primary ? Qt.rgba(1, 1, 1, 0.16) : QS.cardBg

                        Text {
                            id: workspaceText

                            anchors.centerIn: parent
                            text: root.workspaceLabel(modelData.name)
                            font.family: Theme.fontUi
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: primary ? "white" : Theme.textDim
                        }
                    }

                    MouseArea {
                        id: dragArea

                        property var pressPoint: null

                        anchors.fill: parent
                        enabled: root.displayService.mode === "extend" && !root.displayService.busy
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        onPressed: mouse => {
                            pressPoint = layoutMonitor.mapToItem(layoutCanvas, mouse.x, mouse.y);
                            root.selectedOutput = modelData.name;
                            root.dragPosition = { name: modelData.name, dx: 0, dy: 0 };
                            root.dropPreview = null;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || !pressPoint)
                                return;
                            const point = layoutMonitor.mapToItem(layoutCanvas, mouse.x, mouse.y);
                            const dx = point.x - pressPoint.x;
                            const dy = point.y - pressPoint.y;
                            root.dragPosition = { name: modelData.name, dx: dx, dy: dy };
                            root.dropPreview = root.placementForDrag(modelData, dx, dy);
                        }
                        onReleased: {
                            if (root.dropPreview)
                                root.snapLayout(modelData, root.dropPreview);
                            root.dragPosition = null;
                            root.dropPreview = null;
                            pressPoint = null;
                        }
                        onCanceled: {
                            root.dragPosition = null;
                            root.dropPreview = null;
                            pressPoint = null;
                        }
                    }
                }
            }

            Rectangle {
                visible: root.displayService.mode === "duplicate" && root.displayService.monitors.length > 0
                width: Math.min(280, parent.width - 64)
                height: 150
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2 + 8)
                radius: 14
                color: Qt.rgba(0.24, 0.39, 0.69, 0.83)
                border.width: 2
                border.color: Theme.blue

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Repeater {
                        model: root.displayService.monitors.length

                        delegate: Row {
                            required property int index
                            spacing: 12

                            Item {
                                visible: parent.index > 0
                                width: visible ? 1 : 0
                                height: 40

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 1
                                    height: 19
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                }
                            }
                            Text {
                                text: parent.index + 1
                                font.family: Theme.fontUi
                                font.pixelSize: 33
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: dropHint.implicitWidth + 24
                height: 26
                radius: 13
                color: Qt.rgba(0.13, 0.2, 0.34, 0.95)
                border.color: Theme.blue
                border.width: 1
                visible: root.displayService.mode === "extend" && root.dropPreview !== null
                z: 3

                Text {
                    id: dropHint
                    anchors.centerIn: parent
                    text: root.dropPreview ? "Place " + root.dropPreview.direction + " " + root.dropPreview.target : ""
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            visible: root.displayService.mode === "extend" && root.selectedMonitor !== null
            color: QS.cardBg
            radius: 16
            border.width: 1
            border.color: QS.cardBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.selectedMonitor ? (root.selectedMonitor.description || root.selectedMonitor.name) : ""
                        elide: Text.ElideRight
                        color: Theme.textPrimary
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.selectedMonitor && root.selectedMonitor.name === root.displayService.primary ? "Primary display" : ""
                        color: Theme.blue
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                    }
                }
                Text {
                    text: root.selectedMonitor ? (root.selectedMonitor.width + " × " + root.selectedMonitor.height + "  ·  " + Math.round(root.selectedMonitor.refreshRate) + " Hz  ·  " + Math.round(root.selectedMonitor.scale * 100) + "% scale") : ""
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.workspaceLabel(root.selectedMonitor ? root.selectedMonitor.name : "")
                        color: Theme.textDim
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                    }
                    Rectangle {
                        visible: root.selectedMonitor && root.selectedMonitor.name !== root.displayService.primary
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 26
                        radius: 13
                        color: primaryHover.hovered ? QS.chipBgHover : QS.chipBg
                        Text { anchors.centerIn: parent; text: "Make primary"; color: Theme.textPrimary; font.family: Theme.fontUi; font.pixelSize: 11 }
                        HoverHandler { id: primaryHover; cursorShape: Qt.ArrowCursor }
                        MouseArea { anchors.fill: parent; enabled: parent.visible && !root.displayService.busy; onClicked: root.displayService.setPrimary(root.selectedMonitor.name) }
                    }
                }
            }
        }
        Rectangle {
            id: orientationRow
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: root.selectedMonitor !== null && root.displayService.mode === "extend"
            color: QS.cardBg
            radius: 16
            border.width: 1
            border.color: QS.cardBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                Text { Layout.fillWidth: true; text: "Orientation"; color: Theme.textPrimary; font.family: Theme.fontUi; font.pixelSize: 12 }
                Rectangle {
                    Layout.preferredWidth: 172
                    Layout.preferredHeight: 32
                    radius: 10
                    color: rotateHover.hovered ? QS.chipBgHover : QS.chipBg
                    Text {
                        anchors.centerIn: parent
                        text: root.orientationLabel(root.selectedMonitor ? root.selectedMonitor.transform : 0) + "  ⌄"
                        color: Theme.textPrimary
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                    }
                    HoverHandler { id: rotateHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectedMonitor !== null && !root.displayService.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: orientationMenu.open()
                    }
                }
            }

            Controls.Popup {
                id: orientationMenu
                parent: orientationRow
                x: orientationRow.width - width - 10
                y: -height - 6
                width: 194
                padding: 6
                closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

                background: Rectangle {
                    radius: 12
                    color: "#282c34"
                    border.width: 1
                    border.color: QS.cardBorderHover
                }

                contentItem: Column {
                    spacing: 2

                    Repeater {
                        model: root.orientations

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: root.selectedMonitor && root.selectedMonitor.transform === modelData.transform

                            width: orientationMenu.availableWidth
                            height: 34
                            radius: 8
                            color: selected ? Qt.rgba(0.24, 0.39, 0.69, 0.68)
                                            : choiceHover.hovered ? QS.chipBgHover : "transparent"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData.label
                                color: Theme.textPrimary
                                font.family: Theme.fontUi
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.selected
                                text: "✓"
                                color: Theme.textPrimary
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                            }
                            HoverHandler { id: choiceHover; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.displayService.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    orientationMenu.close();
                                    if (root.selectedMonitor && !parent.selected)
                                        root.displayService.rotate(root.selectedMonitor.name, parent.modelData.transform);
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: "#ef8d8d"
            font.family: Theme.fontUi
            font.pixelSize: 11
            text: root.displayService.lastError
            visible: root.displayService.lastError.length > 0
        }
    }
}
