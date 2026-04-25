import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Row {
    id: root

    property int barHeight: 34

    spacing: 0

    property int cpuPct: 0
    property real ramUsedGb: 0.0

    // ── CPU polling ────────────────────────────────────────────
    // Read /proc/stat twice to compute delta
    property var _prevIdle: 0
    property var _prevTotal: 0

    Timer {
        interval: 2000
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
                var parts = cpuOut.text.trim().split(/\s+/)
                if (parts.length < 7) return
                var user = parseInt(parts[0])
                var nice = parseInt(parts[1])
                var sys  = parseInt(parts[2])
                var idle = parseInt(parts[3])
                var iowait = parseInt(parts[4])
                var irq  = parseInt(parts[5])
                var softirq = parseInt(parts[6])
                var total = user + nice + sys + idle + iowait + irq + softirq
                var dTotal = total - root._prevTotal
                var dIdle  = idle - root._prevIdle
                if (dTotal > 0)
                    root.cpuPct = Math.round(100 * (dTotal - dIdle) / dTotal)
                root._prevTotal = total
                root._prevIdle  = idle
            }
        }
    }

    // ── RAM polling ────────────────────────────────────────────
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ramProc.running = true
    }

    Process {
        id: ramProc
        command: ["bash", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.1f\", (t-a)/1048576}' /proc/meminfo"]
        stdout: StdioCollector {
            id: ramOut
            onStreamFinished: {
                var val = parseFloat(ramOut.text.trim())
                if (!isNaN(val)) root.ramUsedGb = val
            }
        }
    }

    // ── CPU display ────────────────────────────────────────────
    Rectangle {
        height: root.barHeight - 8
        implicitWidth: cpuRow.implicitWidth + 20
        radius: Theme.radiusSmall
        color: cpuHover.hovered ? Theme.hoverBg : "transparent"
        anchors.verticalCenter: parent.verticalCenter
        Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

        Row {
            id: cpuRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                text: "󰍛"
                font.family: Theme.fontIcons
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.cpuPct >= 90 ? Theme.red
                     : root.cpuPct >= 70 ? Theme.yellow
                     : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.cpuPct + "%"
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.cpuPct >= 90 ? Theme.red
                     : root.cpuPct >= 70 ? Theme.yellow
                     : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler {
            id: cpuHover
            blocking: false
            cursorShape: Qt.ArrowCursor
        }
    }

    // ── RAM display ────────────────────────────────────────────
    Rectangle {
        height: root.barHeight - 8
        implicitWidth: ramRow.implicitWidth + 20
        radius: Theme.radiusSmall
        color: ramHover.hovered ? Theme.hoverBg : "transparent"
        anchors.verticalCenter: parent.verticalCenter
        Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

        Row {
            id: ramRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                text: "󰒋"
                font.family: Theme.fontIcons
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.ramUsedGb.toFixed(1) + "G"
                font.family: Theme.fontUi
                font.pixelSize: 13
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
    }
}
