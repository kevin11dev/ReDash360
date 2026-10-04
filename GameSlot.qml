import QtQuick
import QtCore

Tile {
    id: slot

    required property string slotId

    signal pickRequested()

    readonly property bool hasGame: saved.command !== ""

    label: hasGame ? saved.name : "Choose a Game"
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
    }

    Settings{
        id: saved
        category: "gameSlot_" + slot.slotId
        property string name
        property string command
        property string cover
    }
}
