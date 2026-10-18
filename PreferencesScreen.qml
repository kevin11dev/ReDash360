import QtQuick
import Qt.labs.folderlistmodel

// Settings > Preferences: the dashboard's own settings. The picture behind
// it, its sounds, how the clock shows the time, and whether it opens by
// itself when you sign in.
FocusScope {
    id: preferencesScreen
    visible: false

    property Item returnFocusTo: null

    // "menu"; "choose": how the clock looks; "background": picking a picture
    property string view: "menu"
    property var choices: []                    // [{label, detail, value, current}]

    readonly property var rows: ["background", "sounds", "soundVolume", "clock", "startup"]

    // The time now, for the clock row; ticks while the screen is open
    property date now: new Date()

    function open() {
        returnFocusTo = Window.activeFocusItem
        view = "menu"
        menu.currentIndex = 0
        now = new Date()
        Autostart.refresh()
        visible = true
        menu.forceActiveFocus()
        panelAnimation.restart()
    }

    function close() {
        Preferences.previewing = false
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function back() {
        if (view === "menu") {
            close()
            return
        }
        if (view === "background")
            panelAnimation.restart()
        Preferences.previewing = false
        view = "menu"
        menu.forceActiveFocus()
    }

    function label(id) {
        return { background: "Background", sounds: "Sound Effects", soundVolume: "Sound Effects Volume",
                 clock: "Clock", startup: "Start Automatically" }[id] || ""
    }

    function usable(id) {
        return id !== "soundVolume" || Preferences.soundEffects
    }

    function clockWords(format) {
        return { "": "Automatic", "12": "12-hour", "24": "24-hour" }[format] || ""
    }

    // "file:///home/kevin/.local/share/ReDash360/backgrounds/Blades%20Blue.jpg" -> "Blades Blue"
    function pictureName(file) {
        return decodeURIComponent(file.split("/").pop()).replace(/\.[^.]*$/, "")
    }

    // What a row says on the right
    function value(id) {
        switch (id) {
        case "background": return Preferences.background ? pictureName(Preferences.background) : "Default"
        case "sounds": return Preferences.soundEffects ? "On" : "Off"
        case "soundVolume": return Preferences.soundVolume + "%"
        case "clock": return clockWords(Preferences.clock)
        case "startup": return Autostart.enabled ? "On" : "Off"
        }
        return ""
    }

    // What the panel on the right says about a row
    function about(id) {
        return {
            background: "The picture behind the dashboard. Add your own to "
                        + "~/.local/share/ReDash360/backgrounds to choose them here.",
            sounds: "The clicks and swooshes as you move around the dashboard.",
            soundVolume: "How loud the dashboard's sounds are, next to everything else. "
                         + "Press left or right to change it.",
            clock: "How the time shows in the Guide and on your profile.",
            startup: "Opens the dashboard as soon as you sign in, so your PC starts like a console. "
                     + "If you move the dashboard to another folder, turn this off and on again.",
        }[id] || ""
    }

    function activate(id) {
        if (!usable(id))
            return
        if (id === "background") {
            openPictures()
        } else if (id === "sounds") {
            Preferences.setSoundEffects(!Preferences.soundEffects)
            if (Preferences.soundEffects)
                Sounds.play("select")           // so you hear they're back
        } else if (id === "clock") {
            now = new Date()
            choices = ["", "12", "24"].map(format => ({
                label: clockWords(format), detail: Preferences.time(now, format),
                value: format, current: format === Preferences.clock }))
            view = "choose"
            chooser.currentIndex = Math.max(0, choices.findIndex(c => c.current))
            chooser.forceActiveFocus()
        } else if (id === "startup") {
            Autostart.enabled = !Autostart.enabled
        }
    }

    function choose(choice) {
        back()
        Preferences.setClock(choice.value)
    }

    // ---- Choosing a background ---------------------------------------------
    // "Default" first, then every picture in the backgrounds folder. The one
    // you're on shows behind the dashboard straight away.

    function pictureAt(index) {
        return index <= 0 ? "" : pictureFiles.get(index - 1, "fileUrl").toString()
    }

    function openPictures() {
        view = "background"
        const mine = pictureFiles.indexOf(Preferences.background)
        pictures.currentIndex = Preferences.background && mine >= 0 ? mine + 1 : 0
        pictures.positionViewAtIndex(pictures.currentIndex, ListView.Contain)
        pictures.forceActiveFocus()
        showPicture()
    }

    function showPicture() {
        Preferences.preview = pictureAt(pictures.currentIndex)
        Preferences.previewing = true
    }

    function choosePicture() {
        Preferences.setBackground(pictureAt(pictures.currentIndex))
        back()
    }

    FolderListModel {
        id: pictureFiles
        folder: Preferences.backgroundsFolder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        caseSensitive: false
    }

    Timer {
        interval: 1000
        running: preferencesScreen.visible
        repeat: true
        onTriggered: preferencesScreen.now = new Date()
    }

    // ---- What's on screen ----------------------------------------------------

    Keys.onEscapePressed: back()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        text: preferencesScreen.view === "choose" ? "Clock"
            : preferencesScreen.view === "background" ? "Background" : "Preferences"
        color: "white"
        font.pixelSize: 50
    }

    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719
        visible: preferencesScreen.view !== "background"

        Rectangle {
            width: 760; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            // ---- The settings ----
            ListView {
                id: menu
                width: parent.width
                height: count * 70
                visible: preferencesScreen.view === "menu"
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: preferencesScreen.rows

                delegate: SettingRow {}

                Keys.onReturnPressed: preferencesScreen.activate(preferencesScreen.rows[currentIndex])
                Keys.onEnterPressed: preferencesScreen.activate(preferencesScreen.rows[currentIndex])
                Keys.onPressed: (event) => {
                    // Left and right change the sound effects' volume
                    if (preferencesScreen.rows[currentIndex] !== "soundVolume" || !Preferences.soundEffects)
                        return
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        Preferences.setSoundVolume(Preferences.soundVolume + (event.key === Qt.Key_Right ? 10 : -10))
                        Sounds.play("move")         // at the new volume
                        event.accepted = true
                    }
                }
            }

            // ---- How the clock looks ----
            ListView {
                id: chooser
                width: parent.width
                height: count * 70
                visible: preferencesScreen.view === "choose"
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: preferencesScreen.choices

                delegate: ChoiceRow {}

                Keys.onReturnPressed: preferencesScreen.choose(preferencesScreen.choices[currentIndex])
                Keys.onEnterPressed: preferencesScreen.choose(preferencesScreen.choices[currentIndex])
            }
        }

        // ---- About the selected setting ----
        Rectangle {
            x: 760
            width: 560; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            readonly property string row: preferencesScreen.view === "choose" ? "clock"
                                          : preferencesScreen.rows[menu.currentIndex] || ""

            TileIcon {
                x: 40; y: 40
                width: 96; height: 96
                name: ({ background: "picture", sounds: "volume", soundVolume: "volume",
                         clock: "clock", startup: "power" })[parent.row] || ""
                color: "#2E3336"
            }
            Text {
                x: 40; y: 170
                width: parent.width - 80
                text: preferencesScreen.label(parent.row)
                color: "#2E3336"
                font.pixelSize: 36
            }
            Text {
                x: 40; y: 226
                width: parent.width - 80
                text: preferencesScreen.about(parent.row)
                color: "#3A4044"
                font.pixelSize: 28
                wrapMode: Text.Wrap
            }

            // The background you have now
            BackgroundPicture {
                x: 40; y: 449
                width: 480; height: 230
                visible: parent.row === "background"
                file: Preferences.background
            }

            // The volume, big, while it's the one selected
            Column {
                x: 40; y: 420
                width: parent.width - 80
                spacing: 16
                visible: parent.row === "soundVolume"
                opacity: Preferences.soundEffects ? 1 : 0.4
                Text {
                    text: Preferences.soundEffects ? Preferences.soundVolume + "%" : "Off"
                    color: "#2E3336"
                    font.pixelSize: 72
                }
                Rectangle {
                    width: parent.width; height: 22
                    color: "#2B3033"
                    Rectangle {
                        width: parent.width * Preferences.soundVolume / 100
                        height: parent.height
                        color: "#6BD12B"
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // The time, the way the clock will show it
            Text {
                x: 40; y: 420
                visible: parent.row === "clock"
                text: Preferences.time(preferencesScreen.now,
                                       preferencesScreen.view === "choose"
                                       ? preferencesScreen.choices[chooser.currentIndex].value : undefined)
                color: "#2E3336"
                font.pixelSize: 72
            }
        }

        // Like the 360's lists: the panel grows out of the middle
        ParallelAnimation {
            id: panelAnimation
            NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
        }
    }

    // ---- The backgrounds, in a row along the bottom ----
    Item {
        anchors.fill: parent
        visible: preferencesScreen.view === "background"

        Text {
            x: 142; y: 470
            visible: pictureFiles.count === 0
            text: "Add pictures to ~/.local/share/ReDash360/backgrounds\nto choose them here."
            color: "white"
            font.pixelSize: 36
            style: Text.Outline
            styleColor: "#40000000"
        }

        ListView {
            id: pictures
            y: 628
            width: parent.width
            height: 236
            orientation: ListView.Horizontal
            spacing: 26
            leftMargin: 142
            rightMargin: 142
            keyNavigationEnabled: true
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 142
            preferredHighlightEnd: width - 142
            highlightMoveDuration: 200
            model: pictureFiles.count + 1

            onCurrentIndexChanged: if (activeFocus) preferencesScreen.showPicture()

            delegate: Item {
                id: tile
                required property int index
                readonly property string file: preferencesScreen.pictureAt(index)
                readonly property bool selected: ListView.isCurrentItem && pictures.activeFocus

                width: 384; height: 216
                y: 10
                scale: selected ? 1.08 : 1.0
                z: selected ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                BackgroundPicture {
                    anchors.fill: parent
                    file: tile.file
                }

                Rectangle {                     // a white edge round the one you're on
                    anchors.fill: parent
                    color: "transparent"
                    border.width: tile.selected ? 5 : 1
                    border.color: tile.selected ? "white" : "#80FFFFFF"
                }

                Rectangle {                     // a tick on the one you have now
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 44; height: 44
                    color: "#008E00"
                    visible: tile.file === Preferences.background
                    TileIcon {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        name: "check"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: if (Pointer.active) pictures.currentIndex = tile.index
                    onClicked: {
                        pictures.currentIndex = tile.index
                        preferencesScreen.choosePicture()
                    }
                }
            }

            Keys.onReturnPressed: preferencesScreen.choosePicture()
            Keys.onEnterPressed: preferencesScreen.choosePicture()
        }

        Text {
            x: 142; y: 884
            text: pictures.currentIndex > 0 ? preferencesScreen.pictureName(preferencesScreen.pictureAt(pictures.currentIndex))
                                            : "Default"
            color: "white"
            font.pixelSize: 36
            style: Text.Outline
            styleColor: "#40000000"
        }
    }

    Row {
        x: 138; y: 973
        spacing: 30
        ButtonHint {
            button: "A"
            label: preferencesScreen.view === "background" ? "Choose" : "Select"
            visible: preferencesScreen.view !== "menu"
                     || (preferencesScreen.usable(preferencesScreen.rows[menu.currentIndex])
                         && preferencesScreen.rows[menu.currentIndex] !== "soundVolume")
        }
        ButtonHint { button: "B"; label: "Back" }
    }

    // ---- Pieces ----------------------------------------------------------------

    // A background, small: the picture, or the dashboard's own grey
    component BackgroundPicture: Rectangle {
        property string file

        clip: true
        gradient: Gradient {                    // the same grey as Main.qml's
            GradientStop { position: 0.00; color: "#525357" }
            GradientStop { position: 0.20; color: "#65666a" }
            GradientStop { position: 0.40; color: "#808185" }
            GradientStop { position: 0.60; color: "#a0a0a2" }
            GradientStop { position: 0.78; color: "#b3b3b5" }
            GradientStop { position: 0.88; color: "#acadaf" }
            GradientStop { position: 1.00; color: "#8a8b8f" }
        }

        Image {
            anchors.fill: parent
            source: parent.file
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 480
            asynchronous: true
        }
    }

    // A setting: its name, and what it's set to on the right
    component SettingRow: Rectangle {
        id: row
        required property int index
        required property string modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property bool usable: preferencesScreen.usable(modelData)
        readonly property color ink: selected ? "white" : usable ? "#222222" : "#9AA3A6"

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        Text {
            x: 45
            anchors.verticalCenter: parent.verticalCenter
            text: preferencesScreen.label(row.modelData)
            color: row.ink
            font.pixelSize: 36
        }

        Rectangle {                             // a little volume bar
            anchors.right: value.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 120; height: 14
            visible: row.modelData === "soundVolume"
            color: row.selected ? "#1F5C12" : "#2B3033"
            opacity: row.usable ? 1 : 0.4
            Rectangle {
                width: parent.width * Preferences.soundVolume / 100
                height: parent.height
                color: row.selected ? "white" : "#6BD12B"
            }
        }

        Text {
            id: value
            anchors.right: parent.right
            anchors.rightMargin: 45
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 300)
            horizontalAlignment: Text.AlignRight
            text: preferencesScreen.value(row.modelData)
            color: row.ink
            font.pixelSize: 32
            elide: Text.ElideRight
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !row.selected && row.ListView.view.currentIndex !== row.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) row.ListView.view.currentIndex = row.index
            onClicked: {
                row.ListView.view.currentIndex = row.index
                preferencesScreen.activate(row.modelData)
            }
        }
    }

    // A choice: a tick next to the one in use now
    component ChoiceRow: Rectangle {
        id: choice
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property color ink: selected ? "white" : "#222222"

        width: ListView.view.width
        height: 70
        color: selected ? "#008E00" : "transparent"

        TileIcon {
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            name: "check"
            color: choice.ink
            visible: choice.modelData.current
        }
        Text {
            x: 90
            anchors.verticalCenter: parent.verticalCenter
            text: choice.modelData.label
            color: choice.ink
            font.pixelSize: 36
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 45
            anchors.verticalCenter: parent.verticalCenter
            text: choice.modelData.detail
            color: choice.selected ? "white" : "#5A6064"
            font.pixelSize: 28
        }

        Column {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !choice.selected && choice.ListView.view.currentIndex !== choice.index + 1
            Rectangle { width: parent.width; height: 1; color: "#8E979A" }
            Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (Pointer.active) choice.ListView.view.currentIndex = choice.index
            onClicked: {
                choice.ListView.view.currentIndex = choice.index
                preferencesScreen.choose(choice.modelData)
            }
        }
    }
}