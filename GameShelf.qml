import QtQuick

FocusScope{
    id: shelf

    visible: false

    property Item returnFocusTo: null

    property var pickCallback: null
    readonly property bool picking: pickCallback !== null

    function open() {
        pickCallback = null
        show()
    }

    function pick(callback) {
        pickCallback = callback
        show()
    }

    function show() {
        returnFocusTo = Window.activeFocusItem
        visible = true
        list.forceActiveFocus()
    }

    function close() {
        visible = false
        pickCallback = null
        if(returnFocusTo)
            returnFocusTo.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: "#1c1c1c"
        opacity: 0.94
    }

    MouseArea{
        anchors.fill: parent
        hoverEnabled: true
    }

    Shortcut{
        sequence: "Esc"
        enabled: shelf.visible
        onActivated: shelf.close()
    }

    Column{
        anchors.right: parent.right
        anchors.rightMargin: 120
        y: 70

        Text{
            anchors.right: parent.right
            text: shelf.picking ? "choose a game" : "my games"
            color: "white"
            font.pixelSize: 56
            font.weight: Font.Light
        }

        Text{
            anchors.right: parent.right
            text: list.count > 0 ? (list.currentIndex + 1) + " of " + list.count : ""
            color: "white"
            opacity: 0.7
            font.pixelSize: 30
        }
    }

    Text{
        anchors.centerIn: parent
        visible: list.count ===0
        text: "No Games Found"
        color: "white"
        font.pixelSize: 40
        font.weight: Font.Light
    }

    ListView{
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        y: 230
        height: 640

        orientation: ListView.Horizontal
        spacing: 28
        leftMargin: 120
        rightMargin: 120
        model: GameLibrary

        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 120
        preferredHighlightEnd: width - 500
        highlightMoveDuration: 200

        Keys.onReturnPressed: activateCurrent()
        Keys.onEnterPressed: activateCurrent()
        Keys.onEscapePressed: shelf.close()

        function activateCurrent() {
            if(!currentItem)
                return
            if (shelf.picking) {
                shelf.pickCallback({
                    name: currentItem.name,
                    command: currentItem.command,
                    cover: currentItem.cover,
                    banner: currentItem.banner
                })
            } else {
                Launcher.play(currentItem.name, currentItem.command)
            }
            shelf.close()
        }

        delegate: Rectangle{
            id: card

            required property int index
            required property string name
            required property string source
            required property string command
            required property string cover
            required property string banner

            readonly property bool selected: ListView.isCurrentItem && list.activeFocus

            width: 340
            height: 600
            color: "white"
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            scale: selected ? 1.06 : 1.0
            z: selected ? 1 : 0
            Behavior on scale{NumberAnimation {duration: 150; easing.type: Easing.OutCubic}}

            Rectangle{
                id: coverArea
                x: 12; y: 12
                width: parent.width - 24
                height: width * 1.5
                color: "#008a00"

                Text{
                    anchors.fill: parent
                    anchors.margins: 16
                    visible: art.status !== Image.Ready
                    text: card.name
                    color: "white"
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignBottom
                }

                Image{
                    id: art
                    anchors.fill: parent
                    source: card.cover
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: width
                }
            }

            Text{
                anchors.left: coverArea.left
                anchors.right: coverArea.right
                anchors.top: coverArea.bottom
                anchors.topMargin: 14
                text: card.name
                color: "#333333"
                font.pixelSize: 28
                elide: Text.ElideRight
            }

            Text{
                anchors.left: coverArea.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                text: card.source
                color: "#777777"
                font.pixelSize: 22
            }

            MouseArea{
                anchors.fill: parent
                onClicked:{
                    list.currentIndex = card.index
                    list.activateCurrent()
                }
            }
        }
    }

    Row{
        x: 180
        y: 990
        spacing: 40
        ButtonHint{button: "A"; label: shelf.picking ? "Select" : "Launch"}
        ButtonHint{button: "B"; label: "Back"}
    }
}