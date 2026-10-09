import QtQuick
import Qt.labs.folderlistmodel

FocusScope{
    id: profileScreen
    visible: false

    property Item returnFocusTo: null

    readonly property var options: [
        {label: "Change Gamertag", run: ()=> profileScreen.editGamertag()},
        {label: "Change Avatar", run: ()=> picker.open()},
        {label: "Remove Avatar", run: ()=> UserProfile.setAvatar("")},
        {label: "Open Avatar Folder", run: ()=> Qt.openUrlExternally(UserProfile.avatarFolder)}
    ]

    function open() {
        returnFocusTo = Window.activeFocusItem
        picker.visible = false
        nameField.visible = false
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

    function editGamertag(){
        nameField.text = UserProfile.gamertag
        nameField.visible = true
        nameField.selectAll()
        nameField.forceActiveFocus()
    }

    NumberAnimation {
        id: fadeIn
        target: profileScreen
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    Keys.onEscapePressed: close()

    MouseArea{
        anchors.fill: parent
        hoverEnabled: true
    }

    Item {
        anchors.fill: parent
        visible: !picker.visible

        Text{
            anchors.right: parent.right
            anchors.rightMargin: 145
            y: 118
            text: "My Profile"
            color: "white"
            font.pixelSize: 52
        }

        Item{
            id: stage
            x: 200; y: 280
            width: 520; height:600

            Rectangle{
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 300; height: 36
                radius: 18
                color: Qt.rgba(0, 0, 0, 0.25)
            }

            Avatar{
                anchors.fill: parent
                anchors.bottomMargin: 18
                source: UserProfile.avatar
            }

            TileIcon{
                anchors.centerIn: parent
                width: 300; height: 300
                name: "person"
                opacity: 0.35
                visible: UserProfile.avatar === ""
            }
        }

        Text{
            anchors.horizontalCenter: stage.horizontalCenter
            y: 190
            text: UserProfile.gamertag
            color: "white"
            font.pixelSize: 48
            visible: !nameField.visible
        }

        TextInput{
            id: nameField
            anchors.horizontalCenter: stage.horizontalCenter
            y: 190
            width: 520
            horizontalAlignment: TextInput.AlignHCenter
            color: "white"
            selectionColor: "#107C10"
            font.pixelSize: 48
            maximumLength: 20
            visible: false

            Rectangle{
                anchors.top: parent.bottom
                width: parent.width; height: 3
                color: "white"
            }

            function finish(save) {
                if(save)
                    UserProfile.setGamertag(text)
                visible = false
                list.forceActiveFocus()
            }

            Keys.onReturnPressed: finish(true)
            Keys.onEnterPressed: finish(true)
            Keys.onEscapePressed: finish(false)
        }

        Rectangle {
            x: 900; y: 304
            width: 823
            height: list.height + 24
            gradient: Gradient {
                GradientStop{position: 0.0; color: "#F7FDFD"}
                GradientStop{position: 1.0; color: "#D2DDDE"}
            }
            
            ListView{
                id: list
                width: parent.width
                height: count * 63
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: profileScreen.options
                
                delegate: Rectangle{
                    id: row
                    required property int index
                    required property var modelData
                    readonly property bool selected: ListView.isCurrentItem && list.activeFocus

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
                        onClicked: {
                            list.currentIndex = row.index
                            row.modelData.run()
                        }
                    }
                }

                Keys.onReturnPressed: model[currentIndex].run()
                Keys.onEnterPressed: model[currentIndex].run()
            }
        }

        Row{
            x: 180
            y: 990
            spacing: 40
            ButtonHint{button: "A"; label: nameField.visible ? "Save" : "Select"}
            ButtonHint{button: "B"; label: nameField.visible ? "Cancel" : "Back"}
        }
    }

    FocusScope{
        id: picker
        anchors.fill: parent
        visible: false

        function open() {
            visible = true
            grid.currentIndex = 0
            grid.forceActiveFocus()
        }

        function close() {
            visible = false
            list.forceActiveFocus()
        }

        Keys.onEscapePressed: close()

        Text{
            anchors.right: parent.right
            anchors.rightMargin: 145
            y: 118
            text: "Choose an Avatar"
            color: "white"
            font.pixelSize: 52
        }

        Text{
            anchors.centerIn: parent
            visible: grid.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: "Put GIF or PNG files in \n~/.local/share/ReDash360/avatars"
            color: "white"
            font.pixelSize: 40
            font.weight: Font.Light
        }

        GridView{
            id: grid
            y: 280
            width: parent.width
            height: 2 * cellHeight
            flow: GridView.FlowTopToBottom
            cellWidth: 313
            cellHeight: 293
            leftMargin: 195
            rightMargin: 195
            keyNavigationEnabled: true
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: 195
            preferredHighlightEnd: width - 500
            highlightMoveDuration: 200

            model: FolderListModel{
                folder: UserProfile.avatarFolder
                nameFilters: ["*.gif", "*.png", "*.webp", "*.jpg"]
                showDirs: false
            }

            function choose(){
                if(count === 0)
                    return
                UserProfile.setAvatar(model.get(currentIndex, "fileUrl").toString())
                picker.close()
            }

            Keys.onReturnPressed: choose()
            Keys.onEnterPressed: choose()

            delegate: Rectangle {
                id: tile
                required property int index
                required property url fileUrl
                readonly property bool selected: GridView.isCurrentItem && grid.activeFocus

                width: 287; height: 287
                color: "#009000"
                scale: selected ? 1.08 : 1.0
                z: selected ? 1 : 0
                Behavior on scale {NumberAnimation{duration: 150; easing.type: Easing.OutCubic}}

                Avatar {
                    anchors.fill: parent
                    anchors.margins: 24
                    source: tile.fileUrl
                }

                MouseArea{
                    anchors.fill: parent
                    onClicked: {
                        grid.currentIndex = tile.index
                        grid.choose()
                    }
                }
            }
        }

        Row{
            x: 180
            y: 990
            spacing: 40
            ButtonHint{button: "A"; label: "Choose"; visible: grid.count > 0}
            ButtonHint{button: "B"; label: "Back"}
        }
    }

    component Avatar: AnimatedImage{
        fillMode: Image.PreserveAspectFit
        smooth: implicitWidth * 2 > width
        asynchronous: true
        playing: visible
    }




























}