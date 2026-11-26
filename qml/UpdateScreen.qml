import QtQuick

// Updating ReDash360 (Settings > System, Y; or Update Now when a new version
// pops up): what's new on GitHub, and installing it. The password is asked
// for with the on-screen keyboard and goes to sudo for this update only.
FocusScope {
    id: updateScreen
    visible: false

    property Item returnFocusTo: null

    // What A does now: "Update Now", "Try Again", "Restart Now", or nothing
    readonly property string action: Updater.state === "done" ? "Restart Now"
                                   : !Updater.canInstall ? ""
                                   : Updater.state === "available" ? "Update Now"
                                   : Updater.state === "failed" ? "Try Again" : ""
    readonly property bool busy: Updater.state === "checking" || Updater.state === "updating"
    readonly property int shown: 8              // changes listed; then "and 3 more"

    function open(startNow) {
        returnFocusTo = Window.activeFocusItem
        visible = true
        forceActiveFocus()
        panelAnimation.restart()
        if (Updater.state === "unknown" || Updater.state === "offline" || Updater.state === "upToDate")
            Updater.check()
        if (startNow)
            askPassword()
    }

    function close() {
        visible = false
        if (returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function askPassword() {
        if (!Updater.canInstall || (Updater.state !== "available" && Updater.state !== "failed"))
            return
        keyboard.open({ title: "Password", password: true, maxLength: 128, doneLabel: "Update",
                        prompt: "Enter your password to install the update. It's only used for this update, and isn't saved.",
                        done: password => { if (password !== "") Updater.install(password) } })
    }

    function act() {
        if (Updater.state === "done")
            Updater.restart()
        else if (action !== "")
            askPassword()
    }

    // When there's nothing new to list, why
    function emptyText() {
        switch (Updater.state) {
        case "checking": return "Looking for updates..."
        case "upToDate": return "You have the newest version."
        case "offline": return "Couldn't reach GitHub. Check the internet connection, then press Y to look again."
        case "unknown": return Updater.version === ""
                ? "This version doesn't know which one it is, so it can't look for updates."
                : "This version isn't one from GitHub (a build of your own, or not installed), so it doesn't look for updates."
        }
        return ""
    }

    Keys.onEscapePressed: close()
    Keys.onReturnPressed: act()
    Keys.onEnterPressed: act()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Y && !busy && Updater.state !== "done") {
            Updater.check()
            event.accepted = true
        }
    }

    // Stops the mouse reaching the dashboard underneath
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        x: 142
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 120
        text: "Update ReDash360"
        color: "white"
        font.pixelSize: 50
    }

    Item {
        id: panel
        x: 300; y: 171
        width: 1320; height: 719

        // ---- What's new ----
        Rectangle {
            width: 760; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F4FBFA" }
                GradientStop { position: 1.0; color: "#D5DFE0" }
            }

            Text {
                x: 45; y: 26
                text: "What's New"
                color: "#2E3336"
                font.pixelSize: 36
            }

            Column {
                x: 45; y: 96
                width: parent.width - 90
                Repeater {
                    model: Updater.changes.slice(0, updateScreen.shown)
                    Item {
                        required property var modelData
                        width: parent.width
                        height: 72
                        Text {
                            width: parent.width
                            text: parent.modelData.title
                            color: "#222222"
                            font.pixelSize: 30
                            elide: Text.ElideRight
                        }
                        Text {
                            y: 36
                            visible: parent.modelData.time > 0
                            text: News.ago(parent.modelData.time)
                            color: "#5A6064"
                            font.pixelSize: 22
                        }
                    }
                }
                Text {
                    visible: Updater.changes.length > updateScreen.shown
                    text: "and " + (Updater.changes.length - updateScreen.shown) + " more"
                    color: "#5A6064"
                    font.pixelSize: 26
                }
            }

            Text {
                x: 45; y: 96
                width: parent.width - 90
                visible: Updater.changes.length === 0
                text: updateScreen.emptyText()
                color: "#3A4044"
                font.pixelSize: 30
                wrapMode: Text.Wrap
            }
        }

        // ---- This version, the newest, and installing it ----
        Rectangle {
            x: 760
            width: 560; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C3C9CD" }
                GradientStop { position: 1.0; color: "#9EA6AA" }
            }

            Column {
                x: 40; y: 26
                width: parent.width - 80
                spacing: 6
                Text { text: "This version"; color: "#3A4044"; font.pixelSize: 24 }
                Text { text: Updater.version || "Unknown"; color: "#2E3336"; font.pixelSize: 36 }
                Item { width: 1; height: 14 }
                Text { text: "Newest"; color: "#3A4044"; font.pixelSize: 24; visible: Updater.latest !== "" }
                Text { text: Updater.latest; color: "#2E3336"; font.pixelSize: 36; visible: Updater.latest !== "" }
            }

            Column {
                x: 40; y: 300
                width: parent.width - 80
                spacing: 18

                // Installing: what it's doing, and how far along
                Text {
                    visible: Updater.state === "updating" || Updater.state === "done"
                    text: Updater.state === "done" ? "Installed" : Updater.step + "..."
                    color: "#2E3336"
                    font.pixelSize: 36
                }
                Rectangle {
                    visible: Updater.state === "updating" || Updater.state === "done"
                    width: parent.width; height: 22
                    color: "#2B3033"
                    Rectangle {
                        width: parent.width * Updater.progress
                        height: parent.height
                        color: "#6BD12B"
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Updater.state === "failed" || Updater.error !== "" ? "#A01E14" : "#2E3336"
                    font.pixelSize: 28
                    text: {
                        switch (Updater.state) {
                        case "updating": return Math.round(Updater.progress * 100) + "%. You can keep using the "
                                                + "dashboard, but don't turn the PC off."
                        case "done": return "Restart ReDash360 to use the new version."
                        case "failed": return Updater.error
                        case "available":
                            if (Updater.error !== "")
                                return Updater.error
                            return Updater.canInstall
                                ? Updater.changes.length + (Updater.changes.length === 1 ? " new change" : " new changes")
                                  + ", ready to install. It takes a few minutes."
                                : "To update, get the newest code from GitHub and build it again, as in the README."
                        }
                        return ""
                    }
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
        ButtonHint { button: "A"; label: updateScreen.action; visible: updateScreen.action !== "" }
        ButtonHint { button: "B"; label: "Back" }
        ButtonHint { button: "Y"; label: "Check Again"; visible: !updateScreen.busy && Updater.state !== "done" }
    }

    Keyboard {
        id: keyboard
        anchors.fill: parent
    }
}