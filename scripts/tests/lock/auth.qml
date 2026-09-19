import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "."

ShellRoot {
    id: suite
    property int successes: 0
    property int checks: 0
    property var controller
    property var backend

    Component {
        id: backendFactory
        QtObject {
            property bool responseRequired: false
            property bool messageIsError: false
            property string message: "Password:"
            property bool startResult: true
            property int starts: 0
            property int responses: 0
            property string response: ""
            signal pamMessage()
            signal completed(int result)
            function start() { starts++; return startResult; }
            function abort() { responseRequired = false; }
            function respond(value) { response = value; responses++; responseRequired = false; }
        }
    }
    Component {
        id: controllerFactory
        AuthController { onAuthenticated: suite.successes++ }
    }
    function check(condition, description) {
        if (!condition)
            throw new Error(description);
        checks++;
    }
    function fresh() {
        if (controller) { controller.cancel(); controller.destroy(); backend.destroy(); }
        successes = 0;
        backend = backendFactory.createObject(suite);
        controller = controllerFactory.createObject(suite, {pam: backend, secure: true});
    }
    function prompt() { backend.responseRequired = true; backend.pamMessage(); }
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        try {
            fresh();
            controller.secure = false;
            controller.submit("test-only");
            check(backend.starts === 0, "must not authenticate before secure");
            controller.secure = true;
            controller.submit("");
            check(backend.starts === 0, "empty input must not start PAM");

            fresh();
            controller.submit("test-only");
            controller.submit("duplicate");
            check(backend.starts === 1, "duplicate submit must not start another attempt");
            prompt();
            check(backend.response === "test-only", "first input must reach PAM intact");
            check(controller.pendingResponse === "" && !controller.hasPendingResponse, "pending secret must clear");
            backend.completed(PamResult.Success);
            check(successes === 1, "successful active PAM attempt unlocks once");
            backend.completed(PamResult.Success);
            check(successes === 1, "duplicate completion ignored");

            for (const result of [PamResult.Failed, PamResult.Error, PamResult.MaxTries]) {
                fresh();
                controller.submit("test-only");
                prompt();
                backend.completed(result);
                check(successes === 0 && controller.busy, "failure/error/maxtries must stay locked with cooldown");
                controller.cancel();
                controller.submit("retry");
                check(backend.starts === 1, "Escape must not bypass cooldown");
            }

            fresh();
            controller.submit("test-only");
            controller.cancel();
            backend.completed(PamResult.Success);
            check(successes === 0 && controller.pendingResponse === "", "cancelled completion must not unlock");

            fresh();
            backend.startResult = false;
            controller.submit("test-only");
            check(!controller.inFlight && controller.pendingResponse === "" && successes === 0, "start error must clear secret and stay locked");

            fresh();
            controller.submit("test-only");
            controller.secure = false;
            backend.completed(PamResult.Success);
            check(successes === 0, "lost secure state must invalidate authentication");

            fresh();
            controller.submit("first-factor");
            prompt();
            prompt();
            check(backend.responses === 1 && !controller.busy, "second prompt must not reuse the password");
            controller.submit("second-factor");
            check(backend.responses === 2 && backend.response === "second-factor", "second factor must be handled in same conversation");
            backend.completed(PamResult.Success);
            check(successes === 1, "multi-prompt success");
            console.log("PASS: " + checks + " authentication assertions");
            Qt.callLater(() => Qt.quit());
        } catch (error) {
            console.error(error);
            Qt.callLater(() => Qt.exit(1));
        }
    }
}
