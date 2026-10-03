import QtQuick

FocusScope {
    id: root
    signal tabRequested(int index)

        Item {
            id: grid
            width: 4 * 310 + 3 * 4
            height: 3 * 150 + 2 * 4
            anchors.centerIn: parent

            Tile{                                       //Open Tray
                id: openTrayTile
                label: "Open Tray"
                column: 0; row: 0
                focus: true
                KeyNavigation.right: newsTile
                KeyNavigation.down: pinsTile
                onActivated: console.log("Open Tray")
            }

            Tile{                                       //Pins
                id: pinsTile
                label: "My Pins"
                column: 0; row: 1
                KeyNavigation.right: newsTile
                KeyNavigation.up: openTrayTile
                KeyNavigation.down: recentsTile
                onActivated: console.log("My Pins")
            }

            Tile{                                       //Recents
                id: recentsTile
                label: "Recents"
                column: 0; row: 2
                KeyNavigation.right: mediaTile
                KeyNavigation.up: pinsTile
                onActivated: console.log("Recents")
            }

            Tile{                                       //News
                id: newsTile
                label: "News"
                column: 1; row: 0
                columnSpan: 2; rowSpan: 2
                KeyNavigation.down: mediaTile
                KeyNavigation.left: openTrayTile
                 KeyNavigation.right: searchTile
                onActivated: console.log("News")
            }

            Tile{                                       //Media
                id: mediaTile
                label: "Media"
                column: 1; row: 2
                KeyNavigation.right: appsTile
                KeyNavigation.left: recentsTile
                KeyNavigation.up: newsTile
                onActivated: root.tabRequested(4)
            }

            Tile{                                       //Apps
                id: appsTile
                label: "Apps"
                column: 2; row: 2
                KeyNavigation.right: gamesTile
                KeyNavigation.left: mediaTile
                KeyNavigation.up: newsTile
                onActivated: root.tabRequested(5)
            }

            Tile{                                       //Search
                id: searchTile
                label: "Search"
                column: 3; row: 0
                KeyNavigation.left: newsTile
                KeyNavigation.down: settingsTile
                onActivated: root.tabRequested(0)
            }

            Tile{                                       //Settings
                id: settingsTile
                label: "Settings"
                column: 3; row: 1
                KeyNavigation.left: newsTile
                KeyNavigation.up: searchTile
                KeyNavigation.down: gamesTile
                onActivated: root.tabRequested(6)
            }

            Tile{                                       //Games
                id: gamesTile
                label: "Games"
                column: 3; row: 2
                KeyNavigation.left: appsTile
                KeyNavigation.up: settingsTile
                onActivated: root.tabRequested(3)
            }
    }
}