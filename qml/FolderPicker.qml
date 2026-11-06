import QtQuick
import QtCore
import Qt.labs.folderlistmodel

// Choosing a folder with a controller: first your home folder and your drives
// (the same ones as Settings > Storage), then the folders inside. A opens a
// folder, "Use This Folder" at the top picks the one you're in, B goes back up.
FocusScope {
    id: picker

    property string path: ""                    // "" = the list of drives
    signal chosen(string path)
    signal cancelled()

    readonly property string home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
    readonly property var places: [{ label: "Home", detail: home, path: home }].concat(
        Storage.devices.map(device => ({ label: device.name, detail: device.path, path: device.path })))

    // What the list shows: the drives, or "Use This Folder" and the folders in this one
    property var rows: []
    function rebuild() {
        if (path === "") {
            rows = places
            return
        }
        const list = [{ label: "Use This Folder", detail: "", path: path, use: true }]
        for (let i = 0; i < folders.count; i++)
            list.push({ label: folders.get(i, "fileName"), detail: "", path: folders.get(i, "filePath") })
        rows = list
    }

    function open() {
        Storage.refresh()
        show("")
        forceActiveFocus()
    }

    function show(newPath, selectPath) {
        path = newPath
        rebuild()
        const at = selectPath ? rows.findIndex(row => row.path === selectPath) : 0
        list.currentIndex = Math.max(0, at)
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
        list.forceActiveFocus()
    }

    function activate() {
        const row = rows[list.currentIndex]
        if (!row)
            return
        if (row.use)
            chosen(row.path)
        else
            show(row.path)
    }

    // Up a folder; from a drive (or home) back to the list of drives; from there, out
    function back() {
        if (path === "") {
            cancelled()
            return
        }
        const from = path
        if (places.some(place => place.path === path))
            show("", from)
        else
            show(path.replace(/\/[^\/]+\/?$/, "") || "/", from)
    }

    FolderListModel {
        id: folders
        folder: picker.path ? "file://" + picker.path : ""
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) picker.rebuild()
        onCountChanged: picker.rebuild()
    }

    // Where you are
    Text {
        id: where
        x: 45; y: 14
        width: parent.width - 90
        text: picker.path === "" ? "Choose a drive" : picker.path
        color: "#3A4044"
        font.pixelSize: 26
        elide: Text.ElideMiddle
    }

    ListView {
        id: list
        y: 60
        width: parent.width
        height: parent.height - y
        clip: true
        keyNavigationEnabled: true
        highlightMoveDuration: 0
        model: picker.rows

        delegate: Rectangle {
            id: row
            required property int index
            required property var modelData
            readonly property bool selected: ListView.isCurrentItem && list.activeFocus
            readonly property color ink: selected ? "white" : "#222222"

            width: list.width
            height: 70
            color: selected ? "#008E00" : "transparent"

            TileIcon {
                x: 30
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36
                name: row.modelData.use ? "check" : picker.path === "" ? (row.index === 0 ? "home" : "storage") : "folder"
                color: row.ink
            }
            Text {
                x: 90
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - detail.width - 70
                text: row.modelData.label
                color: row.ink
                font.pixelSize: 36
                font.bold: !!row.modelData.use
                elide: Text.ElideRight
            }
            Text {
                id: detail
                anchors.right: parent.right
                anchors.rightMargin: 45
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 300)
                text: row.modelData.detail
                color: row.selected ? "white" : "#5A6064"
                font.pixelSize: 26
                elide: Text.ElideMiddle
            }
            Column {
                anchors.bottom: parent.bottom
                width: parent.width
                visible: !row.selected && list.currentIndex !== row.index + 1
                Rectangle { width: parent.width; height: 1; color: "#8E979A" }
                Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: if (Pointer.active) list.currentIndex = row.index
                onClicked: {
                    list.currentIndex = row.index
                    picker.activate()
                }
            }
        }

        Keys.onReturnPressed: picker.activate()
        Keys.onEnterPressed: picker.activate()
        Keys.onEscapePressed: picker.back()
    }

    Text {
        x: 45
        visible: picker.path !== "" && picker.rows.length === 1
        text: "No folders in here."
        color: "#5A6064"
        font.pixelSize: 30
        anchors.top: list.top
        anchors.topMargin: 90
    }
}