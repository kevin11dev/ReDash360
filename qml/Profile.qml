import QtQuick

// The signed-in profile in the top-right corner, like on the 360: your
// gamertag with your gamerpic to its right, and on a laptop its battery
// to their left
Item {
    id: profile
    width: 400                  // room for the text; the picture sits at the right edge
    height: 57

    // From the shared profile (UserProfile.qml), so every screen agrees
    readonly property string gamertag: UserProfile.gamertag
    readonly property string gamerpic: UserProfile.gamerpic

    Gamerpic {
        id: pic
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        id: tag
        anchors.right: pic.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: profile.gamertag
        color: "white"
        font.pixelSize: 28
        opacity: 0.88
    }

    LaptopBattery {
        anchors.right: tag.left
        anchors.rightMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        opacity: 0.88
    }
}