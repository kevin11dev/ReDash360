import QtQuick

TilePage {
    id: root

    Tile{                                       //Open Tray
        id: openTrayTile
        readonly property bool hasGame: Launcher.lastCommand !== ""
        readonly property var game: {
            GameLibrary.count
            return hasGame ? GameLibrary.find(Launcher.lastCommand) : {}
        }
        label: hasGame ? "Play " + Launcher.lastName : "Open Tray"
        icon: art.visible ? "" : "disc"
        hints: hasGame ? [{button: "Y", label: "Eject"}] : []
        column: 0; row: 0
        focus: true
        onActivated:{
            if(hasGame)
                Launcher.play(Launcher.lastName, Launcher.lastCommand)
        }
        onYPressed: Launcher.eject()
        Image{
            id: art
            anchors.fill: parent
            visible: status === Image.Ready
            readonly property var choices: [
                openTrayTile.game.hero,
                openTrayTile.game.cover,
                openTrayTile.game.banner
            ].filter(url=>url)
            property int tried: 0
            onChoicesChanged: tried = 0
            source: tried < choices.length ? choices[tried] : ""
            onStatusChanged:{
                if(status === Image.Error)
                    tried++
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: width
        }
        Rectangle{
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 90
            visible: art.visible
            gradient: Gradient{
                GradientStop{position: 0.0; color: "#00000000"}
                GradientStop{position: 1.0; color: "#b0000000"}
            }
        }
        TileIcon{
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            width: 52; height: 52
            name: "disc"
            visible: art.visible
        }
    }

    Tile{                                       //Pins
        id: pinsTile
        label: "My Pins"
        icon: "pin"
        column: 0; row: 1
        onActivated: root.pinsRequested()
    }

    Tile{                                       //Recents
        id: recentsTile
        label: "Recents"
        icon: "clock"
        column: 0; row: 2
        onActivated: root.recentsRequested()
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