import QtQuick
import QtQuick.Layouts
import "../../theme/Theme.js" as Theme
import "../QuickSettingsStyle.js" as QS

Item {
    id: root

    required property var displayService
    property bool menuOpen: false
    property bool showHeader: true
    property bool showAdvanced: false
    property string selectedOutput: ""
    property bool dragActive: false
    property var dragPosition: null
    property var dropPreview: null
    property var pendingPositions: null
    readonly property var selectedMonitor: displayService.monitors.find(m => m.name === (selectedOutput || displayService.primary)) || displayService.monitors[0] || null
    readonly property bool selectedIsPrimary: selectedMonitor !== null && selectedMonitor.name === displayService.primary
    readonly property real layoutMinX: displayService.monitors.length > 0 ? Math.min.apply(null, displayService.monitors.map(monitor => monitorX(monitor))) : 0
    readonly property real layoutMinY: displayService.monitors.length > 0 ? Math.min.apply(null, displayService.monitors.map(monitor => monitorY(monitor))) : 0
    readonly property real layoutMaxX: displayService.monitors.length > 0 ? Math.max.apply(null, displayService.monitors.map(monitor => monitorX(monitor) + logicalWidth(monitor))) : 1
    readonly property real layoutMaxY: displayService.monitors.length > 0 ? Math.max.apply(null, displayService.monitors.map(monitor => monitorY(monitor) + logicalHeight(monitor))) : 1
    readonly property real stackedHeight: displayService.monitors.reduce((sum, monitor) => sum + logicalHeight(monitor), 0)
    readonly property real layoutScale: Math.min(0.14, (layoutCanvas.width - 64) / Math.max(1, layoutMaxX - layoutMinX), (layoutCanvas.height - 86) / Math.max(1, layoutMaxY - layoutMinY, displayService.monitors.length === 2 ? stackedHeight : 1))
    readonly property real layoutOffsetX: Math.max(16, (layoutCanvas.width - (layoutMaxX - layoutMinX) * layoutScale) / 2)
    readonly property real layoutOffsetY: Math.max(16, (layoutCanvas.height - (layoutMaxY - layoutMinY) * layoutScale) / 2)
    readonly property var orientations: [
        { transform: 0, label: "Landscape (0°)" },
        { transform: 2, label: "Landscape (180°)" },
        { transform: 1, label: "Portrait (90°)" },
        { transform: 3, label: "Portrait (270°)" }
    ]
    readonly property var advertisedModes: modesFor(selectedMonitor)
    readonly property string selectedResolution: {
        if (!selectedMonitor)
            return "";
        const direct = selectedMonitor.width + "x" + selectedMonitor.height;
        if (advertisedModes.some(mode => mode.resolution === direct))
            return direct;
        const rotated = selectedMonitor.height + "x" + selectedMonitor.width;
        return advertisedModes.some(mode => mode.resolution === rotated) ? rotated : direct;
    }
    readonly property var resolutionOptions: {
        const resolutions = [];
        for (const mode of advertisedModes) {
            if (!resolutions.some(item => item.value === mode.resolution))
                resolutions.push({ label: mode.width + " × " + mode.height, value: mode.resolution, area: mode.width * mode.height });
        }
        return resolutions.sort((a, b) => b.area - a.area || b.value.localeCompare(a.value));
    }
    readonly property var refreshOptions: advertisedModes.filter(mode => mode.resolution === selectedResolution)
        .sort((a, b) => b.rate - a.rate)
        .map(mode => ({ label: (Number.isInteger(mode.rate) ? mode.rate : mode.rate.toFixed(2)) + " Hz", value: mode.value }))
    readonly property string selectedMode: {
        if (!selectedMonitor)
            return "";
        const match = advertisedModes.find(mode => mode.resolution === selectedResolution && Math.abs(mode.rate - selectedMonitor.refreshRate) < 0.15);
        return match ? match.value : "";
    }
    readonly property var scaleOptions: {
        const values = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 1.8, 2, 2.25, 2.5, 3];
        if (selectedMonitor && !values.some(value => Math.abs(value - selectedMonitor.scale) < 0.001))
            values.push(selectedMonitor.scale);
        return values.sort((a, b) => a - b).map(value => ({ label: Math.round(value * 100) + "%", value: String(value) }));
    }

    signal backClicked

    function modesFor(monitor) {
        const result = [];
        for (const advertised of (monitor && monitor.availableModes || [])) {
            const match = /^(\d+)x(\d+)@(\d+(?:\.\d+)?)Hz?$/.exec(advertised);
            if (!match)
                continue;
            const value = match[1] + "x" + match[2] + "@" + match[3];
            if (!result.some(mode => mode.value === value))
                result.push({ width: Number(match[1]), height: Number(match[2]), resolution: match[1] + "x" + match[2], rate: Number(match[3]), value: value });
        }
        return result;
    }

    function setResolution(resolution) {
        const matching = advertisedModes.filter(mode => mode.resolution === resolution).sort((a, b) => b.rate - a.rate);
        if (selectedMonitor && matching.length > 0)
            displayService.setOutputMode(selectedMonitor.name, matching[0].value);
    }

    function monitorX(monitor) {
        return pendingPositions && pendingPositions[monitor.name] ? pendingPositions[monitor.name].x : monitor.x;
    }

    function monitorY(monitor) {
        return pendingPositions && pendingPositions[monitor.name] ? pendingPositions[monitor.name].y : monitor.y;
    }

    function monitorScale(monitor) {
        const scale = Number(monitor && monitor.scale);
        return Number.isFinite(scale) && scale > 0 ? scale : 1;
    }

    function swapsAxes(monitor) {
        return [1, 3, 5, 7].indexOf(Number(monitor && monitor.transform) || 0) !== -1;
    }

    function logicalWidth(monitor) {
        return (swapsAxes(monitor) ? monitor.height : monitor.width) / monitorScale(monitor);
    }

    function logicalHeight(monitor) {
        return (swapsAxes(monitor) ? monitor.width : monitor.height) / monitorScale(monitor);
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

    function guidedOffset(desired, start, otherSize, movedSize) {
        // Only attract to an alignment when the pointer is actually near it.
        const guides = [start, start + (otherSize - movedSize) / 2, start + otherSize - movedSize];
        const nearest = guides.reduce((best, value) => Math.abs(value - desired) < Math.abs(best - desired) ? value : best, guides[0]);
        return Math.abs(nearest - desired) * layoutScale <= 5 ? nearest : desired;
    }

    function connectedPlacement(moved, candidate, monitors) {
        const rects = monitors.map(monitor => ({
            x: monitor.name === moved.name ? candidate.x : monitorX(monitor),
            y: monitor.name === moved.name ? candidate.y : monitorY(monitor),
            w: logicalWidth(monitor),
            h: logicalHeight(monitor)
        }));
        const seen = [0];
        for (let index = 0; index < seen.length; index++) {
            const a = rects[seen[index]];
            for (let next = 0; next < rects.length; next++) {
                if (seen.includes(next))
                    continue;
                const b = rects[next];
                const horizontal = (Math.abs(a.x + a.w - b.x) <= 1 || Math.abs(b.x + b.w - a.x) <= 1)
                    && a.y < b.y + b.h - 1 && b.y < a.y + a.h - 1;
                const vertical = (Math.abs(a.y + a.h - b.y) <= 1 || Math.abs(b.y + b.h - a.y) <= 1)
                    && a.x < b.x + b.w - 1 && b.x < a.x + a.w - 1;
                if (horizontal || vertical)
                    seen.push(next);
            }
        }
        return seen.length === rects.length;
    }

    function placementForDrag(moved, dragX, dragY) {
        if (Math.max(Math.abs(dragX), Math.abs(dragY)) < 4)
            return null;
        const monitors = displayService.monitors;
        const width = logicalWidth(moved);
        const height = logicalHeight(moved);
        const desiredX = monitorX(moved) + dragX / layoutScale;
        const desiredY = monitorY(moved) + dragY / layoutScale;
        const others = monitors.filter(monitor => monitor.name !== moved.name);
        let best = null;
        // Keep at least a small usable passage between screens. The other
        // coordinate remains free except near optional alignment guides.
        const minOverlap = 12 / layoutScale;
        for (const other of others) {
            const ow = logicalWidth(other);
            const oh = logicalHeight(other);
            const ox = monitorX(other);
            const oy = monitorY(other);
            const vertical = Math.min(minOverlap, height / 2, oh / 2);
            const horizontal = Math.min(minOverlap, width / 2, ow / 2);
            const guidedY = guidedOffset(desiredY, oy, oh, height);
            const guidedX = guidedOffset(desiredX, ox, ow, width);
            const y = Math.max(oy - height + vertical, Math.min(guidedY, oy + oh - vertical));
            const x = Math.max(ox - width + horizontal, Math.min(guidedX, ox + ow - horizontal));
            const candidates = [
                { x: ox - width, y: y, direction: "left" },
                { x: ox + ow, y: y, direction: "right" },
                { x: x, y: oy - height, direction: "above" },
                { x: x, y: oy + oh, direction: "below" }
            ];
            for (const candidate of candidates) {
                const collides = others.some(monitor => {
                    const mx = monitorX(monitor);
                    const my = monitorY(monitor);
                    const mw = logicalWidth(monitor);
                    const mh = logicalHeight(monitor);
                    return candidate.x < mx + mw - 1 && mx < candidate.x + width - 1 &&
                           candidate.y < my + mh - 1 && my < candidate.y + height - 1;
                });
                if (collides || !connectedPlacement(moved, candidate, monitors))
                    continue;
                const distance = (candidate.x - desiredX) ** 2 + (candidate.y - desiredY) ** 2;
                if (!best || distance < best.distance)
                    best = { x: candidate.x, y: candidate.y, direction: candidate.direction, target: other.name, distance: distance };
            }
        }
        return best;
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

    function finishDrag(moved, commit) {
        if (!dragActive)
            return;
        if (commit && dropPreview)
            snapLayout(moved, dropPreview);
        dragActive = false;
        dragPosition = null;
        dropPreview = null;
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
            id: layoutCanvas

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 300
            clip: true
            color: QS.cardBg
            radius: 16
            border.width: 1
            border.color: QS.cardBorder

            Repeater {
                model: root.displayService.monitors

                delegate: Rectangle {
                    id: layoutMonitor

                    required property int index
                    required property var modelData
                    readonly property bool primary: modelData.name === root.displayService.primary
                    readonly property bool selected: root.selectedMonitor && modelData.name === root.selectedMonitor.name
                    readonly property real logicalWidth: root.logicalWidth(modelData)
                    readonly property real logicalHeight: root.logicalHeight(modelData)
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
                            root.dragActive = true;
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
                        function finish(commit) {
                            root.finishDrag(modelData, commit);
                            pressPoint = null;
                        }
                        onReleased: finish(true)
                        onCanceled: finish(false)
                        onPressedChanged: if (!pressed && root.dragActive) finish(true)
                    }

                    // Recover if a release is lost while the delegate is being
                    // moved under the pointer. This prevents a stale drag
                    // offset or drop hint from becoming the map's resting UI.
                    Timer {
                        interval: 60
                        repeat: true
                        running: root.dragActive && root.dragPosition && root.dragPosition.name === layoutMonitor.modelData.name
                        onTriggered: if (!dragArea.pressed) root.finishDrag(layoutMonitor.modelData, true)
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
                visible: root.displayService.mode === "extend" && root.dragActive && root.dropPreview !== null
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
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.displayService.mode === "duplicate" && root.displayService.monitors.length > 1

            Repeater {
                model: root.displayService.monitors

                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    readonly property bool selected: root.selectedMonitor && root.selectedMonitor.name === modelData.name
                    readonly property bool primary: modelData.name === root.displayService.primary

                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 12
                    color: selected ? Qt.rgba(0.24, 0.39, 0.69, 0.68) : QS.cardBg
                    border.width: 1
                    border.color: selected ? Theme.blue : QS.cardBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6

                        Text {
                            text: (parent.parent.index + 1) + "  " + parent.parent.modelData.name
                            color: Theme.textPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: parent.parent.selected ? Font.DemiBold : Font.Normal
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: parent.parent.primary
                            text: "Primary"
                            color: parent.parent.selected ? Theme.textPrimary : Theme.blue
                            font.family: Theme.fontUi
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedOutput = parent.modelData.name
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            visible: root.selectedMonitor !== null
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Selected display"
                color: Theme.textPrimary
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: root.displayService.monitors.length > 1 && !root.selectedIsPrimary
                Layout.preferredWidth: 112
                Layout.preferredHeight: 30
                radius: 10
                color: primaryHover.hovered ? QS.chipBgHover : QS.chipBg

                Text {
                    anchors.centerIn: parent
                    text: "Make primary"
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }
                HoverHandler { id: primaryHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: parent.visible && root.selectedMonitor !== null && !root.displayService.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.displayService.setPrimary(root.selectedMonitor.name)
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            visible: root.selectedMonitor !== null
            columns: root.showAdvanced ? 2 : 1
            columnSpacing: 8
            rowSpacing: 8

            DisplayOptionRow {
                label: "Orientation"
                valueText: root.orientationLabel(root.selectedMonitor ? root.selectedMonitor.transform : 0)
                options: root.orientations.map(item => ({ label: item.label, value: String(item.transform) }))
                currentValue: root.selectedMonitor ? String(root.selectedMonitor.transform) : ""
                busy: root.displayService.busy
                visible: root.selectedMonitor !== null
                onChosen: transform => root.displayService.rotate(root.selectedMonitor.name, Number(transform))
            }
            DisplayOptionRow {
                label: "Resolution"
                valueText: root.selectedResolution.replace("x", " × ")
                options: root.resolutionOptions
                currentValue: root.selectedResolution
                busy: root.displayService.busy
                visible: root.showAdvanced && root.selectedMonitor !== null
                onChosen: resolution => root.setResolution(resolution)
            }
            DisplayOptionRow {
                label: "Refresh rate"
                valueText: root.selectedMonitor ? (Number.isInteger(root.selectedMonitor.refreshRate)
                           ? root.selectedMonitor.refreshRate : root.selectedMonitor.refreshRate.toFixed(2)) + " Hz" : ""
                options: root.refreshOptions
                currentValue: root.selectedMode
                busy: root.displayService.busy
                visible: root.showAdvanced && root.selectedMonitor !== null
                onChosen: mode => root.displayService.setOutputMode(root.selectedMonitor.name, mode)
            }
            DisplayOptionRow {
                label: "Scale"
                valueText: root.selectedMonitor ? Math.round(root.selectedMonitor.scale * 100) + "%" : ""
                options: root.scaleOptions
                currentValue: root.selectedMonitor ? String(root.selectedMonitor.scale) : ""
                busy: root.displayService.busy
                visible: root.showAdvanced && root.selectedMonitor !== null
                onChosen: scale => root.displayService.setScale(root.selectedMonitor.name, scale)
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
