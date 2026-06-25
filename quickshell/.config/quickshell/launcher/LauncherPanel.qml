import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../components" as Components
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    required property var launcherService
    property bool open: false
    property real reveal: 0
    property int selectedIndex: -1
    property bool hasOpenedOnce: false
    property var appGridView: null
    readonly property alias inputRegion: inputRegion
    readonly property bool inputActive: reveal > 0.03
    readonly property bool hovered: panelHover.hovered || boundsHover.hovered
    readonly property real attachBottom: Theme.launcherAttachBottom
    readonly property real topLeftRadius: Theme.launcherSurfaceTopLeftRadius
    readonly property real topRightRadius: Theme.launcherSurfaceTopRightRadius
    readonly property int openDuration: Theme.panelCloseDuration
    readonly property real bottomLeftRadius: 0.001
    readonly property real bottomRightRadius: 0.001
    readonly property real revealProgress: reveal
    readonly property real bodyWidth: Theme.launcherWidth
    readonly property real bodyHeight: Theme.launcherHeight
    readonly property real touchpadScrollMultiplier: 3.2
    readonly property real mouseWheelScrollRows: 2.4
    readonly property int horizontalKeyRepeatMs: Theme.qsPageFadeDuration
    readonly property int verticalKeyRepeatMs: 95
    readonly property int gridColumnCount: 5
    property real lastHorizontalKeyMoveMs: 0
    property real lastVerticalKeyMoveMs: 0
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseOpticalInset: 2
    readonly property real fuseBottomInset: root.attachBottom
    readonly property real bottomFuseJoinY: frame.height - root.fuseBottomInset - Theme.barCornerRadius
    readonly property real clipSurfaceWidth: root.bodyWidth + root.fuseOverhang * 2
    readonly property real clipSurfaceHeight: root.bodyHeight + root.attachBottom
    readonly property real surfaceOffsetY: (1 - root.reveal) * root.clipSurfaceHeight
    readonly property string searchQuery: searchInput.text.trim().toLowerCase()
    readonly property var filteredEntries: root.launcherService.searchEntries(root.searchQuery)
    readonly property var allEntries: {
        // Stable delegate model: frecency changes only move existing delegates via
        // filteredEntryIndexes. Rebuilding this model on every app launch destroys
        // every Image and makes 256px icons reload on the next open.
        const entriesRevision = root.launcherService.entriesRevision;
        return root.launcherService.entries;
    }
    readonly property var filteredEntryIndexes: {
        const indexes = ({
        });
        const entries = root.filteredEntries;
        for (let index = 0; index < entries.length; index += 1) {
            const entry = entries[index];
            if (entry && typeof entry.statsId === "string")
                indexes[entry.statsId] = index;

        }
        return indexes;
    }

    signal requestClose()

    function focusSearch() {
        root.forceActiveFocus();
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
    }

    function clampSelection() {
        if (root.filteredEntries.length === 0) {
            root.selectedIndex = -1;
            return;
        }

        if (root.selectedIndex < 0 || root.selectedIndex >= root.filteredEntries.length)
            root.selectedIndex = 0;
    }

    function selectedEntry() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.filteredEntries.length)
            return null;

        return root.filteredEntries[root.selectedIndex];
    }

    function moveSelection(delta) {
        if (root.filteredEntries.length === 0)
            return;

        const nextIndex = Math.max(0, Math.min(root.filteredEntries.length - 1, root.selectedIndex + delta));
        root.selectedIndex = nextIndex;
        root.ensureSelectionVisible(nextIndex);
    }

    function moveHorizontalSelection(delta) {
        const now = Date.now();
        if (now - root.lastHorizontalKeyMoveMs < root.horizontalKeyRepeatMs)
            return;

        root.lastHorizontalKeyMoveMs = now;
        root.moveSelection(delta);
    }

    function moveVerticalSelection(direction) {
        const now = Date.now();
        if (now - root.lastVerticalKeyMoveMs < root.verticalKeyRepeatMs)
            return;

        if (root.filteredEntries.length === 0)
            return;

        const columns = root.gridColumns();
        const currentIndex = Math.max(0, Math.min(root.filteredEntries.length - 1, root.selectedIndex));
        const currentColumn = currentIndex % columns;
        const targetRow = Math.floor(currentIndex / columns) + direction;
        if (targetRow < 0)
            return;

        const targetIndex = targetRow * columns + currentColumn;
        if (targetIndex >= root.filteredEntries.length)
            return;

        root.lastVerticalKeyMoveMs = now;
        root.selectedIndex = targetIndex;
        root.ensureSelectionVisible(targetIndex);
    }

    function gridColumns() {
        return root.gridColumnCount;
    }

    function clampGridContentY(value) {
        if (!root.appGridView)
            return 0;

        const maxY = Math.max(0, root.appGridView.contentHeight - root.appGridView.height);
        return Math.max(0, Math.min(maxY, value));
    }

    function scrollGrid(deltaY) {
        if (!root.appGridView)
            return;

        root.appGridView.contentY = root.clampGridContentY(root.appGridView.contentY + deltaY);
    }

    function ensureSelectionVisible(index) {
        if (!root.appGridView || index < 0)
            return;

        const columns = root.gridColumns();
        const row = Math.floor(index / columns);
        const rowTop = row * root.appGridView.cellHeight;
        const rowBottom = rowTop + root.appGridView.cellHeight;
        const viewTop = root.appGridView.contentY;
        const viewBottom = viewTop + root.appGridView.height;

        if (rowTop < viewTop)
            root.appGridView.contentY = root.clampGridContentY(rowTop);
        else if (rowBottom > viewBottom)
            root.appGridView.contentY = root.clampGridContentY(rowBottom - root.appGridView.height);
    }

    function activateEntry(entry) {
        if (!entry)
            return;

        if (root.launcherService.launchEntry(entry))
            root.requestClose();
        else
            Qt.callLater(root.focusSearch);
    }

    function activateSelection() {
        root.activateEntry(root.selectedEntry());
    }

    onOpenChanged: {
        if (open) {
            root.hasOpenedOnce = false;
            root.lastHorizontalKeyMoveMs = 0;
            root.lastVerticalKeyMoveMs = 0;
            root.launcherService.clearError();
            searchInput.text = "";
            root.selectedIndex = 0;
            Qt.callLater(root.focusSearch);
            Qt.callLater(function() {
                root.hasOpenedOnce = true;
            });
        } else {
            searchInput.text = "";
            root.selectedIndex = -1;
            root.hasOpenedOnce = false;
            root.lastHorizontalKeyMoveMs = 0;
            root.lastVerticalKeyMoveMs = 0;
        }
    }
    onFilteredEntriesChanged: {
        clampSelection();
    }
    onSelectedIndexChanged: {
        if (root.appGridView && root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length)
            root.ensureSelectionVisible(root.selectedIndex);
    }

    Shortcut {
        sequence: "Up"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.moveVerticalSelection(-1)
    }

    Shortcut {
        sequence: "Down"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.moveVerticalSelection(1)
    }

    Shortcut {
        sequence: "Left"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.moveHorizontalSelection(-1)
    }

    Shortcut {
        sequence: "Right"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.moveHorizontalSelection(1)
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
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.requestClose()
    }

    Item {
        id: inputRegion

        x: motionFrame.x
        y: motionFrame.y
        width: root.inputActive ? root.width : 0
        height: root.inputActive ? root.height : 0
        visible: false
    }

    state: open ? "open" : ""
    implicitWidth: root.bodyWidth + root.fuseOverhang * 2
    implicitHeight: root.bodyHeight + root.attachBottom
    width: implicitWidth
    height: implicitHeight
    // Never hide/unmap this subtree on close. Hiding it makes Qt drop the
    // Image scene-graph textures, so every reopen has to decode the 256px icons
    // again. The closed state already moves the surface out through the clipped
    // reveal animation; keep it alive so icons stay hot.
    visible: true

    transitions: [
        Transition {
            from: ""
            to: "open"

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.EmphasizedDecel
                duration: root.openDuration
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

    Item {
        id: motionFrame

        width: root.width
        height: Math.max(1, root.height)
        y: 0
        layer.enabled: true

            HoverHandler {
                id: boundsHover

                blocking: false
            }

            Item {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, root.clipSurfaceWidth)
                height: Math.max(1, root.clipSurfaceHeight)
                clip: true

                HoverHandler {
                    id: panelHover

                    blocking: false
                }

                Item {
                    id: frame

                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.bodyWidth
                    height: root.bodyHeight
                    transform: Translate {
                        y: root.surfaceOffsetY
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: -1
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: -root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                        }

                        PathArc {
                            x: 0
                            y: root.bottomFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: 0
                            y: root.topLeftRadius
                        }

                        PathArc {
                            x: root.topLeftRadius
                            y: 0
                            radiusX: root.topLeftRadius
                            radiusY: root.topLeftRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width - root.topRightRadius
                            y: 0
                        }

                        PathArc {
                            x: frame.width
                            y: root.topRightRadius
                            radiusX: root.topRightRadius
                            radiusY: root.topRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width
                            y: root.bottomFuseJoinY
                        }

                        PathArc {
                            x: frame.width + root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width + root.fuseOverhang
                            y: frame.height
                        }

                        PathLine {
                            x: -root.fuseOverhang
                            y: frame.height
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Theme.qsEdge
                        strokeWidth: 1
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: -root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                        }

                        PathArc {
                            x: 0
                            y: root.bottomFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: 0
                            y: root.topLeftRadius
                        }

                        PathArc {
                            x: root.topLeftRadius
                            y: 0
                            radiusX: root.topLeftRadius
                            radiusY: root.topLeftRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width - root.topRightRadius
                            y: 0
                        }

                        PathArc {
                            x: frame.width
                            y: root.topRightRadius
                            radiusX: root.topRightRadius
                            radiusY: root.topRightRadius
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: frame.width
                            y: root.bottomFuseJoinY
                        }

                        PathArc {
                            x: frame.width + root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: Theme.menuBg
                        strokeWidth: 1
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: 0
                            y: frame.height
                        }

                        PathLine {
                            x: root.bottomLeftRadius * root.reveal
                            y: frame.height
                        }

                        PathArc {
                            x: 0
                            y: frame.height - (root.bottomLeftRadius * root.reveal)
                            radiusX: root.bottomLeftRadius * root.reveal
                            radiusY: root.bottomLeftRadius * root.reveal
                            direction: PathArc.Clockwise
                        }

                        PathLine {
                            x: 0
                            y: frame.height
                        }
                    }

                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: Theme.menuBg
                        strokeWidth: 1
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: frame.width
                            y: frame.height
                        }

                        PathLine {
                            x: frame.width - (root.bottomRightRadius * root.reveal)
                            y: frame.height
                        }

                        PathArc {
                            x: frame.width
                            y: frame.height - (root.bottomRightRadius * root.reveal)
                            radiusX: root.bottomRightRadius * root.reveal
                            radiusY: root.bottomRightRadius * root.reveal
                            direction: PathArc.Counterclockwise
                        }

                        PathLine {
                            x: frame.width
                            y: frame.height
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                    }
                }

                ColumnLayout {
                    id: contentLayout

                    anchors {
                        fill: parent
                        leftMargin: 16
                        rightMargin: 16
                        topMargin: 14
                        bottomMargin: 14
                    }

                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 16
                        color: searchInput.activeFocus ? Qt.rgba(1, 1, 1, 0.105) : Qt.rgba(1, 1, 1, 0.058)
                        border.width: 0
                        layer.enabled: searchInput.activeFocus
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.34)
                            shadowBlur: 0.28
                            shadowVerticalOffset: 2
                            shadowHorizontalOffset: 0
                            blurMax: 16
                        }

                        Text {
                            id: searchIcon

                            anchors {
                                left: parent.left
                                leftMargin: 15
                                verticalCenter: parent.verticalCenter
                            }

                            text: "󰍉"
                            font.family: Theme.fontIcons
                            font.pixelSize: 14
                            color: searchInput.activeFocus ? Theme.textPrimary : Theme.textDim
                        }

                        TextInput {
                            id: searchInput

                            color: Theme.textPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.textPrimary
                            cursorVisible: activeFocus
                            clip: true
                            selectByMouse: true
                            activeFocusOnPress: true
                            onTextEdited: root.selectedIndex = 0

                            anchors {
                                left: searchIcon.right
                                right: clearSearch.left
                                leftMargin: 12
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }

                            Keys.onLeftPressed: (event) => {
                                root.moveHorizontalSelection(-1);
                                event.accepted = true;
                            }

                            Keys.onRightPressed: (event) => {
                                root.moveHorizontalSelection(1);
                                event.accepted = true;
                            }
                        }

                        Text {
                            visible: searchInput.text.length === 0
                            text: "Search"
                            color: Theme.textDisabled
                            font.family: Theme.fontUi
                            font.pixelSize: 13

                            anchors {
                                left: searchInput.left
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            id: clearSearch

                            visible: searchInput.text.length > 0
                            width: 28
                            height: 28
                            radius: 14
                            color: clearSearchHover.hovered ? Theme.hoverBgStrong : "transparent"

                            anchors {
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Theme.fontIcons
                                font.pixelSize: 13
                                color: Theme.textDim
                            }

                            HoverHandler {
                                id: clearSearchHover

                                blocking: false
                                cursorShape: Qt.ArrowCursor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    root.selectedIndex = 0;
                                    root.focusSearch();
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 22
                        color: Qt.rgba(0.075, 0.075, 0.075, 0.88)
                        border.width: 1
                        border.color: Theme.qsEdge
                        clip: true

                        Item {
                            anchors.fill: parent

                            Column {
                                visible: root.launcherService.loading && root.filteredEntries.length === 0 && !root.hasOpenedOnce
                                spacing: 10

                                anchors.centerIn: parent

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰑐"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 24
                                    color: Theme.textDisabled
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Loading applications..."
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    color: Theme.textDim
                                }
                            }

                            Column {
                                visible: root.filteredEntries.length === 0 && (!root.launcherService.loading || root.hasOpenedOnce)
                                opacity: visible ? 1 : 0
                                spacing: 10

                                anchors.centerIn: parent

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery.length === 0 ? "󰀻" : "󰍉"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 24
                                    color: Theme.textDisabled
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery.length === 0 ? "No applications found" : "No matches for this search"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    color: Theme.textDim
                                }
                            }

                            Flickable {
                                id: appGrid

                                property int cellWidth: Math.floor(width / root.gridColumnCount)
                                property int cellHeight: 130

                                visible: root.filteredEntries.length > 0
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                contentWidth: width
                                contentHeight: appGridPositioner.height
                                Component.onCompleted: root.appGridView = appGrid

                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                    topMargin: 12
                                    bottomMargin: 12
                                }

                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: (event) => {
                                        const pixelDelta = event.pixelDelta.y;
                                        const wheelSteps = event.angleDelta.y / 120;
                                        const scrollDelta = pixelDelta !== 0 ? -pixelDelta * root.touchpadScrollMultiplier : -wheelSteps * appGrid.cellHeight * root.mouseWheelScrollRows;
                                        root.scrollGrid(scrollDelta);
                                        event.accepted = true;
                                    }
                                }

                                Item {
                                    id: appGridPositioner

                                    width: appGrid.width
                                    height: Math.ceil(root.filteredEntries.length / root.gridColumnCount) * appGrid.cellHeight

                                    Repeater {
                                        model: root.allEntries

                                        delegate: Item {
                                            required property var modelData

                                            readonly property var mappedIndex: root.filteredEntryIndexes[modelData.statsId]
                                            readonly property int filteredIndex: typeof mappedIndex === "number" ? mappedIndex : -1
                                            readonly property bool matched: filteredIndex >= 0
                                            readonly property bool selected: filteredIndex === root.selectedIndex
                                            // Keep delegates and their 256px icon images alive across searches.
                                            // Toggling visible/size to 0 makes Qt drop/reload async images, which is
                                            // exactly the slow blank-icon flash this drawer must avoid.
                                            enabled: matched
                                            opacity: matched ? 1 : 0
                                            x: matched ? (filteredIndex % root.gridColumnCount) * appGrid.cellWidth : -10000
                                            y: matched ? Math.floor(filteredIndex / root.gridColumnCount) * appGrid.cellHeight : -10000
                                            width: appGrid.cellWidth
                                            height: appGrid.cellHeight

                                            Rectangle {
                                                id: appTile

                                                width: Math.min(134, parent.width - 6)
                                                height: 122
                                                radius: 16
                                                color: selected ? Qt.rgba(1, 1, 1, 0.095) : "transparent"
                                                border.width: selected ? 1 : 0
                                                border.color: selected ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                                scale: selected ? 1.012 : 1

                                                anchors.centerIn: parent

                                                Column {
                                                    width: parent.width
                                                    spacing: 8

                                                    anchors {
                                                        top: parent.top
                                                        topMargin: 9
                                                        horizontalCenter: parent.horizontalCenter
                                                    }

                                                    Item {
                                                        width: 84
                                                        height: 74

                                                        anchors.horizontalCenter: parent.horizontalCenter

                                                        Image {
                                                            anchors.centerIn: parent
                                                            width: 70
                                                            height: 70
                                                            fillMode: Image.PreserveAspectFit
                                                            sourceSize.width: 256
                                                            sourceSize.height: 256
                                                            smooth: true
                                                            mipmap: true
                                                            asynchronous: true
                                                            cache: true
                                                            source: root.launcherService.iconDisplaySource(modelData.iconSource)
                                                        }

                                                        Rectangle {
                                                            visible: modelData.runInTerminal
                                                            width: 22
                                                            height: 18
                                                            radius: 9
                                                            color: Theme.qsCardBg
                                                            border.width: 1
                                                            border.color: Theme.qsCardBorder

                                                            anchors {
                                                                top: parent.top
                                                                right: parent.right
                                                                topMargin: -2
                                                                rightMargin: -2
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: ""
                                                                color: Theme.textDim
                                                                font.family: Theme.fontIcons
                                                                font.pixelSize: 10
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        width: parent.width - 10
                                                        height: 31
                                                        text: modelData.name
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignTop
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                        color: selected ? Theme.textPrimary : Theme.textDim
                                                        font.family: Theme.fontUi
                                                        font.pixelSize: 12
                                                        lineHeight: 0.94

                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                }

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: Theme.qsPageFadeDuration
                                                    }
                                                }

                                                Behavior on border.color {
                                                    ColorAnimation {
                                                        duration: Theme.qsPageFadeDuration
                                                    }
                                                }

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: Theme.hoverAnimDuration
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }

                                                layer.enabled: selected
                                                layer.effect: MultiEffect {
                                                    shadowEnabled: true
                                                    shadowColor: Qt.rgba(0, 0, 0, 0.34)
                                                    shadowBlur: 0.34
                                                    shadowVerticalOffset: 2
                                                    shadowHorizontalOffset: 0
                                                    blurMax: 14
                                                }
                                            }

                                            TapHandler {
                                                acceptedButtons: Qt.LeftButton
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onTapped: {
                                                    root.selectedIndex = filteredIndex;
                                                    root.activateEntry(modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: appGrid.visible && appGrid.visibleArea.heightRatio < 0.999
                                width: 4
                                radius: 2
                                color: Theme.qsEdgeSoft

                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                    topMargin: 10
                                    bottomMargin: 10
                                    rightMargin: 8
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: 2
                                    color: Theme.qsCardBorderHover
                                    y: parent.height * appGrid.visibleArea.yPosition
                                    height: Math.max(28, parent.height * appGrid.visibleArea.heightRatio)
                                }
                            }
                        }
                    }
                }

                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.72)
                    shadowBlur: 0.88
                    shadowVerticalOffset: -4
                    shadowHorizontalOffset: 0
                    blurMax: 48
                }
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
