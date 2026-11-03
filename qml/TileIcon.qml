import QtQuick
import QtQuick.Shapes
import "icons.js" as Icons

// One white icon from icons.js, scaled to this item's size
Item {
    id: root

    property string name                                    // e.g. "disc", "gear"; "" = nothing
    property color color: "white"
    readonly property var shape: Icons.shapes[name] || null

    width: 72
    height: 72
    visible: shape !== null

    Shape {
        // Drawn in the 48x48 box from icons.js, then scaled up
        anchors.centerIn: parent
        width: 48
        height: 48
        scale: root.width / 48
        preferredRendererType: Shape.CurveRenderer          // smooth edges at any size

        ShapePath {                                         // the filled parts
            fillColor: root.color
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: root.shape && root.shape.fill ? root.shape.fill : "" }
        }

        ShapePath {                                         // the line parts
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.shape && root.shape.width ? root.shape.width : 4
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.shape && root.shape.line ? root.shape.line : "" }
        }
    }
}