import QtQuick

// My Pins: the games and apps you pinned (Y in My Games or my apps), as
// white cards like Recents. "show me" and "sort" at the top left work like
// in My Games. A starts it, Y unpins it.
FocusScope {
    id: pinShelf
    visible: false

    property Item returnFocusTo: null

    // What's shown: everything, games, apps or one launcher, and the order
    property string filter: "All Pins"
    property string sort: "Recently Pinned"

    readonly property var filters: [
        { label: "All Pins", icon: "pin" },
        { label: "Games", icon: "controller" },
        { label: "Apps", icon: "apps" },
        { label: "Steam", icon: "controller" },
        { label: "Heroic", icon: "controller" },
        { label: "Faugus", icon: "controller" }
    ]
    readonly property var sorts: [
        { label: "Recently Pinned", icon: "clock" },
        { label: "A-Z", icon: "star" }
    ]

    // A pinned game's launcher ("Steam", ...) from the library; "" for apps
    function sourceOf(item) {
        return item.kind === "game" ? (GameLibrary.find(item.command).source || "") : ""
    }

    // The pins to show: filtered and sorted
    readonly property var items: {
        GameLibrary.count                       // look again after a rescan
        let list = Pins.items                   // newest pin first
        if (filter === "Games")
            list = list.filter(item => item.kind === "game")
        else if (filter === "Apps")
            list = list.filter(item => item.kind === "app")
        else if (filter !== "All Pins")
            list = list.filter(item => sourceOf(item) === filter)
        if (sort === "A-Z")
            list = list.slice().sort((a, b) => a.name.localeCompare(b.name))
        return list
    }

    function open() {
        returnFocusTo = Window.activeFocusItem
        menu.close()
        visible = true
        list.currentIndex = 0
        list.forceActiveFocus()
        fadeIn.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function activateCurrent() {
        const item = items[list.currentIndex]
        if (!item)
            return
        close()
        if (item.kind === "game")
            Launcher.play(item.name, item.command)
        else
            Launcher.openApp(item.name, item.command, item.icon)
    }

    NumberAnimation { id: fadeIn; target: pinShelf; property: "opacity"; from: 0; to: 1; duration: 200 }

    // B anywhere on this screen (the menu handles its own B first)
    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // "show me" and "sort", top left (the same buttons as in My Games)
    GameShelf.HeaderButton {
        id: showMe
        x: 153; y: 152
        caption: "show me"
        value: pinShelf.filter.toLowerCase()
        KeyNavigation.right: sortBy
        KeyNavigation.down: list
        onActivated: menu.open(pinShelf.filters, label => pinShelf.filter = label, showMe)
    }

    GameShelf.HeaderButton {
        id: sortBy
        x: 541; y: 152
        caption: "sort"
        value: pinShelf.sort.toLowerCase()
        KeyNavigation.left: showMe
        KeyNavigation.down: list
        onActivated: menu.open(pinShelf.sorts, label => pinShelf.sort = label, sortBy)
    }

    // Title and "1 of 6", top right
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 145
        y: 118

        Text {
            anchors.right: parent.right
            text: "My Pins"
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
        horizontalAlignment: Text.AlignHCenter
        text: Pins.items.length === 0 ? "Pin games and apps with Y\nin My Games and my apps"
                                       : "Nothing Here"
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
        model: pinShelf.items
        keyNavigationEnabled: true

        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 153
        preferredHighlightEnd: width - 500
        highlightMoveDuration: 200

        Keys.onReturnPressed: pinShelf.activateCurrent()
        Keys.onEnterPressed: pinShelf.activateCurrent()
        Keys.onUpPressed: showMe.forceActiveFocus()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Y && count > 0) {
                const index = currentIndex
                Pins.unpin(pinShelf.items[index].command)
                currentIndex = Math.min(index, count - 1)   // stay where you were
                event.accepted = true
            }
        }

        // Same white card as Recents
        delegate: RecentShelf.RecentCard {
            required property int index
            required property var modelData
            item: modelData
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: {
                list.currentIndex = index
                pinShelf.activateCurrent()
            }
        }
    }

    Row {
        x: 180
        y: 990
        spacing: 40
        ButtonHint { button: "A"; label: list.activeFocus ? "Launch" : "Select"; visible: list.count > 0 || !list.activeFocus }
        ButtonHint { button: "B"; label: "Back" }
        ButtonHint { button: "Y"; label: "Unpin"; visible: list.activeFocus && list.count > 0 }
    }

    // The green-tile menu for "show me" and "sort" (like in My Games)
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
}