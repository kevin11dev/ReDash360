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
        Launcher.rememberGame()
        console.info("Guide overlay: opening over", Launcher.gameTitle)
        showFullScreen()
        requestActivate()
        guide.open()
        pauseTimer.restart()                    // freeze the game once the Guide is on screen
    }

    function closeGuide() {
        guide.close()
    }

    // Freezing the game straight away kept the Guide from showing up, so the
    // game keeps running while the Guide fades in, then freezes behind it
    Timer{
        id: pauseTimer
        interval: 600
        onTriggered: Launcher.pauseGame()
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
            gameTitle: Launcher.gameTitle
            backdropColor: "#99000000"          // lighter, so the paused game shows through
            onVisibleChanged: {
                if(!visible){
                    pauseTimer.stop()           // closed before it froze? then it never will
                    Launcher.resumeGame()       // the game carries on
                    Qt.callLater(overlay.hide)
                }
            }
            onTabRequested: (index) => overlay.tabRequested(index)
            onShelfRequested: overlay.shelfRequested()
            onQuitRequested: overlay.quitRequested()
        }
    }
}