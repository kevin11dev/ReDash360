import QtQuick

Rectangle{
    id: tile
    width: 46; height: 46
    color: "#107C10"

    Text{
        anchors.centerIn: parent
        text: UserProfile.gamertag.charAt(0).toUpperCase()
        color: picture.visible ? "transparent" : "#107C10"     // green only behind the letter
        font.pixelSize: tile.height * 0.6
        visible: !picture.visible
    }

    AnimatedImage{
        id: picture
        anchors.fill: parent
        source: UserProfile.gamerpic
        visible: status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        smooth: implicitWidth * 2 > width
        asynchronous: true
    }
}