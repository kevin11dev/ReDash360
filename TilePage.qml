import QtQuick

FocusScope {
    id: page

    signal tabRequested(int index)
    signal shelfRequested()
    signal pickGameRequested(var callback)
    signal appsRequested()
    signal appListRequested(string title, var apps)    // "my apps" screen with just these apps
    signal pickAppRequested(string title, var apps, var callback)   // same screen, to choose one
    signal powerRequested()
    signal recentsRequested()
    signal pinsRequested()
    signal profileRequested()
    signal networkRequested()
    signal storageRequested()
    signal controllersRequested()
    signal systemRequested()
    signal displaySoundRequested()
    signal preferencesRequested()
    signal newsRequested(var cards, int index)
    signal appSearchRequested()

    property alias cellWidth: grid.cellWidth
    property alias cellHeight: grid.cellHeight
    property alias gap: grid.gap

    default property alias tiles: grid.data

    Item{
        id: grid

        property int cellWidth: 310
        property int cellHeight: 220
        property int gap: 4

        anchors.left: parent.left
        anchors.top: parent.top
        width: childrenRect.width
        height: childrenRect.height
    }

    Keys.onPressed: (event) => {
        const from = focusedTile()
        if (!from)
            return
        const next = neighbour(from, event.key)
        if (next) {
            next.forceActiveFocus()
            event.accepted = true
        }
    }

    function focusedTile() {
        for (let i = 0; i < grid.children.length; i++) {
            if (grid.children[i].activeFocus)
                return grid.children[i]
        }
        return null
    }

    function neighbour(from, key) {
        let best = null
        for (let i = 0; i < grid.children.length; i++) {
            const t = grid.children[i]
            if (t === from || t.columnSpan === undefined)   // skip non-tiles
                continue

            // Do the two tiles share any rows / any columns?
            const rowsOverlap = t.row < from.row + from.rowSpan && t.row + t.rowSpan > from.row
            const colsOverlap = t.column < from.column + from.columnSpan && t.column + t.columnSpan > from.column

            let touching = false
            if (key === Qt.Key_Right)
                touching = rowsOverlap && t.column === from.column + from.columnSpan
            else if (key === Qt.Key_Left)
                touching = rowsOverlap && t.column + t.columnSpan === from.column
            else if (key === Qt.Key_Down)
                touching = colsOverlap && t.row === from.row + from.rowSpan
            else if (key === Qt.Key_Up)
                touching = colsOverlap && t.row + t.rowSpan === from.row
            if (!touching)
                continue

            const linedUp = (key === Qt.Key_Left || key === Qt.Key_Right)
                ? t.row <= from.row && from.row < t.row + t.rowSpan
                : t.column <= from.column && from.column < t.column + t.columnSpan
            if (!best || linedUp)
                best = t
        }
        return best
    }
}