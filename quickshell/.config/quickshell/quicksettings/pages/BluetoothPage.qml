import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../../theme/Theme.js" as Theme

Item {
    id: root

    property bool btOn: false
    property string connectedDevice: ""
    property bool menuOpen: false
    property var _devices: []
    property string _actingMac: "" // MAC currently being acted on
    property bool _actingIsDisconn: false // Whether current action is disconnection
    property string _resultMac: "" // MAC that just got a result
    property bool _resultOk: false

    signal backClicked()

    function toggle() {
        btOn = !btOn;
        btToggleProc.running = true;
        afterToggle.start();
    }

    Layout.fillWidth: true
    // Fixed height for the submenu to allow scrolling
    implicitHeight: 460
    onMenuOpenChanged: {
        if (menuOpen)
            pollProc.running = true;

    }

    // ── Layout ────────────────────────────────────────────────────
    ColumnLayout {
        id: col

        anchors.fill: parent
        spacing: 0

        // BT on/off header
        Rectangle {
            Layout.fillWidth: true
            height: 52
            radius: 18
            color: Theme.qsCardBg
            border.width: 1
            border.color: Theme.qsCardBorder

            RowLayout {
                spacing: 0

                anchors {
                    fill: parent
                    leftMargin: 4
                    rightMargin: 8
                }

                // Back button
                Rectangle {
                    readonly property bool hovered: backHover.hovered

                    width: 44
                    height: 44
                    radius: 22
                    color: hovered ? Theme.qsCardChipBgHover : "transparent"
                    border.width: hovered ? 1 : 0
                    border.color: Theme.qsCardChipBorderHover

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: Theme.fontIcons
                        font.pixelSize: 18
                        color: Theme.textPrimary
                    }

                    HoverHandler {
                        id: backHover

                        blocking: false
                        cursorShape: Qt.ArrowCursor
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.backClicked()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }

                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 110
                        }

                    }

                }

                Item {
                    width: 8
                }

                Text {
                    text: root.btOn ? "󰂯" : "󰂲"
                    font.family: Theme.fontIcons
                    font.pixelSize: 18
                    color: root.btOn ? Theme.accent : Theme.textDim
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Item {
                    width: 3
                }

                Text {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                // Toggle pill
                Rectangle {
                    width: 48
                    height: 26
                    radius: 13
                    color: root.btOn ? Theme.tileActiveBg : Theme.qsCardChipBg
                    border.width: 1
                    border.color: root.btOn ? Theme.tileActiveBorder : Theme.qsCardChipBorder

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.btOn ? parent.width - width - 3 : 3

                        Behavior on x {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.ArrowCursor
                        onClicked: root.toggle()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }

                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 80
                        }

                    }

                }

            }

        }

        Item {
            height: 8
        }

        // Scrollable area for device list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: listCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: listCol

                width: parent.width
                spacing: 4

                Repeater {
                    model: root.btOn ? root._devices : []

                    delegate: Rectangle {
                        id: devRow

                        required property var modelData
                        readonly property bool _acting: root._actingMac === modelData.mac
                        readonly property bool _hasResult: root._resultMac === modelData.mac

                        Layout.fillWidth: true
                        height: 52
                        radius: 18
                        color: devRow.modelData.connected ? Qt.rgba(0.122, 0.122, 0.122, 0.98) : (btHover.hovered ? Theme.qsCardBgHover : Theme.qsCardBg)
                        border.width: 1
                        border.color: devRow.modelData.connected ? Qt.rgba(1, 1, 1, 0.14) : (btHover.hovered ? Theme.qsCardBorderHover : Theme.qsCardBorder)

                        RowLayout {
                            spacing: 10

                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: devRow.modelData.connected ? Qt.rgba(1, 1, 1, 0.12) : (btHover.hovered ? Theme.qsCardChipBgHover : Theme.qsCardChipBg)
                                border.width: 1
                                border.color: devRow.modelData.connected ? Qt.rgba(1, 1, 1, 0.12) : (btHover.hovered ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder)

                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 1
                                    text: "󰂯"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 15
                                    color: devRow.modelData.connected ? Theme.textPrimary : Theme.textDim
                                }

                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: devRow.modelData.name || devRow.modelData.mac
                                    font.family: Theme.fontUi
                                    font.pixelSize: 12
                                    font.weight: devRow.modelData.connected ? Font.DemiBold : Font.Medium
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: devRow.modelData.connected ? "Connected" : "Paired device"
                                    font.family: Theme.fontUi
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                }

                            }

                            Rectangle {
                                id: actionBtn

                                readonly property bool busy: devRow._acting
                                readonly property bool hasResult: devRow._hasResult
                                readonly property bool ok: root._resultOk
                                readonly property bool connected: devRow.modelData.connected

                                width: 112
                                height: 30
                                radius: 15
                                color: {
                                    if (hasResult)
                                        return ok ? Theme.qsCardChipBgHover : Qt.rgba(1, 0.35, 0.35, 0.14);

                                    if (busy)
                                        return Theme.qsCardChipBg;

                                    return connected ? Theme.qsCardChipBgHover : (btnMouse.containsMouse ? Theme.qsCardChipBgHover : Theme.qsCardChipBg);
                                }
                                border.width: 1
                                border.color: btnMouse.containsMouse ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

                                Text {
                                    id: btnLabel

                                    anchors.centerIn: parent
                                    font.family: Theme.fontUi
                                    font.pixelSize: 11
                                    text: {
                                        if (actionBtn.hasResult) {
                                            if (root._actingIsDisconn)
                                                return actionBtn.ok ? "Disconnected" : "Failed";

                                            return actionBtn.ok ? "Connected" : "Failed";
                                        }
                                        if (actionBtn.busy)
                                            return actionBtn.connected ? "Disconnecting…" : "Connecting…";

                                        return actionBtn.connected ? "Disconnect" : "Connect";
                                    }
                                    color: {
                                        if (actionBtn.hasResult)
                                            return actionBtn.ok ? Theme.textPrimary : Theme.red;

                                        if (actionBtn.busy)
                                            return Theme.textDisabled;

                                        return Theme.textPrimary;
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }

                                    }

                                }

                                MouseArea {
                                    id: btnMouse

                                    anchors.fill: parent
                                    preventStealing: true
                                    cursorShape: Qt.ArrowCursor
                                    hoverEnabled: true
                                    enabled: !actionBtn.busy && !actionBtn.hasResult
                                    onClicked: {
                                        root._resultMac = "";
                                        root._actingMac = devRow.modelData.mac;
                                        root._actingIsDisconn = devRow.modelData.connected;
                                        if (devRow.modelData.connected) {
                                            btDisconnProc.command = ["bluetoothctl", "disconnect", devRow.modelData.mac];
                                            btDisconnProc.running = true;
                                        } else {
                                            btConnProc.command = ["bluetoothctl", "connect", devRow.modelData.mac];
                                            btConnProc.running = true;
                                        }
                                        actionTimeout.restart();
                                    }
                                }

                            }

                        }

                        HoverHandler {
                            id: btHover

                            blocking: false
                            cursorShape: Qt.ArrowCursor
                        }

                    }

                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.btOn && root._devices.length === 0
                    height: 48
                    radius: 18
                    color: Theme.qsCardBg
                    border.width: 1
                    border.color: Theme.qsCardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "No paired devices"
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        color: Theme.textDisabled
                    }

                }

            }

            ScrollBar.vertical: ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                background: null

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.2)
                }

            }

        }

        Item {
            height: 8
        }

        // Footer with Search button
        Rectangle {
            id: footerButton

            Layout.fillWidth: true
            height: 48
            radius: 18
            color: searchMouse.containsMouse ? Theme.qsCardBgHover : Theme.qsCardBg
            border.width: 1
            border.color: searchMouse.containsMouse ? Theme.qsCardBorderHover : Theme.qsCardBorder

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰂰"
                    font.family: Theme.fontIcons
                    font.pixelSize: 16
                    color: Theme.textPrimary
                }

                Text {
                    text: "Bluetooth Settings"
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    color: Theme.textPrimary
                }

            }

            MouseArea {
                id: searchMouse

                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.ArrowCursor
                hoverEnabled: true
                onClicked: {
                    searchProc.running = true;
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 110
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 110
                }

            }

        }

    }

    // ── Timers ────────────────────────────────────────────────────
    Timer {
        id: afterToggle

        interval: 800
        onTriggered: pollProc.running = true
    }

    Timer {
        id: actionTimeout

        interval: 20000 // 20s hard timeout
        onTriggered: {
            root._resultOk = false;
            root._resultMac = root._actingMac;
            resultClearTimer.start();
        }
    }

    Timer {
        id: resultClearTimer

        interval: 2500
        onTriggered: {
            root._resultMac = "";
            root._actingMac = "";
            pollProc.running = true;
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    // ── Processes ─────────────────────────────────────────────────
    Process {
        id: pollProc

        command: ["bash", "-c", "echo \"bt:$(/usr/bin/bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}')\";" + "connected=$(/usr/bin/bluetoothctl devices Connected 2>/dev/null | awk '{print $2}' | tr '\\n' ' ');" + "/usr/bin/bluetoothctl devices Paired 2>/dev/null | while read _ mac name; do " + "  if echo \"$connected\" | grep -qF \"$mac\"; then echo \"DEV|$mac|${name}|yes\"; " + "  else echo \"DEV|$mac|${name}|no\"; fi; done"]

        stdout: StdioCollector {
            id: pollData

            onStreamFinished: {
                var lines = pollData.text.split("\n");
                var devs = [], connName = "";
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.startsWith("bt:")) {
                        root.btOn = line.slice(3).trim() === "yes";
                    } else if (line.startsWith("DEV|")) {
                        var p = line.split("|");
                        if (p.length >= 4) {
                            var dev = {
                                "mac": p[1],
                                "name": p[2],
                                "connected": p[3] === "yes"
                            };
                            devs.push(dev);
                            if (dev.connected && !connName)
                                connName = dev.name;

                        }
                    }
                }
                root._devices = devs;
                root.connectedDevice = connName;
            }
        }

    }

    Process {
        id: btToggleProc

        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/bt-toggle.sh"]
    }

    Process {
        id: searchProc

        command: ["blueman-manager"]
    }

    Process {
        id: btConnProc

        command: ["echo"]

        stdout: SplitParser {
            onRead: (line) => {
                var l = line.toLowerCase();
                if (l.indexOf("successful") >= 0 || l.indexOf("already connected") >= 0) {
                    actionTimeout.stop();
                    root._resultOk = true;
                    root._resultMac = root._actingMac;
                    resultClearTimer.start();
                } else if (l.indexOf("failed") >= 0 || l.indexOf("error") >= 0 || l.indexOf("not available") >= 0) {
                    actionTimeout.stop();
                    root._resultOk = false;
                    root._resultMac = root._actingMac;
                    resultClearTimer.start();
                }
            }
        }

    }

    Process {
        id: btDisconnProc

        command: ["echo"]

        stdout: SplitParser {
            onRead: (line) => {
                var l = line.toLowerCase();
                if (l.indexOf("successful") >= 0 || l.indexOf("not connected") >= 0) {
                    actionTimeout.stop();
                    root._resultOk = true;
                    root._resultMac = root._actingMac;
                    resultClearTimer.start();
                } else if (l.indexOf("failed") >= 0 || l.indexOf("error") >= 0) {
                    actionTimeout.stop();
                    root._resultOk = false;
                    root._resultMac = root._actingMac;
                    resultClearTimer.start();
                }
            }
        }

    }

}
