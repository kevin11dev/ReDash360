import QtQuick
import QtCore

TilePage {
    id: root
    readonly property vatr videoApps: AppLibrary.videoApps()

    Tile{                                       //My Video Apps
        id: myVideoAppsTile
        label: "My Video Apps"
        icon: "play"
        column: 0; row: 0
        focus: true
        onActivated: root.appListRequested("my video apps", root.videoApps)
    }

    Tile{                                       //Browse Video
        id: browseVideoTile
        label: "My Videos"
        icon: "folder"
        column: 0; row: 1
        focus: true
        onActivated: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.MoviesLocation))
    }

    Tile{                                       //Music
        id: searchVideoTile
        label: "Music"
        icon: "search"
        column: 0; row: 2
        focus: true
        onActivated: root.appListRequested("my music apps", AppLibrary.musicApps())
    }

    Tile{                                       //Continue Watching
        id: xboxVideoTile
        label: "Continue Watching"
        column: 1; row: 0
        columnSpan: 2; rowSpan: 2
        focus: true
        onActivated: console.log("Continue Watching: coming soon")
    }

    Tile{                                       //YouTube
        id: getTVTile
        label: "Youtube"
        icon: "tv"
        column: 1; row: 2
        columnSpan: 2
        focus: true
        onActivated: Qt.openUrlExternally("https://www.youtube.com")
    }

    VideoAppTile{app: root.videoApps[0]; column: 3; row: 0}
    VideoAppTile{app: root.videoApps[1]; column: 3; row: 1}
    VideoAppTile{app: root.videoApps[2]; column: 3; row: 2}

    component VideoAppTile: Tile{
        property var app
        visible: app !== undefined
        label: app ? app.name : ""
        icon: "play"
        image: app && app.icon !== "" ? "image://appicon/" + app.icom : ""
        onActivated: launcher.run(app.command)
    }
}