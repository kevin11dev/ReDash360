import QtQuick

// A note that slides up at the bottom when a controller's battery runs low,
// like the 360's notifications, then goes away by itself
Item {
    id: notice
    anchors.fill: parent

    property string detail

    function show(name, player) {
        detail = (player > 0 ? "Player " + player + " · " : "") + name
        box.y = parent.height
        showing.restart()
    }

    Connections {
        target: Gamepad
        function onBatteryLow(name, player) { notice.show(name, player) }
    }

    Rectangle {
        id: box
        x: (parent.width - width) / 2
        y: parent.height
        width: 760; height: 104
        radius: 6
        color: "#EE1E2124"
        border.color: "#6BD12B"
        border.width: 2
        opacity: 0

        BatteryIcon {
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: 58; height: 30
            level: "low"
        }
        Column {
            x: 120
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 30
            Text {
                text: "Controller battery low"
                color: "white"
                font.pixelSize: 34
            }
            Text {
                width: parent.width
                text: notice.detail
                color: "#C8CDD0"
                font.pixelSize: 26
                elide: Text.ElideRight
            }
        }
    }

    SequentialAnimation {
        id: showing
        ParallelAnimation {
            NumberAnimation { target: box; property: "y"; to: notice.height - box.height - 60; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: box; property: "opacity"; to: 1; duration: 300 }
        }
        PauseAnimation { duration: 5000 }
        NumberAnimation { target: box; property: "opacity"; to: 0; duration: 400 }
    }
}