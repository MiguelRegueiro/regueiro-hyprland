import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "."

ShellRoot {
    id: root
    property int unlocks: 0
    readonly property bool expectSuccess: Quickshell.env("LOCK_TEST_PAM_CONFIG") === "permit"

    PamContext {
        id: backend
        config: Quickshell.env("LOCK_TEST_PAM_CONFIG")
        configDirectory: Quickshell.shellDir + "/pam"
        onCompleted: result => Qt.callLater(() => {
            const correct = root.expectSuccess ? result === PamResult.Success && root.unlocks === 1 : result !== PamResult.Success && root.unlocks === 0;
            console.log(correct ? "PASS: real PAM " + backend.config : "FAIL: real PAM " + backend.config);
            Qt.exit(correct ? 0 : 1);
        })
    }
    AuthController {
        id: auth
        pam: backend
        secure: true
        onAuthenticated: root.unlocks++
    }
    Timer {
        interval: 50
        running: true
        onTriggered: auth.submit("synthetic-test-input")
    }
    Component.onCompleted: Quickshell.watchFiles = false
}
