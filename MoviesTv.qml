import QtQuick
import QtCore

TilePage {
    id: root

    // Installed video players (VLC, mpv, Jellyfin...); empty on Windows
    readonly property var videoApps: AppLibrary.videoApps()

    Tile{                                       //My Video Apps
        id: myVideoAppsTile
        label: "My Video Apps"
        icon: "play"
        column: 0; row: 0
        focus: true
        onActivated: root.appListRequested("my video apps", root.videoApps)
    }

    Tile{                                       //My Videos
        id: myVideosTile
        label: "My Videos"
        icon: "folder"
        column: 0; row: 1
        onActivated: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.MoviesLocation))
    }

    Tile{                                       //Music
        id: musicTile
        label: "Music"
        icon: "music"
        column: 0; row: 2
        onActivated: root.appListRequested("my music apps", AppLibrary.musicApps())
    }

    Tile{                                       //Continue Watching
        id: continueWatchingTile
        label: "Continue Watching"
        column: 1; row: 0
        columnSpan: 2; rowSpan: 2
        onActivated: console.log("Continue Watching: coming soon")
    }

    Tile{                                       //YouTube
        id: youtubeTile
        label: "YouTube"
        icon: "tv"
        column: 1; row: 2
        columnSpan: 2
        onActivated: Qt.openUrlExternally("https://www.youtube.com")
    }

    // Your first three video apps, with their own icons. Fewer installed: the
    // spare tiles hide themselves.
    VideoAppTile{ app: root.videoApps[0]; column: 3; row: 0 }
    VideoAppTile{ app: root.videoApps[1]; column: 3; row: 1 }
    VideoAppTile{ app: root.videoApps[2]; column: 3; row: 2 }

    component VideoAppTile: Tile {
        property var app                        // {name, command, icon} from AppLibrary
        visible: app !== undefined
        label: app ? app.name : ""
        icon: "play"                            // shown if the app has no icon
        image: app && app.icon !== "" ? "image://appicon/" + app.icon : ""
        onActivated: Launcher.run(app.command)
    }
}