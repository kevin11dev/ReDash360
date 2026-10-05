import QtQuick

TilePage {
    id: root

    Tile{                                       //Open Tray
        id: openTrayTile
        label: Launcher.lastName !== "" ? Launcher.lastName : "Open Tray"
        icon: "disc"
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
        icon: "pin"
        column: 0; row: 1
        onActivated: console.log("My Pins")
    }

    Tile{                                       //Recents
        id: recentsTile
        label: "Recents"
        icon: "clock"
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
        icon: "play"
        column: 1; row: 2
        onActivated: root.tabRequested(4)
    }

    Tile{                                       //Apps
        id: appsTile
        label: "Apps"
        icon: "apps"
        column: 2; row: 2
        onActivated: root.tabRequested(5)
    }

    Tile{                                       //Search
        id: searchTile
        label: "Search"
        icon: "search"
        column: 3; row: 0
        onActivated: root.tabRequested(0)
    }

    Tile{                                       //Settings
        id: settingsTile
        label: "Settings"
        icon: "gear"
        column: 3; row: 1
        onActivated: root.tabRequested(6)
    }

    Tile{                                       //Games
        id: gamesTile
        label: "Games"
        icon: "controller"
        column: 3; row: 2
        onActivated: root.tabRequested(3)
    }
}