import QtQuick

// games: every game you have, the Steam store, a search, four slots for the
// games you play most (Y on a slot chooses its game), add-ons (emulators and
// other apps for gaming) and what Steam recommends for you
TilePage {
    id: root
    cellWidth: 247

    // A page of the Steam store: in Steam if you have it, otherwise in your browser
    function openSteamStore(page) {
        const url = "https://store.steampowered.com/" + page
        const hasSteam = GameLibrary.all().some(game => game.source === "Steam")
        Qt.openUrlExternally(hasSteam ? "steam://openurl/" + url : url)
    }

    Tile{                                       //My Games
        id: myGamesTile
        label: "My Games"
        icon: "controller"
        column: 0; row: 0
        focus: true
        onActivated: root.shelfRequested()
    }

    Tile{                                       //Browse Games
        id: browseGamesTile
        label: "Browse Games"
        icon: "bag"
        column: 0; row: 1
        onActivated: root.openSteamStore("")
    }

    Tile{                                       //Search Games
        id: searchGamesTile
        label: "Search Games"
        icon: "search"
        column: 0; row: 2
        onActivated: root.gameSearchRequested()
    }

    GameSlot{                                       //Game 1
        id: game1Tile
        slotId: "Game1"
        column: 1; row: 0
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    GameSlot{                                       //Game 2
        id: game2Tile
        slotId: "Game2"
        column: 3; row: 0
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    GameSlot{                                       //Game 3
        id: game3Tile
        slotId: "Game3"
        column: 1; row: 1
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    GameSlot{                                       //Game 4
        id: game4Tile
        slotId: "Game4"
        column: 3; row: 1
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    Tile{                                       //Add-ons
        id: addOnsTile
        label: "Add-ons"
        icon: "download"
        column: 1; row: 2
        columnSpan: 2
        onActivated: root.addOnsRequested()
    }

    Tile{                                       //Recommended
        id: recomendedTile
        label: "Recommended"
        icon: "star"
        column: 3; row: 2
        columnSpan: 2
        onActivated: root.openSteamStore("explore/")    // your Discovery Queue
    }
}