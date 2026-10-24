import QtQuick
import QtQuick.Shapes
import Qt.labs.folderlistmodel

// Profile, laid out like the 360's (measured from a video of the console at
// 1920x1080): a white list on the left, your orange gamer card on the right,
// on black. Each choice opens the next list (Edit Profile, Gamer Picture...),
// B goes back one. View Games lists your Steam achievements, game by game.
// Typing (gamertag, motto...) uses the on-screen keyboard.
// Gamerpics and avatars are GIFs (or pictures) you put in
// ~/.local/share/ReDash360/gamerpics and .../avatars.
FocusScope {
    id: profileScreen
    visible: false

    property Item returnFocusTo: null

    // The lists you've gone through; the last one is on screen
    property var pages: []
    readonly property var page: pages.length > 0 ? pages[pages.length - 1] : ({title: "", rows: []})
    readonly property int rowHeight: page.rowHeight || 63
    readonly property var current: page.rows[list.currentIndex] || ({})

    function open() {
        returnFocusTo = Window.activeFocusItem
        Achievements.refresh()
        picker.visible = false
        keyboard.visible = false
        pages = [mainPage()]
        list.currentIndex = 0
        visible = true
        list.forceActiveFocus()
        openAnimation.restart()
    }

    // Straight to one game's achievements (from Game Details); B goes back there
    function openGame(appId) {
        open()
        const game = Achievements.games.find(g => g.appId === appId)
        if (game) {
            pages = [gamePage(game)]
            list.currentIndex = 0
        }
    }

    // Straight to your games' achievements (from the Guide)
    function openAchievements() {
        open()
        pages = [gamesPage()]
        list.currentIndex = 0
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function push(next, startIndex) {
        const remembered = pages.slice()
        remembered[remembered.length - 1].index = list.currentIndex   // to come back to
        pages = remembered.concat([next])
        list.currentIndex = startIndex || 0
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    function back() {
        if (pages.length <= 1) {
            close()
            return
        }
        pages = pages.slice(0, -1)
        list.currentIndex = page.index || 0
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    function activate(row) {
        if (!row || row.disabled)
            return
        if (row.edit)
            type(row.edit)
        else if (row.run)
            row.run()
    }

    function valueOf(field) {
        return field === "gamertag" ? UserProfile.gamertag : UserProfile[field]
    }

    // What the keyboard asks for each thing you can type, like the 360
    readonly property var fields: ({
        gamertag: { title: "Change Gamertag", maxLength: 15,
                    prompt: "Enter your new gamertag. Gamertags can be up to 15 characters long." },
        motto: { title: "Change Motto", maxLength: 21,
                 prompt: "Enter your motto. Mottos can be up to 21 characters long." },
        realName: { title: "Change Name", maxLength: 30, prompt: "Enter your name." },
        place: { title: "Change Location", maxLength: 40, prompt: "Enter where you're from." },
        bio: { title: "Change Bio", maxLength: 200, prompt: "Tell people a little about yourself." },
    })

    function type(field) {
        const info = fields[field]
        keyboard.open({ title: info.title, prompt: info.prompt, maxLength: info.maxLength,
                        text: valueOf(field), done: text => save(field, text) })
    }

    function save(field, text) {
        if (field === "gamertag")
            UserProfile.setGamertag(text)
        else
            UserProfile.setDetail(field, text)
    }

    // ---- The lists -------------------------------------------------------

    function mainPage() {
        return { title: "Profile", rows: [
            { label: "View Games", run: () => push(gamesPage()) },
            { label: "Edit Profile", run: () => push(editPage()) },
        ] }
    }

    function editPage() {
        return { title: "Edit Profile", rows: [
            { label: "Gamertag", edit: "gamertag" },
            { label: "Gamer Picture", run: () => push(gamerpicPage()) },
            { label: "Gamer Zone", run: () => push(zonePage(), zones.indexOf(UserProfile.zone)) },
            { label: "Motto", edit: "motto" },
            { label: "Avatar", run: () => push(avatarPage()) },
            { label: "Name", edit: "realName" },
            { label: "Location", edit: "place" },
            { label: "Bio", edit: "bio" },
        ] }
    }

    function gamerpicPage() {
        return { title: "Gamer Picture", rowHeight: 103, rows: [
            { label: "Change Gamer Picture", picture: "gamerpic",
              description: "Your gamer picture shows next to your gamertag all over the dashboard.",
              run: () => picker.open("Choose a Gamer Picture", "gamerpics", file => UserProfile.setGamerpic(file)) },
            { label: "Open Gamer Pictures Folder", icon: "folder",
              description: "Put GIF or PNG files in ~/.local/share/ReDash360/gamerpics to choose from them here.",
              run: () => Qt.openUrlExternally(UserProfile.dataFolder + "/gamerpics") },
        ] }
    }

    function avatarPage() {
        return { title: "Avatar", rowHeight: 103, rows: [
            { label: "Change Avatar", picture: "avatar",
              description: "Your avatar stands next to your gamer card on the Social tab.",
              run: () => picker.open("Choose an Avatar", "avatars", file => UserProfile.setAvatar(file)) },
            { label: "Open Avatars Folder", icon: "folder",
              description: "Put GIF or PNG files in ~/.local/share/ReDash360/avatars to choose from them here. Pixel art stays sharp.",
              run: () => Qt.openUrlExternally(UserProfile.dataFolder + "/avatars") },
        ] }
    }

    readonly property var zones: ["Recreation", "Pro", "Family", "Underground"]
    readonly property var zoneInfo: [
        "You play to have fun and relax.",
        "You play to win, and take it seriously.",
        "You like games everyone in the house can play.",
        "You play your own way, anything goes.",
    ]

    function zonePage() {
        return { title: "Gamer Zone", rows: zones.map((zone, i) => ({
            label: zone, description: zoneInfo[i],
            run: () => { UserProfile.setDetail("zone", zone); back() },
        })) }
    }

    // Every game with achievements, most recently played first
    function gamesPage() {
        const games = Achievements.games
        if (games.length === 0)
            return { title: "Achievements", wide: true, rowHeight: 103, rows: [
                { label: "No achievements yet", sub: "Play a Steam game that has achievements", disabled: true },
            ] }
        return { title: "Achievements", wide: true, rowHeight: 103, rows: games.map(game => ({
            label: game.name,
            sub: game.unlocked + " of " + game.total + " Achievements",
            image: GameLibrary.find("steam steam://rungameid/" + game.appId).cover || "",
            right: String(game.unlocked), badge: true,
            run: () => push(gamePage(game)),
        })) }
    }

    // One game's achievements: unlocked ones (newest first), then locked ones
    function gamePage(game) {
        return { title: game.name, wide: true, rowHeight: 103,
                 rows: Achievements.forGame(game.appId).map(a => {
            const secret = a.hidden && !a.unlocked
            return {
                label: secret ? "Secret Achievement" : a.name,
                sub: secret ? "Keep playing to unlock this secret achievement." : a.description,
                image: a.icon,
                right: a.unlocked ? Qt.formatDate(a.time, Locale.ShortFormat) : "Locked",
                dim: !a.unlocked,
            }
        }) }
    }

    // ---- What's on screen ------------------------------------------------

    Keys.onEscapePressed: back()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "black"
    }

    Item {
        id: stage
        anchors.fill: parent
        visible: !picker.visible

        Text {
            x: 352
            width: 925 - x - 24                 // stops before the gamerpic
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 107
            text: profileScreen.page.title
            color: "white"
            font.pixelSize: 38
            elide: Text.ElideRight
        }

        Gamerpic {
            x: 925; y: 55
            width: 70; height: 70
        }

        Text {
            id: clock
            anchors.right: parent.left
            anchors.rightMargin: -1559
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 107
            color: "white"
            font.pixelSize: 38

            Timer {
                interval: 10000
                running: profileScreen.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = Preferences.time(new Date())
            }
        }

        Item {
            id: panel
            x: 311; y: 137
            width: 1294; height: 787

            // Left: the list (the whole width for the achievement lists)
            Rectangle {
                width: profileScreen.page.wide ? parent.width : 646
                height: parent.height
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#F4FBFA" }
                    GradientStop { position: 1.0; color: "#D5DFE0" }
                }

                ListView {
                    id: list
                    width: parent.width
                    // Only whole rows, like the 360; the strip left under them
                    // shows a little arrow when there's more further down
                    height: Math.floor(parent.height / profileScreen.rowHeight) * profileScreen.rowHeight
                    clip: true
                    focus: true
                    keyNavigationEnabled: true
                    interactive: contentHeight > height
                    highlightMoveDuration: 0
                    model: profileScreen.page.rows
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: ListRow {}

                    Keys.onReturnPressed: profileScreen.activate(profileScreen.current)
                    Keys.onEnterPressed: profileScreen.activate(profileScreen.current)
                }

                TileIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (parent.height - list.height - height) / 2
                    width: 28; height: 28
                    name: "chevron"
                    color: "#555555"
                    visible: !list.atYEnd
                }
            }

            // Right: your gamer card, then your motto and the rest (or what
            // the highlighted choice does)
            Item {
                x: 646
                width: 648; height: parent.height
                visible: !profileScreen.page.wide

                Rectangle {
                    width: parent.width; height: 231
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#DCDEE2" }
                        GradientStop { position: 1.0; color: "#BDC6C9" }
                    }
                }
                Rectangle {
                    y: 231
                    width: parent.width; height: parent.height - y
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#838C8F" }
                        GradientStop { position: 1.0; color: "#596368" }
                    }
                }

                GamerCard { x: 21; y: 20 }

                Text {
                    x: 41; y: 262
                    width: parent.width - 2 * x
                    visible: text !== ""
                    text: profileScreen.current.description || ""
                    color: "white"
                    font.pixelSize: 36
                    lineHeight: 1.1
                    wrapMode: Text.WordWrap
                }

                Column {
                    x: 41; y: 262
                    width: parent.width - 2 * x
                    spacing: 26
                    visible: !profileScreen.current.description

                    Detail { text: UserProfile.motto }
                    Detail {
                        text: [UserProfile.realName, UserProfile.place].filter(t => t !== "").join("\n")
                    }
                    Detail { text: UserProfile.bio !== "" ? UserProfile.bio : "(No bio)" }
                }
            }

            // Like the 360's lists: the white panel grows out of the middle,
            // then the words fade in
            SequentialAnimation {
                id: openAnimation
                ParallelAnimation {
                    NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 150 }
                    NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
                    NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
                }
            }
        }

        Row {
            x: 352; y: 938
            spacing: 30
            ButtonHint {
                button: "A"
                label: "Select"
                visible: !profileScreen.current.disabled && (profileScreen.current.run !== undefined
                                                             || profileScreen.current.edit !== undefined)
            }
            ButtonHint { button: "B"; label: "Back" }
        }
    }

    // One row of a list: words (and a second line), maybe a picture on the
    // left and a number or date on the right
    component ListRow: Rectangle {
        id: row
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem
        readonly property bool hasPicture: modelData.image !== undefined || modelData.picture !== undefined
                                           || modelData.icon !== undefined
        readonly property color ink: selected ? "white" : (modelData.disabled ? "#9AA3A6" : "#222222")

        width: ListView.view.width
        height: profileScreen.rowHeight
        color: selected ? "#008E00" : "transparent"

        Rectangle {                             // the picture's square
            id: thumb
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: row.height - 13; height: width
            visible: row.hasPicture
            color: "#C5CDD0"

            Image {
                anchors.fill: parent
                source: row.modelData.image || ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(180, 180)
                asynchronous: true
                opacity: row.modelData.dim ? 0.6 : 1
            }
            Gamerpic {
                anchors.fill: parent
                visible: row.modelData.picture === "gamerpic"
            }
            AnimatedImage {
                anchors.fill: parent
                visible: row.modelData.picture === "avatar"
                source: visible ? UserProfile.avatar : ""
                fillMode: Image.PreserveAspectFit
                smooth: implicitWidth * 2 > width
                playing: visible
            }
            TileIcon {
                anchors.centerIn: parent
                width: parent.width * 0.7; height: width
                name: row.modelData.icon || ""
                color: "#333333"
            }
        }

        Column {
            x: row.hasPicture ? thumb.x + thumb.width + 13 : 41
            anchors.verticalCenter: parent.verticalCenter
            width: (rightText.visible ? rightText.x : row.width) - x - 20

            Text {
                width: parent.width
                text: row.modelData.label
                color: row.ink
                font.pixelSize: 36
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: (row.modelData.sub || "") !== ""
                text: row.modelData.sub || ""
                color: row.ink
                opacity: row.selected ? 1 : 0.85
                font.pixelSize: 32
                elide: Text.ElideRight
            }
        }

        Text {
            id: rightText
            anchors.right: parent.right
            anchors.rightMargin: row.modelData.badge ? 87 : 41
            anchors.verticalCenter: parent.verticalCenter
            visible: (row.modelData.right || "") !== ""
            text: row.modelData.right || ""
            color: row.ink
            font.pixelSize: 36
        }

        Badge {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            visible: row.modelData.badge === true
            color: row.selected ? "white" : "#222222"
        }

        // A thin grey line between two plain rows
        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !row.selected && row.index < list.count - 1 && list.currentIndex !== row.index + 1
            Rectangle { width: parent.width; height: 1; color: "#C9D0D2" }
            Rectangle { width: parent.width; height: 1; color: "#EEF3F4" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) list.currentIndex = row.index   // not with the controller
            onClicked: profileScreen.activate(row.modelData)
        }
    }

    // The orange gamer card: gamertag, gamerpic, and three lines about you
    component GamerCard: Item {
        width: 606; height: 191

        Rectangle {
            width: parent.width; height: 54
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#F86805" }
                GradientStop { position: 1.0; color: "#FE9000" }
            }
            Text {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                text: UserProfile.gamertag
                color: "white"
                font.pixelSize: 36
                elide: Text.ElideRight
            }
        }

        Gamerpic {
            y: 54
            width: 137; height: 137
        }

        Rectangle {
            x: 137; y: 54
            width: parent.width - x; height: 137
            color: "#F8F8F8"

            Column {
                x: 19; y: 6
                width: parent.width - 2 * x
                spacing: 0
                CardLine { label: "Games"; value: String(GameLibrary.count) }
                CardLine { label: "Achievements"; value: String(Achievements.total); badge: true }
                CardLine { label: "Zone"; value: UserProfile.zone }
            }
        }
    }

    component CardLine: Item {
        property string label
        property string value
        property bool badge: false
        width: parent.width; height: 42
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: "#222222"
            font.pixelSize: 34
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: parent.badge ? 46 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: "#222222"
            font.pixelSize: 34
        }
        Badge {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.badge
            color: "#222222"
        }
    }

    component Detail: Text {
        width: parent.width
        visible: text !== ""
        color: "white"
        font.pixelSize: 36
        lineHeight: 1.1
        wrapMode: Text.WordWrap
    }

    // The round achievements badge (a circle with a star cut out), like the
    // one on the Social tab
    component Badge: Item {
        id: badge
        property color color: "white"
        width: 30; height: 30
        Shape {
            anchors.centerIn: parent
            width: 48; height: 48
            scale: parent.width / 48
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: badge.color
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                PathSvg {
                    path: "M24,0 A24,24 0 1,1 24,48 A24,24 0 1,1 24,0 Z " +
                          "M24.0,12.3 L27.3,20.8 L36.4,21.3 L29.3,27.0 L31.6,35.9 " +
                          "L24.0,30.9 L16.4,35.9 L18.7,27.0 L11.6,21.3 L20.7,20.8 Z"
                }
            }
        }
    }

    // ---- Choosing a gamerpic or avatar -----------------------------------
    // Every GIF/picture in its folder, as tiles. A picks one, Y removes yours.
    FocusScope {
        id: picker
        anchors.fill: parent
        visible: false

        property string title
        property string folderName              // "gamerpics" or "avatars"
        property var choose: null               // function(file); "" = remove

        function open(title, folderName, choose) {
            picker.title = title
            picker.folderName = folderName
            picker.choose = choose
            visible = true
            grid.currentIndex = 0
            grid.forceActiveFocus()
        }

        function done() {
            visible = false
            list.forceActiveFocus()
        }

        function pick(file) {
            choose(file)
            done()
        }

        Keys.onEscapePressed: done()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Y) {
                pick("")
                event.accepted = true
            }
        }

        Text {
            x: 352
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 107
            text: picker.title
            color: "white"
            font.pixelSize: 38
        }

        Text {
            anchors.centerIn: parent
            visible: grid.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: "Put GIF or PNG files in\n~/.local/share/ReDash360/" + picker.folderName
            color: "white"
            font.pixelSize: 40
            font.weight: Font.Light
        }

        GridView {
            id: grid
            y: 280
            width: parent.width
            height: 2 * cellHeight

            flow: GridView.FlowTopToBottom
            cellWidth: 313                          // 287 tile + 26 gap, like my apps
            cellHeight: 293
            leftMargin: 195
            rightMargin: 195
            keyNavigationEnabled: true
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: 195
            preferredHighlightEnd: width - 500
            highlightMoveDuration: 200

            model: FolderListModel {
                folder: UserProfile.dataFolder + "/" + picker.folderName
                nameFilters: ["*.gif", "*.png", "*.webp", "*.jpg"]
                showDirs: false
            }

            function chooseCurrent() {
                if (count > 0)
                    picker.pick(model.get(currentIndex, "fileUrl").toString())
            }

            Keys.onReturnPressed: chooseCurrent()
            Keys.onEnterPressed: chooseCurrent()

            delegate: Rectangle {
                id: tile
                required property int index
                required property url fileUrl
                readonly property bool selected: GridView.isCurrentItem && grid.activeFocus

                width: 287; height: 287
                color: "#009000"
                scale: selected ? 1.08 : 1.0
                z: selected ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: 24
                    source: tile.fileUrl
                    fillMode: Image.PreserveAspectFit
                    smooth: implicitWidth * 2 > width
                    asynchronous: true
                    playing: visible
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        grid.currentIndex = tile.index
                        grid.chooseCurrent()
                    }
                }
            }
        }

        Row {
            x: 352; y: 938
            spacing: 30
            ButtonHint { button: "A"; label: "Choose"; visible: grid.count > 0 }
            ButtonHint { button: "B"; label: "Back" }
            ButtonHint { button: "Y"; label: "Remove" }
        }
    }

    // For typing your gamertag, motto, name, location and bio
    Keyboard {
        id: keyboard
        anchors.fill: parent
    }
}