import QtQuick
import QtCore

TilePage {
    id: root

    Tile{                                       //My Video Apps
        id: myVideoAppsTile
        label: "My Video Apps"
        icon: "play"
        column: 0; row: 0
        focus: true
        onActivated: root.appListRequested("my video apps", AppLibrary.videoApps())
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

    AppSlot{                                    //Video App 1
        id: videoApp1Tile
        slotId: "Video1"
        emptyLabel: "Add Video App"
        column: 3; row: 0
        onPickRequested: root.pickAppRequested("choose an app", AppLibrary.all(), app => setApp(app))
    }

    AppSlot{                                    //Video App 2
        id: videoApp2Tile
        slotId: "Video2"
        emptyLabel: "Add Video App"
        column: 3; row: 1
        onPickRequested: root.pickAppRequested("choose an app", AppLibrary.all(), app => setApp(app))
    }

    AppSlot{                                    //Video App 3
        id: videoApp3Tile
        slotId: "Video3"
        emptyLabel: "Add Video App"
        column: 3; row: 2
        onPickRequested: root.pickAppRequested("choose an app", AppLibrary.all(), app => setApp(app))
    }
}