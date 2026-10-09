import QtQuick

TilePage {
    id: root

    Tile{                                       //Friends
        id: friendsTile
        label: "Friends"
        icon: "person"
        column: 0; row: 0
        focus: true
        onActivated: console.log("Friends")
    }

    Tile{                                       //My Profile
        id: myProfileTile
        label: "My Profile"
        icon: "account"
        column: 0; row: 1
        onActivated: root.profileRequested()
    }

    Tile{                                       //Sign In or Out
        id: signInOutTile
        label: "Sign In or Out"
        icon: "signin"
        column: 0; row: 2
        onActivated: console.log("Sign In or Out")
    }

    Column {
        x: 340; y: 30
        spacing: 2

        Text{
            text: UserProfile.gamertag
            color: "white"
            font.pixelSize: 44
        }

        Text{
            text: GameLibrary.count + (GameLibrary.count === 1 ? " game" : " games")
            color: "white"
            opacity: 0.8
            font.pixelSize: 30
        }
    }

    AnimatedImage{
        id: avatar
        x: 360; y: 150
        width: 420; height: 500
        source: UserProfile.avatar
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        smooth: implicitWidth * 2 > width
        asynchronous: true
        playing: visible
    }

    TileIcon{
        x: 420; y: 260
        width: 300; height: 300
        name: "person"
        opacity: 0.3
        visible: UserProfile.avatar === ""
    }
}