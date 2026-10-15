import QtQuick

TilePage {
    id: root
    cellHeight: 292

    Tile{                                       //System
        id: systemTile
        label: "System"
        icon: "console"
        column: 0; row: 0
        focus: true
        onActivated: root.systemRequested()
    }

    Tile{                                       //Network
        id: networkTile
        label: "Network"
        icon: "wifi"
        column: 0; row: 1
        onActivated: root.networkRequested()
    }

    Tile{                                       //Profile
        id: profileTile
        label: "Profile"
        icon: "account"
        column: 1; row: 0
        onActivated: root.profileRequested()
    }

    Tile{                                       //Display & Sound
        id: displaySoundTile
        label: "Display & Sound"
        icon: "tv"
        column: 1; row: 1
        onActivated: root.displaySoundRequested()
    }

    Tile{                                       //Preferences
        id: preferencesTile
        label: "Preferences"
        icon: "sliders"
        column: 2; row: 0
        onActivated: console.log("Preferences")
    }

    Tile{                                       //Storage
        id: storageTile
        label: "Storage"
        icon: "storage"
        column: 2; row: 1
        onActivated: root.storageRequested()
    }

    Tile{                                       //Controllers
        id: controllersTile
        label: "Controllers"
        icon: "controller"
        column: 3; row: 0
        onActivated: root.controllersRequested()
    }

    Tile{                                       //Turn Off
        id: turnOffTile
        label: "Turn Off"
        icon: "power"
        column: 3; row: 1
        onActivated: root.powerRequested()
    }
}