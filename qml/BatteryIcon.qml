import QtQuick

// The 360's battery: three bars, fewer as it runs down, red when it's empty.
// Shows nothing for a wired controller or one whose battery can't be read.
Item {
    id: battery

    property string level                       // "full", "medium", "low", "empty" or ""
    property color color: "white"

    readonly property int bars: level === "full" ? 3 : level === "medium" ? 2 : level === "low" ? 1 : 0

    width: 44; height: 22
    visible: level !== ""

    Rectangle {
        id: body
        width: parent.width - 5; height: parent.height
        radius: 3
        color: "transparent"
        border.color: battery.level === "empty" ? "#E8402A" : battery.color
        border.width: 2

        Row {
            x: 4; y: 4
            spacing: 2
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: (body.width - 12) / 3; height: body.height - 8
                    color: index < battery.bars ? (battery.level === "low" ? "#E8402A" : battery.color) : "transparent"
                }
            }
        }
    }
    Rectangle {                                 // the nub
        x: body.width; y: parent.height / 4
        width: 4; height: parent.height / 2
        color: body.border.color
    }
}