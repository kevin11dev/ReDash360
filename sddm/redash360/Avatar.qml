import QtQuick
import QtQuick.Shapes

// Someone's avatar from ReDash360 (the animated picture on their Social
// tab), or for anyone without one a plain placeholder. lit: the profile you're
// on, standing out (and moving, with a shadow at its feet); the others are
// faded and still.
Item {
    id: avatar
    property bool lit: false
    property string source                      // their avatar, if they have one

    width: 220
    height: 410
    opacity: lit ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // Shadow on the floor
    Shape {
        x: 20; y: 372
        width: 180; height: 36
        opacity: avatar.lit && own.visible ? 1 : 0                // under a standing avatar
        Behavior on opacity { NumberAnimation { duration: 200 } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 90; centerY: 18; centerRadius: 90
                focalX: 90; focalY: 18
                GradientStop { position: 0.0; color: "#55000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
            PathSvg { path: "M0,18 A90,18 0 1,0 180,18 A90,18 0 1,0 0,18 Z" }
        }
    }

    AnimatedImage {
        id: own
        x: -5
        width: 230; height: 400                 // standing on the shadow
        source: avatar.source
        visible: status === AnimatedImage.Ready
        playing: avatar.lit
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        smooth: true
        asynchronous: true
    }

    // No avatar: the plain head and shoulders apps show for someone without
    // one. Picking an avatar replaces it.
    Item {
        id: figure
        width: parent.width
        height: 276
        anchors.bottom: parent.bottom
        visible: !own.visible
        clip: true                              // the shoulders end in a straight line

        Rectangle {                                                 // head
            x: 54; y: 56
            width: 112; height: 112
            radius: width / 2
            color: "#F4F5F5"
        }
        Rectangle {                                                 // shoulders
            x: 18; y: 184
            width: 184; height: 184
            radius: width / 2
            color: "#F4F5F5"
        }
    }
}
