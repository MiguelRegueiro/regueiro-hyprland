import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property var sessions: []
    property string lastError: ""
    property string pendingTty: ""
    property string terminatingTty: ""
    property string targetUser: ""
    property string targetTty: ""
    readonly property string currentUser: Quickshell.env("USER")
    readonly property bool loading: listProc.running
    readonly property bool mutating: termProc.running || killProc.running || terminatingTty.length > 0

    function normalizeRemoteAddress(address) {
        let candidate = String(address || "").trim();
        if (candidate.startsWith("[") && candidate.endsWith("]"))
            candidate = candidate.slice(1, -1);

        const zoneIndex = candidate.indexOf("%");
        if (zoneIndex > 0)
            candidate = candidate.slice(0, zoneIndex);

        return candidate;
    }

    function isRemoteLogin(remoteHost) {
        const host = root.normalizeRemoteAddress(remoteHost);
        if (host.length === 0)
            return false;

        const lowered = host.toLowerCase();
        return lowered !== "local" && lowered !== "localhost" && lowered !== "localhost.localdomain" && lowered !== ":0" && lowered !== ":1";
    }

    function sessionKey(session) {
        return `${session.user}::${session.tty}::${session.remoteAddress}`;
    }

    function parseWhoOutput(output) {
        const found = [];
        const seen = ({});
        const lines = String(output || "").split(new RegExp("\\r?\\n"));

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0)
                continue;

            const remoteMatch = line.match(new RegExp("\\(([^)]+)\\)\\s*$"));
            if (!remoteMatch)
                continue;

            const remoteHost = root.normalizeRemoteAddress(remoteMatch[1]);
            if (!root.isRemoteLogin(remoteHost))
                continue;

            const fields = line.split(new RegExp("\\s+"));
            if (fields.length < 2)
                continue;

            const session = {
                user: fields[0],
                tty: fields[1],
                remoteHost: remoteHost,
                remoteAddress: remoteHost,
                remotePort: "",
                localAddress: "",
                localPort: "",
                pid: ""
            };
            const key = root.sessionKey(session);
            if (seen[key])
                continue;

            seen[key] = true;
            found.push(session);
        }

        found.sort((a, b) => {
            const byAddress = a.remoteAddress.localeCompare(b.remoteAddress);
            if (byAddress !== 0)
                return byAddress;
            const byUser = a.user.localeCompare(b.user);
            if (byUser !== 0)
                return byUser;
            return a.tty.localeCompare(b.tty);
        });

        root.lastError = "";
        return found;
    }

    function isValidTty(tty) {
        return new RegExp("^[A-Za-z0-9._/-]+$").test(String(tty || ""));
    }

    function canTerminate(session) {
        return session && session.user === root.currentUser && root.isValidTty(session.tty);
    }

    function sessionStillPresent(user, tty) {
        for (let i = 0; i < root.sessions.length; i++) {
            const session = root.sessions[i];
            if (session.user === user && session.tty === tty)
                return true;
        }

        return false;
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function requestTerminate(session) {
        if (!root.canTerminate(session) || root.mutating)
            return;

        root.pendingTty = session.tty;
    }

    function cancelTerminate() {
        root.pendingTty = "";
    }

    function confirmTerminate(session) {
        if (!root.canTerminate(session) || root.mutating)
            return;

        root.lastError = "";
        root.pendingTty = "";
        root.terminatingTty = session.tty;
        root.targetUser = session.user;
        root.targetTty = session.tty;
        termProc.command = ["pkill", "-TERM", "-t", session.tty];
        termProc.running = true;
    }

    Timer {
        interval: Theme.sshSessionsPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon

        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: forceKillCheck

        interval: 800
        repeat: false
        onTriggered: {
            root.refresh();
            verifyAfterTerm.restart();
        }
    }

    Timer {
        id: verifyAfterTerm

        interval: 250
        repeat: false
        onTriggered: {
            if (root.sessionStillPresent(root.targetUser, root.targetTty)) {
                killProc.command = ["pkill", "-KILL", "-t", root.targetTty];
                killProc.running = true;
            } else {
                root.terminatingTty = "";
                root.targetUser = "";
                root.targetTty = "";
            }
        }
    }

    Process {
        id: listProc

        command: ["who"]

        stdout: StdioCollector {
            id: listOut

            waitForEnd: true
            onStreamFinished: root.sessions = root.parseWhoOutput(listOut.text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Failed to list SSH sessions";
        }
    }

    Process {
        id: termProc

        command: ["pkill", "-TERM", "-t", ""]
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.lastError = "Failed to end SSH session";
                root.terminatingTty = "";
                root.targetUser = "";
                root.targetTty = "";
                refreshSoon.restart();
                return;
            }

            forceKillCheck.restart();
        }
    }

    Process {
        id: killProc

        command: ["pkill", "-KILL", "-t", ""]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Failed to force-end SSH session";

            root.terminatingTty = "";
            root.targetUser = "";
            root.targetTty = "";
            refreshSoon.restart();
        }
    }
}
