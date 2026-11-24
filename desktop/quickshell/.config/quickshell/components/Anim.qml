import QtQuick
import "../theme/Theme.js" as Theme

NumberAnimation {
    enum Curve {
        Standard,
        StandardAccel,
        StandardDecel,
        Emphasized,
        EmphasizedAccel,
        EmphasizedDecel,
        DefaultSpatial,
        FastSpatial,
        SlowSpatial,
        DefaultEffects,
        FastEffects,
        SlowEffects
    }

    property int curve: Anim.Standard

    duration: {
        switch (curve) {
        case Anim.FastSpatial:    return Theme.animDurFastSpatial;
        case Anim.DefaultSpatial: return Theme.animDurDefaultSpatial;
        case Anim.SlowSpatial:    return Theme.animDurSlowSpatial;
        case Anim.FastEffects:    return Theme.animDurFastEffects;
        case Anim.DefaultEffects: return Theme.animDurDefaultEffects;
        case Anim.SlowEffects:    return Theme.animDurSlowEffects;
        case Anim.StandardAccel:
        case Anim.EmphasizedAccel: return Theme.animDurSmall;
        default:                   return Theme.animDurNormal;
        }
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (curve) {
        case Anim.StandardAccel:   return Theme.curveStandardAccel;
        case Anim.StandardDecel:   return Theme.curveStandardDecel;
        case Anim.Emphasized:      return Theme.curveEmphasized;
        case Anim.EmphasizedAccel: return Theme.curveEmphasizedAccel;
        case Anim.EmphasizedDecel: return Theme.curveEmphasizedDecel;
        case Anim.DefaultSpatial:  return Theme.curveDefaultSpatial;
        case Anim.FastSpatial:     return Theme.curveFastSpatial;
        case Anim.SlowSpatial:     return Theme.curveSlowSpatial;
        case Anim.DefaultEffects:  return Theme.curveDefaultEffects;
        case Anim.FastEffects:     return Theme.curveFastEffects;
        case Anim.SlowEffects:     return Theme.curveSlowEffects;
        default:                   return Theme.curveStandard;
        }
    }
}
