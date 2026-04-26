import QtQuick
import Quickshell
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
    property string _lang: "es"

    Behavior on color { ColorAnimation { duration: Theme.hoverAnimDuration } }

    Text {
        id: langLabel
        anchors.centerIn: parent
        text: langBtn._lang
        color: Theme.textPrimary
        font.family: Theme.fontUi
        font.pixelSize: 15
        font.weight: Font.Bold
        font.letterSpacing: 0.5
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!langProc.running) langProc.running = true
    }

    Process {
        id: langProc
        command: ["bash", "-c",
            "if ! fcitx5-remote --check >/dev/null 2>&1; then echo es; " +
            "else e=$(fcitx5-remote -n 2>/dev/null); " +
            "if [ \"$e\" = 'mozc' ]; then echo あ; else echo es; fi; fi"]
        stdout: StdioCollector {
            id: langOut
            onStreamFinished: {
                var s = langOut.text.trim()
                if (s === "あ" || s === "es") langBtn._lang = s
            }
        }
    }

    Process { id: toggleProc; command: [Quickshell.env("HOME") + "/.config/hypr/scripts/fcitx-toggle.sh"] }

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
