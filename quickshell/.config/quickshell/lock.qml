pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "lockscreen"

ShellRoot {
    id: root

    property string passwordText: ""
    property bool passwordVisible: false
    property bool revealed: false

    Component.onCompleted: {
        // A running locker must not reload when the bar/theme is edited.
        Quickshell.watchFiles = false;
        sessionLock.locked = true;
    }

    PamContext {
        id: pamBackend

        config: "login"
        configDirectory: "/etc/pam.d"
        // Leave user unset: Quickshell resolves the current uid itself.
    }
    AuthController {
        id: auth

        pam: pamBackend
        secure: sessionLock.secure

        onAuthenticated: {
            sessionLock.locked = false;
            // Distinguish authenticated exit from crashes/termination for
            // the supervisor. No timer or IPC method can reach this path.
            Qt.callLater(() => Qt.exit(42));
        }
    }
    IpcHandler {
        function isSecure(): bool {
            return sessionLock.secure;
        }

        target: "lock"
    }
    Timer {
        interval: 8000
        running: !sessionLock.secure

        onTriggered: Qt.exit(1)
    }
    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: "#161a24"

            LockScene {
                id: scene

                anchors.fill: parent
                busy: auth.busy || !sessionLock.secure
                message: auth.message
                passwordText: root.passwordText
                passwordVisible: root.passwordVisible
                prompt: auth.prompt
                revealed: root.revealed

                onPasswordEdited: text => root.passwordText = text
                onPasswordVisibilityRequested: visible => root.passwordVisible = visible
                onResetRequested: {
                    auth.cancel();
                    root.passwordText = "";
                    root.passwordVisible = false;
                    root.revealed = false;
                }
                onRevealRequested: root.revealed = true
                onSubmitRequested: secret => auth.submit(secret)

                Connections {
                    function onClearInputs() {
                        root.passwordText = "";
                        root.passwordVisible = false;
                    }

                    target: auth
                }
            }
        }
    }
}
