import QtQuick

// Your gamerpic, or the first letter of your gamertag on green
Rectangle{
    id: tile
    width: 46; height: 46
    color: picture.visible ? "transparent" : "#107C10"     // no green showing through a picture

    Text{
        anchors.centerIn: parent
        text: UserProfile.gamertag.charAt(0).toUpperCase()
        color: "white"
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