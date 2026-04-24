import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../../services" as Services
import "../../theme/Theme.js" as Theme

// Expandable WiFi submenu (toggle + network list + password prompt)
FocusScope {
    id: root

    Layout.fillWidth: true
    implicitHeight: 460

    // Public — read by parent tiles
    property bool wifiOn: false
    property string connectedSsid: ""
    property bool needsFocus: false

    signal backClicked()

    // Polling frequency control
    property bool menuOpen: false
    onMenuOpenChanged: {
        if (menuOpen) {
            pollProc.running = true
            wifiService.refreshSavedProfiles()
        }
    }

    // Internal
    property var _networks: []
    property string _connectSsid: ""
    property string _connectSecurity: ""
    property bool _connectSecure: false
    property bool _showPassword: false
    property bool _connecting: false
    property bool _awaitingActivation: false
    property string _connectMode: ""
    property int _activationChecks: 0
    property string _connectError: ""
    property string _forgetConfirmSsid: ""
    property string _forgetBusySsid: ""
    property string _forgetResultSsid: ""
    property bool _forgetResultOk: false
    readonly property bool _showStatus: root._connecting || root._connectError !== ""

    function promptOpen() {
        return root._connectSsid !== "" && root._connectSecure
    }

    function openPasswordPrompt(ssid, security) {
        root._stopActivationCheck()
        root._clearForgetState()
        root._connectSsid = ssid
        root._connectSecurity = security || ""
        root._connectSecure = true
        root._showPassword = false
        root._connecting = false
        root._connectMode = "password"
        root._connectError = ""
        passField.text = ""
        focusTimer.restart()
    }

    function _statusText() {
        if (root._connecting)
            return root._connectSsid !== "" ? "Connecting to " + root._connectSsid + "…" : "Connecting…"

        return root._connectError
    }

    function _beginInlineConnect(ssid, security) {
        root._stopActivationCheck()
        root._clearForgetState()
        root._connectSsid = ssid || ""
        root._connectSecurity = security || ""
        root._connectSecure = false
        root._showPassword = false
        root._connecting = true
        root._connectError = ""
    }

    function _ssidMatches(left, right) {
        return (left || "").trim().toLowerCase() === (right || "").trim().toLowerCase()
    }

    function _hasSavedProfile(ssid) {
        return wifiService.findSavedProfileName(ssid) !== ""
    }

    function _networkStatusText(network) {
        if (network.active)
            return "Connected"
        if (root._hasSavedProfile(network.ssid))
            return "Saved network"
        return ((network.security || "") !== "") ? "Secured network" : "Open network"
    }

    function _clearForgetState() {
        root._forgetConfirmSsid = ""
        root._forgetBusySsid = ""
        root._forgetResultSsid = ""
        root._forgetResultOk = false
    }

    function _confirmForget(ssid) {
        if (root._connecting || root._forgetBusySsid !== "" || ssid === "")
            return

        root._forgetResultSsid = ""
        root._forgetResultOk = false
        root._forgetConfirmSsid = ssid
    }

    function _cancelForget(ssid) {
        if (root._forgetConfirmSsid === ssid)
            root._forgetConfirmSsid = ""
    }

    function _forgetNetwork(ssid) {
        const target = (ssid || "").trim()
        if (target.length === 0 || root._forgetBusySsid !== "")
            return

        root._forgetConfirmSsid = ""
        root._forgetResultSsid = ""
        root._forgetResultOk = false
        root._forgetBusySsid = target

        if (!wifiService.forgetNetwork(target, function(result) {
            root._forgetBusySsid = ""
            root._forgetResultSsid = target
            root._forgetResultOk = !!(result && result.success)
            pollProc.running = true
            forgetResultClearTimer.restart()
        })) {
            root._forgetBusySsid = ""
            root._forgetResultSsid = target
            root._forgetResultOk = false
            forgetResultClearTimer.restart()
        }
    }

    function _startActivationCheck(mode) {
        root._connectMode = mode || root._connectMode
        root._awaitingActivation = true
        root._activationChecks = 0
        if (!pollProc.running)
            pollProc.running = true
        activationTimer.start()
    }

    function _stopActivationCheck() {
        root._awaitingActivation = false
        root._activationChecks = 0
        activationTimer.stop()
    }

    function _forgetFailedTarget() {
        wifiService.forgetNetwork(root._connectSsid)
    }

    function _handleActivationTimeout() {
        const failedSsid = root._connectSsid
        const failedSecurity = root._connectSecurity
        const failedMode = root._connectMode

        root._stopActivationCheck()
        root._connecting = false

        if (failedMode === "saved") {
            root._forgetFailedTarget()
            root.openPasswordPrompt(failedSsid, failedSecurity)
            root._connectError = "Saved password was rejected. Enter it again."
            return
        }

        if (failedMode === "password") {
            root._forgetFailedTarget()
            passField.text = ""
            root._connectError = "Password rejected. Try again."
            passField.forceActiveFocus()
            return
        }

        root._connectError = "Connection timed out"
    }

    function _finishConnectSuccess() {
        root._stopActivationCheck()
        passField.text = ""
        root._connectSsid = ""
        root._connectSecurity = ""
        root._connectSecure = false
        root._showPassword = false
        root._connecting = false
        root._connectMode = ""
        root._connectError = ""
        root.needsFocus = false
        wifiService.refreshSavedProfiles()
        afterConnect.start()
    }

    function _connectOpenNetwork(ssid) {
        root._beginInlineConnect(ssid, "")
        root._connectMode = "open"
        if (!wifiService.connect(ssid, "", function(result) {
            if (result && result.success) {
                root._startActivationCheck("open")
                return
            }

            root._stopActivationCheck()
            root._connecting = false
            root._connectError = wifiService.describeFailure(result, false)
        })) {
            root._connecting = false
            root._connectError = "Another Wi-Fi request is still running"
        }
    }

    function _connectSavedSecureNetwork(network) {
        root._beginInlineConnect(network.ssid, network.security || "")
        root._connectMode = "saved"
        if (!wifiService.connect(network.ssid, "", function(result) {
            if (result && result.success) {
                root._startActivationCheck("saved")
                return
            }

            root._stopActivationCheck()
            root._connecting = false
            if (result && result.needsPassword) {
                root.openPasswordPrompt(network.ssid, network.security || "")
                root._connectError = "Saved password was rejected. Enter it again."
                return
            }

            root._connectError = wifiService.describeFailure(result, false)
        })) {
            root._connecting = false
            root._connectError = "Another Wi-Fi request is still running"
        }
    }

    Services.WifiConnectionService {
        id: wifiService
    }

    component StatusPill: Rectangle {
        id: pill
        required property bool active
        required property bool connecting
        required property string message
        property color fillColor: pill.connecting ? Theme.qsRowBgHover : Theme.qsRowBg
        property color strokeColor: pill.connecting ? Theme.qsEdge : Theme.qsEdgeSoft
        property color labelColor: pill.connecting ? Theme.textPrimary : Theme.red

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Math.min(root.width - 24, statusRow.implicitWidth + 24)
        Layout.preferredHeight: 28
        radius: 14
        color: fillColor
        border.width: 1
        border.color: strokeColor
        opacity: active ? 1 : 0
        clip: true

        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }

        Behavior on fillColor {
            ColorAnimation { duration: 110 }
        }

        Behavior on strokeColor {
            ColorAnimation { duration: 110 }
        }

        RowLayout {
            id: statusRow

            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 8

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: pill.connecting ? Theme.accent : Theme.red
                opacity: 0.95

                SequentialAnimation on opacity {
                    running: pill.active && pill.connecting
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 0.95
                        to: 0.35
                        duration: 650
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        from: 0.35
                        to: 0.95
                        duration: 650
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: pill.active ? pill.message : " "
                font.family: Theme.fontUi
                font.pixelSize: 11
                font.weight: Font.Medium
                color: pill.labelColor
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ── Layout ────────────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 0

        // Wi-Fi on/off header
        Rectangle {
            id: header
            Layout.fillWidth: true
            height: 52
            radius: 18
            color: Theme.qsRowBg
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)
            z: 3

            RowLayout {
                anchors { fill: parent; leftMargin: 4; rightMargin: 8 }
                spacing: 0

                // Back button
                Rectangle {
                    readonly property bool hovered: backHover.hovered
                    width: 44; height: 44; radius: 22
                    color: hovered ? Theme.hoverBgStrong : Theme.qsRowBg
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: Theme.fontIcons; font.pixelSize: 18
                        color: Theme.textPrimary
                    }
                    HoverHandler {
                        id: backHover
                        blocking: false
                        cursorShape: Qt.ArrowCursor
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.backClicked()
                    }
                }

                Item { width: 8 }

                Text {
                    text: root.wifiOn ? "󰤨" : "󰤭"
                    font.family: Theme.fontIcons
                    font.pixelSize: 18
                    color: root.wifiOn ? Theme.accent : Theme.textDim
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }
                Item { width: 6 }
                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                // Toggle pill
                Rectangle {
                    width: 48; height: 26; radius: 13
                    color: root.wifiOn ? Theme.accent : Qt.rgba(1,1,1,0.15)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Rectangle {
                        width: 20; height: 20; radius: 10; color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.wifiOn ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent; preventStealing: true; cursorShape: Qt.ArrowCursor; z: 2
                        onClicked: root.toggle()
                    }
                }
            }
        }

        Item { height: 8; z: 3 }

        StatusPill {
            active: !root.promptOpen() && root._showStatus
            connecting: root._connecting
            message: root._statusText()
        }

        Item {
            height: 8
            z: 3
        }

        // Password input (Sticky below header)
        Rectangle {
            id: passBox
            Layout.fillWidth: true
            visible: root.promptOpen()
            height: visible ? passContent.implicitHeight + 24 : 0
            radius: 18
            color: Theme.menuBg
            border.color: Theme.qsEdge
            border.width: 1
            clip: true
            z: 5 // Ensure it's on top of the list content
            
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: passContent
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 12 }
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Password Required"
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._connectSsid
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: passField.activeFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1

                    TextInput {
                        id: passField
                        anchors {
                            left: parent.left
                            right: eyeButton.left
                            leftMargin: 12
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.textPrimary
                        echoMode: root._showPassword ? TextInput.Normal : TextInput.Password
                        focus: root.promptOpen()
                        cursorVisible: activeFocus
                        selectByMouse: true
                        activeFocusOnPress: true
                        clip: true
                        onTextEdited: if (!root._connecting) root._connectError = ""
                        Keys.onReturnPressed: {
                            event.accepted = true
                            root._doConnect(text)
                        }
                        Keys.onEnterPressed: {
                            event.accepted = true
                            root._doConnect(text)
                        }
                        Keys.onEscapePressed: {
                            event.accepted = true
                            root._cancel()
                        }
                    }

                    Text {
                        anchors {
                            left: passField.left
                            verticalCenter: parent.verticalCenter
                        }
                        visible: passField.text.length === 0
                        text: "Enter Wi-Fi password"
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.42)
                    }

                    Rectangle {
                        id: eyeButton
                        width: 28
                        height: 28
                        radius: 14
                        anchors {
                            right: parent.right
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        color: eyeHover.hovered ? Theme.hoverBgStrong : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: root._showPassword ? "\uf070" : "\uf06e"
                            font.family: Theme.fontIcons
                            font.pixelSize: 14
                            color: Theme.textDim
                        }

                        HoverHandler {
                            id: eyeHover
                            blocking: false
                            cursorShape: Qt.ArrowCursor
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                root._showPassword = !root._showPassword
                                passField.forceActiveFocus()
                            }
                        }
                    }
                }

                StatusPill {
                    active: root._showStatus
                    connecting: root._connecting
                    message: root._statusText()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 17
                        color: cancelHover.hovered ? Theme.qsRowBgHover : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            color: Theme.textPrimary
                        }

                        HoverHandler {
                            id: cancelHover
                            blocking: false
                            cursorShape: Qt.ArrowCursor
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root._cancel()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 17
                        opacity: root._connecting ? 0.5 : 1.0
                        color: connectHover.hovered && !root._connecting ? Theme.tileActiveBgHover : Theme.tileActiveBg
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Text {
                            anchors.centerIn: parent
                            text: root._connecting ? "Connecting…" : "Connect"
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "white"
                        }

                        HoverHandler {
                            id: connectHover
                            blocking: false
                            cursorShape: Qt.ArrowCursor
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root._doConnect(passField.text)
                        }
                    }
                }
            }
        }

        Item { height: root.promptOpen() ? 12 : 0; z: 3 }

        // Scrollable area for network list
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: listCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            z: 1

            ScrollBar.vertical: ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                background: null
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Qt.rgba(1,1,1,0.2)
                }
            }

            ColumnLayout {
                id: listCol
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.wifiOn ? root._networks : []
                    delegate: Rectangle {
                        id: wifiRow
                        required property var modelData
                        Layout.fillWidth: true
                        height: 52
                        radius: 18
                        readonly property bool secureNetwork: (modelData.security || "") !== ""
                        readonly property bool selectedForPrompt: root.promptOpen() && root._connectSsid === modelData.ssid
                        readonly property bool rememberedProfile: root._hasSavedProfile(modelData.ssid)
                        readonly property bool savedProfile: !modelData.active && rememberedProfile
                        readonly property bool forgetPending: root._forgetConfirmSsid === modelData.ssid
                        readonly property bool forgetBusy: root._forgetBusySsid === modelData.ssid
                        readonly property bool forgetHasResult: root._forgetResultSsid === modelData.ssid
                        readonly property bool forgetOk: forgetHasResult && root._forgetResultOk
                        readonly property bool forgetActionVisible: rememberedProfile
                            && (wifiHover.hovered || forgetPending || forgetBusy || forgetHasResult)
                        color: modelData.active
                            ? Theme.hoverBgStrong
                            : (selectedForPrompt ? Qt.rgba(1, 1, 1, 0.10)
                                                 : (wifiHover.hovered ? Theme.qsRowBgHover : Theme.qsRowBg))
                        border.width: 1
                        border.color: modelData.active
                            ? Qt.rgba(1, 1, 1, 0.14)
                            : (selectedForPrompt ? Theme.accent : Qt.rgba(1, 1, 1, 0.05))

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.ArrowCursor
                            enabled: root._forgetBusySsid === ""
                                && !wifiRow.forgetPending
                                && !wifiRow.forgetBusy
                                && !wifiRow.forgetHasResult
                            onClicked: {
                                root._forgetConfirmSsid = ""
                                if (root._connecting) return
                                if (modelData.active) return
                                if ((modelData.security || "") !== "") {
                                    if (wifiService.hasSavedProfile(modelData.ssid))
                                        root._connectSavedSecureNetwork(modelData)
                                    else
                                        root.openPasswordPrompt(modelData.ssid, modelData.security)
                                } else {
                                    root._connectOpenNetwork(modelData.ssid)
                                }
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: modelData.active
                                    ? Qt.rgba(1, 1, 1, 0.12)
                                    : (wifiHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05))

                                Text {
                                    anchors.centerIn: parent
                                    text: root._sigIcon(modelData.signal || 0)
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 15
                                    color: modelData.active ? Theme.textPrimary : Theme.textDim
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.ssid || ""
                                    font.family: Theme.fontUi
                                    font.pixelSize: 12
                                    font.weight: modelData.active ? Font.DemiBold : Font.Medium
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root._networkStatusText(modelData)
                                    font.family: Theme.fontUi
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                visible: wifiRow.secureNetwork
                                text: "󰌾"
                                font.family: Theme.fontIcons
                                font.pixelSize: 12
                                color: Theme.textDim
                            }
                            Item {
                                z: 1
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: forgetActions.visible ? forgetActions.implicitWidth
                                                                    : (savedChip.visible ? savedChip.implicitWidth : 0)
                                implicitHeight: forgetActions.visible ? forgetActions.implicitHeight
                                                                      : (savedChip.visible ? savedChip.implicitHeight : 0)

                                RowLayout {
                                    id: forgetActions
                                    anchors.centerIn: parent
                                    visible: wifiRow.forgetActionVisible
                                    spacing: 6

                                    Rectangle {
                                        visible: wifiRow.forgetPending
                                        implicitWidth: 56
                                        implicitHeight: 28
                                        radius: 14
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Cancel"
                                            font.family: Theme.fontUi
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: Theme.textPrimary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            preventStealing: true
                                            cursorShape: Qt.ArrowCursor
                                            onClicked: root._cancelForget(wifiRow.modelData.ssid)
                                        }
                                    }

                                    Rectangle {
                                        id: forgetButton
                                        implicitWidth: wifiRow.forgetBusy ? 78 : (wifiRow.forgetPending ? 58 : 62)
                                        implicitHeight: 28
                                        radius: 14
                                        color: {
                                            if (wifiRow.forgetHasResult)
                                                return wifiRow.forgetOk ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 0.35, 0.35, 0.14)
                                            if (wifiRow.forgetPending)
                                                return Qt.rgba(1, 0.35, 0.35, 0.16)
                                            if (wifiRow.forgetBusy)
                                                return Qt.rgba(1, 1, 1, 0.06)
                                            return Qt.rgba(1, 1, 1, 0.08)
                                        }
                                        border.width: 1
                                        border.color: wifiRow.forgetPending
                                            ? Qt.rgba(1, 0.45, 0.45, 0.22)
                                            : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                if (wifiRow.forgetHasResult) return wifiRow.forgetOk ? "Forgot" : "Failed"
                                                if (wifiRow.forgetBusy) return "Forgetting…"
                                                return "Forget"
                                            }
                                            font.family: Theme.fontUi
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: {
                                                if (wifiRow.forgetHasResult)
                                                    return wifiRow.forgetOk ? Theme.textPrimary : Theme.red
                                                if (wifiRow.forgetBusy)
                                                    return Theme.textDisabled
                                                if (wifiRow.forgetPending)
                                                    return Theme.red
                                                return Theme.textPrimary
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            preventStealing: true
                                            cursorShape: Qt.ArrowCursor
                                            enabled: root._forgetBusySsid === "" && !wifiRow.forgetHasResult
                                            onClicked: {
                                                if (wifiRow.forgetPending)
                                                    root._forgetNetwork(wifiRow.modelData.ssid)
                                                else
                                                    root._confirmForget(wifiRow.modelData.ssid)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: savedChip
                                    anchors.centerIn: parent
                                    visible: wifiRow.savedProfile && !wifiRow.forgetActionVisible
                                    implicitWidth: savedLabel.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        id: savedLabel
                                        anchors.centerIn: parent
                                        text: "Saved"
                                        font.family: Theme.fontUi
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: Theme.accent
                                    }
                                }
                            }
                            Text {
                                visible: !!modelData.active
                                text: "󰄬"
                                font.family: Theme.fontIcons
                                font.pixelSize: 14
                                color: Theme.green
                            }
                        }

                        HoverHandler {
                            id: wifiHover
                            blocking: false
                            cursorShape: Qt.ArrowCursor
                        }
                    }
                }
            }
        }
    }

    function toggle() {
        wifiOn = !wifiOn
        wifiToggleProc.running = true
        afterToggle.start()
    }

    // ── Helpers ────────────────────────────────────────────────────
    function _sigIcon(pct) {
        if (pct < 25) return "󰤟"
        if (pct < 50) return "󰤢"
        if (pct < 75) return "󰤥"
        return "󰤨"
    }

    function _isWpaSecurity(security) {
        var sec = (security || "").toUpperCase()
        return sec.indexOf("WPA") >= 0 || sec.indexOf("PSK") >= 0 || sec.indexOf("SAE") >= 0
    }

    function _validatePassword(pwd) {
        if (pwd.length === 0) return "Enter a password"
        if (!root._isWpaSecurity(root._connectSecurity)) return ""
        if (pwd.length < 8) return "WPA password must be at least 8 characters"
        if (pwd.length > 64) return "WPA password must be 8-63 chars, or 64 hex digits"
        if (pwd.length === 64 && !/^[0-9A-Fa-f]{64}$/.test(pwd))
            return "A 64-character WPA key must use only 0-9 and A-F"
        return ""
    }

    function _doConnect(pwd) {
        if (root._connecting) return
        root._connectError = root._validatePassword(pwd)
        if (root._connectError !== "") {
            passField.forceActiveFocus()
            return
        }

        root._connecting = true
        root._connectMode = "password"
        if (!wifiService.connect(root._connectSsid, pwd, function(result) {
            if (result && result.success) {
                root._startActivationCheck("password")
                return
            }

            root._stopActivationCheck()
            root._connecting = false
            if (result && (result.needsPassword || wifiService.detectAuthenticationError(result.error || "")))
                passField.text = ""

            root._connectError = wifiService.describeFailure(result, true)
            passField.forceActiveFocus()
        })) {
            root._connecting = false
            root._connectError = "Another Wi-Fi request is still running"
        }
    }

    function _cancel() {
        root._stopActivationCheck()
        passField.text = ""
        root._connectSsid = ""
        root._connectSecurity = ""
        root._connectSecure = false
        root._showPassword = false
        root._connecting = false
        root._connectMode = ""
        root._connectError = ""
        root.needsFocus = false
    }

    // ── Timers ─────────────────────────────────────────────────────
    Timer { id: focusTimer;   interval: 80;   onTriggered: passField.forceActiveFocus() }
    Timer { id: afterToggle;  interval: 700;  onTriggered: pollProc.running = true }
    Timer { id: afterConnect; interval: 3500; onTriggered: pollProc.running = true }
    Timer {
        id: forgetResultClearTimer
        interval: 2200
        onTriggered: {
            root._forgetResultSsid = ""
            root._forgetResultOk = false
            pollProc.running = true
        }
    }
    Timer {
        id: activationTimer
        interval: 900
        repeat: true
        onTriggered: {
            if (!root._awaitingActivation) {
                stop()
                return
            }

            if (root._ssidMatches(root.connectedSsid, root._connectSsid)) {
                root._finishConnectSuccess()
                return
            }

            root._activationChecks += 1
            if (root._activationChecks >= 8) {
                root._handleActivationTimeout()
                return
            }

            if (!pollProc.running)
                pollProc.running = true
        }
    }

    // Poll every 6s; extra trigger when menu opens
    Timer {
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    // ── Processes ─────────────────────────────────────────────────
    Process {
        id: pollProc
        command: ["bash", "-c",
            "echo \"wifi:$(nmcli radio wifi 2>/dev/null)\";" +
            "echo \"ssid:$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 | head -1)\";" +
            "nmcli -t -m multiline -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list 2>/dev/null | sed 's/^/NET:/'"
        ]
        environment: ({
            LANG: "C.UTF-8",
            LC_ALL: "C.UTF-8"
        })
        stdout: StdioCollector {
            id: pollData
            onStreamFinished: {
                var lines = pollData.text.split("\n")
                var list = [], cur = null
                for (var i = 0; i < lines.length; i++) {
                    var raw = lines[i]
                    if (raw.startsWith("wifi:")) {
                        root.wifiOn = raw.slice(5).trim() === "enabled"; continue
                    }
                    if (raw.startsWith("ssid:")) {
                        root.connectedSsid = raw.slice(5).trim(); continue
                    }
                    if (!raw.startsWith("NET:")) continue
                    var line = raw.slice(4)
                    var ci = line.indexOf(":")
                    if (ci < 0) continue
                    var key = line.slice(0, ci).replace(/\[\d+\]$/, "")
                    var val = line.slice(ci + 1).replace(/\\:/g, ":")
                    if (key === "IN-USE") {
                        if (cur && cur.ssid !== undefined) list.push(cur)
                        cur = { active: val.trim() === "*" }
                    } else if (cur) {
                        if      (key === "SSID")     cur.ssid     = val
                        else if (key === "SECURITY") cur.security = val
                        else if (key === "SIGNAL")   cur.signal   = parseInt(val) || 0
                    }
                }
                if (cur && cur.ssid !== undefined) list.push(cur)
                // Deduplicate by SSID — keep active entry or highest signal
                var seen = {}
                list.forEach(n => {
                    if (!n.ssid) return
                    if (!seen[n.ssid] || n.active || n.signal > (seen[n.ssid].signal || 0))
                        seen[n.ssid] = n
                })
                root._networks = Object.values(seen).sort((a, b) => {
                    if (a.active && !b.active) return -1
                    if (!a.active && b.active) return 1
                    return (b.signal || 0) - (a.signal || 0)
                })

                if (root._awaitingActivation && root._ssidMatches(root.connectedSsid, root._connectSsid))
                    root._finishConnectSuccess()
            }
        }
    }

    Process { id: wifiToggleProc; command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wifi-toggle.sh"] }
}
