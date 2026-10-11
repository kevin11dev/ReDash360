import QtQuick
import QtMultimedia
import Qt.labs.folderlistmodel

// One player for every .wav in the sounds folder, found by name ("move" plays
// move.wav). Files you add or remove while it's running are picked up too.
QtObject {
    id: bank

    property string folder

    property var players: ({})

    function play(name) {
        const player = players[name]
        if (player && player.status === SoundEffect.Ready)
            player.play()
    }

    property Instantiator files: Instantiator {
        model: FolderListModel {
            folder: bank.folder
            nameFilters: ["*.wav"]
            showDirs: false
            caseSensitive: false
        }

        delegate: SoundEffect {
            required property string fileBaseName
            required property url fileUrl
            source: fileUrl
        }

        onObjectAdded: (index, player) => bank.players[player.fileBaseName.toLowerCase()] = player
        onObjectRemoved: (index, player) => delete bank.players[player.fileBaseName.toLowerCase()]
    }
}