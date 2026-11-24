import QtQuick
import "../theme/Theme.js" as Theme

ColorAnimation {
    duration: Theme.animDurNormal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curveStandard
}
