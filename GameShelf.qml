import QtQuick

// My Games: its own screen, like on the 360. The dashboard fades away and
// the games appear as white cards on the same background. Up goes to the
// "show me" / "sort" headers, which open a menu of green tiles.
FocusScope {
    id: shelf
    visible: false

    property Item returnFocusTo: null

    // Picking mode: choose a game for a game slot instead of launching it
    property var pickCallback: null
    readonly property bool picking: pickCallback !== null

    // What's shown: a source ("Steam", ...) or "All Games", and the order
    property string filter: "All Games"
    property string sort: "A-Z"

    readonly property var filters: [
        { label: "All Games", icon: "apps" },
        { label: "Steam", icon: "controller" },
        { label: "Heroic", icon: "controller" },
        { label: "Faugus", icon: "controller" }
    ]
    readonly property var sorts: [
        { label: "A-Z", icon: "star" },
        { label: "Source", icon: "apps" }
    ]

    // The games to show: every game, filtered and sorted
    readonly property var games: {
        GameLibrary.count                       // build the list again after a rescan
        let list = GameLibrary.all()            // already sorted A-Z
        if (filter !== "All Games")
            list = list.filter(game => game.source === filter)
        if (sort === "Source")
            list.sort((a, b) => a.source.localeCompare(b.source))   // stays A-Z within each source
        return list
    }

    function open() {
        pickCallback = null
        show()
    }

    function pick(callback) {
        pickCallback = callback
        show()
    }

    function show() {
        returnFocusTo = Window.activeFocusItem
        menu.close()
        visible = true
        list.currentIndex = 0
        list.forceActiveFocus()
        fadeIn.restart()
    }

    function close() {
        visible = false
        pickCallback = null
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function activateCurrent() {
        const game = games[list.currentIndex]
        if (!game)
            return
        if (picking)
            pickCallback(game)                  // {name, source, command, cover, banner}
        else
            Launcher.play(game.name, game.command)
        close()
    }

    NumberAnimation { id: fadeIn; target: shelf; property: "opacity"; from: 0; to: 1; duration: 200 }

    // B anywhere on this screen (the menu handles its own B first)
    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // "show me" and "sort", top left
    HeaderButton {
        id: showMe
        x: 153; y: 152
        caption: "show me"
        value: shelf.filter.toLowerCase()
        KeyNavigation.right: sortBy
        KeyNavigation.down: list
        onActivated: menu.open(shelf.filters, label => shelf.filter = label, showMe)
    }

    HeaderButton {
        id: sortBy
        x: 541; y: 152
        caption: "sort"
        value: shelf.sort.toLowerCase()
        KeyNavigation.left: showMe
        KeyNavigation.down: list
        onActivated: menu.open(shelf.sorts, label => shelf.sort = label, sortBy)
    }

    // Title and "1 of 6", top right
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 145
        y: 118

        Text {
            anchors.right: parent.right
            text: shelf.picking ? "Choose a Game" : "My Games"
            color: "white"
            font.pixelSize: 52
        }
        Text {
            anchors.right: parent.right
            text: list.count > 0 ? (list.currentIndex + 1) + " of " + list.count : ""
            color: "white"
            font.pixelSize: 30
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: "No Games Found"
        color: "white"
        font.pixelSize: 40
        font.weight: Font.Light
    }

    ListView {
        id: list
        y: 250
        width: parent.width
        height: 640

        orientation: ListView.Horizontal
        spacing: 9
        leftMargin: 153
        rightMargin: 153
        model: shelf.games
        keyNavigationEnabled: true

        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 153
        preferredHighlightEnd: width - 500
        highlightMoveDuration: 200

        Keys.onReturnPressed: shelf.activateCurrent()
        Keys.onEnterPressed: shelf.activateCurrent()
        Keys.onUpPressed: showMe.forceActiveFocus()
        Keys.onPressed: (event) => {
            const game = shelf.games[currentIndex]
            if (event.key === Qt.Key_Y && game && !shelf.picking) {
                Pins.toggle({ kind: "game", name: game.name, command: game.command })
                event.accepted = true
            }
        }

        delegate: GameCard {
            required property int index
            required property var modelData
            game: modelData
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: {
                list.currentIndex = index
                shelf.activateCurrent()
            }
        }
    }

    Row {
        x: 180
        y: 990
        spacing: 40
        ButtonHint { button: "A"; label: menu.visible || !list.activeFocus ? "Select"
                                                          : shelf.picking ? "Choose" : "Launch" }
        ButtonHint { button: "B"; label: "Back" }
        ButtonHint{
            readonly property var game: shelf.game[list.currentIndex]
            button: "Y"
            label: game && Pins.isPinned(game.command) ? "Unpin" : "Pin"
            visible: list.activeFocus && !menu.visible && !shelf.picking && game !== undefined
        }
    }

    // The green-tile menu for "show me" and "sort"
    Item {
        id: menu
        anchors.fill: parent
        visible: false

        property var options: []
        property var choose: null               // function(label), called with the chosen tile
        property Item returnTo: null

        function open(options, choose, returnTo) {
            menu.options = options
            menu.choose = choose
            menu.returnTo = returnTo
            visible = true
            tiles.forceActiveFocus()
        }

        function close() {
            visible = false
            if (returnTo)
                returnTo.forceActiveFocus()
        }

        Rectangle {                             // dims the cards behind the menu
            anchors.fill: parent
            color: "black"
            opacity: 0.55
        }

        TilePage {
            id: tiles
            x: 370; y: 272
            cellWidth: 300
            cellHeight: 226
            gap: 4

            Repeater {
                model: menu.options
                Tile {
                    required property int index
                    required property var modelData
                    label: modelData.label
                    icon: modelData.icon
                    column: index % 4
                    row: Math.floor(index / 4)
                    focus: index === 0
                    onActivated: {
                        menu.choose(modelData.label)
                        menu.close()
                        list.currentIndex = 0
                    }
                }
            }

            Keys.onEscapePressed: menu.close()
        }
    }

    // "⌄ show me" over "all games"
    component HeaderButton: Column {
        id: header
        property string caption
        property string value
        signal activated()

        opacity: activeFocus ? 1 : 0.8

        Row {
            spacing: 8
            TileIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                name: "chevron"
            }
            Text {
                text: header.caption
                color: "white"
                font.pixelSize: 28
            }
        }
        Text {
            text: header.value
            color: "white"
            font.pixelSize: 38
            font.weight: Font.Light
        }
        Rectangle {                             // underline while focused
            width: parent.width; height: 3
            color: "white"
            visible: header.activeFocus
        }

        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
    }

    // One game: a white card with the box art, name and source
    component GameCard: Rectangle {
        id: card
        property var game
        property bool selected
        signal clicked()

        width: 335
        height: 596
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: "#F2F2F2"

        scale: selected ? 1.08 : 1.0
        z: selected ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // Soft shadow under the selected card (same trick as the tiles)
        Item {
            anchors.fill: parent
            z: -1
            opacity: card.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Repeater {
                model: 8
                Rectangle {
                    required property int index
                    x: 4 - index * 2
                    y: 8 - index * 2
                    width: parent.width + index * 4
                    height: parent.height + index * 4
                    radius: index * 2
                    color: Qt.rgba(0, 0, 0, 0.07)
                }
            }
        }

        // Box art, or a grey box with a controller if there is none
        Rectangle {
            id: artBox
            x: 14; y: 14
            width: parent.width - 28
            height: 420
            color: "#8A8A8A"

            TileIcon {
                anchors.centerIn: parent
                width: 150; height: 150
                name: "controller"
                visible: art.status !== Image.Ready
            }

            Image {
                id: art
                anchors.fill: parent
                source: card.game.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: width
            }
        }

        Text {
            id: title
            anchors.left: artBox.left
            anchors.right: artBox.right
            anchors.top: artBox.bottom
            anchors.topMargin: 12
            text: card.game.name
            color: "#333333"
            font.pixelSize: 30
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            anchors.left: artBox.left
            anchors.top: title.bottom
            anchors.topMargin: 4
            text: card.game.source
            color: "#777777"
            font.pixelSize: 26
        }

        TileIcon {                              // small controller, bottom right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            width: 32; height: 32
            name: "controller"
            color: "#555555"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: card.clicked()
        }
    }
}