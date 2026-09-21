import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme

FocusScope {
    id: root

    property bool busy: false
    property var status: null
    property string message: ""
    property string passwordText: ""
    property bool passwordVisible: false
    property string prompt: "Password"
    property real revealProgress: revealed ? 1 : 0
    property bool revealed: false
    readonly property real uiScale: Math.min(1, width / 800, height / 650)
    property string wallpaperPath: Quickshell.env("HOME") + "/regueiro-hyprland/wallpapers/wallpaper5.png"

    signal passwordEdited(string text)
    signal passwordVisibilityRequested(bool visible)
    signal resetRequested
    signal revealRequested
    signal submitRequested(string secret)

    function clearInput() {
        passwordEdited("");
        passwordVisibilityRequested(false);
    }
    function goBack() {
        if (revealed) {
            clearInput();
            resetRequested();
        }
    }
    function submit() {
        if (busy || !revealed || password.text.length === 0)
            return;
        submitRequested(passwordText);
        clearInput();
    }

    LockIndicators {
        anchors.fill: parent
        z: 10
        status: root.status
    }

    clip: true
    focus: true

    // One motion curve coordinates the password field's entrance.
    Behavior on revealProgress {
        NumberAnimation {
            duration: root.revealed ? 200 : 140
            easing.type: Easing.OutQuint
        }
    }

    Component.onCompleted: password.forceActiveFocus()
    Keys.onEscapePressed: goBack()
    onRevealedChanged: {
        if (!revealed)
            clearInput();
        password.forceActiveFocus();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
    FileView {
        id: wallpaperState

        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/regueiro-hyprland/wallpaper"
        watchChanges: true
        onLoaded: {
            const path = wallpaperState.text().trim();
            if (path.length > 0)
                root.wallpaperPath = path;
        }
    }
    Image {
        id: wallpaper

        anchors.fill: parent
        anchors.margins: -96
        fillMode: Image.PreserveAspectCrop
        source: "file://" + root.wallpaperPath
        visible: false
    }
    MultiEffect {
        anchors.fill: wallpaper
        autoPaddingEnabled: false
        blur: 1
        blurEnabled: true
        blurMax: 64
        blurMultiplier: 1.0
        saturation: -0.12
        source: wallpaper
    }
    Rectangle {
        anchors.fill: parent
        color: "#10131b"
        opacity: 0.48
    }
    MouseArea {
        anchors.fill: parent
        enabled: !root.revealed

        onClicked: root.revealRequested()
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.revealRequested();
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        y: parent.height * 0.41 - height / 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            antialiasing: true
            color: Theme.textPrimary
            // Native rasterization avoids small gaps in large curved glyphs
            // that can occur with the GPU curve renderer on some drivers.
            renderType: Text.NativeRendering
            text: Qt.formatDateTime(clock.date, "HH:mm")

            font {
                family: Theme.fontUi
                letterSpacing: -5 * root.uiScale
                pixelSize: Math.round(128 * root.uiScale)
                weight: Font.Bold
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.textPrimary
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")

            font {
                family: Theme.fontUi
                pixelSize: Math.round(25 * root.uiScale)
                weight: Font.Medium
            }
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: Math.min(1, root.revealProgress * 1.4)
        scale: root.uiScale * (0.985 + 0.015 * root.revealProgress)
        spacing: 16
        width: Math.min(320, parent.width - 48)
        y: parent.height * 0.59 - height / 2 + 16 * (1 - root.revealProgress)

        TextField {
            id: password

            color: Theme.textPrimary
            echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
            focus: true
            height: 48
            horizontalAlignment: TextInput.AlignLeft
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            leftPadding: 14
            maximumLength: 1024
            passwordCharacter: "●"
            passwordMaskDelay: 0
            placeholderText: root.prompt
            placeholderTextColor: Theme.textDim
            readOnly: root.busy
            rightPadding: 84
            selectByMouse: true
            text: root.passwordText
            width: parent.width

            background: Rectangle {
                // Translucent charcoal field with a neutral focus outline.
                color: password.activeFocus ? "#66202226" : "#4d1b1d21"
                radius: 12

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                border {
                    color: password.activeFocus ? "#70bfc4ce" : "#26bfc4ce"
                    width: 2
                }
            }

            Keys.onEscapePressed: root.goBack()
            onAccepted: {
                if (root.revealed && text.length > 0)
                    root.submit();
                else
                    root.revealRequested();
            }
            onPreeditTextChanged: {
                if (preeditText.length > 0 && !root.revealed)
                    root.revealRequested();
            }
            // Focused even while transparent: the first character goes directly
            // into the real editor, including composed/input-method text.
            onTextEdited: {
                root.passwordEdited(text);
                if (!root.revealed)
                    root.revealRequested();
            }

            Button {
                id: revealButton

                Accessible.name: root.passwordVisible ? "Hide password" : "Show password"
                anchors.right: submitButton.left
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                display: AbstractButton.IconOnly
                enabled: root.revealed && !root.busy && password.text.length > 0
                height: 32
                icon.color: enabled ? Theme.textPrimary : Theme.textDisabled
                icon.height: 16
                icon.name: root.passwordVisible ? "view-conceal-symbolic" : "view-reveal-symbolic"
                icon.width: 16
                width: 32

                background: Rectangle {
                    border.color: revealButton.activeFocus ? "#99ffffff" : "transparent"
                    border.width: 1
                    color: revealButton.hovered ? "#14ffffff" : "transparent"
                    radius: 8
                }

                Keys.onEscapePressed: root.goBack()
                onClicked: {
                    root.passwordVisibilityRequested(!root.passwordVisible);
                    password.forceActiveFocus();
                }
            }
            Button {
                id: submitButton

                Accessible.name: "Unlock"
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.revealed && !root.busy && password.text.length > 0
                height: 32
                width: 32

                background: Rectangle {
                    border.color: submitButton.activeFocus ? "#99ffffff" : "transparent"
                    border.width: 1
                    color: submitButton.down ? "#26ffffff" : submitButton.hovered && submitButton.enabled ? "#14ffffff" : "transparent"
                    radius: 8

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                }
                contentItem: Text {
                    color: submitButton.enabled ? "white" : Theme.textDisabled
                    font.family: Theme.fontUi
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: "→"
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onEscapePressed: root.goBack()
                onClicked: root.submit()
            }
            font {
                family: Theme.fontUi
                letterSpacing: password.text.length > 0 && !root.passwordVisible ? 2 : 0
                pixelSize: password.text.length > 0 && !root.passwordVisible ? 18 : 17
                weight: password.text.length > 0 && !root.passwordVisible ? Font.Bold : Font.Normal
            }
        }
        Text {
            color: Theme.textDim
            horizontalAlignment: Text.AlignHCenter
            text: root.message
            textFormat: Text.PlainText
            visible: text.length > 0
            width: parent.width
            wrapMode: Text.WordWrap

            font {
                family: Theme.fontUi
                pixelSize: 14
            }
        }
    }
}
