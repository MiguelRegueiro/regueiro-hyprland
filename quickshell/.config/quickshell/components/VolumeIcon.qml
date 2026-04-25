import QtQuick

Canvas {
    id: root

    property bool muted: false
    property int volumePercent: 50
    property color iconColor: "white"

    implicitHeight: 16
    implicitWidth: Math.ceil(height * 1.5)

    renderTarget: Canvas.FramebufferObject

    readonly property int waveCount: {
        if (muted || volumePercent <= 0) return 0
        if (volumePercent < 34) return 1
        if (volumePercent < 67) return 2
        return 3
    }

    Component.onCompleted: requestPaint()
    onMutedChanged: requestPaint()
    onWaveCountChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        var h  = height
        var cy = h / 2

        // Speaker body — slim, short so the cone flares dramatically
        var bW = h * 0.22   // slightly wider body
        var bH = h * 0.36   // slightly taller body
        var cW = h * 0.38   // cone width
        var bR = h * 0.09   // left-corner rounding radius

        // Cone tip nearly reaches the icon edges → steep junction angle (~38°)
        var tipTop = h * 0.04
        var tipBot = h * 0.96

        // Arc waves — centred at the cone tip
        var ax    = bW + cW
        var r1    = h * 0.26
        var r2    = h * 0.42
        var r3    = h * 0.58
        var sweep = Math.PI * 58 / 180   // ±58°
        var waveStrokeWidth = Math.max(1, h * 0.09)

        // Center the speaker+waves footprint inside the canvas so the icon
        // reads optically centered in circular button backgrounds.
        var contentRight = ax + r3 + waveStrokeWidth / 2
        var xOffset = (width - contentRight) / 2

        var r = Math.round(iconColor.r * 255)
        var g = Math.round(iconColor.g * 255)
        var b = Math.round(iconColor.b * 255)
        var a = iconColor.a

        // Full-opacity colour string
        var cs = "rgba(" + r + "," + g + "," + b + "," + a + ")"
        // Dimmed speaker colour (when muted)
        var speakerCs = muted
            ? "rgba(" + r + "," + g + "," + b + "," + (a * 0.30) + ")"
            : cs
        // Dim colour for inactive wave arcs
        var dimCs = "rgba(" + r + "," + g + "," + b + "," + (a * 0.22) + ")"

        ctx.lineWidth = waveStrokeWidth
        ctx.lineCap   = "round"

        // Body + cone — dimmed when muted
        ctx.fillStyle = speakerCs
        ctx.beginPath()
        ctx.moveTo(xOffset, cy - bH / 2 + bR)
        ctx.arcTo(xOffset, cy - bH / 2,  xOffset + bR, cy - bH / 2, bR)
        ctx.lineTo(xOffset + bW, cy - bH / 2)
        ctx.lineTo(xOffset + ax, tipTop)
        ctx.lineTo(xOffset + ax, tipBot)
        ctx.lineTo(xOffset + bW, cy + bH / 2)
        ctx.lineTo(xOffset + bR, cy + bH / 2)
        ctx.arcTo(xOffset, cy + bH / 2, xOffset, cy + bH / 2 - bR, bR)
        ctx.lineTo(xOffset, cy - bH / 2 + bR)
        ctx.closePath()
        ctx.fill()

        // Sound waves — all 3 always drawn; inactive arcs are dim
        var waves = waveCount

        ctx.strokeStyle = waves >= 1 ? cs : dimCs
        ctx.beginPath(); ctx.arc(xOffset + ax, cy, r1, -sweep, sweep); ctx.stroke()

        ctx.strokeStyle = waves >= 2 ? cs : dimCs
        ctx.beginPath(); ctx.arc(xOffset + ax, cy, r2, -sweep, sweep); ctx.stroke()

        ctx.strokeStyle = waves >= 3 ? cs : dimCs
        ctx.beginPath(); ctx.arc(xOffset + ax, cy, r3, -sweep, sweep); ctx.stroke()

        // Muted: white diagonal slash across the whole icon
        if (muted) {
            var margin = h * 0.06
            ctx.strokeStyle = cs
            ctx.lineWidth   = Math.max(1.2, h * 0.11)
            ctx.lineCap     = "round"
            ctx.beginPath()
            ctx.moveTo(xOffset + margin, h - margin)
            ctx.lineTo(xOffset + contentRight - margin, margin)
            ctx.stroke()
        }
    }
}
