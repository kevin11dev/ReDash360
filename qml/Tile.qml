import QtQuick

Rectangle{
    id: tile

    property string label
    property int column: 0
    property int row: 0
    property int columnSpan: 1
    property int rowSpan: 1
    property var hints: []
    property string icon
    property string image
    property int iconSize: 72

    signal activated()
    signal yPressed()

    x: column * (parent.cellWidth + parent.gap)
    y: row * (parent.cellHeight + parent.gap)
    width: columnSpan * parent.cellWidth + (columnSpan - 1) * parent.gap
    height: rowSpan * parent.cellHeight + (rowSpan - 1) * parent.gap

    color: "#009000"

    scale: activeFocus ? 1.07 : 1.0
    z: activeFocus ? 1 : 0
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    TileIcon{
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20
        width: tile.iconSize
        height: tile.iconSize
        name: picture.status === Image.Ready ? "" : tile.icon
        z: 2
    }

    Image{
        id: picture
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20
        width: tile.iconSize
        height: tile.iconSize
        source: tile.image
        sourceSize: Qt.size(tile.iconSize, tile.iconSize)
        asynchronous: true
        z: 2
    }

    Text{
        z: 2
        text: tile.label
        color: "white"
        font.pixelSize: 25
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 0.9
    }

    // Soft shadow under the focused tile: a few see-through dark rectangles,
    // each a bit bigger than the last, so the edge fades out
    Item{
        anchors.fill: parent
        z: -1                                   // behind the tile, so only the edges show
        opacity: tile.activeFocus ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Repeater{
            model: 8
            Rectangle{
                required property int index
                x: 4 - index * 2
                y: 8 - index * 2
                width: parent.width + index * 4
                height: parent.height + index * 4
                radius: index * 2
                color: Qt.rgba(0, 0, 0, 0.07)
            }
        }
    }

    MouseArea{
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: {
            if(Pointer.active && !tile.activeFocus)
                tile.forceActiveFocus()
        }
        onClicked: tile.activated()
    }

    Keys.onReturnPressed: tile.activated()
    Keys.onEnterPressed: tile.activated()
    Keys.onSpacePressed: tile.activated()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Y){
            tile.yPressed()
            event.accepted = true
        }
    }
}
