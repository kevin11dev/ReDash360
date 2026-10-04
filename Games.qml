import QtQuick

TilePage {
    id: root
    cellWidth: 247

    Tile{                                       //My Games
        id: myGamesTile
        label: "My Games"
        column: 0; row: 0
        focus: true
        onActivated: console.log("My Games")
    }

    Tile{                                       //Browse Games
        id: browseGamesTile
        label: "Browse Games"
        column: 0; row: 1
        focus: true
        onActivated: console.log("Browse Games")
    }

    Tile{                                       //Search Games
        id: searchGamesTile
        label: "Search Games"
        column: 0; row: 2
        focus: true
        onActivated: console.log("Search Games")
    }

    Tile{                                       //Game 1
        id: game1Tile
        label: "Game1"
        column: 1; row: 0
        columnSpan: 2
        focus: true
        onActivated: console.log("Game1")
    }

    Tile{                                       //Game 2
        id: game2Tile
        label: "Game2"
        column: 3; row: 0
        columnSpan: 2
        focus: true
        onActivated: console.log("Game2")
    }

    Tile{                                       //Game 3
        id: game3Tile
        label: "Game3"
        column: 1; row: 1
        columnSpan: 2
        focus: true
        onActivated: console.log("Game3")
    }

    Tile{                                       //Game 4
        id: game4Tile
        label: "Game4"
        column: 3; row: 1
        columnSpan: 2
        focus: true
        onActivated: console.log("Game4")
    }

    Tile{                                       //Add-ons
        id: addOnsTile
        label: "Add-ons"
        column: 1; row: 2
        focus: true
        onActivated: console.log("Add-ons")
    }

    Tile{                                       //Demos
        id: demosTile
        label: "Demos"
        column: 2; row: 2
        focus: true
        onActivated: console.log("Demos")
    }

    Tile{                                       //Recommended
        id: recomendedTile
        label: "Recommended"
        column: 3; row: 2
        columnSpan: 2
        focus: true
        onActivated: console.log("Recommended")
    }
}