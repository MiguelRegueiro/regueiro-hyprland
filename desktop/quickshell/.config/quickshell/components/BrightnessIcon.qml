import QtQuick

Canvas {
    id: root

    property color iconColor: "white"

    implicitHeight: 16
    implicitWidth: height
    renderTarget: Canvas.FramebufferObject
    Component.onCompleted: requestPaint()
    onIconColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        var r = Math.round(iconColor.r * 255);
        var g = Math.round(iconColor.g * 255);
        var b = Math.round(iconColor.b * 255);
        var a = iconColor.a;
        var cs = "rgba(" + r + "," + g + "," + b + "," + a + ")";
        var cx = width / 2;
        var cy = height / 2;
        var size = Math.min(width, height);
        var circleR = size * 0.24;
        var rayInner = size * 0.38;
        var rayOuter = size * 0.5;
        var rayWidth = size * 0.07;
        ctx.fillStyle = cs;
        ctx.strokeStyle = cs;
        ctx.lineCap = "round";
        ctx.lineWidth = rayWidth;
        // Center circle
        ctx.beginPath();
        ctx.arc(cx, cy, circleR, 0, Math.PI * 2);
        ctx.fill();
        // 8 rays
        for (var i = 0; i < 8; i++) {
            var angle = (i / 8) * Math.PI * 2 - Math.PI / 2;
            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(angle) * rayInner, cy + Math.sin(angle) * rayInner);
            ctx.lineTo(cx + Math.cos(angle) * rayOuter, cy + Math.sin(angle) * rayOuter);
            ctx.stroke();
        }
    }
}
