import QtQuick

FocusScope {
    id: page

    signal tabRequested(int index)

    property alias cellWidth: grid.cellWidth
    property alias cellHeight: grid.cellHeight
    property alias gap: grid.gap

    default property alias tiles: grid.data

    Item{
        id: grid

        property int cellWidth: 310
        property int cellHeight: 197
        property int gap: 4

        anchors.left: parent.left
        anchors.top: parent.top
        width: childrenRect.width
        height: childrenRect.height
    }
}