import QtQuick

Canvas {
    id: root

    property bool connected: false
    property int signal: 100
    property color iconColor: "white"
    property color inactiveColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.34)

    implicitWidth: Math.ceil(height * 1.36)
    implicitHeight: 14
    renderTarget: Canvas.FramebufferObject

    onConnectedChanged: requestPaint()
    onSignalChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onInactiveColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const scale = height / 14;
        const stroke = Math.max(1.25, 1.55 * scale);
        const colour = connected ? iconColor : inactiveColor;
        const r = Math.round(colour.r * 255);
        const g = Math.round(colour.g * 255);
        const b = Math.round(colour.b * 255);
        const css = "rgba(" + r + "," + g + "," + b + "," + colour.a + ")";
        const dimCss = "rgba(" + r + "," + g + "," + b + "," + (colour.a * 0.30) + ")";
        const centreX = width / 2;
        const strength = Math.max(0, Math.min(100, signal));
        const activeArches = strength >= 75 ? 3 : (strength >= 50 ? 2 : (strength >= 25 ? 1 : 0));

        ctx.fillStyle = css;
        ctx.lineWidth = stroke;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        function wave(startX, startY, controlY, endX, endY, active) {
            ctx.strokeStyle = active ? css : dimCss;
            ctx.beginPath();
            ctx.moveTo(startX, startY);
            ctx.quadraticCurveTo(centreX, controlY, endX, endY);
            ctx.stroke();
        }

        wave(1.3 * scale, 5.5 * scale, -0.5 * scale, width - 1.3 * scale, 5.5 * scale, activeArches >= 3);
        wave(4.0 * scale, 8.0 * scale, 3.0 * scale, width - 4.0 * scale, 8.0 * scale, activeArches >= 2);
        wave(6.6 * scale, 9.6 * scale, 7.4 * scale, width - 6.6 * scale, 9.6 * scale, activeArches >= 1);

        ctx.beginPath();
        ctx.arc(centreX, 12.15 * scale, Math.max(1.05, 1.3 * scale), 0, Math.PI * 2);
        ctx.fill();
    }
}
