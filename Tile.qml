import QtQuick

Rectangle{
    id: tile

    property string label
    property int column: 0
    property int row: 0
    property int columnSpan: 1
    property int rowSpan: 1

    readonly property int cellWidth: 310
    readonly property int cellHeight: 150
    readonly property int gap: 4

    signal activated()

    x: column * (cellWidth + gap)
    y: row * (cellHeight + gap)
    width: columnSpan * cellWidth + (columnSpan - 1) * gap
    height: rowSpan * cellHeight + (rowSpan - 1) * gap

    color: "#107C10"
    border.color: "white"
    border.width: activeFocus ? 4 : 0

    scale: activeFocus ? 1.04 : 1.0
    z: activeFocus ? 1 : 0
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Text{
        text: tile.label
        color: "white"
        font.pixelSize: 25
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
    }

    MouseArea{
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tile.forceActiveFocus()
        onClicked: tile.activated()
    }

    Keys.onReturnPressed: tile.activated()
    Keys.onEnterPressed: tile.activated()
    Keys.onSpacePressed: tile.activated()
}
