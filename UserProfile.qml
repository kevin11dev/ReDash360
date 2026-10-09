pragma Singleton
import QtQuick
import QtCore

// You: gamertag, gamerpic and avatar, shared by every screen and saved in
// ReDash360.conf under [profile]
QtObject {
    id: me

    // "file:///home/kevin" or "file:///C:/Users/kevin" -> "kevin"
    readonly property string userName: {
        const home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        return home.substring(home.lastIndexOf("/") + 1)
    }

    readonly property string gamertag: saved.gamertag !== "" ? saved.gamertag : userName

    // The small picture next to your gamertag; "" = your first letter on green
    readonly property string gamerpic: saved.gamerpic

    // The big animated one on the Social tab and My Profile; "" = none
    readonly property string avatar: saved.avatar

    // ~/.local/share/ReDash360, with the avatars/ and gamerpics/ folders in it
    readonly property string dataFolder:
        StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/ReDash360"

    function setGamertag(name) {
        saved.gamertag = name.trim()            // empty = back to your user name
    }

    function setGamerpic(file) {
        saved.gamerpic = file
    }

    function setAvatar(file) {
        saved.avatar = file
    }

    property Settings saved: Settings {
        category: "profile"
        property string gamertag                // empty = the computer's user name
        property string gamerpic                // image file/URL, empty = letter tile
        property string avatar                  // image file/URL, empty = none
    }
}