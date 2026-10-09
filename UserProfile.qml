pragma Singleton
import QtQuick
import QtCore

QtObject{
    id: me

    readonly property string userName: {
        const home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        return home.substring(home.lastIndexOf("/") + 1)
    }

    readonly property string gamertag: saved.gamertag !== "" ? saved.gamertag : userName

    readonly property string avatar: saved.avatar

    readonly property string gamerpic: saved.gamerpic !== "" ? saved.gamerpic : saved.avatar

    readonly property string avatarFolder:
        StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/ReDash360/avatars"

    function setGamertag(name){
        saved.gamertag = name.trim()
    }

    function setAvatar(file) {
        saved.avatar = file
    }

    property Settings saved: Settings{
        category: "profile"
        property string gamertag
        property string gamerpic
        property string avatar
    }
}
