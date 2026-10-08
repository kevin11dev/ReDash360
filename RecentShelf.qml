import QtQuick

// Recents: the games and apps you started last, newest first, as white cards
// like My Games. A starts it again, Y takes it off the list.
FocusScope {
    id: recents
    visible: false

    property Item returnFocusTo: null

    function open() {
        returnFocusTo = Window.activeFocusItem
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
        const item = Launcher.recents[list.currentIndex]
        if (!item)
            return
        close()                                 // close first: starting it changes the list
        if (item.kind === "game")
            Launcher.play(item.name, item.command)
        else
            Launcher.openApp(item.name, item.command, item.icon)
    }

    NumberAnimation { id: fadeIn; target: recents; property: "opacity"; from: 0; to: 1; duration: 200 }

    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // Title and "1 of 6", top right
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 145
        y: 118

        Text {
            anchors.right: parent.right
            text: "Recent"
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
        text: "Nothing Here Yet"
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
        model: Launcher.recents
        keyNavigationEnabled: true

        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 153
        preferredHighlightEnd: width - 500
        highlightMoveDuration: 200

        Keys.onReturnPressed: recents.activateCurrent()
        Keys.onEnterPressed: recents.activateCurrent()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Y && count > 0) {
                const index = currentIndex
                Launcher.removeRecent(index)
                currentIndex = Math.min(index, count - 1)   // stay where you were
                event.accepted = true
            }
        }

        delegate: RecentCard {
            required property int index
            required property var modelData
            item: modelData
            selected: ListView.isCurrentItem && list.activeFocus
            onClicked: {
                list.currentIndex = index
                recents.activateCurrent()
            }
        }
    }

    Row {
        x: 180
        y: 990
        spacing: 40
        ButtonHint { button: "A"; label: "Launch"; visible: list.count > 0 }
        ButtonHint { button: "B"; label: "Back" }
        ButtonHint { button: "Y"; label: "Remove"; visible: list.count > 0 }
    }

    // One game or app: a white card like in My Games. Games show their box
    // art, apps their icon on green.
    component RecentCard: Rectangle {
        id: card
        property var item                       // {kind, name, command, icon}
        property bool selected
        signal clicked()

        readonly property bool isGame: item.kind === "game"
        // A game's art and source come from the library ({} if it's gone)
        readonly property var game: {
            GameLibrary.count                   // look again after a rescan
            return isGame ? GameLibrary.find(item.command) : {}
        }

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

        // Box art for games (grey with a controller if there is none),
        // the app's icon on green for apps
        Rectangle {
            id: artBox
            x: 14; y: 14
            width: parent.width - 28
            height: 420
            color: card.isGame ? "#8A8A8A" : "#009000"

            TileIcon {
                anchors.centerIn: parent
                width: 150; height: 150
                name: card.isGame ? "controller" : "apps"
                visible: card.isGame ? art.status !== Image.Ready : appIcon.status !== Image.Ready
            }

            Image {
                id: art
                anchors.fill: parent
                visible: card.isGame
                source: card.isGame && card.game.cover ? card.game.cover : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: width
            }

            Image {
                id: appIcon
                anchors.centerIn: parent
                width: 160; height: 160
                visible: !card.isGame
                source: !card.isGame && card.item.icon ? "image://appicon/" + card.item.icon : ""
                sourceSize: Qt.size(160, 160)
                asynchronous: true
            }
        }

        Text {
            id: title
            anchors.left: artBox.left
            anchors.right: artBox.right
            anchors.top: artBox.bottom
            anchors.topMargin: 12
            text: card.item.name
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
            text: card.isGame ? (card.game.source || "Game") : "App"
            color: "#777777"
            font.pixelSize: 26
        }

        TileIcon {                              // small controller or apps icon, bottom right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            width: 32; height: 32
            name: card.isGame ? "controller" : "apps"
            color: "#555555"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: card.clicked()
        }
    }
}