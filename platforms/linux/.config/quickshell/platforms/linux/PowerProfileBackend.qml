import QtQuick
import Quickshell.Services.UPower

Item {
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property string mode: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Balanced:
            return "balanced";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "";
        }
    }

    function setMode(nextMode) {
        if (nextMode === "power-saver")
            PowerProfiles.profile = PowerProfile.PowerSaver;
        else if (nextMode === "balanced")
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (nextMode === "performance" && hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance;
    }
}
