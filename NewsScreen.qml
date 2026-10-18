import QtQuick

// All News (Y on Home's News tile): every story in a list, the one you're on
// bigger on the right. A reads it in your web browser (or plays today's game).
FocusScope {
    id: newsScreen
    visible: false

    property Item returnFocusTo: null
    property var cards: []
    readonly property var current: cards[list.currentIndex] || ({})

    function open(newCards, index) {
        returnFocusTo = Window.activeFocusItem
        cards = newCards
        list.currentIndex = index
        visible = true
        list.forceActiveFocus()
        list.positionViewAtIndex(index, ListView.Contain)
        panelAnimation.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function activate(card) {
        if (!card || !card.kind)
            return
        close()
        if (card.kind === "pick")
            Launcher.play(card.title, card.command)
        else
            Qt.openUrlExternally(card.url)
    }

    // "Blasphemous · 3 days ago"
    function about(card) {
        return [card.source, card.time ? News.ago(card.time) : ""].filter(part => part).join(" · ")
    }

    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        text: "All News"
        color: "white"
        font.pixelSize: 50
    }

    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719

        Rectangle {
            width: 760; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(count * 89, 8 * 89)
                clip: true
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: newsScreen.cards
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: StoryRow {}

                Keys.onReturnPressed: newsScreen.activate(newsScreen.current)
                Keys.onEnterPressed: newsScreen.activate(newsScreen.current)
            }
        }

        // ---- The one you're on, bigger ----
        Rectangle {
            x: 760
            width: 560; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            Picture {
                x: 40; y: 40
                width: 480; height: 270
                card: newsScreen.current
                iconSize: 120
            }
            Column {
                x: 40; y: 334
                width: parent.width - 80
                spacing: 10

                Text {
                    width: parent.width
                    text: newsScreen.current.title || ""
                    color: "#2E3336"
                    font.pixelSize: 32
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: newsScreen.about(newsScreen.current)
                    color: "#4A5155"
                    font.pixelSize: 24
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: newsScreen.current.summary || ""
                    color: "#3A4044"
                    font.pixelSize: 25
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }
            }
        }

        // Like the 360's lists: the panel grows out of the middle
        ParallelAnimation {
            id: panelAnimation
            NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
        }
    }

    Row {
        x: 138; y: 973
        spacing: 30
        ButtonHint { button: "A"; label: newsScreen.current.kind === "pick" ? "Play" : "Read" }
        ButtonHint { button: "B"; label: "Back" }
    }

    // ---- Pieces ----------------------------------------------------------------

    // A story's picture, or a globe on green when there isn't one (or it's offline)
    component Picture: Rectangle {
        id: picture
        property var card: ({})
        property int iconSize: 36

        clip: true
        color: "#009000"

        Image {
            id: image
            anchors.fill: parent
            source: picture.card.image || ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: picture.width * 2
            asynchronous: true
        }
        TileIcon {
            anchors.centerIn: parent
            width: picture.iconSize; height: picture.iconSize
            name: "globe"
            visible: image.status !== Image.Ready
        }
    }

    // A story: its picture, its headline, and where and when it's from
    component StoryRow: Rectangle {
        id: row
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus

        width: ListView.view.width
        height: 89
        color: selected ? "#008E00" : "transparent"

        Picture {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 128; height: 64
            card: row.modelData
        }
        Column {
            x: 176
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 30
            spacing: 2
            Text {
                width: parent.width
                text: row.modelData.title
                color: row.selected ? "white" : "#222222"
                font.pixelSize: 28
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: newsScreen.about(row.modelData)
                color: row.selected ? "#E0FFFFFF" : "#5A6064"
                font.pixelSize: 22
                elide: Text.ElideRight
            }
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !row.selected && row.ListView.view.currentIndex !== row.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) row.ListView.view.currentIndex = row.index
            onClicked: {
                row.ListView.view.currentIndex = row.index
                newsScreen.activate(row.modelData)
            }
        }
    }
}