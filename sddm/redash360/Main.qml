import QtQuick

// ReDash360's login screen (an SDDM theme), laid out like the Xbox 360's
// Sign In screen (measured from a video of the console at 1920x1080): each
// profile stands next to its gamer picture and name. Left/right pick a
// profile and A (Enter) signs in, asking for the password if it has one.
// X changes which desktop starts, Y turns the PC off or restarts it.
//
// SDDM gives the theme sddm (signing in, turning off), userModel (who can
// sign in), sessionModel (the desktops), keyboard, config (theme.conf) and
// primaryScreen. Each person's gamerpic and avatar come from ReDash360,
// which copies them to ~/.redash360 for this screen (loginscreen.cpp).
Rectangle {
    id: root

    // The dashboard's grey (Main.qml)
    gradient: Gradient {
        GradientStop { position: 0.00; color: "#525357" }
        GradientStop { position: 0.20; color: "#65666a" }
        GradientStop { position: 0.40; color: "#808185" }
        GradientStop { position: 0.60; color: "#a0a0a2" }
        GradientStop { position: 0.78; color: "#b3b3b5" }
        GradientStop { position: 0.88; color: "#acadaf" }
        GradientStop { position: 1.00; color: "#8a8b8f" }
    }

    property int session: Math.max(0, sessionModel.lastIndex)    // which desktop starts
    property string signingInAs: ""                             // set while SDDM checks the password
    property string who: ""                                     // the profile asking for a password
    property string wrongPassword: ""

    readonly property string sessionName: {
        sessionNames.count                      // look again once the names are in
        const item = sessionNames.itemAt(session)
        return item ? item.name : ""
    }

    // A: sign in, straight away when there's no password to type
    function choose(profile) {
        if (!profile || signingInAs !== "")
            return
        wrongPassword = ""
        if (profile.needsPassword) {
            who = profile.name
            passwordCard.open()
        } else {
            signIn(profile.name, "")
        }
    }

    function signIn(name, password) {
        signingInAs = name
        sddm.login(name, password, session)
    }

    // X: the next desktop, round and round
    function nextSession() {
        if (sessionNames.count > 1)
            session = (session + 1) % sessionNames.count
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            const name = root.signingInAs
            root.signingInAs = ""
            root.who = name
            root.wrongPassword = "That password didn't work. Try again."
            passwordCard.open()
        }
        function onInformationMessage(message) {
            info.text = message
        }
    }

    Component.onCompleted: profiles.forceActiveFocus()

    Image {
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // The desktops' names, for the X hint
    Item {
        visible: false
        Repeater {
            id: sessionNames
            model: sessionModel
            Item { required property string name }
        }
    }

    Item {
        id: canvas
        width: 1920
        height: 1080
        anchors.centerIn: parent
        scale: Math.min(root.width / width, root.height / height)
        visible: primaryScreen                  // the other screens just get the background

        // Top right: what this screen is, and the PC's name
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 145
            y: 118

            Text {
                anchors.right: parent.right
                text: "Sign In"
                color: "white"
                font.pixelSize: 52
            }
            Text {
                anchors.right: parent.right
                text: sddm.hostName
                color: "white"
                font.pixelSize: 30
            }
        }

        // The profiles, side by side in the middle, three at a time; more scroll
        ListView {
            id: profiles
            y: 318
            x: 350
            width: Math.min(count, 3) * 503
            height: 560
            clip: count > 3
            orientation: ListView.Horizontal
            interactive: false
            keyNavigationEnabled: true
            highlightMoveDuration: 250
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: width - 503
            model: userModel
            currentIndex: Math.max(0, userModel.lastIndex)     // whoever signed in last
            focus: true

            delegate: Profile {}

            Keys.onReturnPressed: root.choose(currentItem)
            Keys.onEnterPressed: root.choose(currentItem)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_X) {
                    root.nextSession()
                    event.accepted = true
                } else if (event.key === Qt.Key_Y) {
                    powerCard.open()
                    event.accepted = true
                }
            }
        }

        Text {
            id: info                            // messages from SDDM
            anchors.right: parent.right
            anchors.rightMargin: 145
            y: 990
            color: "white"
            font.pixelSize: 26
            opacity: 0.8
        }

        Row {
            x: 138; y: 973
            spacing: 30
            visible: root.signingInAs === ""

            ButtonHint { button: "A"; label: "Select" }
            Hint {
                button: "X"
                label: root.sessionName
                visible: sessionNames.count > 1
                onClicked: root.nextSession()
            }
            Hint {
                button: "Y"
                label: "Turn Off"
                visible: sddm.canPowerOff || sddm.canReboot
                onClicked: powerCard.open()
            }
        }

        // "Enter the password for ..."
        Card {
            id: passwordCard
            anchors.fill: parent
            title: "Sign In"
            message: "Enter the password for " + root.who + "."
            asksPassword: true
            problem: root.wrongPassword !== "" ? root.wrongPassword
                   : keyboard.capsLock ? "Caps Lock is on." : ""
            defaultIndex: 0
            options: [
                { label: "Sign In", run: () => root.signIn(root.who, passwordCard.password) },
                { label: "Cancel", run: () => {} }
            ]
        }

        Card {
            id: powerCard
            anchors.fill: parent
            title: "Turn Off"
            message: "What would you like to do?"
            defaultIndex: 0
            options: (sddm.canPowerOff ? [{ label: "Turn Off", run: () => sddm.powerOff() }] : [])
                     .concat(sddm.canReboot ? [{ label: "Restart", run: () => sddm.reboot() }] : [])
                     .concat([{ label: "Cancel", run: () => {} }])
        }
    }

    // One profile: the figure, and beside it the gamer picture, name and
    // whether it has a password. The one you're on stands out.
    component Profile: Item {
        id: profile
        required property int index
        required property string name
        required property string realName
        required property string icon
        required property string homeDir
        required property bool needsPassword
        readonly property string shared: "file://" + homeDir + "/.redash360/"    // from ReDash360
        readonly property bool current: ListView.isCurrentItem
        readonly property bool signingIn: root.signingInAs === name

        width: 503
        height: 560
        opacity: root.signingInAs !== "" && !signingIn ? 0 : 1    // signing in: the others go
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Avatar {
            lit: profile.current
            source: profile.shared + "avatar"
        }

        Column {
            x: 205; y: 52
            width: 290

            Text {                              // "SIGNING IN..." above the picture, like the 360
                height: 27
                text: "SIGNING IN..."
                color: "white"
                font.pixelSize: 26
                font.bold: true
                opacity: profile.signingIn ? 1 : 0
            }

            Item { width: 1; height: 16 }

            Row {
                spacing: 14

                // Gamer picture: their gamerpic from ReDash360, or the account's
                // picture, or its first letter on green
                Rectangle {
                    width: 56; height: 56
                    color: "#107C10"
                    Text {
                        anchors.centerIn: parent
                        text: profile.name.charAt(0).toUpperCase()
                        color: "white"
                        font.pixelSize: 32
                    }
                    Image {
                        anchors.fill: parent
                        source: profile.icon
                        visible: status === Image.Ready && !gamerpic.visible
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 112
                        asynchronous: true
                    }
                    AnimatedImage {
                        id: gamerpic
                        anchors.fill: parent
                        source: profile.shared + "gamerpic"
                        visible: status === AnimatedImage.Ready
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                TileIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30
                    name: profile.needsPassword ? "lock" : ""
                }
            }

            Item { width: 1; height: 22 }

            Text {
                width: parent.width
                text: profile.name
                color: "white"
                font.pixelSize: 36
                font.weight: Font.Light
                elide: Text.ElideRight
            }

            Item { width: 1; height: 50 }

            Text {
                width: parent.width
                text: profile.realName
                visible: text !== "" && text !== profile.name
                color: "white"
                font.pixelSize: 30
                elide: Text.ElideRight
            }
        }

        // Clicking a profile signs in as it. (Pointing at one doesn't pick it:
        // the screen moving under a pointer that's standing still would.)
        MouseArea {
            anchors.fill: parent
            onClicked: {
                profile.ListView.view.currentIndex = profile.index
                root.choose(profile)
            }
        }
    }

    // A button hint you can also click
    component Hint: Item {
        property alias button: hint.button
        property alias label: hint.label
        signal clicked()

        implicitWidth: hint.width
        implicitHeight: hint.height

        ButtonHint { id: hint }
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }
}
