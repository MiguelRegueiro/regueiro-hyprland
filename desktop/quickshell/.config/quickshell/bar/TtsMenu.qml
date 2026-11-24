import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components" as Components
import "../theme/Theme.js" as Theme

PanelWindow {
    id: root
    required property var targetScreen
    required property var ttsService
    property bool open: false
    property bool fullscreenActive: false
    property string provider: "kokoro"
    property string voice: "kokoro-michael"
    property string rate: "+50%"
    property int selectorOpen: 0
    readonly property var kokoroVoices: [
        { label: "Michael · US English male", value: "kokoro-michael" },
        { label: "Onyx · US English male", value: "kokoro-onyx" }
    ]
    readonly property var edgeVoices: [
        { label: "Christopher · Edge US male", value: "en-US-ChristopherNeural" },
        { label: "Roger · Edge US male", value: "en-US-RogerNeural" },
        { label: "Guy · Edge US male", value: "en-US-GuyNeural" },
        { label: "Andrew · Edge multilingual male", value: "en-US-AndrewMultilingualNeural" }
    ]
    readonly property var voiceOptions: provider === "edge" ? edgeVoices : kokoroVoices
    signal closeRequested
    signal barPressed(real x, real y)

    onOpenChanged: {
        if (!open)
            selectorOpen = 0;
        else
            syncPreferences();
    }

    function routeBarPress(mouse) {
        if (mouse.button !== Qt.LeftButton || mouse.y < 0 || mouse.y >= Theme.barHeight)
            return false;

        root.barPressed(mouse.x, mouse.y);
        return true;
    }

    function chooseSelectorOption(data, itemIndex) {
        if (selectorOpen === 1) {
            provider = data.value;
            modelBox.currentIndex = itemIndex;
            voice = voiceOptions[0].value;
            voiceBox.currentIndex = 0;
        } else if (selectorOpen === 2) {
            voice = data.value;
            voiceBox.currentIndex = itemIndex;
        } else if (selectorOpen === 3) {
            rate = data.value;
            speedBox.currentIndex = itemIndex;
        }
        selectorOpen = 0;
        ttsService.setPreferences(provider, voice, rate);
    }

    function syncPreferences() {
        if (ttsService.provider) {
            provider = ttsService.provider;
            for (let index = 0; index < modelBox.model.length; index++) {
                if (modelBox.model[index].value === provider) {
                    modelBox.currentIndex = index;
                    break;
                }
            }
        }
        if (ttsService.voice) {
            voice = ttsService.voice;
            for (let index = 0; index < voiceOptions.length; index++) {
                if (voiceOptions[index].value === voice) {
                    voiceBox.currentIndex = index;
                    break;
                }
            }
        }
        if (ttsService.rate) {
            rate = ttsService.rate;
            for (let index = 0; index < speedBox.model.length; index++) {
                if (speedBox.model[index].value === rate) {
                    speedBox.currentIndex = index;
                    break;
                }
            }
        }
    }

    Component.onCompleted: syncPreferences()

    screen: targetScreen
    visible: open
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-tts-menu"
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    // Leave the bar outside the popup's input region unless a fullscreen
    // window requires this overlay to own the bar. This lets the bar receive
    // clicks and switch directly to another menu.
    mask: Region {
        x: 0
        y: root.fullscreenActive ? 0 : Theme.barHeight
        width: root.open ? Math.round(root.width) : 0
        height: root.open ? Math.max(0, Math.round(root.height - (root.fullscreenActive ? 0 : Theme.barHeight))) : 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.open
        onPressed: mouse => {
            if (root.fullscreenActive && root.routeBarPress(mouse))
                return;

            root.closeRequested();
        }
    }
    Rectangle {
        id: ttsPanel
        width: 520; height: 176
        x: Math.max(8, parent.width - width - 108)
        y: Theme.barHeight + Theme.topBarMenuTopGap
        radius: Theme.ncSurfaceBottomLeftRadius
        // Match the selector's neutral frosted material rather than the
        // cooler quick-settings surface.
        color: Qt.rgba(0.115, 0.12, 0.135, 0.84)
        border.width: 1; border.color: ttsPanel.outline
        // Same neutral grey used by a hovered selector row: it stays glassy
        // instead of reading as a separate bluish button material.
        readonly property color controlBg: Qt.rgba(1, 1, 1, 0.10)
        readonly property color outline: Theme.menuSurfaceOutline
        readonly property color controlBorder: Qt.rgba(0.56, 0.58, 0.62, 0.22)
        readonly property color controlBorderActive: Qt.rgba(0.62, 0.64, 0.68, 0.35)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.96)
            shadowBlur: 0.72
            shadowVerticalOffset: 2
            blurMax: 28
        }
        MouseArea {
            anchors.fill: parent
            onPressed: {
                if (root.selectorOpen !== 0)
                    root.selectorOpen = 0;
            }
        }
        Item {
            anchors.fill: parent; anchors.margins: 16
            RowLayout {
                id: selectors
                width: parent.width; height: 42; spacing: 12
                ComboBox {
                    id: modelBox
                    Layout.preferredWidth: 160
                    Layout.fillHeight: true
                    model: [
                        { label: "Local · Kokoro fast", value: "kokoro" },
                        { label: "Edge · online test", value: "edge" }
                    ]
                    textRole: "label"
                    valueRole: "value"
                    contentItem: Text { leftPadding: 14; rightPadding: 30; text: modelBox.displayText; color: Theme.textPrimary; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    indicator: Text { x: modelBox.width - width - 12; anchors.verticalCenter: parent.verticalCenter; text: "󰅀"; color: Theme.textPrimary; font.family: Theme.fontIcons; font.pixelSize: 14 }
                    background: Rectangle { radius: 12; color: ttsPanel.controlBg; border.width: 1; border.color: modelBox.activeFocus ? ttsPanel.controlBorderActive : ttsPanel.controlBorder }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.selectorOpen = root.selectorOpen === 1 ? 0 : 1
                    }
                }
                ComboBox {
                    id: voiceBox
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.voiceOptions
                    textRole: "label"
                    valueRole: "value"
                    onActivated: root.voice = currentValue
                    contentItem: Text { leftPadding: 16; rightPadding: 34; text: voiceBox.displayText; color: Theme.textPrimary; font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.Medium; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    indicator: Text { x: voiceBox.width - width - 14; anchors.verticalCenter: parent.verticalCenter; text: "󰅀"; color: Theme.textPrimary; font.family: Theme.fontIcons; font.pixelSize: 14 }
                    background: Rectangle { radius: 12; color: ttsPanel.controlBg; border.width: 1; border.color: voiceBox.activeFocus ? ttsPanel.controlBorderActive : ttsPanel.controlBorder }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.selectorOpen = root.selectorOpen === 2 ? 0 : 2
                    }
                }
                ComboBox {
                    id: speedBox
                    Layout.preferredWidth: 102
                    Layout.fillHeight: true
                    model: [{ label: "0.75×", value: "-25%" }, { label: "1×", value: "+0%" }, { label: "1.25×", value: "+25%" }, { label: "1.5×", value: "+50%" }, { label: "1.75×", value: "+75%" }, { label: "2×", value: "+100%" }]
                    currentIndex: 3
                    textRole: "label"
                    valueRole: "value"
                    onActivated: root.rate = currentValue
                    contentItem: Text { leftPadding: 16; rightPadding: 28; text: speedBox.displayText; color: Theme.textPrimary; font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.Medium; verticalAlignment: Text.AlignVCenter }
                    indicator: Text { x: speedBox.width - width - 14; anchors.verticalCenter: parent.verticalCenter; text: "󰅀"; color: Theme.textPrimary; font.family: Theme.fontIcons; font.pixelSize: 14 }
                    background: Rectangle { radius: 12; color: ttsPanel.controlBg; border.width: 1; border.color: speedBox.activeFocus ? ttsPanel.controlBorderActive : ttsPanel.controlBorder }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.selectorOpen = root.selectorOpen === 3 ? 0 : 3
                    }
                }
            }
            Row {
                x: Math.round((parent.width - width) / 2); y: 54; spacing: 10
                ButtonControl { text: ttsService.status === "generating" ? "Cancel" : "Speak"; primary: true; onClicked: ttsService.status === "generating" ? ttsService.cancel() : ttsService.speakClipboard(root.provider, root.voice, root.rate) }
                ButtonControl { text: ttsService.status === "playing" ? "󰏤" : "󰐊"; icon: true; onClicked: ttsService.toggle() }
                ButtonControl { text: "■"; compact: true; onClicked: ttsService.reset() }
            }
            RowLayout {
                x: 0; y: 96; width: parent.width; height: 28; spacing: 10
                readonly property bool playbackActive: ttsService.status === "playing" || ttsService.status === "paused"
                Text { text: root.formatTime(parent.playbackActive ? ttsService.position : 0); color: Theme.textDim; font.family: Theme.fontUi; font.pixelSize: 12 }
                Slider {
                    id: progress
                    Layout.fillWidth: true
                    property bool dragging: false
                    property bool awaitingSeek: false
                    property real draggedValue: 0
                    from: 0; to: Math.max(0.01, ttsService.duration); value: dragging ? draggedValue : (parent.playbackActive ? ttsService.position : 0)
                    enabled: parent.playbackActive
                    onMoved: draggedValue = value
                    onPressedChanged: {
                        if (pressed) {
                            awaitingSeek = false;
                            seekConfirmTimer.stop();
                            dragging = true;
                            draggedValue = value;
                        } else {
                            ttsService.seek(draggedValue);
                            awaitingSeek = true;
                            seekConfirmTimer.restart();
                        }
                    }
                    Timer {
                        id: seekConfirmTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            progress.awaitingSeek = false;
                            progress.dragging = false;
                        }
                    }
                    background: Rectangle { x: progress.leftPadding; y: progress.topPadding + progress.availableHeight / 2 - height / 2; width: progress.availableWidth; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.14); Rectangle { width: progress.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: Theme.accent } }
                    handle: Rectangle {
                        x: progress.leftPadding + progress.visualPosition * (progress.availableWidth - width)
                        y: progress.topPadding + progress.availableHeight / 2 - height / 2
                        width: 18; height: 18; radius: 9
                        color: "white"
                        scale: progress.pressed ? 1.16 : (progressHover.hovered ? 1.08 : 1)
                        transformOrigin: Item.Center
                        Behavior on scale { Components.Anim { curve: Components.Anim.FastEffects; duration: Theme.animDurFastEffects } }
                    }
                    HoverHandler { id: progressHover; cursorShape: Qt.ArrowCursor }
                }
                Text { text: root.formatTime(parent.playbackActive ? ttsService.duration : 0); color: Theme.textDim; font.family: Theme.fontUi; font.pixelSize: 12 }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 127; text: ttsService.status === "idle" ? "Ready" : (ttsService.detail || "Preparing speech"); color: Theme.textDim; font.family: Theme.fontUi; font.pixelSize: 12 }
        }
    }
    PanelWindow {
        id: selectorWindow
        readonly property real panelX: Math.max(8, root.width - 520 - 108)
        readonly property real modelWidth: 160
        readonly property real voiceWidth: 520 - 32 - 24 - modelWidth - 102
        readonly property real speedWidth: 102
        readonly property real selectorX: root.selectorOpen === 1 ? panelX + 16 : (root.selectorOpen === 2 ? panelX + 16 + modelWidth + 12 : panelX + 16 + modelWidth + 12 + voiceWidth + 12)
        readonly property real selectorY: Theme.barHeight + Theme.topBarMenuTopGap + 16 + 42 + 3
        readonly property real selectorWidth: root.selectorOpen === 1 ? modelWidth : (root.selectorOpen === 2 ? voiceWidth : speedWidth)
        screen: root.targetScreen
        visible: root.open && root.selectorOpen !== 0
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // This is intentionally its own layer surface: Hyprland can blur its
        // backdrop just like the TTS OSD, rather than only tinting the parent.
        WlrLayershell.namespace: "qs-tts-menu"
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }

        mask: Region {
            x: Math.round(selectorMenu.x)
            y: Math.round(selectorMenu.y)
            width: Math.round(selectorMenu.width)
            height: Math.round(selectorMenu.height)
        }

        Rectangle {
            id: selectorMenu
            readonly property var sourceCombo: root.selectorOpen === 1 ? modelBox : (root.selectorOpen === 2 ? voiceBox : speedBox)

            x: selectorWindow.selectorX
            y: selectorWindow.selectorY
            width: selectorWindow.selectorWidth
            height: Math.min(348, selectorList.contentHeight + 8)
            radius: 12
            color: Theme.osdSurfaceBg
            border.width: 1
            border.color: Qt.rgba(0.56, 0.58, 0.62, 0.42)
            clip: true

            ListView {
                id: selectorList
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: selectorMenu.sourceCombo.model
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property int index
                    required property var modelData
                    width: selectorList.width
                    height: 38
                    Rectangle {
                        x: 6
                        width: parent.width - (selectorScrollTrack.visible ? 20 : 12)
                        height: parent.height
                        radius: 9
                        color: selectorInput.hoveredIndex === parent.index ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14
                            width: parent.width - 28
                            text: modelData.label
                            color: Theme.textPrimary
                            font.family: Theme.fontUi
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            Item {
                id: selectorScrollTrack
                visible: selectorList.contentHeight > selectorList.height
                width: visible ? 14 : 0
                anchors.top: selectorList.top
                anchors.bottom: selectorList.bottom
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                anchors.right: selectorList.right
                readonly property bool active: selectorInput.draggingThumb || selectorInput.overScrollTrack
                readonly property real thumbHeight: Math.max(28, height * selectorList.visibleArea.heightRatio)
                readonly property real thumbTravel: Math.max(0, height - thumbHeight)
                readonly property real contentRange: Math.max(0, selectorList.contentHeight - selectorList.height)
                readonly property real scrollProgress: contentRange > 0 ? Math.max(0, Math.min(1, (selectorList.contentY - selectorList.originY) / contentRange)) : 0
                Rectangle {
                    width: 3
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: width / 2
                    color: Qt.rgba(0.851, 0.867, 0.902, 0.16)
                }
                Rectangle {
                    width: parent.active ? 8 : 5
                    height: parent.thumbHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.scrollProgress * parent.thumbTravel
                    radius: width / 2
                    color: Qt.rgba(0.851, 0.867, 0.902, parent.active ? 0.58 : 0.36)
                    Behavior on width { Components.Anim { curve: Components.Anim.FastEffects; duration: Theme.animDurFastEffects } }
                    Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }
                }
            }
        }
        MouseArea {
            id: selectorInput
            anchors.fill: parent
            z: 10
            property bool draggingThumb: false
            property real pressY: 0
            property real startContentY: 0
            property int hoveredIndex: -1
            readonly property bool overScrollTrack: containsMouse
                && mouseX >= selectorMenu.x + selectorList.x + selectorList.width - selectorScrollTrack.width
                && mouseX <= selectorMenu.x + selectorList.x + selectorList.width
                && mouseY >= selectorMenu.y + selectorList.y
                && mouseY <= selectorMenu.y + selectorList.y + selectorList.height
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            hoverEnabled: true
            cursorShape: draggingThumb ? Qt.ClosedHandCursor : (overScrollTrack ? Qt.OpenHandCursor : Qt.PointingHandCursor)

            function maxContentY() {
                return Math.max(0, selectorList.contentHeight - selectorList.height);
            }
            function scrollBy(delta) {
                selectorList.contentY = Math.max(0, Math.min(maxContentY(), selectorList.contentY + delta));
            }
            function updateHovered(mouse) {
                const localX = mouse.x - selectorMenu.x - selectorList.x;
                const localY = mouse.y - selectorMenu.y - selectorList.y + selectorList.contentY - selectorList.originY;
                hoveredIndex = localX >= 6 && localX < selectorList.width - (selectorScrollTrack.visible ? 14 : 6)
                    ? Math.floor(localY / 38) : -1;
            }
            onPressed: mouse => {
                updateHovered(mouse);
                pressY = mouse.y;
                startContentY = selectorList.contentY;
                const localX = mouse.x - selectorMenu.x;
                draggingThumb = selectorScrollTrack.visible && localX >= selectorList.x + selectorList.width - selectorScrollTrack.width;
            }
            onPositionChanged: mouse => {
                updateHovered(mouse);
                if (!draggingThumb || !pressed)
                    return;
                const travel = Math.max(1, selectorScrollTrack.thumbTravel);
                selectorList.contentY = Math.max(selectorList.originY, Math.min(selectorList.originY + maxContentY(), startContentY + (mouse.y - pressY) / travel * maxContentY()));
            }
            onReleased: mouse => {
                if (!draggingThumb && Math.abs(mouse.y - pressY) < 6) {
                    const localY = mouse.y - selectorMenu.y - selectorList.y;
                    const itemIndex = Math.floor((localY + selectorList.contentY - selectorList.originY) / 38);
                    const model = selectorMenu.sourceCombo.model;
                    if (itemIndex >= 0 && itemIndex < model.length)
                        root.chooseSelectorOption(model[itemIndex], itemIndex);
                }
                draggingThumb = false;
                updateHovered(mouse);
            }
            onWheel: wheel => {
                const delta = wheel.pixelDelta.y !== 0 ? -wheel.pixelDelta.y : -wheel.angleDelta.y / 120 * 54;
                scrollBy(delta);
                wheel.accepted = true;
            }
        }
    }
    function formatTime(seconds) {
        const value = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0");
    }
    component ButtonControl: Rectangle {
        required property string text
        property bool icon: false
        property bool compact: false
        property bool primary: false
        signal clicked
        implicitWidth: icon || compact ? 46 : label.implicitWidth + 30; implicitHeight: 40; radius: 12
        color: ttsPanel.controlBg; border.width: 1; border.color: ttsPanel.controlBorder
        Text { id: label; anchors.centerIn: parent; text: parent.text; font.family: parent.icon ? Theme.fontIcons : Theme.fontUi; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.textPrimary }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }
    Connections {
        target: ttsService
        function onVoiceChanged() { root.syncPreferences(); }
        function onRateChanged() { root.syncPreferences(); }
        function onPositionChanged() {
            if (progress.awaitingSeek && Math.abs(ttsService.position - progress.draggedValue) < 0.5) {
                progress.awaitingSeek = false;
                progress.dragging = false;
                seekConfirmTimer.stop();
            }
        }
    }
}
