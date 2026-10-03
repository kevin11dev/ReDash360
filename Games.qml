import QtQuick

Rectangle {
    color: "#eeeeee"

    Text {
        anchors.centerIn: parent
        text: "GAMES"
        color: "#107C10"
        font.pixelSize: 48
        font.bold: true
    }

    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 90

        width: 420
        height: 120
        color: "#107C10"

        Text {
            anchors.centerIn: parent
            text: "Your Games Library"
            color: "white"
            font.pixelSize: 25
        }
    }
}