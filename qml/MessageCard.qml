import QtQuick

FocusScope{
    id: card
    visible: false

    property string title
    property string message
    property string icon: "?"
    property var options: [{label: "OK", run: () => {}}]
    property int defaultIndex: options.length - 1

    property Item returnFocusTo: null

    function open() {
        returnFocusTo = Window.activeFocusItem
        list.currentIndex = Math.max(0, Math.min(defaultIndex, options.length - 1))
        visible = true
        list.forceActiveFocus()
        openAnimation.restart()
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

    Rectangle{
        id: backdrop
        anchors.fill: parent
        color: "#EE000000"

        MouseArea{
            anchors.fill: parent
            onClicked: card.close()
        }
    }

    Item{
        id: panel
        x: 547; y: 67
        width: 823; height: 857

        Rectangle{
            anchors.fill: parent
            gradient: Gradient{
                GradientStop{position: 0.0; color: "#FDFFFF"}
                GradientStop{position: 1.0; color: "#DCE5E6"}
            }
            MouseArea{anchors.fill: parent}
        }

        Rectangle{
            id: titleBar
            width: parent.width; height: 69
            gradient: Gradient{
                GradientStop{position: 0.0; color: "#97A0A3"}
                GradientStop{position: 1.0; color: "#585E66"}
            }
        }

        Item{
            id: details
            anchors.fill: parent

            Rectangle{
                x: 13
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: titleBar.height / 2
                width: 38; height: 38
                radius: width / 2
                gradient: Gradient{
                    GradientStop{position: 0.0; color: "#B4EC4C"}
                    GradientStop{position: 1.0; color: "#5FA818"}
                }

                Text{
                    anchors.centerIn: parent
                    text: card.icon
                    color: "white"
                    font.pixelSize: 28
                    font.bold: true
                }
            }

            Text{
                x: 62
                width: parent.width - x - 20
                height: titleBar.height
                verticalAlignment: Text.AlignVCenter
                text: card.title
                color: "white"
                font.pixelSize: 38
                elide: Text.ElideRight
            }

            Text{
                x: 41; y: 103
                width: parent.width - 2 * x
                text: card.message
                color: "#333333"
                font.pixelSize: 34
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }

            ListView{
                id: list
                anchors.bottom: parent.bottom
                width: parent.width
                height: count * 63
                interactive: false
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                model: card.options

                delegate: Rectangle{
                    id: row
                    required property int index
                    required property var modelData
                    readonly property bool selected: ListView.isCurrentItem

                    width: ListView.view.width
                    height: 63
                    color: selected ? "#008E00" : "#D5DFE0"

                    Text{
                        x: 41
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        color: row.selected ? "white" : "#222222"
                        font.pixelSize: 36
                    }

                    // A thin grey line between two plain rows, like the 360's lists
                    Column{
                        anchors.bottom: parent.bottom
                        width: parent.width
                        visible: !row.selected && row.index < list.count - 1
                                 && list.currentIndex !== row.index + 1
                        Rectangle{width: parent.width; height: 1; color: "#8E979A"}
                        Rectangle{width: parent.width; height: 1; color: "#C4CCCF"}
                    }

                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (Pointer.active) list.currentIndex = row.index   // not with the controller
                        onClicked: card.choose(row.index)
                    }
                }

                Keys.onReturnPressed: card.choose(currentIndex)
                Keys.onEnterPressed: card.choose(currentIndex)
                Keys.onEscapePressed: card.close()
            }
        }
    }

    Row{
        x: 547
        y: panel.y + panel.height + 14
        spacing: 30
        ButtonHint{button: "A"; label: "Select"}
        ButtonHint{button: "B"; label: "Back"}
    }

    SequentialAnimation{
        id: openAnimation
        ParallelAnimation{
            NumberAnimation{target: backdrop; property: "opacity"; from: 0; to: 1; duration: 150}
            NumberAnimation{target: panel; property: "scale"; from: 0.45; to: 1; duration: 250; easing.type: Easing.OutCubic}
            NumberAnimation{target: panel; property: "opacity"; from: 0.35; to: 1; duration: 250}
            PropertyAction{target: details; property: "opacity"; value: 0}
        }
        NumberAnimation{target: details; property: "opacity"; to: 1; duration: 200}
    }
}