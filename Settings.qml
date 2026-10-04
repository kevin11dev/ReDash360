import QtQuick

TilePage {
    id: root
    cellHeight: 292

    Tile{                                       //System
        id: systemTile
        label: "System"
        column: 0; row: 0
        focus: true
        onActivated: console.log("System")
    }

    Tile{                                       //Network
        id: networkTile
        label: "Network"
        column: 0; row: 1
        focus: true
        onActivated: console.log("Network")
    }

    Tile{                                       //Profile
        id: profileTile
        label: "Profile"
        column: 1; row: 0
        focus: true
        onActivated: console.log("Profile")
    }

    Tile{                                       //Display & Sound
        id: displaySoundTile
        label: "Display & Sound"
        column: 1; row: 1
        focus: true
        onActivated: console.log("Display & Sound")
    }

    Tile{                                       //Preferences
        id: preferencesTile
        label: "Preferences"
        column: 2; row: 0
        focus: true
        onActivated: console.log("Preferences")
    }

    Tile{                                       //Display & Sound
        id: storageTile
        label: "Display & Sound"
        column: 2; row: 1
        focus: true
        onActivated: console.log("Display & Sound")
    }

    Tile{                                       //Controllers
        id: controllersTile
        label: "Controllers"
        column: 3; row: 0
        focus: true
        onActivated: console.log("Controllers")
    }

    Tile{                                       //Turn Off
        id: turnOffTile
        label: "Turn Off"
        column: 3; row: 1
        focus: true
        onActivated: console.log("Turn Off")
    }
}