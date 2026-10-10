import QtQuick

FocusScope{
    id: power
    visible: false

    property Item returnFocusTo: null

    readonly property bool onWindows: Qt.platform.os === "windows"
    readonly property var options: [
        {label: "Turn Off", run: () => Launcher.run(power.onWindows ? "shutdown /s /t 0" : "systemctl poweroff")},
        {label: "Restart", run: () => Launcher.run(power.onWindows ? "shutdown /r /t 0" : "systemctl reboot")},
        {label: "Exit to Desktop", run: () => Qt.quit()},
        {label: "Cancel", run: () => {}}
    ]

    function open() {
        returnFocusTo = Window.activeFocusItem
        list.currentIndex = 0
        visible = true
        list.forceActiveFocus()
        fadeIn.restart()
    }

    function close() {
        visible = false
        if(returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    function choose(index) {
        close()
        options[index].run()
    }

    NumberAnimation {id: fadeIn; target: power; property: "opacity"; from: 0; to: 1; duration: 200}

    Rectangle{
        anchors.fill: parent
        color: "#C0000000"
        MouseArea{
            anchors.fill: parent
            hoverEnabled: true
            onClicked: power.close()
        }
    }

    Rectangle{
        id: panel
        x: 548
        y: 340
        width: 823
        height: 112 + list.height + 24
        gradient: Gradient{
            GradientStop{position: 0.0; color: "#F7FDFD"}
            GradientStop{position: 1.0; color: "#D2DDDE"}
        }

        Text{
            x: 32; y:26
            text: "Turn Off"
            color: "#111111"
            font.pixelSize: 40
        }

        Text{
            x: 32; y:76
            text: "What would you like to do?"
            color: "#555555"
            font.pixelSize: 26
        }

        ListView{
            id: list
            y: 112
            width: parent.width
            height: count * 63
            interactive: false
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            model: power.options

            delegate: Rectangle{
                id: row
                required property int index
                required property var modelData
                readonly property bool selected: ListView.isCurrentItem

                width: ListView.view.width
                height: 63
                color: selected ? "#008E00" : "#F5FBFD"

                Rectangle{
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 2
                    color: "#CED4D6"
                    visible: !row.selected
                }

                Text{
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: row.selected ? "white" : "#111111"
                    font.pixelSize: 32
                }

                MouseArea{
                    anchors.fill: parent
                    onClicked: power.choose(row.index)
                }
            }

            Keys.onReturnPressed: power.choose(currentIndex)
            Keys.onEnterPressed: power.choose(currentIndex)
            Keys.onEscapePressed: power.close()
        }
    }

    Row{
        x: 548
        y: panel.y + panel.height + 18
        spacing: 30
        ButtonHint{button: "A"; label: "Select"}
        ButtonHint{button: "B"; label: "Back"}
    }
}