import QtQuick
import QtQuick.Window

Window {
    id: overlay
    objectName: "guideOverlay"
    transientParent: null
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    visible: false

    property alias gamertag: guide.gamertag
    property alias gamerpic: guide.gamerpic

    signal tabRequested(int index)
    signal shelfRequested()
    signal quitRequested()

    function openGuide() {
        console.info("Guide overlay: opening over the game")
        showFullScreen()
        requestActivate()
        guide.open()
    }

    function closeGuide() {
        guide.close()
    }

    Shortcut{
        sequence: "Home"
        onActivated: overlay.closeGuide()
    }

    Item{
        width: 1920
        height: 1080
        anchors.centerIn: parent
        scale: Math.min(overlay.width / width, overlay.height / height)

        Guide{
            id: guide
            anchors.fill: parent
            onVisibleChanged: {
                if(!visible)
                    Qt.callLater(overlay.hide)
            }
            onTabRequested: (index) => overlay.tabRequested(index)
            onShelfRequested: overlay.shelfRequested()
            onQuitRequested: overlay.quitRequested()
        }
    }
}