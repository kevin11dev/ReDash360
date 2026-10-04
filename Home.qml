import QtQuick

TilePage {
    id: root

    Tile{                                       //Open Tray
        id: openTrayTile
        label: Launcher.lastName !== "" ? Launcher.lastName : "Open Tray"
        hints: [{button: "Y", label: "Eject"}]
        column: 0; row: 0
        focus: true
        onActivated: {
            if(Launcher.lastCommand !== "")
                Launcher.play(Launcher.lastName, Launcher.lastCommand)
        }
    }

    Tile{                                       //Pins
        id: pinsTile
        label: "My Pins"
        column: 0; row: 1
        onActivated: console.log("My Pins")
    }

    Tile{                                       //Recents
        id: recentsTile
        label: "Recents"
        column: 0; row: 2
        onActivated: console.log("Recents")
    }

    Tile{                                       //News
        id: newsTile
        label: "News"
        column: 1; row: 0
        columnSpan: 2; rowSpan: 2
        onActivated: console.log("News")
    }

    Tile{                                       //Media
        id: mediaTile
        label: "Media"
        column: 1; row: 2
        onActivated: root.tabRequested(4)
    }

    Tile{                                       //Apps
        id: appsTile
        label: "Apps"
        column: 2; row: 2
        onActivated: root.tabRequested(5)
    }

    Tile{                                       //Search
        id: searchTile
        label: "Search"
        column: 3; row: 0
        onActivated: root.tabRequested(0)
    }

    Tile{                                       //Settings
        id: settingsTile
        label: "Settings"
        column: 3; row: 1
        onActivated: root.tabRequested(6)
    }

    Tile{                                       //Games
        id: gamesTile
        label: "Games"
        column: 3; row: 2
        onActivated: root.tabRequested(3)
    }
}