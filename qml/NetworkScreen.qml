import QtQuick
import QtQuick.Shapes

// Settings > Network, like the 360's. Available Networks shows every network
// as a big white blade (signal bars, a lock if it has a password, a corner
// with a tick on the one you're on). Picking one joins it, asking for the
// password on the on-screen keyboard, then Network Settings tests the
// connection from this PC to the internet and Steam, step by step.
FocusScope {
    id: networkScreen
    visible: false

    property Item returnFocusTo: null

    // "blades" (Available Networks), "settings" (one network) or "advanced"
    property string view: "blades"

    // The network on the Network Settings page
    property var chosen: ({ kind: "wifi", ssid: "" })
    property bool chosenHidden: false           // joined with Specify Unlisted Network

    // How the connection test went: "unknown", "testing", "ok", "fail" or
    // "portal" (the network wants you to sign in on a web page first)
    property var results: ({ network: "unknown", internet: "unknown", steam: "unknown" })
    property int testStep: 0                    // 0 = not testing, 1 network, 2 internet, 3 Steam
    property var details: ({})                  // IP address and the rest, from the test

    property string steamAddress: "https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/"

    readonly property var chosenNetwork: chosen.kind === "wifi"
                                         ? Network.networks.find(n => n.ssid === chosen.ssid) || null : null
    readonly property bool chosenConnecting: chosen.kind === "wired" ? Network.wired.state === "connecting"
                                                                     : Network.connecting === chosen.ssid
    readonly property bool chosenConnected: chosen.kind === "wired" ? Network.wired.state === "connected"
                                                                    : chosenNetwork !== null && chosenNetwork.active
    readonly property string chosenName: chosen.kind === "wired" ? "Wired Network" : chosen.ssid

    // The rows on Network Settings; their words change with the connection
    readonly property var settingsRows: chosen.kind === "wired" ? ["test", "stats", "toggle"]
                                                                : ["test", "stats", "toggle", "forget"]

    function open() {
        returnFocusTo = Window.activeFocusItem
        keyboard.visible = false
        card.visible = false
        Network.refresh()                       // what NetworkManager knows now,
        Network.scan()                          // then a fresh look around
        syncBlades()
        showBlades()
        blades.currentIndex = Math.max(0, findBlade(b => b.active))     // start on the one you're on
        visible = true
        openAnimation.restart()
    }

    function close() {
        visible = false
        testStep = 0
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function back() {
        if (view === "blades")
            close()
        else
            showBlades()
    }

    function showBlades() {
        view = "blades"
        testStep = 0
        blades.forceActiveFocus()
    }

    function showSettings(kind, ssid) {
        chosen = { kind: kind, ssid: ssid }
        results = { network: "unknown", internet: "unknown", steam: "unknown" }
        details = {}
        testStep = 0
        view = "settings"
        settingsList.currentIndex = 0
        settingsList.forceActiveFocus()
        panelAnimation.restart()
        if (chosenConnected)
            startTest()
    }

    function showAdvanced() {
        view = "advanced"
        advancedList.currentIndex = 0
        advancedList.forceActiveFocus()
        panelAnimation.restart()
    }

    // A card over everything, like the Turn Off one
    function showMessage(title, text, options) {
        card.title = title
        card.message = text
        card.options = options || [{ label: "OK", run: () => {} }]
        card.defaultIndex = 0
        card.open()
    }

    // ---- The blades --------------------------------------------------------

    // Wired first, then the Wi-Fi networks, then Advanced Options. A
    // ListModel kept up to date in place, so the blade you're on stays put
    // while the list refreshes underneath it
    ListModel { id: bladeModel }

    function bladeList() {
        const list = []
        if (Network.wired.device)
            list.push(blade("wired", "Wired Network", { active: Network.wired.state === "connected",
                                                        bladeState: Network.wired.state }))
        if (Network.hasWifi && !Network.wifiEnabled)
            list.push(blade("wifioff", "Turn On Wi-Fi", {}))
        for (const network of Network.networks)
            list.push(blade("wifi", network.ssid, network))
        if (Network.hasWifi)
            list.push(blade("advanced", "Advanced Options", {}))
        return list
    }

    function blade(kind, label, info) {
        return { key: kind + ":" + label, kind: kind, label: label, ssid: info.ssid || "",
                 strength: info.signal || 0, secured: !!info.secured, enterprise: !!info.enterprise,
                 active: !!info.active, known: !!info.known, bladeState: info.bladeState || "" }
    }

    function findBlade(test) {
        for (let i = 0; i < bladeModel.count; i++)
            if (test(bladeModel.get(i)))
                return i
        return -1
    }

    function syncBlades() {
        const wanted = bladeList()
        for (let i = bladeModel.count - 1; i >= 0; i--)
            if (!wanted.some(b => b.key === bladeModel.get(i).key))
                bladeModel.remove(i)
        wanted.forEach((b, i) => {
            let at = -1
            for (let j = i; j < bladeModel.count; j++)
                if (bladeModel.get(j).key === b.key) { at = j; break }
            if (at < 0) {
                bladeModel.insert(i, b)
            } else {
                if (at !== i)
                    bladeModel.move(at, i, 1)
                bladeModel.set(i, b)
            }
        })
    }

    function select(b) {
        if (b.kind === "advanced") {
            showAdvanced()
        } else if (b.kind === "wifioff") {
            Network.setWifiEnabled(true)
        } else if (b.kind === "wired") {
            if (b.bladeState === "unplugged") {
                showMessage("Wired Network", "There's no network cable plugged in. Plug one into this PC "
                            + "to use a wired connection.")
                return
            }
            if (b.bladeState === "disconnected")
                Network.connectWired()
            showSettings("wired", "")
        } else if (b.active) {
            showSettings("wifi", b.ssid)
        } else {
            connectTo(b.ssid, b.secured, b.known, b.enterprise, false)
        }
    }

    function connectTo(ssid, secured, known, enterprise, hidden) {
        if (enterprise) {
            showMessage(ssid, ssid + " needs a username as well as a password (like a school or work "
                        + "network). Connect to it from the desktop for now.")
        } else if (secured && !known) {
            askPassword(ssid, hidden)
        } else {
            join(ssid, "", hidden)
        }
    }

    function askPassword(ssid, hidden) {
        keyboard.open({ title: "Password", password: true, maxLength: 63,
                        prompt: hidden ? "Enter the password for " + ssid + ". Leave it empty if it doesn't have one."
                                       : "Enter the password for " + ssid + ".",
                        done: text => join(ssid, text, hidden) })
    }

    function join(ssid, password, hidden) {
        chosenHidden = hidden
        Network.connectTo(ssid, password, hidden)
        showSettings("wifi", ssid)
    }

    // ---- The connection test ------------------------------------------------

    function startTest() {
        results = { network: "testing", internet: "unknown", steam: "unknown" }
        testStep = 1
        Network.test(chosen.kind)
    }

    property var tested: ({})
    function nextTestStep() {
        const now = Object.assign({}, results)
        if (testStep === 1) {
            now.network = tested.connected ? "ok" : "fail"
            if (!tested.connected) {
                results = now
                testStep = 0
                return
            }
            now.internet = "testing"
            results = now
            testStep = 2
            stepTimer.restart()
        } else if (testStep === 2) {
            const state = tested.internet
            now.internet = state === "full" ? "ok" : state === "portal" ? "portal"
                         : state === "unknown" ? "unknown" : "fail"
            now.steam = "testing"
            results = now
            testStep = 3
            checkSteam()
        }
    }

    function checkSteam() {
        const request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE)
                steamChecked(request.status === 200)
        }
        request.open("GET", steamAddress)
        request.send()
        steamTimeout.restart()
    }

    function steamChecked(ok) {
        if (testStep !== 3)
            return
        steamTimeout.stop()
        const now = Object.assign({}, results)
        now.steam = ok ? "ok" : "fail"
        if (now.internet === "unknown" && ok)
            now.internet = "ok"                 // NetworkManager couldn't check, but Steam answered
        results = now
        testStep = 0
    }

    // Each step shows for a moment, like the 360's dots running along
    Timer { id: stepTimer; interval: 800; onTriggered: networkScreen.nextTestStep() }
    Timer { id: steamTimeout; interval: 10000; onTriggered: networkScreen.steamChecked(false) }

    function resultWords(result, what) {
        if (what === "network" && networkScreen.chosenConnecting)
            return "Connecting..."
        if (result === "ok")
            return "Connected"
        if (result === "testing")
            return "Testing..."
        if (result === "portal")
            return "Sign-in Needed"
        if (result === "fail")
            return what === "network" ? "Not Connected" : what === "steam" ? "Can't Reach Steam" : "No Internet"
        return "Unknown"
    }

    function signalWords(signal) {
        return signal >= 75 ? "Excellent" : signal >= 50 ? "Good" : signal >= 25 ? "Fair" : "Weak"
    }

    // ---- Network Settings' rows ----------------------------------------------

    function rowLabel(id) {
        if (id === "test")
            return "Test Connection"
        if (id === "stats")
            return "Network Statistics"
        if (id === "toggle")
            return chosenConnected ? "Disconnect" : "Connect"
        return "Forget This Network"
    }

    function rowEnabled(id) {
        if (id === "test")
            return chosenConnected && testStep === 0
        if (id === "toggle")
            return !chosenConnecting
        if (id === "forget")
            return chosenNetwork !== null && chosenNetwork.known && !chosenConnecting
        return false
    }

    function activateRow(id) {
        if (!rowEnabled(id))
            return
        if (id === "test") {
            startTest()
        } else if (id === "toggle") {
            if (chosenConnected) {
                Network.disconnectFrom(chosen.kind)
                showBlades()
            } else if (chosen.kind === "wired") {
                Network.connectWired()
            } else {
                const n = chosenNetwork || {}
                connectTo(chosen.ssid, n.secured !== false, !!n.known, !!n.enterprise, chosenHidden)
            }
        } else if (id === "forget") {
            const ssid = chosen.ssid
            showMessage("Forget " + ssid + "?",
                        "ReDash360 will forget the password for " + ssid + " and stop joining it by itself.",
                        [{ label: "Forget Network", run: () => { Network.forget(ssid); showBlades() } },
                         { label: "Cancel", run: () => {} }])
        }
    }

    // ---- NetworkManager's answers ------------------------------------------

    Connections {
        target: Network
        function onChanged() { networkScreen.syncBlades() }

        function onConnectFinished(ok, ssid, error) {
            if (ok || !networkScreen.visible)
                return
            const wrongPassword = error.indexOf("password") >= 0
            const hidden = networkScreen.chosenHidden
            networkScreen.showMessage("Couldn't Connect", error, wrongPassword
                ? [{ label: "Try Again", run: () => networkScreen.askPassword(ssid, hidden) },
                   { label: "Cancel", run: () => networkScreen.showBlades() }]
                : [{ label: "OK", run: () => networkScreen.showBlades() }])
        }

        function onTested(result) {
            if (networkScreen.testStep !== 1)
                return
            networkScreen.tested = result
            networkScreen.details = result
            stepTimer.restart()
        }

        function onFailed(error) {
            if (networkScreen.visible)
                networkScreen.showMessage("Something Went Wrong", error)
        }
    }

    // Test as soon as a network you picked has joined
    onChosenConnectedChanged: {
        if (view === "settings" && chosenConnected && testStep === 0)
            startTest()
    }

    // NetworkManager doesn't tell us when things change, so ask now and then
    Timer {
        interval: 4000
        repeat: true
        running: networkScreen.visible && !Network.scanning
        onTriggered: Network.refresh()
    }

    // ---- What's on screen ----------------------------------------------------

    Keys.onEscapePressed: back()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        text: networkScreen.view === "blades" ? "Available Networks"
            : networkScreen.view === "settings" ? "Network Settings" : "Advanced Wireless Options"
        color: "white"
        font.pixelSize: 50
    }

    // ---- Available Networks ----
    Item {
        id: bladesView
        anchors.fill: parent
        visible: networkScreen.view === "blades"

        Text {
            x: 145; y: 162
            visible: Network.scanning
            text: "Looking for networks..."
            color: "white"
            opacity: 0.8
            font.pixelSize: 30
        }

        ListView {
            id: blades
            y: 280
            width: parent.width; height: 480
            orientation: ListView.Horizontal
            spacing: 15
            interactive: false
            keyNavigationEnabled: true
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 231          // the blade you're on starts at x 216, like the 360's
            preferredHighlightEnd: 231 + 450
            highlightMoveDuration: 250
            model: bladeModel

            delegate: Blade {}

            Keys.onReturnPressed: if (currentIndex >= 0) networkScreen.select(bladeModel.get(currentIndex))
            Keys.onEnterPressed: if (currentIndex >= 0) networkScreen.select(bladeModel.get(currentIndex))
            Keys.onPressed: (event) => {
                const current = currentIndex >= 0 ? bladeModel.get(currentIndex) : null
                if (event.key === Qt.Key_X) {
                    Network.scan()
                    event.accepted = true
                } else if (event.key === Qt.Key_Y && current && current.active) {
                    Network.disconnectFrom(current.kind === "wired" ? "wired" : "wifi")
                    event.accepted = true
                }
            }
        }

        // When there's nothing to show (or no way to ask)
        Text {
            x: 216; y: 790
            width: 1450
            visible: text !== ""
            text: !Network.available || Network.problem !== ""
                  ? Network.problem + " Change networks from the desktop for now."
                  : Network.hasWifi && Network.wifiEnabled && Network.networks.length === 0 && !Network.scanning
                  ? "No Wi-Fi networks found. Press X to look again."
                  : !Network.hasWifi && !Network.wired.device ? "This PC doesn't have Wi-Fi or a network socket." : ""
            color: "white"
            font.pixelSize: 34
            wrapMode: Text.WordWrap
        }

        NumberAnimation { id: openAnimation; target: blades; property: "opacity"; from: 0; to: 1; duration: 250 }

        Row {
            x: 138; y: 973
            spacing: 30
            ButtonHint { button: "A"; label: "Select"; visible: blades.count > 0 }
            ButtonHint { button: "B"; label: "Back" }
            ButtonHint { button: "X"; label: "Scan Again"; visible: Network.hasWifi && Network.wifiEnabled }
            ButtonHint {
                button: "Y"
                label: "Disconnect"
                visible: blades.currentIndex >= 0 && blades.currentItem !== null && blades.currentItem.active
            }
        }
    }

    // ---- Network Settings ----
    Item {
        id: settingsView
        anchors.fill: parent
        visible: networkScreen.view === "settings"

        Item {
            id: settingsPanel
            x: 300; y: 171
            width: 1320; height: 719

            // Left: what you can do, and a note under it
            Rectangle {
                width: 660; height: 526
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#F4FBFA" }
                    GradientStop { position: 1.0; color: "#D5DFE0" }
                }

                ListView {
                    id: settingsList
                    width: parent.width; height: count * 70
                    interactive: false
                    keyNavigationEnabled: true
                    highlightMoveDuration: 0
                    model: networkScreen.settingsRows
                    delegate: MenuRow {
                        label: networkScreen.rowLabel(modelData)
                        usable: networkScreen.rowEnabled(modelData) || modelData === "stats"
                        onChosen: networkScreen.activateRow(modelData)
                    }
                    Keys.onReturnPressed: networkScreen.activateRow(networkScreen.settingsRows[currentIndex])
                    Keys.onEnterPressed: networkScreen.activateRow(networkScreen.settingsRows[currentIndex])
                }

                Rectangle {
                    x: 20; y: parent.height - height - 22
                    width: parent.width - 40; height: 125
                    color: "#E9EDEE"
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 22; anchors.rightMargin: 22
                        verticalAlignment: Text.AlignVCenter
                        text: networkScreen.chosenConnecting ? "Connecting to " + networkScreen.chosenName + "..."
                                                             : "Trouble connecting? Restart your router, then test again."
                        color: "#333333"
                        font.pixelSize: 30
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Right: how the connection is, or the numbers, or what the row does
            Rectangle {
                x: 660
                width: 660; height: 526
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#C3C9CD" }
                    GradientStop { position: 1.0; color: "#B9BFC3" }
                }

                readonly property string row: networkScreen.settingsRows[settingsList.currentIndex] || "test"

                Text {
                    x: 16
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: 52
                    text: parent.row === "stats" ? "Network Statistics"
                        : parent.row === "test" ? "Your Network Status" : networkScreen.rowLabel(parent.row)
                    color: "#5E656B"
                    font.pixelSize: 36
                }

                // Your Network Status
                Column {
                    x: 20; y: 88
                    visible: parent.row === "test"
                    spacing: 12
                    Repeater {
                        model: [{ what: "network", label: "Network:" }, { what: "internet", label: "Internet:" },
                                { what: "steam", label: "Steam:" }]
                        Item {
                            id: line
                            required property var modelData
                            readonly property string result: networkScreen.results[modelData.what]
                            width: 620; height: 40
                            StatusIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                result: line.modelData.what === "network" && networkScreen.chosenConnecting
                                        ? "testing" : line.result
                            }
                            Text {
                                x: 48
                                anchors.verticalCenter: parent.verticalCenter
                                text: line.modelData.label
                                color: "#4A5055"
                                font.pixelSize: 32
                            }
                            Text {
                                x: 352
                                anchors.verticalCenter: parent.verticalCenter
                                text: networkScreen.resultWords(line.result, line.modelData.what)
                                color: "#4A5055"
                                font.pixelSize: 32
                            }
                        }
                    }
                }

                // Network Statistics
                Column {
                    x: 20; y: 92
                    visible: parent.row === "stats"
                    spacing: 6
                    Repeater {
                        model: {
                            const d = networkScreen.details
                            const n = networkScreen.chosenNetwork
                            const rows = [["Network", networkScreen.chosenName]]
                            if (n)
                                rows.push(["Signal", n.signal + "% (" + networkScreen.signalWords(n.signal) + ")"],
                                          ["Security", n.security || "None"], ["Speed", n.rate])
                            else if (d.speed)
                                rows.push(["Speed", d.speed])
                            if (!networkScreen.chosenConnected)
                                return rows.concat([["Status", "Not connected"]])
                            return rows.concat([["IP Address", d.ip], ["Gateway", d.gateway], ["DNS", d.dns],
                                                ["MAC Address", d.mac]].filter(r => r[1]))
                        }
                        Item {
                            required property var modelData
                            width: 620; height: 42
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[0]
                                color: "#4A5055"
                                font.pixelSize: 30
                            }
                            Text {
                                x: 230
                                width: parent.width - x
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[1] || ""
                                color: "#4A5055"
                                font.pixelSize: 30
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // What Disconnect / Connect / Forget do
                Text {
                    x: 20; y: 96
                    width: parent.width - 40
                    visible: parent.row === "toggle" || parent.row === "forget"
                    text: parent.row === "forget"
                          ? "Forget the password for " + networkScreen.chosenName + ". ReDash360 won't join it "
                            + "by itself any more, and you'll need the password to connect again."
                          : networkScreen.chosenConnected
                          ? "Disconnect from " + networkScreen.chosenName + ". Choose it in Available Networks "
                            + "to connect again."
                          : "Connect to " + networkScreen.chosenName + "."
                    color: "#4A5055"
                    font.pixelSize: 32
                    lineHeight: 1.1
                    wrapMode: Text.WordWrap
                }
            }

            // Bottom: this PC ... the network ... the internet ... Steam
            Rectangle {
                y: 526
                width: parent.width; height: 193
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#9BA1A3" }
                    GradientStop { position: 1.0; color: "#747D7E" }
                }

                Chain { anchors.fill: parent }
            }

            // Like the 360's lists: the panel grows out of the middle
            ParallelAnimation {
                id: panelAnimation
                NumberAnimation { target: settingsPanel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
                NumberAnimation { target: settingsPanel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
            }
        }

        Row {
            x: 138; y: 973
            spacing: 30
            ButtonHint {
                button: "A"
                label: "Select"
                visible: networkScreen.rowEnabled(networkScreen.settingsRows[settingsList.currentIndex] || "")
            }
            ButtonHint { button: "B"; label: "Back" }
        }
    }

    // ---- Advanced Wireless Options ----
    Item {
        anchors.fill: parent
        visible: networkScreen.view === "advanced"

        Rectangle {
            id: advancedPanel
            x: 300; y: 171
            width: 1320; height: 719
            scale: settingsPanel.scale
            opacity: settingsPanel.opacity
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            ListView {
                id: advancedList
                width: parent.width; height: count * 70
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: ["unlisted", "radio"]
                delegate: MenuRow {
                    label: modelData === "unlisted" ? "Specify Unlisted Network"
                         : Network.wifiEnabled ? "Turn Off Wi-Fi" : "Turn On Wi-Fi"
                    onChosen: networkScreen.activateAdvanced(modelData)
                }
                Keys.onReturnPressed: networkScreen.activateAdvanced(model[currentIndex])
                Keys.onEnterPressed: networkScreen.activateAdvanced(model[currentIndex])
            }
        }

        Row {
            x: 138; y: 973
            spacing: 30
            ButtonHint { button: "A"; label: "Select" }
            ButtonHint { button: "B"; label: "Back" }
        }
    }

    function activateAdvanced(id) {
        if (id === "radio") {
            Network.setWifiEnabled(!Network.wifiEnabled)
        } else {
            keyboard.open({ title: "Unlisted Network", prompt: "Enter the name of the network.", maxLength: 32,
                            done: name => { if (name.trim() !== "") askPassword(name.trim(), true) } })
        }
    }

    MessageCard {
        id: card
        anchors.fill: parent
        icon: "!"
    }

    Keyboard {
        id: keyboard
        anchors.fill: parent
    }

    // ---- Pieces ----------------------------------------------------------------

    // One network on Available Networks: a white square, bigger when you're on it
    component Blade: Item {
        id: item
        required property int index
        required property string kind
        required property string label
        required property int strength
        required property bool secured
        required property bool active
        required property string bladeState

        width: ListView.isCurrentItem ? 450 : 375
        height: ListView.view.height
        Behavior on width { NumberAnimation { duration: 150 } }

        Rectangle {
            id: face
            x: (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 375; height: 375
            scale: item.ListView.isCurrentItem ? 1.28 : 1
            Behavior on scale { NumberAnimation { duration: 150 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4F4F4" }
                GradientStop { position: 1.0; color: "#ECECEC" }
            }

            // Signal bars, the darker the more of them you get
            Repeater {
                model: item.kind === "wifi" ? 4 : 0
                Rectangle {
                    required property int index
                    readonly property int level: item.strength >= 75 ? 4 : item.strength >= 50 ? 3
                                               : item.strength >= 25 ? 2 : item.strength > 0 ? 1 : 0
                    x: 104 + index * 44.5
                    y: 238 - height
                    width: 33; height: 55 + index * 28
                    color: index < level ? "#6F808C" : "#D8DCDE"
                }
            }

            TileIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: 167
                width: item.kind === "advanced" ? 125 : 150; height: width
                visible: item.kind !== "wifi"
                name: item.kind === "advanced" ? "gear" : item.kind === "wired" ? "ethernet" : "wifi"
                color: item.kind === "wifioff" || item.bladeState === "unplugged" ? "#C9CED1" : "#6A7881"
            }

            Text {
                x: 23
                width: (item.secured ? 300 : 352) - x
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: 345
                text: item.label
                color: "#5A6064"
                font.pixelSize: 30
                elide: Text.ElideRight
            }

            TileIcon {
                x: 318; y: 326
                width: 36; height: 36
                visible: item.secured
                name: "lock"
                color: "#5A6064"
            }

            // The corner with the tick, on the network you're on
            Shape {
                anchors.right: parent.right
                width: 93; height: 93
                visible: item.active
                ShapePath {
                    fillColor: "#008E00"
                    strokeColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: 93; y: 0 }
                    PathLine { x: 93; y: 93 }
                    PathLine { x: 0; y: 0 }
                }
                Rectangle {
                    x: 51; y: 12
                    width: 30; height: 30
                    radius: 15
                    color: "white"
                    TileIcon {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        name: "check"
                        color: "#222222"
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: face
            hoverEnabled: true
            onEntered: if (Pointer.active) blades.currentIndex = item.index
            onClicked: {
                blades.currentIndex = item.index
                networkScreen.select(bladeModel.get(item.index))
            }
        }
    }

    // A row in the lists: green when you're on it, a grey line under the others
    component MenuRow: Rectangle {
        id: row
        required property int index
        required property var modelData
        property string label
        property bool usable: true              // grey when it can't be used right now
        signal chosen()
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        Text {
            x: 45
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: row.selected ? "white" : row.usable ? "#222222" : "#9AA3A6"
            opacity: row.selected && !row.usable ? 0.7 : 1
            font.pixelSize: 36
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !row.selected && row.ListView.view.currentIndex !== row.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) row.ListView.view.currentIndex = row.index
            onClicked: {
                row.ListView.view.currentIndex = row.index
                row.chosen()
            }
        }
    }

    // A round icon for each line of Your Network Status
    component StatusIcon: Rectangle {
        id: icon
        property string result
        width: 36; height: 36
        radius: 18
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: icon.result === "fail" ? "#F0603E" : icon.result === "portal" ? "#FFC54A"
                     : icon.result === "testing" ? "#B5BCC0" : "#B4EC4C"
            }
            GradientStop {
                position: 1.0
                color: icon.result === "fail" ? "#B3200B" : icon.result === "portal" ? "#D98A00"
                     : icon.result === "testing" ? "#7D868B" : "#2E9A10"
            }
        }
        TileIcon {
            anchors.centerIn: parent
            width: icon.width * 0.66; height: width
            visible: icon.result === "ok" || icon.result === "fail"
            name: icon.result === "ok" ? "check" : "cross"
        }
        Text {
            anchors.centerIn: parent
            visible: icon.result !== "ok" && icon.result !== "fail"
            text: icon.result === "testing" ? "..." : icon.result === "portal" ? "!" : "?"
            color: "white"
            font.pixelSize: 24
            font.bold: true
        }
    }

    // The strip under Network Settings: four stops with dots between them.
    // The dots run while that step is being tested, then stay lit if it worked
    component Chain: Item {
        id: chain
        readonly property var centres: [130, 466, 812, 1185]
        readonly property var steps: ["network", "internet", "steam"]
        property int tick: 0

        Timer {
            interval: 140
            repeat: true
            running: networkScreen.testStep > 0 || networkScreen.chosenConnecting
            onTriggered: chain.tick = (chain.tick + 1) % 6
        }

        Repeater {
            model: 3
            Item {
                id: gap
                required property int index
                readonly property real from: chain.centres[index] + 72
                readonly property real to: chain.centres[index + 1] - 82
                readonly property string result: networkScreen.results[chain.steps[index]]
                readonly property bool running: result === "testing"
                                                || (index === 0 && networkScreen.chosenConnecting)
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        x: gap.from + index * (gap.to - gap.from) / 4 - width / 2
                        y: 79 - height / 2
                        width: 22; height: 22
                        radius: 11
                        color: gap.result === "ok" ? "#8CD43C"
                             : gap.running && index < chain.tick ? "#F2F4F5" : "transparent"
                        border.width: 2
                        border.color: gap.result === "ok" ? "#8CD43C" : "#B5BBBE"
                    }
                }
            }
        }

        Repeater {
            model: [{ icon: "console", label: Network.hostName || "This PC" },
                    { icon: networkScreen.chosen.kind === "wired" ? "ethernet" : "", label: networkScreen.chosenName },
                    { icon: "globe", label: "Internet" },
                    { icon: "controller", label: "Steam" }]
            Item {
                id: stop
                required property int index
                required property var modelData
                readonly property string result: index === 0 ? "" : networkScreen.results[chain.steps[index - 1]]
                x: chain.centres[index] - width / 2
                width: 240; height: parent.height

                TileIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: 79
                    width: 80; height: 80
                    visible: stop.modelData.icon !== ""
                    name: stop.modelData.icon
                    color: "#D3D7D9"
                }

                // Wi-Fi: the network's own signal bars
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 79 + 36 - 72
                    height: 72
                    spacing: 6
                    visible: stop.modelData.icon === ""
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            readonly property int strength: networkScreen.chosenNetwork ? networkScreen.chosenNetwork.signal : 0
                            readonly property int level: strength >= 75 ? 4 : strength >= 50 ? 3 : strength >= 25 ? 2 : strength > 0 ? 1 : 0
                            anchors.bottom: parent.bottom
                            width: 16; height: 30 + index * 14
                            color: index < level ? "#D3D7D9" : "#9BA3A6"
                        }
                    }
                }

                // A tick or a cross once that step has been tested
                StatusIcon {
                    x: parent.width / 2 + 28; y: 34
                    width: 32; height: 32; radius: 16
                    visible: stop.result === "ok" || stop.result === "fail" || stop.result === "portal"
                    result: stop.result
                }

                Text {
                    width: parent.width
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: 159
                    horizontalAlignment: Text.AlignHCenter
                    text: stop.modelData.label
                    color: "#D3D7D9"
                    font.pixelSize: 30
                    elide: Text.ElideRight
                }
            }
        }
    }
}