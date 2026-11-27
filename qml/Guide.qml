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
// a row, A runs it, B closes, Y goes to Xbox Home. Switching blades slides
// the new one in a little while the old one fades, like the 360 does.
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
    signal achievementsRequested()
    signal recentsRequested()
    signal profileRequested()
    signal preferencesRequested()
    signal signOutRequested()

    property string gameTitle
    property string appTitle                    // an app the Guide's open over (not a game), to close
    property bool confirming: false
    property var afterQuit: null
    // What the confirm box asks: [question, note, yes, no]
    property var question: []
    property Item returnFocusTo: null
    property int tab: 1                         // opens on your gamertag blade
    property bool inControls: false             // on the media buttons (Media blade)
    property bool atSelectMusic: false          // on Select Music, above them
    property int control: 0                     // which media button
    property int targetTab: 1                   // the blade it's switching to
    property bool switching: false              // until the picture of the old blade is taken
    property var oldBlade: null                 // that picture, while it fades away
    // The controller you're using: its quarter of the ring of light and its battery
    readonly property var pad: Gamepad.controllers.find(c => c.id === Gamepad.lastUsed) || null
    readonly property int player: pad ? pad.player : 1



    readonly property string homeFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()

    // Box art of the last played game, for the "Play ..." row
    readonly property string lastCover: {
        GameLibrary.count                       // look again after a rescan
        return GameLibrary.find(Launcher.lastCommand).cover || ""
    }

    // Active Downloads is Steam's
    readonly property bool hasSteam: {
        GameLibrary.count
        return GameLibrary.all().some(game => game.source === "Steam")
    }

    // The blades. Each row: label, and optionally an icon (from icons.js) or
    // image on the right, and run (what A does). dashboard: it opens something
    // on the dashboard, so over a game you're asked to quit the game first.
    readonly property var blades: [
        { title: "Games & Apps", rows: [
            { label: "Achievements", dashboard: true, run: () => guide.achievementsRequested() },
            { label: "Recent", dashboard: true, run: () => guide.recentsRequested() },
            { label: "My Games", dashboard: true, run: () => guide.shelfRequested() }
          ].concat(!guide.hasSteam ? [] : [
            { label: "Active Downloads", run: () => Qt.openUrlExternally("steam://open/downloads") } ]) },
        { title: guide.gamertag, rows: [
                { label: "Xbox Home", dashboard: true, icon: "home", run: () => guide.tabRequested(1) }
              ].concat(guide.appTitle === "" ? [] : [
                { label: "Close " + guide.appTitle, icon: "cross", asks: true, run: () => guide.askToClose() } ]).concat([
                { label: "File Browser", icon: "folder",
                  run: () => Launcher.run(Qt.platform.os === "windows" ? "explorer"
                                                                        : "xdg-open " + guide.homeFolder) }
              ]).concat(Launcher.lastName === "" ? [] : [
            { label: "Play " + Launcher.lastName, image: guide.lastCover,
              run: () => Launcher.play(Launcher.lastName, Launcher.lastCommand) } ]) },
        { title: "Media", media: true, rows: [
            { label: "System Video Player", run: () => guide.openPlayer(AppLibrary.videoApps(), StandardPaths.MoviesLocation) },
            { label: "System Music Player", run: () => guide.openPlayer(AppLibrary.musicApps(), StandardPaths.MusicLocation) },
            { label: "Picture Viewer", run: () => guide.openFolder(StandardPaths.PicturesLocation) } ] },
        { title: "Settings", rows: [
            { label: "Profile", dashboard: true, run: () => guide.profileRequested() },
            { label: "Preferences", dashboard: true, run: () => guide.preferencesRequested() },
            { label: "Turn Off Console", run: () => guide.quitRequested() } ] }
    ]

    // The Media blade's row above its buttons: your music, to pick from
    readonly property var selectMusic: ({ label: "Select Music", run: () => guide.openFolder(StandardPaths.MusicLocation) })

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
        targetTab = 1
        switching = false
        crossFade.stop()
        oldBlade = null
        slideIn.complete()
        inControls = false
        atSelectMusic = false
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
        goToBlade((switching ? targetTab : tab) + step)
    }

    // Like the 360: the highlight goes, then the new blade (strips and all)
    // slides in a little from the side you're going towards while the old one
    // fades away. The old one is a picture of it, fading on top.
    function goToBlade(index) {
        if (index < 0 || index >= blades.length || index === (switching ? targetTab : tab))
            return
        targetTab = index
        if (switching)
            return                              // already on its way: it goes on to this one
        switching = true                        // no highlight in the picture
        slideIn.complete()                      // the picture is of it where it belongs
        if (!bladeArea.grabToImage(picture => showBlade(picture)))
            showBlade(null)                     // not on screen: no picture to fade
    }

    function showBlade(picture) {
        const step = targetTab > tab ? 1 : -1
        oldBlade = picture                      // keeps the picture while it's shown
        tab = targetTab
        inControls = false
        atSelectMusic = false
        list.currentIndex = 0
        switching = false
        if (picture)
            crossFade.restart()
        slideIn.from = step * 50
        slideIn.restart()
    }

    // The app you opened last of these (or the first one), or the folder when
    // you have none
    function openPlayer(apps, folder) {
        const recent = Launcher.recents.find(r => r.kind === "app" && apps.some(app => app.command === r.command))
        const app = recent ? apps.find(app => app.command === recent.command) : apps[0]
        if (app)
            Launcher.openApp(app.name, app.command, app.icon)
        else
            openFolder(folder)
    }

    function openFolder(location) {
        Qt.openUrlExternally(StandardPaths.writableLocation(location))
    }

    function activateCurrent() {
        if (inControls) {
            Launcher.run(mediaControls[control].command)    // the guide stays open
            return
        }
        const row = atSelectMusic ? selectMusic : current.rows[list.currentIndex]
        if (!row.run)
            return                              // not built yet
        if (row.dashboard && gameTitle !== "") {
            askToQuit(row.run)                  // over a game: quit it first
            return
        }
        if (row.asks) {
            row.run()                           // it asks first, in the Guide
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
        question = ["Quit " + gameTitle + "?", "Any unsaved progress will be lost.",
                    "Yes, quit and go to Xbox Home", "No, back to the game"]
        afterQuit = () => { Launcher.closeGame(); then() }
        ask()
    }

    // "Close <app>?" - closed the way its X would, so it can save (or ask)
    function askToClose() {
        question = ["Close " + appTitle + "?", "It's closed like clicking its X, so it can save first.",
                    "Yes, close it and go to Xbox Home", "No, back to " + appTitle]
        afterQuit = () => { Launcher.closeApp(); guide.tabRequested(1) }
        ask()
    }

    function ask() {
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
                onTriggered: clock.text = Preferences.time(new Date())
            }
        }

        // The blades: the current one's rows (and media buttons) in the white
        // panel, and a strip for each
        Item {
            id: bladeArea
            x: 300; y: 304
            width: 1320; height: 471

            transform: Translate { id: bladeShift }
            NumberAnimation { id: slideIn; target: bladeShift; property: "x"; to: 0; duration: 200; easing.type: Easing.OutCubic }

            Rectangle {                             // the white panel again, so the picture of the blade is solid
                x: base.x - bladeArea.x
                width: base.width; height: base.height
                gradient: base.gradient
            }

            Item {
                id: panel
                x: 342
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

                    delegate: GuideRow {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        label: modelData.label
                        icon: modelData.icon || ""
                        image: modelData.image || ""
                        selected: ListView.isCurrentItem && !guide.inControls && !guide.atSelectMusic && !guide.switching
                        onClicked: {
                            guide.inControls = false
                            guide.atSelectMusic = false
                            list.currentIndex = index
                            guide.activateCurrent()
                        }
                    }

                    // Off the bottom of the Media blade's rows: Select Music, then the buttons
                    Keys.onDownPressed: (event) => {
                        if (guide.atSelectMusic) {
                            guide.atSelectMusic = false
                            guide.inControls = true
                        } else if (guide.inControls) {
                            return
                        } else if (currentIndex < count - 1) {
                            currentIndex++
                        } else if (guide.current.media) {
                            guide.atSelectMusic = true
                        }
                    }
                    Keys.onUpPressed: (event) => {
                        if (guide.inControls) {
                            guide.inControls = false
                            guide.atSelectMusic = true
                        } else if (guide.atSelectMusic) {
                            guide.atSelectMusic = false
                        } else if (currentIndex > 0) {
                            currentIndex--
                        }
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
                        } else if (event.key === Qt.Key_X) {
                            guide.close()
                            guide.signOutRequested()
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
                        label: guide.selectMusic.label
                        selected: guide.atSelectMusic && !guide.switching
                        onClicked: {
                            guide.inControls = false
                            guide.atSelectMusic = true
                            guide.activateCurrent()
                        }
                    }

                    Row {
                        x: 14
                        Repeater {
                            model: guide.mediaControls
                            Rectangle {
                                required property int index
                                required property var modelData
                                width: 117; height: 82
                                readonly property bool selected: guide.inControls && guide.control === index && !guide.switching
                                color: selected ? "#008E00" : "transparent"

                                TileIcon {
                                    anchors.centerIn: parent
                                    width: 40; height: 40
                                    name: modelData.icon
                                    color: parent.selected ? "white" : "#3A4246"
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
                                        guide.atSelectMusic = false
                                        guide.control = index
                                        guide.activateCurrent()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // One strip per blade
            Repeater {
                model: guide.blades
                Rectangle {
                    id: strip
                    required property int index
                    required property var modelData
                    readonly property bool isCurrent: index === guide.tab

                    x: guide.stripX(index) - bladeArea.x
                    width: isCurrent ? 95 : 67
                    height: 471

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
                        onClicked: guide.goToBlade(strip.index)
                    }
                }
            }
        }

        // The old blade, fading away over the new one
        Image {
            id: before
            x: bladeArea.x; y: bladeArea.y
            width: bladeArea.width; height: bladeArea.height
            source: guide.oldBlade ? guide.oldBlade.url : ""
            visible: guide.oldBlade !== null

            NumberAnimation on opacity {
                id: crossFade
                running: false
                from: 1; to: 0
                duration: 25
                onFinished: guide.oldBlade = null
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
                text: guide.question[0] || ""
                color: "#111111"
                font.pixelSize: 40
                elide: Text.ElideRight
            }
            Text {
                x: 32; y: 90
                text: guide.question[1] || ""
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
                model: [guide.question[2] || "", guide.question[3] || ""]

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