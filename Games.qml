import QtQuick

TilePage {
    id: root
    cellWidth: 247

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
        onActivated: console.log("Browse Games")
    }

    Tile{                                       //Search Games
        id: searchGamesTile
        label: "Search Games"
        icon: "search"
        column: 0; row: 2
        onActivated: console.log("Search Games")
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
        icon: "plus"
        column: 1; row: 2
        onActivated: console.log("Add-ons")
    }

    Tile{                                       //Demos
        id: demosTile
        label: "Demos"
        icon: "download"
        column: 2; row: 2
        onActivated: console.log("Demos")
    }

    Tile{                                       //Recommended
        id: recomendedTile
        label: "Recommended"
        icon: "star"
        column: 3; row: 2
        columnSpan: 2
        onActivated: console.log("Recommended")
    }
}