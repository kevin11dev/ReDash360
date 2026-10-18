import QtQuick
import QtCore

Tile {
    id: slot

    required property string slotId

    signal pickRequested()

    readonly property bool hasGame: saved.command !== ""

    label: hasGame ? saved.name : "Choose a Game"
    color: art.visible ? "transparent" : "#009000"     // no green showing round the picture
    hints: [{button: "Y", label: hasGame ? "Change Game" : "Choose Game"}]

    onActivated: {
        if(hasGame)
            Launcher.play(saved.name, saved.command)
        else
            pickRequested()
    }
    onYPressed: pickRequested()

    function setGame(game) {
        saved.name = game.name
        saved.command = game.command
        saved.cover = game.cover
        saved.banner = game.banner
        art.bannerFailed = false
    }

    // The game's art, behind the name. Inset by the border width so the
    // white focus border stays visible on top of the picture.
    Image {
        id: art
        anchors.fill: parent
        visible: slot.hasGame && status === Image.Ready
        // Wide banner if the game has one, otherwise the tall cover (cropped)
        // (and the cover too if the banner fails to load)
        property bool bannerFailed: false
        source: !slot.hasGame ? ""
              : (saved.banner !== "" && !bannerFailed) ? saved.banner
              : saved.cover
        onStatusChanged: {
            if (status === Image.Error && source == saved.banner)
                bannerFailed = true
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: width
    }

    // Dark strip so the white name stays readable on bright pictures
    Rectangle {
        anchors.left: art.left
        anchors.right: art.right
        anchors.bottom: art.bottom
        height: 56
        z: 1                                    // above the picture, below the name
        visible: art.visible
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#b0000000" }
        }
    }

    Settings{
        id: saved
        category: "gameSlot_" + slot.slotId
        property string name
        property string command
        property string cover
        property string banner
    }
}