import QtQuick
import QtQuick.Shapes
import QtCore

// The Xbox Guide, laid out like the real Xbox 360 one (measured from a video
// of the console at 1920x1080, the same size as our canvas).
//
// Four blades: Games & Apps | <gamertag> | Media | Settings. The current
// blade's rows fill the white panel, with its name on a light strip to the
// left. Every other blade is a dark strip: earlier ones stack to the left,
// later ones to the right. LB/RB (or left/right) switch blades, up/down pick
// a row, A runs it, B closes, Y goes to Xbox Home.
FocusScope {
    id: guide
    visible: false

    property string gamertag
    property string gamerpic
    property color backdropColor: "#F0000000"

    // What the rows ask the dashboard to do
    signal tabRequested(int index)
    signal shelfRequested()
    signal quitRequested()

    property string gameTitle
    property bool confirming: false
    property var afterQuit: null
    property Item returnFocusTo: null
    property int tab: 1                         // opens on your gamertag blade
    property bool inControls: false             // on the media buttons (Media blade)
    property int control: 0                     // which media button
    // The controller you're using: its quarter of the ring of light and its battery
    readonly property var pad: Gamepad.controllers.find(c => c.id === Gamepad.lastUsed) || null
    readonly property int player: pad ? pad.player : 1



    readonly property string homeFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()

    // Box art of the last played game, for the "Play ..." row
    readonly property string lastCover: {
        GameLibrary.count                       // look again after a rescan
        return GameLibrary.find(Launcher.lastCommand).cover || ""
    }

    // The blades. Each row: label, and optionally an icon (from icons.js) or
    // image on the right, and run (what A does). Rows without run do nothing yet.
    readonly property var blades: [
        { title: "Games & Apps", rows: [
            { label: "Achievements" },
            { label: "Awards" },
            { label: "Recent" },
            { label: "My Games", dashboard: true, run: () => guide.shelfRequested() },
            { label: "Active Downloads" },
            { label: "Redeem Code" },
            { label: "Activity Feed" } ] },
        { title: guide.gamertag, rows: [
            { label: "Xbox Home", dashboard: true, icon: "home", run: () => guide.tabRequested(1) },
            { label: "File Browser", icon: "folder",
              run: () => Launcher.run(Qt.platform.os === "windows" ? "explorer"
                                                                    : "xdg-open " + guide.homeFolder) }
          ].concat(Launcher.lastName === "" ? [] : [
            { label: "Play " + Launcher.lastName, image: guide.lastCover,
              run: () => Launcher.play(Launcher.lastName, Launcher.lastCommand) } ]) },
        { title: "Media", media: true, rows: [
            { label: "System Video Player" },
            { label: "System Music Player" },
            { label: "Picture Viewer" } ] },
        { title: "Settings", rows: [
            { label: "Profile" },
            { label: "Preferences" },
            { label: "Family Settings" },
            { label: "System Settings", dashboard: true, run: () => guide.tabRequested(6) },
            { label: "Account Management" },
            { label: "Turn Off Console", run: () => guide.quitRequested() } ] }
    ]

    // Media buttons along the bottom of the Media blade. They control whatever
    // is playing (Spotify, a browser, ...) through playerctl on Linux.
    readonly property var mediaControls: [
        { icon: "playSolid", command: "playerctl play-pause" },
        { icon: "previous", command: "playerctl previous" },
        { icon: "stop", command: "playerctl stop" },
        { icon: "next", command: "playerctl next" },
        { icon: "shuffle", command: "playerctl shuffle Toggle" },
        { icon: "volume", command: "playerctl volume 0.1+" }
    ]

    readonly property var current: blades[tab]

    function open() {
        returnFocusTo = guide.Window.activeFocusItem
        tab = 1
        inControls = false
        list.currentIndex = 0
        visible = true
        list.forceActiveFocus()
        openAnimation.restart()
        Sounds.play("guide-open")
    }

    function close() {
        Sounds.play("guide-close")
        confirming = false
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function switchTab(step) {
        const next = tab + step
        if (next < 0 || next >= blades.length)
            return
        tab = next
        inControls = false
        list.currentIndex = 0
        slideIn.from = step * 60                // rows slide in from the side we moved towards
        slideIn.restart()
    }

    function activateCurrent() {
        if (inControls) {
            Launcher.run(mediaControls[control].command)    // the guide stays open
            return
        }
        const row = current.rows[list.currentIndex]
        if (!row.run)
            return                              // not built yet
        if (row.dashboard && gameTitle !== "") {
            askToQuit(row.run)                  // over a game: quit it first
            return
        }
        close()                                 // close first, so focus is back on the dashboard
        row.run()
    }

    function goHome() {
        if (gameTitle !== "") {
            askToQuit(() => guide.tabRequested(1))
            return
        }
        close()
        tabRequested(1)
    }

    // "Quit <game>?" - then() runs if you say yes
    function askToQuit(then) {
        afterQuit = then
        confirming = true
        confirmList.currentIndex = 1            // "No" is selected first, to be safe
        confirmList.forceActiveFocus()
    }

    function answer(yes) {
        if (!yes) {
            confirming = false
            list.forceActiveFocus()             // back to the Guide
            return
        }
        const then = afterQuit
        close()
        Launcher.closeGame()
        then()
    }

    // Left edge of blade i's strip, for the current tab
    function stripX(i) {
        if (i < tab) return 547 - (tab - i) * 67
        if (i === tab) return 547
        return 1370 + (i - tab - 1) * 68
    }

    // Almost-black backdrop; also stops the mouse reaching the dashboard underneath
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: guide.backdropColor
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: guide.close()
        }
    }

    // The white panel the guide grows out of when it opens
    Rectangle {
        id: base
        x: 547; y: 304
        width: 823; height: 471
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#F7FDFD" }
            GradientStop { position: 1.0; color: "#D2DDDE" }
        }
    }

    Item {
        id: details
        anchors.fill: parent

        Text {
            x: 548; y: 236
            text: "Xbox Guide"
            color: "#F0F0F0"
            font.pixelSize: 38
        }

        // Gamerpic: the saved picture, or the first letter on a green tile
        Rectangle {
            x: 928; y: 226
            width: 64; height: 64
            color: "#107C10"
            Text {
                anchors.centerIn: parent
                text: guide.gamertag.charAt(0).toUpperCase()
                color: "white"
                font.pixelSize: 36
            }
            Image {
                anchors.fill: parent
                source: guide.gamerpic
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        // Ring of light: which controller you are (player 1 = top-left quarter lit)
        Shape {
            x: 1335; y: 222
            width: 32; height: 32
            preferredRendererType: Shape.CurveRenderer

            RingQuarter { startAngle: 185; lit: guide.player === 1 }    // 0 degrees = 3 o'clock, going clockwise
            RingQuarter { startAngle: 275; lit: guide.player === 2 }
            RingQuarter { startAngle: 5; lit: guide.player === 4 }
            RingQuarter { startAngle: 95; lit: guide.player === 3 }
        }

        BatteryIcon {
            x: 1287; y: 227
            level: guide.pad ? guide.pad.battery : ""
            color: "#F0F0F0"
        }

        Text {
            id: clock
            x: 1370 - width                             // right edge lines up with the panel
            y: 261
            color: "#F0F0F0"
            font.pixelSize: 34

            Timer {
                interval: 1000
                running: guide.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
            }
        }

        // The current blade's rows (and media buttons) in the white panel
        Item {
            id: panel
            x: 642; y: 304
            width: 728; height: 471
            clip: true

            ListView {
                id: list
                width: parent.width
                height: guide.current.media ? 326 : parent.height
                model: guide.current.rows
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0

                transform: Translate { id: shift }
                NumberAnimation { id: slideIn; target: shift; property: "x"; to: 0; duration: 180; easing.type: Easing.OutCubic }

                delegate: GuideRow {
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    label: modelData.label
                    icon: modelData.icon || ""
                    image: modelData.image || ""
                    selected: ListView.isCurrentItem && !guide.inControls
                    onClicked: {
                        guide.inControls = false
                        list.currentIndex = index
                        guide.activateCurrent()
                    }
                }

                Keys.onDownPressed: (event) => {
                    if (currentIndex < count - 1)
                        currentIndex++
                    else if (guide.current.media)
                        guide.inControls = true     // off the bottom: onto the media buttons
                }
                Keys.onUpPressed: (event) => {
                    if (guide.inControls)
                        guide.inControls = false
                    else if (currentIndex > 0)
                        currentIndex--
                }
                Keys.onReturnPressed: guide.activateCurrent()
                Keys.onEnterPressed: guide.activateCurrent()
                Keys.onEscapePressed: guide.close()
                Keys.onPressed: (event) => {
                    const left = event.key === Qt.Key_Left, right = event.key === Qt.Key_Right
                    if (guide.inControls && (left || right)) {
                        // Left/right move between the media buttons
                        guide.control = Math.max(0, Math.min(guide.mediaControls.length - 1,
                                                             guide.control + (left ? -1 : 1)))
                        event.accepted = true
                    } else if (event.key === Qt.Key_Q || left) {
                        guide.switchTab(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_E || right) {
                        guide.switchTab(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Y) {
                        guide.goHome()
                        event.accepted = true
                    }
                }
            }

            // Media blade only: "Select Music" and the playback buttons
            Column {
                visible: guide.current.media === true
                y: 326
                width: parent.width

                GuideRow {
                    width: parent.width
                    label: "Select Music"
                }

                Row {
                    x: 14
                    Repeater {
                        model: guide.mediaControls
                        Rectangle {
                            required property int index
                            required property var modelData
                            width: 117; height: 82
                            color: guide.inControls && guide.control === index ? "#008E00" : "transparent"

                            TileIcon {
                                anchors.centerIn: parent
                                width: 40; height: 40
                                name: modelData.icon
                                color: guide.inControls && guide.control === index ? "white" : "#3A4246"
                            }
                            Rectangle {                     // divider on the right
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2; height: 62
                                color: "#C6CDD0"
                                visible: index < guide.mediaControls.length - 1
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    guide.inControls = true
                                    guide.control = index
                                    guide.activateCurrent()
                                }
                            }
                        }
                    }
                }
            }
        }

        // One strip per blade, sliding into place when the tab changes
        Repeater {
            model: guide.blades
            Rectangle {
                id: strip
                required property int index
                required property var modelData
                readonly property bool isCurrent: index === guide.tab

                x: guide.stripX(index)
                y: 304
                width: isCurrent ? 95 : 67
                height: 471
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                gradient: Gradient {
                    GradientStop { position: 0.0; color: strip.isCurrent ? "#D6DFE0" : "#465D6D" }
                    GradientStop { position: 1.0; color: strip.isCurrent ? "#BCC6C9" : "#465D6D" }
                }

                Rectangle {                             // darker line on the outer edge
                    width: 2; height: parent.height
                    x: index < guide.tab ? parent.width - 2 : 0
                    color: "#2F404C"
                    visible: !strip.isCurrent
                }

                // Name written sideways, reading downwards from the top
                Text {
                    x: (parent.width + height) / 2
                    y: 24
                    rotation: 90
                    transformOrigin: Item.TopLeft
                    width: 420
                    elide: Text.ElideRight
                    text: strip.modelData.title
                    color: strip.isCurrent ? "#7C878D" : "#E3E9ED"
                    font.pixelSize: 34
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: guide.switchTab(strip.index - guide.tab)
                }
            }
        }

        // "Quit <game>?" covering the blades, with Yes / No rows
        Rectangle {
            x: 547; y: 304
            width: 823; height: 471
            visible: guide.confirming
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F7FDFD" }
                GradientStop { position: 1.0; color: "#D2DDDE" }
            }

            Text {
                x: 32; y: 28
                width: parent.width - 64
                text: "Quit " + guide.gameTitle + "?"
                color: "#111111"
                font.pixelSize: 40
                elide: Text.ElideRight
            }
            Text {
                x: 32; y: 90
                text: "Any unsaved progress will be lost."
                color: "#555555"
                font.pixelSize: 30
            }

            ListView {
                id: confirmList
                x: 0; y: 175
                width: parent.width
                height: 126
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: ["Yes, quit and go to Xbox Home", "No, back to the game"]

                delegate: GuideRow {
                    required property int index
                    required property string modelData
                    width: ListView.view.width
                    label: modelData
                    selected: ListView.isCurrentItem
                    onClicked: guide.answer(index === 0)
                }

                Keys.onReturnPressed: guide.answer(currentIndex === 0)
                Keys.onEnterPressed: guide.answer(currentIndex === 0)
                Keys.onEscapePressed: guide.answer(false)
            }
        }

        Row {
            x: 548; y: 793
            spacing: 30
            ButtonHint { button: "A"; label: "Select" }
            ButtonHint { button: "B"; label: "Back" }
            ButtonHint { button: "X"; label: "Sign Out" }
            ButtonHint { button: "Y"; label: "Xbox Home" }
        }
    }

    // Opening: the screen darkens while the white panel grows out of the
    // middle, then the rows, strips and header fade in on top of it
    SequentialAnimation {
        id: openAnimation
        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { target: base; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: base; property: "opacity"; from: 0.35; to: 1; duration: 250 }
            PropertyAction { target: details; property: "opacity"; value: 0 }
        }
        NumberAnimation { target: details; property: "opacity"; to: 1; duration: 200 }
    }

    // A quarter of the ring of light
    component RingQuarter: ShapePath {
        id: quarter
        property real startAngle
        property bool lit: false
        fillColor: "transparent"
        strokeColor: lit ? "#6BD12B" : "#6E767A"
        strokeWidth: lit ? 4 : 2.5
        capStyle: ShapePath.FlatCap
        PathAngleArc {
            centerX: 16; centerY: 16
            radiusX: 13; radiusY: 13
            startAngle: quarter.startAngle
            sweepAngle: 80
        }
    }

    // One row of a blade
    component GuideRow: Rectangle {
        id: row
        property string label
        property string icon
        property string image
        property bool selected
        signal clicked()

        height: 63
        color: selected ? "#008E00" : "#F5FBFD"

        Rectangle {                                 // light line along the top of the selected row
            width: parent.width; height: 2
            color: "#15A31A"
            visible: row.selected
        }
        Rectangle {                                 // line under every row
            anchors.bottom: parent.bottom
            width: parent.width; height: 2
            color: "#CED4D6"
            visible: !row.selected
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 72
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.label
            color: row.selected ? "white" : "#111111"
            font.pixelSize: 35
        }

        TileIcon {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 42
            name: row.icon
            color: row.selected ? "white" : "#111111"
        }

        Image {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 46
            source: row.image
            visible: row.image !== "" && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 92
        }

        MouseArea {
            anchors.fill: parent
            onClicked: row.clicked()
        }
    }
}