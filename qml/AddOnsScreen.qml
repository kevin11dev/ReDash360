import QtCore
import QtQuick

// Add-ons (on the games tab): emulators, launchers and other apps for gaming.
// A opens the ones you have. The rest you get from your app store (Discover
// or GNOME Software), Flathub in your browser, or on Windows their websites.
FocusScope {
    id: addOnsScreen
    visible: false

    property Item returnFocusTo: null
    readonly property bool windows: Qt.platform.os === "windows"
    readonly property var current: shown[list.currentIndex] || ({})

    // Each one: what it's for, how to spot it among your apps (find is tried
    // on each app's command and icon), its icon names, its Flathub ID and its
    // download page. only: "linux" or "windows" for the ones made for just one.
    readonly property var addOns: [
        { group: "Emulators", name: "RetroArch", about: "Lots of consoles in one",
          text: "Plays games from lots of consoles, each through its own core. Once it's installed, get cores in RetroArch: Main Menu > Online Updater > Core Downloader.",
          find: /retroarch/i, icon: "org.libretro.RetroArch,retroarch",
          flatpak: "org.libretro.RetroArch", site: "https://www.retroarch.com/?page=platforms" },
        { group: "Emulators", name: "PCSX2", about: "PlayStation 2",
          text: "Plays PlayStation 2 games, at higher resolutions than the console could manage.",
          find: /pcsx2/i, icon: "net.pcsx2.PCSX2,pcsx2",
          flatpak: "net.pcsx2.PCSX2", site: "https://pcsx2.net/downloads" },
        { group: "Emulators", name: "RPCS3", about: "PlayStation 3",
          text: "Plays PlayStation 3 games. It needs a fairly powerful PC.",
          find: /rpcs3/i, icon: "net.rpcs3.RPCS3,rpcs3",
          flatpak: "net.rpcs3.RPCS3", site: "https://rpcs3.net/download" },
        { group: "Emulators", name: "PPSSPP", about: "PSP",
          text: "Plays PSP games, and runs well even on modest PCs.",
          find: /ppsspp/i, icon: "org.ppsspp.PPSSPP,ppsspp",
          flatpak: "org.ppsspp.PPSSPP", site: "https://www.ppsspp.org/download" },
        { group: "Emulators", name: "xemu", about: "Original Xbox",
          text: "Plays games from the original Xbox.",
          find: /xemu/i, icon: "app.xemu.xemu,xemu",
          flatpak: "app.xemu.xemu", site: "https://xemu.app/" },
        { group: "Emulators", name: "Xenia", about: "Xbox 360",
          text: "Plays Xbox 360 games. Its website has the latest version and which games work.",
          find: /xenia/i, icon: "xenia,xenia-canary",
          site: "https://xenia.jp/" },
        { group: "Emulators", name: "Dolphin", search: "Dolphin Emulator", about: "GameCube and Wii",
          text: "Plays GameCube and Wii games, in HD if you like.",
          find: /dolphin-emu/i, icon: "org.DolphinEmu.dolphin-emu,dolphin-emu",
          flatpak: "org.DolphinEmu.dolphin-emu", site: "https://dolphin-emu.org/download/" },
        { group: "Emulators", name: "Cemu", about: "Wii U",
          text: "Plays Wii U games.",
          find: /cemu/i, icon: "info.cemu.Cemu,cemu",
          flatpak: "info.cemu.Cemu", site: "https://cemu.info/" },
        { group: "Emulators", name: "melonDS", about: "Nintendo DS",
          text: "Plays Nintendo DS games, with the two screens side by side or one above the other.",
          find: /melonds/i, icon: "net.kuribo64.melonDS,melonDS",
          flatpak: "net.kuribo64.melonDS", site: "https://melonds.kuribo64.net/downloads.php" },
        { group: "Emulators", name: "mGBA", about: "Game Boy Advance",
          text: "Plays Game Boy Advance games, plus Game Boy and Game Boy Color.",
          find: /mgba/i, icon: "io.mgba.mGBA,mgba",
          flatpak: "io.mgba.mGBA", site: "https://mgba.io/downloads.html" },
        { group: "Emulators", name: "ScummVM", about: "Classic adventure games",
          text: "Runs classic point-and-click adventures, like Monkey Island and Broken Sword, from the games' own files.",
          find: /scummvm/i, icon: "org.scummvm.ScummVM,scummvm",
          flatpak: "org.scummvm.ScummVM", site: "https://www.scummvm.org/downloads/" },
        { group: "Emulators", name: "DOSBox Staging", about: "DOS games",
          text: "Runs old DOS games.",
          find: /dosbox/i, icon: "io.github.dosbox-staging,dosbox-staging",
          flatpak: "io.github.dosbox-staging", site: "https://www.dosbox-staging.org/" },

        { group: "Launchers", name: "Steam", about: "Valve's store and launcher",
          text: "Your Steam games and the Steam store. On Linux, its Proton runs Windows games too.",
          find: /(^|\/)steam(-runtime)?( |$)|com\.valvesoftware\.Steam/i, icon: "com.valvesoftware.Steam,steam",
          flatpak: "com.valvesoftware.Steam", site: "https://store.steampowered.com/about/" },
        { group: "Launchers", name: "Heroic Games Launcher", search: "Heroic", about: "Epic, GOG and Amazon games",
          text: "Plays your games from Epic Games, GOG and Amazon.",
          find: /heroic/i, icon: "com.heroicgameslauncher.hgl,heroic",
          flatpak: "com.heroicgameslauncher.hgl", site: "https://heroicgameslauncher.com/downloads" },
        { group: "Launchers", name: "Faugus Launcher", about: "Windows games without Steam", only: "linux",
          text: "Runs Windows games with Proton, without needing Steam.",
          find: /faugus/i, icon: "io.github.Faugus.faugus-launcher,faugus-launcher",
          flatpak: "io.github.Faugus.faugus-launcher" },
        { group: "Launchers", name: "Lutris", about: "Games from everywhere", only: "linux",
          text: "Installs games from lots of stores and emulators, using install scripts made by its community.",
          find: /lutris/i, icon: "net.lutris.Lutris,lutris",
          flatpak: "net.lutris.Lutris" },
        { group: "Launchers", name: "Bottles", about: "Windows programs", only: "linux",
          text: "Runs Windows programs and game launchers on Linux, each in its own bottle.",
          find: /bottles/i, icon: "com.usebottles.bottles,bottles",
          flatpak: "com.usebottles.bottles" },
        { group: "Launchers", name: "Playnite", about: "Every launcher in one", only: "windows",
          text: "Puts the games from all your launchers and emulators in one library.",
          find: /playnite/i, icon: "playnite,playnite-desktop",
          site: "https://playnite.link/" },

        { group: "Tools", name: "ProtonUp-Qt", about: "Newer Proton versions", only: "linux",
          text: "Installs newer Proton and Wine versions, like Proton-GE, for Steam, Lutris and Heroic.",
          find: /pupgui2|protonup/i, icon: "net.davidotek.pupgui2,protonup-qt",
          flatpak: "net.davidotek.pupgui2" },
        { group: "Tools", name: "Discord", about: "Voice chat with friends",
          text: "Voice chat, messages and streaming with your friends.",
          find: /discord/i, icon: "com.discordapp.Discord,discord",
          flatpak: "com.discordapp.Discord", site: "https://discord.com/download" },
        { group: "Tools", name: "OBS Studio", about: "Record and stream",
          text: "Records your games, or streams them to Twitch or YouTube.",
          find: /(^|\/)obs( |$)|obsproject/i, icon: "com.obsproject.Studio,obs",
          flatpak: "com.obsproject.Studio", site: "https://obsproject.com/download" },
        { group: "Tools", name: "Moonlight", about: "Play from another PC",
          text: "Plays games streamed from another PC in your home, like a gaming PC in another room.",
          find: /moonlight/i, icon: "com.moonlight_stream.Moonlight,moonlight",
          flatpak: "com.moonlight_stream.Moonlight", site: "https://moonlight-stream.org/" },
        { group: "Tools", name: "Sunshine", about: "Stream this PC's games",
          text: "Streams this PC's games to Moonlight on your other devices.",
          find: /sunshine/i, icon: "dev.lizardbyte.app.Sunshine,sunshine",
          flatpak: "dev.lizardbyte.app.Sunshine", site: "https://github.com/LizardByte/Sunshine/releases" },
        { group: "Tools", name: "AntiMicroX", about: "Controller as mouse and keyboard",
          text: "Makes your controller work as a mouse and keyboard, for games and apps that don't support one.",
          find: /antimicrox/i, icon: "io.github.antimicrox.antimicrox,antimicrox",
          flatpak: "io.github.antimicrox.antimicrox", site: "https://github.com/AntiMicroX/antimicrox/releases" }
    ]

    // The ones made for this system
    readonly property var shown: addOns.filter(addOn => !addOn.only || addOn.only === (windows ? "windows" : "linux"))

    // The ones you have: each add-on's name -> its app ({name, command, icon})
    readonly property var installed: {
        AppLibrary.count                        // look again after a rescan
        const apps = AppLibrary.all()
        const found = {}
        for (const addOn of addOns) {
            const matches = apps.filter(app => addOn.find.test(app.command + " " + app.icon))
            // Its own entry, not a game shortcut made by it (Lutris makes those)
            found[addOn.name] = matches.find(app => app.name.toLowerCase().startsWith(addOn.name.toLowerCase()))
                                || matches[0] || null
        }
        return found
    }

    // Where "Get" takes you on Linux: your app store, searching for it
    readonly property string store: {
        AppLibrary.count
        const apps = AppLibrary.all()
        if (apps.some(app => /plasma-discover/.test(app.command)))
            return "Discover"
        if (apps.some(app => /gnome-software/.test(app.command)))
            return "GNOME Software"
        return ""
    }

    // ---- Icons and screenshots from Flathub ------------------------------------
    // For each add-on that's on Flathub, its icon and a screenshot, so you see
    // them before you install it. Where they are is kept for two weeks (in
    // ~/.cache/ReDash360/ReDash360/addons.conf), and the pictures stay on disk
    // with the other pictures from the internet.
    property var art: ({})                      // Flathub ID -> { icon, shot, when }

    Settings {
        id: artStore
        location: StandardPaths.writableLocation(StandardPaths.CacheLocation) + "/addons.conf"
        category: "flathub"
        property string art: "{}"
    }

    Component.onCompleted: {
        try {
            art = JSON.parse(artStore.art)
        } catch (error) {}
    }

    function fetchArt() {
        const twoWeeks = 14 * 24 * 60 * 60 * 1000
        for (const addOn of shown) {
            const id = addOn.flatpak
            if (!id || (art[id] && Date.now() - art[id].when < twoWeeks))
                continue
            const request = new XMLHttpRequest()
            request.onreadystatechange = function() {
                if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200)
                    return
                try {
                    const app = JSON.parse(request.responseText)
                    const found = Object.assign({}, art)
                    found[id] = { icon: app.icon || "", shot: screenshot(app.screenshots), when: Date.now() }
                    art = found
                    artStore.art = JSON.stringify(found)
                } catch (error) {}
            }
            request.open("GET", "https://flathub.org/api/v2/appstream/" + id)
            request.send()
        }
    }

    // Its main screenshot, or the first one that's wider than it's tall, at
    // about 750 pixels wide
    function screenshot(screenshots) {
        const all = screenshots || []
        const wide = shot => shot.sizes && shot.sizes.length > 0
                             && parseInt(shot.sizes[0].width) >= parseInt(shot.sizes[0].height)
        const chosen = all.find(shot => shot.default && wide(shot)) || all.find(wide) || all[0]
        if (!chosen || !chosen.sizes || chosen.sizes.length === 0)
            return ""
        const sizes = chosen.sizes.slice().sort((a, b) => parseInt(a.width) - parseInt(b.width))
        return (sizes.find(size => parseInt(size.width) >= 720) || sizes[sizes.length - 1]).src
    }

    function open() {
        returnFocusTo = Window.activeFocusItem
        AppLibrary.refresh()                    // see what's been installed since
        fetchArt()
        list.currentIndex = 0
        visible = true
        list.forceActiveFocus()
        list.positionViewAtBeginning()
        panelAnimation.restart()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    // "Discover", "Flathub" or "its website"
    function from(addOn) {
        if (windows || !addOn.flatpak)
            return "its website"
        return store || "Flathub"
    }

    function get(addOn) {
        const name = addOn.search || addOn.name
        if (windows || !addOn.flatpak)
            Qt.openUrlExternally(addOn.site)
        else if (store === "Discover")
            Launcher.run("plasma-discover --search \"" + name + "\"")
        else if (store === "GNOME Software")
            Launcher.run("gnome-software --search \"" + name + "\"")
        else
            Qt.openUrlExternally("https://flathub.org/apps/" + addOn.flatpak)
    }

    // Get one by name, from elsewhere on the dashboard (Discord on the social tab)
    function getNamed(name) {
        const addOn = addOns.find(addOn => addOn.name === name)
        if (addOn)
            get(addOn)
    }

    // A: open it, or get it. Getting it keeps this screen open, so it says
    // Installed when you come back.
    function activate(addOn) {
        if (!addOn || !addOn.name)
            return
        const app = installed[addOn.name]
        if (app) {
            close()
            Launcher.openApp(app.name, app.command, app.icon)
        } else {
            get(addOn)
        }
    }

    // Back from your app store: look for what you installed
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (addOnsScreen.visible && Qt.application.state === Qt.ApplicationActive)
                AppLibrary.refresh()
        }
    }

    Keys.onEscapePressed: close()

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        text: "Add-ons"
        color: "white"
        font.pixelSize: 50
    }

    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719

        Rectangle {
            width: 760; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: addOnsScreen.shown
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: AddOnRow {}

                Keys.onReturnPressed: addOnsScreen.activate(addOnsScreen.current)
                Keys.onEnterPressed: addOnsScreen.activate(addOnsScreen.current)
            }
        }

        // ---- The one you're on, bigger ----
        Rectangle {
            x: 760
            width: 560; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            Picture {
                x: 40; y: 40
                width: 480; height: 270
                addOn: addOnsScreen.current
                iconSize: 160
                screenshot: true
            }
            Column {
                x: 40; y: 334
                width: parent.width - 80
                spacing: 10

                Text {
                    width: parent.width
                    text: addOnsScreen.current.name || ""
                    color: "#2E3336"
                    font.pixelSize: 32
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: addOnsScreen.current.about || ""
                    color: "#4A5155"
                    font.pixelSize: 24
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: addOnsScreen.current.text || ""
                    color: "#3A4044"
                    font.pixelSize: 25
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                }
            }

            // Installed, or where it comes from
            Row {
                x: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 34
                spacing: 10
                readonly property bool have: !!addOnsScreen.installed[addOnsScreen.current.name]

                TileIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30
                    name: parent.have ? "check" : "download"
                    color: "#2E3336"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.have ? "Installed" : addOnsScreen.current.name ? "Get it from " + addOnsScreen.from(addOnsScreen.current) : ""
                    color: "#2E3336"
                    font.pixelSize: 24
                }
            }
        }

        // Like the 360's lists: the panel grows out of the middle
        ParallelAnimation {
            id: panelAnimation
            NumberAnimation { target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250 }
        }
    }

    Row {
        x: 138; y: 973
        spacing: 30
        ButtonHint { button: "A"; label: addOnsScreen.installed[addOnsScreen.current.name] ? "Open" : "Get" }
        ButtonHint { button: "B"; label: "Back" }
    }

    // ---- Pieces ----------------------------------------------------------------

    // Its icon on green: the app's own if you have it, otherwise Flathub's or
    // your icon theme's, otherwise a picture for its group. The big one shows
    // its screenshot, with the icon in the corner.
    component Picture: Rectangle {
        id: picture
        property var addOn: ({})
        property int iconSize: 40
        property bool screenshot: false

        readonly property var app: addOnsScreen.installed[addOn.name] || null
        readonly property var online: addOnsScreen.art[addOn.flatpak] || ({})

        // The icons to try, best first: on to the next if one doesn't load
        readonly property var icons: [app && app.icon ? "image://appicon/" + app.icon : "",
                                      online.icon || "",
                                      addOn.icon ? "image://appicon/" + addOn.icon : ""].filter(icon => icon !== "")
        property int tried: 0
        onIconsChanged: tried = 0

        color: "#009000"

        Image {
            id: shot
            anchors.fill: parent
            source: picture.screenshot && picture.online.shot ? picture.online.shot : ""
            sourceSize.width: 960
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop
            asynchronous: true
            visible: status === Image.Ready
        }

        Rectangle {
            id: iconBox
            readonly property bool corner: shot.visible
            x: corner ? 16 : 0
            y: corner ? parent.height - height - 16 : 0
            width: corner ? 104 : parent.width
            height: corner ? 104 : parent.height
            color: corner ? "#009000" : "transparent"
            border.color: corner ? "#B0FFFFFF" : "transparent"
            border.width: corner ? 2 : 0

            Image {
                id: image
                anchors.centerIn: parent
                width: iconBox.corner ? 80 : picture.iconSize
                height: width
                source: picture.icons[picture.tried] || ""
                sourceSize.width: picture.iconSize * 2
                sourceSize.height: picture.iconSize * 2
                asynchronous: true
                visible: status === Image.Ready && implicitWidth > 0
                onStatusChanged: {
                    const failed = status === Image.Error || (status === Image.Ready && implicitWidth === 0)
                    if (failed && picture.tried < picture.icons.length - 1)
                        picture.tried++
                }
            }
            TileIcon {
                anchors.centerIn: parent
                width: image.width * 0.8; height: image.height * 0.8
                name: picture.addOn.group === "Emulators" ? "console"
                    : picture.addOn.group === "Launchers" ? "controller" : "sliders"
                visible: !image.visible
            }
        }
    }

    // One add-on: its icon, name and what it's for, with its group's name
    // above the first one of each group
    component AddOnRow: Item {
        id: row
        required property int index
        required property var modelData
        readonly property bool selected: ListView.isCurrentItem && ListView.view.activeFocus
        readonly property bool firstOfGroup: index === 0 || addOnsScreen.shown[index - 1].group !== modelData.group

        width: ListView.view.width
        height: (firstOfGroup ? 56 : 0) + 89

        Text {
            x: 24
            y: 14
            visible: row.firstOfGroup
            text: row.modelData.group
            color: "#5A6064"
            font.pixelSize: 24
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 89
            color: row.selected ? "#008E00" : "transparent"

            Picture {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64
                addOn: row.modelData
                iconSize: 48
            }
            Column {
                x: 112
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (installedMark.visible ? installedMark.width + 30 : 30)
                spacing: 2
                Text {
                    width: parent.width
                    text: row.modelData.name
                    color: row.selected ? "white" : "#222222"
                    font.pixelSize: 28
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: row.modelData.about
                    color: row.selected ? "#E0FFFFFF" : "#5A6064"
                    font.pixelSize: 22
                    elide: Text.ElideRight
                }
            }

            Row {
                id: installedMark
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: !!addOnsScreen.installed[row.modelData.name]
                TileIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24
                    name: "check"
                    color: row.selected ? "white" : "#3A4044"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Installed"
                    color: row.selected ? "white" : "#3A4044"
                    font.pixelSize: 22
                }
            }

            Column {
                anchors.bottom: parent.bottom
                width: parent.width
                readonly property var next: addOnsScreen.shown[row.index + 1]
                visible: !row.selected && (row.ListView.view.currentIndex !== row.index + 1
                                           || (next !== undefined && next.group !== row.modelData.group))
                Rectangle { width: parent.width; height: 1; color: "#8E979A" }
                Rectangle { width: parent.width; height: 1; color: "#C4CCCF" }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: if (Pointer.active) row.ListView.view.currentIndex = row.index
                onClicked: {
                    row.ListView.view.currentIndex = row.index
                    addOnsScreen.activate(row.modelData)
                }
            }
        }
    }
}