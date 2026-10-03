import QtQuick

TilePage {
    id: root
    cellWidth: 247

    Tile{                                       //My Video Apps
        id: myVideoAppsTile
        label: "My Video Apps"
        column: 0; row: 0
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Browse Video
        id: browseVideoTile
        label: "Browse TV & Movies"
        column: 0; row: 1
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Search Video
        id: searchVideoTile
        label: "Search TV & Movies"
        column: 0; row: 2
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Xbox Video
        id: xboxVideoTile
        label: "Xbox Video"
        column: 1; row: 0
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Get Your TV App
        id: getTVTile
        label: "Get Your TV App"
        column: 1; row: 1
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Sales & Specials Video
        id: salesSpecialsTile
        label: "Sales & Specials"
        column: 1; row: 2
        columnSpan: 2
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Categories
        id: categoriesTile
        label: "Categories"
        column: 3; row: 2
        columnSpan: 2
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Featured
        id: featuredTile
        label: "Featured"
        column: 2; row: 0
        columnSpan: 2; rowSpan: 2
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //New TV
        id: newTVTile
        label: "New TV"
        column: 4; row: 0
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }

    Tile{                                       //Latest Films
        id: latestFilmsTile
        label: "Latest Films"
        column: 4; row: 1
        focus: true
        KeyNavigation.down: browseAppsTile
        KeyNavigation.right: featuredAppsTile
        onActivated: console.log("My Video Apps")
    }
}