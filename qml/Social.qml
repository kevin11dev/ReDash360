import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

TilePage {
    id: root

    // Coming to this tab (or back from a game) reads Steam's files again,
    // so achievements you just unlocked show up
    onActiveFocusChanged: if (activeFocus) Achievements.refresh()

    // Your Discord app (Vesktop is Discord too), if you have it. Windows has
    // no list of apps, so there Discord's own link is tried instead.
    readonly property var discord: {
        AppLibrary.count                        // look again after a rescan
        const apps = AppLibrary.all().filter(app => /discord|vesktop/i.test(app.command + " " + app.icon))
        return apps.find(app => /^discord/i.test(app.name)) || apps[0] || null
    }

    // Discord, or when it isn't installed, a card offering to get it
    function openDiscord() {
        AppLibrary.refresh()                    // installed it just now?
        if (discord)
            Launcher.openApp(discord.name, discord.command, discord.icon)
        else if (Qt.platform.os !== "windows" || !Qt.openUrlExternally("discord://-/channels/@me"))
            root.installRequested("Discord")
    }

    Tile{                                       //Discord
        id: discordTile
        label: "Discord"
        icon: discordMark.found ? "" : "person"
        column: 0; row: 0
        focus: true
        onActivated: root.openDiscord()

        // Discord's face from its icon, bigger than an app icon, like the
        // dashboard's own icons
        WhiteParts {
            id: discordMark
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            width: 120; height: 120
            z: 2
            source: root.discord && root.discord.icon ? "image://appicon/" + root.discord.icon : ""
        }
    }

    Tile{                                       //My Profile
        id: myProfileTile
        label: "My Profile"
        icon: "account"
        column: 0; row: 1
        onActivated: root.profileRequested()
    }

    Tile{                                       //Sign Out
        id: signOutTile
        label: "Sign Out"
        icon: "signin"
        column: 0; row: 2
        onActivated: root.signOutRequested()
    }

    Column {
        x: 340; y: 30
        spacing: 2

        Text{
            text: UserProfile.gamertag
            color: "white"
            font.pixelSize: 44
        }

        // Where the 360 showed your gamerscore: the achievements you've unlocked
        // in your installed Steam games. Without Steam (or on Windows) your game count
        Row{
            spacing: 10
            opacity: 0.8

            Text{
                id: score
                text: Achievements.total > 0
                      ? Achievements.total
                      : GameLibrary.count + (GameLibrary.count === 1 ? " game" : " games")
                color: "white"
                font.pixelSize: 30
            }

            // A white circle with a star cut out of it, like the 360's G
            // Centred on the digits themselves, not on the whole line of text
            Item{
                readonly property rect digits: scoreMetrics.tightBoundingRect("0123456789")
                width: 24; height: 24
                y: score.baselineOffset + digits.y + digits.height / 2 - height / 2
                visible: Achievements.total > 0

                Shape{
                    anchors.centerIn: parent
                    width: 48; height: 48
                    scale: parent.width / 48
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath{
                        fillColor: "white"
                        strokeColor: "transparent"
                        fillRule: ShapePath.OddEvenFill // the star inside the circle stays empty
                        PathSvg{
                            path: "M24,0 A24,24 0 1,1 24,48 A24,24 0 1,1 24,0 Z " +
                                  "M24.0,12.3 L27.3,20.8 L36.4,21.3 L29.3,27.0 L31.6,35.9 " +
                                  "L24.0,30.9 L16.4,35.9 L18.7,27.0 L11.6,21.3 L20.7,20.8 Z"
                        }
                    }
                }
            }
        }
    }

    FontMetrics{
        id: scoreMetrics
        font: score.font
    }

    // Your 9 newest achievements, newest top left, like the 360's
    Grid {
        id: achievementGrid
        x: 342; y: 135
        columns: 3
        spacing: 5
        visible: Achievements.total > 0

        Repeater{
            model: 9

            Rectangle{
                id: slot
                required property int index
                readonly property var achievement: Achievements.recent[index]

                width: 54; height: 54
                radius: 5
                color: "#33ffffff"              // empty slot, or while the icon downloads

                Image{
                    id: icon
                    anchors.fill: parent
                    source: slot.achievement ? slot.achievement.icon : ""
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    // Rounded corners: only the parts inside the rounded mask show
                    layer.enabled: true
                    layer.effect: MultiEffect{
                        maskEnabled: true
                        maskSource: roundedMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                Item{
                    id: roundedMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false

                    Rectangle{
                        anchors.fill: parent
                        radius: slot.radius
                    }
                }

                // The thin silver edge around each icon
                Rectangle{
                    anchors.fill: parent
                    radius: slot.radius
                    color: "transparent"
                    border.color: "#b0ffffff"
                    border.width: 1
                }

                // No internet: the icons come from Steam's servers, so show a star
                TileIcon{
                    anchors.centerIn: parent
                    width: 28; height: 28
                    name: "star"
                    opacity: 0.5
                    visible: slot.achievement !== undefined && icon.status !== Image.Ready
                }
            }
        }
    }

    AnimatedImage{
        id: avatar
        x: achievementGrid.visible ? 525 : 360
        y: achievementGrid.visible ? 40 : 150
        width: achievementGrid.visible ? 340 : 420
        height: achievementGrid.visible ? 560 : 500
        source: UserProfile.avatar
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        smooth: implicitWidth * 2 > width
        asynchronous: true
        playing: visible
    }

    TileIcon{
        x: avatar.x + (avatar.width - 300) / 2
        y: avatar.y + avatar.height - 340
        width: 300; height: 300
        name: "person"
        opacity: 0.3
        visible: UserProfile.avatar === ""
    }

    // An app's icon (from your icon theme) with only its white parts kept, in
    // white: Discord's face without its blue circle, so it sits on the green
    // like the dashboard's own icons. found: there was something white in it.
    component WhiteParts: Canvas {
        id: mark
        property string source
        property bool found: false

        onSourceChanged: {
            found = false
            if (source !== "")
                loadImage(source)
            requestPaint()
        }
        onImageLoaded: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (source === "" || !isImageLoaded(source))
                return
            ctx.drawImage(source, 0, 0, width, height)
            const picture = ctx.getImageData(0, 0, width, height)
            const pixels = picture.data
            let white = 0
            for (let i = 0; i < pixels.length; i += 4) {
                // How white a pixel is: its darkest colour. Discord's blue is
                // far from white, its face all the way there
                const darkest = Math.min(pixels[i], pixels[i + 1], pixels[i + 2])
                const whiteness = Math.max(0, Math.min(1, (darkest - 120) / 135))
                pixels[i + 3] = Math.round(pixels[i + 3] * whiteness)
                pixels[i] = pixels[i + 1] = pixels[i + 2] = 255
                if (pixels[i + 3] > 128)
                    white++
            }
            ctx.clearRect(0, 0, width, height)
            ctx.putImageData(picture, 0, 0, 0, 0, width, height)   // with just (picture, 0, 0) Qt draws nothing
            found = white > 0
        }
    }
}