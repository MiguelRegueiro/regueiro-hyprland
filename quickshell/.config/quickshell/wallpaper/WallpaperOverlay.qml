import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root

    required property var targetScreen
    property bool open: false
    property string currentWallpaper: ""
    property int selectedIndex: 0
    property int selectionDirection: 0
    property bool carouselInitialized: false
    property bool carouselVisible: false
    property bool carouselMotionEnabled: false
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/regueiro-hyprland/wallpapers"
    property var previewSources: ({})

    // Warm the disk cache while hidden. Periodic metadata checks also catch
    // replacements that do not change FolderListModel's file count.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!thumbnailProcess.running) thumbnailProcess.running = true; }
    }

    Process {
        id: thumbnailProcess
        command: ["python3", (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/scripts/wallpaper-thumbnails.py", root.wallpaperDir]
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                const fallback = {};
                for (let i = 0; i < wallpaperFiles.count; i++)
                    fallback[root.pathForIndex(i)] = wallpaperFiles.get(i, "fileUrl").toString();
                root.previewSources = fallback;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    if (JSON.stringify(next) !== JSON.stringify(root.previewSources))
                        root.previewSources = next;
                } catch (error) {
                    console.warn("Could not load wallpaper previews: " + error);
                }
            }
        }
    }

    signal requestClose()

    function pathForIndex(index) {
        if (index < 0 || index >= wallpaperFiles.count)
            return "";
        return decodeURIComponent(wallpaperFiles.get(index, "fileUrl").toString().replace(/^file:\/\//, ""));
    }

    function indexForPath(path) {
        for (let index = 0; index < wallpaperFiles.count; index++) {
            if (pathForIndex(index) === path)
                return index;
        }
        return 0;
    }

    function selectAdjacent(direction) {
        if (wallpaperFiles.count === 0)
            return;
        selectionDirection = direction;
        selectedIndex = (selectedIndex + direction + wallpaperFiles.count) % wallpaperFiles.count;
    }

    function applySelected() {
        const path = pathForIndex(selectedIndex);
        if (!path)
            return;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/set-wallpaper", path]);
        currentWallpaper = path;
        requestClose();
    }

    function focusCarousel() {
        if (open && wallpaperFiles.count > 0)
            Qt.callLater(function() { carousel.forceActiveFocus(); });
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/regueiro-hyprland/wallpaper"
        watchChanges: true
        onLoaded: {
            root.carouselInitialized = false;
            root.currentWallpaper = this.text().trim();
            root.selectedIndex = root.indexForPath(root.currentWallpaper);
            carouselSettleTimer.restart();
        }
    }

    Timer {
        id: carouselSettleTimer

        interval: 220
        repeat: false
        onTriggered: root.carouselInitialized = true
    }

    Timer {
        id: carouselOpenTimer

        interval: 70
        repeat: false
        onTriggered: {
            if (!root.open)
                return;
            root.carouselVisible = true;
            root.focusCarousel();
            carouselMotionTimer.start();
        }
    }

    Timer {
        id: carouselMotionTimer

        interval: 30
        repeat: false
        onTriggered: {
            if (root.open)
                root.carouselMotionEnabled = true;
        }
    }

    onOpenChanged: {
        carouselVisible = false;
        carouselMotionEnabled = false;
        carouselOpenTimer.stop();
        carouselMotionTimer.stop();
        if (open) {
            carouselOpenTimer.start();
        }
    }

    screen: targetScreen
    visible: open
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-wallpaper-picker"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.open
        onActivated: root.requestClose()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    Item {
        id: picker

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 28
        width: Math.min(parent.width - 72, 1580)
        height: Math.min(parent.height - 110, 600)

        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
            anchors.centerIn: parent
            visible: wallpaperFiles.count > 0 && Object.keys(root.previewSources).length === 0
            text: "Preparing wallpaper previews…"
            color: "white"
        }

        Item {
            id: carousel

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            height: Math.min(475, parent.height - 74)
            focus: true

            readonly property real expandedWidth: Math.min(768, width * 0.58)
            readonly property real expandedHeight: height
            readonly property real sliceWidth: Math.min(108, width * 0.09)
            readonly property real sliceHeight: expandedHeight - 42
            readonly property real sliceStep: sliceWidth - 30
            readonly property real sliceGap: -30
            readonly property real skewOffset: 28
            readonly property real previewX: (width - expandedWidth) / 2

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.requestClose();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.applySelected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.selectAdjacent(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    root.selectAdjacent(1);
                    event.accepted = true;
                }
            }

            Repeater {
                model: wallpaperFiles

                delegate: Item {
                    id: wallpaperSlice

                    required property int index
                    required property url fileUrl

                    readonly property int relativeIndex: {
                        const count = wallpaperFiles.count;
                        if (count === 0)
                            return 0;

                        let relative = index - root.selectedIndex;
                        const half = Math.floor(count / 2);
                        if (relative > half)
                            relative -= count;
                        else if (relative < -half)
                            relative += count;
                        return relative;
                    }
                    readonly property bool selected: relativeIndex === 0
                    readonly property bool nearby: Math.abs(relativeIndex) <= 6
                    visible: root.carouselVisible && root.carouselInitialized && nearby
                    width: selected ? carousel.expandedWidth : carousel.sliceWidth
                    height: selected ? carousel.expandedHeight : carousel.sliceHeight
                    x: selected ? carousel.previewX
                                : (relativeIndex < 0
                                   ? carousel.previewX + relativeIndex * carousel.sliceStep
                                   : carousel.previewX + carousel.expandedWidth + carousel.sliceGap + (relativeIndex - 1) * carousel.sliceStep)
                    y: selected ? 0 : (carousel.expandedHeight - height) / 2
                    z: selected ? 100 : 50 - Math.abs(relativeIndex)

                    Item {
                        id: roundedMask

                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: wallpaperSlice.selected ? 22 : 14
                            color: "white"
                        }
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: roundedMask
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }

                        Image {
                            anchors.fill: parent
                            readonly property string originalPath: root.pathForIndex(wallpaperSlice.index)
                            source: root.previewSources[originalPath] || ""
                            fillMode: Image.PreserveAspectCrop
                            // Cached previews are cheap to decode. If conversion
                            // failed, never synchronously decode the original.
                            asynchronous: source.toString() === wallpaperSlice.fileUrl.toString()
                            cache: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: wallpaperSlice.selected ? "transparent" : Qt.rgba(0.004, 0.006, 0.012, 0.48)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: wallpaperSlice.selected
                        radius: 22
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(0.851, 0.867, 0.902, 0.44)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (wallpaperSlice.selected) {
                                root.applySelected();
                            } else {
                                root.selectionDirection = wallpaperSlice.index > root.selectedIndex ? 1 : -1;
                                root.selectedIndex = wallpaperSlice.index;
                            }
                        }
                    }
                }
            }
        }

    }

    FolderListModel {
        id: wallpaperFiles

        folder: "file://" + root.wallpaperDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: {
            if (!thumbnailProcess.running)
                thumbnailProcess.running = true;
            if (count > 0) {
                root.selectedIndex = root.indexForPath(root.currentWallpaper);
                carouselSettleTimer.restart();
                root.focusCarousel();
            }
        }
    }
}
