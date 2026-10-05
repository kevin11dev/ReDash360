import QtQuick
import QtCore

// The signed-in profile in the top-right corner, laid out like the 2012
// dashboard: a small gamerpic with one line of text to its left. Every
// 6 seconds the text changes: gamertag -> stats -> nothing -> gamertag ...
Item {
    id: profile
    width: 400                  // room for the text; the picture sits at the right edge
    height: 57
    opacity: 0.88

    // Saved in the settings under [profile]; leave empty to use the defaults
    Settings {
        id: saved
        category: "profile"
        property string gamertag        // empty = the computer's user name
        property string gamerpic        // image file/URL, empty = letter tile
    }

    // "file:///home/kevin" or "file:///C:/Users/kevin" -> "kevin"
    readonly property string userName: {
        const home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        return home.substring(home.lastIndexOf("/") + 1)
    }

    readonly property string gamertag: saved.gamertag !== "" ? saved.gamertag : userName
    readonly property string gamerpic: saved.gamerpic

    // Which text is showing: 0 = gamertag, 1 = stats, 2 = none (just the picture)
    property int showing: 0

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: profile.showing = (profile.showing + 1) % 3
    }

    // Gamerpic: the saved picture, or the gamertag's first letter on a green tile
    Rectangle {
        id: pic
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 46
        color: "#107C10"

        Text {
            anchors.centerIn: parent
            text: profile.gamertag.charAt(0).toUpperCase()
            color: "white"
            font.pixelSize: 28
        }

        Image {
            anchors.fill: parent
            source: saved.gamerpic
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Text {
        anchors.right: pic.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: profile.gamertag
        color: "white"
        font.pixelSize: 28
        opacity: profile.showing === 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 280 } }
    }

    Text {
        anchors.right: pic.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: GameLibrary.count + (GameLibrary.count === 1 ? " game" : " games")
        color: "white"
        font.pixelSize: 27
        opacity: profile.showing === 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 280 } }
    }
}