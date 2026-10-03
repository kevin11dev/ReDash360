import QtQuick

TilePage {
    id: root
    cellHeight: 292

    Tile{                                       //System
        id: systemTile
        label: "System"
        column: 0; row: 0
        focus: true
        KeyNavigation.right: profileTile
        KeyNavigation.down: networkTile
        onActivated: console.log("System")
    }

    Tile{                                       //Network
        id: networkTile
        label: "Network"
        column: 0; row: 1
        focus: true
        KeyNavigation.right: displaySoundTile
        KeyNavigation.up: systemTile
        onActivated: console.log("Network")
    }

    Tile{                                       //Profile
        id: profileTile
        label: "Profile"
        column: 1; row: 0
        focus: true
        KeyNavigation.right: preferencesTile
        KeyNavigation.down: displaySoundTile
        onActivated: console.log("Profile")
    }

    Tile{                                       //Display & Sound
        id: displaySoundTile
        label: "Display & Sound"
        column: 1; row: 1
        focus: true
        KeyNavigation.right: storageTile
        KeyNavigation.up: profileTile
        onActivated: console.log("Display & Sound")
    }

    Tile{                                       //Preferences
        id: preferencesTile
        label: "Preferences"
        column: 2; row: 0
        focus: true
        KeyNavigation.right: controllersTile
        KeyNavigation.down: storageTile
        onActivated: console.log("Preferences")
    }

    Tile{                                       //Display & Sound
        id: storageTile
        label: "Display & Sound"
        column: 2; row: 1
        focus: true
        KeyNavigation.right: turnOffTile
        KeyNavigation.up: preferencesTile
        onActivated: console.log("Display & Sound")
    }

    Tile{                                       //Controllers
        id: controllersTile
        label: "Controllers"
        column: 3; row: 0
        focus: true
        KeyNavigation.left: preferencesTile
        KeyNavigation.down: turnOffTile
        onActivated: console.log("Controllers")
    }

    Tile{                                       //Turn Off
        id: turnOffTile
        label: "Turn Off"
        column: 3; row: 1
        focus: true
        KeyNavigation.left: storageTile
        KeyNavigation.up: controllersTile
        onActivated: console.log("Turn Off")
    }
}