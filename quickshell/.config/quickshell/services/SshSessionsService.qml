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

    function splitEndpoint(endpoint) {
        const text = String(endpoint || "").trim();
        if (text.length === 0 || text === "*:*")
            return {
                address: "",
                port: ""
            };

        if (text.startsWith("[")) {
            const close = text.lastIndexOf("]:");
            if (close > 0)
                return {
                    address: text.slice(1, close),
                    port: text.slice(close + 2)
                };
        }

        const index = text.lastIndexOf(":");
        if (index <= 0)
            return {
                address: text,
                port: ""
            };

        return {
            address: text.slice(0, index),
            port: text.slice(index + 1)
        };
    }

    function parseSshProcessMap(output) {
        const byTty = ({});
        const lines = String(output || "").split(/\r?\n/);

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            const match = line.match(/^(\S+)\s+(\d+)\s+\d+\s+\S+\s+sshd-session:\s+([^@\s]+)@([A-Za-z0-9._/-]+)/);
            if (!match)
                continue;

            byTty[match[4]] = {
                pid: match[2],
                user: match[3],
                tty: match[4]
            };
        }

        return byTty;
    }

    function parseSshSocketMap(output) {
        const byPid = ({});
        const lines = String(output || "").split(/\r?\n/);

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/);
            if (fields.length < 7 || fields[0] === "USER")
                continue;
            if (fields[1].indexOf("sshd") !== 0)
                continue;

            const local = root.splitEndpoint(fields[5]);
            const remote = root.splitEndpoint(fields[6]);
            if (remote.address.length === 0)
                continue;

            byPid[fields[2]] = {
                localAddress: local.address,
                localPort: local.port,
                remoteAddress: remote.address,
                remotePort: remote.port
            };
        }

        return byPid;
    }

    function sessionKey(session) {
        return `${session.user}::${session.tty}::${session.remoteAddress}`;
    }

    function parseWhoOutput(output, processMap, socketMap) {
        const found = [];
        const seen = ({});
        const lines = String(output || "").split(/\r?\n/);

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0)
                continue;

            const remoteMatch = line.match(/\(([^)]+)\)\s*$/);
            if (!remoteMatch)
                continue;

            const fields = line.split(/\s+/);
            if (fields.length < 2)
                continue;

            const tty = fields[1];
            const process = processMap[tty] || {};
            const socket = socketMap[process.pid] || {};
            const remoteHost = root.normalizeRemoteAddress(remoteMatch[1]);
            const remoteAddress = socket.remoteAddress || remoteHost;

            const session = {
                user: fields[0],
                tty: tty,
                remoteHost: remoteHost,
                remoteAddress: remoteAddress,
                remotePort: socket.remotePort || "",
                localAddress: socket.localAddress || "",
                localPort: socket.localPort || "",
                pid: process.pid || ""
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

    function parseSessionSnapshot(output) {
        const parts = String(output || "").split(/^__QS_SSH_SECTION__ (who|ps|sockstat)$/m);
        let whoOutput = "";
        let psOutput = "";
        let sockstatOutput = "";

        for (let i = 1; i < parts.length; i += 2) {
            const name = parts[i];
            const text = parts[i + 1] || "";
            if (name === "who")
                whoOutput = text;
            else if (name === "ps")
                psOutput = text;
            else if (name === "sockstat")
                sockstatOutput = text;
        }

        return root.parseWhoOutput(whoOutput, root.parseSshProcessMap(psOutput), root.parseSshSocketMap(sockstatOutput));
    }

    function isValidTty(tty) {
        return /^[A-Za-z0-9._/-]+$/.test(String(tty || ""));
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

        command: ["sh", "-c", "printf '__QS_SSH_SECTION__ who\\n'; who; printf '__QS_SSH_SECTION__ ps\\n'; ps -axo user,pid,ppid,tty,command; printf '__QS_SSH_SECTION__ sockstat\\n'; sockstat -46 -P tcp -p 22"]

        stdout: StdioCollector {
            id: listOut

            waitForEnd: true
            onStreamFinished: root.sessions = root.parseSessionSnapshot(listOut.text)
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
