import QtQuick
import QtQuick.Layouts

// Page shown inside Main.qml's StackView (must be an Item, not a Window)
Rectangle {
    id: root
    color: "#eeeeee"
    clip: true

    //Create Main Space For Blocks and Resizeability
    Rectangle{
        id: panel
        width: 1920
        height: 1080
        color: "#eeeeee"

        anchors.centerIn: parent
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center

        // Open Tray
        Rectangle{
            id: openTrayTile
            width: 310
            height: 150
            color: "#107C10"

            scale: openTrayMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: openTrayMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: parent.width * 0.15
            anchors.topMargin: parent.height * 0.15

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Tray")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "Open Tray"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: openTrayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Pins
        Rectangle{
            id: pinsTile
            width: 310
            height: 150
            color: "#107C10"

            scale: pinsMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: pinsMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: openTrayTile.left
            anchors.top: openTrayTile.bottom
            anchors.topMargin: 4

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Pin")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "My Pins"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: pinsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Recents
        Rectangle{
            id: recentsTile
            width: 310
            height: 150
            color: "#107C10"

            scale: recentsMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: recentsMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: pinsTile.left
            anchors.top: pinsTile.bottom
            anchors.topMargin: 4

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Recent")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "Recents"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: recentsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // News
        Rectangle{
            id: newsTile
            width: 624
            height: 304
            color: "#107C10"

            scale: newsMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: newsMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: openTrayTile.right
            anchors.leftMargin: 4
            anchors.top: openTrayTile.top

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Recent")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "News"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: newsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Media
        Rectangle{
            id: mediaTile
            width: 310
            height: 150
            color: "#107C10"

            scale: mediaMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: mediaMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: recentsTile.right
            anchors.top: newsTile.bottom
            anchors.topMargin: 4
            anchors.leftMargin: 4

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Recent")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "Media"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    Qt.openUrlExternally("https://www.youtube.com")
                }
            }
        }

        // Apps
        Rectangle{
            id: appsTile
            width: 310
            height: 150
            color: "#107C10"

            scale: appsMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: appsMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: mediaTile.right
            anchors.top: newsTile.bottom
            anchors.topMargin: 4
            anchors.leftMargin: 4

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Recent")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "Apps"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: appsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    Qt.openUrlExternally("file:///home")
                }
            }
        }

        // Search
        Rectangle{
            id: searchTile
            width: 310
            height: 150
            color: "#107C10"

            scale: searchMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: searchMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: newsTile.right
            anchors.top: openTrayTile.top
            anchors.leftMargin: 4

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Recent")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "Search"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: searchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    Qt.openUrlExternally("https://www.google.com")
                }
            }
        }

        // Settings
        Rectangle{
            id: settingsTile
            width: 310
            height: 150
            color: "#107C10"

            scale: settingMouse.containsMouse || activeFocus ? 1.04 : 1.0
            z: settingMouse.containsMouse || activeFocus ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            anchors.left: newsTile.right
            anchors.top: searchTile.bottom
            anchors.leftMargin: 4

            //keyNavigation.down: pinTile
            //keyNavigation.right: news1Tile

            function activate(){
                console.log("Peak Recent")
            }

            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Text{
                text: "Settings"
                color: "white"
                font.pixelSize: 25

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
            }

            MouseArea{
                id: settingMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    Qt.openUrlExternally("https://www.google.com")
                }
            }
        }

    }


}
