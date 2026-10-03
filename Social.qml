import QtQuick

TilePage {
    id: root

    Tile{                                       //Friends
        id: friendsTile
        label: "Friends"
        column: 0; row: 0
        focus: true
        KeyNavigation.down: avatarStoreTile
        onActivated: console.log("Friends")
    }

    Tile{                                       //Avatar Store
        id: avatarStoreTile
        label: "Avatar Store"
        column: 0; row: 1
        focus: true
        KeyNavigation.up: friendsTile
        KeyNavigation.down: signInOutTile
        onActivated: console.log("Avatar Store")
    }

    Tile{                                       //Sign In or Out
        id: signInOutTile
        label: "Sign In or Out"
        column: 0; row: 2
        focus: true
        KeyNavigation.up: avatarStoreTile
        onActivated: console.log("Sign In or Out")
    }
}