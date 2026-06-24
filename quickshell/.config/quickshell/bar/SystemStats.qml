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
    // Read /proc/stat twice to compute delta
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

        command: ["bash", "-c", "awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat"]

        stdout: StdioCollector {
            id: cpuOut

            onStreamFinished: {
                var parts = cpuOut.text.trim().split(/\s+/);
                if (parts.length < 7)
                    return ;

                var user = parseInt(parts[0]);
                var nice = parseInt(parts[1]);
                var sys = parseInt(parts[2]);
                var idle = parseInt(parts[3]);
                var iowait = parseInt(parts[4]);
                var irq = parseInt(parts[5]);
                var softirq = parseInt(parts[6]);
                var total = user + nice + sys + idle + iowait + irq + softirq;
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

        command: ["bash", "-c", "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.1f\", (t-a)/1048576}' /proc/meminfo"]

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
                text: root.ramUsedGb.toFixed(1) + "GB"
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
