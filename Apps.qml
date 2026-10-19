import QtQuick
import QtCore

// apps: every app you have, your PC's app store, a search, YouTube, your
// music apps and videos, and six slots for the apps you use most (Y on a
// slot chooses its app)
TilePage {
    id: root
    cellWidth: 247

    // Your PC's app store: the first one it has (Discover on KDE), the
    // Microsoft Store on Windows, or Flathub in the browser
    function openStore() {
        if (Qt.platform.os === "windows") {
            Qt.openUrlExternally("ms-windows-store://home")
            return
        }
        const store = AppLibrary.all().find(app =>
            /plasma-discover|gnome-software|bazaar|pamac-manager|octopi|mintinstall/i.test(app.command))
        if (store)
            Launcher.openApp(store.name, store.command, store.icon)
        else
            Qt.openUrlExternally("https://flathub.org")
    }

    Tile{                                       //My Apps
        id: myAppsTile
        label: "My Apps"
        icon: "apps"
        column: 0; row: 0
        focus: true
        onActivated: root.appsRequested()
    }

    Tile{                                       //Browse Apps
        id: browseAppsTile
        label: "Browse Apps"
        icon: "bag"
        column: 0; row: 1
        onActivated: root.openStore()
    }

    Tile{                                       //Search Apps
        id: searchAppsTile
        label: "Search Apps"
        icon: "search"
        column: 0; row: 2
        onActivated: root.appSearchRequested()
    }

    Tile{                                       //YouTube
        id: youtubeTile
        label: "YouTube"
        icon: "tv"
        iconSize: 120
        column: 1; row: 0
        columnSpan: 2; rowSpan: 2
        onActivated: Qt.openUrlExternally("https://www.youtube.com")
    }

    Tile{                                       //Music
        id: musicTile
        label: "Music"
        icon: "music"
        column: 1; row: 2
        onActivated: root.appListRequested("my music apps", AppLibrary.musicApps())
    }

    Tile{                                       //My Videos
        id: myVideosTile
        label: "My Videos"
        icon: "folder"
        column: 2; row: 2
        onActivated: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.MoviesLocation))
    }

    // The six app slots: the two columns on the right
    Repeater{
        model: [[3, 0], [4, 0], [3, 1], [4, 1], [3, 2], [4, 2]]

        delegate: AppSlot{
            required property int index
            required property var modelData
            slotId: "App" + (index + 1)
            column: modelData[0]; row: modelData[1]
            onPickRequested: root.pickAppRequested("choose an app", AppLibrary.all(), app => setApp(app))
        }
    }
}