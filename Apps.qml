import QtQuick

TilePage {
    id: root
    cellWidth: 247

    Tile{                                       //My Apps
        id: myAppsTile
        label: "My Apps"
        icon: "apps"
        column: 0; row: 0
        focus: true
        onActivated: console.log("My Apps")
    }

    Tile{                                       //Browse Apps
        id: browseAppsTile
        label: "Browse Apps"
        icon: "bag"
        column: 0; row: 1
        focus: true
        onActivated: console.log("Browse Apps")
    }

    Tile{                                       //Search Apps
        id: searchAppsTile
        label: "Search Apps"
        icon: "search"
        column: 0; row: 2
        focus: true
        onActivated: console.log("Search Apps")
    }

    Tile{                                       //Featured Apps
        id: featuredAppsTile
        label: "Featured Apps"
        column: 1; row: 0
        columnSpan: 2; rowSpan: 2
        focus: true
        onActivated: console.log("Featured Apps")
    }

    Tile{                                       //App 1
        id: app1Tile
        label: "App1"
        column: 3; row: 0
        focus: true
        onActivated: console.log("App1")
    }

    Tile{                                       //App 2
        id: app2Tile
        label: "App2"
        column: 4; row: 0
        focus: true
        onActivated: console.log("App2")
    }

    Tile{                                       //App 3
        id: app3Tile
        label: "App3"
        column: 3; row: 1
        focus: true
        onActivated: console.log("App3")
    }

    Tile{                                       //App 4
        id: app4Tile
        label: "App4"
        column: 4; row: 1
        focus: true
        onActivated: console.log("App4")
    }

    Tile{                                       //App 5
        id: app5Tile
        label: "App5"
        column: 1; row: 2
        focus: true
        onActivated: console.log("App5")
    }

    Tile{                                       //App 6
        id: app6Tile
        label: "App6"
        column: 2; row: 2
        focus: true
        onActivated: console.log("App6")
    }

    Tile{                                       //App 7
        id: app7Tile
        label: "App7"
        column: 3; row: 2
        focus: true
        onActivated: console.log("App7")
    }

    Tile{                                       //App 8
        id: app8Tile
        label: "App8"
        column: 4; row: 2
        focus: true
        onActivated: console.log("App8")
    }
}