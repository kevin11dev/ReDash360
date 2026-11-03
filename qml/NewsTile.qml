import QtQuick

// Home's big News tile, like the 360's spotlight: it takes turns showing
// what's new in your Steam games, stories from your news site (Settings >
// Preferences > News Site) and a game from your library to play. A opens the
// one showing, Y lists them all.
Tile {
    id: tile

    signal allNewsRequested(var cards, int index)

    label: cards.length > 0 ? "" : "News"
    icon: cards.length > 0 ? "" : "globe"
    hints: cards.length > 0 ? [{ button: "Y", label: "All News" }] : []

    // What the tile shows, in turn: a game's news, a story, and so on, with
    // today's game from your library in among them. Game news older than two
    // months is left to All News.
    readonly property var cards: {
        const now = Date.now()
        const games = News.items.filter(item => item.kind === "game" && now - item.time < 60 * day).slice(0, 6)
        const stories = News.items.filter(item => item.kind === "site").slice(0, 6)
        const list = []
        for (let i = 0; i < Math.max(games.length, stories.length); i++) {
            if (i < games.length)
                list.push(games[i])
            if (i < stories.length)
                list.push(stories[i])
        }
        const pick = todaysPick()
        if (pick)
            list.splice(Math.min(2, list.length), 0, pick)
        return list
    }

    // Everything for All News: the tile's cards first, then the older news
    readonly property var everything: {
        const shown = cards.map(card => card.url)
        return cards.concat(News.items.filter(item => shown.indexOf(item.url) < 0))
    }

    readonly property int day: 24 * 60 * 60 * 1000
    property int current: 0
    onCardsChanged: if (current >= cards.length) current = 0

    onActivated: open(cards[current])
    onYPressed: if (cards.length > 0) allNewsRequested(everything, current)

    function open(card) {
        if (!card)
            return
        if (card.kind === "pick")
            Launcher.play(card.title, card.command)
        else
            Qt.openUrlExternally(card.url)
    }

    // A game from your library, a different one each day: one you haven't
    // started from the dashboard yet, if there are any
    function todaysPick() {
        GameLibrary.count                       // choose again after a rescan
        const played = Launcher.recents.map(recent => recent.command)
        const all = GameLibrary.all()
        const unplayed = all.filter(game => played.indexOf(game.command) < 0)
        const choices = unplayed.length > 0 ? unplayed : all
        if (choices.length === 0)
            return null
        const game = choices[Math.floor(Date.now() / day) % choices.length]
        return { kind: "pick", title: game.name, source: "From your library", label: "", time: 0,
                 url: game.command, command: game.command, image: game.hero || game.banner || game.cover,
                 summary: unplayed.length > 0 ? "You haven't played this from the dashboard yet."
                                              : "One to come back to." }
    }

    // ---- Looking for news ------------------------------------------------------

    // Your Steam games, the ones you've played lately first
    function steamGames() {
        const played = Launcher.recents.map(recent => recent.command)
        const games = []
        for (const game of GameLibrary.all()) {
            const appid = (/rungameid\/(\d+)/.exec(game.command) || [])[1]
            if (game.source === "Steam" && appid)
                games.push({ appid: appid, name: game.name, image: game.hero || game.banner || game.cover,
                             played: played.indexOf(game.command) })
        }
        games.sort((a, b) => (a.played < 0) - (b.played < 0) || a.played - b.played || a.name.localeCompare(b.name))
        return games
    }

    function refresh() {
        const site = Preferences.newsSite
        News.refresh(steamGames(), site.url, site.name)
    }

    // When the dashboard starts, then every hour
    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tile.refresh()
    }

    Connections {
        target: Preferences
        function onNewsSiteChanged() { tile.refresh() }
    }

    Connections {
        target: GameLibrary
        function onCountChanged() { Qt.callLater(tile.refresh) }
    }

    // A new card every 8 seconds
    Timer {
        interval: 8000
        running: tile.cards.length > 1 && Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: tile.current = (tile.current + 1) % tile.cards.length
    }

    // ---- What's on it ------------------------------------------------------------

    Repeater {
        model: tile.cards

        delegate: Item {
            id: card
            required property int index
            required property var modelData

            anchors.fill: parent
            clip: true
            opacity: index === tile.current ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 500 } }

            Image {
                id: picture
                anchors.fill: parent
                source: card.modelData.image || ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 720
                asynchronous: true
            }

            TileIcon {                          // no picture (offline): a globe on the green
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -60
                width: 96; height: 96
                name: "globe"
                visible: picture.status !== Image.Ready
            }

            Rectangle {                         // dark at the bottom, so the words stay readable
                anchors.bottom: parent.bottom
                width: parent.width; height: 240
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#D0000000" }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                spacing: 6

                Text {
                    width: parent.width
                    text: card.modelData.source + (card.modelData.time ? " · " + News.ago(card.modelData.time) : "")
                    color: "#E0FFFFFF"
                    font.pixelSize: 22
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: card.modelData.title
                    color: "white"
                    font.pixelSize: 32
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    lineHeight: 0.95
                }
            }
        }
    }

    // Which card it's on
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 6
        visible: tile.cards.length > 1
        Repeater {
            model: tile.cards.length
            Rectangle {
                required property int index
                width: 10; height: 10
                color: "white"
                opacity: index === tile.current ? 1 : 0.4
            }
        }
    }
}