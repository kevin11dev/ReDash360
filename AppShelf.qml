import QtQuick

// "my apps": every installed app as a square green tile, two rows that
// scroll sideways, like the 360's my apps screen. Its own screen, like My Games.
FocusScope {
    id: appShelf
    visible: false

    property Item returnFocusTo: null
    property string title: "my apps"
    property var apps: []
    property var pickCallback: null             // set while choosing an app for a slot
    readonly property bool picking: pickCallback !== null

    // open()                          -> every app, as "my apps"
    // open("my video apps", someApps) -> just those apps, with that title
    function open(newTitle, newApps) {
        pickCallback = null
        show(newTitle, newApps)
    }

    // Choose an app for a slot: callback(app) gets the one you pick
    function pick(newTitle, newApps, callback) {
        pickCallback = callback
        show(newTitle, newApps)
    }

    function show(newTitle, newApps) {
        title = newTitle || "my apps"
        apps = newApps || AppLibrary.all()
        returnFocusTo = Window.activeFocusItem
        visible = true
        grid.currentIndex = 0
        grid.forceActiveFocus()
        fadeIn.restart()
    }

    function close() {
        visible = false
        pickCallback = null
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function activateCurrent() {
        const app = grid.model[grid.currentIndex]
        if (!app)
            return
        if (picking)
            pickCallback(app)                   // {name, command, icon}
        else
            Launcher.openApp(app.name, app.command, app.icon)
        close()
    }

    NumberAnimation { id: fadeIn; target: appShelf; property: "opacity"; from: 0; to: 1; duration: 200 }

    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // Title and "1 of 7", top right
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 170
        y: 130

        Text {
            anchors.right: parent.right
            text: appShelf.title
            color: "white"
            font.pixelSize: 52
        }
        Text {
            anchors.right: parent.right
            text: grid.count > 0 ? (grid.currentIndex + 1) + " of " + grid.count : ""
            color: "white"
            font.pixelSize: 30
        }
    }

    Text {
        anchors.centerIn: parent
        visible: grid.count === 0
        text: "No Apps Found"
        color: "white"
        font.pixelSize: 40
        font.weight: Font.Light
    }

    GridView {
        id: grid
        y: 280
        width: parent.width
        height: 2 * cellHeight                  // two rows...

        flow: GridView.FlowTopToBottom          // ...filled top to bottom, then the next column
        cellWidth: 313                          // 287 tile + 26 gap
        cellHeight: 293                         // 287 tile + 6 gap
        leftMargin: 195
        rightMargin: 195
        model: appShelf.apps
        keyNavigationEnabled: true

        highlightRangeMode: GridView.ApplyRange
        preferredHighlightBegin: 195
        preferredHighlightEnd: width - 500
        highlightMoveDuration: 200

        Keys.onReturnPressed: appShelf.activateCurrent()
        Keys.onEnterPressed: appShelf.activateCurrent()

        delegate: AppTile {
            required property int index
            required property var modelData
            app: modelData
            selected: GridView.isCurrentItem && grid.activeFocus
            onClicked: {
                grid.currentIndex = index
                appShelf.activateCurrent()
            }
        }
    }

    Row {
        x: 180
        y: 990
        spacing: 40
        ButtonHint { button: "A"; label: appShelf.picking ? "Choose" : "Launch" }
        ButtonHint { button: "B"; label: "Back" }
    }

    // One app: a square green tile with its icon and name
    component AppTile: Rectangle {
        id: tile
        property var app
        property bool selected
        signal clicked()

        width: 287
        height: 287
        color: "#009000"

        scale: selected ? 1.08 : 1.0
        z: selected ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // Soft shadow under the selected tile (same trick as Tile.qml)
        Item {
            anchors.fill: parent
            z: -1
            opacity: tile.selected ? 1 : 0
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

        // The app's own icon, or our generic apps icon if it has none
        Image {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -24
            width: 112; height: 112
            source: tile.app.icon !== "" ? "image://appicon/" + tile.app.icon : ""
            sourceSize: Qt.size(112, 112)
            asynchronous: true
        }
        TileIcon {
            anchors.centerIn: icon
            width: 96; height: 96
            name: "apps"
            visible: icon.status !== Image.Ready
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            text: tile.app.name
            color: "white"
            font.pixelSize: 28
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 0.9
        }

        MouseArea {
            anchors.fill: parent
            onClicked: tile.clicked()
        }
    }
}