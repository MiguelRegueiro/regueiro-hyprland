import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    required property var clipboardService
    property bool open: false
    property real reveal: 0
    property int selectedIndex: -1
    property bool closeAfterPathCopy: false
    property bool hasOpenedOnce: false
    readonly property alias inputRegion: inputRegion
    readonly property bool inputActive: reveal > 0.03
    readonly property bool hovered: panelHover.hovered || boundsHover.hovered
    readonly property real attachBottom: Theme.clipboardAttachBottom
    readonly property real topLeftRadius: Theme.clipboardSurfaceTopLeftRadius
    readonly property real topRightRadius: Theme.clipboardSurfaceTopRightRadius
    readonly property real bottomLeftRadius: 0.001
    readonly property real bottomRightRadius: 0.001
    readonly property real revealProgress: reveal
    readonly property real animTopLeftRadius: root.topLeftRadius * root.reveal
    readonly property real animTopRightRadius: root.topRightRadius * root.reveal
    readonly property real clipWidthProgress: 0.84 + root.reveal * 0.16
    readonly property real clipHeightProgress: 0.78 + root.reveal * 0.22
    readonly property real frameScale: 0.988 + root.reveal * 0.012
    readonly property real frameOpacity: 0.72 + root.reveal * 0.28
    readonly property real bodyWidth: Theme.clipboardWidth
    readonly property real bodyHeight: Theme.clipboardHeight
    readonly property real fuseOverhang: Theme.barCornerRadius
    readonly property real fuseOpticalInset: 2
    readonly property real fuseBottomInset: root.attachBottom
    readonly property real bottomFuseJoinY: frame.height - root.fuseBottomInset - Theme.barCornerRadius
    readonly property real clipSurfaceWidth: root.bodyWidth * root.clipWidthProgress + root.fuseOverhang * 2 * root.reveal
    readonly property real clipSurfaceHeight: root.bodyHeight * root.clipHeightProgress + root.attachBottom * root.reveal
    readonly property string searchQuery: searchInput.text.trim().toLowerCase()
    readonly property var filteredEntries: {
        const query = root.searchQuery;
        const entries = root.clipboardService.entries || [];
        if (query.length === 0)
            return entries;
        return entries.filter((entry) => entry.searchText.includes(query));
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
        listView.positionViewAtIndex(nextIndex, ListView.Contain);
    }

    function activateEntry(entry) {
        if (!entry)
            return;
        root.clipboardService.copyEntry(entry);
        root.requestClose();
    }

    function activateSelection() {
        root.activateEntry(root.selectedEntry());
    }

    function deleteEntry(entry) {
        if (!entry)
            return;
        root.clipboardService.deleteEntry(entry);
    }

    function deleteSelection() {
        const entry = root.selectedEntry();
        if (!entry)
            return;
        root.deleteEntry(entry);
    }

    function copyEntryPath(entry) {
        if (!entry || !entry.path || root.clipboardService.mutating)
            return;
        root.closeAfterPathCopy = true;
        root.clipboardService.copyPath(entry);
    }

    onOpenChanged: {
        if (open) {
            root.hasOpenedOnce = false;
            root.clipboardService.refresh();
            searchInput.text = "";
            root.selectedIndex = -1;
            root.closeAfterPathCopy = false;
            Qt.callLater(root.focusSearch);
            Qt.callLater(function() {
                root.hasOpenedOnce = true;
            });
        } else {
            searchInput.text = "";
            root.selectedIndex = -1;
            root.closeAfterPathCopy = false;
            root.hasOpenedOnce = false;
        }
    }
    onFilteredEntriesChanged: clampSelection()
    onSelectedIndexChanged: {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length)
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
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

    Shortcut {
        sequence: "Ctrl+Delete"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.deleteSelection()
    }

    Timer {
        interval: Theme.inputPollInterval * 3
        running: root.open
        repeat: true
        onTriggered: root.clipboardService.refresh()
    }

    state: open ? "open" : ""
    implicitWidth: root.bodyWidth + root.fuseOverhang * 2
    implicitHeight: root.bodyHeight + root.attachBottom
    width: implicitWidth
    height: implicitHeight
    visible: reveal > 0.001
    transitions: [
        Transition {
            from: ""
            to: "open"

            NumberAnimation {
                target: root
                property: "reveal"
                duration: Theme.panelOpenDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }

        },
        Transition {
            from: "open"
            to: ""

            NumberAnimation {
                target: root
                property: "reveal"
                duration: Theme.panelCloseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.4, 0, 0.85, 0.3, 1, 1]
            }

        }
    ]

    Connections {
        function onDeleteCompleted(success) {
            if (success)
                Qt.callLater(root.focusSearch);
        }

        function onCopyPathCompleted(success) {
            const shouldClose = root.closeAfterPathCopy && success;
            root.closeAfterPathCopy = false;
            if (shouldClose)
                root.requestClose();
        }

        function onWipeCompleted(success) {
            if (success)
                Qt.callLater(root.focusSearch);
        }

        target: root.clipboardService
    }

    Item {
        id: inputRegion

        x: motionFrame.x
        y: motionFrame.y
        width: root.inputActive ? root.width : 0
        height: root.inputActive ? root.height : 0
        visible: false
    }

    Item {
        id: motionFrame

        width: root.width
        height: root.height
        y: (1 - root.reveal) * 4
        scale: root.frameScale
        transformOrigin: Item.Bottom
        opacity: root.frameOpacity
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

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    // One continuous fill surface.
                    ShapePath {
                        fillColor: Theme.menuBg
                        strokeColor: "transparent"
                        strokeWidth: 0
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin

                        PathMove {
                            x: -root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                        }

                        // Left fused corner into body.
                        PathArc {
                            x: 0
                            y: root.bottomFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Left body edge.
                        PathLine {
                            x: 0
                            y: root.topLeftRadius
                        }

                        // Top-left corner.
                        PathArc {
                            x: root.topLeftRadius
                            y: 0
                            radiusX: root.topLeftRadius
                            radiusY: root.topLeftRadius
                            direction: PathArc.Clockwise
                        }

                        // Top edge.
                        PathLine {
                            x: frame.width - root.topRightRadius
                            y: 0
                        }

                        // Top-right corner.
                        PathArc {
                            x: frame.width
                            y: root.topRightRadius
                            radiusX: root.topRightRadius
                            radiusY: root.topRightRadius
                            direction: PathArc.Clockwise
                        }

                        // Right body edge.
                        PathLine {
                            x: frame.width
                            y: root.bottomFuseJoinY
                        }

                        // Right fused corner into bar.
                        PathArc {
                            x: frame.width + root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Close through the hidden/merged bottom area.
                        PathLine {
                            x: frame.width + root.fuseOverhang
                            y: frame.height
                        }

                        PathLine {
                            x: -root.fuseOverhang
                            y: frame.height
                        }
                    }

                    // One matching outline path.
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

                        // Left fuse arc.
                        PathArc {
                            x: 0
                            y: root.bottomFuseJoinY
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }

                        // Left edge.
                        PathLine {
                            x: 0
                            y: root.topLeftRadius
                        }

                        // Top-left corner.
                        PathArc {
                            x: root.topLeftRadius
                            y: 0
                            radiusX: root.topLeftRadius
                            radiusY: root.topLeftRadius
                            direction: PathArc.Clockwise
                        }

                        // Top edge.
                        PathLine {
                            x: frame.width - root.topRightRadius
                            y: 0
                        }

                        // Top-right corner.
                        PathArc {
                            x: frame.width
                            y: root.topRightRadius
                            radiusX: root.topRightRadius
                            radiusY: root.topRightRadius
                            direction: PathArc.Clockwise
                        }

                        // Right edge.
                        PathLine {
                            x: frame.width
                            y: root.bottomFuseJoinY
                        }

                        // Right fuse arc.
                        PathArc {
                            x: frame.width + root.fuseOverhang
                            y: frame.height - root.fuseBottomInset
                            radiusX: Theme.barCornerRadius
                            radiusY: Theme.barCornerRadius
                            direction: PathArc.Counterclockwise
                        }
                    }

                    // Bottom-left merge patch.
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

                    // Bottom-right merge patch.
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
                        leftMargin: 14
                        rightMargin: 14
                        topMargin: 14
                        bottomMargin: 16
                    }

                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 16
                        color: Theme.qsCardBg
                        border.width: 1
                        border.color: searchInput.activeFocus ? Theme.tileActiveBorderHover : Theme.qsCardBorder

                        Text {
                            text: "󰍉"
                            font.family: Theme.fontIcons
                            font.pixelSize: 14
                            color: Theme.textDim

                            anchors {
                                left: parent.left
                                leftMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
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
                                left: parent.left
                                right: clearSearch.left
                                leftMargin: 38
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            visible: searchInput.text.length === 0
                            text: "Type to search clipboard"
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
                        radius: 20
                        color: Theme.popupBg
                        border.width: 1
                        border.color: Theme.qsEdge
                        clip: true

                        Item {
                            anchors.fill: parent

                            Column {
                                visible: root.clipboardService.loading && root.filteredEntries.length === 0 && !root.hasOpenedOnce
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
                                    text: "Refreshing clipboard..."
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    color: Theme.textDim
                                }
                            }

                            Column {
                                visible: root.filteredEntries.length === 0 && (!root.clipboardService.loading || root.hasOpenedOnce)
                                opacity: visible ? 1 : 0
                                spacing: 10

                                anchors.centerIn: parent

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery.length === 0 ? "󰅍" : "󰍉"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 24
                                    color: Theme.textDisabled
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery.length === 0 ? "Clipboard is empty" : "No matches for this search"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    color: Theme.textDim
                                }
                            }

                            ListView {
                                id: listView

                                visible: root.filteredEntries.length > 0
                                model: root.filteredEntries
                                spacing: 8
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                anchors {
                                    fill: parent
                                    leftMargin: 16
                                    rightMargin: 16
                                    topMargin: 10
                                    bottomMargin: 10
                                }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    readonly property bool selected: index === root.selectedIndex
                                    readonly property bool hovered: rowHover.hovered
                                    readonly property bool hasPathAction: !!(modelData.path && modelData.path.length > 0)
                                    width: listView.width
                                    implicitHeight: Math.max(58, previewLabel.implicitHeight + 22)
                                    radius: 16
                                    color: selected ? Qt.rgba(1, 1, 1, 0.10) : hovered ? Theme.qsCardBgHover : Theme.qsCardBg
                                    border.width: 1
                                    border.color: selected ? Qt.rgba(1, 1, 1, 0.16) : hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder

                                    HoverHandler {
                                        id: rowHover

                                        blocking: false
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: actionRow.width + 16
                                        anchors.topMargin: 10
                                        anchors.bottomMargin: 10
                                        spacing: 8

                                        Item {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.isImage ? "󰋩" : "󰅌"
                                                font.family: Theme.fontIcons
                                                font.pixelSize: 14
                                                color: selected ? Theme.textPrimary : Theme.textDim
                                            }
                                        }

                                        Text {
                                            id: previewLabel

                                            Layout.fillWidth: true
                                            text: modelData.displayPreview
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            color: Theme.textPrimary
                                            font.family: Theme.fontUi
                                            font.pixelSize: 13
                                        }

                                    }

                                    TapHandler {
                                        acceptedButtons: Qt.LeftButton
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: {
                                            root.selectedIndex = index;
                                            root.activateEntry(modelData);
                                        }
                                    }

                                    Row {
                                        id: actionRow
                                        z: 2
                                        visible: hovered || selected
                                        spacing: 8
                                        width: deleteButton.width + (pathButton.visible ? pathButton.width + spacing : 0)
                                        height: 28

                                        anchors {
                                            right: parent.right
                                            rightMargin: 8
                                            verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            id: pathButton

                                            visible: hasPathAction
                                            width: 42
                                            height: 28
                                            radius: 14
                                            color: pathHover.hovered ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                            border.width: pathHover.hovered ? 1 : 0
                                            border.color: Qt.rgba(1, 1, 1, 0.16)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Path"
                                                font.family: Theme.fontUi
                                                font.pixelSize: 11
                                                color: selected ? Theme.textPrimary : Theme.textDim
                                            }

                                            HoverHandler {
                                                id: pathHover

                                                blocking: false
                                                cursorShape: Qt.ArrowCursor
                                            }

                                            TapHandler {
                                                acceptedButtons: Qt.LeftButton
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onTapped: {
                                                    root.selectedIndex = index;
                                                    root.copyEntryPath(modelData);
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: deleteButton

                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: deleteHover.hovered ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                            border.width: deleteHover.hovered ? 1 : 0
                                            border.color: Qt.rgba(1, 1, 1, 0.16)

                                            Text {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 0.5
                                                text: "󰆴"
                                                font.family: Theme.fontIcons
                                                font.pixelSize: 13
                                                color: selected ? Theme.textPrimary : Theme.textDim
                                            }

                                            HoverHandler {
                                                id: deleteHover

                                                blocking: false
                                                cursorShape: Qt.ArrowCursor
                                            }

                                            TapHandler {
                                                acceptedButtons: Qt.LeftButton
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onTapped: {
                                                    root.selectedIndex = index;
                                                    root.deleteEntry(modelData);
                                                }
                                            }
                                        }
                                    }

                                }
                            }

                            Rectangle {
                                visible: listView.visible && listView.visibleArea.heightRatio < 0.999
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
                                    y: parent.height * listView.visibleArea.yPosition
                                    height: Math.max(28, parent.height * listView.visibleArea.heightRatio)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: root.clipboardService.lastError.length > 0 ? root.clipboardService.lastError : (root.filteredEntries.length === root.clipboardService.entries.length ? `${root.filteredEntries.length} entries` : `${root.filteredEntries.length} of ${root.clipboardService.entries.length} entries`)
                            font.family: Theme.fontUi
                            font.pixelSize: 11
                            color: root.clipboardService.lastError.length > 0 ? Theme.red : Theme.textDim
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: clearAllLabel.implicitWidth + 22
                            implicitHeight: 32
                            radius: 16
                            color: clearAllHover.hovered && clearAllEnabled ? Theme.hoverBgStrong : Theme.qsCardBg
                            border.width: 1
                            border.color: clearAllEnabled ? (clearAllHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder) : Theme.qsEdgeSoft
                            opacity: clearAllEnabled ? 1 : 0.5
                            readonly property bool clearAllEnabled: root.clipboardService.entries.length > 0 && !root.clipboardService.mutating

                            Text {
                                id: clearAllLabel

                                anchors.centerIn: parent
                                text: "Clear all"
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                color: Theme.textPrimary
                            }

                            HoverHandler {
                                id: clearAllHover

                                blocking: false
                                cursorShape: parent.clearAllEnabled ? Qt.ArrowCursor : Qt.ForbiddenCursor
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.clearAllEnabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: root.clipboardService.wipe()
                            }

                        }
                    }
                }

                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.72 * root.reveal)
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
