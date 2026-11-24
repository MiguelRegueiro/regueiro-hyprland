import QtQuick
import Quickshell.Io

Item {
    id: root

    property var savedProfiles: []
    property var _profilesCallback: null
    property var _connectCallback: null
    property var _forgetCallback: null
    property string _pendingSsid: ""
    property string _pendingPassword: ""
    property string _pendingDeleteProfile: ""
    property string _pendingForgetProfile: ""
    property var _cleanupResult: null
    property string _cleanupProfile: ""
    readonly property var _env: ({
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8"
    })

    function _cleanError(error) {
        return (error || "").trim().replace(/^Error:\s*/, "");
    }

    function _profileNamesFromOutput(output) {
        const lines = (output || "").trim().split("\n");
        const next = [];
        const placeholder = "__QS_COLON__";
        for (let i = 0; i < lines.length; ++i) {
            const raw = (lines[i] || "").trim();
            if (raw.length === 0)
                continue;

            const safe = raw.replace(/\\:/g, placeholder);
            const idx = safe.lastIndexOf(":");
            if (idx < 0)
                continue;

            const name = safe.slice(0, idx).replace(new RegExp(placeholder, "g"), ":").trim();
            const type = safe.slice(idx + 1).replace(new RegExp(placeholder, "g"), ":").trim();
            if ((type === "802-11-wireless" || type === "wifi") && name.length > 0)
                next.push(name);

        }
        return next;
    }

    function findSavedProfileName(ssid) {
        const needle = (ssid || "").trim().toLowerCase();
        if (needle.length === 0)
            return "";

        for (let i = 0; i < root.savedProfiles.length; ++i) {
            const name = (root.savedProfiles[i] || "").trim();
            if (name.toLowerCase() === needle)
                return name;

        }
        return "";
    }

    function hasSavedProfile(ssid) {
        return root.findSavedProfileName(ssid) !== "";
    }

    function _removeSavedProfile(profileName) {
        const needle = (profileName || "").trim().toLowerCase();
        if (needle.length === 0)
            return ;

        root.savedProfiles = root.savedProfiles.filter((name) => {
            return (name || "").trim().toLowerCase() !== needle;
        });
    }

    function detectPasswordRequired(error) {
        if (!error || error.length === 0)
            return false;

        return (error.includes("Secrets were required") || error.includes("Secrets were required, but not provided") || error.includes("No secrets provided") || error.includes("802-11-wireless-security.psk") || error.includes("password for") || (error.includes("password") && !error.includes("Connection activated") && !error.includes("successfully")) || (error.includes("Secrets") && !error.includes("Connection activated") && !error.includes("successfully")) || (error.includes("802.11") && !error.includes("Connection activated") && !error.includes("successfully"))) && !error.includes("Connection activated") && !error.includes("successfully");
    }

    function detectAuthenticationError(error) {
        const lower = (error || "").toLowerCase();
        if (lower.length === 0)
            return false;

        return root.detectPasswordRequired(error) || lower.includes("invalid secrets") || lower.includes("wrong password") || lower.includes("incorrect password") || lower.includes("authentication");
    }

    function describeFailure(result, usedPassword) {
        if (!result)
            return "Connection failed";

        const error = result.error || "";
        const clean = root._cleanError(error);
        const lower = clean.toLowerCase();
        if (result.needsPassword || (usedPassword && root.detectAuthenticationError(error)))
            return usedPassword ? "Password rejected. Try again." : "Password required";

        if (lower.includes("no network with ssid") || lower.includes("could not be found"))
            return "Network not found";

        if (lower.includes("timed out") || lower.includes("timeout"))
            return "Connection timed out";

        if (lower.includes("not allowed") || lower.includes("denied"))
            return "Connection was denied";

        return clean.length > 0 ? clean : "Connection failed";
    }

    function refreshSavedProfiles(callback) {
        if (profilesProc.running)
            return ;

        root._profilesCallback = callback || null;
        profilesProc.running = true;
    }

    function forgetNetwork(ssid, callback) {
        const profileName = root.findSavedProfileName(ssid) || (ssid || "").trim();
        if (profileName.length === 0) {
            if (callback)
                callback({
                "success": false,
                "output": "",
                "error": "No SSID specified",
                "exitCode": -1
            });

            return false;
        }
        if (forgetNetworkProc.running || connectProc.running || forgetProc.running || cleanupProc.running)
            return false;

        root._forgetCallback = callback || null;
        root._pendingForgetProfile = profileName;
        forgetNetworkProc.command = ["nmcli", "connection", "delete", profileName];
        forgetNetworkProc.running = true;
        return true;
    }

    function connect(ssid, password, callback) {
        const target = (ssid || "").trim();
        if (target.length === 0) {
            if (callback)
                callback({
                "success": false,
                "output": "",
                "error": "No SSID specified",
                "exitCode": -1,
                "needsPassword": false
            });

            return false;
        }
        if (connectProc.running || forgetProc.running || forgetNetworkProc.running || cleanupProc.running)
            return false;

        root._connectCallback = callback || null;
        root._pendingSsid = target;
        root._pendingPassword = password || "";
        const existingProfile = root._pendingPassword.length > 0 ? root.findSavedProfileName(target) : "";
        if (existingProfile.length > 0) {
            root._pendingDeleteProfile = existingProfile;
            forgetProc.command = ["nmcli", "connection", "delete", existingProfile];
            forgetProc.running = true;
        } else {
            root._startConnect();
        }
        return true;
    }

    function _startConnect() {
        const cmd = ["nmcli", "device", "wifi", "connect", root._pendingSsid];
        if (root._pendingPassword.length > 0)
            cmd.push("password", root._pendingPassword);

        connectProc.command = cmd;
        connectProc.running = true;
    }

    function _finishConnect(result) {
        const callback = root._connectCallback;
        root._connectCallback = null;
        root._pendingSsid = "";
        root._pendingPassword = "";
        root._pendingDeleteProfile = "";
        root._cleanupResult = null;
        root._cleanupProfile = "";
        if (result && result.success)
            root.refreshSavedProfiles();

        if (callback)
            callback(result);

    }

    function _cleanupFailedProfile(result) {
        const savedProfile = root.findSavedProfileName(root._pendingSsid);
        const profileName = savedProfile.length > 0 ? savedProfile : (root._pendingPassword.length > 0 ? root._pendingSsid : "");
        if (profileName.length === 0) {
            root._finishConnect(result);
            return ;
        }
        root._cleanupResult = result;
        root._cleanupProfile = profileName;
        root._removeSavedProfile(profileName);
        cleanupProc.command = ["nmcli", "connection", "delete", profileName];
        cleanupProc.running = true;
    }

    Process {
        id: profilesProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        environment: root._env
        onExited: (code) => {
            if (code === 0)
                root.savedProfiles = root._profileNamesFromOutput(profilesStdout.text);
            else
                root.savedProfiles = [];
            const callback = root._profilesCallback;
            root._profilesCallback = null;
            if (callback)
                callback(root.savedProfiles);

        }

        stdout: StdioCollector {
            id: profilesStdout
        }

    }

    Process {
        id: forgetProc

        command: ["echo"]
        environment: root._env
        onExited: (code) => {
            const deletedProfile = root._pendingDeleteProfile;
            root._pendingDeleteProfile = "";
            if (deletedProfile.length > 0)
                root._removeSavedProfile(deletedProfile);

            root._startConnect();
        }
    }

    Process {
        id: cleanupProc

        command: ["echo"]
        environment: root._env
        onExited: (code) => {
            const result = root._cleanupResult;
            root._finishConnect(result);
        }
    }

    Process {
        id: forgetNetworkProc

        command: ["echo"]
        environment: root._env
        onExited: (code) => {
            const deletedProfile = root._pendingForgetProfile;
            root._pendingForgetProfile = "";
            const callback = root._forgetCallback;
            root._forgetCallback = null;
            if (code === 0 && deletedProfile.length > 0) {
                root._removeSavedProfile(deletedProfile);
                root.refreshSavedProfiles();
            }
            if (callback)
                callback({
                "success": code === 0,
                "output": (forgetNetworkStdout.text || "").trim(),
                "error": (forgetNetworkStderr.text || "").trim(),
                "exitCode": code
            });

        }

        stdout: StdioCollector {
            id: forgetNetworkStdout
        }

        stderr: StdioCollector {
            id: forgetNetworkStderr
        }

    }

    Process {
        id: connectProc

        command: ["echo"]
        environment: root._env
        onExited: (code) => {
            const error = (connectStderr.text || "").trim();
            const result = {
                "success": code === 0,
                "output": (connectStdout.text || "").trim(),
                "error": error,
                "exitCode": code,
                "needsPassword": root.detectPasswordRequired(error)
            };
            if (!result.success && (result.needsPassword || root.detectAuthenticationError(error))) {
                root._cleanupFailedProfile(result);
                return ;
            }
            root._finishConnect(result);
        }

        stdout: StdioCollector {
            id: connectStdout
        }

        stderr: StdioCollector {
            id: connectStderr
        }

    }

}
