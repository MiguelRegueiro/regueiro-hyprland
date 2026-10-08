import QtQuick
import "../theme/Theme.js" as Theme

// Percentage-first battery badge. The charge symbol deliberately lives outside
// the battery, where it remains legible at the bar's small scale.
Item {
    id: root

    property int percent: 0
    property bool charging: false
    property bool full: false
    readonly property int clampedPercent: Math.max(0, Math.min(100, percent))
    // Less luminous than the general success green: this is a persistent
    // status mark, not an attention-grabbing confirmation.
    readonly property color fillColor: charging || full ? "#84e89b"
        : clampedPercent <= Theme.batteryLowThreshold ? Theme.red : "#e4e6eb"
    // Opaque enough to remain visible against the dark bar, especially for
    // the small terminal at high charge levels.
    readonly property color remainderColor: "#8e9098"
    readonly property real bodyWidth: 29
    // At this scale, 98% is only about half a pixel short of a full body.
    // Keep a small slice of the remainder exposed for every non-full state:
    // otherwise the fill's deliberately squarer end enters the body's rounded
    // right cap and looks like it is sitting on top of it.
    readonly property real partialFillRightInset: 1.5

    // Only reserve the bolt slot while it is visible; otherwise the status
    // cluster ends snugly at the battery terminal.
    implicitWidth: charging ? 44 : 33
    implicitHeight: 14

    Rectangle {
        id: body

        width: root.bodyWidth
        height: root.height
        radius: height * 0.32
        color: root.remainderColor
        clip: true

        Rectangle {
            width: root.clampedPercent >= 100
                ? parent.width
                : Math.min(parent.width * root.clampedPercent / 100,
                           parent.width - root.partialFillRightInset)
            height: parent.height
            // A partial charge fills from the rounded left edge with a subtle
            // softened end. Only a full charge reaches the battery's fully
            // rounded right end.
            topLeftRadius: parent.radius
            bottomLeftRadius: parent.radius
            topRightRadius: root.clampedPercent >= 100 ? parent.radius : 1.5
            bottomRightRadius: root.clampedPercent >= 100 ? parent.radius : 1.5
            color: root.fillColor

            Behavior on width {
                NumberAnimation { duration: Theme.batteryFillDuration }
            }
        }

        Text {
            // Use the battery body's fixed width as the alignment box. This
            // keeps 1-, 2-, and 3-digit values centered despite their glyphs
            // having different advances and side bearings.
            width: parent.width
            height: parent.height
            anchors.centerIn: parent
            // Numeric glyphs sit a little high inside their line box; nudge
            // them down for visual, rather than purely geometric, centering.
            anchors.verticalCenterOffset: 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.clampedPercent
            font.family: Theme.fontUi
            font.pixelSize: 10
            font.weight: Font.Bold
            color: root.clampedPercent >= 45 ? "#1d1d20" : Theme.textPrimary
        }
    }

    // Terminal cap stays separate to preserve the chunky silhouette.
    Rectangle {
        // Draw behind the body: its rounded edge cleanly masks the join,
        // making this read as a terminal rather than a second pill on top.
        z: -1
        x: body.width - 1
        anchors.verticalCenter: body.verticalCenter
        width: 4
        height: 6
        radius: 2
        color: root.remainderColor
    }

    Text {
        // UPower can briefly report a plugged-in 100% battery as
        // FullyCharged before switching to Charging. Both states deserve the
        // bolt, otherwise it visibly arrives after the green fill.
        visible: root.charging
        x: body.width + 4
        anchors.verticalCenter: parent.verticalCenter
        text: "󱐋"
        font.family: Theme.fontIcons
        font.pixelSize: 12
        color: "#c8cad1"
    }
}
