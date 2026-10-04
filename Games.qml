import QtQuick

TilePage {
    id: root
    cellWidth: 247

    Tile{                                       //My Games
        id: myGamesTile
        label: "My Games"
        column: 0; row: 0
        focus: true
        onActivated: root.shelfRequested()
    }

    Tile{                                       //Browse Games
        id: browseGamesTile
        label: "Browse Games"
        column: 0; row: 1
        onActivated: console.log("Browse Games")
    }

    Tile{                                       //Search Games
        id: searchGamesTile
        label: "Search Games"
        column: 0; row: 2
        onActivated: console.log("Search Games")
    }

    GameSlot{                                       //Game 1
        id: game1Tile
        label: "Game 1"
        column: 1; row: 0
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    GameSlot{                                       //Game 2
        id: game2Tile
        label: "Game 2"
        column: 3; row: 0
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    GameSlot{                                       //Game 3
        id: game3Tile
        label: "Game 3"
        column: 1; row: 1
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    GameSlot{                                       //Game 4
        id: game4Tile
        label: "Game 4"
        column: 3; row: 1
        columnSpan: 2
        onPickRequested: root.pickGameRequested(game => setGame(game))
    }

    Tile{                                       //Add-ons
        id: addOnsTile
        label: "Add-ons"
        column: 1; row: 2
        onActivated: console.log("Add-ons")
    }

    Tile{                                       //Demos
        id: demosTile
        label: "Demos"
        column: 2; row: 2
        onActivated: console.log("Demos")
    }

    Tile{                                       //Recommended
        id: recomendedTile
        label: "Recommended"
        column: 3; row: 2
        columnSpan: 2
        onActivated: console.log("Recommended")
    }
}