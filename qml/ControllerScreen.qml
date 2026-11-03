import QtQuick

// Settings > Controllers: every connected controller with its player number
// and battery. Pick one to test it (a live picture of the controller that
// lights up every button and moves with the sticks and triggers, to spot
// stick drift), make it vibrate, or turn it off.
FocusScope {
    id: controllersScreen
    visible: false

    property Item returnFocusTo: null

    // "list", "pad" (one controller) or "test"
    property string view: "list"
    property int padId: -1
    readonly property var pad: Gamepad.controllers.find(c => c.id === padId) || null

    // "xbox", "playstation" or "nintendo": how its buttons are labelled
    readonly property string family: pad && pad.type ? pad.type : "xbox"

    // What the controller is doing right now (pad and test views)
    property var input: ({})

    // Test Controller: how long B has been held (to leave), and each
    // stick's resting place, to tell drift from a thumb on the stick
    property real holdB: 0
    property var steady: ({ left: { x: 0, y: 0, since: 0 }, right: { x: 0, y: 0, since: 0 } })
    property real now: 0                        // the time, so "Drift" shows up while nothing moves

    function open() {
        returnFocusTo = Window.activeFocusItem
        card.visible = false
        view = "list"
        list.currentIndex = 0
        visible = true
        list.forceActiveFocus()
        panelAnimation.restart()
    }

    function close() {
        Gamepad.captured = false
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function back() {
        if (view === "test") {
            Gamepad.captured = false
            view = "pad"
            padList.forceActiveFocus()
        } else if (view === "pad") {
            view = "list"
            list.forceActiveFocus()
        } else {
            close()
        }
    }

    function showPad(id) {
        padId = id
        view = "pad"
        padList.currentIndex = 0
        padList.forceActiveFocus()
        panelAnimation.restart()
    }

    function showTest() {
        holdB = 0
        steady = { left: { x: 0, y: 0, since: Date.now() }, right: { x: 0, y: 0, since: Date.now() } }
        view = "test"
        Gamepad.captured = true                 // every button is for testing now; hold B to leave
        tester.forceActiveFocus()
    }

    function activate(row) {
        if (row === "test") {
            showTest()
        } else if (row === "vibrate") {
            Gamepad.vibrate(padId)
        } else if (row === "off" && !Gamepad.turnOff(padId)) {
            card.title = "Turn Off Controller"
            card.message = "Only Bluetooth controllers can be turned off from here. To turn this one off, "
                         + "unplug it or hold its Guide button."
            card.options = [{ label: "OK", run: () => {} }]
            card.defaultIndex = 0
            card.open()
        }
    }

    // "Bluetooth", "Wired", "Wireless" or ""
    function connection(c) {
        return c.bluetooth ? "Bluetooth" : c.wired ? "Wired" : c.battery !== "" ? "Wireless" : ""
    }

    // "Medium (55%)", "Full", "" when it can't be read
    function batteryWords(c) {
        if (c.battery === "")
            return ""
        return c.battery.charAt(0).toUpperCase() + c.battery.slice(1) + (c.percent >= 0 ? " (" + c.percent + "%)" : "")
    }

    // A stick at rest should sit in the middle: "Centered", "Moving", or
    // "Drift" when it stays a little off-center without being touched
    function stickWords(which, x, y) {
        const rest = steady[which]
        const distance = Math.sqrt(x * x + y * y)
        if (distance < 0.1)
            return "Centered"
        if (distance < 0.4 && now - rest.since > 800)
            return "Drift " + distance.toFixed(2)
        return "Moving"
    }

    function track(which, x, y) {
        const rest = steady[which]
        if (Math.abs(x - rest.x) > 0.02 || Math.abs(y - rest.y) > 0.02) {
            const moved = Object.assign({}, steady)
            moved[which] = { x: x, y: y, since: Date.now() }
            steady = moved
        }
    }

    // The controller you were looking at was unplugged or turned off
    onPadChanged: {
        if (pad === null && view !== "list") {
            Gamepad.captured = false
            view = "list"
            list.forceActiveFocus()
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: controllersScreen.visible && controllersScreen.view !== "list"
        onTriggered: {
            const current = Gamepad.state(controllersScreen.padId)
            controllersScreen.input = current
            if (controllersScreen.view !== "test")
                return
            controllersScreen.now = Date.now()
            controllersScreen.track("left", current.leftX || 0, current.leftY || 0)
            controllersScreen.track("right", current.rightX || 0, current.rightY || 0)
            controllersScreen.holdB = current.buttons && current.buttons.b ? controllersScreen.holdB + interval : 0
            if (controllersScreen.holdB >= 1000)
                controllersScreen.back()
        }
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
        text: controllersScreen.view === "list" ? "Controllers"
            : controllersScreen.view === "test" ? "Test Controller" : "Controller"
        color: "white"
        font.pixelSize: 50
    }

    Text {                                      // which controller, top right
        anchors.right: parent.left
        anchors.rightMargin: -1775
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 124
        width: 900
        horizontalAlignment: Text.AlignRight
        visible: controllersScreen.view !== "list" && controllersScreen.pad !== null
        text: controllersScreen.pad ? controllersScreen.pad.name : ""
        color: "white"
        font.pixelSize: 36
        elide: Text.ElideLeft
    }

    // ---- The list, and one controller ----
    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719
        visible: controllersScreen.view !== "test"

        Rectangle {
            width: controllersScreen.view === "list" ? parent.width : 660
            height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            // Every controller
            ListView {
                id: list
                width: parent.width
                height: Math.floor(parent.height / 156) * 156
                visible: controllersScreen.view === "list"
                clip: true
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: Gamepad.controllers
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: PadRow {}

                Keys.onReturnPressed: if (currentIndex >= 0 && count > 0) controllersScreen.showPad(Gamepad.controllers[currentIndex].id)
                Keys.onEnterPressed: if (currentIndex >= 0 && count > 0) controllersScreen.showPad(Gamepad.controllers[currentIndex].id)
            }

            Text {
                x: 45; y: 40
                width: parent.width - 90
                visible: controllersScreen.view === "list" && list.count === 0
                text: "No controllers are connected. Plug one in, or turn on a wireless one."
                color: "#333333"
                font.pixelSize: 36
                wrapMode: Text.WordWrap
            }

            // What you can do with one
            ListView {
                id: padList
                width: parent.width
                height: count * 70
                visible: controllersScreen.view === "pad"
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: ["test", "vibrate", "off"]

                delegate: MenuRow {
                    label: modelData === "test" ? "Test Controller" : modelData === "vibrate" ? "Vibrate" : "Turn Off Controller"
                    usable: modelData !== "off" || (controllersScreen.pad !== null && controllersScreen.pad.bluetooth)
                    onChosen: controllersScreen.activate(modelData)
                }

                Keys.onReturnPressed: controllersScreen.activate(model[currentIndex])
                Keys.onEnterPressed: controllersScreen.activate(model[currentIndex])
            }
        }

        // Right of one controller's list: the controller itself (it lights
        // up as you press things), its player number, battery and connection
        Rectangle {
            x: 660
            width: 660; height: parent.height
            visible: controllersScreen.view === "pad"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            ControllerPicture {
                x: (parent.width - width * scale) / 2
                y: 6
                scale: 0.6
                transformOrigin: Item.TopLeft
                input: controllersScreen.input
                player: controllersScreen.pad ? controllersScreen.pad.player : 0
                family: controllersScreen.family
            }

            Column {
                x: 40; y: 430
                spacing: 10
                Text {
                    text: controllersScreen.pad && controllersScreen.pad.player > 0
                          ? "Player " + controllersScreen.pad.player : "No player number"
                    color: "#2E3336"
                    font.pixelSize: 36
                }
                Row {
                    spacing: 16
                    visible: controllersScreen.pad !== null && controllersScreen.pad.battery !== ""
                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        level: controllersScreen.pad ? controllersScreen.pad.battery : ""
                        color: "#2E3336"
                    }
                    Text {
                        text: controllersScreen.pad ? "Battery: " + controllersScreen.batteryWords(controllersScreen.pad) : ""
                        color: "#2E3336"
                        font.pixelSize: 32
                    }
                }
                Text {
                    visible: text !== ""
                    text: controllersScreen.pad && controllersScreen.connection(controllersScreen.pad) !== ""
                          ? "Connection: " + controllersScreen.connection(controllersScreen.pad) : ""
                    color: "#2E3336"
                    font.pixelSize: 32
                }
            }
        }

        // Like the 360's lists: the panel grows out of the middle
        ParallelAnimation {
            id: panelAnimation
            NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
        }
    }

    Row {
        x: 138; y: 973
        spacing: 30
        visible: controllersScreen.view !== "test"
        ButtonHint {
            button: "A"
            label: "Select"
            visible: controllersScreen.view === "pad"
                     ? padList.currentIndex !== 2 || (controllersScreen.pad !== null && controllersScreen.pad.bluetooth)
                     : list.count > 0
        }
        ButtonHint { button: "B"; label: "Back" }
    }

    // ---- Test Controller ----
    FocusScope {
        id: tester
        anchors.fill: parent
        visible: controllersScreen.view === "test"

        ControllerPicture {
            x: 105; y: 185
            input: controllersScreen.input
            player: controllersScreen.pad ? controllersScreen.pad.player : 0
            family: controllersScreen.family
        }

        // The numbers: where each stick is, and how far the triggers are pulled
        Rectangle {
            x: 960; y: 171
            width: 815; height: 760
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            StickReadout {
                y: 24
                title: "Left Stick"
                which: "left"
                stickX: controllersScreen.input.leftX || 0
                stickY: controllersScreen.input.leftY || 0
            }
            StickReadout {
                y: 300
                title: "Right Stick"
                which: "right"
                stickX: controllersScreen.input.rightX || 0
                stickY: controllersScreen.input.rightY || 0
            }

            Column {
                x: 36; y: 580
                spacing: 14
                Text {
                    text: "Triggers"
                    color: "#2E3336"
                    font.pixelSize: 34
                }
                TriggerReadout {
                    label: controllersScreen.family === "playstation" ? "L2" : controllersScreen.family === "nintendo" ? "ZL" : "LT"
                    amount: controllersScreen.input.lt || 0
                }
                TriggerReadout {
                    label: controllersScreen.family === "playstation" ? "R2" : controllersScreen.family === "nintendo" ? "ZR" : "RT"
                    amount: controllersScreen.input.rt || 0
                }
            }
        }

        // Hold B to leave: the bar fills while it's held
        Row {
            x: 138; y: 973
            spacing: 14
            ButtonHint { button: "B"; label: "Hold to Go Back" }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 160; height: 10
                radius: 5
                color: "#55FFFFFF"
                Rectangle {
                    width: parent.width * Math.min(1, controllersScreen.holdB / 1000)
                    height: parent.height
                    radius: 5
                    color: "#E8402A"
                }
            }
        }
        Text {
            anchors.right: parent.left
            anchors.rightMargin: -1775
            y: 978
            text: "Press anything on the controller to see it light up"
            color: "white"
            opacity: 0.8
            font.pixelSize: 28
        }
    }

    MessageCard {
        id: card
        anchors.fill: parent
        icon: "!"
    }

    // ---- Pieces ----------------------------------------------------------------

    // A controller in the list: its name, then its player number and connection,
    // with its battery on the right
    component PadRow: Rectangle {
        id: row
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property color ink: selected ? "white" : "#333333"

        width: ListView.view.width
        height: 156
        color: selected ? "#008E00" : "transparent"

        TileIcon {
            x: 26
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 48
            width: 68; height: 68
            name: "controller"
            color: row.ink
        }
        Text {
            x: 128
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 48
            width: parent.width - x - 340
            text: row.modelData.name
            color: row.ink
            font.pixelSize: 36
            elide: Text.ElideRight
        }
        Text {
            x: 128
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 119
            text: [row.modelData.player > 0 ? "Player " + row.modelData.player : "",
                   controllersScreen.connection(row.modelData)].filter(t => t !== "").join("  ·  ")
            color: row.ink
            font.pixelSize: 32
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 47
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 48
            spacing: 16
            BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                level: row.modelData.battery
                color: row.ink
            }
            Text {
                text: controllersScreen.batteryWords(row.modelData)
                color: row.ink
                font.pixelSize: 32
            }
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
                controllersScreen.showPad(row.modelData.id)
            }
        }
    }

    // A row in a list: green when you're on it, a grey line under the others
    component MenuRow: Rectangle {
        id: menuRow
        required property int index
        required property var modelData
        property string label
        property bool usable: true
        signal chosen()
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        Text {
            x: 45
            anchors.verticalCenter: parent.verticalCenter
            text: menuRow.label
            color: menuRow.selected ? "white" : menuRow.usable ? "#222222" : "#9AA3A6"
            opacity: menuRow.selected && !menuRow.usable ? 0.7 : 1
            font.pixelSize: 36
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !menuRow.selected && menuRow.ListView.view.currentIndex !== menuRow.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) menuRow.ListView.view.currentIndex = menuRow.index
            onClicked: {
                menuRow.ListView.view.currentIndex = menuRow.index
                menuRow.chosen()
            }
        }
    }

    // One stick: a square with a dot where the stick is (the small circle in
    // the middle is "close enough to centered"), its X and Y, and whether it
    // sits centered when you let go
    component StickReadout: Item {
        id: readout
        property string title
        property string which
        property real stickX
        property real stickY
        readonly property string words: controllersScreen.stickWords(which, stickX, stickY)

        x: 36
        width: 743; height: 250

        Text {
            text: readout.title
            color: "#2E3336"
            font.pixelSize: 34
        }

        Rectangle {
            id: plot
            y: 50
            width: 200; height: 200
            color: "#2B3033"
            Rectangle { x: parent.width / 2; width: 1; height: parent.height; color: "#59636A" }
            Rectangle { y: parent.height / 2; width: parent.width; height: 1; color: "#59636A" }
            Rectangle {                         // "centered" is anywhere in here
                anchors.centerIn: parent
                width: 20; height: 20
                radius: 10
                color: "transparent"
                border.color: "#6BD12B"
                border.width: 2
            }
            Rectangle {
                x: parent.width / 2 + readout.stickX * (parent.width / 2 - 8) - width / 2
                y: parent.height / 2 + readout.stickY * (parent.height / 2 - 8) - height / 2
                width: 16; height: 16
                radius: 8
                color: readout.words.startsWith("Drift") ? "#FFB020" : "white"
            }
        }

        Column {
            x: 240; y: 64
            spacing: 8
            Text {
                text: "X   " + (readout.stickX >= 0 ? " " : "") + readout.stickX.toFixed(2)
                color: "#2E3336"
                font.pixelSize: 34
                font.family: "monospace"
            }
            Text {
                text: "Y   " + (readout.stickY >= 0 ? " " : "") + readout.stickY.toFixed(2)
                color: "#2E3336"
                font.pixelSize: 34
                font.family: "monospace"
            }
            Text {
                text: readout.words
                color: readout.words === "Centered" ? "#1E8E10" : readout.words.startsWith("Drift") ? "#D9800A" : "#5A6064"
                font.pixelSize: 34
            }
            Text {
                visible: readout.words.startsWith("Drift")
                text: "Not touching it? Then it drifts."
                color: "#5A6064"
                font.pixelSize: 26
            }
        }
    }

    // LT 0% [=====     ]
    component TriggerReadout: Row {
        id: triggerRow
        property string label
        property real amount
        spacing: 18
        Text {
            width: 50
            text: triggerRow.label
            color: "#2E3336"
            font.pixelSize: 30
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 520; height: 22
            color: "#2B3033"
            Rectangle {
                width: parent.width * triggerRow.amount
                height: parent.height
                color: "#6BD12B"
            }
        }
        Text {
            text: Math.round(triggerRow.amount * 100) + "%"
            color: "#2E3336"
            font.pixelSize: 30
        }
    }
}