import QtQuick

TilePage {
    id: root

    Tile{                                       //Open Tray
        id: openTrayTile
        readonly property bool hasGmae: Launcher.lastCommand !== ""
        readonly property var game: {
            GameLibrary.count
            return hasGame ? GameLibrary.find(Launcher.lastCommand) : {}
        }
        label: hasGame ? "Play " + Laucnher.lastName : "Open Tray"
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
            property bool bannerFailed: false
            readonly property string banner: openTrayTile.game.banner || ""
            readonly property string cover: openTrayTile.game.cover || ""
            source: banner !== "" && !bannerFailed ? banner : cover
            onStatusChanged:{
                if(status === Image.Error && source == banner)
                    bannerFailed = true
            }
            onBannerChanged: bannerFailed = false
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
        Rectangle{
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            width: 46; height: 46
            radius: 23
            color: "white"
            visible: art.visible

            Rectangle{
                anchors.centerIn: parent
                width: 16; height: 16
                radius: 8
                color: "transparent"

                Rectangle{
                    anchors.centerIn: parent
                    width: 6; height: 6
                    radius: 3
                    color: "white"
                }
            }
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