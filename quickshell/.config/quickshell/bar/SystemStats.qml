import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Row {
    id: root

    property int barHeight: 34
    property bool cpuMenuOpen: false
    property bool ramMenuOpen: false
    property int cpuPct: 0
    property real ramUsedGb: 0
    // ── CPU polling ────────────────────────────────────────────
    // Read kern.cp_time twice to compute delta on FreeBSD.
    property var _prevIdle: 0
    property var _prevTotal: 0

    spacing: 0

    signal cpuClicked()
    signal ramClicked()

    Timer {
        interval: Theme.statsFastInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }

    Process {
        id: cpuProc

        command: ["sh", "-c", "/sbin/sysctl -n kern.cp_time 2>/dev/null"]

        stdout: StdioCollector {
            id: cpuOut

            onStreamFinished: {
                var parts = cpuOut.text.trim().split(/\s+/);
                if (parts.length < 5)
                    return ;

                var user = parseInt(parts[0]);
                var nice = parseInt(parts[1]);
                var sys = parseInt(parts[2]);
                var intr = parseInt(parts[3]);
                var idle = parseInt(parts[4]);
                var total = user + nice + sys + idle + intr;
                var dTotal = total - root._prevTotal;
                var dIdle = idle - root._prevIdle;
                if (dTotal > 0)
                    root.cpuPct = Math.round(100 * (dTotal - dIdle) / dTotal);

                root._prevTotal = total;
                root._prevIdle = idle;
            }
        }

    }

    // ── RAM polling ────────────────────────────────────────────
    Timer {
        interval: Theme.statsSlowInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ramProc.running = true
    }

    Process {
        id: ramProc

        command: ["sh", "-c", "active=$(/sbin/sysctl -n vm.stats.vm.v_active_count 2>/dev/null); wired=$(/sbin/sysctl -n vm.stats.vm.v_wire_count 2>/dev/null); pagesize=$(/sbin/sysctl -n hw.pagesize 2>/dev/null); if [ -n \"$active\" ] && [ -n \"$wired\" ] && [ -n \"$pagesize\" ]; then used=$(((active + wired) * pagesize)); awk -v used=\"$used\" 'BEGIN { printf \"%.1f\", used / 1073741824 }'; fi"]

        stdout: StdioCollector {
            id: ramOut

            onStreamFinished: {
                var val = parseFloat(ramOut.text.trim());
                if (!isNaN(val))
                    root.ramUsedGb = val;

            }
        }

    }

    // ── CPU display ────────────────────────────────────────────
    Rectangle {
        height: Math.min(root.barHeight, Theme.barItemHeight)
        implicitWidth: cpuRow.implicitWidth + 20
        radius: Theme.radiusSmall
        color: cpuHover.hovered && !root.cpuMenuOpen ? Theme.hoverBg : "transparent"
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: cpuRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                text: "󰍛"
                font.family: Theme.fontIcons
                font.pixelSize: 13 + Theme.fontSizeDelta
                font.weight: Font.DemiBold
                color: root.cpuPct >= Theme.cpuCritThreshold ? Theme.red : root.cpuPct >= Theme.cpuWarnThreshold ? Theme.yellow : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.cpuPct + "%"
                font.family: Theme.fontUi
                font.pixelSize: 13 + Theme.fontSizeDelta
                font.weight: Font.DemiBold
                color: root.cpuPct >= Theme.cpuCritThreshold ? Theme.red : root.cpuPct >= Theme.cpuWarnThreshold ? Theme.yellow : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        HoverHandler {
            id: cpuHover

            blocking: false
            cursorShape: Qt.ArrowCursor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cpuClicked()
        }

        Behavior on color {
            enabled: !root.cpuMenuOpen

            ColorAnimation {
                duration: Theme.hoverAnimDuration
            }

        }

    }

    // ── RAM display ────────────────────────────────────────────
    Rectangle {
        height: Math.min(root.barHeight, Theme.barItemHeight)
        implicitWidth: ramRow.implicitWidth + 20
        radius: Theme.radiusSmall
        color: ramHover.hovered && !root.ramMenuOpen ? Theme.hoverBg : "transparent"
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: ramRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                text: "󰒋"
                font.family: Theme.fontIcons
                font.pixelSize: 13 + Theme.fontSizeDelta
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.ramUsedGb.toFixed(1) + "G"
                font.family: Theme.fontUi
                font.pixelSize: 13 + Theme.fontSizeDelta
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        HoverHandler {
            id: ramHover

            blocking: false
            cursorShape: Qt.ArrowCursor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.ramClicked()
        }

        Behavior on color {
            enabled: !root.ramMenuOpen

            ColorAnimation {
                duration: Theme.hoverAnimDuration
            }

        }

    }

}
