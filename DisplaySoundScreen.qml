import QtQuick

// Settings > Display & Sound: volume, mute and where sound plays, then the
// screen's resolution, refresh rate, scale, HDR and adaptive sync (with KDE
// Plasma). A display change asks whether to keep it, and goes back by itself
// after 15 seconds in case the screen can't show it.
FocusScope {
    id: displaySound
    visible: false

    property Item returnFocusTo: null

    // "menu", or "choose": picking one of the choices for a setting
    property string view: "menu"
    property string choosing: ""                // "output", "resolution", "refresh", "scale" or "vrr"
    property var choices: []                    // [{label, detail, value, current}]

    // The menu's rows, by id; only the ones this PC can use
    property var rows: []

    // A display change waiting to be kept: {kind, value} to go back to
    property var undo: null
    property int secondsLeft: 0

    readonly property var display: DisplaySettings.current

    function open() {
        returnFocusTo = Window.activeFocusItem
        card.visible = false
        view = "menu"
        updateRows()
        menu.currentIndex = 0
        visible = true
        menu.forceActiveFocus()
        DisplaySettings.refresh(Screen.name)
        panelAnimation.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function back() {
        if (view === "choose") {
            view = "menu"
            menu.forceActiveFocus()
        } else {
            close()
        }
    }

    function updateRows() {
        const list = ["volume", "mute", "output"]
        if (DisplaySettings.available) {
            list.push("resolution", "refresh", "scale")
            if (display.hdr)
                list.push("hdr")
            if (display.vrr)
                list.push("vrr")
        } else {
            list.push("display")
        }
        if (JSON.stringify(list) === JSON.stringify(rows))
            return
        const selected = rows[menu.currentIndex]     // stay on the same row
        rows = list
        menu.currentIndex = Math.max(0, list.indexOf(selected))
    }

    function label(id) {
        return { volume: "Volume", mute: "Mute", output: "Sound Output", resolution: "Resolution",
                 refresh: "Refresh Rate", scale: "Scale", hdr: "HDR", vrr: "Adaptive Sync", display: "Display" }[id] || ""
    }

    function usable(id) {
        if (id === "volume" || id === "mute" || id === "output")
            return AudioSettings.available
        return id !== "display"
    }

    function vrrWords(policy) {
        return { never: "Never", automatic: "Automatic", always: "Always" }[policy] || ""
    }

    // What a row says on the right
    function value(id) {
        if (!usable(id) && id !== "display")
            return "–"
        switch (id) {
        case "volume": return AudioSettings.volume + "%"
        case "mute": return AudioSettings.muted ? "On" : "Off"
        case "output": {
            const current = AudioSettings.outputs.find(o => o.current)
            return current ? current.description : ""
        }
        case "resolution": return display.width + " × " + display.height
        case "refresh": return display.refresh > 0 ? Math.round(display.refresh) + " Hz" : "–"
        case "scale": return Math.round(display.scale * 100) + "%"
        case "hdr": return display.hdr === "on" ? "On" : "Off"
        case "vrr": return vrrWords(display.vrr)
        case "display": return Math.round(Screen.width * Screen.devicePixelRatio) + " × "
                               + Math.round(Screen.height * Screen.devicePixelRatio)
        }
        return ""
    }

    // What the panel on the right says about a row
    function about(id) {
        return {
            volume: "How loud everything is. Press left or right to change it.",
            mute: "Turns all sound off, and back on again.",
            output: "Where sound plays: your speakers, a headset, or your TV.",
            resolution: "How sharp the picture is. If the screen goes black after a change, "
                        + "wait: it goes back by itself after 15 seconds.",
            refresh: "How many times a second the picture changes. Higher is smoother.",
            scale: "How big the desktop draws text and windows.",
            hdr: "Brighter highlights and deeper colours, in games and videos made for HDR.",
            vrr: "Lets the screen keep pace with the game, for smoother play without tearing.",
            display: "Changing the screen's settings from here needs KDE Plasma.",
        }[id] || ""
    }

    function activate(id) {
        if (!usable(id))
            return
        if (id === "mute") {
            AudioSettings.setMuted(!AudioSettings.muted)
        } else if (id === "hdr") {
            const was = display.hdr
            changeDisplay("hdr", was, () => DisplaySettings.setHdr(was !== "on"))
        } else if (id !== "volume") {
            choosing = id
            choices = choicesFor(id)
            view = "choose"
            chooser.currentIndex = Math.max(0, choices.findIndex(c => c.current))
            chooser.forceActiveFocus()
        }
    }

    function choicesFor(id) {
        if (id === "output") {
            return AudioSettings.outputs.map(o => ({ label: o.description, detail: o.unplugged ? "Unplugged" : "",
                                                     value: o.name, current: o.current }))
        }
        const seen = {}
        const list = []
        if (id === "resolution") {
            for (const mode of DisplaySettings.modes) {
                const key = mode.width + "x" + mode.height
                if (seen[key])
                    continue
                seen[key] = true
                list.push({ label: mode.width + " × " + mode.height, detail: "", value: key,
                            current: mode.width === display.width && mode.height === display.height })
            }
        } else if (id === "refresh") {
            for (const mode of DisplaySettings.modes) {
                const hz = Math.round(mode.refresh)
                if (mode.width !== display.width || mode.height !== display.height || seen[hz])
                    continue
                seen[hz] = true
                list.push({ label: hz + " Hz", detail: "", value: mode.id, current: hz === Math.round(display.refresh) })
            }
        } else if (id === "scale") {
            for (const scale of [1, 1.25, 1.5, 1.75, 2]) {
                list.push({ label: Math.round(scale * 100) + "%", detail: scale === 1 ? "Normal size" : "",
                            value: scale, current: Math.abs(scale - display.scale) < 0.01 })
            }
        } else if (id === "vrr") {
            list.push({ label: "Never", detail: "", value: "never", current: display.vrr === "never" })
            list.push({ label: "Automatic", detail: "When a game asks for it", value: "automatic",
                        current: display.vrr === "automatic" })
            list.push({ label: "Always", detail: "", value: "always", current: display.vrr === "always" })
        }
        return list
    }

    function choose(choice) {
        back()
        if (choice.current)
            return
        if (choosing === "output") {
            AudioSettings.setOutput(choice.value)
        } else if (choosing === "resolution") {
            // The new size at the same refresh rate if it has it, or its fastest
            const size = choice.value.split("x").map(Number)
            const modes = DisplaySettings.modes.filter(m => m.width === size[0] && m.height === size[1])
            const same = modes.find(m => Math.round(m.refresh) === Math.round(display.refresh))
            const was = display.modeId
            changeDisplay("mode", was, () => DisplaySettings.setMode((same || modes[0]).id))
        } else if (choosing === "refresh") {
            const was = display.modeId
            changeDisplay("mode", was, () => DisplaySettings.setMode(choice.value))
        } else if (choosing === "scale") {
            const was = display.scale
            changeDisplay("scale", was, () => DisplaySettings.setScale(choice.value))
        } else if (choosing === "vrr") {
            DisplaySettings.setVrr(choice.value)
        }
    }

    // Make a display change, then ask whether to keep it
    function changeDisplay(kind, was, change) {
        undo = { kind: kind, value: was }
        change()
        secondsLeft = 15
        card.title = "Keep Display Settings?"
        card.message = Qt.binding(() => "If you can see this, choose Keep. Otherwise it goes back to how it was in "
                                        + secondsLeft + (secondsLeft === 1 ? " second." : " seconds."))
        card.options = [{ label: "Keep", run: () => { undo = null; countdown.stop() } },
                        { label: "Go Back", run: () => revert() }]
        card.defaultIndex = 0
        card.open()
        countdown.restart()
    }

    function revert() {
        countdown.stop()
        if (!undo)
            return
        const was = undo
        undo = null
        if (was.kind === "mode")
            DisplaySettings.setMode(was.value)
        else if (was.kind === "scale")
            DisplaySettings.setScale(was.value)
        else if (was.kind === "hdr")
            DisplaySettings.setHdr(was.value === "on")
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            displaySound.secondsLeft--
            if (displaySound.secondsLeft <= 0) {
                card.close()
                displaySound.revert()
            }
        }
    }

    // B on the question counts as Go Back
    Connections {
        target: card
        function onVisibleChanged() {
            if (!card.visible)
                Qt.callLater(() => { if (displaySound.undo) displaySound.revert() })
        }
    }

    Connections {
        target: DisplaySettings
        function onChanged() { displaySound.updateRows() }
    }

    // Changes made elsewhere (like a keyboard's volume keys) show up here too
    Binding {
        target: AudioSettings
        property: "watching"
        value: displaySound.visible
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
        text: displaySound.view === "choose" ? displaySound.label(displaySound.choosing) : "Display & Sound"
        color: "white"
        font.pixelSize: 50
    }

    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719

        Rectangle {
            width: 760; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            // ---- The settings ----
            ListView {
                id: menu
                width: parent.width
                height: count * 70
                visible: displaySound.view === "menu"
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: displaySound.rows

                delegate: SettingRow {}

                Keys.onReturnPressed: displaySound.activate(displaySound.rows[currentIndex])
                Keys.onEnterPressed: displaySound.activate(displaySound.rows[currentIndex])
                Keys.onPressed: (event) => {
                    // Left and right change the volume
                    if (displaySound.rows[currentIndex] !== "volume" || !AudioSettings.available)
                        return
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        AudioSettings.setVolume(AudioSettings.volume + (event.key === Qt.Key_Right ? 5 : -5))
                        Sounds.play("move")
                        event.accepted = true
                    }
                }
            }

            // ---- The choices for one setting ----
            ListView {
                id: chooser
                width: parent.width
                height: Math.min(count * 70, Math.floor(parent.height / 70) * 70)
                visible: displaySound.view === "choose"
                clip: true
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: displaySound.choices
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: ChoiceRow {}

                Keys.onReturnPressed: displaySound.choose(displaySound.choices[currentIndex])
                Keys.onEnterPressed: displaySound.choose(displaySound.choices[currentIndex])
            }
        }

        // ---- About the selected setting ----
        Rectangle {
            x: 760
            width: 560; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            readonly property string row: displaySound.view === "choose" ? displaySound.choosing
                                                                          : displaySound.rows[menu.currentIndex] || ""
            readonly property bool sound: row === "volume" || row === "mute" || row === "output"

            TileIcon {
                x: 40; y: 40
                width: 96; height: 96
                name: parent.sound ? "volume" : "tv"
                color: "#2E3336"
            }
            Text {
                x: 40; y: 170
                width: parent.width - 80
                text: displaySound.label(parent.row)
                color: "#2E3336"
                font.pixelSize: 36
            }
            Text {
                x: 40; y: 226
                width: parent.width - 80
                text: displaySound.about(parent.row)
                color: "#3A4044"
                font.pixelSize: 28
                wrapMode: Text.WordWrap
            }

            // The volume, big, while it's the one selected
            Column {
                x: 40; y: 420
                width: parent.width - 80
                spacing: 16
                visible: parent.row === "volume" && AudioSettings.available
                Text {
                    text: AudioSettings.muted ? "Muted" : AudioSettings.volume + "%"
                    color: "#2E3336"
                    font.pixelSize: 72
                }
                Rectangle {
                    width: parent.width; height: 22
                    color: "#2B3033"
                    Rectangle {
                        width: parent.width * AudioSettings.volume / 100
                        height: parent.height
                        color: AudioSettings.muted ? "#7A8085" : "#6BD12B"
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
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
        ButtonHint {
            button: "A"
            label: "Select"
            visible: displaySound.view === "choose"
                     || (displaySound.usable(displaySound.rows[menu.currentIndex])
                         && displaySound.rows[menu.currentIndex] !== "volume")
        }
        ButtonHint { button: "B"; label: "Back" }
    }

    MessageCard {
        id: card
        anchors.fill: parent
        icon: "?"
    }

    // ---- Pieces ----------------------------------------------------------------

    // A setting: its name, and what it's set to on the right
    component SettingRow: Rectangle {
        id: row
        required property int index
        required property string modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property bool usable: displaySound.usable(modelData)
        readonly property color ink: selected ? "white" : usable ? "#222222" : "#9AA3A6"

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        Text {
            x: 45
            anchors.verticalCenter: parent.verticalCenter
            text: displaySound.label(row.modelData)
            color: row.ink
            font.pixelSize: 36
        }

        Rectangle {                             // a little volume bar
            anchors.right: value.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 120; height: 14
            visible: row.modelData === "volume" && row.usable
            color: row.selected ? "#1F5C12" : "#2B3033"
            Rectangle {
                width: parent.width * AudioSettings.volume / 100
                height: parent.height
                color: AudioSettings.muted ? "#7A8085" : (row.selected ? "white" : "#6BD12B")
            }
        }

        Text {
            id: value
            anchors.right: parent.right
            anchors.rightMargin: 45
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 380)
            horizontalAlignment: Text.AlignRight
            text: displaySound.value(row.modelData)
            color: row.ink
            font.pixelSize: 32
            elide: Text.ElideRight
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
                displaySound.activate(row.modelData)
            }
        }
    }

    // A choice: a tick next to the one in use now
    component ChoiceRow: Rectangle {
        id: choice
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property color ink: selected ? "white" : "#222222"

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        TileIcon {
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            name: "check"
            color: choice.ink
            visible: choice.modelData.current
        }
        Text {
            x: 90
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - detail.width - 70
            text: choice.modelData.label
            color: choice.ink
            font.pixelSize: 36
            elide: Text.ElideRight
        }
        Text {
            id: detail
            anchors.right: parent.right
            anchors.rightMargin: 45
            anchors.verticalCenter: parent.verticalCenter
            text: choice.modelData.detail
            color: choice.selected ? "white" : "#5A6064"
            font.pixelSize: 28
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !choice.selected && choice.ListView.view.currentIndex !== choice.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) choice.ListView.view.currentIndex = choice.index
            onClicked: {
                choice.ListView.view.currentIndex = choice.index
                displaySound.choose(choice.modelData)
            }
        }
    }
}