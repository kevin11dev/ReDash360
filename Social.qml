import QtQuick

TilePage {
    id: root

    // Coming to this tab (or back from a game) reads Steam's files again,
    // so achievements you just unlocked show up
    onActiveFocusChanged: if (activeFocus) Achievements.refresh()

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

        // Your achievement count; without Steam (or on Windows) your game count
        Text{
            text: Achievements.total > 0
                  ? Achievements.total + (Achievements.total === 1 ? " achievement" : " achievements")
                  : GameLibrary.count + (GameLibrary.count === 1 ? " game" : " games")
            color: "white"
            opacity: 0.8
            font.pixelSize: 30
        }
    }

    // Your 9 newest achievements, newest top left, like the 360's
    Grid {
        id: achievementGrid
        x: 342; y: 135
        columns: 3
        spacing: 5
        visible: Achievements.total > 0

        Repeater{
            model: 9

            Rectangle{
                id: slot
                required property int index
                readonly property var achievement: Achievements.recent[index]

                width: 54; height: 54
                color: "#33ffffff"              // empty slot, or while the icon downloads

                Image{
                    id: icon
                    anchors.fill: parent
                    source: slot.achievement ? slot.achievement.icon : ""
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // No internet: the icons come from Steam's servers, so show a star
                TileIcon{
                    anchors.centerIn: parent
                    width: 28; height: 28
                    name: "star"
                    opacity: 0.5
                    visible: slot.achievement !== undefined && icon.status !== Image.Ready
                }
            }
        }
    }

    AnimatedImage{
        id: avatar
        x: achievementGrid.visible ? 525 : 360
        y: achievementGrid.visible ? 40 : 150
        width: achievementGrid.visible ? 340 : 420
        height: achievementGrid.visible ? 560 : 500
        source: UserProfile.avatar
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        smooth: implicitWidth * 2 > width
        asynchronous: true
        playing: visible
    }

    TileIcon{
        x: avatar.x + (avatar.width - 300) / 2
        y: avatar.y + avatar.height - 340
        width: 300; height: 300
        name: "person"
        opacity: 0.3
        visible: UserProfile.avatar === ""
    }
}