import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Rectangle {
    id: langBtn

    property int barHeight: 34

    height: barHeight - 8
    implicitWidth: Math.max(langLabel.implicitWidth + 16, 36)
    radius: Theme.radiusSmall
    readonly property bool hovered: hover.hovered
    color: hovered ? Theme.hoverBg : "transparent"
    property string _lang: "ES"

    Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

    Text {
        id: langLabel
        anchors.centerIn: parent
        text: langBtn._lang
        color: Theme.textDim
        font.family: Theme.fontUi
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 0.5
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!langProc.running) langProc.running = true
    }

    Process {
        id: langProc
        command: ["bash", "-c",
            "e=$(ibus engine 2>/dev/null); " +
            "if echo \"$e\" | grep -qiE 'anthy|jp|ja|mozc'; then echo JP; else echo ES; fi"]
        stdout: StdioCollector {
            id: langOut
            onStreamFinished: {
                var s = langOut.text.trim()
                if (s === "JP" || s === "ES") langBtn._lang = s
            }
        }
    }

    Process { id: toggleProc; command: [Quickshell.env("HOME") + "/.config/hypr/scripts/ibus-toggle.sh"] }

    HoverHandler {
        id: hover
        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toggleProc.running = true
    }
}
