import QtQuick

FocusScope{
    id: root

    signal searchRequested()

    Text{
        anchors.right: bar.left
        anchors.rightMargin: 40
        anchors.verticalCenter: bar.verticalCenter
        text: Preferences.searchEngine.name.toLowerCase()
        color: "white"
        font.pixelSize: 58
        font.weight: Font.Light
    }

    Rectangle{
        id: bar
        x: 139; y: 181
        width: 1200; height: 109
        color: "#B0000000"
        border.width: activeFocus ? 2 : 0
        border.color: "#80FFFFFF"
        focus: true

        Text{
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            text: "Search the Web..."
            color: "white"
            font.pixelSize: 44
            font.weight: Font.DemiBold
        }

        TileIcon{
            anchors.right: parent.right
            anchors.rightMargin: 46
            anchors.verticalCenter: parent.verticalCenter
            width: 54; height: 54
            name: "search"
        }

        MouseArea{
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.searchRequested()
        }

        Keys.onReturnPressed: root.searchRequested()
        Keys.onEnterPressed: root.searchRequested()
    }
}