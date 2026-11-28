import QtQuick
import QtQuick.Shapes

// This PC's own battery (a laptop's), on the dashboard and in the Guide: an
// outline that empties as it runs down, a bolt while it's on the charger, and
// how much is left. Red when it's nearly empty; nothing at all on a desktop PC.
Row {
    id: laptop

    property color color: "white"
    property int fontSize: 26

    readonly property bool low: Battery.percent <= 10 && !Battery.pluggedIn
    readonly property color ink: low ? "#E8402A" : color

    visible: Battery.present
    spacing: 8

    Shape {                                     // the bolt, while it's plugged in
        anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 20
        visible: Battery.pluggedIn
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: laptop.ink
            PathSvg { path: "M8,0 L0,11.5 H5 L3.5,20 L12,8 H6.8 Z" }
        }
    }

    Item {                                      // the battery
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 20

        Rectangle {
            id: body
            width: 36; height: parent.height
            radius: 3
            color: "transparent"
            border.color: laptop.ink
            border.width: 2

            Rectangle {                         // how full it is
                x: 4; y: 4
                width: (body.width - 8) * Battery.percent / 100
                height: body.height - 8
                color: laptop.ink
            }
        }
        Rectangle {                             // the nub
            x: body.width; y: parent.height / 4
            width: 4; height: parent.height / 2
            color: laptop.ink
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Battery.percent + "%"
        color: laptop.ink
        font.pixelSize: laptop.fontSize
    }
}