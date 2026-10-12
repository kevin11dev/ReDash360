import QtQuick

// Settings > Storage, like the 360's. Storage Devices lists your drives with
// how much space is free; picking one shows what takes up the space (games,
// shader caches, Proton files, screenshots, your own folders), and Games and
// Apps lists the games on it, biggest first, to uninstall through Steam.
FocusScope {
    id: storageScreen
    visible: false

    property Item returnFocusTo: null

    // "devices", "drive" (what's on one drive) or "games"
    property string view: "devices"

    // The drive being looked at: an id from Storage.devices, or "all"
    property string drive: ""
    readonly property var driveIds: drive === "all" ? Storage.devices.map(d => d.id) : [drive]
    readonly property var driveInfo: drive === "all"
        ? { name: "All Devices", free: Storage.devices.reduce((sum, d) => sum + d.free, 0) }
        : Storage.devices.find(d => d.id === drive) || { name: "", free: 0 }

    // What's on it, once added up (all the drives together for "all")
    property var categories: []
    property var games: []
    property bool measuring: false

    // The Storage Devices rows: All Devices, then each drive
    readonly property var deviceRows: (Storage.devices.length > 1
        ? [{ id: "all", name: "All Devices", kind: "all", detail: Storage.devices.length + " devices" }] : [])
        .concat(Storage.devices.map(d => Object.assign({ detail: size(d.free) + " free" }, d)))

    function open() {
        returnFocusTo = Window.activeFocusItem
        card.visible = false
        Storage.refresh()
        view = "devices"
        devicesList.currentIndex = 0
        visible = true
        devicesList.forceActiveFocus()
        panelAnimation.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function back() {
        if (view === "games") {
            view = "drive"
            driveList.forceActiveFocus()
        } else if (view === "drive") {
            view = "devices"
            devicesList.forceActiveFocus()
        } else {
            close()
        }
    }

    function showDrive(id) {
        drive = id
        view = "drive"
        driveList.currentIndex = 0
        driveList.forceActiveFocus()
        panelAnimation.restart()
        gather()                                // what we already know, while it adds up again
        for (const each of driveIds)
            Storage.measure(each)
        gather()
    }

    function showGames() {
        view = "games"
        gamesList.currentIndex = 0
        gamesList.forceActiveFocus()
        panelAnimation.restart()
    }

    // Put the drives' answers together (just one drive's, unless it's All Devices)
    function gather() {
        const byId = {}
        const order = []
        let found = []
        for (const id of driveIds) {
            for (const c of Storage.categories(id)) {
                if (!(c.id in byId)) {
                    byId[c.id] = { id: c.id, name: c.name, size: 0 }
                    order.push(c.id)
                }
                byId[c.id].size += c.size
            }
            found = found.concat(Storage.games(id))
        }
        if (order.indexOf("other") >= 0)          // Other Files stays last
            order.push(order.splice(order.indexOf("other"), 1)[0])
        // New numbers, but stay on the row you're on
        const onCategory = driveList.currentIndex
        const onGame = gamesList.currentIndex
        categories = order.map(id => byId[id])
        games = found.sort((a, b) => b.size - a.size)
        driveList.currentIndex = Math.min(Math.max(0, onCategory), categories.length - 1)
        gamesList.currentIndex = Math.min(Math.max(0, onGame), games.length - 1)
        measuring = driveIds.some(id => Storage.isMeasuring(id))
    }

    // 1536 -> "2 KB", 17.5 GB -> "17.5 GB", 168 GB -> "168 GB"
    function size(bytes) {
        const units = ["KB", "MB", "GB", "TB"]
        let value = bytes / 1024
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return (unit < 2 || value >= 100 ? Math.round(value) : Math.round(value * 10) / 10) + " " + units[unit]
    }

    function categoryIcon(id) {
        return { games: "controller", shadercache: "gear", proton: "folder", screenshots: "folder",
                 downloads: "download", videos: "play", music: "music", pictures: "folder" }[id] || "storage"
    }

    function canOpen(c) {
        return c !== undefined && ((c.id === "games" && games.length > 0) || (c.id === "shadercache" && c.size > 0))
    }

    function openCategory(c) {
        if (!canOpen(c))
            return
        if (c.id === "games") {
            showGames()
        } else {
            const ids = driveIds
            showMessage("Clear Shader Cache?",
                        "Steam saves shaders so games load faster. Clearing them frees " + size(c.size)
                        + ". Steam makes them again the next time you play, so games may stutter for a little while.",
                        [{ label: "Clear Shader Cache", run: () => { ids.forEach(id => Storage.clearShaderCache(id)); gather() } },
                         { label: "Cancel", run: () => {} }])
        }
    }

    function uninstall(game) {
        showMessage("Uninstall " + game.name + "?",
                    "Steam will ask you to confirm, then remove " + game.name + " and free up " + size(game.size) + ".",
                    [{ label: "Uninstall", run: () => Launcher.run("steam steam://uninstall/" + game.appId) },
                     { label: "Cancel", run: () => {} }])
    }

    function showMessage(title, text, options) {
        card.title = title
        card.message = text
        card.options = options || [{ label: "OK", run: () => {} }]
        card.defaultIndex = 0
        card.open()
    }

    Connections {
        target: Storage
        function onMeasured(id) {
            if (storageScreen.view !== "devices" && storageScreen.driveIds.indexOf(id) >= 0)
                storageScreen.gather()
        }
        function onEjected(id, error) {
            if (!storageScreen.visible)
                return
            if (error === "")
                storageScreen.showMessage("Safe to Remove", "You can unplug the drive now.")
            else
                storageScreen.showMessage("Couldn't Remove Drive", error)
        }
    }

    // Spots USB sticks coming and going while you're here
    Timer {
        interval: 3000
        repeat: true
        running: storageScreen.visible && storageScreen.view === "devices"
        onTriggered: Storage.refresh()
    }

    // ---- What's on screen ----------------------------------------------------

    Keys.onEscapePressed: back()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        width: 1100
        text: storageScreen.view === "devices" ? "Storage Devices"
            : storageScreen.view === "games" ? "Games and Apps" : storageScreen.driveInfo.name
        color: "white"
        font.pixelSize: 50
        elide: Text.ElideRight
    }

    // Free space (or the games' size) top right, like the 360's
    Text {
        anchors.right: parent.left
        anchors.rightMargin: -1775
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 124
        visible: storageScreen.view !== "devices"
        text: storageScreen.view === "games"
              ? storageScreen.size(storageScreen.games.reduce((sum, g) => sum + g.size, 0))
              : storageScreen.size(storageScreen.driveInfo.free) + " free"
        color: "white"
        font.pixelSize: 36
    }

    Rectangle {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#F4FBFA" }
            GradientStop { position: 1.0; color: "#D5DFE0" }
        }

        // ---- Storage Devices ----
        ListView {
            id: devicesList
            width: parent.width
            height: Math.floor(parent.height / 156) * 156      // only whole rows
            visible: storageScreen.view === "devices"
            clip: true
            interactive: false
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            model: storageScreen.deviceRows
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Row2 {}

            Keys.onReturnPressed: storageScreen.showDrive(storageScreen.deviceRows[currentIndex].id)
            Keys.onEnterPressed: storageScreen.showDrive(storageScreen.deviceRows[currentIndex].id)
            Keys.onPressed: (event) => {
                const row = storageScreen.deviceRows[currentIndex]
                if (event.key === Qt.Key_Y && row && row.kind === "usb") {
                    Storage.eject(row.id)
                    event.accepted = true
                }
            }
        }

        // ---- One drive ----
        ListView {
            id: driveList
            width: parent.width
            height: Math.floor(parent.height / 70) * 70
            visible: storageScreen.view === "drive" && storageScreen.categories.length > 0
            clip: true
            interactive: false
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            model: storageScreen.categories

            delegate: Row1 {
                icon: storageScreen.categoryIcon(modelData.id)
                label: modelData.name
                amount: storageScreen.size(modelData.size)
                onChosen: storageScreen.openCategory(modelData)
            }

            Keys.onReturnPressed: storageScreen.openCategory(storageScreen.categories[currentIndex])
            Keys.onEnterPressed: storageScreen.openCategory(storageScreen.categories[currentIndex])
        }

        Text {
            x: 45; y: 40
            visible: storageScreen.view === "drive" && storageScreen.categories.length === 0
            text: "Adding up what's on " + (storageScreen.drive === "all" ? "your drives" : "this drive") + "..."
            color: "#333333"
            font.pixelSize: 36
        }

        // ---- Games and Apps ----
        ListView {
            id: gamesList
            width: parent.width
            height: Math.floor(parent.height / 70) * 70
            visible: storageScreen.view === "games"
            clip: true
            interactive: false
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            model: storageScreen.games
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Row1 {
                icon: "controller"
                label: modelData.name
                amount: storageScreen.size(modelData.size)
                onChosen: storageScreen.uninstall(modelData)
            }

            Keys.onReturnPressed: if (currentIndex >= 0) storageScreen.uninstall(storageScreen.games[currentIndex])
            Keys.onEnterPressed: if (currentIndex >= 0) storageScreen.uninstall(storageScreen.games[currentIndex])
        }

        // More further down
        TileIcon {
            readonly property ListView shown: storageScreen.view === "devices" ? devicesList
                                            : storageScreen.view === "games" ? gamesList : driveList
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (parent.height - shown.height - height) / 2
            width: 28; height: 28
            name: "chevron"
            color: "#555555"
            visible: shown.visible && !shown.atYEnd
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
        ButtonHint {
            button: "A"
            label: storageScreen.view === "games" ? "Uninstall" : "Select"
            visible: storageScreen.view === "devices"
                     || (storageScreen.view === "games" && storageScreen.games.length > 0)
                     || (storageScreen.view === "drive" && storageScreen.canOpen(storageScreen.categories[driveList.currentIndex]))
        }
        ButtonHint { button: "B"; label: "Back" }
        ButtonHint {
            button: "Y"
            label: "Eject"
            visible: storageScreen.view === "devices" && devicesList.currentIndex >= 0
                     && (storageScreen.deviceRows[devicesList.currentIndex] || {}).kind === "usb"
        }
        Text {                                  // still adding up
            anchors.verticalCenter: parent.verticalCenter
            visible: storageScreen.view !== "devices" && storageScreen.measuring && storageScreen.categories.length > 0
            text: "Updating..."
            color: "white"
            opacity: 0.8
            font.pixelSize: 30
        }
    }

    MessageCard {
        id: card
        anchors.fill: parent
        icon: "!"
    }

    // ---- Pieces ----------------------------------------------------------------

    // A drive on Storage Devices: its name, then how much is free with a bar
    // showing how full it is
    component Row2: Rectangle {
        id: row
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property color ink: selected ? "white" : "#333333"

        width: ListView.view.width
        height: 156
        color: selected ? "#008E00" : "transparent"

        TileIcon {
            x: 26
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 48
            width: 68; height: 68
            name: row.modelData.kind === "usb" ? "usb" : "storage"
            color: row.ink
        }
        Text {
            x: 128
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 48
            width: parent.width - x - 40
            text: row.modelData.name
            color: row.ink
            font.pixelSize: 36
            elide: Text.ElideRight
        }

        // How full it is: the used part dark, the free part green
        Rectangle {
            x: 16
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 119
            width: 92; height: 18
            visible: row.modelData.kind !== "all"
            color: row.selected ? "#BDF09B" : "#2F9E19"
            Rectangle {
                width: row.modelData.total > 0 ? parent.width * row.modelData.used / row.modelData.total : 0
                height: parent.height
                color: "#3C3C3C"
            }
        }
        Text {
            x: 128
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 119
            text: row.modelData.detail
            color: row.ink
            font.pixelSize: 36
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
                storageScreen.showDrive(row.modelData.id)
            }
        }
    }

    // One line: an icon, the name, and a size on the right
    component Row1: Rectangle {
        id: line
        required property int index
        required property var modelData
        property string icon
        property string label
        property string amount                  // the size on the right
        signal chosen()
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property color ink: selected ? "white" : "#333333"

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        TileIcon {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44
            name: line.icon
            color: line.ink
        }
        Text {
            x: 76
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 260
            text: line.label
            color: line.ink
            font.pixelSize: 36
            elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 47
            anchors.verticalCenter: parent.verticalCenter
            text: line.amount
            color: line.ink
            font.pixelSize: 36
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !line.selected && line.ListView.view.currentIndex !== line.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) line.ListView.view.currentIndex = line.index
            onClicked: {
                line.ListView.view.currentIndex = line.index
                line.chosen()
            }
        }
    }
}