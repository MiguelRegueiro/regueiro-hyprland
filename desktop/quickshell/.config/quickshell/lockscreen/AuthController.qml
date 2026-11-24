import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Coordinates the PAM conversation, cancellation, and retry cooldown.
Scope {
    id: root

    readonly property bool busy: cooldown.running || (inFlight && (!pam.responseRequired || hasPendingResponse))
    property bool hasPendingResponse: false
    property bool inFlight: false
    property string message: ""
    required property var pam
    property string pendingResponse: ""
    readonly property string prompt: inFlight && pam.responseRequired && !hasPendingResponse ? pam.message.replace(/[:：]\s*$/, "") : "Password"
    property bool secure: false

    signal authenticated
    signal clearInputs

    function cancel() {
        // Invalidate before abort: late completion must never unlock.
        inFlight = false;
        pendingResponse = "";
        hasPendingResponse = false;
        deadline.stop();
        pam.abort();
        message = "";
        clearInputs();
    }
    function submit(secret) {
        if (!secure || busy || secret.length === 0)
            return;
        message = "Checking…";
        clearInputs();
        if (inFlight && pam.responseRequired) {
            pam.respond(secret);
            return;
        }
        pendingResponse = secret;
        hasPendingResponse = true;
        inFlight = true;
        deadline.restart();
        if (!pam.start()) {
            cancel();
            message = "Unable to check password. Please try again.";
        }
    }

    onSecureChanged: {
        if (!secure)
            cancel();
    }

    Timer {
        id: cooldown

        interval: 1500
    }
    Timer {
        id: deadline

        interval: 60000

        onTriggered: {
            root.cancel();
            root.message = "Authentication timed out. Please try again.";
        }
    }
    Connections {
        function onCompleted(result) {
            if (!root.inFlight)
                return;
            root.inFlight = false;
            root.pendingResponse = "";
            root.hasPendingResponse = false;
            deadline.stop();
            root.clearInputs();
            if (result === PamResult.Success && root.secure) {
                root.authenticated();
            } else {
                root.message = result === PamResult.Error ? "Unable to check password. Please try again." : "Password not accepted. Please try again.";
                cooldown.restart();
            }
        }
        function onPamMessage() {
            if (!root.inFlight)
                return;
            if (root.pam.responseRequired && root.hasPendingResponse) {
                const response = root.pendingResponse;
                root.pendingResponse = "";
                root.hasPendingResponse = false;
                root.pam.respond(response);
            } else if (root.pam.responseRequired) {
                root.message = "";
            } else if (root.pam.messageIsError) {
                root.message = "Authentication failed. Please try again.";
            }
        }

        target: root.pam
    }
}
