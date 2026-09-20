import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../components" as Components
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    required property var clipboardService
    property bool open: false
    property real reveal: 0
    property int selectedIndex: -1
    property bool hasOpenedOnce: false
    property bool closeAfterCopy: false
    property int heldVerticalKey: 0
    property int heldVerticalDirection: 0
    property bool verticalReleasePending: false
    readonly property alias inputRegion: inputRegion
    readonly property bool inputActive: reveal > 0.03
    readonly property bool hovered: panelHover.hovered || boundsHover.hovered
    readonly property real topLeftRadius: Theme.clipboardSurfaceTopLeftRadius
    readonly property real topRightRadius: Theme.clipboardSurfaceTopRightRadius
    readonly property real revealProgress: reveal
    readonly property real bodyWidth: Theme.clipboardWidth
    readonly property real bodyHeight: Theme.clipboardHeight
    readonly property real surfaceOffsetY: (1 - root.reveal) * 6
    readonly property real surfaceOpacity: root.reveal
    readonly property bool searchVisuallyActive: root.open || root.reveal > 0.001
    readonly property int verticalHoldDelayMs: 360
    readonly property int verticalKeyRepeatMs: 120
    readonly property int verticalReleaseQuietMs: 8
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

    function iconForKind(kind) {
        switch (kind) {
        case "image":
            return "󰋩";
        case "file":
            return "󰈔";
        case "uri":
            return "󰌹";
        default:
            return "󰅌";
        }
    }

    function entryCountText(count) {
        return count === 1 ? "1 entry" : `${count} entries`;
    }

    function visibleEntryCountText() {
        const total = root.clipboardService.entries.length;
        const visible = root.filteredEntries.length;
        if (root.searchQuery.length > 0 && visible !== total)
            return `${visible} of ${root.entryCountText(total)}`;

        return root.entryCountText(total);
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

    function handleVerticalPress(key) {
        const direction = key === Qt.Key_Up ? -1 : key === Qt.Key_Down ? 1 : 0;
        if (direction === 0)
            return false;

        if (root.heldVerticalKey === key) {
            if (root.verticalReleasePending) {
                root.verticalReleasePending = false;
                verticalReleaseTimer.stop();
            }
            return true;
        }

        root.resetVerticalNavigation();
        root.heldVerticalKey = key;
        root.heldVerticalDirection = direction;
        root.moveSelection(direction);
        verticalHoldTimer.restart();
        return true;
    }

    function handleVerticalRelease(key) {
        if (key !== root.heldVerticalKey)
            return false;

        root.verticalReleasePending = true;
        verticalReleaseTimer.restart();
        return true;
    }

    function resetVerticalNavigation() {
        root.heldVerticalKey = 0;
        root.heldVerticalDirection = 0;
        root.verticalReleasePending = false;
        verticalHoldTimer.stop();
        verticalRepeatTimer.stop();
        verticalReleaseTimer.stop();
    }

    function activateEntry(entry) {
        if (!entry || root.clipboardService.mutating)
            return;
        root.closeAfterCopy = true;
        root.clipboardService.copyEntry(entry);
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

    onOpenChanged: {
        root.resetVerticalNavigation();
        if (open) {
            root.hasOpenedOnce = false;
            root.clipboardService.refresh();
            searchInput.text = "";
            root.selectedIndex = -1;
            Qt.callLater(root.focusSearch);
            Qt.callLater(function() {
                root.hasOpenedOnce = true;
            });
        } else {
            searchInput.text = "";
            root.selectedIndex = -1;
            root.hasOpenedOnce = false;
        }
    }
    onActiveFocusChanged: {
        if (!activeFocus)
            root.resetVerticalNavigation();
    }
    onFilteredEntriesChanged: clampSelection()
    onSelectedIndexChanged: {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length)
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }
    Timer {
        id: verticalHoldTimer

        interval: root.verticalHoldDelayMs
        repeat: false
        onTriggered: {
            if (root.heldVerticalKey !== 0)
                root.moveSelection(root.heldVerticalDirection);
            verticalRepeatTimer.start();
        }
    }

    Timer {
        id: verticalRepeatTimer

        interval: root.verticalKeyRepeatMs
        repeat: true
        onTriggered: {
            if (root.heldVerticalKey !== 0)
                root.moveSelection(root.heldVerticalDirection);
        }
    }

    Timer {
        id: verticalReleaseTimer

        interval: root.verticalReleaseQuietMs
        repeat: false
        onTriggered: root.resetVerticalNavigation()
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

    Timer {
        id: closeAfterCopyTimer

        interval: 120
        repeat: false
        onTriggered: {
            if (root.closeAfterCopy) {
                root.closeAfterCopy = false;
                root.requestClose();
            }
        }
    }

    state: open ? "open" : ""
    implicitWidth: root.bodyWidth
    implicitHeight: root.bodyHeight
    width: implicitWidth
    height: implicitHeight
    visible: reveal > 0.001
    transitions: [
        Transition {
            from: ""
            to: "open"

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.StandardDecel
                duration: Theme.topBarMenuOpenDuration
            }

        },
        Transition {
            from: "open"
            to: ""

            Components.Anim {
                target: root
                property: "reveal"
                curve: Components.Anim.StandardAccel
                duration: Theme.topBarMenuCloseDuration
            }

        }
    ]

    Connections {
        function onCopyCompleted(success) {
            if (success)
                closeAfterCopyTimer.restart();
            else
                root.closeAfterCopy = false;
        }

        function onDeleteCompleted(success) {
            if (success)
                Qt.callLater(root.focusSearch);
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
                width: Math.max(1, root.bodyWidth)
                height: Math.max(1, root.bodyHeight)
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
                    opacity: root.surfaceOpacity
                    Rectangle {
                        anchors.fill: parent
                        radius: root.topLeftRadius
                        color: "transparent"
                        border.width: 0
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
                        color: Theme.bottomPanelSearchBg
                        border.width: 2
                        border.color: Theme.bottomPanelCardBorder

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
                            color: root.searchVisuallyActive ? Theme.bottomPanelTextPrimary : Theme.bottomPanelTextSecondary
                        }

                        TextInput {
                            id: searchInput

                            color: Theme.bottomPanelTextPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.textPrimary
                            cursorVisible: activeFocus
                            clip: true
                            selectByMouse: true
                            activeFocusOnPress: true
                            onTextEdited: root.selectedIndex = 0

                            Keys.onPressed: (event) => {
                                if (root.handleVerticalPress(event.key))
                                    event.accepted = true;
                            }

                            Keys.onReleased: (event) => {
                                if (root.handleVerticalRelease(event.key))
                                    event.accepted = true;
                            }

                            anchors {
                                left: searchIcon.right
                                right: countLabel.left
                                leftMargin: 12
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            visible: searchInput.text.length === 0
                            text: "Search"
                            color: Theme.bottomPanelTextMuted
                            font.family: Theme.fontUi
                            font.pixelSize: 13

                            anchors {
                                left: searchInput.left
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            id: countLabel

                            text: root.visibleEntryCountText()
                            color: Theme.bottomPanelTextSecondary
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter

                            anchors {
                                right: clearAllButton.left
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            id: clearAllButton

                            width: clearAllLabel.implicitWidth + 28
                            height: parent.height - 4
                            radius: 13
                            color: clearAllHover.hovered && clearAllEnabled ? Theme.hoverBgStrong : "transparent"
                            border.width: 0
                            opacity: clearAllEnabled ? 1 : 0.5
                            readonly property bool clearAllEnabled: root.clipboardService.entries.length > 0 && !root.clipboardService.mutating

                            anchors {
                                right: clearSearch.visible ? clearSearch.left : parent.right
                                rightMargin: 2
                                verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: clearAllLabel

                                anchors.centerIn: parent
                                text: "Clear all"
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                color: Theme.bottomPanelTextPrimary
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
                                color: Theme.bottomPanelTextSecondary
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
                        radius: 0
                        color: "transparent"
                        border.width: 0
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
                                    color: Theme.bottomPanelTextMuted
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Refreshing clipboard..."
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    color: Theme.bottomPanelTextSecondary
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
                                    color: Theme.bottomPanelTextMuted
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.searchQuery.length === 0 ? "Clipboard is empty" : "No matches for this search"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 13
                                    color: Theme.bottomPanelTextSecondary
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
                                    rightMargin: 18
                                    topMargin: 4
                                    bottomMargin: 4
                                }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    readonly property bool selected: index === root.selectedIndex
                                    readonly property bool hovered: rowHover.hovered
                                    readonly property bool imageEntry: modelData.kind === "image"
                                    width: listView.width
                                    implicitHeight: Math.max(imageEntry ? 82 : 58, previewLabel.implicitHeight + 22)
                                    radius: 14
                                    color: selected ? Theme.bottomPanelCardActiveBg : hovered ? Qt.rgba(0.15, 0.16, 0.19, 0.44) : Theme.bottomPanelCardBg
                                    border.width: selected ? 2 : 1
                                    border.color: selected ? Theme.bottomPanelCardActiveBorder : hovered ? Qt.rgba(0.851, 0.867, 0.902, 0.24) : Theme.bottomPanelCardBorder

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

                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: imageEntry ? 64 : 28
                                            Layout.preferredHeight: imageEntry ? 64 : 28
                                            radius: imageEntry ? 12 : 14
                                            color: imageEntry ? Qt.rgba(0, 0, 0, 0.28) : "transparent"
                                            clip: imageEntry

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !imageEntry || imagePreview.status !== Image.Ready
                                                text: root.iconForKind(modelData.kind)
                                                font.family: Theme.fontIcons
                                                font.pixelSize: 14
                                                color: selected ? Theme.bottomPanelTextPrimary : Theme.bottomPanelTextSecondary
                                            }

                                            Image {
                                                id: imagePreview

                                                anchors.fill: parent
                                                anchors.margins: 1
                                                visible: imageEntry
                                                source: imageEntry ? root.clipboardService.imagePreviewSource(modelData.id) : ""
                                                fillMode: Image.PreserveAspectCrop
                                                sourceSize.width: 128
                                                sourceSize.height: 128
                                                asynchronous: true
                                                cache: true
                                            }
                                        }

                                        Text {
                                            id: previewLabel

                                            Layout.fillWidth: true
                                            text: modelData.displayPreview
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            color: Theme.bottomPanelTextPrimary
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

                                    Component.onCompleted: {
                                        if (imageEntry)
                                            root.clipboardService.requestImagePreview(modelData);
                                    }

                                    Row {
                                        id: actionRow
                                        z: 2
                                        visible: hovered || selected
                                        width: deleteButton.width
                                        height: 28

                                        anchors {
                                            right: parent.right
                                            rightMargin: 8
                                            verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            id: deleteButton

                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: deleteHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
                                            border.width: 1
                                            border.color: deleteHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                            Text {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 0.5
                                                text: "󰆴"
                                                font.family: Theme.fontIcons
                                                font.pixelSize: 13
                                                color: selected ? Theme.bottomPanelTextPrimary : Theme.bottomPanelTextSecondary
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

                            Item {
                                id: clipboardScrollTrack

                                visible: listView.visible && listView.visibleArea.heightRatio < 0.999
                                width: 14
                                z: 10
                                readonly property real thumbHeight: Math.max(28, height * listView.visibleArea.heightRatio)
                                readonly property real maxContentY: Math.max(0, listView.contentHeight - listView.height)

                                function moveTo(pointerY) {
                                    const travel = Math.max(1, height - thumbHeight);
                                    const next = Math.max(0, Math.min(travel, pointerY - thumbHeight / 2));
                                    listView.contentY = maxContentY * next / travel;
                                }

                                anchors {
                                    top: listView.top
                                    bottom: listView.bottom
                                    right: parent.right
                                    rightMargin: -2
                                }

                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        bottom: parent.bottom
                                        horizontalCenter: parent.horizontalCenter
                                    }
                                    width: 3
                                    radius: width / 2
                                    color: Qt.rgba(0.851, 0.867, 0.902, 0.16)
                                }

                                Rectangle {
                                    id: clipboardScrollThumb

                                    width: clipboardScrollDrag.containsMouse || clipboardScrollDrag.pressed ? 9 : 5
                                    height: clipboardScrollTrack.thumbHeight
                                    radius: width / 2
                                    color: Qt.rgba(0.851, 0.867, 0.902, clipboardScrollDrag.containsMouse || clipboardScrollDrag.pressed ? 0.68 : 0.42)
                                    x: (parent.width - width) / 2
                                    y: clipboardScrollTrack.maxContentY > 0
                                       ? (parent.height - height) * listView.contentY / clipboardScrollTrack.maxContentY
                                       : 0

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 100
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                MouseArea {
                                    id: clipboardScrollDrag

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    onPressed: (mouse) => clipboardScrollTrack.moveTo(mouse.y)
                                    onPositionChanged: (mouse) => {
                                        if (pressed)
                                            clipboardScrollTrack.moveTo(mouse.y);
                                    }
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
