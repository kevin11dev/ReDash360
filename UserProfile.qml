pragma Singleton
import QtQuick
import QtCore

// You: gamertag, gamerpic, avatar and the rest of your gamer card, shared by
// every screen and saved in ReDash360.conf under [profile]
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

    // The big animated one on the Social tab; "" = none
    readonly property string avatar: saved.avatar

    // The rest of the gamer card, all optional, like on the 360
    readonly property string motto: saved.motto
    readonly property string realName: saved.realName
    readonly property string place: saved.place           // "Location" on the 360
    readonly property string bio: saved.bio
    readonly property string zone: saved.zone !== "" ? saved.zone : "Recreation"

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

    // The login screen shows your gamerpic and avatar too (loginscreen.cpp)
    function shareWithLogin() {
        LoginScreen.share(gamerpic, avatar)
    }
    onGamerpicChanged: Qt.callLater(shareWithLogin)
    onAvatarChanged: Qt.callLater(shareWithLogin)
    Component.onCompleted: Qt.callLater(shareWithLogin)

    // "motto", "realName", "place", "bio" or "zone"
    function setDetail(field, value) {
        saved[field] = value.trim()
    }

    property Settings saved: Settings {
        category: "profile"
        property string gamertag                // empty = the computer's user name
        property string gamerpic                // image file/URL, empty = letter tile
        property string avatar                  // image file/URL, empty = none
        property string motto
        property string realName
        property string place                   // not "location": Settings has one of its own
        property string bio
        property string zone                    // empty = Recreation
    }
}