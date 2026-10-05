import QtQuick

// The Xbox Guide: a dark overlay with a row of "blades" (tabs). The current
// blade is the big middle panel; the two blades on each side peek in as
// narrow strips with their names written sideways. LB/RB (Q/E) or
// left/right switch blades, up/down picks a row, A runs it, B closes.
// Sizes come from DashX360's guide, scaled from 1280x720 to our 1920x1080.
FocusScope {
    id: guide
    visible: false

    property string gamertag
    property string gamerpic

    // What the rows ask the dashboard to do
    signal tabRequested(int index)
    signal shelfRequested()
    signal quitRequested()

    property Item returnFocusTo: null
    property int tab: 2                         // start on "Xbox Home"

    // The blades, left to right. A row without "run" does nothing yet.
    readonly property var blades: [
        { title: "Games & Apps", rows: [
            { label: "My Games", run: () => guide.shelfRequested() },
            { label: "My Apps", run: () => guide.tabRequested(5) },
            { label: "Game Marketplace" },
            { label: "App Marketplace" } ] },
        { title: guide.gamertag, rows: [
            { label: "Achievements" },
            { label: "Recent" },
            { label: "My Games", run: () => guide.shelfRequested() } ] },
        { title: "Xbox Home", rows: [
            { label: "Xbox Home", run: () => guide.tabRequested(1) },
            { label: "Friends", run: () => guide.tabRequested(2) },
            { label: "Party" },
            { label: "Minimize", run: () => {} } ] },
        { title: "Media", rows: [
            { label: "Video Player" },
            { label: "Music Player" },
            { label: "Picture Viewer" } ] },
        { title: "Settings", rows: [
            { label: "System Settings", run: () => guide.tabRequested(6) },
            { label: "Profile" },
            { label: "Preferences" },
            { label: "Turn Off", run: () => guide.quitRequested() } ] }
    ]

    function open() {
        returnFocusTo = guide.Window.activeFocusItem
        tab = 2
        list.currentIndex = 0
        visible = true
        list.forceActiveFocus()
        openAnimation.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function switchTab(step) {
        const next = tab + step
        if (next < 0 || next >= blades.length)
            return
        tab = next
        list.currentIndex = 0
        slideIn.from = step * 60                // slide in from the side we moved towards
        slideIn.restart()
    }

    function activateCurrent() {
        const row = blades[tab].rows[list.currentIndex]
        if (!row.run)
            return                              // not built yet
        close()                                 // close first, so focus is back on the dashboard
        row.run()
    }

    // Name of the blade `offset` steps away from the current one ("" past the ends)
    function bladeTitle(offset) {
        const i = tab + offset
        return i >= 0 && i < blades.length ? blades[i].title : ""
    }

    // Dark backdrop; also stops the mouse reaching the dashboard underneath
    Rectangle {
        anchors.fill: parent
        color: "#E6000000"
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: guide.close()
        }
    }

    Item {
        id: content
        anchors.fill: parent

        Text {
            x: 531; y: 247
            text: "Xbox Guide"
            color: "#E8EAEB"
            font.pixelSize: 34
            font.weight: Font.Light
        }

        // Gamerpic: the saved picture, or the first letter on a green tile
        Rectangle {
            x: 910; y: 219
            width: 72; height: 72
            color: "#107C10"
            Text {
                anchors.centerIn: parent
                text: guide.gamertag.charAt(0).toUpperCase()
                color: "white"
                font.pixelSize: 40
            }
            Image {
                anchors.fill: parent
                source: guide.gamerpic
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Text {
            id: clock
            x: 1165; y: 268
            width: 189
            horizontalAlignment: Text.AlignHCenter
            color: "#E8EAEB"
            font.pixelSize: 31
            font.weight: Font.DemiBold

            Timer {
                interval: 1000
                running: guide.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = Qt.formatTime(new Date(), "h:mm AP")
            }
        }

        // The blades: outer strip, inner strip, main panel, inner strip, outer strip
        Row {
            id: bladeRow
            x: 471; y: 306
            height: 472

            SideStrip { width: 72; outer: true; offset: -2 }
            SideStrip { width: 87; outer: false; offset: -1 }

            Rectangle {
                width: 735
                height: parent.height
                color: "#E5EAEB"
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    model: guide.blades[guide.tab].rows
                    interactive: false
                    keyNavigationEnabled: true
                    highlightMoveDuration: 0

                    transform: Translate { id: shift }
                    NumberAnimation { id: slideIn; target: shift; property: "x"; to: 0; duration: 180; easing.type: Easing.OutCubic }

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData

                        width: ListView.view.width
                        height: 63
                        color: ListView.isCurrentItem ? "#107C10" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 27
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: row.ListView.isCurrentItem ? "white" : "#333638"
                            font.pixelSize: 30
                            font.weight: Font.DemiBold
                        }

                        Rectangle {                     // thin line under each row
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: "#C0C8CA"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                list.currentIndex = row.index
                                guide.activateCurrent()
                            }
                        }
                    }

                    Keys.onReturnPressed: guide.activateCurrent()
                    Keys.onEnterPressed: guide.activateCurrent()
                    Keys.onEscapePressed: guide.close()
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Q || event.key === Qt.Key_Left) {
                            guide.switchTab(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_E || event.key === Qt.Key_Right) {
                            guide.switchTab(1)
                            event.accepted = true
                        }
                    }
                }
            }

            SideStrip { width: 80; outer: false; offset: 1 }
            SideStrip { width: 67; outer: true; offset: 2 }
        }

        Row {
            x: 507; y: 796
            spacing: 40
            ButtonHint { button: "A"; label: "Select" }
            ButtonHint { button: "B"; label: "Back" }
        }
    }

    // Pop in: fade up and grow slightly
    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: guide; property: "opacity"; from: 0; to: 1; duration: 150 }
        NumberAnimation { target: content; property: "scale"; from: 0.97; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }

    // A neighbouring blade, shown as a strip with its name written sideways
    component SideStrip: Rectangle {
        id: strip
        property bool outer
        property int offset

        height: parent.height
        color: outer ? "#BBC6CC" : "#E8EEEE"

        Text {
            anchors.centerIn: parent
            width: strip.height - 40            // turned sideways, so its width runs down the strip
            rotation: 90
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: guide.bladeTitle(strip.offset)
            color: strip.outer ? "#4A555D" : "#3C4144"
            font.pixelSize: 30
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            onClicked: guide.switchTab(strip.offset)
        }
    }
}