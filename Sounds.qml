pragma Singleton
import QtQuick

// The dashboard's sounds. Put WAV files in ~/.local/share/ReDash360/sounds named:
//   move.wav         moving between tiles, games and menu items
//   tab.wav          switching tabs (LB / RB)
//   select.wav       A
//   back.wav         B
//   guide-open.wav   the Guide opening
//   guide-close.wav  the Guide closing
// A missing file is just silence, so you can add them one at a time.
QtObject {
    id: sounds

    readonly property string folder: UserProfile.dataFolder + "/sounds"

    // How many sounds have played; lets a sound played on purpose (like the
    // Guide closing) win over the automatic one for the same key press
    property int played: 0

    function play(name) {
        played++
        if (bank)
            bank.play(name)
    }

    // The players live in SoundBank.qml, so a PC without Qt Multimedia only
    // loses the sounds instead of the whole dashboard
    property QtObject bank: null

    Component.onCompleted: {
        const component = Qt.createComponent("SoundBank.qml")
        if (component.status === Component.Ready)
            bank = component.createObject(sounds, { folder: Qt.binding(() => sounds.folder) })
        else
            console.warn("Sounds off, Qt Multimedia is missing:", component.errorString())
    }

    // Every key press, before the dashboard reacts to it. Once it has, play a
    // sound only if something actually changed: no "move" when you're already
    // at the edge, no "back" when there's nothing to go back from
    function keyPressed(window, key) {
        let name
        if (key === Qt.Key_Up || key === Qt.Key_Down || key === Qt.Key_Left || key === Qt.Key_Right)
            name = "move"
        else if (key === Qt.Key_Q || key === Qt.Key_E)
            name = "tab"
        else if (key === Qt.Key_Escape)
            name = "back"
        else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            play("select")
            return
        } else {
            return
        }

        const focusBefore = window.activeFocusItem
        const indexBefore = focusBefore ? focusBefore.currentIndex : undefined
        const playedBefore = played
        Qt.callLater(function() {
            if (played !== playedBefore)
                return                          // that key already made its own sound
            const focusNow = window.activeFocusItem
            const indexNow = focusNow ? focusNow.currentIndex : undefined
            if (focusNow !== focusBefore || indexNow !== indexBefore)
                play(name)
        })
    }

    property Connections keys: Connections {
        target: Pointer
        function onKeyPressed(window, key) { sounds.keyPressed(window, key) }
    }
}