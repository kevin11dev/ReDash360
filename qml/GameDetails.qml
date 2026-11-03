import QtQuick

// Game Details, like the 360's (X on a game in My Games): the game's art
// behind everything, its name top right, and tabs (overview, details,
// gallery) that slide across with LB / RB. For Steam games the details and
// screenshots come from Steam's store page, so they need the internet.
FocusScope {
    id: gameDetails
    visible: false

    property Item returnFocusTo: null
    property var game: ({})                     // {name, source, command, cover, banner, hero}

    // Steam's store data for this game once it arrives, and how that's going:
    // "" (not a Steam game), "loading", "ready", "none" (Steam has no page
    // for it) or "failed" (no internet)
    property var store: null
    property string storeState: ""
    property string storeAddress: "https://store.steampowered.com/api/appdetails?l=english&appids={id}"

    readonly property string appId: {
        const match = /rungameid\/(\d+)/.exec(game.command || "")
        return match ? match[1] : ""
    }
    readonly property var achievements: Achievements.games.find(g => g.appId === appId) || null

    property int tab: 0
    readonly property var tabs: ["overview", "details", "gallery"]

    signal achievementsRequested(string appId)

    function open(chosen) {
        returnFocusTo = Window.activeFocusItem
        game = chosen
        tab = 0
        store = null
        gallery.currentIndex = 0
        fullscreen.visible = false
        visible = true
        playTile.forceActiveFocus()
        fadeIn.restart()
        loadStore()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function showTab(index) {
        tab = Math.max(0, Math.min(tabs.length - 1, index))
        if (tab === 0)
            playTile.forceActiveFocus()
        else if (tab === 1)
            about.forceActiveFocus()
        else
            gallery.forceActiveFocus()
    }

    function play() {
        close()
        Launcher.play(game.name, game.command)
    }

    // ---- Steam's store page ----------------------------------------------

    function loadStore() {
        if (appId === "") {
            storeState = ""
            return
        }
        storeState = "loading"
        const id = appId
        const request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || id !== gameDetails.appId)
                return
            try {
                const entry = JSON.parse(request.responseText)[id]
                if (entry && entry.success) {
                    store = entry.data
                    storeState = "ready"
                } else {
                    storeState = "none"
                }
                return
            } catch (error) {}
            storeState = "failed"
        }
        request.open("GET", storeAddress.replace("{id}", id))
        request.send()
    }

    // Steam writes its texts as web pages: keep the words, lose the rest
    function plainText(html) {
        return (html || "")
            .replace(/<br\s*\/?>/gi, "\n").replace(/<\/(p|li|h\d)>/gi, "\n").replace(/<li>/gi, "• ")
            .replace(/<[^>]*>/g, "")
            .replace(/&quot;/g, "\"").replace(/&#0?39;|&apos;/g, "'").replace(/&nbsp;/g, " ")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&#(\d+);/g, (match, code) => String.fromCharCode(code))
            .replace(/&amp;/g, "&")
            .replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim()
    }

    readonly property var categories: store && store.categories ? store.categories.map(c => c.description) : []
    function has(names) {
        return names.some(name => categories.indexOf(name) >= 0)
    }

    // Steam's features, split like the 360's capabilities: what works on
    // this PC, then everything that goes through the internet
    readonly property var localNames: ["Single-player", "Shared/Split Screen", "Shared/Split Screen PvP",
        "Shared/Split Screen Co-op", "Full controller support", "Partial Controller Support",
        "Captions available", "HDR available", "Includes level editor", "Commentary available",
        "VR Supported", "VR Only", "Tracked Controller Support"]
    readonly property var localFeatures: categories.filter(name => localNames.indexOf(name) >= 0)
    readonly property var onlineFeatures: categories.filter(name => localNames.indexOf(name) < 0)

    readonly property var screenshots: {
        if (store && store.screenshots && store.screenshots.length > 0)
            return store.screenshots.map(shot => shot.path_full)
        const art = game.hero || game.banner || game.cover
        return art ? [art] : []
    }

    // The lines under the big picture on the overview
    readonly property var facts: {
        const lines = [{ text: (game.source || "PC") + " Game" }]
        if (!store)
            return lines
        if (store.genres && store.genres.length > 0)
            lines.push({ text: store.genres[0].description })
        const multiplayer = has(["Online PvP"]) ? "Online" : has(["Shared/Split Screen PvP"]) ? "Local"
                          : has(["Multi-player", "PvP"]) ? "Yes" : "None"
        const coop = has(["Online Co-op"]) ? "Online" : has(["Shared/Split Screen Co-op"]) ? "Local"
                   : has(["Co-op"]) ? "Yes" : "None"
        lines.push({ icon: "person", text: "Multiplayer: " + multiplayer })
        lines.push({ icon: "person", text: "Co-op: " + coop })
        if (store.controller_support === "full" || has(["Full controller support"]))
            lines.push({ icon: "controller", text: "Full controller support" })
        else if (has(["Partial Controller Support"]))
            lines.push({ icon: "controller", text: "Partial controller support" })
        return lines
    }

    // What the details tab says when there's nothing from Steam
    readonly property string missing: storeState === "loading" ? "Getting this game's details from Steam..."
                                    : storeState === "failed" ? "Couldn't reach Steam. Connect to the internet to see this game's details."
                                    : storeState === "none" ? "Steam doesn't have any details for this game."
                                    : "Details are only available for Steam games."

    // ---- What's on screen ------------------------------------------------

    NumberAnimation { id: fadeIn; target: gameDetails; property: "opacity"; from: 0; to: 1; duration: 200 }

    Keys.onEscapePressed: close()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Q) {           // LB
            showTab(tab - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_E) {    // RB
            showTab(tab + 1)
            event.accepted = true
        }
    }

    // Stops the mouse reaching the screen underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // The game's art, darkened so the words stay readable
    Rectangle {
        anchors.fill: parent
        color: "#1E1F22"
    }
    Image {
        id: art
        anchors.fill: parent
        source: gameDetails.store && gameDetails.store.background_raw ? gameDetails.store.background_raw
                : gameDetails.game.hero || gameDetails.game.banner || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.55
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 145
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 152
        width: 1000
        horizontalAlignment: Text.AlignRight
        text: gameDetails.game.name || ""
        color: "white"
        font.pixelSize: 54
        elide: Text.ElideRight
    }

    // overview  details  gallery
    Row {
        x: 230
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 211
        spacing: 61
        Repeater {
            model: gameDetails.tabs
            Text {
                required property int index
                required property string modelData
                text: modelData
                color: "white"
                opacity: index === gameDetails.tab ? 1 : 0.45
                font.pixelSize: 48
                font.weight: Font.Light
                MouseArea {
                    anchors.fill: parent
                    onClicked: gameDetails.showTab(parent.index)
                }
            }
        }
    }

    // The three tabs side by side; the strip slides so the current one is in
    // front, with the next one peeking in at the right edge
    Item {
        id: strip
        y: 272
        width: parent.width; height: 600
        x: -gameDetails.tab * 1458
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // ---- overview ----
        Item {
            id: overview
            x: 250
            width: 1458; height: parent.height
            opacity: gameDetails.tab === 0 ? 1 : 0.5

            DetailTile {
                id: playTile
                x: 0; y: 0
                label: "Play Now"
                KeyNavigation.right: pinTile
                KeyNavigation.down: achievementsTile.visible ? achievementsTile : null
                onActivated: gameDetails.play()
            }
            DetailTile {
                id: pinTile
                x: 229; y: 0
                label: Pins.isPinned(gameDetails.game.command) ? "Unpin" : "Pin to Home"
                icon: "pin"
                KeyNavigation.left: playTile
                KeyNavigation.right: pictureTile
                KeyNavigation.down: achievementsTile.visible ? achievementsTile : null
                onActivated: Pins.toggle({ kind: "game", name: gameDetails.game.name, command: gameDetails.game.command })
            }
            DetailTile {
                id: achievementsTile
                x: 0; y: 153
                visible: gameDetails.achievements !== null
                label: "Achievements"
                icon: "star"
                note: gameDetails.achievements ? gameDetails.achievements.unlocked + " of "
                                                 + gameDetails.achievements.total : ""
                KeyNavigation.up: playTile
                KeyNavigation.right: pictureTile
                onActivated: gameDetails.achievementsRequested(gameDetails.appId)
            }

            // The big picture: a screenshot (or the game's art); opens the gallery
            DetailTile {
                id: pictureTile
                x: 456; y: 0
                width: 362; height: 296
                KeyNavigation.left: pinTile
                Keys.onRightPressed: gameDetails.showTab(1)
                onActivated: gameDetails.showTab(2)

                Image {
                    anchors.centerIn: parent
                    width: parent.width; height: width * 9 / 16
                    source: gameDetails.screenshots.length > 0 ? gameDetails.screenshots[0] : ""
                    sourceSize.width: 724
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                TileIcon {                      // no pictures of this game
                    anchors.centerIn: parent
                    width: 96; height: 96
                    name: "controller"
                    visible: gameDetails.screenshots.length === 0
                }
            }

            Column {
                x: 456; y: 326
                spacing: 6
                Repeater {
                    model: gameDetails.facts
                    Row {
                        required property var modelData
                        spacing: 14
                        TileIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40
                            visible: (parent.modelData.icon || "") !== ""
                            name: parent.modelData.icon || ""
                        }
                        Text {
                            text: parent.modelData.text
                            color: "white"
                            font.pixelSize: 34
                        }
                    }
                }
            }

            Text {
                x: 840; y: 6
                width: 590
                text: gameDetails.store ? gameDetails.plainText(gameDetails.store.short_description) : ""
                color: "white"
                font.pixelSize: 30
                lineHeight: 1.1
                wrapMode: Text.WordWrap
                maximumLineCount: 13
                elide: Text.ElideRight
            }
        }

        // ---- details ----
        FocusScope {
            id: about
            x: 1458 + 312
            width: 1458; height: parent.height
            opacity: gameDetails.tab === 1 ? 1 : 0.5

            Keys.onLeftPressed: gameDetails.showTab(0)
            Keys.onRightPressed: gameDetails.showTab(2)
            Keys.onUpPressed: description.contentY = Math.max(0, description.contentY - 135)
            Keys.onDownPressed: description.contentY = Math.min(Math.max(0, description.contentHeight - description.height),
                                                                description.contentY + 135)

            Text {
                width: 1300
                visible: !gameDetails.store
                text: gameDetails.missing
                color: "white"
                font.pixelSize: 34
                wrapMode: Text.WordWrap
            }

            Column {
                visible: gameDetails.store !== null
                spacing: 38
                Fact { heading: "Developer"; value: gameDetails.store && gameDetails.store.developers ? gameDetails.store.developers.join(", ") : "" }
                Fact { heading: "Publisher"; value: gameDetails.store && gameDetails.store.publishers ? gameDetails.store.publishers.join(", ") : "" }
                Fact { heading: "Genre"; value: gameDetails.store && gameDetails.store.genres ? gameDetails.store.genres.map(g => g.description).join(", ") : "" }
                Fact { heading: "Release Date"; value: gameDetails.store && gameDetails.store.release_date ? gameDetails.store.release_date.date : "" }
            }

            Column {
                x: 330
                width: 310; height: 540
                clip: true
                spacing: 45
                visible: gameDetails.store !== null
                Features { heading: "Local Capabilities"; headingColor: "#8CD43C"; names: gameDetails.localFeatures }
                Features { heading: "Online Capabilities"; headingColor: "#F2B835"; names: gameDetails.onlineFeatures }
            }

            Flickable {
                id: description
                x: 660
                width: 640; height: 540
                visible: gameDetails.store !== null
                clip: true
                contentHeight: aboutText.height
                Behavior on contentY { NumberAnimation { duration: 150 } }

                Text {
                    id: aboutText
                    width: parent.width
                    text: gameDetails.store ? gameDetails.plainText(gameDetails.store.about_the_game
                                                                    || gameDetails.store.short_description) : ""
                    color: "white"
                    font.pixelSize: 34
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 45                  // 12 whole lines fit
                    wrapMode: Text.WordWrap
                }
            }

            TileIcon {                          // more to read further down
                x: description.x + description.width - 30
                y: description.y + description.height + 10
                width: 28; height: 28
                name: "chevron"
                visible: description.visible && !description.atYEnd
            }
        }

        // ---- gallery ----
        ListView {
            id: gallery
            x: 2 * 1458 + 429
            y: -22
            width: 1061; height: 597
            orientation: ListView.Horizontal
            spacing: 40
            clip: false
            interactive: false
            highlightMoveDuration: 250
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: width
            opacity: gameDetails.tab === 2 ? 1 : 0.5
            model: gameDetails.screenshots

            delegate: Rectangle {
                required property int index
                required property string modelData
                width: 1061; height: 597
                color: "#30FFFFFF"
                opacity: index === gallery.currentIndex ? 1 : 0.4
                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: parent.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Keys.onLeftPressed: currentIndex > 0 ? decrementCurrentIndex() : gameDetails.showTab(1)
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onReturnPressed: fullscreen.show()
            Keys.onEnterPressed: fullscreen.show()
        }

        Text {
            x: gallery.x; y: 6
            visible: gallery.count === 0
            text: "There aren't any pictures of this game."
            color: "white"
            font.pixelSize: 34
            opacity: gallery.opacity
        }

        Text {                                  // "2 of 9" under the picture
            anchors.right: gallery.right
            anchors.top: gallery.bottom
            anchors.topMargin: 10
            visible: gameDetails.tab === 2 && gallery.count > 1
            text: (gallery.currentIndex + 1) + " of " + gallery.count
            color: "white"
            font.pixelSize: 30
        }
    }

    Row {
        x: 138; y: 973
        spacing: 30
        ButtonHint {
            button: "A"
            label: gameDetails.tab === 2 ? "View Fullscreen" : "Select"
            visible: gameDetails.tab !== 1 && !(gameDetails.tab === 2 && gallery.count === 0)
        }
        ButtonHint { button: "B"; label: "Back" }
    }

    // A screenshot on the whole screen; left / right for the others, A or B to go back
    FocusScope {
        id: fullscreen
        anchors.fill: parent
        visible: false

        function show() {
            if (gallery.count === 0)
                return
            visible = true
            forceActiveFocus()
        }
        function hide() {
            visible = false
            gallery.forceActiveFocus()
        }

        Keys.onEscapePressed: hide()
        Keys.onReturnPressed: hide()
        Keys.onEnterPressed: hide()
        Keys.onLeftPressed: gallery.decrementCurrentIndex()
        Keys.onRightPressed: gallery.incrementCurrentIndex()

        Rectangle {
            anchors.fill: parent
            color: "black"
        }
        Image {
            anchors.fill: parent
            source: gameDetails.screenshots[gallery.currentIndex] || ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        MouseArea {
            anchors.fill: parent
            onClicked: fullscreen.hide()
        }
    }

    // A small tile like the 360's: its name bottom left, a little icon top right
    component DetailTile: Rectangle {
        id: tile
        property string label
        property string icon
        property string note                    // small text top left ("35 of 63")
        signal activated()

        width: 218; height: 143
        color: "#009000"
        scale: activeFocus ? 1.07 : 1.0
        z: activeFocus ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()

        TileIcon {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            width: 40; height: 40
            name: tile.icon
        }
        Text {
            x: 14; y: 10
            visible: tile.note !== ""
            text: tile.note
            color: "white"
            font.pixelSize: 26
        }
        Text {
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: parent.width - 28
            text: tile.label
            color: "white"
            font.pixelSize: 30
            fontSizeMode: Text.HorizontalFit        // "Achievements" fits
            minimumPixelSize: 24
            elide: Text.ElideRight
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) tile.forceActiveFocus()
            onClicked: {
                tile.forceActiveFocus()
                tile.activated()
            }
        }
    }

    // "Developer" over "Ubisoft"
    component Fact: Column {
        property string heading
        property string value
        visible: value !== ""
        Text {
            text: parent.heading
            color: "white"
            font.pixelSize: 34
            font.weight: Font.DemiBold
            lineHeightMode: Text.FixedHeight
            lineHeight: 45
        }
        Text {
            width: 300
            text: parent.value
            color: "white"
            font.pixelSize: 34
            lineHeightMode: Text.FixedHeight
            lineHeight: 45
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // "Local Capabilities" in colour, then the features under it
    component Features: Column {
        property string heading
        property color headingColor
        property var names: []
        width: 310
        visible: names.length > 0
        Text {
            width: parent.width
            text: parent.heading
            color: parent.headingColor
            font.pixelSize: 34
            lineHeightMode: Text.FixedHeight
            lineHeight: 45
            wrapMode: Text.WordWrap
        }
        Repeater {
            model: parent.names
            Text {
                required property string modelData
                width: 310
                text: modelData
                color: "white"
                font.pixelSize: 34
                lineHeightMode: Text.FixedHeight
                lineHeight: 45
                wrapMode: Text.WordWrap
            }
        }
    }
}